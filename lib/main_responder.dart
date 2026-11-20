import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'citizen/app/citizen_app_bootstrap.dart';
import 'citizen/core/citizen_providers.dart';
import 'responder/field_responder_app.dart';
import 'shared/app/system_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSystemUi();
  final prefs = await CitizenAppBootstrap.initialize();
  runApp(
    ProviderScope(
      overrides: [preferencesProvider.overrideWithValue(prefs)],
      child: const FieldResponderApp(),
    ),
  );
}
