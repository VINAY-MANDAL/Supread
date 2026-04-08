import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:universal_io/io.dart' as io;
import '../models/pdf_file_data.dart';

class PdfViewerScreen extends StatefulWidget {
  final PdfFileData pdfData;
  const PdfViewerScreen({super.key, required this.pdfData});

  @override
  State<PdfViewerScreen> createState() => _PdfViewerScreenState();
}

class _PdfViewerScreenState extends State<PdfViewerScreen> {
  final PdfViewerController _controller = PdfViewerController();
  int _currentPage = 1;
  int _totalPages = 0;

  final TextEditingController _pageController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.pdfData.name,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
        actions: [
          // Page info
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '$_currentPage / $_totalPages',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ),
          // Jump to page
          IconButton(
            icon: const Icon(Icons.find_in_page),
            onPressed: () => _showGoToPageDialog(),
          ),
          // Zoom in
          IconButton(
            icon: const Icon(Icons.zoom_in),
            onPressed: () => _controller.zoomLevel += 0.25,
          ),
          // Zoom out
          IconButton(
            icon: const Icon(Icons.zoom_out),
            onPressed: () => _controller.zoomLevel -= 0.25,
          ),
        ],
      ),
      body: widget.pdfData.isWeb
          ? _buildWebPdfViewer()
          : _buildNativePdfViewer(),
      // Bottom navigation bar
      bottomNavigationBar: BottomAppBar(
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

  void _showGoToPageDialog() {
    _pageController.clear();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Go to Page'),
        content: TextField(
          controller: _pageController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter page (1 - $_totalPages)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
      io.File(widget.pdfData.path!),
      controller: _controller,
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
      onDocumentLoaded: (details) {
        setState(() {
          _currentPage = 1;
          _totalPages = details.document.pages.count;
        });
      },
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
      onPageChanged: (details) {
        setState(() {
          _currentPage = details.newPageNumber;
        });
      },
      onDocumentLoaded: (details) {
        setState(() {
          _currentPage = 1;
          _totalPages = details.document.pages.count;
        });
      },
    );
  }
}