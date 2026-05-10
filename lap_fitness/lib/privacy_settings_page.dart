import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/brand_app_bar.dart';
import 'data/user_repository.dart';

class PrivacySettingsPage extends StatefulWidget {
  final String userId;

  const PrivacySettingsPage({super.key, required this.userId});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  final UserRepository _users = UserRepository();
  bool _privateMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPrivateMode();
  }

  Future<void> _fetchPrivateMode() async {
    try {
      final profile = await _users.fetchProfileFor(widget.userId);
      if (!mounted) return;
      setState(() {
        _privateMode = profile.privateMode;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
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
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: const BrandAppBar(title: 'Privacy Settings'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: SwitchListTile(
                    secondary: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.visibility_off_outlined,
                        color: AppColors.brand,
                      ),
                    ),
                    title: const Text(
                      'Private Mode',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Hide your email and use a random display name on posts.',
                    ),
                    value: _privateMode,
                    onChanged: _onToggle,
                  ),
                ),
              ],
            ),
    );
  }
}
