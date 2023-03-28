// ignore_for_file: prefer_const_constructors
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: 'AIzaSyBKVvcV9EPJL_OXx3I1p6z4forM-kAiqEg',
          appId: '1:1076168022651:web:c48ba297634030ba68a0de',
          messagingSenderId: '1076168022651',
          projectId: 'lap-fitness',
          authDomain: 'lap-fitness.firebaseapp.com',
          databaseURL: 'https://lap-fitness-default-rtdb.firebaseio.com',
          storageBucket: 'lap-fitness.appspot.com',
          measurementId: 'G-476VRMEZBX'),
    );
  } catch (e) {
    // ignore: avoid_print
    print('Error initializing Firebase: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
