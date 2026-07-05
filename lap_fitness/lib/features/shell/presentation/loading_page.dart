import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';

/// Splash gate shown right after sign-in: decides between onboarding and home
/// based on whether the user's profile is complete.
class LoadingPage extends ConsumerStatefulWidget {
  const LoadingPage({super.key});

  @override
  ConsumerState<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends ConsumerState<LoadingPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _routeToNextScreen());
  }

  Future<void> _routeToNextScreen() async {
    try {
      final uid = ref.read(authRepositoryProvider).currentUid;
      final profile = uid == null
          ? null
          : await ref.read(profileRepositoryProvider).getProfile(uid);
      if (!mounted) return;
      context.go(profile != null && profile.isComplete
          ? Routes.home
          : Routes.onboarding);
    } catch (_) {
      if (mounted) context.go(Routes.onboarding);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.brand,
            ),
            SizedBox(height: 16),
            Text('Loading...'),
          ],
        ),
      ),
    );
  }
}
