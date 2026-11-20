import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../citizen/routes/citizen_router.dart';
import '../core/responder_providers.dart';
import '../inventory/equipment_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/field_responder_shell.dart';
import '../screens/field_responder_home.dart';
import '../screens/login_screen.dart';
import '../screens/signup_screen.dart';
import '../screens/reset_password_screen.dart';

final fieldResponderRouterProvider = Provider<GoRouter>((ref) {
  final authenticated = ValueNotifier(ref.read(authProvider).authenticated);
  ref.listen<bool>(
    authProvider.select((state) => state.authenticated),
    (_, next) => authenticated.value = next,
  );
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authenticated,
    redirect: (_, state) {
      final authRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup' ||
          state.matchedLocation == '/reset-password';
      if (!authenticated.value) return authRoute ? null : '/login';
      return state.matchedLocation == '/login' ||
              state.matchedLocation == '/signup'
          ? '/'
          : null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const ResponderLoginScreen()),
      GoRoute(
        path: '/signup',
        builder: (_, __) => const ResponderSignupScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          uid: state.uri.queryParameters['uid'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => FieldResponderShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, __) => const FieldResponderHome()),
          GoRoute(
            path: '/inventory',
            builder: (_, __) => const EquipmentScreen(),
          ),
          GoRoute(
            path: '/more',
            builder: (_, __) => const FieldResponderMenu(),
          ),
          GoRoute(
            path: '/account',
            builder: (_, __) => const AccountSettingsScreen(),
          ),
          ...citizenContentRoutes(includeHome: false, includeMenu: false),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    authenticated.dispose();
  });
  return router;
});
