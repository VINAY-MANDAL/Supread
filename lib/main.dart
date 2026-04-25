import 'package:flutter/material.dart';
import 'screeen/home_screeen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

// Global notifier jo theme mode (system, light, dark) ko control karega
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Adhyay PDF Reader',
          theme: lightAppTheme,
          darkTheme: darkAppTheme,
          themeMode: currentMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
