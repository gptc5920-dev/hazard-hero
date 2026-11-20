import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'responder/app/responder_app_bootstrap.dart';
import 'responder/responder_app.dart';
import 'shared/app/system_ui.dart';

/// The existing administration console has its own Android package.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureSystemUi();
  await ResponderAppBootstrap.initialize();
  runApp(const ProviderScope(child: ResponderApp()));
}
