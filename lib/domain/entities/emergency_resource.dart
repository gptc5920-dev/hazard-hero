enum ResourceKind { alert, evacuationCenter, hotline, guide, goBagItem }

enum SyncState { pending, synced, failed }

class EmergencyResource {
  const EmergencyResource({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.metadata,
    required this.isActive,
    required this.version,
    required this.createdAt,
    required this.updatedAt,
    required this.syncState,
  });

  final String id;
  final ResourceKind kind;
  final String title;
  final String description;
  final Map<String, String> metadata;
  final bool isActive;
  final int version;
  final DateTime createdAt;
  final DateTime updatedAt;
  final SyncState syncState;
}

class ResourceDraft {
  const ResourceDraft({
    required this.kind,
    required this.title,
    required this.description,
    this.metadata = const {},
    this.isActive = true,
  });

  final ResourceKind kind;
  final String title;
  final String description;
  final Map<String, String> metadata;
  final bool isActive;

  void validate() {
    if (title.trim().length < 3) {
      throw const DomainValidationException(
        'Title must contain at least 3 characters.',
      );
    }
    if (description.trim().isEmpty) {
      throw const DomainValidationException('Description is required.');
    }
  }
}

class DomainValidationException implements Exception {
  const DomainValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}
