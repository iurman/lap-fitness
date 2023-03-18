import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: FirebaseOptions(
          apiKey: "AIzaSyCrquklDanvegDSTBXd3LUemKHQu3OwcZc",
          authDomain: "lap-firebase-ac2a7.firebaseapp.com",
          projectId: "lap-firebase-ac2a7",
          storageBucket: "lap-firebase-ac2a7.appspot.com",
          messagingSenderId: "171214035542",
          appId: "1:171214035542:web:f838044ed2c652551279f7",
          measurementId: "G-ZHBYDPC5WK"),
    );
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Stream<User?> _authStateStream;
  User? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  void _initializeApp() async {
    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      setState(() {
        _isLoading = false;
        _currentUser = currentUser;
      });

      _authStateStream = FirebaseAuth.instance.authStateChanges();
      _authStateStream.listen((user) {
        setState(() {
          _isLoading = false;
          _currentUser = user;
        });
      });
    } catch (e) {
      print('Error initializing the app: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase Auth Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: _isLoading
          ? LoadingPage()
          : (_currentUser == null
              ? LoginPage()
              : LoggedInPage(user: _currentUser!)),
    );
  }
}

class LoadingPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class LoggedInPage extends StatelessWidget {
  final User user;

  LoggedInPage({required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Logged in as ${user.email}'),
      ),
    );
  }
}
