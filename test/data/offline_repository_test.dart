import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/data/local/app_database.dart';
import 'package:hazard_hero/data/repositories/local_auth_repository.dart';
import 'package:hazard_hero/data/repositories/local_resource_repository.dart';
import 'package:hazard_hero/data/security/password_hasher.dart';
import 'package:hazard_hero/domain/entities/app_user.dart';
import 'package:hazard_hero/domain/entities/emergency_resource.dart';
import 'package:hazard_hero/domain/services/authorization_service.dart';

class _FastHasher implements PasswordHasher {
  @override
  Future<PasswordDigest> hash(String password) async =>
      PasswordDigest(hash: 'hash:$password', salt: 'test-salt');

  @override
  Future<bool> verify(
    String password, {
    required String hash,
    required String salt,
  }) async => hash == 'hash:$password' && salt == 'test-salt';
}

void main() {
  late AppDatabase database;
  late LocalAuthRepository auth;
  late LocalResourceRepository resources;

  setUp(() {
    database = AppDatabase(executor: NativeDatabase.memory());
    const authorization = AuthorizationService();
    auth = LocalAuthRepository(database, _FastHasher(), authorization);
    resources = LocalResourceRepository(database, authorization);
  });

  tearDown(() => database.close());

  test('empty database provisions a hashed built-in administrator', () async {
    await expectLater(database.ensureInitialized(), completes);
    expect(await auth.hasAnyUser(), isFalse);
    await auth.ensureDefaultAdmin(
      name: 'Hazard Hero Administrator',
      email: 'admin@hazardhero.local',
      password: 'HazardHero123!',
    );
    expect(await auth.hasAnyUser(), isTrue);
    expect(await auth.restoreSession(), isNull);
    final stored = await database.select(database.userAccounts).getSingle();
    expect(stored.email, 'admin@hazardhero.local');
    expect(stored.role, 'admin');
    expect(stored.passwordHash, isNot('HazardHero123!'));
    final session = await auth.signIn(
      email: 'admin@hazardhero.local',
      password: 'HazardHero123!',
    );
    expect(session.user.role.name, 'admin');
    expect(await database.select(database.resourceRows).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });

  test(
    'bootstrap admin supports offline sign-in without plaintext storage',
    () async {
      final session = await auth.bootstrapAdmin(
        name: 'Operations Admin',
        email: 'admin@example.com',
        password: 'very-secure-password',
      );
      expect(session.user.role.name, 'admin');

      final stored = await database.select(database.userAccounts).getSingle();
      expect(stored.passwordHash, isNot('very-secure-password'));

      await auth.signOut();
      final signedIn = await auth.signIn(
        email: 'admin@example.com',
        password: 'very-secure-password',
      );
      expect(signedIn.user.id, session.user.id);
    },
  );

  test(
    'CRUD writes resource and outbox atomically then tombstones delete',
    () async {
      final actor = (await auth.bootstrapAdmin(
        name: 'Operations Admin',
        email: 'admin@example.com',
        password: 'very-secure-password',
      )).user;

      final created = await resources.create(
        actor: actor,
        draft: const ResourceDraft(
          kind: ResourceKind.alert,
          title: 'River warning',
          description: 'Water is rising near the northern bridge.',
        ),
      );
      expect(await database.select(database.syncOutbox).get(), hasLength(1));

      final updated = await resources.update(
        actor: actor,
        id: created.id,
        draft: const ResourceDraft(
          kind: ResourceKind.alert,
          title: 'River warning updated',
          description: 'Water is rising near the northern bridge.',
        ),
      );
      expect(updated.version, 2);
      expect(await database.select(database.syncOutbox).get(), hasLength(2));

      await resources.delete(actor: actor, id: created.id);
      expect(await resources.watchAll().first, isEmpty);
      expect(await database.select(database.syncOutbox).get(), hasLength(3));
      expect(
        (await database.select(database.resourceRows).getSingle()).deletedAt,
        isNotNull,
      );
    },
  );

  test('admin accounts are editable but protected from deletion', () async {
    final actor = (await auth.bootstrapAdmin(
      name: 'Primary Admin',
      email: 'primary@example.com',
      password: 'primary-password',
    )).user;

    final created = await auth.createUser(
      actor: actor,
      name: 'Backup Admin',
      email: 'backup@example.com',
      password: '123',
      role: UserRole.admin,
    );
    expect(created.role, UserRole.admin);

    final updated = await auth.updateUser(
      actor: actor,
      userId: created.id,
      name: 'Operations Admin',
      email: 'operations@example.com',
      password: '456',
      role: UserRole.admin,
    );
    expect(updated.displayName, 'Operations Admin');
    expect(updated.email, 'operations@example.com');

    await auth.setUserActive(actor: actor, userId: created.id, isActive: false);
    await auth.setUserActive(actor: actor, userId: created.id, isActive: true);
    final signedIn = await auth.signIn(
      email: 'operations@example.com',
      password: '456',
    );
    expect(signedIn.user.id, created.id);

    await expectLater(
      auth.deleteUser(actor: actor, userId: created.id),
      throwsA(isA<AuthException>()),
    );

    final responder = await auth.createUser(
      actor: actor,
      name: 'Field Responder',
      email: 'responder@example.com',
      password: 'responder-password',
      role: UserRole.responder,
    );
    await auth.deleteUser(actor: actor, userId: responder.id);
    expect(
      (await auth.watchUsers().first).map((user) => user.id),
      isNot(contains(responder.id)),
    );
    await expectLater(
      auth.deleteUser(actor: actor, userId: actor.id),
      throwsA(isA<AuthException>()),
    );
  });

  test('responder can store guide image, video, and reference URLs', () async {
    final admin = (await auth.bootstrapAdmin(
      name: 'Primary Admin',
      email: 'primary@example.com',
      password: 'admin',
    )).user;
    final responder = await auth.createUser(
      actor: admin,
      name: 'Guide Editor',
      email: 'guide@example.com',
      password: 'guide',
      role: UserRole.responder,
    );

    final guide = await resources.create(
      actor: responder,
      draft: const ResourceDraft(
        kind: ResourceKind.guide,
        title: 'Typhoon preparedness',
        description: 'Steps to follow before a typhoon arrives.',
        metadata: {
          'imageUrl': 'https://example.com/typhoon.jpg',
          'videoUrl': 'https://example.com/typhoon.mp4',
          'referenceUrl': 'https://example.com/typhoon-guide',
        },
      ),
    );

    expect(guide.metadata['imageUrl'], endsWith('typhoon.jpg'));
    expect(guide.metadata['videoUrl'], endsWith('typhoon.mp4'));
    expect(guide.metadata['referenceUrl'], endsWith('typhoon-guide'));
  });
}
