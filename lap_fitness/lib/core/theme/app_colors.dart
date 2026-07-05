import 'package:flutter/material.dart';

/// Brand color tokens. The seed color drives the Material 3 [ColorScheme];
/// these named constants exist for the handful of spots that still reference
/// exact brand values directly.
abstract final class AppColors {
  /// The LAP Fitness brand brown (formerly Color.fromARGB(255, 138, 104, 35)).
  static const brand = Color(0xFF8A6823);

  /// Muted card/surface fill used on the home dashboard.
  static const surfaceMuted = Color(0xFFF6F6F6);
}
