import '../../shared/storage/secure_token_storage.dart';
import '../models/responder_models.dart';
import '../services/responder_api_service.dart';

class ResponderRepository {
  const ResponderRepository(this.api, this.tokens);
  final ResponderApiService api;
  final SecureTokenStorage tokens;
  Future<ResponderUser> login(
    String email,
    String password, {
    required bool remember,
  }) async {
    final data = await api.login(email, password);
    await tokens.setPersistent(remember);
    await tokens.save(
      access: data['access'] as String,
      refresh: data['refresh'] as String,
    );
    return ResponderUser.fromJson(
      (data['user'] as Map).cast<String, dynamic>(),
    );
  }

  Future<ResponderUser?> restore() async {
    if (await tokens.accessToken == null) return null;
    try {
      return ResponderUser.fromJson(await api.profile());
    } catch (_) {
      await tokens.clear();
      return null;
    }
  }

  Future<void> logout() async {
    final refresh = await tokens.refreshToken;
    try {
      if (refresh != null) await api.logout(refresh);
    } finally {
      await tokens.clear();
    }
  }

  Future<List<ManagedRecord>> records(
    String module, {
    Map<String, String>? query,
  }) async =>
      (await api.list(module, query: query)).map(ManagedRecord.new).toList();
}
