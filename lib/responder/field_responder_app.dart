import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/branded_splash_screen.dart';
import 'core/responder_providers.dart';
import 'routes/field_responder_router.dart';

/// Field client: public resident information plus account-local equipment.
class FieldResponderApp extends ConsumerStatefulWidget {
  const FieldResponderApp({super.key});
  @override
  ConsumerState<FieldResponderApp> createState() => _FieldResponderAppState();
}

class _FieldResponderAppState extends ConsumerState<FieldResponderApp> {
  bool _restoring = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(authProvider.notifier).restore();
      if (mounted) setState(() => _restoring = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Keep the router mounted while a login request is pending so form state,
    // validation errors, and the loading indicator remain in the login screen.
    if (_restoring) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.responder(),
        home: const BrandedSplashScreen(),
      );
    }
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Hazard Hero Responder',
      theme: AppTheme.responder(),
      routerConfig: ref.watch(fieldResponderRouterProvider),
    );
  }
}
