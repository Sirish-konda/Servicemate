import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF185C3A);
  static const Color background = Color(0xFFF8FAF8);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.light,
    ),
  );
}
