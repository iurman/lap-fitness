import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lap_fitness/auth_page.dart';

class AccountSettingsPage extends StatefulWidget {
  @override
  _AccountSettingsPageState createState() => _AccountSettingsPageState();
}

class _AccountSettingsPageState extends State<AccountSettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _changeEmail() async {
    // Validate the email address
    if (!_emailFormKey.currentState!.validate()) {
      return;
    }

    try {
      // Update the email address
      await FirebaseAuth.instance.currentUser!
          .updateEmail(_emailController.text);

      // Show a success message
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Email address updated.')));

      // Clear the form
      _formKey.currentState!.reset();
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Update the error message
        _emailError = e.message;
      });
    }
  }

  Future<void> _changePassword() async {
    // Validate the password
    if (!_passwordFormKey.currentState!.validate()) {
      return;
    }

    try {
      // Update the password
      await FirebaseAuth.instance.currentUser!
          .updatePassword(_passwordController.text);

      // Show a success message
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Password updated.')));

      // Clear the form
      _formKey.currentState!.reset();
    } on FirebaseAuthException catch (e) {
      setState(() {
        // Update the error message
        _passwordError = e.message;
      });
    }
  }

  Future<void> _deleteAccount() async {
    // Show a confirmation dialog before deleting the account
    bool confirmed = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Account'),
          content: Text(
              'Are you sure you want to delete your account? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );
    // If the user confirms, delete the account and sign out
    if (confirmed) {
      await FirebaseAuth.instance.currentUser!.delete();
      await FirebaseAuth.instance.signOut();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => AuthPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color.fromARGB(255, 138, 104, 35),
        title: Text('Account Settings'),
      ),
      body: Center(
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(height: 128.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Change Email',
                        style: TextStyle(
                            color: Color.fromARGB(255, 138, 104, 35),
                            fontSize: 18),
                      ),
                      SizedBox(height: 16.0),
                      Form(
                        key: _emailFormKey,
                        child: TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'New Email',
                            errorText: _emailError,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter an email address.';
                            }
                            if (!RegExp(
                                    r'^\w+([\.-]?\w+)*@\w+([\.-]?\w+)*(\.\w{2,3})+$')
                                .hasMatch(value)) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _changeEmail,
                        child: Text('Change Email'),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Color.fromARGB(255, 138, 104, 35),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.0),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Change Password',
                        style: TextStyle(
                            color: Color.fromARGB(255, 138, 104, 35),
                            fontSize: 18),
                      ),
                      SizedBox(height: 16.0),
                      Form(
                        key: _passwordFormKey,
                        child: TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            errorText: _passwordError,
                          ),
                          cursorColor: Color.fromARGB(255, 138, 104, 35),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter a password.';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters long.';
                            }
                            return null;
                          },
                        ),
                      ),
                      SizedBox(height: 16.0),
                      ElevatedButton(
                        onPressed: _changePassword,
                        child: Text('Change Password'),
                        style: ButtonStyle(
                          backgroundColor: MaterialStateProperty.all<Color>(
                            Color.fromARGB(255, 138, 104, 35),
                          ),
                        ),
                      ),
                      SizedBox(height: 32.0),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 32.0),
              ElevatedButton(
                onPressed: _deleteAccount,
                child: Text('Delete Account'),
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
                ),
              ),
              Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
