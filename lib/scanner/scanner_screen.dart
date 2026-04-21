import 'dart:io';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
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

      // ✅ Saare scanned pages ko ek single PDF mein convert karo
      await _convertImagesToPdf(scannedPaths);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${scannedPaths.length} page(s) scanned & saved as PDF!'),
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

  /// ✅ Multiple scanned images ko ek PDF mein convert karo
  Future<void> _convertImagesToPdf(List<String> imagePaths) async {
    final pdf = pw.Document();

    for (final imagePath in imagePaths) {
      final imageFile = File(imagePath);
      if (!imageFile.existsSync()) continue;

      final imageBytes = await imageFile.readAsBytes();
      final image = pw.MemoryImage(imageBytes);

      // Har image ko ek PDF page pe full-page add karo
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Image(image, fit: pw.BoxFit.contain);
          },
        ),
      );
    }

    // PDF bytes generate karo
    final pdfBytes = await pdf.save();

    // File name timestamp se banao
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'Scan_$timestamp.pdf';

    // App ke documents/scans folder mein save karo
    final appDir = await getApplicationDocumentsDirectory();
    final scansDir = Directory('${appDir.path}/scans');
    if (!scansDir.existsSync()) scansDir.createSync(recursive: true);

    final savedFile = File('${scansDir.path}/$fileName');
    await savedFile.writeAsBytes(pdfBytes);

    // Downloads folder mein bhi save karo
    await _saveToDownloads(savedFile, fileName);

    // Recent files mein register karo
    await PdfService.saveScannedFile(
      path: savedFile.path,
      name: fileName,
    );
  }

  /// Android Downloads folder mein PDF save karo
  Future<void> _saveToDownloads(File sourceFile, String fileName) async {
    try {
      PermissionStatus storageStatus;
      if (Platform.isAndroid) {
        storageStatus = await Permission.manageExternalStorage.request();
        if (!storageStatus.isGranted) {
          storageStatus = await Permission.storage.request();
        }
      } else {
        storageStatus = PermissionStatus.granted;
      }

      if (storageStatus.isGranted) {
        const downloadsPath = '/storage/emulated/0/Download';
        final downloadsDir = Directory(downloadsPath);
        if (downloadsDir.existsSync()) {
          final destFile = File('$downloadsPath/$fileName');
          await sourceFile.copy(destFile.path);
        }
      } else {
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          final destFile = File('${extDir.path}/$fileName');
          await sourceFile.copy(destFile.path);
        }
      }
    } catch (e) {
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
                    'Scanning & Converting to PDF...',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ],
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
