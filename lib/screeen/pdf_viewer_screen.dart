import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:universal_io/io.dart' as uio;
import '../models/pdf_file_data.dart';
import '../services/pdf_service.dart';

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

  // Zoom level
  double _zoomLevel = 1.0;
  static const double _minZoom = 0.5;
  static const double _maxZoom = 5.0;
  static const double _zoomStep = 0.25;

  bool get _isImage {
    final n = widget.pdfData.name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
  }

  @override
  void initState() {
    super.initState();
    // File khulte hi lastViewed update karo — isse recent list mein yahi file
    // upar aa jaayegi
    PdfService.touchRecent(widget.pdfData);
  }

  // ── Annotation mode toggle ───────────────────────────────────────────────
  void _setMode(PdfAnnotationMode mode) {
    final next = (_activeMode == mode) ? PdfAnnotationMode.none : mode;
    setState(() => _activeMode = next);
    _controller.annotationMode = next;
  }

  // Zoom in
  void _zoomIn() {
    final newZoom = (_zoomLevel + _zoomStep).clamp(_minZoom, _maxZoom);
    setState(() => _zoomLevel = newZoom);
    _controller.zoomLevel = newZoom;
  }

  // Zoom out
  void _zoomOut() {
    final newZoom = (_zoomLevel - _zoomStep).clamp(_minZoom, _maxZoom);
    setState(() => _zoomLevel = newZoom);
    _controller.zoomLevel = newZoom;
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
                tooltip: 'Zoom In',
                onPressed: _zoomLevel < _maxZoom ? _zoomIn : null),
          if (!_isImage)
            IconButton(
                icon: const Icon(Icons.zoom_out),
                tooltip: 'Zoom Out',
                onPressed: _zoomLevel > _minZoom ? _zoomOut : null),
        ],
      ),
      body: Column(
        children: [
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
                _eraserBtn(),
                const SizedBox(width: 4),
                _iconActionBtn(
                  icon: Icons.undo,
                  label: 'Undo',
                  onTap: () {
                    _snack(
                        'Undo feature requires selecting an annotation first.');
                  },
                ),
                const SizedBox(width: 4),
                _iconActionBtn(
                  icon: Icons.delete_forever,
                  label: 'Clear All',
                  onTap: () {
                    _pdfViewerKey.currentState?.clearSelection();
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
    final theme = Theme.of(context);
    final isActive = _activeMode == mode;
    return Tooltip(
      message: label,
      child: GestureDetector(
        onTap: () => _setMode(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: isActive
              ? BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                )
              : null,
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
      initialZoomLevel: 1.0,
      // ✅ Page change hone par save karo
      onPageChanged: (d) {
        setState(() => _currentPage = d.newPageNumber);
        PdfService.saveLastPage(widget.pdfData, d.newPageNumber);
      },
      // ✅ Document load hone par saved page par jump karo
      onDocumentLoaded: (d) async {
        final total = d.document.pages.count;
        setState(() {
          _totalPages = total;
          _zoomLevel = 1.0;
        });
        // Saved page fetch karo
        final savedPage = await PdfService.getLastPage(widget.pdfData);
        if (savedPage > 1 && savedPage <= total) {
          // Viewer ko render hone ka time do
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _controller.jumpToPage(savedPage);
            setState(() => _currentPage = savedPage);
          }
        } else {
          setState(() => _currentPage = 1);
        }
      },
      onAnnotationSelected: (annotation) {
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
      initialZoomLevel: 1.0,
      onPageChanged: (d) {
        setState(() => _currentPage = d.newPageNumber);
        PdfService.saveLastPage(widget.pdfData, d.newPageNumber);
      },
      onDocumentLoaded: (d) async {
        final total = d.document.pages.count;
        setState(() {
          _totalPages = total;
          _zoomLevel = 1.0;
        });
        final savedPage = await PdfService.getLastPage(widget.pdfData);
        if (savedPage > 1 && savedPage <= total) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (mounted) {
            _controller.jumpToPage(savedPage);
            setState(() => _currentPage = savedPage);
          }
        } else {
          setState(() => _currentPage = 1);
        }
      },
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
  //  BOTTOM NAV — height 40
  // ════════════════════════════════════════════════════════════════════════
  Widget _buildBottomNav() {
    return SizedBox(
      height: 40,
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 4,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _navBtn(
              icon: Icons.first_page,
              tooltip: 'First Page',
              onPressed: () => _controller.jumpToPage(1),
            ),
            _navBtn(
              icon: Icons.navigate_before,
              tooltip: 'Previous',
              onPressed: _currentPage > 1
                  ? () => _controller.jumpToPage(_currentPage - 1)
                  : null,
            ),
            _navBtn(
              icon: Icons.navigate_next,
              tooltip: 'Next',
              onPressed: _currentPage < _totalPages
                  ? () => _controller.jumpToPage(_currentPage + 1)
                  : null,
            ),
            _navBtn(
              icon: Icons.last_page,
              tooltip: 'Last Page',
              onPressed: () => _controller.jumpToPage(_totalPages),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navBtn({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
        onPressed: onPressed,
        color: onPressed != null
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }
}
 