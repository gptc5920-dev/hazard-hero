import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/core/responder_providers.dart';
import 'package:hazard_hero/responder/screens/login_screen.dart';
import 'package:hazard_hero/responder/screens/signup_screen.dart';
import 'package:hazard_hero/responder/services/responder_api_service.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets(
    'mobile sign-up validates confirmation, keeps errors editable, and confirms pending verification',
    (tester) async {
      tester.view.physicalSize = const Size(400, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var attempts = 0;
      final client = ApiClient(
        client: MockClient((request) async {
          attempts++;
          expect(request.url.path, '/api/responder/auth/signup/');
          expect(request.headers.containsKey('authorization'), isFalse);
          final body = jsonDecode(request.body) as Map;
          expect(body['email'], 'mira@example.com');
          expect(body['first_name'], 'Mira');
          expect(body['password'], 'StrongRescue123!');
          expect(body.containsKey('is_verified'), isFalse);
          return attempts == 1
              ? http.Response(
                  jsonEncode({
                    'success': false,
                    'message': 'Invalid request',
                    'errors': {
                      'email': ['An account with this email already exists.'],
                    },
                  }),
                  400,
                )
              : http.Response(
                  jsonEncode({
                    'success': true,
                    'data': {'detail': 'Account created'},
                  }),
                  201,
                );
        }),
      );
      addTearDown(client.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            responderApiProvider.overrideWithValue(ResponderApiService(client)),
          ],
          child: const MaterialApp(home: ResponderSignupScreen()),
        ),
      );
      Future<void> fill(String label, String value) async {
        final field = find.widgetWithText(TextFormField, label);
        await tester.ensureVisible(field);
        await tester.enterText(field, value);
      }

      Future<void> submit() async {
        final button = find.text('Create account');
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await fill('First name', 'Mira');
      await fill('Last name', 'Reyes');
      await fill('Email', 'MIRA@example.com');
      await fill('Password', 'StrongRescue123!');
      await fill('Confirm password', 'Mismatch123!');
      await submit();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(attempts, 0);
      await fill('Confirm password', 'StrongRescue123!');
      await submit();
      expect(
        find.textContaining('An account with this email already exists.'),
        findsOneWidget,
      );
      expect(find.text('Account created'), findsNothing);
      expect(
        find.widgetWithText(TextFormField, 'MIRA@example.com'),
        findsOneWidget,
      );
      await submit();
      expect(find.text('Account created'), findsOneWidget);
      expect(
        find.textContaining('awaiting admin verification'),
        findsOneWidget,
      );
      expect(find.text('Back to login'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('admin login does not offer public sign-up', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ResponderLoginScreen(admin: true)),
      ),
    );
    expect(find.text('Hazard Hero Admin'), findsOneWidget);
    expect(find.text('New responder? Sign up'), findsNothing);
  });
}
