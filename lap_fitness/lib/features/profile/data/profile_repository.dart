import '../../../core/firebase/database_refs.dart';
import '../domain/user_profile.dart';

/// Owns reads/writes for the user profile at `/users/{uid}`.
class ProfileRepository {
  ProfileRepository(this._refs);

  final DatabaseRefs _refs;

  /// Live profile updates for [uid].
  Stream<UserProfile> watchProfile(String uid) {
    return _refs
        .user(uid)
        .onValue
        .map((event) => UserProfile.fromMap(event.snapshot.value as Map?));
  }

  /// One-shot profile read for [uid].
  Future<UserProfile> getProfile(String uid) async {
    final snapshot = await _refs.user(uid).get();
    return UserProfile.fromMap(snapshot.value as Map?);
  }

  /// Saves the onboarding fields without touching `privateMode`.
  Future<void> saveProfile(String uid, UserProfile profile) {
    return _refs.user(uid).update(profile.toMap());
  }

  Future<void> setPrivateMode(String uid, bool value) {
    return _refs.user(uid).update({'privateMode': value});
  }
}
