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
        await _saveScannedResult(result, isPdf: false);
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
        await _saveScannedResult(result, isPdf: true);
        _showSnack('PDF scanned successfully!');
      }
    } on PlatformException catch (e) {
      _showSnack('PDF scan failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ✅ Save scanned result into PdfService so HomeScreen recents also updates
  Future<void> _saveScannedResult(dynamic result, {required bool isPdf}) async {
    final paths = _extractPaths(result);
    for (final path in paths) {
      debugPrint('Processing path: $path');
      if (!File(path).existsSync()) {
        debugPrint('CRITICAL: Scanned file does not exist at path: $path');
      }

      final ext = isPdf ? '.pdf' : '.jpg';
      final name = 'Scan_${DateTime.now().millisecondsSinceEpoch}$ext';
      await PdfService.saveScannedFile(path: path, name: name);
      final fileData = PdfFileData(name: name, path: path, isWeb: false);
      if (mounted) {
        setState(() => _scannedFiles.insert(0, fileData));
      }
    }
    await _loadScannedFiles(); // Refresh to ensure data is properly persisted
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
  List<String> _extractPaths(dynamic result) {
    if (result == null) return [];

    List<String> rawPaths = [];
    if (result is String) {
      rawPaths = [result];
    } else if (result is List) {
      rawPaths = result.map((e) => e.toString()).toList();
    } else if (result is Map) {
      // Handle various keys returned by different versions of scanner plugins
      final pdfPath = result['pdfPath'] ??
          result['pdf'] ??
          result['path'] ??
          result['pdf_path'];
      if (pdfPath != null) {
        rawPaths = [pdfPath.toString()];
      } else {
        final images = result['images'] ?? result['imagePaths'];
        if (images is List) {
          rawPaths = images.map((e) => e.toString()).toList();
        }
      }
    }

    // Sanitize paths: Remove 'file://' prefix and trim whitespace
    return rawPaths
        .map((p) {
          String sanitized = p.trim();
          // Remove common URI prefixes that dart:io can't handle
          if (sanitized.startsWith('file://')) {
            sanitized = sanitized.replaceFirst('file://', '');
          }
          // On some Android builds, multiple slashes can occur
          return sanitized.replaceAll('///', '/').replaceAll('//', '/');
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
