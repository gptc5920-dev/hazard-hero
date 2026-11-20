import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/screens/login_screen.dart';

void main() {
  testWidgets('responder login provides secure authentication controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResponderLoginScreen())),
    );
    expect(find.text('Hazard Hero Responder'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Email'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.byIcon(Icons.visibility), findsOneWidget);
    expect(find.textContaining('Responder API'), findsNothing);
    expect(find.textContaining('hazardheroapi.site'), findsNothing);
  });

  testWidgets('forgot-password dialog validates email before submission', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ResponderLoginScreen())),
    );

    await tester.tap(find.text('Forgot password?'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email address'),
      'invalid-email',
    );
    await tester.tap(find.text('Send instructions'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);
  });
}
