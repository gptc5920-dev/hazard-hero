import '../entities/sync_info.dart';

abstract interface class SyncRepository {
  Stream<SyncInfo> watchStatus();
  Future<void> synchronize();
  Future<void> initialize();
  Future<void> dispose();
}
