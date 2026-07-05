import '../../../core/firebase/database_refs.dart';

/// Owns reads/writes for the water intake counter.
///
/// NOTE: this currently points at the global `/waterIntake` node, so the value
/// is shared across every user. That is a pre-existing bug scoped to be fixed
/// in a later phase; the repository boundary is here so the fix is a one-line
/// change to the ref.
class WaterRepository {
  WaterRepository(this._refs);

  final DatabaseRefs _refs;

  /// Live water intake count (cups).
  Stream<int> watchIntake() {
    return _refs.waterIntake().onValue.map((event) {
      final value = event.snapshot.value;
      return value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
    });
  }

  Future<void> setIntake(int cups) => _refs.waterIntake().set(cups);
}
