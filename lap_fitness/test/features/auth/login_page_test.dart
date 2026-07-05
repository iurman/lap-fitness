import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/features/auth/presentation/login_page.dart';

void main() {
  testWidgets('LoginPage renders its form and controls', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginPage()),
      ),
    );

    expect(find.text('Welcome back!'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text(' Register now'), findsOneWidget);
    // Two text fields: email and password.
    expect(find.byType(TextField), findsNWidgets(2));
  });
}
