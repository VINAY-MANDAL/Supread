import 'package:flutter/material.dart';
import '../services/pdf_service.dart';
import '../models/pdf_file_data.dart';
import 'pdf_viewer_screen.dart';
import '../scanner/scanner_screen.dart';
import '../widgets/recents_file_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<PdfFileData> recentFiles = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
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
    // ✅ FIX: Added a small delay to ensure the database/service is updated
    // before refreshing the Home Screen list.
    await Future.delayed(const Duration(milliseconds: 500));
    _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supread'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.document_scanner),
            tooltip: 'Scan Document',
            onPressed: _openScanner,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear All Recents',
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Clear All Recents?'),
                  content: const Text(
                      'This will remove all recent files from the list.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirmed == true) {
                await PdfService.clearRecent();
                _loadRecent();
              }
            },
          ),
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
                onOpen: (file) => _openFileInApp(file), // ✅ In-app viewer
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('Open PDF'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
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
