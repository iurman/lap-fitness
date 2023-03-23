import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'home_page.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoginForm = true;
  bool _isLoading = false;

  String _errorMessage = '';

  bool _isPasswordReset = false;

  void _showPasswordResetForm() {
    setState(() {
      _isLoginForm = false;
      _isPasswordReset = true;
      _errorMessage = '';
    });
  }

  void _showLoginForm() {
    setState(() {
      _isLoginForm = true;
      _isPasswordReset = false;
      _errorMessage = '';
    });
  }

  Future<void> _signInWithEmailAndPassword() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final UserCredential userCredential =
          await _auth.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final User? user = userCredential.user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user?.email ?? ''} signed in'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to sign in: ${e.message}';
      });
    }
  }

  Future<void> _createUserWithEmailAndPassword() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      final User? user = userCredential.user;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${user?.email ?? ''} account created'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to create account: ${e.message}';
      });
    }
  }

  Future<void> _sendPasswordResetEmail() async {
    try {
      setState(() {
        _isLoading = true;
      });

      await _auth.sendPasswordResetEmail(email: _emailController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset email sent'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to send password reset email: ${e.message}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLoginForm ? 'Login' : 'Create Account'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _isPasswordReset
                ? _buildPasswordResetForm()
                : _buildLoginForm(),
      ),
    );
  }

  Widget _buildPasswordResetForm() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TextField(
          controller: _emailController,
          decoration: InputDecoration(
            labelText: 'Email',
          ),
        ),
        SizedBox(height: 20),
        ElevatedButton(
          child: Text('Send Password Reset Email'),
          onPressed: _sendPasswordResetEmail,
        ),
        SizedBox(height: 20),
        TextButton(
          child: Text('Back to Login'),
          onPressed: _showLoginForm,
        ),
      ],
    );
  }

  Widget _buildLoginForm() {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      TextField(
        controller: _emailController,
        decoration: InputDecoration(
          labelText: 'Email',
        ),
      ),
      TextField(
        controller: _passwordController,
        decoration: InputDecoration(
          labelText: 'Password',
        ),
        obscureText: true,
      ),
      SizedBox(height: 20),
      ElevatedButton(
        child: Text(_isLoginForm ? 'Login' : 'Create Account'),
        onPressed: _isLoginForm
            ? _signInWithEmailAndPassword
            : _createUserWithEmailAndPassword,
      ),
      TextButton(
        child: Text(_isLoginForm ? 'Create Account' : 'Back to Login'),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SignupPage()),
          );
        },
      ),
    ]);
  }
}
