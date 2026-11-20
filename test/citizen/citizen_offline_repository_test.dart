import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/citizen/repositories/citizen_repository.dart';
import 'package:hazard_hero/citizen/services/citizen_api_service.dart';
import 'package:hazard_hero/shared/api/api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('uses saved citizen records when the backend is offline', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    var online = true;
    final repository = CitizenRepository(
      CitizenApiService(
        ApiClient(
          client: MockClient((request) async {
            if (!online) {
              return http.Response(
                '{"success":false,"message":"offline","data":null,"errors":null}',
                503,
              );
            }
            return http.Response(
              '{"success":true,"message":"ok","data":{"count":1,"next":null,"previous":null,"results":[{"id":"alert-1","title":"Flood warning","message":"Move to higher ground"}]},"errors":null}',
              200,
            );
          }),
        ),
      ),
      preferences,
    );

    final onlineRecords = await repository.records('alerts', 'en');
    online = false;
    final offlineRecords = await repository.records('alerts', 'en');

    expect(onlineRecords.single.title, 'Flood warning');
    expect(offlineRecords.single.title, 'Flood warning');
    expect(repository.lastSync, isNotNull);
  });

  test('syncs and saves every public module for offline browsing', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final requestedModules = <String>{};
    final repository = CitizenRepository(
      CitizenApiService(
        ApiClient(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/languages/')) {
              return http.Response(
                '{"success":true,"message":"ok","data":[{"name":"English","native_name":"English","language_code":"en","is_default":true}],"errors":null}',
                200,
              );
            }
            final module =
                request.url.pathSegments[request.url.pathSegments.length - 2];
            requestedModules.add(module);
            return http.Response(
              '{"success":true,"message":"ok","data":{"count":1,"next":null,"previous":null,"results":[{"id":"$module-1","name":"Saved $module"}]},"errors":null}',
              200,
            );
          }),
        ),
      ),
      preferences,
    );

    await repository.syncAll('en');

    expect(requestedModules, CitizenRepository.publicModules.toSet());
    for (final module in CitizenRepository.publicModules) {
      expect(repository.cachedRecords(module, 'en'), isNotEmpty);
    }
    expect(await repository.languages(), isNotEmpty);
  });
}
