import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:light_dark_theme_toggle/light_dark_theme_toggle.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/pdf_service.dart';
import '../models/pdf_file_data.dart';
import 'pdf_viewer_screen.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/recents_file_card.dart';
import '../main.dart'; // themeNotifier ke liye import

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfFileData> recentFiles = [];

  // ✅ Open With — bahar se aane wali files ke liye subscription
  StreamSubscription? _intentSub;

  @override
  void initState() {
    super.initState();
    _loadRecent();
    _setupOpenWith();
  }

  @override
  void dispose() {
    _intentSub?.cancel();
    super.dispose();
  }

  // ✅ "Open With" setup — dono cases handle karta hai:
  // 1. App pehle se chal rahi ho aur koi PDF bahar se open kare
  // 2. PDF se directly app pehli baar khuli ho
  void _setupOpenWith() {
    // App running ho tab bahar se aane wali files
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((files) {
      if (files.isNotEmpty && mounted) {
        _openExternalFile(files.first.path);
      }
    });

    // App band thi, PDF se khuli ho
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      if (files.isNotEmpty && mounted) {
        _openExternalFile(files.first.path);
        // Intent clear karo taaki dobara trigger na ho
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  // ✅ Bahar se aayi PDF file ko open karo aur recents mein save karo
  Future<void> _openExternalFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (!file.existsSync()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found.')),
        );
      }
      return;
    }

    final name = path.split('/').last;
    // Recents mein save karo
    await PdfService.saveScannedFile(path: path, name: name);
    _loadRecent();

    final pdfData = PdfFileData(name: name, path: path, isWeb: false);
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfData: pdfData)),
      );
      _loadRecent();
    }
  }

  Future<void> _loadRecent() async {
    final files = await PdfService.getRecent();
    if (mounted) setState(() => recentFiles = files);
  }

  Future<void> _pickAndOpen() async {
    final pdfData = await PdfService.pickPdf();
    if (pdfData != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PdfViewerScreen(pdfData: pdfData)),
      );
      _loadRecent();
    }
  }

  Future<void> _openScanner() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adhyay'),
        actions: [
          // Theme Toggle
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeNotifier,
            builder: (context, mode, child) {
              return LightDarkThemeToggle(
                value: mode == ThemeMode.light,
                onChanged: (bool isLight) {
                  themeNotifier.value =
                      isLight ? ThemeMode.light : ThemeMode.dark;
                },
                size: 28,
              );
            },
          ),
          // Scanner
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Document',
            onPressed: _openScanner,
          ),
          // ✅ "Clear All" button HATA DIYA — galti se press hone se bacha
          // Agar zaroorat ho to RecentsFileCard ke popup menu se ek-ek delete kar sakte hain
        ],
      ),
      body: recentFiles.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No recent files',
                      style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('Open a PDF or scan a document to get started.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: recentFiles.length,
              itemBuilder: (ctx, index) => RecentsFileCard(
                file: recentFiles[index],
                onDeleted: _loadRecent,
                onRenamed: _loadRecent,
                onOpen: (file) => _openFileInApp(file),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('Open PDF'),
      ),
    );
  }

  // ✅ PDF aur Image dono ko in-app open kare
  Future<void> _openFileInApp(PdfFileData file) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(pdfData: file),
      ),
    );
    _loadRecent();
  }
}
