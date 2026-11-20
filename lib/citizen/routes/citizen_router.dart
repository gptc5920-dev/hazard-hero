import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/widgets/branded_splash_screen.dart';
import '../screens/citizen_landing_screen.dart';
import '../screens/citizen_shell.dart';
import '../screens/citizen_menu_screen.dart';
import '../screens/content_list_screen.dart';
import '../screens/downloads_screen.dart';
import '../screens/guideline_detail_screen.dart';
import '../screens/home_screen.dart';
import '../screens/record_detail_screen.dart';

final citizenRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, _) =>
          BrandedSplashScreen(onFinished: () => context.go('/welcome')),
    ),
    GoRoute(path: '/welcome', builder: (_, __) => const CitizenLandingScreen()),
    ShellRoute(
      builder: (context, state, child) => CitizenShell(child: child),
      routes: citizenContentRoutes(),
    ),
  ],
);

/// Public information screens shared by residents and field responders.
List<RouteBase> citizenContentRoutes({
  bool includeHome = true,
  bool includeMenu = true,
}) => [
  if (includeHome)
    GoRoute(path: '/', builder: (_, __) => const CitizenHomeScreen()),
  GoRoute(
    path: '/go-bag',
    builder: (_, __) => const ContentListScreen(
      module: 'go-bag',
      title: 'Go Bag',
      icon: Icons.backpack,
    ),
  ),
  GoRoute(
    path: '/go-bag/:id',
    builder: (_, state) => CitizenRecordDetailScreen(
      module: 'go-bag',
      recordId: state.pathParameters['id']!,
      pageTitle: 'Go Bag item',
    ),
  ),
  GoRoute(
    path: '/calamities',
    builder: (_, __) => const ContentListScreen(
      module: 'calamities',
      title: 'Calamities',
      icon: Icons.storm,
    ),
  ),
  GoRoute(
    path: '/calamities/:id',
    builder: (_, state) => CitizenRecordDetailScreen(
      module: 'calamities',
      recordId: state.pathParameters['id']!,
      pageTitle: 'Calamity information',
    ),
  ),
  GoRoute(
    path: '/guidelines',
    builder: (_, __) => const ContentListScreen(
      module: 'guidelines',
      title: 'Guidelines',
      icon: Icons.menu_book,
    ),
  ),
  GoRoute(
    path: '/guidelines/:slug',
    builder: (_, s) => GuidelineDetailScreen(slug: s.pathParameters['slug']!),
  ),
  GoRoute(
    path: '/evacuation-centers',
    builder: (_, __) => const ContentListScreen(
      module: 'evacuation-centers',
      title: 'Evacuation Centers',
      icon: Icons.location_on,
    ),
  ),
  GoRoute(
    path: '/evacuation-centers/:id',
    builder: (_, state) => CitizenRecordDetailScreen(
      module: 'evacuation-centers',
      recordId: state.pathParameters['id']!,
      pageTitle: 'Evacuation center',
    ),
  ),
  GoRoute(
    path: '/emergency-contacts',
    builder: (_, __) => const ContentListScreen(
      module: 'emergency-contacts',
      title: 'Emergency Contacts',
      icon: Icons.call,
    ),
  ),
  GoRoute(
    path: '/emergency-contacts/:id',
    builder: (_, state) => CitizenRecordDetailScreen(
      module: 'emergency-contacts',
      recordId: state.pathParameters['id']!,
      pageTitle: 'Emergency contact',
    ),
  ),
  GoRoute(
    path: '/alerts',
    builder: (_, __) => const ContentListScreen(
      module: 'alerts',
      title: 'Active Alerts',
      icon: Icons.warning,
    ),
  ),
  GoRoute(
    path: '/alerts/:id',
    builder: (_, state) => CitizenRecordDetailScreen(
      module: 'alerts',
      recordId: state.pathParameters['id']!,
      pageTitle: 'Emergency alert',
    ),
  ),
  GoRoute(path: '/downloads', builder: (_, __) => const DownloadsScreen()),
  if (includeMenu)
    GoRoute(path: '/more', builder: (_, __) => const CitizenMenuScreen()),
];
