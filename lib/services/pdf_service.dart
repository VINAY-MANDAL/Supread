import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/pdf_file_data.dart';

class PdfService {
  static const _recentKey = 'recent_pdfs';

  // ─── Pick a PDF file from device ──────────────────────────────────────────
  static Future<PdfFileData?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb,
      );
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        if (kIsWeb) {
          if (file.bytes != null) {
            await _saveRecentWeb(file.name, file.bytes!);
            return PdfFileData(name: file.name, bytes: file.bytes, isWeb: true);
          }
        } else {
          if (file.path != null) {
            await _saveRecent(file.path!, file.name);
            return PdfFileData(name: file.name, path: file.path!, isWeb: false);
          }
        }
      }
    } catch (e) {
      developer.log('Error picking PDF: $e');
    }
    return null;
  }

  // ✅ FIXED: Save a scanned file (called from ScannerScreen)
  // Returns PdfFileData so caller can open it directly if needed
  static Future<PdfFileData?> saveScannedFile({
    required String path,
    required String name,
  }) async {
    try {
      await _saveRecent(path, name);
      return PdfFileData(name: name, path: path, isWeb: false);
    } catch (e) {
      developer.log('Error saving scanned file: $e');
      return null;
    }
  }

  // ─── Save recent — native ─────────────────────────────────────────────────
  static Future<void> _saveRecent(String path, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }
    list.removeWhere((e) => e['path'] == path);
    list.insert(0, {'path': path, 'name': name, 'platform': 'native'});
    if (list.length > 20) list = list.sublist(0, 20);
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // ─── Save recent — web ────────────────────────────────────────────────────
  static Future<void> _saveRecentWeb(String name, List<int> bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
          (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)));
    }
    final fileId = base64Encode(bytes.sublist(0, min(100, bytes.length)));
    list.removeWhere((e) => e['id'] == fileId);
    list.insert(0, {
      'id': fileId,
      'name': name,
      'bytes': base64Encode(bytes),
      'platform': 'web',
    });
    if (list.length > 20) list = list.sublist(0, 20);
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // ─── Load recent PDFs ─────────────────────────────────────────────────────
  static Future<List<PdfFileData>> getRecent() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      return list.map((e) {
        final map = Map<String, dynamic>.from(e);
        if (map['platform'] == 'web') {
          return PdfFileData(
            name: map['name'] as String,
            bytes: base64Decode(map['bytes'] as String),
            isWeb: true,
          );
        } else {
          return PdfFileData(
            name: map['name'] as String,
            path: map['path'] as String,
            isWeb: false,
          );
        }
      }).toList();
    }
    return [];
  }

  // ✅ Delete one file from recent list
  static Future<void> deleteRecent(PdfFileData fileToRemove) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (fileToRemove.isWeb) {
      list.removeWhere((e) => e['name'] == fileToRemove.name);
    } else {
      list.removeWhere((e) => e['path'] == fileToRemove.path);
    }
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // ✅ Rename a file in the recent list
  static Future<void> renameRecent(PdfFileData file, String newName) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    if (raw == null) return;
    final list = (jsonDecode(raw) as List)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    for (final item in list) {
      if (file.isWeb && item['name'] == file.name) {
        item['name'] = newName;
        break;
      } else if (!file.isWeb && item['path'] == file.path) {
        item['name'] = newName;
        break;
      }
    }
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // ─── Clear ALL recent files ───────────────────────────────────────────────
  static Future<void> clearRecent() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_recentKey);
  }
}
