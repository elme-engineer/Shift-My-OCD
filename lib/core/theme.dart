import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color.fromARGB(0, 77, 138, 196);     // teal-500
  static const anxietyHigh = Color(0xFFEF4444); // red-500
  static const anxietyLow = Color(0xFF22C55E);  // green-500
  static const surface = Color(0xFFF8FAFC);
  static const textPrimary = Color(0xFF0F172A);
}

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.surface,
  );
}