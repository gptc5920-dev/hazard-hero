import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:hazard_hero/shared/api/api_exception.dart';
import 'package:hazard_hero/shared/storage/secure_token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('unwraps standard Django success envelope', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"success":true,"message":"ok","data":{"value":7},"errors":null}',
          200,
          headers: {'content-type': 'application/json'},
        ),
      ),
    );
    final data = await client.get('http://example.test');
    expect(data['value'], 7);
  });
  test('converts backend errors into safe ApiException', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '{"success":false,"message":"Invalid request","data":null,"errors":{"field":["Required"]}}',
          400,
        ),
      ),
    );
    expect(
      () => client.get('http://example.test'),
      throwsA(
        isA<ApiException>().having(
          (x) => x.message,
          'message',
          'Invalid request',
        ),
      ),
    );
  });

  test('does not expose an XML error response', () async {
    final client = ApiClient(
      client: MockClient(
        (_) async => http.Response(
          '<?xml version="1.0"?><Error><Code>InternalError</Code></Error>',
          500,
          headers: {'content-type': 'application/xml'},
        ),
      ),
    );

    expect(
      () => client.get('http://example.test'),
      throwsA(
        isA<ApiException>()
            .having(
              (error) => error.toString(),
              'safe message',
              'The request could not be completed.',
            )
            .having(
              (error) => error.toString(),
              'XML response',
              isNot(contains('<Error>')),
            ),
      ),
    );
  });

  test('user-facing errors replace markup with a generic message', () {
    expect(
      userFacingErrorMessage(
        Exception('<html><body>Internal Server Error</body></html>'),
      ),
      'Something went wrong. Please try again.',
    );
    expect(
      userFacingErrorMessage(
        FormatException(
          'Unexpected response: <?xml version="1.0"?><Response />',
        ),
      ),
      'Something went wrong. Please try again.',
    );
  });

  test('shares one token refresh across concurrent unauthorized requests', () async {
    final tokens = _MemoryTokenStorage('expired-access', 'valid-refresh');
    var refreshRequests = 0;
    final client = ApiClient(
      tokens: tokens,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh/')) {
          refreshRequests++;
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return http.Response(
            '{"success":true,"message":"ok","data":{"access":"new-access","refresh":"new-refresh"},"errors":null}',
            200,
          );
        }
        if (request.headers['authorization'] == 'Bearer new-access') {
          return http.Response(
            '{"success":true,"message":"ok","data":{"value":1},"errors":null}',
            200,
          );
        }
        return http.Response(
          '{"success":false,"message":"Unauthorized","data":null,"errors":null}',
          401,
        );
      }),
    );

    final responses = await Future.wait([
      client.get('https://example.test/one', authenticated: true),
      client.get('https://example.test/two', authenticated: true),
    ]);

    expect(refreshRequests, 1);
    expect(responses.map((response) => response['value']), [1, 1]);
    expect(await tokens.accessToken, 'new-access');
  });
}

class _MemoryTokenStorage extends SecureTokenStorage {
  _MemoryTokenStorage(this._access, this._refresh);

  String? _access;
  String? _refresh;

  @override
  Future<String?> get accessToken async => _access;

  @override
  Future<String?> get refreshToken async => _refresh;

  @override
  Future<void> save({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
  }
}
