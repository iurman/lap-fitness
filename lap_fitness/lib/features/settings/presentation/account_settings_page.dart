// ignore_for_file: use_key_in_widget_constructors, library_private_types_in_public_api, use_build_context_synchronously, prefer_const_constructors, sort_child_properties_last

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

class AccountSettingsPage extends ConsumerStatefulWidget {
  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
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
      // Send a verification link to the new address; the change is applied
      // once the user confirms. `updateEmail` was removed in firebase_auth 6.x.
      await ref
          .read(authRepositoryProvider)
          .verifyBeforeUpdateEmail(_emailController.text);

      // Show a success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Verification link sent to ${_emailController.text}.')));

      // Clear the form
      _emailFormKey.currentState?.reset();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
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
      await ref
          .read(authRepositoryProvider)
          .updatePassword(_passwordController.text);

      // Show a success message
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Password updated.')));

      // Clear the form
      _passwordFormKey.currentState?.reset();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        // Update the error message
        _passwordError = e.message;
      });
    }
  }

  Future<void> _deleteAccount() async {
    // Show a confirmation dialog before deleting the account. Barrier-dismissing
    // the dialog returns null, so default to "not confirmed".
    final confirmed = await showDialog<bool>(
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
    // If the user confirms, delete the account and sign out.
    if (confirmed ?? false) {
      try {
        // After deletion the auth state change drives the router back to /login.
        await ref.read(authRepositoryProvider).deleteAccount();
        await ref.read(authRepositoryProvider).signOut();
      } on FirebaseAuthException catch (e) {
        // `delete()` throws `requires-recent-login` for older sessions. Surface
        // it instead of crashing on an unhandled async error. (A full re-auth
        // flow and RTDB data cleanup are planned as a later milestone.)
        if (!mounted) return;
        final message = e.code == 'requires-recent-login'
            ? 'For your security, please sign in again before deleting your account.'
            : (e.message ?? 'Could not delete account. Please try again.');
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.brand,
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
                        style: TextStyle(color: AppColors.brand, fontSize: 18),
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
                          backgroundColor: WidgetStateProperty.all<Color>(
                            AppColors.brand,
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
                        style: TextStyle(color: AppColors.brand, fontSize: 18),
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
                          cursorColor: AppColors.brand,
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
                          backgroundColor: WidgetStateProperty.all<Color>(
                            AppColors.brand,
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
                  backgroundColor: WidgetStateProperty.all<Color>(Colors.red),
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
