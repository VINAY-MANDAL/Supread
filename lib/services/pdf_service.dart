import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/pdf_file_data.dart';

class PdfService {
  static const _recentKey = 'recent_pdfs';

  // Pick a PDF file from device
  static Future<PdfFileData?> pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: kIsWeb, // For web, get file data
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;

        if (kIsWeb) {
          // Web platform - use bytes
          if (file.bytes != null) {
            final fileName = file.name;
            await _saveRecentWeb(fileName, file.bytes!);
            return PdfFileData(
              name: fileName,
              bytes: file.bytes,
              isWeb: true,
            );
          }
        } else {
          // Native platforms - use file path
          if (file.path != null) {
            final path = file.path!;
            final fileName = file.name;
            await _saveRecent(path, fileName);
            return PdfFileData(
              name: fileName,
              path: path,
              isWeb: false,
            );
          }
        }
      }
    } catch (e) {
      developer.log('Error picking PDF: $e');
    }
    return null;
  }

  // Save recent list for native platforms
  static Future<void> _saveRecent(String path, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    List<Map<String, String>> list = [];
    if (raw != null) {
      list = List<Map<String, String>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, String>.from(e)),
      );
    }

    list.removeWhere((e) => e['path'] == path); // avoid duplicates
    list.insert(0, {'path': path, 'name': name, 'platform': 'native'});
    if (list.length > 10) list = list.sublist(0, 10); // keep only 10 recent
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // Save recent list for web platform
  static Future<void> _saveRecentWeb(String name, List<int> bytes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recentKey);
    List<Map<String, dynamic>> list = [];
    if (raw != null) {
      list = List<Map<String, dynamic>>.from(
        (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e)),
      );
    }

    // For web, store a hash of the file content as identifier
    final fileId = base64Encode(bytes.sublist(0, min(100, bytes.length)));
    list.removeWhere((e) => e['id'] == fileId); // avoid duplicates
    list.insert(0, {
      'id': fileId,
      'name': name,
      'bytes': base64Encode(bytes),
      'platform': 'web'
    });
    if (list.length > 10) list = list.sublist(0, 10); // keep only 10 recent
    await prefs.setString(_recentKey, jsonEncode(list));
  }

  // Load recent PDFs
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
   // Clear all recent files
    static Future<void> clearRecent() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentKey);
  }
}
