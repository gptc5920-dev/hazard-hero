import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/emergency_resource.dart';
import '../../domain/repositories/resource_repository.dart';
import '../../domain/services/authorization_service.dart';
import '../local/app_database.dart';
import '../mappers/entity_mappers.dart';

class LocalResourceRepository implements ResourceRepository {
  LocalResourceRepository(this._db, this._authorization, {Uuid? uuid})
    : _uuid = uuid ?? const Uuid();
  final AppDatabase _db;
  final AuthorizationService _authorization;
  final Uuid _uuid;

  @override
  Stream<List<EmergencyResource>> watchAll({ResourceKind? kind}) {
    final query = _db.select(_db.resourceRows)
      ..where((t) => t.deletedAt.isNull());
    if (kind != null) query.where((t) => t.kind.equals(kind.name));
    query.orderBy([(t) => OrderingTerm.desc(t.updatedAt)]);
    return query.watch().map(
      (rows) => rows.map(mapResource).toList(growable: false),
    );
  }

  @override
  Future<EmergencyResource> create({
    required AppUser actor,
    required ResourceDraft draft,
  }) async {
    draft.validate();
    _authorization.requireResourceAccess(actor, draft.kind);
    final now = DateTime.now().toUtc();
    final id = _uuid.v4();
    final row = ResourceRowsCompanion.insert(
      id: id,
      kind: draft.kind.name,
      title: draft.title.trim(),
      description: draft.description.trim(),
      metadataJson: Value(jsonEncode(draft.metadata)),
      imageUrl: Value(draft.metadata['imageUrl']),
      videoUrl: Value(draft.metadata['videoUrl']),
      referenceUrl: Value(draft.metadata['referenceUrl']),
      isActive: Value(draft.isActive),
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.resourceRows).insert(row);
      final saved = await (_db.select(
        _db.resourceRows,
      )..where((t) => t.id.equals(id))).getSingle();
      await _enqueue(saved, 'create');
    });
    return mapResource(
      await (_db.select(
        _db.resourceRows,
      )..where((t) => t.id.equals(id))).getSingle(),
    );
  }

  @override
  Future<EmergencyResource> update({
    required AppUser actor,
    required String id,
    required ResourceDraft draft,
  }) async {
    draft.validate();
    _authorization.requireResourceAccess(actor, draft.kind);
    return _db.transaction(() async {
      final existing =
          await (_db.select(_db.resourceRows)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (existing == null) throw const ResourceNotFoundException();
      if (existing.kind != draft.kind.name) {
        throw const DomainValidationException(
          'Resource type cannot be changed.',
        );
      }
      await (_db.update(_db.resourceRows)..where((t) => t.id.equals(id))).write(
        ResourceRowsCompanion(
          title: Value(draft.title.trim()),
          description: Value(draft.description.trim()),
          metadataJson: Value(jsonEncode(draft.metadata)),
          imageUrl: Value(draft.metadata['imageUrl']),
          videoUrl: Value(draft.metadata['videoUrl']),
          referenceUrl: Value(draft.metadata['referenceUrl']),
          isActive: Value(draft.isActive),
          version: Value(existing.version + 1),
          updatedAt: Value(DateTime.now().toUtc()),
          syncState: Value(SyncState.pending.name),
        ),
      );
      final saved = await (_db.select(
        _db.resourceRows,
      )..where((t) => t.id.equals(id))).getSingle();
      await _enqueue(saved, 'update');
      return mapResource(saved);
    });
  }

  @override
  Future<void> delete({
    required AppUser actor,
    required String id,
  }) => _db.transaction(() async {
    final existing = await (_db.select(
      _db.resourceRows,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (existing == null) throw const ResourceNotFoundException();
    _authorization.requireResourceAccess(
      actor,
      ResourceKind.values.byName(existing.kind),
    );
    await (_db.update(_db.resourceRows)..where((t) => t.id.equals(id))).write(
      ResourceRowsCompanion(
        deletedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
        version: Value(existing.version + 1),
        syncState: Value(SyncState.pending.name),
      ),
    );
    await _enqueue(
      await (_db.select(
        _db.resourceRows,
      )..where((t) => t.id.equals(id))).getSingle(),
      'delete',
    );
  });

  Future<void> _enqueue(ResourceRow row, String operation) => _db
      .into(_db.syncOutbox)
      .insert(
        SyncOutboxCompanion.insert(
          id: _uuid.v4(),
          entityId: row.id,
          entityType: 'resource',
          operation: operation,
          payloadJson: jsonEncode(resourcePayload(row)),
          createdAt: DateTime.now().toUtc(),
        ),
      );
}

class ResourceNotFoundException implements Exception {
  const ResourceNotFoundException();
  @override
  String toString() => 'The resource no longer exists.';
}
