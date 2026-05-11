# LAP Fitness — Flutter App Modernization & Refactor Plan

> **For the assistant picking this up:** This is a real refactor on a real app, not a writeup task. You must open the files referenced below, run `flutter analyze` / `flutter pub outdated` / `flutter test` as you go, and verify the app still builds after each phase. **Do not** generate a generic "how to modernize Flutter" doc — modify this codebase. Work on the existing branch `claude/flutter-modernization-guide-TLRW0` (or a child branch of it) and commit after each phase with a clear message. Push when you finish a phase so progress is visible.

---

## 0. Orientation (do this first, ~10 min)

The repo root is `/home/user/lap-fitness`. The Flutter app lives in **`lap_fitness/`**. There is also a `landing/` Next.js site and an `sdk/` folder — **ignore both** unless explicitly told otherwise.

Before touching anything:

1. `cd lap_fitness && flutter --version && dart --version` — record what's installed.
2. `flutter pub get` — make sure deps resolve on the current pinned versions.
3. `flutter analyze > /tmp/analyze_before.txt` — capture the baseline warnings/errors.
4. `flutter test` — see what (if anything) passes today. (Spoiler: there's one boilerplate test in `test/widget_test.dart` that references a counter widget that doesn't exist.)
5. Read these files end-to-end so you have the mental model:
   - `lap_fitness/pubspec.yaml`
   - `lap_fitness/lib/main.dart`
   - `lap_fitness/lib/main_page.dart`
   - `lap_fitness/lib/home_page.dart`
   - `lap_fitness/lib/firebase_options.dart`

Then list the entire `lib/` directory — every file is a flat sibling, no subfolders. That flat layout is one of the things you're going to fix.

---

## 1. What this app is (so you don't break intent)

LAP Fitness is a fitness/wellness tracker backed entirely by Firebase. Current features:

| Feature | File | Backend path |
|---|---|---|
| Email/password auth + password reset | `login_page.dart`, `register_page.dart`, `forgot_pw_page.dart` | Firebase Auth |
| First-time profile capture (age/gender/weight/height/calorie target) | `user_info.dart` | RTDB `/users/{uid}` |
| Bottom-nav shell | `home_page.dart` | — |
| Social feed (posts with privacy toggle) | `feed_page.dart` | RTDB `/feedData` |
| Notes (CRUD, date-tagged) | `note_page.dart` | RTDB `/users/{uid}/notes` |
| Month calendar that filters notes by day | `calendar_page.dart` | RTDB (reads notes) |
| Workout timer/rep counter (push-ups, squats, lunges) | `workout_tracker.dart` | local state |
| Water intake counter | `water_tracker.dart` | RTDB `/waterIntake` **← bug: global, not per-user** |
| Meal/macro tracker | `meal_tracking_page.dart` | RTDB `/meals/{uid}` |
| Privacy / account / "profile" settings | `settings_page.dart`, `privacy_settings_page.dart`, `account_settings_page.dart`, `profile_settings_page.dart` | Firebase Auth + RTDB |

Keep all these features working. The refactor must be **behavior-preserving** unless a section below explicitly says to change behavior (e.g., fixing `/waterIntake` to be per-user, finishing `profile_settings_page.dart`).

---

## 2. Known broken / unfinished parts (verify each before changing)

These are the concrete gaps to close as part of this refactor — go read each file, confirm the problem, then fix it in the relevant phase below.

