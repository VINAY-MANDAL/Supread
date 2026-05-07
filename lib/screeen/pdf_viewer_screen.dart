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
  // ── Controllers & Keys ──────────────────────────────────────────────────
  final PdfViewerController _controller = PdfViewerController();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final TextEditingController _pageController = TextEditingController();

  // ── State ────────────────────────────────────────────────────────────────
  int _currentPage = 1;
  int _totalPages = 0;
  bool _showAnnotationToolbar = false;
  PdfAnnotationMode _activeMode = PdfAnnotationMode.none;

  bool get _isImage {
    final n = widget.pdfData.name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
  }

  // ── Annotation mode toggle ───────────────────────────────────────────────
  void _setMode(PdfAnnotationMode mode) {
    final next = (_activeMode == mode) ? PdfAnnotationMode.none : mode;
    setState(() => _activeMode = next);
    _controller.annotationMode = next;
  }

  // ── Share ────────────────────────────────────────────────────────────────
  Future<void> _shareFile() async {
    final path = widget.pdfData.path;
    if (path == null || !File(path).existsSync()) {
      _snack('File not found for sharing.');
      return;
    }
    await Share.shareXFiles([XFile(path)],
        text: 'Document: ${widget.pdfData.name}');
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Go-to-page dialog ────────────────────────────────────────────────────
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
              InputDecoration(hintText: 'Enter page (1 – $_totalPages)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final p = int.tryParse(_pageController.text);
              if (p != null && p >= 1 && p <= _totalPages) {
                _controller.jumpToPage(p);
                Navigator.pop(context);
              }
            },
            child: const Text('Go'),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pdfData.name, overflow: TextOverflow.ellipsis),
        actions: [
          // Annotation toggle (PDF only)
          if (!_isImage)
            IconButton(
              icon: Icon(
                Icons.draw,
                color: _showAnnotationToolbar
                    ? Theme.of(context).colorScheme.inversePrimary
                    : null,
              ),
              tooltip: 'Annotation Tools',
              onPressed: () {
                setState(() {
                  _showAnnotationToolbar = !_showAnnotationToolbar;
                  if (!_showAnnotationToolbar) {
                    _activeMode = PdfAnnotationMode.none;
                    _controller.annotationMode = PdfAnnotationMode.none;
                  }
                });
              },
            ),
          IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share',
              onPressed: _shareFile),
          if (!_isImage)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('$_currentPage / $_totalPages',
                    style: const TextStyle(fontSize: 15)),
              ),
            ),
          if (!_isImage)
            IconButton(
                icon: const Icon(Icons.find_in_page),
                onPressed: _showGoToPageDialog),
          if (!_isImage)
            IconButton(
                icon: const Icon(Icons.zoom_in),
                onPressed: () => _controller.zoomLevel += 0.25),
          if (!_isImage)
            IconButton(
                icon: const Icon(Icons.zoom_out),
                onPressed: () => _controller.zoomLevel -= 0.25),
        ],
      ),
      body: Column(
        children: [
          // Annotation toolbar slides in from the top
          if (_showAnnotationToolbar && !_isImage) _buildAnnotationToolbar(),
          Expanded(child: _isImage ? _buildImageViewer() : _buildPdfViewer()),
        ],
      ),
      bottomNavigationBar: _isImage ? null : _buildBottomNav(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  ANNOTATION TOOLBAR
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildAnnotationToolbar() {
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Tool row ──────────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _toolBtn(
                  icon: Icons.highlight,
                  label: 'Highlight',
                  mode: PdfAnnotationMode.highlight,
                ),
                const SizedBox(width: 4),
                _toolBtn(
                  icon: Icons.format_underlined,
                  label: 'Underline',
                  mode: PdfAnnotationMode.underline,
                ),
                const SizedBox(width: 4),
                _toolBtn(
                  icon: Icons.format_strikethrough,
                  label: 'Strike',
                  mode: PdfAnnotationMode.strikethrough,
                ),
                const SizedBox(width: 4),
                _toolBtn(
                  icon: Icons.waves,
                  label: 'Squiggly',
                  mode: PdfAnnotationMode.squiggly,
                ),
                const SizedBox(width: 8),
                // ── Eraser ─────────────────────────────────────────────
                _eraserBtn(),
                const SizedBox(width: 4),
                // ── Undo ──────────────────────────────────────────────
                _iconActionBtn(
                  icon: Icons.undo,
                  label: 'Undo',
                  onTap: () {
                    _snack(
                        'Undo feature requires selecting an annotation first.');
                  },
                ),
                const SizedBox(width: 4),
                // ── Clear All ─────────────────────────────────────────
                _iconActionBtn(
                  icon: Icons.clear_all,
                  label: 'Clear All',
                  onTap: () async {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Clear all annotations?'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('Clear',
                                  style: TextStyle(color: Colors.red))),
                        ],
                      ),
                    );
                    if (ok == true) {
                      _snack(
                          'Clear all annotations feature not available in this version.');
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String label,
    required PdfAnnotationMode mode,
  }) {
    final isActive = _activeMode == mode;
    final theme = Theme.of(context);
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _setMode(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? theme.colorScheme.primary.withOpacity(0.25)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive ? theme.colorScheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 22, color: isActive ? theme.colorScheme.primary : null),
              const SizedBox(height: 2),
              Text(label,
                  style: TextStyle(
                      fontSize: 9,
                      color: isActive ? theme.colorScheme.primary : null,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _eraserBtn() {
    return Tooltip(
      message: 'Eraser (select & delete)',
      child: GestureDetector(
        onTap: () {
          // Switch to selection mode — user taps an annotation then deletes it
          setState(() {
            _activeMode = PdfAnnotationMode.none;
            _controller.annotationMode = PdfAnnotationMode.none;
          });
          _snack(
              'Tap an annotation to select it, then press Delete to remove.');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_fix_off, size: 22),
              SizedBox(height: 2),
              Text('Eraser', style: TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconActionBtn({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22),
              const SizedBox(height: 2),
              Text(label, style: const TextStyle(fontSize: 9)),
            ],
          ),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  PDF / IMAGE VIEWERS
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildPdfViewer() {
    if (widget.pdfData.isWeb) return _buildWebPdfViewer();
    return _buildNativePdfViewer();
  }

  Widget _buildNativePdfViewer() {
    return SfPdfViewer.file(
      uio.File(widget.pdfData.path!),
      key: _pdfViewerKey,
      controller: _controller,
      onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
      onDocumentLoaded: (d) => setState(() {
        _currentPage = 1;
        _totalPages = d.document.pages.count;
      }),
      // Allow annotation selection so user can delete by tapping
      onAnnotationSelected: (annotation) {
        // When eraser mode: immediately remove selected annotation
        if (_activeMode == PdfAnnotationMode.none) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Delete annotation?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: () {
                    _controller.removeAnnotation(annotation);
                    Navigator.pop(context);
                  },
                  child:
                      const Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        }
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
      key: _pdfViewerKey,
      controller: _controller,
      onPageChanged: (d) => setState(() => _currentPage = d.newPageNumber),
      onDocumentLoaded: (d) => setState(() {
        _currentPage = 1;
        _totalPages = d.document.pages.count;
      }),
    );
  }

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
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('Could not load image.')),
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════
  //  BOTTOM NAV
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
              icon: const Icon(Icons.first_page),
              tooltip: 'First Page',
              onPressed: () => _controller.jumpToPage(1)),
          IconButton(
              icon: const Icon(Icons.navigate_before),
              tooltip: 'Previous',
              onPressed: () {
                if (_currentPage > 1) {
                  _controller.jumpToPage(_currentPage - 1);
                }
              }),
          IconButton(
              icon: const Icon(Icons.navigate_next),
              tooltip: 'Next',
              onPressed: () {
                if (_currentPage < _totalPages) {
                  _controller.jumpToPage(_currentPage + 1);
                }
              }),
          IconButton(
              icon: const Icon(Icons.last_page),
              tooltip: 'Last Page',
              onPressed: () => _controller.jumpToPage(_totalPages)),
        ],
      ),
    );
  }
}
