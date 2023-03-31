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
      appBar: AppBar(
        title: Text("Notes"),
      ),
      body: GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
        ),
        itemCount: notesList.length,
        itemBuilder: (BuildContext context, int index) {
          return Container(
            margin: EdgeInsets.all(8),
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Editable name of the note
                TextFormField(
                  decoration: InputDecoration(hintText: "New Note"),
                  initialValue: notesList[index]["name"],
                  onChanged: (value) =>
                      updateNoteName(notesList[index]["key"], value),
                ),
                SizedBox(height: 8),
                // Editable content of the note
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(hintText: "Type Here"),
                    initialValue: notesList[index]["content"],
                    onChanged: (value) =>
                        updateNoteContent(notesList[index]["key"], value),
                    maxLines: null,
                  ),
                ),
                SizedBox(height: 8),
                // Delete button for the note
                IconButton(
                  icon: Icon(Icons.delete),
                  onPressed: () => deleteNote(notesList[index]["key"]),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: Icon(Icons.add),
        onPressed: () => addNewNote(),
      ),
    );
  }
}
