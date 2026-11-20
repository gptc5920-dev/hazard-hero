import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  SecureTokenStorage([
    this._storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        storageNamespace: 'hazard_hero_responder_v1',
        migrateOnAlgorithmChange: false,
        resetOnError: true,
      ),
    ),
  ]);
  final FlutterSecureStorage _storage;
  bool _persistent = true;
  String? _sessionAccess;
  String? _sessionRefresh;

  Future<String?> get accessToken async {
    if (_sessionAccess != null) return _sessionAccess;
    if (!_persistent) return null;
    return _storage.read(key: 'responder_access_token');
  }

  Future<String?> get refreshToken async {
    if (_sessionRefresh != null) return _sessionRefresh;
    if (!_persistent) return null;
    return _storage.read(key: 'responder_refresh_token');
  }

  Future<void> setPersistent(bool persistent) async {
    _persistent = persistent;
    if (!persistent) {
      await _deletePersistedTokens();
    }
  }

  Future<void> save({required String access, required String refresh}) async {
    _sessionAccess = access;
    _sessionRefresh = refresh;
    if (_persistent) {
      await _storage.write(key: 'responder_access_token', value: access);
      await _storage.write(key: 'responder_refresh_token', value: refresh);
    }
  }

  Future<void> clear() async {
    _sessionAccess = null;
    _sessionRefresh = null;
    await _deletePersistedTokens();
  }

  Future<void> _deletePersistedTokens() async {
    await _storage.delete(key: 'responder_access_token');
    await _storage.delete(key: 'responder_refresh_token');
  }
}
