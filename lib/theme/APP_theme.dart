// Renamed from APP_theme.dart to app_theme.dart for snake_case convention
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextTheme _buildTextTheme() {
  return TextTheme(
    displayLarge: const TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
    titleLarge: GoogleFonts.oswald(fontSize: 30, fontStyle: FontStyle.italic),
    bodyMedium: GoogleFonts.merriweather(),
    displaySmall: GoogleFonts.pacifico(),
  );
}

ThemeData get lightAppTheme {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.light,
    ),
    textTheme: _buildTextTheme(),
  );
}

ThemeData get darkAppTheme {
  return ThemeData(
    useMaterial3: true,
    // Define the default brightness and colors.
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.purple,
      brightness: Brightness.dark,
    ),
    textTheme: _buildTextTheme(),
  );
}
