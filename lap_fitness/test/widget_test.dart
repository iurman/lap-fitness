import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lap_fitness/core/theme/app_colors.dart';
import 'package:lap_fitness/core/theme/app_theme.dart';
import 'package:lap_fitness/core/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton renders its label and is tappable',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: PrimaryButton(
              label: 'Sign In',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Sign In'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('PrimaryButton swaps label for spinner when isLoading',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: Center(
            child: PrimaryButton(
              label: 'Sign In',
              onPressed: null,
              isLoading: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sign In'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  test('AppColors brand value is the lap-fitness brown', () {
    expect(AppColors.brand, const Color(0xFF8A6823));
  });
}
