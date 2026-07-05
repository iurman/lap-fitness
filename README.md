# lap-fitness

LAP Fitness is a Flutter fitness and wellness tracker backed by Firebase
(Auth + Realtime Database). It supports email/password sign-up with a
first-time profile (age, gender, weight, height, calorie target), a shared
social feed with a privacy toggle, date-tagged notes and a month calendar, a
workout rep/timer tracker, per-user water intake, and a meal/macro tracker,
plus account and privacy settings. The app is organized feature-first with
typed models and repositories, Riverpod for state, go_router for navigation,
and a Material 3 theme.

The Flutter app lives in [`lap_fitness/`](lap_fitness). There is also a
`landing/` Next.js waitlist site (independent of the app).

## Getting started

1. Clone the repository to your local machine.
2. Install **Flutter 3.24 or newer** (developed against Flutter 3.44 / Dart
   3.x) and add it to your `PATH`.
3. Run `flutter pub get` in the `lap_fitness` folder to install dependencies.
4. Run `flutter run` (or open the project in your editor) from `lap_fitness`.

## Development

From the `lap_fitness` directory:

- `flutter analyze` — static analysis (kept at zero issues).
- `dart format .` — formatting (enforced in CI).
- `flutter test --coverage` — unit and widget tests.

CI runs analyze, format check, and tests on every push and pull request
(see `.github/workflows/ci.yml`).

## License

This project is licensed under the [GPL-3.0 License](https://opensource.org/licenses/GPL-3.0).
