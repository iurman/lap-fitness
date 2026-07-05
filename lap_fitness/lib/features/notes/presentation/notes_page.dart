// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api
import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers.dart';
import '../../auth/data/auth_repository.dart';
import '../data/notes_repository.dart';
import '../domain/note.dart';

class NotesPage extends ConsumerStatefulWidget {
  final DateTime? selectedDate;
  final bool showAppBar;
  final bool showAllNotes;

  NotesPage(
      {super.key,
      this.selectedDate,
      this.showAppBar = false,
      this.showAllNotes = true});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  AuthRepository get _authRepo => ref.read(authRepositoryProvider);
  NotesRepository get _notesRepo => ref.read(notesRepositoryProvider);
  List<Note> notesList = [];
  StreamSubscription<List<Note>>? _notesSub;
  String? _uid;

  // Function to add a new note to Firebase
  Future<void> addNewNote() async {
    if (_uid == null) return;
    await _notesRepo.addNote(uid: _uid!, day: widget.selectedDate);
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> updateNoteName(String key, String name) async {
    if (_uid == null) return;
    await _notesRepo.updateName(_uid!, key, name);
  }

  Future<void> updateNoteContent(String key, String content) async {
    if (_uid == null) return;
    await _notesRepo.updateContent(_uid!, key, content);
  }

  Future<void> deleteNote(String key) async {
    if (_uid == null) return;
    await _notesRepo.deleteNote(_uid!, key);
  }

  @override
  void initState() {
    super.initState();

    _uid = _authRepo.currentUid;
    if (_uid != null) {
      final DateTime? day =
          (!widget.showAllNotes && widget.selectedDate != null)
              ? widget.selectedDate
              : null;

      _notesSub = _notesRepo.watchNotes(_uid!, day: day).listen((notes) {
        if (mounted) {
          setState(() {
            notesList = notes;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _notesSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: AppColors.brand,
              title: Text(
                  "Notes for ${DateFormat.yMMMd().format(widget.selectedDate ?? DateTime.now())}"),
              leading: IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            )
          : null,
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.75,
        ),
        itemCount: notesList.length,
        itemBuilder: (BuildContext context, int index) {
          final Note note = notesList[index];
          // Key by note id so Flutter preserves each cell's controllers by
          // identity. Deletion is left to the repository; the watchNotes
          // stream re-emits the updated list, so no manual removeAt is needed.
          return _NoteCard(
            key: ValueKey(note.key),
            note: note,
            onNameChanged: (value) => updateNoteName(note.key, value),
            onContentChanged: (value) => updateNoteContent(note.key, value),
            onDelete: () => deleteNote(note.key),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.brand,
        child: Icon(Icons.add),
        onPressed: () => addNewNote(),
      ),
    );
  }
}

/// A single editable note cell. It owns its title/content controllers, created
/// once in [State] and preserved across rebuilds because the grid keys each
/// card by note id. Previously the controllers were rebuilt inside the grid's
/// `itemBuilder` on every stream re-emit/keystroke, which reset the caret and
/// could bind in-progress text to the wrong note after a delete.
class _NoteCard extends StatefulWidget {
  const _NoteCard({
    super.key,
    required this.note,
    required this.onNameChanged,
    required this.onContentChanged,
    required this.onDelete,
  });

  final Note note;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<String> onContentChanged;
  final VoidCallback onDelete;

  @override
  State<_NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<_NoteCard> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.note.name);
  late final TextEditingController _contentController =
      TextEditingController(text: widget.note.content);

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Editable name of the note
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.brand,
            ),
            onChanged: widget.onNameChanged,
          ),
          const SizedBox(height: 12),
          // Creation date of the note
          Text(
            widget.note.createdAt != null
                ? DateFormat.yMd().add_jm().format(widget.note.createdAt!)
                : '',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          // Editable content of the note
          Expanded(
            child: TextFormField(
              controller: _contentController,
              decoration: const InputDecoration(
                hintText: 'Note',
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: widget.onContentChanged,
              maxLines: null,
              style: const TextStyle(fontSize: 16),
            ),
          ),
          // Delete button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: widget.onDelete,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
