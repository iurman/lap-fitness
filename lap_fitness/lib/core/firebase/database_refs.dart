import 'package:firebase_database/firebase_database.dart';

/// Central access point for Realtime Database references so feature
/// repositories don't each reach for `FirebaseDatabase.instance` directly.
class DatabaseRefs {
  DatabaseRefs(this._db);

  final FirebaseDatabase _db;

  DatabaseReference get root => _db.ref();

  DatabaseReference user(String uid) => root.child('users').child(uid);

  DatabaseReference notes(String uid) => user(uid).child('notes');

  DatabaseReference feed() => root.child('feedData');

  DatabaseReference meals(String uid) => root.child('meals').child(uid);

  /// Global water intake node, shared across all users. This is a known bug
  /// (see the modernization plan) fixed in a later phase by scoping it per-user.
  DatabaseReference waterIntake() => root.child('waterIntake');
}
