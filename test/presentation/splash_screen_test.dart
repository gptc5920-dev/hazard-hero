import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/app/splash_screen.dart';

void main() {
  testWidgets('splash displays brand and startup progress', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));

    expect(find.text('Hazard Hero'), findsOneWidget);
    expect(find.text('Ready. Resilient. Together.'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
