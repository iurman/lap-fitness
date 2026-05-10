import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'data/user_repository.dart';
import 'home_page.dart';
import 'user_info.dart';

class LoadingPage extends StatefulWidget {
  final String welcomeMessage;

  const LoadingPage({super.key, required this.welcomeMessage});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage>
    with SingleTickerProviderStateMixin {
  final UserRepository _users = UserRepository();
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    _routeFromProfile();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _routeFromProfile() async {
    Widget? next;
    try {
      final profile = await _users.fetchProfile();
      next = profile.hasRequiredInfo
          ? const HomePage()
          : UserInfoPage(
              calories: widget.welcomeMessage,
              showBackButton: false,
            );
    } catch (_) {
      next = UserInfoPage(
        calories: widget.welcomeMessage,
        showBackButton: false,
      );
    }
    // Hold the splash briefly so the user can read the message.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1.04).animate(
                CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
              ),
              child: Hero(
                tag: 'lap-logo',
                child: Image.asset(
                  'assets/images/lap2.png',
                  width: 180,
                  height: 180,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                color: AppColors.brand,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.welcomeMessage,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
