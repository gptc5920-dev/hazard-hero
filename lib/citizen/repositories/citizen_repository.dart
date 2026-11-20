import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/citizen_models.dart';
import '../services/citizen_api_service.dart';
import '../../shared/storage/offline_file_store.dart';

class CitizenRepository {
  CitizenRepository(this._api, this._preferences);

  static const publicModules = <String>[
    'go-bag',
    'calamities',
    'guidelines',
    'evacuation-centers',
    'emergency-contacts',
    'alerts',
  ];

  final CitizenApiService _api;
  final SharedPreferences _preferences;

  String _key(String module, String language) =>
      'citizen_cache_${module}_$language';

  Future<List<PublicRecord>> records(
    String module,
    String language, {
    Map<String, String>? query,
  }) async {
    try {
      final data = await _api.list(module, language, query: query);
      await _saveRecords(module, language, data);
      await _saveLastSync();
      return data.map(PublicRecord.new).toList();
    } catch (_) {
      final cached = cachedRecords(module, language);
      if (cached == null) rethrow;
      return cached;
    }
  }

  List<PublicRecord>? cachedRecords(String module, String language) {
    final raw = _preferences.getString(_key(module, language));
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((item) => PublicRecord((item as Map).cast<String, dynamic>()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> syncAll(String language) async {
    final responses = await Future.wait(
      publicModules.map(
        (module) async => MapEntry(module, await _api.list(module, language)),
      ),
    );
    for (final response in responses) {
      await _saveRecords(response.key, language, response.value);
    }
    await _saveLastSync();
    await languages();
  }

  Future<List<LanguageOption>> languages() async {
    try {
      final data = await _api.languages();
      await _preferences.setString('citizen_languages', jsonEncode(data));
      return data.map(LanguageOption.fromJson).toList();
    } catch (_) {
      final cached = _preferences.getString('citizen_languages');
      if (cached == null) rethrow;
      return (jsonDecode(cached) as List)
          .map(
            (item) =>
                LanguageOption.fromJson((item as Map).cast<String, dynamic>()),
          )
          .toList();
    }
  }

  Future<void> _saveRecords(
    String module,
    String language,
    List<Map<String, dynamic>> data,
  ) => _preferences.setString(_key(module, language), jsonEncode(data));

  Future<void> _saveLastSync() => _preferences.setString(
    'citizen_last_sync',
    DateTime.now().toUtc().toIso8601String(),
  );

  Future<OfflinePackage> downloadGuideline(
    String slug,
    String language, {
    required void Function(double) onProgress,
  }) async {
    final manifest = await _api.offlineManifest(slug, language);
    final paths = await createOfflineFileStore(
      _preferences,
    ).downloadManifestFiles(manifest, onProgress: onProgress);
    final item = OfflinePackage(
      id: manifest['guideline_id'].toString(),
      language: language,
      manifest: manifest,
      savedAt: DateTime.now().toUtc(),
      localPaths: paths,
    );
    final all =
        offlinePackages
            .where((x) => !(x.id == item.id && x.language == language))
            .toList()
          ..add(item);
    await _preferences.setString(
      'citizen_downloads',
      jsonEncode(all.map((x) => x.toJson()).toList()),
    );
    return item;
  }

  List<OfflinePackage> get offlinePackages {
    final raw = _preferences.getString('citizen_downloads');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => OfflinePackage.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
  }

  Future<void> deletePackage(String id, String language) async {
    final current = offlinePackages;
    final matches = current.where((x) => x.id == id && x.language == language);
    if (matches.isNotEmpty) {
      await createOfflineFileStore(
        _preferences,
      ).deletePackage(id, language, matches.first.localPaths.values);
    }
    final all = current.where((x) => x.id != id || x.language != language);
    await _preferences.setString(
      'citizen_downloads',
      jsonEncode(all.map((x) => x.toJson()).toList()),
    );
  }

  DateTime? get lastSync {
    final raw = _preferences.getString('citizen_last_sync');
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
