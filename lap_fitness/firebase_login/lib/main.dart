import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'signup_page.dart';

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
  runApp(MaterialApp(home: MyApp()));
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
      final FirebaseAuth auth = FirebaseAuth.instance;
      await auth.authStateChanges().listen((User? user) {
        setState(() {
          _isLoading = false;
          _currentUser = user;
        });
      });
      _currentUser = auth.currentUser;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error initializing the app: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void goToLoginPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LoginPage(),
      ),
    );
  }

  void goToSignUpPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SignupPage(),
      ),
    );
  }

  void _signOut() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      print('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Firebase Auth Demo',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: _isLoading
              ? LoadingPage()
              : (_currentUser == null
                  ? Scaffold(
                      body: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Builder(
                              builder: (context) => InkWell(
                                onTap: goToLoginPage,
                                child: ElevatedButton(
                                  onPressed: () {
                                    goToLoginPage();
                                  },
                                  child: Text('Log In'),
                                ),
                              ),
                            ),
                            Builder(
                              builder: (context) => InkWell(
                                onTap: goToSignUpPage,
                                child: ElevatedButton(
                                  onPressed: () {
                                    goToSignUpPage();
                                  },
                                  child: Text('Sign Up'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Scaffold(
                      appBar: AppBar(
                        title: Text('Logged In'),
                        actions: [
                          IconButton(
                            onPressed: _signOut,
                            icon: Icon(Icons.logout),
                          ),
                        ],
                      ),
                      body: Center(
                        child: Text('Logged in as ${_currentUser!.email}'),
                      ),
                    )),
        ),
        debugShowCheckedModeBanner: false);
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
