// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class NotesPage extends StatefulWidget {
  final DateTime? selectedDate;
  final bool showAppBar;
  final bool showAllNotes;

  NotesPage(
      {this.selectedDate, this.showAppBar = false, this.showAllNotes = true});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final databaseReference = FirebaseDatabase.instance.reference();
  User? user = FirebaseAuth.instance.currentUser;
  List notesList = [];

  get database => null;

  // Function to add a new note to Firebase
  addNewNote() async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .push()
        .set({
      "name": "",
      "content": "",
      "created_at": DateTime.now().toIso8601String(),
      "selected_date": widget.selectedDate?.toIso8601String() ?? ''
    });
    if (mounted) {
      setState(() {});
    }
  }

  // Function to update the name of a note in Firebase
  updateNoteName(String key, String name) async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .child(key)
        .update({"name": name});
    if (mounted) {
      setState(() {});
    }
  }

  // Function to update the content of a note in Firebase
  updateNoteContent(String key, String content) async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .child(key)
        .update({"content": content});
    setState(() {});
  }

  // Function to delete a note from Firebase
  deleteNote(String key) async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .child(key)
        .remove();
    if (mounted) {
      setState(() {});
    }
  }

  bool _listenerSet = false;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.authStateChanges().listen((User? firebaseUser) {
      if (firebaseUser != null && !_listenerSet) {
        _listenerSet = true;
        user = firebaseUser;

        Query query =
            databaseReference.child("users").child(user!.uid).child("notes");

        if (!widget.showAllNotes && widget.selectedDate != null) {
          String selectedDateStr = widget.selectedDate!.toIso8601String();
          query = query
              .orderByChild("selected_date")
              .startAt(selectedDateStr)
              .endAt(widget.selectedDate!
                  .add(Duration(days: 1))
                  .toIso8601String());
        }

        query.onValue.listen((event) {
          notesList.clear();
          if (event.snapshot.value != null) {
            Map<dynamic, dynamic> notesMap =
                event.snapshot.value as Map<dynamic, dynamic>;
            notesMap.forEach((key, value) {
              notesList.add({
                "key": key,
                "name": value["name"],
                "content": value["content"],
                "created_at": value["created_at"],
              });
            });
          }
          if (mounted) {
            setState(() {});
          }
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: Color.fromARGB(255, 138, 104, 35),
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
          final titleController =
              TextEditingController(text: notesList[index]["name"]);
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
                  color: Colors.grey.withOpacity(0.3),
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
                    color: Color.fromARGB(255, 138, 104, 35),
                  ),
                  onChanged: (value) =>
                      updateNoteName(notesList[index]["key"], value),
                ),
                SizedBox(height: 12),
                // Creation date of the note
                Text(
                  DateFormat.yMd()
                      .add_jm()
                      .format(DateTime.parse(notesList[index]["created_at"])),
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
                    initialValue: notesList[index]["content"],
                    onChanged: (value) =>
                        updateNoteContent(notesList[index]["key"], value),
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
                        deleteNote(notesList[index]["key"]);
                        if (mounted) {
                          // Remove note from notesList
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
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        child: Icon(Icons.add),
        onPressed: () => addNewNote(),
      ),
    );
  }
}
