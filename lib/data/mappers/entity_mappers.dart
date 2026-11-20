import 'dart:convert';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/emergency_resource.dart';
import '../local/app_database.dart';

AppUser mapUser(UserAccount row) => AppUser(
  id: row.id,
  email: row.email,
  displayName: row.displayName,
  role: UserRole.values.byName(row.role),
  isActive: row.isActive,
);

Map<String, String> _resourceMetadata(ResourceRow row) {
  final metadata = (jsonDecode(row.metadataJson) as Map<String, dynamic>).map(
    (key, value) => MapEntry(key, value.toString()),
  );
  if (row.imageUrl != null) metadata['imageUrl'] = row.imageUrl!;
  if (row.videoUrl != null) metadata['videoUrl'] = row.videoUrl!;
  if (row.referenceUrl != null) metadata['referenceUrl'] = row.referenceUrl!;
  return metadata;
}

EmergencyResource mapResource(ResourceRow row) => EmergencyResource(
  id: row.id,
  kind: ResourceKind.values.byName(row.kind),
  title: row.title,
  description: row.description,
  metadata: _resourceMetadata(row),
  isActive: row.isActive,
  version: row.version,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
  syncState: SyncState.values.byName(row.syncState),
);

Map<String, Object?> resourcePayload(ResourceRow row) => {
  'id': row.id,
  'kind': row.kind,
  'title': row.title,
  'description': row.description,
  'metadata': _resourceMetadata(row),
  'isActive': row.isActive,
  'version': row.version,
  'createdAt': row.createdAt.toUtc().toIso8601String(),
  'updatedAt': row.updatedAt.toUtc().toIso8601String(),
  'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
};
