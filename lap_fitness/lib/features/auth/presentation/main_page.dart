import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../data/auth_repository.dart';
import 'auth_page.dart';

class MainPage extends StatelessWidget {
  const MainPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authRepo = AuthRepository(FirebaseAuth.instance);
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: authRepo.authStateChanges(),
        builder: (context, snapshot) {
          // Both signed-in and signed-out states currently land on AuthPage,
          // which gates onward navigation itself.
          return const AuthPage();
        },
      ),
    );
  }
}
