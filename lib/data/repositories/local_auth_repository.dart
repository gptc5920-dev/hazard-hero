import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/services/authorization_service.dart';
import '../local/app_database.dart';
import '../mappers/entity_mappers.dart';
import '../security/password_hasher.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._db, this._hasher, this._authorization, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();
  final AppDatabase _db;
  final PasswordHasher _hasher;
  final AuthorizationService _authorization;
  final Uuid _uuid;

  @override
  Future<bool> hasAnyUser() async =>
      (await _db.userAccounts.count().getSingle()) > 0;

  @override
  Future<void> ensureDefaultAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = _validateIdentity(name, email);
    _validatePassword(password);
    if (await hasAnyUser()) return;
    final digest = await _hasher.hash(password);
    await _db.transaction(() async {
      if (await hasAnyUser()) return;
      final now = DateTime.now().toUtc();
      await _db
          .into(_db.userAccounts)
          .insert(
            UserAccountsCompanion.insert(
              id: _uuid.v4(),
              email: normalized.$2,
              displayName: normalized.$1,
              role: UserRole.admin.name,
              passwordHash: digest.hash,
              passwordSalt: digest.salt,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
  }

  @override
  Future<AuthSession> bootstrapAdmin({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalized = _validateIdentity(name, email);
    final digest = await _hasher.hash(password);
    return _db.transaction(() async {
      if (await hasAnyUser()) {
        throw const AuthException(
          'The administrator has already been configured.',
        );
      }
      final now = DateTime.now().toUtc();
      final userId = _uuid.v4();
      await _db
          .into(_db.userAccounts)
          .insert(
            UserAccountsCompanion.insert(
              id: userId,
              email: normalized.$2,
              displayName: normalized.$1,
              role: UserRole.admin.name,
              passwordHash: digest.hash,
              passwordSalt: digest.salt,
              createdAt: now,
              updatedAt: now,
            ),
          );
      return _createSession(
        mapUser(
          await (_db.select(
            _db.userAccounts,
          )..where((t) => t.id.equals(userId))).getSingle(),
        ),
      );
    });
  }

  @override
  Future<AuthSession> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    final row = await (_db.select(
      _db.userAccounts,
    )..where((t) => t.email.equals(normalized))).getSingleOrNull();
    if (row == null ||
        !row.isActive ||
        !await _hasher.verify(
          password,
          hash: row.passwordHash,
          salt: row.passwordSalt,
        )) {
      throw const AuthException('Invalid email or password.');
    }
    await (_db.update(_db.authSessionRows)
          ..where((t) => t.isActive.equals(true)))
        .write(const AuthSessionRowsCompanion(isActive: Value(false)));
    return _createSession(mapUser(row));
  }

  Future<AuthSession> _createSession(AppUser user) async {
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    await _db
        .into(_db.authSessionRows)
        .insert(
          AuthSessionRowsCompanion.insert(
            id: id,
            userId: user.id,
            createdAt: now,
            lastAuthenticatedAt: now,
          ),
        );
    return AuthSession(id: id, user: user);
  }

  @override
  Future<AuthSession?> restoreSession() async {
    final session =
        await (_db.select(_db.authSessionRows)
              ..where((t) => t.isActive.equals(true))
              ..orderBy([(t) => OrderingTerm.desc(t.lastAuthenticatedAt)])
              ..limit(1))
            .getSingleOrNull();
    if (session == null) return null;
    final row = await (_db.select(
      _db.userAccounts,
    )..where((t) => t.id.equals(session.userId))).getSingleOrNull();
    if (row == null || !row.isActive) {
      await signOut();
      return null;
    }
    return AuthSession(id: session.id, user: mapUser(row));
  }

  @override
  Future<void> signOut() =>
      (_db.update(_db.authSessionRows)..where((t) => t.isActive.equals(true)))
          .write(const AuthSessionRowsCompanion(isActive: Value(false)));

  @override
  Stream<List<AppUser>> watchUsers() =>
      (_db.select(_db.userAccounts)
            ..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .watch()
          .map((rows) => rows.map(mapUser).toList(growable: false));

  @override
  Future<AppUser> createUser({
    required AppUser actor,
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _authorization.requireAdmin(actor);
    final normalized = _validateIdentity(name, email);
    _validatePassword(password);
    final digest = await _hasher.hash(password);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    try {
      await _db
          .into(_db.userAccounts)
          .insert(
            UserAccountsCompanion.insert(
              id: id,
              email: normalized.$2,
              displayName: normalized.$1,
              role: role.name,
              passwordHash: digest.hash,
              passwordSalt: digest.salt,
              createdAt: now,
              updatedAt: now,
            ),
          );
    } on Object catch (_) {
      throw const AuthException('An account with that email already exists.');
    }
    return mapUser(
      await (_db.select(
        _db.userAccounts,
      )..where((t) => t.id.equals(id))).getSingle(),
    );
  }

  @override
  Future<AppUser> updateUser({
    required AppUser actor,
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    String? password,
  }) async {
    _authorization.requireAdmin(actor);
    final normalized = _validateIdentity(name, email);
    if (password != null && password.isNotEmpty) _validatePassword(password);
    return _db.transaction(() async {
      final target = await (_db.select(
        _db.userAccounts,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (target == null) throw const AuthException('User not found.');
      if (actor.id == userId && role != actor.role) {
        throw const AuthException(
          'You cannot change your own administrator role.',
        );
      }
      if (target.role == UserRole.admin.name &&
          role != UserRole.admin &&
          target.isActive) {
        await _requireAnotherActiveAdmin(userId);
      }
      PasswordDigest? digest;
      if (password != null && password.isNotEmpty) {
        digest = await _hasher.hash(password);
      }
      try {
        await (_db.update(
          _db.userAccounts,
        )..where((t) => t.id.equals(userId))).write(
          UserAccountsCompanion(
            displayName: Value(normalized.$1),
            email: Value(normalized.$2),
            role: Value(role.name),
            passwordHash: digest == null
                ? const Value.absent()
                : Value(digest.hash),
            passwordSalt: digest == null
                ? const Value.absent()
                : Value(digest.salt),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      } on Object catch (_) {
        throw const AuthException('An account with that email already exists.');
      }
      return mapUser(
        await (_db.select(
          _db.userAccounts,
        )..where((t) => t.id.equals(userId))).getSingle(),
      );
    });
  }

  @override
  Future<void> deleteUser({
    required AppUser actor,
    required String userId,
  }) async {
    _authorization.requireAdmin(actor);
    if (actor.id == userId) {
      throw const AuthException('You cannot delete your own active account.');
    }
    await _db.transaction(() async {
      final target = await (_db.select(
        _db.userAccounts,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (target == null) throw const AuthException('User not found.');
      if (target.role == UserRole.admin.name) {
        throw const AuthException('Administrator accounts cannot be deleted.');
      }
      await (_db.delete(
        _db.authSessionRows,
      )..where((t) => t.userId.equals(userId))).go();
      await (_db.delete(
        _db.userAccounts,
      )..where((t) => t.id.equals(userId))).go();
    });
  }

  @override
  Future<void> setUserActive({
    required AppUser actor,
    required String userId,
    required bool isActive,
  }) async {
    _authorization.requireAdmin(actor);
    if (actor.id == userId && !isActive) {
      throw const AuthException('You cannot disable your own active session.');
    }
    await _db.transaction(() async {
      final target = await (_db.select(
        _db.userAccounts,
      )..where((t) => t.id.equals(userId))).getSingleOrNull();
      if (target == null) {
        throw const AuthException('User not found.');
      }
      if (!isActive && target.role == UserRole.admin.name) {
        final activeAdmins =
            await (_db.select(_db.userAccounts)..where(
                  (t) =>
                      t.role.equals(UserRole.admin.name) &
                      t.isActive.equals(true),
                ))
                .get();
        if (activeAdmins.length <= 1) {
          throw const AuthException(
            'The last active administrator cannot be disabled.',
          );
        }
      }
      await (_db.update(
        _db.userAccounts,
      )..where((t) => t.id.equals(userId))).write(
        UserAccountsCompanion(
          isActive: Value(isActive),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
    });
  }

  Future<void> _requireAnotherActiveAdmin(String excludedUserId) async {
    final others =
        await (_db.select(_db.userAccounts)..where(
              (t) =>
                  t.id.equals(excludedUserId).not() &
                  t.role.equals(UserRole.admin.name) &
                  t.isActive.equals(true),
            ))
            .get();
    if (others.isEmpty) {
      throw const AuthException(
        'At least one active administrator must remain.',
      );
    }
  }

  void _validatePassword(String password) {
    if (password.isEmpty) {
      throw const AuthException('Password is required.');
    }
  }

  (String, String) _validateIdentity(String name, String email) {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    if (cleanName.length < 2) {
      throw const AuthException('Name must contain at least 2 characters.');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanEmail)) {
      throw const AuthException('Enter a valid email address.');
    }
    return (cleanName, cleanEmail);
  }
}

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}
