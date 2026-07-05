// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/features/profile/domain/user_profile.dart';

void main() {
  group('UserProfile', () {
    test('fromMap reads all fields', () {
      final profile = UserProfile.fromMap({
        'age': '30',
        'gender': 'Male',
        'weight': '180',
        'heightFeet': '5',
        'heightInches': '11',
        'calories': '2200',
        'privateMode': true,
      });

      expect(profile.age, '30');
      expect(profile.gender, 'Male');
      expect(profile.weight, '180');
      expect(profile.heightFeet, '5');
      expect(profile.heightInches, '11');
      expect(profile.calories, '2200');
      expect(profile.privateMode, isTrue);
    });

    test('fromMap tolerates null map and missing keys', () {
      expect(UserProfile.fromMap(null), const UserProfile());

      final partial = UserProfile.fromMap({'age': '25'});
      expect(partial.age, '25');
      expect(partial.gender, '');
      expect(partial.privateMode, isFalse);
    });

    test('toMap round-trips the onboarding fields', () {
      const profile = UserProfile(
        age: '40',
        gender: 'Female',
        weight: '150',
        heightFeet: '5',
        heightInches: '6',
        calories: '1900',
      );
      final restored = UserProfile.fromMap(profile.toMap());
      expect(restored, profile);
    });

    test('toMap omits privateMode so it is not clobbered on save', () {
      const profile = UserProfile(privateMode: true);
      expect(profile.toMap().containsKey('privateMode'), isFalse);
    });

    test('isComplete requires the core fields', () {
      expect(const UserProfile().isComplete, isFalse);
      expect(
        const UserProfile(age: '30', gender: 'Male', weight: '180').isComplete,
        isFalse,
      );
      expect(
        const UserProfile(
                age: '30', gender: 'Male', weight: '180', calories: '2000')
            .isComplete,
        isTrue,
      );
    });

    test('copyWith overrides only the given field', () {
      const profile = UserProfile(age: '30', gender: 'Male');
      final updated = profile.copyWith(age: '31');
      expect(updated.age, '31');
      expect(updated.gender, 'Male');
    });

    test('equality and hashCode are value-based', () {
      const a = UserProfile(age: '30', gender: 'Male');
      const b = UserProfile(age: '30', gender: 'Male');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
