import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/core/providers.dart';
import 'package:lap_fitness/features/meals/domain/meal.dart';
import 'package:lap_fitness/features/meals/presentation/meal_tracking_page.dart';

import '../../support/fakes.dart';

void main() {
  testWidgets('shows meals from the repository and their macro totals',
      (tester) async {
    final meals = [
      const Meal(key: 'm1', name: 'Chicken', protein: 30, fat: 5, carbs: 0),
      const Meal(key: 'm2', name: 'Rice', protein: 4, fat: 1, carbs: 45),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          mealsRepositoryProvider.overrideWithValue(FakeMealsRepository(meals)),
        ],
        child: MaterialApp(home: MealTrackingPage()),
      ),
    );
    await tester.pump(); // let the meals stream emit

    expect(find.text('Chicken'), findsOneWidget);
    expect(find.text('Rice'), findsOneWidget);

    // Totals: protein 34, fat 6, carbs 45; calories = 4*34 + 9*6 + 4*45 = 370.
    expect(
      find.textContaining('Total Calories: 370.00 cal'),
      findsOneWidget,
    );
  });
}
