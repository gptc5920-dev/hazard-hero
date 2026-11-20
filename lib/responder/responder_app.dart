import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../shared/theme/app_theme.dart';
import '../shared/widgets/branded_splash_screen.dart';
import 'core/responder_providers.dart';
import 'routes/responder_router.dart';

class ResponderApp extends ConsumerStatefulWidget {
  const ResponderApp({super.key});
  @override
  ConsumerState<ResponderApp> createState() => _State();
}

class _State extends ConsumerState<ResponderApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(authProvider.notifier).restore());
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (auth.loading)
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.responder(),
        builder: _responsiveBuilder,
        home: const BrandedSplashScreen(),
      );
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Hazard Hero Admin',
      theme: AppTheme.responder(),
      builder: _responsiveBuilder,
      routerConfig: ref.watch(responderRouterProvider),
    );
  }
}

Widget _responsiveBuilder(BuildContext context, Widget? child) =>
    ResponsiveBreakpoints.builder(
      child: child ?? const SizedBox.shrink(),
      breakpoints: const [
        Breakpoint(start: 0, end: 599, name: MOBILE),
        Breakpoint(start: 600, end: 1023, name: TABLET),
        Breakpoint(start: 1024, end: 1919, name: DESKTOP),
        Breakpoint(start: 1920, end: double.infinity, name: '4K'),
      ],
    );
