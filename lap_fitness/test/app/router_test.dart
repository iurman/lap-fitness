import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/app/router.dart';
import 'package:lap_fitness/core/providers.dart';
import 'package:lap_fitness/features/profile/domain/user_profile.dart';

import '../support/fakes.dart';

Widget _routedApp() {
  return Consumer(
    builder: (context, ref, _) => MaterialApp.router(
      routerConfig: ref.watch(routerProvider),
    ),
  );
}

void main() {
  testWidgets('signed-out user lands on the login screen', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository(uid: null)),
      ],
      child: _routedApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back!'), findsOneWidget); // LoginPage
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('signed-in user with a complete profile is routed to home',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider.overrideWithValue(FakeProfileRepository(
          const UserProfile(
              age: '30', gender: 'Male', weight: '180', calories: '2000'),
        )),
      ],
      child: _routedApp(),
    ));
    await tester.pumpAndSettle();

    // login -> (redirect) loading -> (profile complete) home dashboard
    expect(find.text('Welcome to the App!'), findsOneWidget);
  });

  testWidgets('signed-in user with an incomplete profile goes to onboarding',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        profileRepositoryProvider
            .overrideWithValue(FakeProfileRepository(const UserProfile())),
      ],
      child: _routedApp(),
    ));
    await tester.pumpAndSettle();

    // Onboarding is the UserInfoPage titled "User Info".
    expect(find.text('User Info'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
