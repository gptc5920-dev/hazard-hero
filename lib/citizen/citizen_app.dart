import 'package:flutter/material.dart';
import 'package:responsive_framework/responsive_framework.dart';
import '../shared/theme/app_theme.dart';
import 'routes/citizen_router.dart';

class CitizenApp extends StatelessWidget {
  const CitizenApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp.router(
    debugShowCheckedModeBanner: false,
    title: 'Hazard Hero Citizen',
    theme: AppTheme.citizen(),
    builder: (context, child) => ResponsiveBreakpoints.builder(
      child: child ?? const SizedBox.shrink(),
      breakpoints: const [
        Breakpoint(start: 0, end: 599, name: MOBILE),
        Breakpoint(start: 600, end: 1023, name: TABLET),
        Breakpoint(start: 1024, end: 1919, name: DESKTOP),
        Breakpoint(start: 1920, end: double.infinity, name: '4K'),
      ],
    ),
    routerConfig: citizenRouter,
  );
}
