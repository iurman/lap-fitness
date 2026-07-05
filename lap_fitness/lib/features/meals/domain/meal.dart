import 'package:flutter/foundation.dart';

/// A logged meal with its macronutrients, stored at RTDB `/meals/{uid}/{key}`.
@immutable
class Meal {
  const Meal({
    required this.key,
    this.name = '',
    this.protein = 0,
    this.fat = 0,
    this.carbs = 0,
  });

  final String key;
  final String name;
  final double protein;
  final double fat;
  final double carbs;

  /// Calories derived from macros: 4 cal/g protein, 9 cal/g fat, 4 cal/g carbs.
  double get calories => 4 * protein + 9 * fat + 4 * carbs;

  factory Meal.fromMap(String key, Map<dynamic, dynamic> map) {
    return Meal(
      key: key,
      name: (map['name'] ?? '').toString(),
      protein: _toDouble(map['protein']),
      fat: _toDouble(map['fat']),
      carbs: _toDouble(map['carbs']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// The RTDB payload for a meal. `key` is excluded because it is the node id.
  Map<String, dynamic> toMap() => {
        'name': name,
        'protein': protein,
        'fat': fat,
        'carbs': carbs,
      };

  Meal copyWith({
    String? key,
    String? name,
    double? protein,
    double? fat,
    double? carbs,
  }) {
    return Meal(
      key: key ?? this.key,
      name: name ?? this.name,
      protein: protein ?? this.protein,
      fat: fat ?? this.fat,
      carbs: carbs ?? this.carbs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Meal &&
      other.key == key &&
      other.name == name &&
      other.protein == protein &&
      other.fat == fat &&
      other.carbs == carbs;

  @override
  int get hashCode => Object.hash(key, name, protein, fat, carbs);
}
