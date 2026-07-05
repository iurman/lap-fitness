// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/features/meals/domain/meal.dart';

void main() {
  group('Meal', () {
    test('fromMap coerces numeric strings to doubles', () {
      final meal = Meal.fromMap('m1', {
        'name': 'Chicken',
        'protein': '30',
        'fat': 5,
        'carbs': 0,
      });
      expect(meal.key, 'm1');
      expect(meal.name, 'Chicken');
      expect(meal.protein, 30);
      expect(meal.fat, 5);
      expect(meal.carbs, 0);
    });

    test('calories = 4*protein + 9*fat + 4*carbs', () {
      const meal = Meal(key: 'm', protein: 30, fat: 10, carbs: 40);
      // 4*30 + 9*10 + 4*40 = 120 + 90 + 160 = 370
      expect(meal.calories, 370);
    });

    test('toMap omits the key and round-trips', () {
      const meal = Meal(key: 'm2', name: 'Rice', protein: 4, fat: 1, carbs: 45);
      final map = meal.toMap();
      expect(map.containsKey('key'), isFalse);
      expect(Meal.fromMap('m2', map), meal);
    });

    test('missing macros default to zero', () {
      final meal = Meal.fromMap('m3', {'name': 'Water'});
      expect(meal.protein, 0);
      expect(meal.fat, 0);
      expect(meal.carbs, 0);
      expect(meal.calories, 0);
    });
  });
}
