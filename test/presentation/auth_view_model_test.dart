import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/domain/entities/app_user.dart';
import 'package:hazard_hero/domain/repositories/auth_repository.dart';
import 'package:hazard_hero/presentation/view_models/auth_view_model.dart';

class _AuthFake implements AuthRepository {
  bool hasUsers = false;
  AuthSession? session;

  @override
  Future<bool> hasAnyUser() async => hasUsers;
  @override
  Future<void> ensureDefaultAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    hasUsers = true;
  }

  @override
  Future<AuthSession?> restoreSession() async => session;
  @override
  Future<void> signOut() async => session = null;
  @override
  Stream<List<AppUser>> watchUsers() => const Stream.empty();

  @override
  Future<AuthSession> bootstrapAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    hasUsers = true;
    return session = AuthSession(
      id: 'session',
      user: AppUser(
        id: 'admin',
        email: email,
        displayName: name,
        role: UserRole.admin,
        isActive: true,
      ),
    );
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async => session ?? (throw StateError('Invalid credentials'));

  @override
  Future<AppUser> createUser({
    required AppUser actor,
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) => throw UnimplementedError();

  @override
  Future<AppUser> updateUser({
    required AppUser actor,
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    String? password,
  }) => throw UnimplementedError();

  @override
  Future<void> deleteUser({required AppUser actor, required String userId}) =>
      throw UnimplementedError();

  @override
  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  }) => throw UnimplementedError();
}

void main() {
  test(
    'ViewModel opens sign in then authenticates an existing account',
    () async {
      final repository = _AuthFake();
      final viewModel = AuthViewModel(repository);
      await viewModel.initialize();
      expect(viewModel.state.phase, AuthPhase.signedOut);

      repository.session = const AuthSession(
        id: 'session',
        user: AppUser(
          id: 'admin',
          email: 'admin@example.com',
          displayName: 'Admin',
          role: UserRole.admin,
          isActive: true,
        ),
      );
      await viewModel.signIn(
        email: 'admin@example.com',
        password: 'long-password',
      );
      expect(viewModel.state.phase, AuthPhase.authenticated);
      expect(viewModel.state.session!.user.role, UserRole.admin);
      await viewModel.dispose();
    },
  );
}
