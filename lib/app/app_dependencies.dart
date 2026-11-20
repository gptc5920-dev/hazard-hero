import '../data/local/app_database.dart';
import '../data/network/network_monitor.dart';
import '../data/remote/remote_sync_gateway.dart';
import '../data/repositories/local_auth_repository.dart';
import '../data/repositories/local_resource_repository.dart';
import '../data/repositories/offline_first_sync_repository.dart';
import '../data/security/password_hasher.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/resource_repository.dart';
import '../domain/repositories/sync_repository.dart';
import '../domain/services/authorization_service.dart';

class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.auth,
    required this.resources,
    required this.sync,
    required this.authorization,
  });
  final AppDatabase database;
  final AuthRepository auth;
  final ResourceRepository resources;
  final SyncRepository sync;
  final AuthorizationService authorization;

  static Future<AppDependencies> create() async {
    final database = AppDatabase();
    await database.ensureInitialized();
    final authorization = const AuthorizationService();
    final auth = LocalAuthRepository(
      database,
      ArgonPasswordHasher(),
      authorization,
    );
    await auth.ensureDefaultAdmin(
      name: const String.fromEnvironment(
        'DEFAULT_ADMIN_NAME',
        defaultValue: 'Hazard Hero Administrator',
      ),
      email: const String.fromEnvironment(
        'DEFAULT_ADMIN_EMAIL',
        defaultValue: 'admin@hazardhero.local',
      ),
      password: const String.fromEnvironment(
        'DEFAULT_ADMIN_PASSWORD',
        defaultValue: 'HazardHero123!',
      ),
    );
    final sync = OfflineFirstSyncRepository(
      database,
      ConnectivityNetworkMonitor(),
      HttpRemoteSyncGateway(
        baseUrl: const String.fromEnvironment('API_BASE_URL'),
        bearerToken: const String.fromEnvironment('API_AUTH_TOKEN'),
      ),
    );
    final dependencies = AppDependencies._(
      database: database,
      authorization: authorization,
      auth: auth,
      resources: LocalResourceRepository(database, authorization),
      sync: sync,
    );
    await sync.initialize();
    return dependencies;
  }

  Future<void> dispose() async {
    await sync.dispose();
    await database.close();
  }
}
