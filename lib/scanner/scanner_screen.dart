import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_doc_scanner/flutter_doc_scanner.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/pdf_file_data.dart';
import '../services/pdf_service.dart';
import '../screeen/pdf_viewer_screen.dart'; // ✅ Added internal viewer import

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
      if (!mounted) return;
      if (result != null) {
        await _saveScannedResult(result, isPdfRequested: false);
        _showSnack('Document scanned and saved!');
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
      if (!mounted) return;
      if (result != null) {
        await _saveScannedResult(result, isPdfRequested: true);
        _showSnack('PDF scanned and saved!');
      }
    } on PlatformException catch (e) {
      _showSnack('PDF scan failed: ${e.message}');
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  // ✅ KEY FIX: Scan hone ke baad file ko permanent app directory mein copy karo
  Future<void> _saveScannedResult(dynamic result,
      {required bool isPdfRequested}) async {
    final paths = _extractPaths(result, isPdfRequested);

    // App ki permanent internal directory
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!scansDir.existsSync()) {
      scansDir.createSync(recursive: true);
    }

    for (final tempPath in paths) {
      final sourceFile = File(tempPath);
      if (!sourceFile.existsSync()) {
        debugPrint('Source file not found: $tempPath');
        continue;
      }

      final ext = tempPath.toLowerCase().endsWith('.pdf') ? '.pdf' : '.jpg';
      final name = 'Scan_${DateTime.now().microsecondsSinceEpoch}$ext';

      // ✅ Temporary path se permanent path mein copy karo
      final permanentPath = '${scansDir.path}/$name';
      await sourceFile.copy(permanentPath);

      debugPrint('Saved permanently at: $permanentPath');

      // ✅ PdfService mein permanent path save karo
      await PdfService.saveScannedFile(path: permanentPath, name: name);
    }

    await _loadScannedFiles();
  }

  // ─── Open File ─────────────────────────────────────────────────────────────
  Future<void> _openFile(PdfFileData file) async {
    if (file.path == null || !File(file.path!).existsSync()) {
      _showSnack('File not found on device.');
      return;
    }

    // ✅ FIX: Use in-app viewer instead of external OpenFilex
    // This ensures files in internal storage can actually be opened.
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfData: file)),
    );
    _loadScannedFiles();
  }

  // ─── Share File ────────────────────────────────────────────────────────────
  Future<void> _shareFile(PdfFileData file) async {
    if (file.path == null) {
      _showSnack('File path not found.');
      return;
    }
    final fileToShare = File(file.path!);
    if (!fileToShare.existsSync()) {
      _showSnack('File does not exist on storage.');
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path!)],
      text: 'Document: ${file.name}',
    );
  }

  // ─── Save to Downloads ─────────────────────────────────────────────────────
  Future<void> _saveToDownloads(PdfFileData file) async {
    if (file.path == null || !File(file.path!).existsSync()) {
      _showSnack('File not found.');
      return;
    }

    // Android par storage permission maango
    if (Platform.isAndroid) {
      final status = await Permission.storage.request();
      // Android 13+ ke liye manage external storage
      if (!status.isGranted) {
        final manage = await Permission.manageExternalStorage.request();
        if (!manage.isGranted) {
          _showSnack('Storage permission denied.');
          return;
        }
      }
    }

    try {
      // Downloads folder path
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!downloadsDir.existsSync()) {
          downloadsDir = await getExternalStorageDirectory();
        }
      } else if (Platform.isIOS) {
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      if (downloadsDir == null) {
        _showSnack('Could not find Downloads folder.');
        return;
      }

      final destPath = '${downloadsDir.path}/${file.name}';
      await File(file.path!).copy(destPath);

      if (mounted) {
        _showSnack('Saved to Downloads: ${file.name}');
      }
    } catch (e) {
      _showSnack('Save failed: $e');
    }
  }

  // ─── Delete File ───────────────────────────────────────────────────────────
  Future<void> _deleteFile(PdfFileData file) async {
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
      _loadScannedFiles();
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
          String s = Uri.decodeFull(p.trim());
          s = s.replaceFirst(RegExp(r'^file:/{1,3}'), '/');
          return s.replaceAll(RegExp(r'/+'), '/');
        })
        .where((p) => p.isNotEmpty)
        .toList();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ─── File Action Bottom Sheet ───────────────────────────────────────────────
  void _showFileOptions(PdfFileData file) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                file.name,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.open_in_new, color: Colors.deepPurple),
              title: const Text('Open'),
              onTap: () {
                Navigator.pop(context);
                _openFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Share'),
              onTap: () {
                Navigator.pop(context);
                _shareFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: const Text('Save to Downloads'),
              onTap: () {
                Navigator.pop(context);
                _saveToDownloads(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _deleteFile(file);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _scannedFiles.length,
                  itemBuilder: (ctx, i) {
                    final file = _scannedFiles[i];
                    final isImage = !file.name.toLowerCase().endsWith('.pdf');

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 2,
                      child: ListTile(
                        leading: Icon(
                          isImage ? Icons.image : Icons.picture_as_pdf,
                          color: isImage ? Colors.blueAccent : Colors.red,
                          size: 36,
                        ),
                        title: Text(file.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(
                          file.path ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        onTap: () => _openFile(file),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.share, color: Colors.blue),
                              tooltip: 'Share',
                              onPressed: () => _shareFile(file),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_vert),
                              tooltip: 'More options',
                              onPressed: () => _showFileOptions(file),
                            ),
                          ],
                        ),
                      ),
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
