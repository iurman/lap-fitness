import 'package:firebase_database/firebase_database.dart';

class FeedRepository {
  FeedRepository({FirebaseDatabase? db})
      : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  DatabaseReference get _ref => _db.ref().child('feedData');

  Stream<DatabaseEvent> get onChildAdded => _ref.onChildAdded;
  Stream<DatabaseEvent> get onChildRemoved => _ref.onChildRemoved;

  DatabaseReference newPostRef() => _ref.push();

  Future<void> setPost(DatabaseReference ref, Map<String, dynamic> data) =>
      ref.set(data);

  Future<void> deletePost(String key) => _ref.child(key).remove();
}
