import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/citizen/services/citizen_api_service.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loads every page of citizen records', () async {
    final requested = <Uri>[];
    final service = CitizenApiService(
      ApiClient(
        client: MockClient((request) async {
          requested.add(request.url);
          if (request.url.queryParameters['page'] == '2') {
            return http.Response(
              '{"success":true,"message":"ok","data":{"count":2,"next":null,"previous":"http://example.test/api/citizen/go-bag/?page=1","results":[{"id":"2","name":"Radio"}]},"errors":null}',
              200,
            );
          }
          return http.Response(
            '{"success":true,"message":"ok","data":{"count":2,"next":"http://example.test/api/citizen/go-bag/?language=en&page=2","previous":null,"results":[{"id":"1","name":"Water"}]},"errors":null}',
            200,
          );
        }),
      ),
    );

    final records = await service.list('go-bag', 'en');

    expect(records.map((item) => item['name']), ['Water', 'Radio']);
    expect(requested, hasLength(2));
  });
}
