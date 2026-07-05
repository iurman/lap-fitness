// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/features/notes/domain/note.dart';

void main() {
  group('Note', () {
    test('fromMap parses dates', () {
      final created = DateTime(2026, 7, 5, 9, 30);
      final selected = DateTime(2026, 7, 4);
      final note = Note.fromMap('n1', {
        'name': 'Workout',
        'content': 'Legs day',
        'created_at': created.toIso8601String(),
        'selected_date': selected.toIso8601String(),
      });

      expect(note.key, 'n1');
      expect(note.name, 'Workout');
      expect(note.content, 'Legs day');
      expect(note.createdAt, created);
      expect(note.selectedDate, selected);
    });

    test('fromMap treats empty/missing dates as null', () {
      final note = Note.fromMap('n2', {'name': 'x', 'selected_date': ''});
      expect(note.createdAt, isNull);
      expect(note.selectedDate, isNull);
    });

    test('toMap serializes dates to ISO strings and omits the key', () {
      final created = DateTime(2026, 1, 2, 3, 4);
      final note = Note(key: 'n3', name: 'a', createdAt: created);
      final map = note.toMap();
      expect(map.containsKey('key'), isFalse);
      expect(map['created_at'], created.toIso8601String());
      expect(map['selected_date'], '');
    });

    test('round-trips through fromMap/toMap', () {
      final note = Note(
        key: 'n4',
        name: 'title',
        content: 'body',
        createdAt: DateTime(2026, 5, 1, 12),
        selectedDate: DateTime(2026, 5, 1),
      );
      expect(Note.fromMap('n4', note.toMap()), note);
    });
  });
}
