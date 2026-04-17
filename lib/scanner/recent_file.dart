import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/pdf_file_data.dart';
import '../services/pdf_service.dart';

/// Reusable card for recent PDF/scanned files.
/// onOpen → in-app viewer ke liye (HomeScreen se pass hota hai)
class RecentsFileCard extends StatelessWidget {
  final PdfFileData file;
  final VoidCallback onDeleted;
  final VoidCallback? onRenamed;
  final void Function(PdfFileData)? onOpen; // ✅ NEW: in-app open callback

  const RecentsFileCard({
    super.key,
    required this.file,
    required this.onDeleted,
    this.onRenamed,
    this.onOpen,
  });

  // ✅ In-app open (PDF viewer ya image viewer)
  void _open(BuildContext context) {
    if (file.path == null || !File(file.path!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device.')),
      );
      return;
    }
    if (onOpen != null) {
      onOpen!(file);
    }
  }

  Future<void> _share(BuildContext context) async {
    if (file.path == null || !File(file.path!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found.')),
      );
      return;
    }
    await Share.shareXFiles(
      [XFile(file.path!)],
      text: 'Document: ${file.name}',
    );
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove from recents?'),
        content: Text('"${file.name}"'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      if (!file.isWeb && file.path != null) {
        final f = File(file.path!);
        if (f.existsSync()) await f.delete();
      }
      await PdfService.deleteRecent(file);
      onDeleted();
    }
  }

  Future<void> _rename(BuildContext context) async {
    final controller = TextEditingController(text: file.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'New name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Rename')),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != file.name) {
      await PdfService.renameRecent(file, newName);
      (onRenamed ?? onDeleted)();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    final isImage = file.name.toLowerCase().endsWith('.jpg') ||
        file.name.toLowerCase().endsWith('.jpeg') ||
        file.name.toLowerCase().endsWith('.png');

    // ✅ Image thumbnail (agar local file exist kare)
    Widget leadingWidget;
    if (isImage && file.path != null && File(file.path!).existsSync()) {
      leadingWidget = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          File(file.path!),
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.image, color: Colors.blueAccent, size: 36),
        ),
      );
    } else {
      leadingWidget = Icon(
        isPdf ? Icons.picture_as_pdf : Icons.image,
        color: isPdf ? Colors.red : Colors.blueAccent,
        size: 36,
      );
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: leadingWidget,
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          file.isWeb ? 'Web file' : (file.path ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: () => _open(context), // ✅ In-app open
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'open') _open(context);
            if (action == 'share') _share(context);
            if (action == 'delete') _delete(context);
            if (action == 'rename') _rename(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'open',
                child: ListTile(
                    leading: Icon(Icons.open_in_new), title: Text('Open'))),
            PopupMenuItem(
                value: 'share',
                child: ListTile(
                    leading: Icon(Icons.share, color: Colors.blue),
                    title: Text('Share'))),
            PopupMenuItem(
                value: 'rename',
                child:
                    ListTile(leading: Icon(Icons.edit), title: Text('Rename'))),
            PopupMenuItem(
                value: 'delete',
                child: ListTile(
                    leading: Icon(Icons.delete, color: Colors.red),
                    title:
                        Text('Remove', style: TextStyle(color: Colors.red)))),
          ],
        ),
      ),
    );
  }
}
