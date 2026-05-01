import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:universal_io/io.dart' as uio;
import '../models/pdf_file_data.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfFileData pdfData;
  const PdfViewerScreen({super.key, required this.pdfData});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  final TextEditingController _pageController = TextEditingController();
  int _currentPage = 1;
  int _totalPages = 0;

  bool get _isImage {
    final name = widget.pdfData.name.toLowerCase();
    return name.endsWith('.jpg') ||
        name.endsWith('.jpeg') ||
        name.endsWith('.png');
  }

  Future<void> _shareFile() async {
    final path = widget.pdfData.path;
    if (path == null || !File(path).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found for sharing.')),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(path)],
      text: 'Document: ${widget.pdfData.name}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfData.name, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share',
            onPressed: _shareFile,
          ),
          // Page info — sirf PDF ke liye
          if (!_isImage)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 15),
                ),
              ),
            ),
          if (!_isImage)
            IconButton(
              icon: const Icon(Icons.find_in_page),
              onPressed: _showGoToPageDialog,
            ),
          if (!_isImage)
            IconButton(
              icon: const Icon(Icons.zoom_in),
              onPressed: () => _controller.zoomLevel += 0.25,
            ),
          if (!_isImage)
            IconButton(
              icon: const Icon(Icons.zoom_out),
              onPressed: () => _controller.zoomLevel -= 0.25,
            ),
        ],
      ),
      // ✅ Image ya PDF — dono handle karo
      body: _isImage ? _buildImageViewer() : _buildPdfViewer(),
      bottomNavigationBar: _isImage
          ? null
          : BottomAppBar(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.first_page),
                    onPressed: () => _controller.jumpToPage(1),
                    tooltip: 'First Page',
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_before),
                    onPressed: () {
                      if (_currentPage > 1) {
                        _controller.jumpToPage(_currentPage - 1);
                      }
                    },
                    tooltip: 'Previous',
                  ),
                  IconButton(
                    icon: const Icon(Icons.navigate_next),
                    onPressed: () {
                      if (_currentPage < _totalPages) {
                        _controller.jumpToPage(_currentPage + 1);
                      }
                    },
                    tooltip: 'Next',
                  ),
                  IconButton(
                    icon: const Icon(Icons.last_page),
                    onPressed: () => _controller.jumpToPage(_totalPages),
                    tooltip: 'Last Page',
                  ),
                ],
              ),
            ),
    );
  }

  // ✅ Image viewer — pinch-to-zoom ke saath
  Widget _buildImageViewer() {
    final path = widget.pdfData.path;
    if (path == null || !File(path).existsSync()) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, size: 80, color: Colors.grey),
            SizedBox(height: 16),
            Text('Image not found on device.'),
          ],
        ),
      );
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5.0,
      child: Center(
        child: Image.file(
          File(path),
          errorBuilder: (_, __, ___) => const Center(
            child: Text('Could not load image.'),
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    if (widget.pdfData.isWeb) return _buildWebPdfViewer();
    return _buildNativePdfViewer();
  }

  void _showGoToPageDialog() {
    _pageController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          decoration:
              InputDecoration(hintText: 'Enter page (1 - $_totalPages)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final page = int.tryParse(_pageController.text);
              if (page != null && page >= 1 && page <= _totalPages) {
                _controller.jumpToPage(page);
                Navigator.pop(context);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  Widget _buildNativePdfViewer() {
    return SfPdfViewer.file(
      uio.File(widget.pdfData.path!),
      controller: _controller,
      onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
      onDocumentLoaded: (d) => setState(() {
        _currentPage = 1;
        _totalPages = d.document.pages.count;
      }),
    );
  }

  Widget _buildWebPdfViewer() {
    final webBytes = widget.pdfData.bytes;
    if (webBytes == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 80, color: Colors.red),
            SizedBox(height: 16),
            Text('Unable to load PDF bytes for web.'),
          ],
        ),
      );
    }
    return SfPdfViewer.memory(
      Uint8List.fromList(webBytes),
      controller: _controller,
      onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
      onDocumentLoaded: (d) => setState(() {
        _currentPage = 1;
        _totalPages = d.document.pages.count;
      }),
    );
  }
}
