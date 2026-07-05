// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../profile/data/profile_repository.dart';

class PrivacySettingsPage extends ConsumerStatefulWidget {
  final String userId;

  const PrivacySettingsPage({super.key, required this.userId});

  @override
  ConsumerState<PrivacySettingsPage> createState() =>
      _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends ConsumerState<PrivacySettingsPage> {
  bool _privateMode = false;
  ProfileRepository get _profileRepo => ref.read(profileRepositoryProvider);

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
