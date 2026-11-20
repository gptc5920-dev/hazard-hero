import 'dart:async';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

enum AuthPhase { initializing, signedOut, authenticated }

class AuthState {
  const AuthState({
    required this.phase,
    this.session,
    this.isBusy = false,
    this.error,
  });
  final AuthPhase phase;
  final AuthSession? session;
  final bool isBusy;
  final String? error;
  AuthState copyWith({
    AuthPhase? phase,
    AuthSession? session,
    bool? isBusy,
    String? error,
    bool clearError = false,
  }) => AuthState(
    phase: phase ?? this.phase,
    session: session ?? this.session,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : error ?? this.error,
  );
}

class AuthViewModel {
  AuthViewModel(this._repository);
  final AuthRepository _repository;
  final _states = StreamController<AuthState>.broadcast();
  AuthState _state = const AuthState(phase: AuthPhase.initializing);
  Stream<AuthState> get states => _states.stream;
  AuthState get state => _state;

  Future<void> initialize() async {
    try {
      final session = await _repository.restoreSession();
      if (session != null) {
        return _emit(
          AuthState(phase: AuthPhase.authenticated, session: session),
        );
      }
      _emit(const AuthState(phase: AuthPhase.signedOut));
    } on Object catch (error) {
      _emit(AuthState(phase: AuthPhase.signedOut, error: error.toString()));
    }
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async => _run(() => _repository.signIn(email: email, password: password));

  Future<void> _run(Future<AuthSession> Function() action) async {
    _emit(_state.copyWith(isBusy: true, clearError: true));
    try {
      _emit(AuthState(phase: AuthPhase.authenticated, session: await action()));
    } on Object catch (error) {
      _emit(_state.copyWith(isBusy: false, error: error.toString()));
    }
  }

  Future<void> signOut() async {
    await _repository.signOut();
    _emit(const AuthState(phase: AuthPhase.signedOut));
  }

  void clearError() => _emit(_state.copyWith(clearError: true));
  void _emit(AuthState state) {
    _state = state;
    if (!_states.isClosed) _states.add(state);
  }

  Future<void> dispose() => _states.close();
}
