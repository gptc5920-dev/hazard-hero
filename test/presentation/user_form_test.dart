import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazard_hero/domain/entities/app_user.dart';
import 'package:hazard_hero/domain/entities/emergency_resource.dart';
import 'package:hazard_hero/domain/entities/sync_info.dart';
import 'package:hazard_hero/domain/repositories/auth_repository.dart';
import 'package:hazard_hero/domain/repositories/resource_repository.dart';
import 'package:hazard_hero/domain/repositories/sync_repository.dart';
import 'package:hazard_hero/domain/services/authorization_service.dart';
import 'package:hazard_hero/presentation/view_models/workspace_view_model.dart';
import 'package:hazard_hero/presentation/views/workspace_pages.dart';

class _AuthFake implements AuthRepository {
  String? updatedName;

  @override
  Future<AppUser> updateUser({
    required AppUser actor,
    required String userId,
    required String name,
    required String email,
    required UserRole role,
    String? password,
  }) async {
    updatedName = name;
    return AppUser(
      id: userId,
      email: email,
      displayName: name,
      role: role,
      isActive: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ResourceFake implements ResourceRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SyncFake implements SyncRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('Save changes updates a user before closing the dialog', (
    tester,
  ) async {
    const admin = AppUser(
      id: 'admin',
      email: 'admin@example.com',
      displayName: 'Original Admin',
      role: UserRole.admin,
      isActive: true,
    );
    final auth = _AuthFake();
    final viewModel = WorkspaceViewModel(
      currentUser: admin,
      resources: _ResourceFake(),
      auth: auth,
      sync: _SyncFake(),
      authorization: const AuthorizationService(),
    );
    addTearDown(viewModel.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showUserForm(
                context,
                viewModel,
                existing: admin,
                allowRoleChange: false,
              ),
              child: const Text('Edit'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Updated Admin');
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(auth.updatedName, 'Updated Admin');
    expect(find.text('Save changes'), findsNothing);
  });

  testWidgets('workspace pages do not overflow on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const admin = AppUser(
      id: 'admin',
      email: 'administrator-with-a-long-email@example.com',
      displayName: 'Emergency Management Administrator',
      role: UserRole.admin,
      isActive: true,
    );
    const responder = AppUser(
      id: 'responder',
      email: 'responder-with-a-long-email@example.com',
      displayName: 'Community Emergency Responder',
      role: UserRole.responder,
      isActive: true,
    );
    final viewModel = WorkspaceViewModel(
      currentUser: admin,
      resources: _ResourceFake(),
      auth: _AuthFake(),
      sync: _SyncFake(),
      authorization: const AuthorizationService(),
    );
    addTearDown(viewModel.dispose);
    final now = DateTime(2026);
    final resource = EmergencyResource(
      id: 'center',
      kind: ResourceKind.evacuationCenter,
      title: 'Community Evacuation Center With A Long Name',
      description: 'A safe evacuation center for the entire community.',
      metadata: const {
        'address': 'A long street address, Sample Municipality',
        'capacity': '1000',
        'status': 'Open',
      },
      isActive: true,
      version: 1,
      createdAt: now,
      updatedAt: now,
      syncState: SyncState.synced,
    );
    final state = WorkspaceState(
      resources: [resource],
      users: const [admin, responder],
      selectedKind: ResourceKind.evacuationCenter,
      manageableKinds: ResourceKind.values.toSet(),
      canManageUsers: true,
      syncInfo: const SyncInfo(
        isOnline: false,
        isConfigured: false,
        isSyncing: false,
        pendingOperations: 0,
      ),
    );

    for (final page in <Widget>[
      DashboardPage(state: state, user: admin, onOpenContent: () {}),
      ResourcesPage(state: state, viewModel: viewModel),
      UsersPage(state: state, viewModel: viewModel, currentUserId: admin.id),
    ]) {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });
}
