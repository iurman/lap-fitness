import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lap_fitness/core/theme/app_colors.dart';
import 'package:lap_fitness/core/widgets/primary_button.dart';

void main() {
  testWidgets('PrimaryButton renders its label and is tappable',
      (WidgetTester tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PrimaryButton(
            label: 'Sign In',
            onPressed: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Sign In'), findsOneWidget);

    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();

    expect(tapped, isTrue);
  });

  test('AppColors brand value is the lap-fitness brown', () {
    expect(AppColors.brand, const Color.fromARGB(255, 138, 104, 35));
  });
}
