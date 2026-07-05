import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/database_refs.dart';
import '../domain/meal.dart';

/// Owns reads/writes for a user's meal journal at `/meals/{uid}`.
class MealsRepository {
  MealsRepository(this._refs);

  final DatabaseRefs _refs;

  DatabaseReference _meals(String uid) => _refs.meals(uid);

  /// Live meal journal for [uid].
  Stream<List<Meal>> watchMeals(String uid) {
    return _meals(uid).onValue.map((event) {
      final value = event.snapshot.value as Map?;
      if (value == null) return <Meal>[];
      return value.entries
          .map((e) => Meal.fromMap(e.key.toString(), e.value as Map))
          .toList();
    });
  }

  Future<void> addMeal(String uid, Meal meal) =>
      _meals(uid).push().set(meal.toMap());

  Future<void> deleteMeal(String uid, String key) =>
      _meals(uid).child(key).remove();
}
