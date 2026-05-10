import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NotesRepository {
  NotesRepository({FirebaseDatabase? db, FirebaseAuth? auth})
      : _db = db ?? FirebaseDatabase.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseDatabase _db;
  final FirebaseAuth _auth;

  DatabaseReference _notesRef() {
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('NotesRepository called without a signed-in user');
    }
    return _db.ref().child('users').child(user.uid).child('notes');
  }

  Query buildQuery({DateTime? selectedDate, bool showAll = true}) {
    Query query = _notesRef();
    if (!showAll && selectedDate != null) {
      final start = selectedDate.toIso8601String();
      final end = selectedDate.add(const Duration(days: 1)).toIso8601String();
      query = query.orderByChild('selected_date').startAt(start).endAt(end);
    }
    return query;
  }

  Future<void> addNote(DateTime? selectedDate) {
    return _notesRef().push().set({
      'name': '',
      'content': '',
      'created_at': DateTime.now().toIso8601String(),
      'selected_date': selectedDate?.toIso8601String() ?? '',
    });
  }

  Future<void> updateName(String key, String name) =>
      _notesRef().child(key).update({'name': name});

  Future<void> updateContent(String key, String content) =>
      _notesRef().child(key).update({'content': content});

  Future<void> deleteNote(String key) => _notesRef().child(key).remove();
}
