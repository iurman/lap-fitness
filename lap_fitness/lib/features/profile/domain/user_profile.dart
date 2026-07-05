import 'package:flutter/foundation.dart';

/// A user's fitness profile, stored at RTDB `/users/{uid}`.
///
/// Historically every field was persisted as a string (the text-field values
/// from the onboarding form), so we keep them as strings here to stay
/// round-trip compatible with existing data. `privateMode` is the one boolean.
@immutable
class UserProfile {
  const UserProfile({
    this.age = '',
    this.gender = '',
    this.weight = '',
    this.heightFeet = '',
    this.heightInches = '',
    this.calories = '',
    this.privateMode = false,
  });

  final String age;
  final String gender;
  final String weight;
  final String heightFeet;
  final String heightInches;
  final String calories;
  final bool privateMode;

  /// True once the user has filled in the core onboarding fields.
  bool get isComplete =>
      age.isNotEmpty &&
      gender.isNotEmpty &&
      weight.isNotEmpty &&
      calories.isNotEmpty;

  factory UserProfile.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const UserProfile();
    return UserProfile(
      age: (map['age'] ?? '').toString(),
      gender: (map['gender'] ?? '').toString(),
      weight: (map['weight'] ?? '').toString(),
      heightFeet: (map['heightFeet'] ?? '').toString(),
      heightInches: (map['heightInches'] ?? '').toString(),
      calories: (map['calories'] ?? '').toString(),
      privateMode: map['privateMode'] == true,
    );
  }

  /// Only the onboarding fields; `privateMode` is written separately by the
  /// privacy screen so it is not clobbered here.
  Map<String, dynamic> toMap() => {
        'age': age,
        'gender': gender,
        'weight': weight,
        'heightFeet': heightFeet,
        'heightInches': heightInches,
        'calories': calories,
      };

  UserProfile copyWith({
    String? age,
    String? gender,
    String? weight,
    String? heightFeet,
    String? heightInches,
    String? calories,
    bool? privateMode,
  }) {
    return UserProfile(
      age: age ?? this.age,
      gender: gender ?? this.gender,
      weight: weight ?? this.weight,
      heightFeet: heightFeet ?? this.heightFeet,
      heightInches: heightInches ?? this.heightInches,
      calories: calories ?? this.calories,
      privateMode: privateMode ?? this.privateMode,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is UserProfile &&
      other.age == age &&
      other.gender == gender &&
      other.weight == weight &&
      other.heightFeet == heightFeet &&
      other.heightInches == heightInches &&
      other.calories == calories &&
      other.privateMode == privateMode;

  @override
  int get hashCode => Object.hash(
      age, gender, weight, heightFeet, heightInches, calories, privateMode);
}
