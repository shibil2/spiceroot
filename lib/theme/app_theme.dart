import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primaryColor = Color(0xFF1D9E75);
  static const Color backgroundColor = Color(0xFFF4F9F7);
  static const Color cardColor = Colors.white;
  static const Color priceUpColor = Color(0xFF22C55E);
  static const Color priceDownColor = Color(0xFFEF4444);
  static const Color stableColor = Color(0xFF888780);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        surface: backgroundColor,
      ),
      scaffoldBackgroundColor: backgroundColor,
      cardColor: cardColor,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
    );
  }
}
