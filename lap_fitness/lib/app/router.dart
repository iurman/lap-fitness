import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/go_router_refresh_stream.dart';
import '../core/providers.dart';
import '../features/auth/presentation/forgot_pw_page.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/register_page.dart';
import '../features/profile/presentation/user_info_page.dart';
import '../features/settings/presentation/account_settings_page.dart';
import '../features/settings/presentation/privacy_settings_page.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/shell/presentation/home_shell.dart';
import '../features/shell/presentation/loading_page.dart';
import '../features/water/presentation/water_tracker_page.dart';
import '../features/workout/presentation/workout_tracker_page.dart';

/// Route path constants to avoid stringly-typed navigation scattered around.
abstract final class Routes {
  static const login = '/login';
  static const register = '/register';
  static const forgotPassword = '/forgot-password';
  static const loading = '/loading';
  static const onboarding = '/onboarding';
  static const home = '/home';
  static const editProfile = '/home/edit-profile';
  static const settings = '/settings';
  static const account = '/settings/account';
  static const privacy = '/settings/privacy';
  static const workout = '/workout';
  static const water = '/water';
}

final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);

  final router = GoRouter(
    initialLocation: Routes.login,
    refreshListenable: GoRouterRefreshStream(authRepo.authStateChanges()),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      // Wait for the first auth event before deciding anything.
      if (authState.isLoading) return null;

      final loggedIn = authState.value != null;
      final location = state.matchedLocation;
      const authRoutes = {
        Routes.login,
        Routes.register,
        Routes.forgotPassword,
      };
      final onAuthRoute = authRoutes.contains(location);

      if (!loggedIn) {
        return onAuthRoute ? null : Routes.login;
      }
      // Signed in but still on an auth screen: hand off to the loading gate,
      // which decides between onboarding and home based on profile state.
      if (onAuthRoute) return Routes.loading;
      return null;
    },
    routes: [
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: Routes.forgotPassword,
        builder: (context, state) => const ForgotPasswordPage(),
      ),
      GoRoute(
        path: Routes.loading,
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const UserInfoPage(isOnboarding: true),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomePage(),
        routes: [
          GoRoute(
            path: 'edit-profile',
            builder: (context, state) =>
                const UserInfoPage(isOnboarding: false),
          ),
        ],
      ),
      GoRoute(
        path: Routes.settings,
        builder: (context, state) => SettingsPage(),
        routes: [
          GoRoute(
            path: 'account',
            builder: (context, state) => AccountSettingsPage(),
          ),
          GoRoute(
            path: 'privacy',
            builder: (context, state) => PrivacySettingsPage(
                userId: ref.read(authRepositoryProvider).currentUid ?? ''),
          ),
        ],
      ),
      GoRoute(
        path: Routes.workout,
        builder: (context, state) => WorkoutTracker(),
      ),
      GoRoute(
        path: Routes.water,
        builder: (context, state) => WaterTracker(),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});
