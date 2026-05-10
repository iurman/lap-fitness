import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'data/notes_repository.dart';

class NotesPage extends StatefulWidget {
  final DateTime? selectedDate;
  final bool showAppBar;
  final bool showAllNotes;

  const NotesPage({
    super.key,
    this.selectedDate,
    this.showAppBar = false,
    this.showAllNotes = true,
  });

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final NotesRepository _repo = NotesRepository();
  final Map<String, TextEditingController> _titleControllers = {};
  StreamSubscription<DatabaseEvent>? _sub;
  List<Map<String, dynamic>> _notesList = [];

  @override
  void initState() {
    super.initState();
    _subscribe();
  }

  void _subscribe() {
    try {
      final query = _repo.buildQuery(
        selectedDate: widget.selectedDate,
        showAll: widget.showAllNotes,
      );
      _sub = query.onValue.listen((event) {
        final value = event.snapshot.value as Map<dynamic, dynamic>?;
        final notes = <Map<String, dynamic>>[];
        if (value != null) {
          value.forEach((key, v) {
            notes.add({
              'key': key,
              'name': v['name'],
              'content': v['content'],
              'created_at': v['created_at'],
            });
          });
        }
        if (!mounted) return;
        setState(() => _notesList = notes);
      });
    } catch (_) {/* not signed in */}
  }

  TextEditingController _titleControllerFor(String key, String text) {
    final existing = _titleControllers[key];
    if (existing != null) {
      if (existing.text != text && !existing.selection.isValid) {
        existing.text = text;
      }
      return existing;
    }
    final controller = TextEditingController(text: text);
    _titleControllers[key] = controller;
    return controller;
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final c in _titleControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: widget.showAppBar
          ? BrandAppBar(
              title:
                  'Notes for ${DateFormat.yMMMd().format(widget.selectedDate ?? DateTime.now())}',
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: _notesList.isEmpty
          ? const _EmptyNotes()
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              itemCount: _notesList.length,
              itemBuilder: (context, index) {
                final note = _notesList[index];
                final key = note['key'] as String;
                final titleController =
                    _titleControllerFor(key, note['name'] as String? ?? '');
                return AnimatedScale(
                  scale: 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            hintText: 'Title',
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            filled: false,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                          onChanged: (value) => _repo.updateName(key, value),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat.yMd().add_jm().format(
                                DateTime.parse(note['created_at'] as String),
                              ),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Note',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              filled: false,
                              contentPadding: EdgeInsets.zero,
                            ),
                            initialValue: note['content'] as String? ?? '',
                            onChanged: (value) =>
                                _repo.updateContent(key, value),
                            maxLines: null,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: Colors.grey),
                            onPressed: () {
                              _repo.deleteNote(key);
                              _titleControllers.remove(key)?.dispose();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        onPressed: () => _repo.addNote(widget.selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('New Note'),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  const _EmptyNotes();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sticky_note_2_outlined,
              size: 72, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No notes yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the button below to add one.',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
