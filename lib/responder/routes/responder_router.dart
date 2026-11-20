import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/modules.dart';
import '../core/responder_providers.dart';
import '../screens/audit_logs_screen.dart';
import '../screens/account_settings_screen.dart';
import '../screens/crud_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/languages_screen.dart';
import '../screens/login_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/responder_shell.dart';
import '../screens/translations_screen.dart';

final responderRouterProvider = Provider<GoRouter>((ref) {
  final authenticated = ref.watch(authProvider.select((x) => x.authenticated));
  final router = GoRouter(
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final login = state.matchedLocation == '/login';
      final resetPassword = state.matchedLocation == '/reset-password';
      if (!authenticated) return login || resetPassword ? null : '/login';
      if (login) return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const ResponderLoginScreen(admin: true),
      ),
      GoRoute(
        path: '/reset-password',
        builder: (_, state) => ResetPasswordScreen(
          uid: state.uri.queryParameters['uid'] ?? '',
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (_, __, child) => ResponderShell(child: child),
        routes: [
          GoRoute(
            path: '/dashboard',
            builder: (_, __) => const ResponderDashboardScreen(),
          ),
          for (final m in responderModules)
            GoRoute(
              path: m.path == 'accounts' ? '/responders' : '/${m.path}',
              builder: (_, __) => CrudScreen(module: m),
            ),
          GoRoute(
            path: '/translations',
            builder: (_, __) => const TranslationsScreen(),
          ),
          GoRoute(
            path: '/languages',
            builder: (_, __) => const LanguagesScreen(),
          ),
          GoRoute(
            path: '/account',
            builder: (_, __) => const AccountSettingsScreen(),
          ),
          GoRoute(
            path: '/audit-logs',
            builder: (_, __) => const AuditLogsScreen(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
