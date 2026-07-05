import 'package:firebase_database/firebase_database.dart';

import '../../../core/firebase/database_refs.dart';
import '../domain/note.dart';

/// Owns reads/writes for a user's notes at `/users/{uid}/notes`.
class NotesRepository {
  NotesRepository(this._refs);

  final DatabaseRefs _refs;

  /// Live notes for [uid]. When [day] is provided, only notes whose
  /// `selected_date` falls on that day are returned.
  Stream<List<Note>> watchNotes(String uid, {DateTime? day}) {
    Query query = _refs.notes(uid);
    if (day != null) {
      query = query
          .orderByChild('selected_date')
          .startAt(day.toIso8601String())
          .endAt(day.add(const Duration(days: 1)).toIso8601String());
    }
    return query.onValue.map((event) {
      final value = event.snapshot.value as Map?;
      if (value == null) return <Note>[];
      return value.entries
          .map((e) => Note.fromMap(e.key.toString(), e.value as Map))
          .toList();
    });
  }

  Future<void> addNote({required String uid, DateTime? day}) {
    final note = Note(
      key: '',
      createdAt: DateTime.now(),
      selectedDate: day,
    );
    return _refs.notes(uid).push().set(note.toMap());
  }

  Future<void> updateName(String uid, String key, String name) =>
      _refs.notes(uid).child(key).update({'name': name});

  Future<void> updateContent(String uid, String key, String content) =>
      _refs.notes(uid).child(key).update({'content': content});

  Future<void> deleteNote(String uid, String key) =>
      _refs.notes(uid).child(key).remove();
}
