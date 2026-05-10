import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class UserProfile {
  final String? age;
  final String? gender;
  final String? weight;
  final String? heightFeet;
  final String? heightInches;
  final String? calories;
  final bool privateMode;

  const UserProfile({
    this.age,
    this.gender,
    this.weight,
    this.heightFeet,
    this.heightInches,
    this.calories,
    this.privateMode = false,
  });

  factory UserProfile.fromMap(Map<dynamic, dynamic>? map) {
    if (map == null) return const UserProfile();
    return UserProfile(
      age: map['age'] as String?,
      gender: map['gender'] as String?,
      weight: map['weight'] as String?,
      heightFeet: map['heightFeet'] as String?,
      heightInches: map['heightInches'] as String?,
      calories: map['calories'] as String?,
      privateMode: (map['privateMode'] as bool?) ?? false,
    );
  }

  bool get hasRequiredInfo =>
      age != null &&
      gender != null &&
      weight != null &&
      // height historically stored either as a single 'height' key or split feet/inches
      (heightFeet != null) &&
      calories != null;
}

class UserRepository {
  UserRepository({FirebaseDatabase? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('UserRepository called without a signed-in user');
    }
    return user.uid;
  }

  DatabaseReference _userRef(String uid) =>
      _db.ref().child('users').child(uid);

  DatabaseReference currentUserRef() => _userRef(_uid);

  Future<UserProfile> fetchProfile() async {
    final snap = await currentUserRef().once();
    return UserProfile.fromMap(snap.snapshot.value as Map<dynamic, dynamic>?);
  }

  Future<UserProfile> fetchProfileFor(String uid) async {
    final snap = await _userRef(uid).once();
    return UserProfile.fromMap(snap.snapshot.value as Map<dynamic, dynamic>?);
  }

  Future<void> updateProfile({
    required String age,
    required String? gender,
    required String weight,
    required String heightFeet,
    required String heightInches,
    required String calories,
  }) {
    return currentUserRef().update({
      'age': age,
      'gender': gender,
      'weight': weight,
      'heightFeet': heightFeet,
      'heightInches': heightInches,
      'calories': calories,
    });
  }

  Future<void> setPrivateMode(String uid, bool value) {
    return _userRef(uid).update({'privateMode': value});
  }
}
