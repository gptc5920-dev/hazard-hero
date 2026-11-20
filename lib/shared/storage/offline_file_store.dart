import 'package:shared_preferences/shared_preferences.dart';
import 'offline_file_store_stub.dart'
    if (dart.library.io) 'offline_file_store_io.dart'
    as implementation;

abstract interface class OfflineFileStore {
  Future<Map<String, String>> downloadManifestFiles(
    Map<String, dynamic> manifest, {
    required void Function(double) onProgress,
  });
  Future<void> deletePackage(
    String id,
    String language,
    Iterable<String> paths,
  );
}

OfflineFileStore createOfflineFileStore(SharedPreferences preferences) =>
    implementation.createOfflineFileStore(preferences);
