// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class NotesPage extends StatefulWidget {
  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final databaseReference = FirebaseDatabase.instance.reference();
  User? user = FirebaseAuth.instance.currentUser;
  List notesList = [];

  // Function to add a new note to Firebase
  addNewNote() async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .push()
        .set({"name": "", "content": ""});
    setState(() {});
  }

  // Function to update the name of a note in Firebase
  updateNoteName(String key, String name) async {
    await databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .child(key)
        .update({"name": name});
    setState(() {});
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
    setState(() {});
  }

  @override
  void initState() {
    super.initState();

    // Attach a listener to the "notes" node in Firebase to update the notesList
    databaseReference
        .child("users")
        .child(user!.uid)
        .child("notes")
        .onValue
        .listen((event) {
      notesList.clear();
      if (event.snapshot.value != null) {
        Map<dynamic, dynamic> notesMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        ;
        notesMap.forEach((key, value) {
          notesList.add(
              {"key": key, "name": value["name"], "content": value["content"]});
        });
      }
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                        setState(() {
                          notesList
                              .removeAt(index); // remove the note from the list
                        });
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
