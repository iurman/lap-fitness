import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/user_repository.dart';
import 'home_page.dart';
import 'user_info.dart';

class LoadingPage extends StatefulWidget {
  final String welcomeMessage;

  const LoadingPage({Key? key, required this.welcomeMessage}) : super(key: key);

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final UserRepository _users = UserRepository();

  @override
  void initState() {
    super.initState();
    _routeFromProfile();
  }

  Future<void> _routeFromProfile() async {
    try {
      final profile = await _users.fetchProfile();
      if (!mounted) return;
      if (profile.hasRequiredInfo) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => UserInfoPage(
              calories: widget.welcomeMessage,
              showBackButton: false,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => UserInfoPage(
            calories: widget.welcomeMessage,
            showBackButton: false,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.brand),
            const SizedBox(height: 16),
            Text(widget.welcomeMessage),
          ],
        ),
      ),
    );
  }
}
