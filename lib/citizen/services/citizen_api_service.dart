import '../../shared/api/api_client.dart';
import '../../shared/constants/api_config.dart';

class CitizenApiService {
  const CitizenApiService(this._client);
  final ApiClient _client;
  String _url(String path, String language, {Map<String, String>? query}) =>
      Uri.parse('${ApiConfig.citizenBase}/$path/')
          .replace(
            queryParameters: {
              'language': language,
              'page_size': '100',
              ...?query,
            },
          )
          .toString();
  Future<List<Map<String, dynamic>>> list(
    String path,
    String language, {
    Map<String, String>? query,
  }) async {
    final records = <Map<String, dynamic>>[];
    String? next = _url(path, language, query: query);
    final visited = <String>{};
    while (next != null && visited.add(next)) {
      final current = Uri.parse(next);
      final data = await _client.get(next);
      final rows = data is Map
          ? data['results'] as List? ?? const []
          : data as List? ?? const [];
      records.addAll(rows.map((e) => (e as Map).cast<String, dynamic>()));
      final nextValue = data is Map ? data['next']?.toString() : null;
      next = nextValue == null ? null : current.resolve(nextValue).toString();
    }
    return records;
  }

  Future<List<Map<String, dynamic>>> languages() async =>
      ((await _client.get('${ApiConfig.citizenBase}/languages/')) as List)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
  Future<Map<String, dynamic>> offlineManifest(
    String slug,
    String language,
  ) async =>
      ((await _client.get(_url('guidelines/$slug/offline-manifest', language)))
              as Map)
          .cast<String, dynamic>();
}
