import 'package:flutter/material.dart';

class ReJoyTheme {
  static ThemeData get theme {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF5A8DEE),
      brightness: Brightness.dark,
      background: const Color(0xFF0B1220),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF07101C),
      cardTheme: CardThemeData(
        color: const Color(0xFF101B2D),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: const Color(0xFF0B1626),
        indicatorColor: const Color(0xFF213E6B),
      ),
    );
  }
}
