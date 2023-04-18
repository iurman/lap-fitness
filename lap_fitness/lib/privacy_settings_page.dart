// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class PrivacySettingsPage extends StatefulWidget {
  final String userId;

  PrivacySettingsPage({required this.userId});

  @override
  _PrivacySettingsPageState createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _privateMode = false;
  final DatabaseReference _usersDatabase =
      FirebaseDatabase.instance.reference().child('users');

  @override
  void initState() {
    super.initState();
    _fetchPrivateMode();
  }

  void _fetchPrivateMode() async {
    await _usersDatabase
        .child(widget.userId)
        .once()
        .then((DatabaseEvent event) {
      Map<dynamic, dynamic>? userData =
          event.snapshot.value as Map<dynamic, dynamic>?;
      setState(() {
        _privateMode = userData?['privateMode'] ?? false;
      });
    });
  }

  void _savePrivateMode() async {
    await _usersDatabase
        .child(widget.userId)
        .update({'privateMode': _privateMode});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text('Privacy Settings'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Private Mode'),
            Switch(
              value: _privateMode,
              onChanged: (value) {
                setState(() {
                  _privateMode = value;
                });
                _savePrivateMode();
              },
            ),
          ],
        ),
      ),
    );
  }
}
