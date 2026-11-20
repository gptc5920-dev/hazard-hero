import 'dart:async';
import '../../domain/entities/app_user.dart';
import '../../domain/entities/emergency_resource.dart';
import '../../domain/entities/sync_info.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/resource_repository.dart';
import '../../domain/repositories/sync_repository.dart';
import '../../domain/services/authorization_service.dart';

class WorkspaceState {
  const WorkspaceState({
    required this.resources,
    required this.users,
    required this.selectedKind,
    required this.manageableKinds,
    required this.canManageUsers,
    this.syncInfo = const SyncInfo(
      isOnline: false,
      isConfigured: false,
      isSyncing: false,
      pendingOperations: 0,
    ),
    this.isBusy = false,
    this.error,
  });
  final List<EmergencyResource> resources;
  final List<AppUser> users;
  final ResourceKind? selectedKind;
  final Set<ResourceKind> manageableKinds;
  final bool canManageUsers;
  final SyncInfo syncInfo;
  final bool isBusy;
  final String? error;

  List<EmergencyResource> get visibleResources => selectedKind == null
      ? resources
      : resources
            .where((item) => item.kind == selectedKind)
            .toList(growable: false);
  bool get canManageSelected =>
      selectedKind != null && manageableKinds.contains(selectedKind);
  bool canManage(EmergencyResource resource) =>
      manageableKinds.contains(resource.kind);
  int count(ResourceKind kind) =>
      resources.where((item) => item.kind == kind).length;

  WorkspaceState copyWith({
    List<EmergencyResource>? resources,
    List<AppUser>? users,
    ResourceKind? selectedKind,
    bool clearKind = false,
    Set<ResourceKind>? manageableKinds,
    bool? canManageUsers,
    SyncInfo? syncInfo,
    bool? isBusy,
    String? error,
    bool clearError = false,
  }) => WorkspaceState(
    resources: resources ?? this.resources,
    users: users ?? this.users,
    selectedKind: clearKind ? null : selectedKind ?? this.selectedKind,
    manageableKinds: manageableKinds ?? this.manageableKinds,
    canManageUsers: canManageUsers ?? this.canManageUsers,
    syncInfo: syncInfo ?? this.syncInfo,
    isBusy: isBusy ?? this.isBusy,
    error: clearError ? null : error ?? this.error,
  );
}

class WorkspaceViewModel {
  WorkspaceViewModel({
    required AppUser currentUser,
    required ResourceRepository resources,
    required AuthRepository auth,
    required SyncRepository sync,
    required AuthorizationService authorization,
  }) : _currentUser = currentUser,
       _resources = resources,
       _auth = auth,
       _sync = sync {
    final manageable = ResourceKind.values
        .where((kind) => authorization.canManageResource(currentUser, kind))
        .toSet();
    _state = WorkspaceState(
      resources: const [],
      users: const [],
      selectedKind: ResourceKind.alert,
      manageableKinds: manageable,
      canManageUsers: authorization.canManageUsers(currentUser),
    );
  }

  final AppUser _currentUser;
  final ResourceRepository _resources;
  final AuthRepository _auth;
  final SyncRepository _sync;
  final _states = StreamController<WorkspaceState>.broadcast();
  late WorkspaceState _state;
  StreamSubscription<List<EmergencyResource>>? _resourceSub;
  StreamSubscription<List<AppUser>>? _userSub;
  StreamSubscription<SyncInfo>? _syncSub;
  Stream<WorkspaceState> get states => _states.stream;
  WorkspaceState get state => _state;

  void initialize() {
    _resourceSub = _resources.watchAll().listen(
      (items) => _emit(_state.copyWith(resources: items)),
      onError: _fail,
    );
    _userSub = _auth.watchUsers().listen(
      (items) => _emit(_state.copyWith(users: items)),
      onError: _fail,
    );
    _syncSub = _sync.watchStatus().listen(
      (status) => _emit(_state.copyWith(syncInfo: status)),
      onError: _fail,
    );
  }

  void selectKind(ResourceKind? kind) => _emit(
    _state.copyWith(
      selectedKind: kind,
      clearKind: kind == null,
      clearError: true,
    ),
  );

  Future<void> create(ResourceDraft draft) =>
      _mutate(() => _resources.create(actor: _currentUser, draft: draft));
  Future<void> update(String id, ResourceDraft draft) => _mutate(
    () => _resources.update(actor: _currentUser, id: id, draft: draft),
  );
  Future<void> delete(String id) =>
      _mutate(() => _resources.delete(actor: _currentUser, id: id));
  Future<void> synchronize() => _mutate(_sync.synchronize);

  Future<void> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) => _mutate(
    () => _auth.createUser(
      actor: _currentUser,
      name: name,
      email: email,
      password: password,
      role: role,
    ),
  );

  Future<void> updateUser({
    required String id,
    required String name,
    required String email,
    required UserRole role,
    String? password,
  }) => _mutate(
    () => _auth.updateUser(
      actor: _currentUser,
      userId: id,
      name: name,
      email: email,
      role: role,
      password: password,
    ),
  );

  Future<void> deleteUser(String id) =>
      _mutate(() => _auth.deleteUser(actor: _currentUser, userId: id));

  Future<void> setUserActive(String id, bool active) => _mutate(
    () =>
        _auth.setUserActive(actor: _currentUser, userId: id, isActive: active),
  );

  Future<void> _mutate(Future<Object?> Function() action) async {
    _emit(_state.copyWith(isBusy: true, clearError: true));
    try {
      await action();
      _emit(_state.copyWith(isBusy: false));
    } on Object catch (error) {
      _fail(error);
    }
  }

  void _fail(Object error) =>
      _emit(_state.copyWith(isBusy: false, error: error.toString()));
  void clearError() => _emit(_state.copyWith(clearError: true));
  void _emit(WorkspaceState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() async {
    await _resourceSub?.cancel();
    await _userSub?.cancel();
    await _syncSub?.cancel();
    await _states.close();
  }
}
