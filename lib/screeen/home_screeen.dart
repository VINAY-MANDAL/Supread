import 'package:flutter/material.dart';
import '../services/pdf_service.dart';
import '../models/pdf_file_data.dart';
import 'pdf_viewer_screen.dart';

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
    setState(() => recentFiles = files);
  }

  Future<void> _pickAndOpen() async {
    final pdfData = await PdfService.pickPdf();
    if (pdfData != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfViewerScreen(pdfData: pdfData),
        ),
      );
      _loadRecent();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('supread'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Recent',
            onPressed: () async {
              await PdfService.clearRecent();
              _loadRecent();
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
                  Text(
                    'No recent files',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text('Tap the button below to open a PDF file.'),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: recentFiles.length,
              itemBuilder: (_, index) {
                final file = recentFiles[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: const Icon(Icons.picture_as_pdf,
                        color: Colors.deepPurple, size: 36),
                    title: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      file.isWeb ? 'Web file' : (file.path ?? 'Unknown path'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfViewerScreen(pdfData: file),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _pickAndOpen,
        icon: const Icon(Icons.folder_open),
        label: const Text('open PDF'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}
