import '../entities/app_user.dart';

abstract interface class AuthRepository {
  Future<bool> hasAnyUser();
  Future<void> ensureDefaultAdmin({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthSession?> restoreSession();
  Future<AuthSession> bootstrapAdmin({
    required String name,
    required String email,
    required String password,
  });
  Future<AuthSession> signIn({required String email, required String password});
  Future<void> signOut();
  Stream<List<AppUser>> watchUsers();
  Future<AppUser> createUser({
    required AppUser actor,
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<AppUser> updateUser({
    required AppUser actor,
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    String? password,
  });
  Future<void> deleteUser({required AppUser actor, required String userId});
  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  });
}
