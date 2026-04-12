import 'dart:io';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../models/pdf_file_data.dart';
import '../services/pdf_service.dart';

/// A reusable card widget for displaying a recent PDF/scanned file.
/// Shows file name, path, and provides Open + Delete actions.
class RecentsFileCard extends StatelessWidget {
  final PdfFileData file;
  final VoidCallback onDeleted; // called after delete so parent refreshes
  final VoidCallback? onRenamed; // optional callback for rename

  const RecentsFileCard({
    super.key,
    required this.file,
    required this.onDeleted,
    this.onRenamed,
  });

  Future<void> _open(BuildContext context) async {
    if (file.isWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Open not supported on web yet.')),
      );
      return;
    }
    if (file.path == null || !File(file.path!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found on device.')),
      );
      return;
    }
    final result = await OpenFilex.open(file.path!);
    if (result.type != ResultType.done && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open: ${result.message}')),
      );
    }
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
      // Delete physical file from disk (if native)
      if (!file.isWeb && file.path != null) {
        final f = File(file.path!);
        if (f.existsSync()) await f.delete();
      }
      await PdfService.deleteRecent(file);
      onDeleted(); // notify parent to refresh
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
      if (onRenamed != null) {
        onRenamed!();
      } else {
        onDeleted(); // Default fallback to refresh list
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPdf = file.name.toLowerCase().endsWith('.pdf');
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      child: ListTile(
        leading: Icon(
          isPdf ? Icons.picture_as_pdf : Icons.image,
          color: isPdf ? Colors.red : Colors.blueAccent,
          size: 36,
        ),
        title: Text(file.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          file.isWeb ? 'Web file' : (file.path ?? ''),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11),
        ),
        onTap: () => _open(context),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'open') _open(context);
            if (action == 'delete') _delete(context);
            if (action == 'rename') _rename(context);
          },
          itemBuilder: (_) => const [
            PopupMenuItem(
                value: 'open',
                child: ListTile(
                    leading: Icon(Icons.open_in_new), title: Text('Open'))),
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
