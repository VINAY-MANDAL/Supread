import 'dart:math';
import 'dart:convert';

class PdfFileData {
  final String name;
  final String? path; // For native platforms
  final List<int>? bytes; // For web platform
  final bool isWeb;

  PdfFileData({
    required this.name,
    this.path,
    this.bytes,
    required this.isWeb,
  });

  // Get file identifier for recent files list
  String get identifier {
    if (isWeb && bytes != null) {
      return base64Encode(bytes!.sublist(0, min(100, bytes!.length)));
    }
    return path ?? name;
  }
}