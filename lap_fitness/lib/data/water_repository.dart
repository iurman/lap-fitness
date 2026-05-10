import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class WaterRepository {
  WaterRepository({FirebaseDatabase? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  DatabaseReference _userWaterRef() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('WaterRepository called without a signed-in user');
    }
    return _db.ref().child('waterIntake').child(user.uid);
  }

  Future<int> fetchIntake() async {
    final snap = await _userWaterRef().once();
    final value = snap.snapshot.value;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Future<void> setIntake(int value) => _userWaterRef().set(value);
}
