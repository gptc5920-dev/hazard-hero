import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_file_store.dart';

class BrowserOfflineFileStore implements OfflineFileStore {
  BrowserOfflineFileStore(this.preferences);
  final SharedPreferences preferences;
  @override
  Future<Map<String, String>> downloadManifestFiles(
    Map<String, dynamic> manifest, {
    required void Function(double) onProgress,
  }) async {
    final urls = _urls(manifest);
    final result = <String, String>{};
    for (var i = 0; i < urls.length; i++) {
      final bytes = await http.readBytes(Uri.parse(urls[i]));
      final key = 'offline_file_${base64Url.encode(utf8.encode(urls[i]))}';
      await preferences.setString(key, base64Encode(bytes));
      result[urls[i]] = 'preferences://$key';
      onProgress((i + 1) / urls.length);
    }
    return result;
  }

  @override
  Future<void> deletePackage(
    String id,
    String language,
    Iterable<String> paths,
  ) async {
    for (final path in paths.where((x) => x.startsWith('preferences://'))) {
      await preferences.remove(path.substring('preferences://'.length));
    }
  }

  List<String> _urls(Map<String, dynamic> m) {
    final values = <String>[];
    void add(dynamic x) {
      if (x is Map && x['url'] != null) values.add(x['url'].toString());
    }

    add(m['featured_image']);
    for (final raw in m['media'] as List? ?? const []) {
      final media = raw as Map;
      add(media['file']);
      add(media['subtitle']);
    }
    return values;
  }
}

OfflineFileStore createOfflineFileStore(SharedPreferences preferences) =>
    BrowserOfflineFileStore(preferences);
