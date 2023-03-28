// ignore_for_file: prefer_const_constructors

// ignore: unused_import
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // text controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  Future signIn() async {
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: _emailController.text.trim(),
      password: _passwordController.text.trim(),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          // ignore: prefer_const_literals_to_create_immutables
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              // ignore: prefer_const_literals_to_create_immutables
              children: [
                Image.asset('assets/images/lap.png'),
                // Hello Again!
                SizedBox(height: 20),
                Text(
                  'Welcome back!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 30),

                // email textfield
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Email',
                          )),
                    ),
                  ),
                ),
                SizedBox(height: 15),

                //password textfield
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      border: Border.all(color: Colors.white),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 20.0),
                      child: TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Password',
                          )),
                    ),
                  ),
                ),
                SizedBox(height: 15),

                // sign in button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: GestureDetector(
                    onTap: signIn,
                    child: Container(
                      padding: EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          'Sign In',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 25),

                // not a member? register now
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  // ignore: prefer_const_literals_to_create_immutables
                  children: [
                    Text(
                      'Not a member?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      ' Register now',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
