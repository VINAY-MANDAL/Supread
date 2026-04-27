import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_pdf_annotations/flutter_pdf_annotations.dart';

class PdfAnnotationService {
  /// Basic example of opening a PDF
  static Future<PdfAnnotationResult?> openBasicPdf(String path) async {
    final result = await FlutterPdfAnnotations.openPDF(
      filePath: path,
    );

    if (result == null) {
      debugPrint("Error: No result returned from the PDF engine.");
    } else if (result.isSuccess) {
      debugPrint("PDF processed successfully");
    } else if (result.isCancelled) {
      debugPrint('User cancelled');
    } else {
      debugPrint('Error: ${result.error}');
    }
    return result;
  }

  /// Advanced example with custom config
  static Future<PdfAnnotationResult?> openPdfWithConfig(
          String path, String savePath) =>
      FlutterPdfAnnotations.openPDF(
        filePath: path,
        savePath: savePath,
        config: PDFAnnotationConfig(
          title: 'Review Contract',
          initialPenColor: Colors.red,
          initialHighlightColor: Colors.yellow.withOpacity(0.5),
          initialStrokeWidth: 3.0,
          initialPage: 2,
          locale: PdfLocale.arabic,
        ),
      );

  /// Open from URL
  static Future<PdfAnnotationResult?> openUrl(String url) =>
      FlutterPdfAnnotations.openFromUrl(
        url: url,
        headers: {
          'Authorization': 'Bearer your_token',
        },
        config: PDFAnnotationConfig(title: 'Remote PDF'),
      );

  /// Open from Bytes
  static Future<PdfAnnotationResult?> openBytes(Uint8List bytes) =>
      FlutterPdfAnnotations.openFromBytes(
        bytes: bytes,
        config: PDFAnnotationConfig(title: 'PDF from Bytes'),
      );

  /// Open from Asset
  static Future<PdfAnnotationResult?> openAsset(String assetPath) =>
      FlutterPdfAnnotations.openFromAsset(
        assetPath: assetPath,
      );
}
