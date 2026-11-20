import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/responder/core/modules.dart';
import 'package:hazard_hero/responder/services/responder_api_service.dart';
import 'package:hazard_hero/responder/validation/responder_validators.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:hazard_hero/shared/api/api_exception.dart';
import 'package:hazard_hero/shared/media/media_link.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('responder field validation', () {
    test('validates email and emergency phone formats', () {
      expect(ResponderValidators.email('not-an-email'), isNotNull);
      expect(ResponderValidators.email('responder@example.com'), isNull);
      expect(ResponderValidators.phone('+63 (917) 123-4567'), isNull);
      expect(ResponderValidators.phone('call-me'), isNotNull);
    });

    test('requires a strong-enough password only when creating an account', () {
      final password = responderModules
          .singleWhere((module) => module.path == 'accounts')
          .fields
          .singleWhere((field) => field.name == 'password');

      expect(
        ResponderValidators.field(password, '', creating: true),
        'Password is required.',
      );
      expect(ResponderValidators.field(password, '', creating: false), isNull);
      expect(
        ResponderValidators.field(password, '12345678', creating: true),
        contains('only numbers'),
      );
      expect(
        ResponderValidators.field(password, 'SafePass123!', creating: true),
        isNull,
      );
    });

    test('enforces numeric ranges and configured choices', () {
      final evacuation = responderModules.singleWhere(
        (module) => module.path == 'evacuation-centers',
      );
      final latitude = evacuation.fields.singleWhere(
        (field) => field.name == 'latitude',
      );
      final facility = evacuation.fields.singleWhere(
        (field) => field.name == 'facility_type',
      );

      expect(
        ResponderValidators.field(latitude, '91', creating: true),
        contains('at most 90'),
      );
      expect(
        ResponderValidators.field(latitude, '8.5', creating: true),
        isNull,
      );
      expect(
        ResponderValidators.field(facility, 'Castle', creating: true),
        contains('Select a valid'),
      );
      expect(
        ResponderValidators.field(facility, 'School', creating: true),
        isNull,
      );
    });

    test('rejects invalid image data before upload', () {
      expect(
        ResponderValidators.image(name: 'payload.exe', size: 100),
        isNotNull,
      );
      expect(ResponderValidators.image(name: 'photo.png', size: 0), isNotNull);
      expect(ResponderValidators.image(name: 'photo.webp', size: 1024), isNull);
    });

    test('validates uploaded guideline media and embedded links', () {
      expect(
        ResponderValidators.mediaFile(
          name: 'evacuation.svg',
          size: 1024,
          mediaType: 'svg',
        ),
        isNull,
      );
      expect(
        ResponderValidators.mediaFile(
          name: 'video.mp4',
          size: 1024,
          mediaType: 'image',
        ),
        isNotNull,
      );
      expect(
        ResponderValidators.mediaUrl(
          'https://youtu.be/dQw4w9WgXcQ',
          mediaType: 'video',
        ),
        isNull,
      );
      expect(
        ResponderValidators.mediaUrl(
          'http://example.com/photo.png',
          mediaType: 'image',
        ),
        isNotNull,
      );
    });
  });

  test('normalizes YouTube and Vimeo links for in-app embedding', () {
    final youtube = MediaLinkInfo.parse(
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
    );
    final vimeo = MediaLinkInfo.parse('https://vimeo.com/123456789');

    expect(youtube?.provider, EmbeddedMediaProvider.youtube);
    expect(youtube?.videoId, 'dQw4w9WgXcQ');
    expect(youtube?.embedUri?.host, 'www.youtube-nocookie.com');
    expect(vimeo?.provider, EmbeddedMediaProvider.vimeo);
    expect(vimeo?.embedUri?.path, '/video/123456789');
  });

  test('API validation errors retain their field names', () {
    const error = ApiException(
      'Request failed.',
      statusCode: 400,
      errors: {
        'email': ['Enter a valid email address.'],
        'non_field_errors': ['The record is invalid.'],
      },
    );

    expect(error.toString(), contains('Email: Enter a valid email address.'));
    expect(error.toString(), contains('The record is invalid.'));
  });

  test('required responder fields mirror the backend schema', () {
    final goBag = responderModules.singleWhere(
      (module) => module.path == 'go-bag',
    );
    final evacuation = responderModules.singleWhere(
      (module) => module.path == 'evacuation-centers',
    );
    final contacts = responderModules.singleWhere(
      (module) => module.path == 'emergency-contacts',
    );

    expect(
      goBag.fields.singleWhere((field) => field.name == 'unit').required,
      isTrue,
    );
    expect(
      evacuation.fields
          .singleWhere((field) => field.name == 'street_address')
          .required,
      isTrue,
    );
    expect(
      contacts.fields.singleWhere((field) => field.name == 'region').required,
      isTrue,
    );
    expect(
      responderModules
          .singleWhere((module) => module.path == 'accounts')
          .supportsSoftDelete,
      isFalse,
    );
  });

  test('deleted records use the responder deleted action endpoint', () async {
    late Uri requestedUri;
    final service = ResponderApiService(
      ApiClient(
        client: MockClient((request) async {
          requestedUri = request.url;
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

    await service.list('go-bag', query: {'deleted': 'true', 'search': 'water'});

    expect(requestedUri.path, endsWith('/api/responder/go-bag/deleted/'));
    expect(requestedUri.queryParameters, {
      'search': 'water',
      'page_size': '100',
    });
  });

  test('responder lists load every API page', () async {
    final requested = <Uri>[];
    final service = ResponderApiService(
      ApiClient(
        client: MockClient((request) async {
          requested.add(request.url);
          final secondPage = request.url.queryParameters['page'] == '2';
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'ok',
              'data': {
                'count': 2,
                'next': secondPage ? null : '?page=2&page_size=100',
                'previous': secondPage ? '?page=1&page_size=100' : null,
                'results': [
                  {'id': secondPage ? '2' : '1'},
                ],
              },
              'errors': null,
            }),
            200,
          );
        }),
      ),
    );

    final records = await service.list('go-bag');

    expect(records.map((record) => record['id']), ['1', '2']);
    expect(requested, hasLength(2));
  });
}
