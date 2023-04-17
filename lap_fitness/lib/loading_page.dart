// ignore_for_file: prefer_const_constructors, use_key_in_widget_constructors, prefer_const_constructors_in_immutables, library_private_types_in_public_api, deprecated_member_use

import 'package:flutter/material.dart';
import 'package:lap_fitness/home_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:lap_fitness/user_info.dart';

class LoadingPage extends StatefulWidget {
  final String welcomeMessage;

  LoadingPage({required this.welcomeMessage});

  @override
  _LoadingPageState createState() => _LoadingPageState();
}

class _LoadingPageState extends State<LoadingPage> {
  late DatabaseReference _userRef;
  late User _currentUser;

  @override
  void initState() {
    super.initState();

    _currentUser = FirebaseAuth.instance.currentUser!;
    _userRef = FirebaseDatabase.instance
        .reference()
        .child('users')
        .child(_currentUser.uid);

    _userRef.onValue.first.then((DatabaseEvent userEvent) {
      final user = userEvent.snapshot.value as Map<dynamic, dynamic>?;
      if (user != null &&
          user['age'] != null &&
          user['gender'] != null &&
          user['weight'] != null &&
          user['height'] != null &&
          user['calories'] != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
              builder: (context) =>
                  UserInfoPage(calories: widget.welcomeMessage)),
        );
      }
    }).catchError((error) {
      // handle error
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color.fromARGB(255, 138, 104, 35),
            ),
            SizedBox(height: 16),
            Text(widget.welcomeMessage),
          ],
        ),
      ),
    );
  }
}
