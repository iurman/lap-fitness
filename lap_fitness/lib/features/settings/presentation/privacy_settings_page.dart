// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/firebase/database_refs.dart';
import '../../profile/data/profile_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  final String userId;

  const PrivacySettingsPage({required this.userId});

  @override
  _PrivacySettingsPageState createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  bool _privateMode = false;
  final ProfileRepository _profileRepo =
      ProfileRepository(DatabaseRefs(FirebaseDatabase.instance));

  @override
  void initState() {
    super.initState();
    _fetchPrivateMode();
  }

  void _fetchPrivateMode() async {
    final profile = await _profileRepo.getProfile(widget.userId);
    if (!mounted) return;
    setState(() {
      _privateMode = profile.privateMode;
    });
  }

  void _savePrivateMode() async {
    await _profileRepo.setPrivateMode(widget.userId, _privateMode);
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
