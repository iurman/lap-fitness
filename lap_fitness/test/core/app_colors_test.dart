import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/core/theme/app_colors.dart';

void main() {
  test('brand color is the LAP Fitness brown', () {
    expect(AppColors.brand, const Color(0xFF8A6823));
  });

  test('surfaceMuted is the light card fill', () {
    expect(AppColors.surfaceMuted, const Color(0xFFF6F6F6));
  });
}
