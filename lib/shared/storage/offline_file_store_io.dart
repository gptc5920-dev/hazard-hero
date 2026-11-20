import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'offline_file_store.dart';

class IoOfflineFileStore implements OfflineFileStore {
  @override
  Future<Map<String, String>> downloadManifestFiles(
    Map<String, dynamic> manifest, {
    required void Function(double) onProgress,
  }) async {
    final files = _files(manifest);
    final root = Directory(
      '${(await getApplicationDocumentsDirectory()).path}${Platform.pathSeparator}hazard_hero_offline${Platform.pathSeparator}${manifest['guideline_id']}${Platform.pathSeparator}${manifest['requested_language']}',
    );
    await root.create(recursive: true);
    final result = <String, String>{};
    for (var i = 0; i < files.length; i++) {
      final entry = files[i];
      final url = entry['url'].toString();
      final bytes = await http.readBytes(Uri.parse(url));
      final expected = entry['sha256']?.toString();
      if (expected != null &&
          expected.isNotEmpty &&
          sha256.convert(bytes).toString() != expected) {
        throw const FileSystemException(
          'Downloaded file failed checksum verification.',
        );
      }
      final uri = Uri.parse(url);
      final name = uri.pathSegments.isEmpty ? 'file_$i' : uri.pathSegments.last;
      final file = File('${root.path}${Platform.pathSeparator}${i}_$name');
      await file.writeAsBytes(bytes, flush: true);
      result[url] = file.path;
      onProgress((i + 1) / files.length);
    }
    return result;
  }

  @override
  Future<void> deletePackage(
    String id,
    String language,
    Iterable<String> paths,
  ) async {
    for (final path in paths) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
    if (paths.isNotEmpty) {
      final parent = File(paths.first).parent;
      if (await parent.exists()) await parent.delete(recursive: true);
    }
  }

  List<Map> _files(Map<String, dynamic> m) {
    final result = <Map>[];
    void add(dynamic x) {
      if (x is Map && x['url'] != null) result.add(x);
    }

    add(m['featured_image']);
    for (final raw in m['media'] as List? ?? const []) {
      final media = raw as Map;
      add(media['file']);
      add(media['subtitle']);
    }
    return result;
  }
}

OfflineFileStore createOfflineFileStore(SharedPreferences preferences) =>
    IoOfflineFileStore();
