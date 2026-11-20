import 'dart:async';
import 'dart:convert';
import 'package:drift/drift.dart';
import '../../domain/entities/emergency_resource.dart';
import '../../domain/entities/sync_info.dart';
import '../../domain/repositories/sync_repository.dart';
import '../local/app_database.dart';
import '../network/network_monitor.dart';
import '../remote/remote_sync_gateway.dart';

class OfflineFirstSyncRepository implements SyncRepository {
  OfflineFirstSyncRepository(this._db, this._network, this._remote);
  final AppDatabase _db;
  final NetworkMonitor _network;
  final RemoteSyncGateway _remote;
  final _controller = StreamController<SyncInfo>.broadcast();
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<List<SyncOutboxData>>? _outboxSubscription;
  bool _online = false, _syncing = false;
  int _pending = 0;
  DateTime? _lastSyncedAt;
  String? _error;

  @override
  Stream<SyncInfo> watchStatus() => _controller.stream;

  @override
  Future<void> initialize() async {
    _online = await _network.isNetworkAvailable;
    _networkSubscription = _network.changes.listen((available) {
      _online = available;
      _emit();
      if (available && _remote.isConfigured) unawaited(synchronize());
    });
    _outboxSubscription = (_db.select(_db.syncOutbox)).watch().listen((rows) {
      _pending = rows.length;
      _emit();
    });
    final stored = await (_db.select(
      _db.appKeyValues,
    )..where((t) => t.key.equals('last_synced_at'))).getSingleOrNull();
    _lastSyncedAt = stored == null ? null : DateTime.tryParse(stored.value);
    _emit();
    if (_online && _remote.isConfigured) unawaited(synchronize());
  }

  @override
  Future<void> synchronize() async {
    if (_syncing || !_remote.isConfigured) {
      _emit();
      return;
    }
    if (!await _network.isNetworkAvailable || !await _remote.healthCheck()) {
      _online = false;
      _error =
          'The sync server is unavailable. Local changes remain safely queued.';
      _emit();
      return;
    }
    _online = true;
    _syncing = true;
    _error = null;
    _emit();
    try {
      final operations = await (_db.select(
        _db.syncOutbox,
      )..orderBy([(t) => OrderingTerm.asc(t.createdAt)])).get();
      await _remote.push(operations);
      final cursorRow = await (_db.select(
        _db.appKeyValues,
      )..where((t) => t.key.equals('sync_cursor'))).getSingleOrNull();
      final pull = await _remote.pull(cursor: cursorRow?.value);
      await _db.transaction(() async {
        for (final operation in operations) {
          await (_db.delete(
            _db.syncOutbox,
          )..where((t) => t.id.equals(operation.id))).go();
          await (_db.update(
            _db.resourceRows,
          )..where((t) => t.id.equals(operation.entityId))).write(
            ResourceRowsCompanion(syncState: Value(SyncState.synced.name)),
          );
        }
        for (final json in pull.records) {
          await _applyRemote(json);
        }
        if (pull.cursor != null) {
          await _db
              .into(_db.appKeyValues)
              .insertOnConflictUpdate(
                AppKeyValuesCompanion.insert(
                  key: 'sync_cursor',
                  value: pull.cursor!,
                ),
              );
        }
        _lastSyncedAt = DateTime.now().toUtc();
        await _db
            .into(_db.appKeyValues)
            .insertOnConflictUpdate(
              AppKeyValuesCompanion.insert(
                key: 'last_synced_at',
                value: _lastSyncedAt!.toIso8601String(),
              ),
            );
      });
    } on Object catch (error) {
      _error = error.toString();
      final operations = await _db.select(_db.syncOutbox).get();
      for (final operation in operations) {
        await (_db.update(
          _db.syncOutbox,
        )..where((t) => t.id.equals(operation.id))).write(
          SyncOutboxCompanion(
            attempts: Value(operation.attempts + 1),
            lastError: Value(_error),
          ),
        );
      }
    } finally {
      _syncing = false;
      _emit();
    }
  }

  Future<void> _applyRemote(Map<String, dynamic> json) async {
    final id = json['id'] as String;
    final pending = await (_db.select(
      _db.syncOutbox,
    )..where((t) => t.entityId.equals(id))).getSingleOrNull();
    if (pending != null) {
      return; // Local unsynchronized work is never silently overwritten.
    }
    DateTime date(String key) => DateTime.parse(json[key] as String).toUtc();
    await _db
        .into(_db.resourceRows)
        .insertOnConflictUpdate(
          ResourceRowsCompanion.insert(
            id: id,
            kind: json['kind'] as String,
            title: json['title'] as String,
            description: json['description'] as String,
            metadataJson: Value(
              jsonEncode((json['metadata'] as Map?) ?? const {}),
            ),
            imageUrl: Value((json['metadata'] as Map?)?['imageUrl'] as String?),
            videoUrl: Value((json['metadata'] as Map?)?['videoUrl'] as String?),
            referenceUrl: Value(
              (json['metadata'] as Map?)?['referenceUrl'] as String?,
            ),
            isActive: Value(json['isActive'] as bool? ?? true),
            version: Value(json['version'] as int? ?? 1),
            createdAt: date('createdAt'),
            updatedAt: date('updatedAt'),
            deletedAt: Value(
              json['deletedAt'] == null
                  ? null
                  : DateTime.parse(json['deletedAt'] as String).toUtc(),
            ),
            syncState: Value(SyncState.synced.name),
          ),
        );
  }

  void _emit() {
    if (_controller.isClosed) return;
    _controller.add(
      SyncInfo(
        isOnline: _online,
        isConfigured: _remote.isConfigured,
        isSyncing: _syncing,
        pendingOperations: _pending,
        lastSyncedAt: _lastSyncedAt,
        error: _error,
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _networkSubscription?.cancel();
    await _outboxSubscription?.cancel();
    await _controller.close();
  }
}
