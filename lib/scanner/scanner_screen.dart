import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/pdf_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Screen open hote hi scanner launch karo
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScan());
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    try {
      // Camera permission maango
      final cameraStatus = await Permission.camera.request();
      if (!cameraStatus.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera permission required.')),
          );
          Navigator.pop(context);
        }
        return;
      }

      // Document scanner launch karo
      final List<String>? scannedPaths =
          await CunningDocumentScanner.getPictures(
        noOfPages: 10,
        isGalleryImportAllowed: true,
      );

      if (scannedPaths == null || scannedPaths.isEmpty) {
        // User ne cancel kiya
        if (mounted) Navigator.pop(context);
        return;
      }

      // Har scanned page ko save karo
      for (final String tempPath in scannedPaths) {
        await _saveScannedFile(tempPath);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '${scannedPaths.length} page(s) scanned & saved to Downloads!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Home screen par wapas jao
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Scanning failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isScanning = false);
    }
  }

  /// Scanned image ko app folder + Downloads dono me save karo
  Future<void> _saveScannedFile(String tempPath) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Scan_$timestamp.jpg';

    // 1. App ke documents folder me copy karo (in-app open ke liye)
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!scansDir.existsSync()) scansDir.createSync(recursive: true);

    final savedFile = File('${scansDir.path}/$fileName');
    await File(tempPath).copy(savedFile.path);

    // 2. Downloads folder me bhi save karo
    await _saveToDownloads(savedFile, fileName);

    // 3. Recent files me register karo
    await PdfService.saveScannedFile(
      path: savedFile.path,
      name: fileName,
    );
  }

  /// Android Downloads folder me file save karo
  Future<void> _saveToDownloads(File sourceFile, String fileName) async {
    try {
      // Android 13+ ke liye MANAGE_EXTERNAL_STORAGE ya MediaStore use karo
      // Pehle storage permission check karo
      PermissionStatus storageStatus;
      if (Platform.isAndroid) {
        storageStatus = await Permission.manageExternalStorage.request();
        if (!storageStatus.isGranted) {
          // Fallback: old API
          storageStatus = await Permission.storage.request();
        }
      } else {
        storageStatus = PermissionStatus.granted;
      }

      if (storageStatus.isGranted) {
        // Standard Downloads path
        const downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (downloadsDir.existsSync()) {
          final destFile = File('$downloadsPath/$fileName');
          await sourceFile.copy(destFile.path);
        }
      } else {
        // Permission nahi mili — external storage dir try karo
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final destFile = File('${extDir.path}/$fileName');
          await sourceFile.copy(destFile.path);
        }
      }
    } catch (e) {
      // Downloads me save nahi hua lekin app me toh save ho gaya
      debugPrint('Could not save to Downloads: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _isScanning
            ? const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.deepPurple),
                  SizedBox(height: 20),
                  Text(
                    'Scanning...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
