// ignore_for_file: prefer_const_constructors
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lap_fitness/core/providers.dart';
import 'package:lap_fitness/features/feed/domain/post.dart';
import 'package:lap_fitness/features/feed/presentation/feed_page.dart';
import 'package:lap_fitness/features/notes/domain/note.dart';
import 'package:lap_fitness/features/notes/presentation/calendar_page.dart';
import 'package:lap_fitness/features/notes/presentation/notes_page.dart';
import 'package:lap_fitness/features/profile/domain/user_profile.dart';
import 'package:lap_fitness/features/profile/presentation/user_info_page.dart';
import 'package:lap_fitness/features/settings/presentation/account_settings_page.dart';
import 'package:lap_fitness/features/settings/presentation/privacy_settings_page.dart';
import 'package:lap_fitness/features/settings/presentation/settings_page.dart';
import 'package:lap_fitness/features/shell/presentation/home_shell.dart';
import 'package:lap_fitness/features/water/presentation/water_tracker_page.dart';
import 'package:lap_fitness/features/workout/presentation/workout_tracker_page.dart';

import '../support/fakes.dart';

void main() {
  testWidgets('HomePage renders the dashboard', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: const HomePage())),
    );
    expect(find.text('Welcome to the App!'), findsOneWidget);
    expect(find.byType(BottomNavigationBar), findsOneWidget);
  });

  testWidgets('WorkoutTracker renders its set/rep counter and controls',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: WorkoutTracker())),
    );
    expect(find.text('Set 1 - Rep 1'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Next Set'), findsOneWidget);
  });

  testWidgets('CalendarPage renders numbered day cells', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: CalendarPage())),
    );
    // Every month contains a 15th; its cell should be rendered.
    expect(find.text('15'), findsOneWidget);
  });

  testWidgets('SettingsPage lists the settings options', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: SettingsPage())),
    );
    expect(find.text('Profile Settings'), findsOneWidget);
    expect(find.text('Privacy Settings'), findsOneWidget);
    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.text('Sign Out'), findsOneWidget);
  });

  testWidgets('AccountSettingsPage renders its forms', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: AccountSettingsPage())),
    );
    expect(find.text('Change Email'), findsWidgets);
    expect(find.text('Change Password'), findsWidgets);
    expect(find.text('Delete Account'), findsOneWidget);
  });

  testWidgets('PrivacySettingsPage renders the private-mode switch',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileRepositoryProvider.overrideWithValue(
              FakeProfileRepository(const UserProfile(privateMode: true))),
        ],
        child: const MaterialApp(home: PrivacySettingsPage(userId: 'test-uid')),
      ),
    );
    await tester.pump();
    expect(find.text('Private Mode'), findsOneWidget);
    // The switch reflects the persisted privateMode value from the repository.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('UserInfoPage renders the profile form', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository(
              const UserProfile(age: '30', gender: 'Male', weight: '180'))),
        ],
        child: const MaterialApp(home: UserInfoPage(isOnboarding: true)),
      ),
    );
    await tester.pump();
    expect(find.text('Save'), findsOneWidget);
    // The form prefills from the injected profile.
    expect(find.text('30'), findsOneWidget); // age
    expect(find.text('180'), findsOneWidget); // weight
  });

  testWidgets('NotesPage renders notes loaded from the repository',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          notesRepositoryProvider.overrideWithValue(FakeNotesRepository([
            Note(key: 'n1', name: 'Leg day', createdAt: DateTime(2026, 7, 5)),
          ])),
        ],
        child: MaterialApp(home: NotesPage(selectedDate: DateTime(2026, 7, 5))),
      ),
    );
    await tester.pump();
    expect(find.text('Leg day'), findsOneWidget);
  });

  testWidgets('FeedPage renders posts from the repository', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          feedRepositoryProvider.overrideWithValue(FakeFeedRepository([
            const Post(
              key: 'k1',
              userId: 'test-uid',
              postId: 'p1',
              body: 'Great workout!',
              userEmail: 'tester@example.com',
              displayName: 'tester@example.com',
            ),
          ])),
          profileRepositoryProvider.overrideWithValue(FakeProfileRepository()),
        ],
        child: const MaterialApp(home: FeedPage()),
      ),
    );
    await tester.pump();
    expect(find.text('Great workout!'), findsOneWidget);
  });

  testWidgets('WaterTracker shows the persisted per-user count',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          waterRepositoryProvider.overrideWithValue(FakeWaterRepository(5)),
        ],
        child: MaterialApp(home: WaterTracker()),
      ),
    );
    await tester.pump();
    expect(find.text('Water Intake: 5 cups'), findsOneWidget);
  });

  testWidgets('WaterTracker increments the count on tap', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          waterRepositoryProvider.overrideWithValue(FakeWaterRepository(5)),
        ],
        child: MaterialApp(home: WaterTracker()),
      ),
    );
    await tester.pump();
    expect(find.text('Water Intake: 5 cups'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Water Intake: 6 cups'), findsOneWidget);
  });
}
