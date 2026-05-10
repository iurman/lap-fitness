import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class MealRepository {
  MealRepository({FirebaseDatabase? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  DatabaseReference get ref {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('MealRepository called without a signed-in user');
    }
    return _db.ref().child('meals').child(user.uid);
  }

  Future<void> addMeal(Map<String, dynamic> meal) => ref.push().set(meal);

  Future<void> deleteMeal(String key) => ref.child(key).remove();
}
