import 'package:flutter/material.dart';

// 1. Light Theme ko define karein taaki main.dart ise use kar sake
final ThemeData lightAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorSchemeSeed: Colors.deepPurple,
);

// 2. Dark Theme ko define karein
final ThemeData darkAppTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorSchemeSeed: Colors.deepPurple,
);
