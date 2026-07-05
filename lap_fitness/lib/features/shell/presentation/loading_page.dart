import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

import '../../../core/firebase/database_refs.dart';
import '../../auth/data/auth_repository.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/user_info_page.dart';
import 'home_shell.dart';

class LoadingPage extends StatefulWidget {
  final String welcomeMessage;

  const LoadingPage({super.key, required this.welcomeMessage});

  @override
  State<LoadingPage> createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  final _authRepo = AuthRepository(FirebaseAuth.instance);
  final _profileRepo = ProfileRepository(DatabaseRefs(FirebaseDatabase.instance));

  @override
  void initState() {
    super.initState();
    _routeToNextScreen();
  }

  Future<void> _routeToNextScreen() async {
    try {
      final uid = _authRepo.currentUid;
      final profile = uid == null ? null : await _profileRepo.getProfile(uid);
      if (!mounted) return;
      if (profile != null && profile.isComplete) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserInfoPage(
                calories: widget.welcomeMessage, showBackButton: false),
          ),
        );
      }
    } catch (_) {
      // handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              color: Color.fromARGB(255, 138, 104, 35),
            ),
            const SizedBox(height: 16),
            Text(widget.welcomeMessage),
          ],
        ),
      ),
    );
  }
}
