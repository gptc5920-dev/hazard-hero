import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/api/api_client.dart';
import '../models/citizen_models.dart';
import '../repositories/citizen_repository.dart';
import '../services/citizen_api_service.dart';

final preferencesProvider = Provider<SharedPreferences>(
  (_) => throw StateError('Citizen bootstrap is not initialized.'),
);
final citizenRepositoryProvider = Provider((ref) {
  final client = ApiClient();
  ref.onDispose(client.close);
  return CitizenRepository(
    CitizenApiService(client),
    ref.watch(preferencesProvider),
  );
});

class LanguageController extends StateNotifier<String> {
  LanguageController(this.prefs)
    : super(prefs.getString('citizen_language') ?? 'en');
  final SharedPreferences prefs;
  Future<void> select(String code) async {
    if (!{'en', 'fil', 'ceb'}.contains(code)) return;
    state = code;
    await prefs.setString('citizen_language', code);
  }
}

final languageProvider = StateNotifierProvider<LanguageController, String>(
  (ref) => LanguageController(ref.watch(preferencesProvider)),
);
final languagesProvider = FutureProvider<List<LanguageOption>>(
  (ref) => ref.watch(citizenRepositoryProvider).languages(),
);
final connectivityProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  try {
    yield _isOnline(await connectivity.checkConnectivity());
  } catch (_) {
    yield true;
  }
  try {
    await for (final results in connectivity.onConnectivityChanged) {
      yield _isOnline(results);
    }
  } catch (_) {
    // Some test and desktop environments do not provide a connectivity stream.
  }
});

bool _isOnline(List<ConnectivityResult> results) =>
    !results.contains(ConnectivityResult.none);

final publicRecordsProvider = FutureProvider.autoDispose
    .family<List<PublicRecord>, String>((ref, module) {
      final language = ref.watch(languageProvider);
      return ref.watch(citizenRepositoryProvider).records(module, language);
    });

class CitizenSyncState {
  const CitizenSyncState({required this.syncing, this.lastSync, this.error});

  final bool syncing;
  final DateTime? lastSync;
  final String? error;

  CitizenSyncState copyWith({
    bool? syncing,
    DateTime? lastSync,
    String? error,
    bool clearError = false,
  }) => CitizenSyncState(
    syncing: syncing ?? this.syncing,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : error ?? this.error,
  );
}

final citizenSyncProvider =
    StateNotifierProvider<CitizenSyncController, CitizenSyncState>(
      (ref) => CitizenSyncController(ref.watch(citizenRepositoryProvider), ref),
    );

class CitizenSyncController extends StateNotifier<CitizenSyncState> {
  CitizenSyncController(this.repository, this.ref)
    : super(CitizenSyncState(syncing: false, lastSync: repository.lastSync));

  final CitizenRepository repository;
  final Ref ref;

  Future<bool> sync(String language) async {
    if (state.syncing) return false;
    state = state.copyWith(syncing: true, clearError: true);
    try {
      await repository.syncAll(language);
      state = CitizenSyncState(syncing: false, lastSync: repository.lastSync);
      for (final module in CitizenRepository.publicModules) {
        ref.invalidate(publicRecordsProvider(module));
      }
      ref.invalidate(languagesProvider);
      return true;
    } catch (error) {
      state = CitizenSyncState(
        syncing: false,
        lastSync: repository.lastSync,
        error: error.toString(),
      );
      return false;
    }
  }
}

final downloadsProvider =
    StateNotifierProvider<
      DownloadsController,
      AsyncValue<List<OfflinePackage>>
    >((ref) => DownloadsController(ref.watch(citizenRepositoryProvider)));

class DownloadsController
    extends StateNotifier<AsyncValue<List<OfflinePackage>>> {
  DownloadsController(this.repo) : super(AsyncData(repo.offlinePackages));
  final CitizenRepository repo;
  double progress = 0;
  Future<void> download(String slug, String lang) async {
    state = const AsyncLoading();
    try {
      await repo.downloadGuideline(
        slug,
        lang,
        onProgress: (value) => progress = value,
      );
      state = AsyncData(repo.offlinePackages);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<void> delete(String id, String lang) async {
    await repo.deletePackage(id, lang);
    state = AsyncData(repo.offlinePackages);
  }
}
