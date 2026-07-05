import '../../../core/firebase/database_refs.dart';

/// Owns reads/writes for a user's water intake counter at
/// `/users/{uid}/waterIntake`.
class WaterRepository {
  WaterRepository(this._refs);

  final DatabaseRefs _refs;

  /// Live water intake count (cups) for [uid].
  Stream<int> watchIntake(String uid) {
    return _refs.waterIntake(uid).onValue.map((event) {
      final value = event.snapshot.value;
      return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
    });
  }

  Future<void> setIntake(String uid, int cups) =>
      _refs.waterIntake(uid).set(cups);
}
