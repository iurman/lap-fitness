// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
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
  bool _listenerSet = false;
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

    _authRepo.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser != null && !_listenerSet) {
        _listenerSet = true;
        _uid = firebaseUser.uid;

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
    });
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
          final titleController = TextEditingController(text: note.name);
          titleController.selection = TextSelection.fromPosition(
              TextPosition(offset: titleController.text.length));
          return Container(
            margin: EdgeInsets.all(12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editable name of the note
                TextFormField(
                  controller: titleController,
                  decoration: InputDecoration(
                    hintText: "Title",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brand,
                  ),
                  onChanged: (value) => updateNoteName(note.key, value),
                ),
                SizedBox(height: 12),
                // Creation date of the note
                Text(
                  note.createdAt != null
                      ? DateFormat.yMd().add_jm().format(note.createdAt!)
                      : '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                SizedBox(height: 12),
                // Editable content of the note
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      hintText: "Note",
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                    initialValue: note.content,
                    onChanged: (value) => updateNoteContent(note.key, value),
                    maxLines: null,
                    style: TextStyle(fontSize: 16),
                  ),
                ),
                // Delete button
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () {
                        // Delete note from database
                        deleteNote(note.key);
                        if (mounted) {
                          setState(() {
                            notesList.removeAt(index);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
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
