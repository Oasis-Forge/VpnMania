import 'package:flutter/material.dart';

class AppTheme {
  static const Color accent = Color(0xFF5865F2); // Discord blurple
  static const Color surface = Color(0xFF1E1F22);
  static const Color background = Color(0xFF111214);
  static const Color card = Color(0xFF2B2D31);
  static const Color onSurface = Color(0xFFF2F3F5);
  static const Color muted = Color(0xFFB5BAC1);
  static const Color success = Color(0xFF23A559);
  static const Color danger = Color(0xFFDA373C);

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
        primary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'Segoe UI',
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(220, 56),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          minimumSize: const Size(220, 56),
          side: const BorderSide(color: Color(0xFF4E5058)),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
