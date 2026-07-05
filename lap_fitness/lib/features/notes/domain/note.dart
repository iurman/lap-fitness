import 'package:flutter/foundation.dart';

/// A date-tagged note, stored at RTDB `/users/{uid}/notes/{key}`.
@immutable
class Note {
  const Note({
    required this.key,
    this.name = '',
    this.content = '',
    this.createdAt,
    this.selectedDate,
  });

  final String key;
  final String name;
  final String content;
  final DateTime? createdAt;
  final DateTime? selectedDate;

  factory Note.fromMap(String key, Map<dynamic, dynamic> map) {
    return Note(
      key: key,
      name: (map['name'] ?? '').toString(),
      content: (map['content'] ?? '').toString(),
      createdAt: _parseDate(map['created_at']),
      selectedDate: _parseDate(map['selected_date']),
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    return DateTime.tryParse(str);
  }

  /// The RTDB payload for a note. `key` is excluded because it is the node id.
  Map<String, dynamic> toMap() => {
        'name': name,
        'content': content,
        'created_at': createdAt?.toIso8601String() ?? '',
        'selected_date': selectedDate?.toIso8601String() ?? '',
      };

  Note copyWith({
    String? key,
    String? name,
    String? content,
    DateTime? createdAt,
    DateTime? selectedDate,
  }) {
    return Note(
      key: key ?? this.key,
      name: name ?? this.name,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      selectedDate: selectedDate ?? this.selectedDate,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Note &&
      other.key == key &&
      other.name == name &&
      other.content == content &&
      other.createdAt == createdAt &&
      other.selectedDate == selectedDate;

  @override
  int get hashCode => Object.hash(key, name, content, createdAt, selectedDate);
}
