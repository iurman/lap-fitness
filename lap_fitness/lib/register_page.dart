import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/primary_button.dart';
import 'core/widgets/rounded_text_field.dart';
import 'loading_page.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterPage({Key? key, required this.showLoginPage})
      : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _toggleObscure() => setState(() => _isObscure = !_isObscure);

  bool get _passwordsMatch =>
      _passwordController.text.trim() ==
      _confirmPasswordController.text.trim();

  Future<void> _signUp() async {
    if (!_passwordsMatch) {
      _showAlert('The passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final credential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (!mounted) return;
      if (credential.user != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const LoadingPage(
              welcomeMessage: 'Sucessfully Registered! Welcome!',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      if (e.code == 'weak-password') {
        _showAlert('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        _showAlert('The account already exists for that email.');
      } else {
        _showAlert(e.message ?? 'Registration failed.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAlert(String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(content: Text(message)),
    );
  }

  Widget _obscureToggle() => IconButton(
        onPressed: _toggleObscure,
        icon: Icon(
          _isObscure ? Icons.visibility : Icons.visibility_off,
          color: Colors.grey[700],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[300],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset('assets/images/lap2.png', width: 400, height: 400),
                const SizedBox(height: 20),
                const Text(
                  'Register below',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 30),
                RoundedTextField(
                  controller: _emailController,
                  hintText: 'Email',
                ),
                const SizedBox(height: 15),
                RoundedTextField(
                  controller: _passwordController,
                  hintText: 'Password',
                  obscureText: _isObscure,
                  suffixIcon: _obscureToggle(),
                ),
                const SizedBox(height: 15),
                RoundedTextField(
                  controller: _confirmPasswordController,
                  hintText: 'Confirm Password',
                  obscureText: _isObscure,
                  suffixIcon: _obscureToggle(),
                ),
                const SizedBox(height: 15),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25.0),
                  child: PrimaryButton(
                    label: 'Sign Up',
                    onPressed: _isLoading ? null : _signUp,
                  ),
                ),
                const SizedBox(height: 25),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'I am a member!',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    GestureDetector(
                      onTap: widget.showLoginPage,
                      child: const Text(
                        ' Login now',
                        style: TextStyle(
                          color: AppColors.brand,
                          fontWeight: FontWeight.bold,
                        ),
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
