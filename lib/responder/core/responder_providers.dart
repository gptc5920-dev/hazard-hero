import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/api_client.dart';
import '../../shared/storage/secure_token_storage.dart';
import '../models/responder_models.dart';
import '../repositories/responder_repository.dart';
import '../services/responder_api_service.dart';

final tokenStorageProvider = Provider((_) => SecureTokenStorage());

class SessionEvents {
  Future<void> Function()? onExpired;
  Future<void> expire() async => onExpired?.call();
}

final sessionEventsProvider = Provider((_) => SessionEvents());
final responderApiProvider = Provider((ref) {
  final client = ApiClient(
    tokens: ref.watch(tokenStorageProvider),
    onSessionExpired: ref.watch(sessionEventsProvider).expire,
  );
  ref.onDispose(client.close);
  return ResponderApiService(client);
});
final backendHealthProvider = FutureProvider<BackendHealth>(
  (ref) => ref.watch(responderApiProvider).health(),
);
final responderRepositoryProvider = Provider(
  (ref) => ResponderRepository(
    ref.watch(responderApiProvider),
    ref.watch(tokenStorageProvider),
  ),
);

class AuthState {
  const AuthState({this.user, this.loading = false, this.error});
  final ResponderUser? user;
  final bool loading;
  final String? error;
  bool get authenticated => user != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this.repo, SessionEvents events)
    : super(const AuthState(loading: true)) {
    events.onExpired = () async => expire();
  }
  final ResponderRepository repo;
  Future<void> restore() async {
    state = const AuthState(loading: true);
    state = AuthState(user: await repo.restore());
  }

  Future<void> login(String e, String p, {required bool remember}) async {
    state = const AuthState(loading: true);
    try {
      state = AuthState(user: await repo.login(e, p, remember: remember));
    } catch (x) {
      state = AuthState(error: x.toString());
    }
  }

  Future<void> logout() async {
    await repo.logout();
    state = const AuthState();
  }

  void applyProfile(Map<String, dynamic> profile) {
    state = AuthState(user: ResponderUser.fromJson(profile));
  }

  void expire() => state = const AuthState(
    error: 'Your session expired. Please sign in again.',
  );
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) => AuthController(
    ref.watch(responderRepositoryProvider),
    ref.watch(sessionEventsProvider),
  ),
);
final managedRecordsProvider = FutureProvider.autoDispose
    .family<List<ManagedRecord>, String>(
      (ref, module) => ref.watch(responderRepositoryProvider).records(module),
    );
