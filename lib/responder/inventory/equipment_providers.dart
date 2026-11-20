import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../citizen/core/citizen_providers.dart';
import '../core/responder_providers.dart';
import 'equipment.dart';
import 'equipment_repository.dart';

final equipmentProvider =
    StateNotifierProvider.autoDispose<
      EquipmentController,
      AsyncValue<List<Equipment>>
    >((ref) {
      final accountId = ref.watch(
        authProvider.select((state) => state.user?.id),
      );
      if (accountId == null) return EquipmentController.signedOut();
      return EquipmentController(
        EquipmentRepository(ref.watch(preferencesProvider), accountId),
      );
    });

class EquipmentController extends StateNotifier<AsyncValue<List<Equipment>>> {
  EquipmentController(this.repository) : super(const AsyncLoading()) {
    reload();
  }

  EquipmentController.signedOut()
    : repository = null,
      super(const AsyncData([]));

  final EquipmentRepository? repository;
  bool _saving = false;

  void reload() {
    try {
      state = AsyncData(repository?.load() ?? []);
    } catch (error, stack) {
      state = AsyncError(error, stack);
    }
  }

  Future<void> upsert(Equipment item) => _commit(
    (records) => [...records.where((record) => record.id != item.id), item],
  );

  Future<void> remove(String id) =>
      _commit((records) => records.where((record) => record.id != id).toList());

  Future<void> _commit(List<Equipment> Function(List<Equipment>) change) async {
    final store = repository;
    if (store == null) throw StateError('Sign in to manage equipment.');
    if (_saving)
      throw StateError('Please wait for the current save to finish.');
    final records = state.asData?.value;
    if (records == null)
      throw StateError('Reload inventory before making changes.');
    _saving = true;
    try {
      final updated = change(records)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await store.save(updated);
      if (mounted) state = AsyncData(updated);
    } finally {
      _saving = false;
    }
  }
}
