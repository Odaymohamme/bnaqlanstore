import 'package:flutter/material.dart';

class GoogleFonts {
  // TextStyle
  static TextStyle cairo({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    double? height,
  }) {
    return TextStyle(
      fontFamily: 'Cairo',
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
    );
  }

  // TextTheme ✅ (هذا المهم)
  static TextTheme cairoTextTheme([TextTheme? base]) {
    final textTheme = base ?? ThemeData.light().textTheme;

    return textTheme.copyWith(
      displayLarge: textTheme.displayLarge?.copyWith(fontFamily: 'Cairo'),
      displayMedium: textTheme.displayMedium?.copyWith(fontFamily: 'Cairo'),
      displaySmall: textTheme.displaySmall?.copyWith(fontFamily: 'Cairo'),

      headlineLarge: textTheme.headlineLarge?.copyWith(fontFamily: 'Cairo'),
      headlineMedium: textTheme.headlineMedium?.copyWith(fontFamily: 'Cairo'),
      headlineSmall: textTheme.headlineSmall?.copyWith(fontFamily: 'Cairo'),

      titleLarge: textTheme.titleLarge?.copyWith(fontFamily: 'Cairo'),
      titleMedium: textTheme.titleMedium?.copyWith(fontFamily: 'Cairo'),
      titleSmall: textTheme.titleSmall?.copyWith(fontFamily: 'Cairo'),

      bodyLarge: textTheme.bodyLarge?.copyWith(fontFamily: 'Cairo'),
      bodyMedium: textTheme.bodyMedium?.copyWith(fontFamily: 'Cairo'),
      bodySmall: textTheme.bodySmall?.copyWith(fontFamily: 'Cairo'),

      labelLarge: textTheme.labelLarge?.copyWith(fontFamily: 'Cairo'),
      labelMedium: textTheme.labelMedium?.copyWith(fontFamily: 'Cairo'),
      labelSmall: textTheme.labelSmall?.copyWith(fontFamily: 'Cairo'),
    );
  }
}
