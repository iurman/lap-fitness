import 'package:firebase_database/firebase_database.dart';

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

  /// Atomically adjusts the intake by [delta] (clamped at zero) using a
  /// transaction, so rapid taps compose server-side instead of racing a stale
  /// local counter — the previous `set(localValue)` approach dropped
  /// increments when the read stream echoed an older value between taps.
  Future<void> adjust(String uid, int delta) async {
    await _refs.waterIntake(uid).runTransaction((current) {
      final value = current is int
          ? current
          : int.tryParse(current?.toString() ?? '') ?? 0;
      final next = value + delta;
      return Transaction.success(next < 0 ? 0 : next);
    });
  }
}
