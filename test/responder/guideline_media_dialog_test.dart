import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/screens/guideline_media_dialog.dart';
import 'package:hazard_hero/responder/services/responder_api_service.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('responder can add an embedded guideline video', (tester) async {
    final records = <Map<String, dynamic>>[];
    final api = ResponderApiService(
      ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            final body = (jsonDecode(request.body) as Map)
                .cast<String, dynamic>();
            final created = <String, dynamic>{
              'id': 'media-1',
              ...body,
              'media_file': null,
            };
            records.add(created);
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'created',
                'data': created,
                'errors': null,
              }),
              201,
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'data': {'results': records},
              'errors': null,
            }),
            200,
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => GuidelineMediaDialog(
                      api: api,
                      guidelineId: 'guideline-1',
                      guidelineTitle: 'Flood Safety',
                    ),
                  ),
                ),
                child: const Text('Manage media'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage media'));
    await tester.pumpAndSettle();
    expect(find.text('No media added yet'), findsOneWidget);

    await tester.tap(find.text('Add first media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Embed link'));
    await tester.pump();
    await tester.tap(find.text('Image').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Video').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title *'),
      'Preparedness video',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'HTTPS media link *'),
      'https://youtu.be/dQw4w9WgXcQ',
    );
    await tester.tap(find.text('Add media').last);
    await tester.pumpAndSettle();

    expect(find.text('Preparedness video'), findsOneWidget);
    expect(find.text('Embedded link'), findsOneWidget);
    expect(records.single['source_type'], 'link');
    expect(records.single['media_type'], 'video');

    await tester.tap(find.byTooltip('Close media manager'));
    await tester.pumpAndSettle();
    expect(find.text('Manage media'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('API failures open a safe modal and keep the media form open', (
    tester,
  ) async {
    final api = ResponderApiService(
      ApiClient(
        client: MockClient((request) async {
          if (request.method == 'POST') {
            return http.Response(
              '<?xml version="1.0"?><Error><Code>UploadFailed</Code></Error>',
              500,
              headers: {'content-type': 'application/xml'},
            );
          }
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'data': {'results': <Object>[]},
              'errors': null,
            }),
            200,
          );
        }),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => GuidelineMediaDialog(
                    api: api,
                    guidelineId: 'guideline-1',
                    guidelineTitle: 'Flood Safety',
                  ),
                ),
              ),
              child: const Text('Manage media'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Manage media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add first media'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Embed link'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Title *'),
      'Safety illustration',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'HTTPS media link *'),
      'https://example.com/safety.png',
    );
    await tester.tap(find.text('Add media').last);
    await tester.pumpAndSettle();

    expect(find.text('Unable to add guideline media'), findsOneWidget);
    expect(find.text('The request could not be completed.'), findsOneWidget);
    expect(find.textContaining('<?xml'), findsNothing);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Add guideline media'), findsOneWidget);
    expect(find.text('Safety illustration'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
