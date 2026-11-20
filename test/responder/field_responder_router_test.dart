import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_hero/citizen/core/citizen_providers.dart';
import 'package:hazard_hero/responder/core/responder_providers.dart';
import 'package:hazard_hero/responder/models/responder_models.dart';
import 'package:hazard_hero/responder/repositories/responder_repository.dart';
import 'package:hazard_hero/responder/routes/field_responder_router.dart';
import 'package:hazard_hero/responder/services/responder_api_service.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:hazard_hero/shared/storage/secure_token_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuth extends AuthController {
  _TestAuth(ResponderRepository repository, {required bool signedIn})
    : super(repository, SessionEvents()) {
    state = AuthState(
      user: signedIn
          ? const ResponderUser(
              id: 'a',
              email: 'a@example.test',
              name: 'Responder A',
              office: 'Rescue',
            )
          : null,
    );
  }

  @override
  Future<void> logout() async => state = const AuthState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> container(bool signedIn) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final client = ApiClient();
    addTearDown(client.close);
    final repo = ResponderRepository(
      ResponderApiService(client),
      SecureTokenStorage(),
    );
    final result = ProviderContainer(
      overrides: [
        preferencesProvider.overrideWithValue(prefs),
        authProvider.overrideWith((_) => _TestAuth(repo, signedIn: signedIn)),
        connectivityProvider.overrideWith((_) => Stream.value(false)),
        publicRecordsProvider.overrideWith((_, module) async => []),
        languagesProvider.overrideWith((_) async => []),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  testWidgets('inventory requires login', (tester) async {
    final scope = await container(false);
    final router = scope.read(fieldResponderRouterProvider);
    router.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, responder'), findsOneWidget);
    expect(find.text('Equipment inventory'), findsNothing);
    expect(router.routeInformationProvider.value.uri.path, '/login');
  });

  testWidgets('responders can open sign-up from login and return to login', (
    tester,
  ) async {
    final scope = await container(false);
    final router = scope.read(fieldResponderRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    final signup = find.text('New responder? Sign up');
    await tester.ensureVisible(signup);
    await tester.tap(signup);
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/signup');
    expect(find.text('Create your responder account'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to login'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, responder'), findsOneWidget);
  });

  testWidgets(
    'field responder has resident routes and equipment without admin navigation',
    (tester) async {
      final scope = await container(true);
      final router = scope.read(fieldResponderRouterProvider);
      final shell = router.configuration.routes.whereType<ShellRoute>().single;
      final paths = shell.routes
          .whereType<GoRoute>()
          .map((route) => route.path)
          .toSet();
      expect(
        paths,
        containsAll([
          '/',
          '/inventory',
          '/go-bag',
          '/guidelines',
          '/calamities',
          '/alerts',
          '/evacuation-centers',
          '/emergency-contacts',
          '/downloads',
        ]),
      );
      expect(
        paths.intersection({
          '/responders',
          '/audit-logs',
          '/translations',
          '/languages',
          '/dashboard',
        }),
        isEmpty,
      );
      router.go('/inventory');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: scope,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hazard Hero Responder'), findsOneWidget);
      expect(find.text('Equipment inventory'), findsOneWidget);
      expect(find.text('ADMIN'), findsNothing);
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Equipment inventory'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();
      expect(find.text('Welcome back, responder'), findsOneWidget);
      expect(find.text('Equipment inventory'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('expired sessions clear the inventory screen and require login', (
    tester,
  ) async {
    final scope = await container(true);
    final router = scope.read(fieldResponderRouterProvider);
    router.go('/inventory');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: scope,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    scope.read(authProvider.notifier).expire();
    await tester.pumpAndSettle();
    expect(find.text('Welcome back, responder'), findsOneWidget);
    expect(find.text('Equipment inventory'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
