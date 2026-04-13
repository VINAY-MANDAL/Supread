import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_data.dart';
import '../services/pdf_service.dart';
import 'recent_file.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  List<PdfFileData> _scannedFiles = [];
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _loadScannedFiles();
  }

  // Load scanned files from PdfService (those whose name starts with 'Scan_')
  Future<void> _loadScannedFiles() async {
    final all = await PdfService.getRecent();
    if (mounted) {
      setState(() {
        _scannedFiles = all.where((f) => f.name.startsWith('Scan_')).toList();
      });
    }
  }

  // ─── Scan as Image ─────────────────────────────────────────────────────────
  Future<void> _scanDocument() async {
    setState(() => _isScanning = true);
    try {
      final result = await FlutterDocScanner().getScanDocuments(page: 4);
      debugPrint('Scanner Result: $result');
      if (!mounted) return;
      if (result != null) {
        await _saveScannedResult(result, isPdfRequested: false);
        _showSnack('Document scanned successfully!');
      }
    } on PlatformException catch (e) {
      _showSnack('Scan failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ─── Scan as PDF ───────────────────────────────────────────────────────────
  Future<void> _scanPdf() async {
    setState(() => _isScanning = true);
    try {
      final result = await FlutterDocScanner().getScannedDocumentAsPdf(page: 4);
      debugPrint('PDF Scanner Result: $result');
      if (!mounted) return;
      if (result != null) {
        await _saveScannedResult(result, isPdfRequested: true);
        _showSnack('PDF scanned successfully!');
      }
    } on PlatformException catch (e) {
      _showSnack('PDF scan failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ✅ Save scanned result into PdfService so HomeScreen recents also updates
  Future<void> _saveScannedResult(dynamic result,
      {required bool isPdfRequested}) async {
    final paths = _extractPaths(result, isPdfRequested);
    debugPrint('--- Verification Start ---');
    debugPrint('Extracted ${paths.length} paths from scanner.');

    for (final path in paths) {
      final file = File(path);
      debugPrint('Step 1: Checking source file at: $path');
      debugPrint('Source file exists: ${file.existsSync()}');

      if (!file.existsSync()) continue;

      // Determine extension based on actual file path, fallback to requested
      final ext = path.toLowerCase().endsWith('.pdf') ? '.pdf' : '.jpg';
      final name = 'Scan_${DateTime.now().microsecondsSinceEpoch}$ext';

      debugPrint('Step 2: Attempting to save as $name via PdfService...');
      await PdfService.saveScannedFile(path: path, name: name);
    }

    // Reload files after saving to ensure we have the updated permanent paths
    await _loadScannedFiles();

    debugPrint('Step 3: Verification after reload:');
    for (var f in _scannedFiles) {
      final exists = f.path != null && File(f.path!).existsSync();
      debugPrint(
          'File in List: ${f.name} | Path: ${f.path} | Exists on disk: $exists');
    }
    debugPrint('--- Verification End ---');
  }

  // ─── Open File ─────────────────────────────────────────────────────────────
  Future<void> _openFile(PdfFileData file) async {
    if (file.path == null || !File(file.path!).existsSync()) {
      debugPrint('Error: Cannot open file. Path: ${file.path}');
      _showSnack('File not found on device.');
      return;
    }

    debugPrint('Opening file: ${file.path}');
    final result = await OpenFilex.open(file.path!);
    if (result.type != ResultType.done && mounted) {
      _showSnack('Could not open: ${result.message}');
    }
  }

  // ─── Share File ────────────────────────────────────────────────────────────
  Future<void> _shareFile(PdfFileData file) async {
    if (file.path == null) {
      _showSnack('File path not found.');
      return;
    }
    final fileToShare = File(file.path!);
    if (await fileToShare.exists()) {
      await Share.shareXFiles([XFile(file.path!)],
          text: 'Check out this document: ${file.name}');
    } else {
      _showSnack('File does not exist on storage.');
    }
  }

  // ─── Delete File ───────────────────────────────────────────────────────────
  Future<void> _deleteFile(int index) async {
    final file = _scannedFiles[index];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Delete "${file.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      if (file.path != null) {
        final f = File(file.path!);
        if (f.existsSync()) await f.delete();
      }
      await PdfService.deleteRecent(file);
      setState(() => _scannedFiles.removeAt(index));
      _showSnack('File deleted.');
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  List<String> _extractPaths(dynamic result, bool isPdfRequested) {
    if (result == null) return [];

    List<String> rawPaths = [];
    if (result is String) {
      rawPaths = [result];
    } else if (result is List) {
      rawPaths = result.map((e) => e.toString()).toList();
    } else if (result is Map) {
      dynamic val;
      if (isPdfRequested) {
        val = result['pdfPath'] ??
            result['pdf'] ??
            result['pdf_path'] ??
            result['path'];
      } else {
        val = result['images'] ?? result['imagePaths'] ?? result['path'];
      }

      if (val is List) {
        rawPaths = val.map((e) => e.toString()).toList();
      } else if (val != null) {
        rawPaths = [val.toString()];
      }
    }

    return rawPaths
        .map((p) {
          String sanitized = Uri.decodeFull(p.trim());
          // Handles file:/, file://, and file:/// prefixes robustly
          sanitized = sanitized.replaceFirst(RegExp(r'^file:/{1,3}'), '/');
          return sanitized.replaceAll(RegExp(r'/+'), '/');
        })
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── UI ────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scanner'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Scanning document…'),
                ],
              ),
            )
          : _scannedFiles.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.document_scanner_outlined,
                          size: 80, color: Colors.grey),
                      SizedBox(height: 12),
                      Text('No scanned documents yet.',
                          style: TextStyle(color: Colors.grey)),
                      SizedBox(height: 8),
                      Text('Use the buttons below to scan.',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _scannedFiles.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final file = _scannedFiles[i];
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RecentsFileCard(
                          file: file,
                          onDeleted: _loadScannedFiles,
                          onRenamed: _loadScannedFiles,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () => _shareFile(file),
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text('Share Document'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.extended(
            heroTag: 'scan_img',
            onPressed: _isScanning ? null : _scanDocument,
            icon: const Icon(Icons.document_scanner),
            label: const Text('Scan Image'),
            backgroundColor: Colors.deepPurple,
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'scan_pdf',
            onPressed: _isScanning ? null : _scanPdf,
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Scan PDF'),
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }
}
