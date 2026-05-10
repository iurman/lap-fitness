import 'package:flutter/material.dart';

import 'core/widgets/brand_app_bar.dart';
import 'data/user_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  final String userId;

  const PrivacySettingsPage({Key? key, required this.userId}) : super(key: key);

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final UserRepository _users = UserRepository();
  bool _privateMode = false;

  @override
  void initState() {
    super.initState();
    _fetchPrivateMode();
  }

  Future<void> _fetchPrivateMode() async {
    try {
      final profile = await _users.fetchProfileFor(widget.userId);
      if (!mounted) return;
      setState(() => _privateMode = profile.privateMode);
    } catch (_) {/* leave default */}
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _privateMode = value);
    try {
      await _users.setPrivateMode(widget.userId, value);
    } catch (_) {/* swallow */}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandAppBar(title: 'Privacy Settings'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Private Mode'),
            Switch(value: _privateMode, onChanged: _onToggle),
          ],
        ),
      ),
    );
  }
}
