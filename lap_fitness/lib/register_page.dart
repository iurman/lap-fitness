import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/widgets/primary_button.dart';
import 'core/widgets/rounded_text_field.dart';
import 'loading_page.dart';

class RegisterPage extends StatefulWidget {
  final VoidCallback showLoginPage;
  const RegisterPage({super.key, required this.showLoginPage});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with TickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _isObscure = true;

  late final AnimationController _entryController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _entryController.dispose();
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
      _showError('The passwords do not match.');
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
              welcomeMessage: 'Successfully registered. Welcome!',
            ),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      switch (e.code) {
        case 'weak-password':
          _showError('The password provided is too weak.');
          break;
        case 'email-already-in-use':
          _showError('An account already exists for that email.');
          break;
        case 'invalid-email':
          _showError('Please enter a valid email address.');
          break;
        default:
          _showError(e.message ?? 'Registration failed.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  Widget _obscureToggle() => IconButton(
        onPressed: _toggleObscure,
        icon: Icon(
          _isObscure
              ? Icons.visibility_outlined
              : Icons.visibility_off_outlined,
          color: Colors.grey[700],
        ),
      );

  Widget _entryWrap({required int index, required Widget child}) {
    final start = (index * 0.08).clamp(0.0, 0.8);
    final curve = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, (start + 0.6).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curve,
      builder: (context, c) => Opacity(
        opacity: curve.value,
        child: Transform.translate(
          offset: Offset(0, (1 - curve.value) * 16),
          child: c,
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Hero(
                  tag: 'lap-logo',
                  child: Image.asset(
                    'assets/images/lap2.png',
                    width: 220,
                    height: 220,
                  ),
                ),
                _entryWrap(
                  index: 0,
                  child: Text(
                    'Create your account',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                _entryWrap(
                  index: 1,
                  child: Text(
                    'Sign up to start tracking your fitness',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 28),
                _entryWrap(
                  index: 2,
                  child: RoundedTextField(
                    controller: _emailController,
                    hintText: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    prefixIcon:
                        const Icon(Icons.mail_outline, color: AppColors.brand),
                  ),
                ),
                const SizedBox(height: 14),
                _entryWrap(
                  index: 3,
                  child: RoundedTextField(
                    controller: _passwordController,
                    hintText: 'Password',
                    obscureText: _isObscure,
                    textInputAction: TextInputAction.next,
                    prefixIcon:
                        const Icon(Icons.lock_outline, color: AppColors.brand),
                    suffixIcon: _obscureToggle(),
                  ),
                ),
                const SizedBox(height: 14),
                _entryWrap(
                  index: 4,
                  child: RoundedTextField(
                    controller: _confirmPasswordController,
                    hintText: 'Confirm Password',
                    obscureText: _isObscure,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _signUp(),
                    prefixIcon: const Icon(Icons.lock_reset_outlined,
                        color: AppColors.brand),
                    suffixIcon: _obscureToggle(),
                  ),
                ),
                const SizedBox(height: 20),
                _entryWrap(
                  index: 5,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25.0),
                    child: PrimaryButton(
                      label: 'Sign Up',
                      icon: Icons.person_add_alt_1_rounded,
                      isLoading: _isLoading,
                      onPressed: _isLoading ? null : _signUp,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                _entryWrap(
                  index: 6,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'I am a member!',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      TextButton(
                        onPressed: widget.showLoginPage,
                        child: const Text('Login now'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
