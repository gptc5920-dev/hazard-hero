import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class UserAccounts extends Table {
  TextColumn get id => text()();
  TextColumn get email => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get role => text()();
  TextColumn get passwordHash => text()();
  TextColumn get passwordSalt => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AuthSessionRows extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastAuthenticatedAt => dateTime()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ResourceRows extends Table {
  TextColumn get id => text()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get description => text()();
  TextColumn get metadataJson => text().withDefault(const Constant('{}'))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  IntColumn get version => integer().withDefault(const Constant(1))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('pending'))();
  TextColumn get imageUrl => text().nullable()();
  TextColumn get videoUrl => text().nullable()();
  TextColumn get referenceUrl => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SyncOutbox extends Table {
  TextColumn get id => text()();
  TextColumn get entityId => text()();
  TextColumn get entityType => text()();
  TextColumn get operation => text()();
  TextColumn get payloadJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
}

class AppKeyValues extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    UserAccounts,
    AuthSessionRows,
    ResourceRows,
    SyncOutbox,
    AppKeyValues,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase({QueryExecutor? executor})
    : super(
        executor ??
            driftDatabase(
              name: 'hazard_hero',
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.dart.js'),
              ),
            ),
      );

  @override
  int get schemaVersion => 2;

  /// Opens the database, applies pending creation/migrations, and verifies
  /// that the core schema is available before repositories start using it.
  Future<void> ensureInitialized() async {
    const requiredTables = {
      'user_accounts',
      'auth_session_rows',
      'resource_rows',
      'sync_outbox',
      'app_key_values',
    };
    final rows = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table'",
      readsFrom: const {},
    ).get();
    final tables = rows.map((row) => row.read<String>('name')).toSet();
    final missing = requiredTables.difference(tables);
    if (missing.isNotEmpty) {
      throw StateError(
        'SQLite initialization failed. Missing tables: ${missing.join(', ')}',
      );
    }
    final resourceColumns = await customSelect(
      "SELECT name FROM pragma_table_info('resource_rows')",
      readsFrom: const {},
    ).get();
    final columnNames = resourceColumns
        .map((row) => row.read<String>('name'))
        .toSet();
    const requiredMediaColumns = {'image_url', 'video_url', 'reference_url'};
    final missingColumns = requiredMediaColumns.difference(columnNames);
    if (missingColumns.isNotEmpty) {
      throw StateError(
        'SQLite initialization failed. Missing resource columns: ${missingColumns.join(', ')}',
      );
    }
  }

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(resourceRows, resourceRows.imageUrl);
        await migrator.addColumn(resourceRows, resourceRows.videoUrl);
        await migrator.addColumn(resourceRows, resourceRows.referenceUrl);
        await customStatement(
          "UPDATE resource_rows SET image_url = json_extract(metadata_json, '\$.imageUrl'), video_url = json_extract(metadata_json, '\$.videoUrl'), reference_url = json_extract(metadata_json, '\$.referenceUrl') WHERE kind = 'guide'",
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
