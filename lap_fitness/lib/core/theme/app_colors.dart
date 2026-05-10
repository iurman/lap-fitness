import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  /// Brand seed; everything else flows from `ColorScheme.fromSeed(seedColor: brand)`.
  static const Color brand = Color(0xFF8A6823);

  /// Slightly lighter brand for highlights/accents.
  static const Color brandSoft = Color(0xFFB68A3A);

  /// Subtle card surface used throughout the home screen.
  static const Color cardBackground = Color(0xFFF6F6F6);

  /// Page background for auth screens.
  static const Color authBackground = Color(0xFFEAEAEA);
}