1. **`lib/profile_settings_page.dart`** — placeholder. Body is just a Text widget that says "Profile Settings Page". `settings_page.dart` doesn't even route here (it routes to `UserInfoPage` instead). Either wire it up to edit the same fields as `UserInfoPage` (age/gender/weight/height/calories) or delete it and rename. Decision: **implement it as the profile editor**, and have `UserInfoPage` be first-time-only.
2. **`lib/themes.dart`** — defined but never used. Uses Flutter 2.x `TextTheme` names (`bodyText1`, `headline1`, etc.) that were renamed in Flutter 3.0. Either delete it or rewrite it as the actual app theme and apply it in `main.dart`. Decision: **rewrite and apply** (see Phase 4).
3. **`lib/home.dart`** — orphan widget displaying "Welcome to the Home Page!". Not imported anywhere. **Delete it.**
4. **`lib/note_page.dart:24`** — `get database => null;` is dead code. **Delete it.**
5. **`/waterIntake` RTDB node** — global across all users in `water_tracker.dart`. Move to `/users/{uid}/waterIntake` and migrate the read/write paths. (No data migration needed — treat existing global value as orphaned.)
6. **`forgot_pw_page.dart`** — calls `Navigator.pushReplacementNamed(context, '/')` but no named routes are registered. Currently relies on Firebase Auth state change to recover. With `go_router` (Phase 3) this becomes `context.go('/login')`.
7. **`/feedData`** — every post is visible to every user, and the "private mode" toggle only anonymizes the author display. Document this as intended (it's the design) but make sure the post model carries `authorUid`, `createdAt`, and `isPrivate` explicitly rather than relying on side-effects.
8. **Unused dependencies in `pubspec.yaml`**: `openfoodfacts`, `http`, `cloud_firestore`, and `google_fonts` are pulled in but never used. Decide per-package in Phase 1 whether to drop or actually use (e.g., `google_fonts` should be wired into the theme; `openfoodfacts` was likely planned for meal lookup — defer that as a follow-up, drop the dep for now).
9. **13 `print()` statements** scattered across `feed_page.dart`, `login_page.dart`, `register_page.dart`, `forgot_pw_page.dart`, `main.dart`. Replace with a real logger (Phase 5).
10. **No `models/`** — everything is `Map<dynamic, dynamic>` cast at the call site. Introduce typed models (Phase 2).
11. **No state management** — pure `setState`. Introduce Riverpod (Phase 3).
12. **No tests** — `test/widget_test.dart` references a counter that doesn't exist. Replace with real tests (Phase 6).
13. **No CI** — add a basic GitHub Actions workflow (Phase 7).
14. **`firebase_options.dart`** throws `UnsupportedError` for Windows/Linux. Leave as-is (those platforms aren't a goal) but confirm the desktop targets we *do* care about (macOS, web) still work.

---

## 3. Phased plan

Each phase is a commit (or a small series). Run `flutter analyze` and `flutter test` after each phase. Do not move to the next phase until the current one is green.

### Phase 1 — Toolchain & dependency upgrades

**Goal:** Get to Dart 3.x and current stable Flutter, with every dependency at a current version, and zero unused deps.

- [ ] Bump Dart SDK constraint in `pubspec.yaml` from `>=2.12.0 <3.0.0` to `>=3.5.0 <4.0.0`.
- [ ] Add an explicit `flutter:` SDK constraint (`>=3.24.0`).
- [ ] Run `flutter pub outdated` and upgrade every package to its current major:
  - `firebase_core`, `firebase_auth`, `firebase_analytics`, `firebase_database`, `cloud_firestore` → latest. After this, regenerate `firebase_options.dart` if needed via `flutterfire configure` is **out of scope** — keep the existing file unless something breaks at build time.
  - `intl`, `shared_preferences`, `uuid`, `cupertino_icons` → latest.
  - `flutter_lints` → latest major. Switch to `package:flutter_lints/flutter.yaml` + add a few targeted custom rules in `analysis_options.yaml` (`prefer_const_constructors`, `prefer_const_literals_to_create_immutables`, `avoid_print`, `unawaited_futures`).
- [ ] **Remove** unused deps from `pubspec.yaml`: `openfoodfacts`, `http`, `cloud_firestore` (only RTDB is used). Leave `google_fonts` in — Phase 4 will wire it up.
- [ ] Run `flutter pub get`, then `dart fix --apply` to auto-migrate trivial deprecations.
- [ ] For every file with `// ignore_for_file: deprecated_member_use` at the top, investigate the real deprecation and fix it properly (most are `FirebaseDatabase.instance.reference()` → `FirebaseDatabase.instance.ref()`). Remove the ignore comment once fixed.
- [ ] Update Android `compileSdkVersion`/`minSdkVersion` in `android/app/build.gradle` if FlutterFire complains (typical minimum is 23 now).
- [ ] Confirm iOS Podfile `platform :ios, '13.0'` or higher (Firebase requires it).
- [ ] **Verify:** `flutter analyze` has *fewer* warnings than the baseline you captured in step 0.4. App builds for Android, iOS, and web (`flutter build apk --debug`, `flutter build ios --no-codesign --debug`, `flutter build web`).

**Commit:** `chore: upgrade to Dart 3 + Flutter stable, drop unused deps`

### Phase 2 — Project structure & typed models

**Goal:** Stop using flat `lib/` and stop passing `Map<dynamic, dynamic>` around.

Move from this:
```
lib/
  main.dart
  feed_page.dart
  ...18 sibling files
```
…to a feature-first layout:
```
lib/
  main.dart
  app/
    app.dart                  // root MaterialApp + theme + router
    router.dart               // go_router config
  core/
    theme/                    // colors, theme, text styles
    logging/                  // logger setup
    firebase/                 // FirebaseDatabase ref helpers
  features/
    auth/
      data/auth_repository.dart
      presentation/login_page.dart
      presentation/register_page.dart
      presentation/forgot_pw_page.dart
      presentation/auth_page.dart
    profile/
      data/profile_repository.dart
      domain/user_profile.dart
      presentation/user_info_page.dart
      presentation/profile_settings_page.dart
    feed/
      data/feed_repository.dart
      domain/post.dart
      presentation/feed_page.dart
    notes/
      data/notes_repository.dart
      domain/note.dart
      presentation/notes_page.dart
      presentation/calendar_page.dart
    workout/
      presentation/workout_tracker_page.dart
    water/
      data/water_repository.dart
      presentation/water_tracker_page.dart
    meals/
      data/meals_repository.dart
      domain/meal.dart
      presentation/meal_tracking_page.dart
    settings/
      presentation/settings_page.dart
      presentation/account_settings_page.dart
      presentation/privacy_settings_page.dart
    shell/
      presentation/home_shell.dart  // formerly home_page.dart
```

- [ ] Create the directory structure above. Move files (use `git mv` so history is preserved). Update every import.
- [ ] For each domain object (`UserProfile`, `Post`, `Note`, `Meal`), create an immutable Dart class with `fromMap` / `toMap` factories. Place under `features/<x>/domain/`. **Don't** add `freezed` yet — keep the dep count low; hand-write `==`, `hashCode`, and `copyWith` (or use Dart 3 records if it fits). Re-evaluate `freezed` only if hand-written boilerplate gets painful.
- [ ] Create a thin repository per feature (e.g., `FeedRepository`) that owns the `FirebaseDatabase.instance.ref(...)` calls and returns/accepts model objects, not Maps. Pages should not touch `FirebaseDatabase` directly anymore.
- [ ] Replace every `Map<dynamic, dynamic>` access in widgets with typed model fields.
- [ ] **Verify:** app still launches and every feature still works end-to-end. Sign up → enter profile → post to feed → write a note → see it on the calendar → log water → log a meal → toggle privacy → sign out.

**Commit:** `refactor: feature-first layout with typed models and repositories`

### Phase 3 — State management (Riverpod) + routing (go_router)

**Goal:** Kill `setState` for anything cross-screen, kill manual `Navigator.push` for navigation.

- [ ] Add `flutter_riverpod` (latest 2.x). Wrap the app in `ProviderScope` in `main.dart`.
- [ ] For each repository created in Phase 2, expose it as a `Provider`.
- [ ] Convert async data screens (`feed_page`, `notes_page`, `meal_tracking_page`, `calendar_page`, `water_tracker_page`, `user_info_page`) from `StatefulWidget` + `setState` to `ConsumerWidget` (or `ConsumerStatefulWidget` where local form state is needed) backed by `StreamProvider`s or `AsyncNotifier`s over the repositories. Local form-only state (e.g., text field controllers, the workout timer) can stay in `setState` — don't over-engineer.
- [ ] Add `go_router` (latest). Define routes in `app/router.dart`:
  - `/` → splash/loading → redirect based on auth + profile-completion state
  - `/login`, `/register`, `/forgot-password`
  - `/onboarding` (user_info first-time)
  - `/home` (shell with bottom-nav child routes: `/home/feed`, `/home/notes`, `/home/dashboard`, `/home/meals`, `/home/calendar`)
  - `/workout`, `/water`
  - `/settings`, `/settings/account`, `/settings/privacy`, `/settings/profile`
- [ ] Use a `redirect` callback that listens to a `authStateProvider` so navigation reacts to sign-in/sign-out automatically. This fixes the `forgot_pw_page.dart` broken named-route bug.
- [ ] Replace every `Navigator.of(context).push(MaterialPageRoute(...))` with `context.go(...)` / `context.push(...)`.
- [ ] **Verify:** sign-in → home, sign-out → login, sign-up flow → onboarding → home, deep link to `/home/notes` works, back stack is sane.

**Commit:** `refactor: introduce Riverpod and go_router`

### Phase 4 — Design system & theming

**Goal:** Stop hardcoding `Color.fromARGB(255, 138, 104, 35)` in 18 files. One Material 3 theme, one place.

- [ ] Rewrite `lib/core/theme/app_colors.dart` with named tokens (`primary`, `onPrimary`, `surface`, `outline`, etc.) using the existing brown as the seed color.
- [ ] In `lib/core/theme/app_theme.dart`, build a `ThemeData` with `useMaterial3: true` and `colorScheme: ColorScheme.fromSeed(seedColor: AppColors.brand)`. Apply both light and dark themes.
- [ ] Wire `google_fonts` (already in pubspec) into the text theme — pick one font (e.g., Inter or Manrope) and apply via `GoogleFonts.interTextTheme(...)`.
- [ ] Apply the theme in `app/app.dart` and remove every inline `ThemeData(...)` and every hardcoded `Color.fromARGB`.
- [ ] Delete the old `lib/themes.dart` once nothing references it.
- [ ] **Verify:** entire app uses the theme; toggle system dark mode in the simulator and confirm dark theme renders correctly. No remaining `Color.fromARGB` or hex literals in screen files — `grep -r "Color.fromARGB\|Color(0x" lib/features lib/app` should return nothing.

**Commit:** `feat(theme): Material 3 theme with seeded color scheme and Google Fonts`

### Phase 5 — Hygiene: logging, errors, deprecations, dead code

- [ ] Add `logger` (or `logging` from dart team) under `core/logging/`. Replace every `print(...)` with a logger call at the appropriate level. The new `avoid_print` lint should now pass.
- [ ] Wrap every Firebase call in a try/catch in the repositories. Surface failures to the UI via `AsyncValue.error` (Riverpod) instead of silent `onError` no-ops. Show a `SnackBar` for user-visible errors.
- [ ] Add `FirebaseCrashlytics` (optional but recommended) and hook it into `FlutterError.onError` and `PlatformDispatcher.instance.onError`. Skip if it adds friction; logging alone is fine.
- [ ] Move the `/waterIntake` node to `/users/{uid}/waterIntake` in `WaterRepository`. Confirm the Water page reads/writes the per-user value.
- [ ] Implement `profile_settings_page.dart` properly — it should let the user edit the same fields as `user_info.dart` and save back to `/users/{uid}`. Have `settings_page.dart` route here instead of to `UserInfoPage`.
- [ ] Delete `lib/home.dart`, the `get database => null;` line in `note_page.dart`, the old `themes.dart` (already deleted in Phase 4), and any other dead files.
- [ ] **Verify:** `flutter analyze` reports **zero** issues. Smoke-test every screen.

**Commit:** `chore: logging, error handling, dead code removal, fix waterIntake scope, implement profile settings`

### Phase 6 — Tests

**Goal:** Replace the empty boilerplate test with a real safety net.

- [ ] Delete `test/widget_test.dart` boilerplate. Create `test/` subfolders matching the feature folders.
- [ ] **Unit tests** for every model (`UserProfile`, `Post`, `Note`, `Meal`) — round-trip `fromMap`/`toMap`.
- [ ] **Repository tests** using `firebase_database_mocks` (or hand-rolled fakes via repository interfaces). Cover the happy path and one error path per repo.
- [ ] **Widget tests** for the most important screens: login form validation, feed empty state, notes CRUD, meal totals calculation. Use `ProviderScope(overrides: [...])` to inject fake repositories.
- [ ] **Goal:** > 40% line coverage. Run with `flutter test --coverage` and confirm `coverage/lcov.info` is produced.

**Commit:** `test: introduce unit, repository, and widget tests`

### Phase 7 — CI

- [ ] Add `.github/workflows/ci.yml` running on push and PR:
  - `flutter pub get`
  - `dart format --output=none --set-exit-if-changed .`
  - `flutter analyze`
  - `flutter test --coverage`
- [ ] Cache the pub cache and Flutter SDK between runs.
- [ ] Get the workflow green on the branch before claiming this phase done.

**Commit:** `ci: add Flutter analyze + test workflow`

---

## 4. Out of scope (do not do)

- Migrating from Realtime Database to Firestore. Keep RTDB. (`cloud_firestore` was an unused import; remove it.)
- Wiring up the `openfoodfacts` library for meal lookup. Defer.
- Rewriting the `landing/` Next.js site.
- Adding new features beyond what's listed in Phase 5 fixes (profile settings, per-user water).
- Changing the visual identity beyond applying a theme. Same brown brand color.

---

## 5. Definition of done

- [ ] `flutter analyze` → 0 issues.
- [ ] `flutter test` → all green, > 40% coverage.
- [ ] `flutter build apk --debug`, `flutter build ios --no-codesign --debug`, `flutter build web` all succeed.
- [ ] Manual smoke test: sign up → onboarding → home → post → note → calendar → workout → water → meal → settings (privacy, account, profile) → sign out → forgot password → sign back in. All work.
- [ ] No `print()`, no hardcoded `Color.fromARGB`, no `Map<dynamic, dynamic>` in widget code, no `// ignore_for_file: deprecated_member_use`.
- [ ] `lib/` follows the feature-first layout in Phase 2.
- [ ] CI workflow is green on the branch.
- [ ] README at repo root updated with the new Flutter version requirement and a one-paragraph description of what the app does.

---

## 6. Operating rules for the assistant doing this work

- Work on branch `claude/flutter-modernization-guide-TLRW0` (or a child branch). Commit per phase. Push after each phase.
- After every phase, paste a short status update: what changed, what `flutter analyze` and `flutter test` say now, what's next.
- If a phase is bigger than expected, split it — don't ship half-done work in a single commit.
- If you discover something this plan got wrong (e.g., a dependency has no current major, a file referenced here was deleted), call it out in your status update and propose a correction before doing it.
- Do not invent features. Do not redesign the UI. Do not migrate the backend. Stay inside scope.
