import 'package:flutter/material.dart';

import 'app/app_dependencies.dart';
import 'app/hazard_hero_app.dart';
import 'app/splash_screen.dart';

/// Legacy offline-first workspace entry point.
///
/// The API-backed administrator/responder application is the default entry
/// point in [main.dart]. Run this file explicitly only when the standalone
/// local SQLite workspace is required.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HazardHeroBootstrap());
}

class HazardHeroBootstrap extends StatefulWidget {
  const HazardHeroBootstrap({super.key});

  @override
  State<HazardHeroBootstrap> createState() => _HazardHeroBootstrapState();
}

class _HazardHeroBootstrapState extends State<HazardHeroBootstrap> {
  late final Future<AppDependencies> _initialization = _initialize();

  Future<AppDependencies> _initialize() async {
    final results = await Future.wait<Object?>([
      AppDependencies.create(),
      Future<void>.delayed(const Duration(milliseconds: 1400)),
    ]);
    return results.first as AppDependencies;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppDependencies>(
    future: _initialization,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return HazardHeroApp(dependencies: snapshot.data!);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Hazard Hero 2.0',
        home: SplashScreen(error: snapshot.error),
      );
    },
  );
}
