import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hazard_hero/citizen/citizen_app.dart';
import 'package:hazard_hero/citizen/core/citizen_providers.dart';
import 'package:hazard_hero/citizen/models/citizen_models.dart';
import 'package:hazard_hero/citizen/routes/citizen_router.dart';
import 'package:hazard_hero/citizen/screens/content_list_screen.dart';
import 'package:hazard_hero/citizen/screens/home_screen.dart';
import 'package:hazard_hero/citizen/screens/record_detail_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const languages = [
    LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      isDefault: true,
    ),
    LanguageOption(
      code: 'fil',
      name: 'Filipino',
      nativeName: 'Filipino',
      isDefault: false,
    ),
    LanguageOption(
      code: 'ceb',
      name: 'Bisaya',
      nativeName: 'Bisaya',
      isDefault: false,
    ),
  ];

  testWidgets('citizen application launches without login controls', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    citizenRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          languagesProvider.overrideWith((_) async => languages),
        ],
        child: const CitizenApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Prepared communities save lives.'), findsOneWidget);
    expect(find.text('Explore safety information'), findsOneWidget);
    expect(find.text('Sign in'), findsNothing);

    final exploreButton = find.text('Explore safety information');
    await tester.ensureVisible(exploreButton);
    await tester.pumpAndSettle();
    await tester.tap(exploreButton);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.home_outlined), findsWidgets);
    expect(find.byKey(const Key('home-notifications')), findsOneWidget);
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Sign in'), findsNothing);
  });

  testWidgets('language button translates citizen navigation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    citizenRouter.go('/splash');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          languagesProvider.overrideWith((_) async => languages),
        ],
        child: const CitizenApp(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Filipino'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      find.text('Ang handang komunidad ay nagliligtas ng buhay.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('language-selector')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Bisaya'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final exploreButton = find.text('Tan-awa ang impormasyon sa kaluwasan');
    await tester.ensureVisible(exploreButton);
    await tester.pumpAndSettle();
    await tester.tap(exploreButton);
    await tester.pumpAndSettle();

    expect(find.text('Balay'), findsWidgets);
    expect(find.text('Ebakuwasyon'), findsWidgets);
    expect(find.text('Mga Hotline'), findsWidgets);
    expect(find.text('Go Bag'), findsWidgets);
    expect(find.text('Mga Giya'), findsWidgets);
    expect(prefs.getString('citizen_language'), 'ceb');
  });

  testWidgets('go bag checklist saves prepared items for offline use', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final items = [
      const PublicRecord({
        'id': 'bag-1',
        'name': 'Drinking Water',
        'description': 'Three-day supply',
        'quantity': 3,
        'unit': 'liters',
      }),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          publicRecordsProvider.overrideWith(
            (_, module) async => module == 'go-bag' ? items : const [],
          ),
        ],
        child: const MaterialApp(
          home: ContentListScreen(
            module: 'go-bag',
            title: 'Go Bag',
            icon: Icons.backpack_rounded,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.text('0 / 1 items prepared'), findsOneWidget);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    expect(find.text('1 / 1 items prepared'), findsOneWidget);
    expect(prefs.getStringList('citizen_go_bag_checked_items'), ['bag-1']);
  });

  testWidgets('notification badge stays hidden after alerts are viewed', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final alert = const PublicRecord({
      'id': 'alert-1',
      'title': 'Flood warning',
      'message': 'Rising water',
      'version': 2,
    });
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, __) => const CitizenHomeScreen()),
        GoRoute(
          path: '/alerts',
          builder: (_, __) =>
              const Scaffold(body: Center(child: Text('Alert feed'))),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          publicRecordsProvider.overrideWith(
            (_, module) async => module == 'alerts' ? [alert] : const [],
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('home-notification-badge')), findsOneWidget);
    await tester.tap(find.byKey(const Key('home-notifications')));
    await tester.pumpAndSettle();

    expect(find.text('Alert feed'), findsOneWidget);
    expect(prefs.getStringList('citizen_viewed_alert_versions'), ['alert-1:2']);

    router.go('/');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home-notification-badge')), findsNothing);
  });

  testWidgets('evacuation center embeds a map and directions control', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final center = const PublicRecord({
      'id': 'center-1',
      'name': 'Central School',
      'description': 'Community evacuation center',
      'street_address': 'Main Street',
      'barangay': 'Central',
      'city_municipality': 'Dipolog',
      'province': 'Zamboanga del Norte',
      'latitude': '8.5000000',
      'longitude': '123.2800000',
      'available_slots': 80,
      'availability_status': 'Available',
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesProvider.overrideWithValue(prefs),
          publicRecordsProvider.overrideWith(
            (_, module) async =>
                module == 'evacuation-centers' ? [center] : const [],
          ),
        ],
        child: const MaterialApp(
          home: CitizenRecordDetailScreen(
            module: 'evacuation-centers',
            recordId: 'center-1',
            pageTitle: 'Evacuation center',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.text('Get directions'), findsOneWidget);
  });
}
