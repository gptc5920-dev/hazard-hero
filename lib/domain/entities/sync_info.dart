class SyncInfo {
  const SyncInfo({
    required this.isOnline,
    required this.isConfigured,
    required this.isSyncing,
    required this.pendingOperations,
    this.lastSyncedAt,
    this.error,
  });

  final bool isOnline;
  final bool isConfigured;
  final bool isSyncing;
  final int pendingOperations;
  final DateTime? lastSyncedAt;
  final String? error;
}
