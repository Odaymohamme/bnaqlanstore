import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryRed = Color(0xFFE53935);
  static const Color darkRed = Color(0xFFB71C1C);
  static const Color beige = Color(0xFFFBE9E7);
  static const Color textDark = Color(0xFF212121);
  static const Color textMedium = Color(0xFF757575);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primaryRed,
      scaffoldBackgroundColor: beige,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkRed,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(
          fontFamily: 'Cairo',
          color: textDark,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Cairo',
          color: textMedium,
        ),
        titleLarge: TextStyle(
          fontFamily: 'Cairo',
          color: textDark,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Cairo',
          color: textDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryRed,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Cairo',
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: textMedium,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Cairo',
          color: textDark,
        ),
      ),
    );
  }
}
