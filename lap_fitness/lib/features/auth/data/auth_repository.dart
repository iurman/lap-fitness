import 'package:firebase_auth/firebase_auth.dart';

/// Wraps Firebase Auth so widgets don't call `FirebaseAuth.instance` directly.
class AuthRepository {
  AuthRepository(this._auth);

  final FirebaseAuth _auth;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  String? get currentUid => _auth.currentUser?.uid;

  String get currentEmail => _auth.currentUser?.email ?? '';

  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> register(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> updatePassword(String password) =>
      _auth.currentUser!.updatePassword(password);

  /// firebase_auth 6 removed the direct `updateEmail`; the address only
  /// changes once the user confirms via the verification link.
  Future<void> verifyBeforeUpdateEmail(String email) =>
      _auth.currentUser!.verifyBeforeUpdateEmail(email);

  Future<void> deleteAccount() => _auth.currentUser!.delete();
}
