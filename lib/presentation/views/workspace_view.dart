import 'package:flutter/material.dart';
import '../../app/app_dependencies.dart';
import '../../domain/entities/app_user.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/workspace_view_model.dart';
import 'workspace_pages.dart';

class WorkspaceView extends StatefulWidget {
  const WorkspaceView({
    super.key,
    required this.session,
    required this.dependencies,
    required this.authViewModel,
  });

  final AuthSession session;
  final AppDependencies dependencies;
  final AuthViewModel authViewModel;

  @override
  State<WorkspaceView> createState() => _WorkspaceViewState();
}

class _WorkspaceViewState extends State<WorkspaceView> {
  late final WorkspaceViewModel viewModel;
  late int page;

  @override
  void initState() {
    super.initState();
    page = widget.session.user.role == UserRole.responder ? 1 : 0;
    viewModel = WorkspaceViewModel(
      currentUser: widget.session.user,
      resources: widget.dependencies.resources,
      auth: widget.dependencies.auth,
      sync: widget.dependencies.sync,
      authorization: widget.dependencies.authorization,
    )..initialize();
  }

  @override
  void dispose() {
    viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<WorkspaceState>(
    stream: viewModel.states,
    initialData: viewModel.state,
    builder: (context, snapshot) {
      final state = snapshot.data!;
      final destinations = <_Destination>[
        const _Destination('Dashboard', Icons.dashboard_outlined),
        const _Destination('Content', Icons.storage_outlined),
        if (state.canManageUsers)
          const _Destination('Users', Icons.manage_accounts_outlined),
        const _Destination('Sync', Icons.sync_outlined),
      ];
      if (page >= destinations.length) page = 0;

      final pages = <Widget>[
        DashboardPage(
          state: state,
          user: widget.session.user,
          onOpenContent: () => setState(() => page = 1),
        ),
        ResourcesPage(state: state, viewModel: viewModel),
        if (state.canManageUsers)
          UsersPage(
            state: state,
            viewModel: viewModel,
            currentUserId: widget.session.user.id,
          ),
        SyncPage(state: state, viewModel: viewModel),
      ];

      return LayoutBuilder(
        builder: (context, constraints) {
          final mobile = constraints.maxWidth < 650;
          final desktop = constraints.maxWidth >= 1100;
          final body = Column(
            children: [
              if (state.error != null)
                MaterialBanner(
                  content: Text(state.error!),
                  actions: [
                    TextButton(
                      onPressed: viewModel.clearError,
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              if (state.isBusy) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: IndexedStack(index: page, children: pages),
              ),
            ],
          );
          return Scaffold(
            appBar: mobile
                ? AppBar(
                    leading: page == 1
                        ? IconButton(
                            tooltip: 'Back',
                            onPressed: () => setState(() => page = 0),
                            icon: const Icon(Icons.arrow_back),
                          )
                        : null,
                    title: Text(
                      page == 1 ? 'Responder Mode' : 'Hazard Hero',
                      style: TextStyle(
                        color: page == 1 ? const Color(0xffed7a21) : null,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    centerTitle: page == 1,
                    actions: page == 1
                        ? null
                        : [
                            IconButton(
                              tooltip: 'Sign out',
                              onPressed: widget.authViewModel.signOut,
                              icon: const Icon(Icons.logout),
                            ),
                          ],
                  )
                : null,
            body: SafeArea(
              child: mobile
                  ? body
                  : Row(
                      children: [
                        NavigationRail(
                          extended: desktop,
                          selectedIndex: page,
                          onDestinationSelected: (value) =>
                              setState(() => page = value),
                          leading: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Icon(
                              Icons.shield,
                              color: Color(0xfff97316),
                              size: 32,
                            ),
                          ),
                          destinations: destinations
                              .map(
                                (item) => NavigationRailDestination(
                                  icon: Icon(item.icon),
                                  label: Text(item.label),
                                ),
                              )
                              .toList(),
                          trailing: Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: IconButton(
                                tooltip: 'Sign out',
                                onPressed: widget.authViewModel.signOut,
                                icon: const Icon(Icons.logout),
                              ),
                            ),
                          ),
                        ),
                        const VerticalDivider(width: 1),
                        Expanded(child: body),
                      ],
                    ),
            ),
            bottomNavigationBar: mobile && page != 1
                ? NavigationBar(
                    selectedIndex: page,
                    onDestinationSelected: (value) =>
                        setState(() => page = value),
                    destinations: destinations
                        .map(
                          (item) => NavigationDestination(
                            icon: Icon(item.icon),
                            label: item.label,
                          ),
                        )
                        .toList(),
                  )
                : null,
          );
        },
      );
    },
  );
}

class _Destination {
  const _Destination(this.label, this.icon);
  final String label;
  final IconData icon;
}
