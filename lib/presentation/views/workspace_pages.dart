import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/entities/emergency_resource.dart';
import '../view_models/workspace_view_model.dart';

const _orange = Color(0xfff97316);

Uri? _validWebUri(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null || !uri.hasAuthority) return null;
  return uri.scheme == 'https' || uri.scheme == 'http' ? uri : null;
}

Future<void> _launchGuideUrl(BuildContext context, Uri uri) async {
  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Unable to open this link.')));
  }
}

Future<void> confirmDelete(
  BuildContext context,
  WorkspaceViewModel viewModel,
  EmergencyResource item,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete record?'),
      content: Text(
        '${item.title} will be removed locally and its tombstone queued for synchronization.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  if (confirmed == true) await viewModel.delete(item.id);
}

Future<void> confirmDeleteUser(
  BuildContext context,
  WorkspaceViewModel viewModel,
  AppUser user,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete user?'),
      content: Text(
        '${user.displayName} (${user.email}) and their local sessions will be permanently removed.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Delete user'),
        ),
      ],
    ),
  );
  if (confirmed == true) await viewModel.deleteUser(user.id);
}

IconData kindIcon(ResourceKind kind) => switch (kind) {
  ResourceKind.alert => Icons.warning_amber,
  ResourceKind.evacuationCenter => Icons.location_on,
  ResourceKind.hotline => Icons.phone,
  ResourceKind.guide => Icons.menu_book,
  ResourceKind.goBagItem => Icons.backpack,
};

String kindLabel(ResourceKind kind) => switch (kind) {
  ResourceKind.alert => 'Alerts',
  ResourceKind.evacuationCenter => 'Evacuation centers',
  ResourceKind.hotline => 'Hotlines',
  ResourceKind.guide => 'Preparedness guides',
  ResourceKind.goBagItem => 'Go Bag items',
};

String kindTabLabel(ResourceKind kind) => switch (kind) {
  ResourceKind.alert => 'Alerts',
  ResourceKind.evacuationCenter => 'Centers',
  ResourceKind.hotline => 'Hotlines',
  ResourceKind.guide => 'Guides',
  ResourceKind.goBagItem => 'Go Bag',
};

Future<void> showResourceForm(
  BuildContext context,
  WorkspaceViewModel viewModel,
  ResourceKind kind, {
  EmergencyResource? existing,
}) async {
  final title = TextEditingController(text: existing?.title);
  final description = TextEditingController(text: existing?.description);
  final details = TextEditingController(text: existing?.metadata['details']);
  final address = TextEditingController(text: existing?.metadata['address']);
  final capacity = TextEditingController(text: existing?.metadata['capacity']);
  final imageUrl = TextEditingController(text: existing?.metadata['imageUrl']);
  final videoUrl = TextEditingController(text: existing?.metadata['videoUrl']);
  final referenceUrl = TextEditingController(
    text: existing?.metadata['referenceUrl'],
  );
  var centerStatus = existing?.metadata['status'] ?? 'Open';
  var alertSeverity = existing?.metadata['severity'] ?? 'Warning';
  var active = existing?.isActive ?? true;
  ModalRoute<dynamic>? formRoute;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      formRoute ??= ModalRoute.of(dialogContext);
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Create ${kindLabel(kind)}'
                : 'Edit ${kindLabel(kind)}',
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: description,
                    minLines: 3,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: kind == ResourceKind.evacuationCenter
                          ? 'Description / notes'
                          : 'Description',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (kind == ResourceKind.evacuationCenter) ...[
                    TextField(
                      controller: address,
                      decoration: const InputDecoration(
                        labelText: 'Address',
                        prefixIcon: Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: capacity,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Capacity (persons)',
                        prefixIcon: Icon(Icons.people_outline),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: centerStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        border: OutlineInputBorder(),
                      ),
                      items: const ['Open', 'Preparing', 'Full', 'Closed']
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(value),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => centerStatus = value);
                        }
                      },
                    ),
                  ] else ...[
                    if (kind == ResourceKind.alert) ...[
                      DropdownButtonFormField<String>(
                        initialValue: alertSeverity,
                        decoration: const InputDecoration(
                          labelText: 'Severity',
                          border: OutlineInputBorder(),
                        ),
                        items: const ['Warning', 'Critical', 'Advisory', 'Info']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => alertSeverity = value);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (kind == ResourceKind.guide) ...[
                      TextField(
                        controller: imageUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Image URL (optional)',
                          hintText: 'https://example.com/image.jpg',
                          prefixIcon: Icon(Icons.image_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: videoUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Video URL (optional)',
                          hintText: 'https://youtube.com/watch?v=...',
                          prefixIcon: Icon(Icons.play_circle_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: referenceUrl,
                        keyboardType: TextInputType.url,
                        decoration: const InputDecoration(
                          labelText: 'Reference URL (optional)',
                          hintText: 'https://example.com/full-guide',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: details,
                      decoration: const InputDecoration(
                        labelText: 'Additional details',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    title: const Text('Active'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
  await formRoute?.completed;
  if (submitted == true) {
    final draft = ResourceDraft(
      kind: kind,
      title: title.text,
      description: description.text,
      metadata: {
        if (details.text.trim().isNotEmpty) 'details': details.text.trim(),
        if (kind == ResourceKind.alert) 'severity': alertSeverity,
        if (kind == ResourceKind.evacuationCenter) ...{
          if (address.text.trim().isNotEmpty) 'address': address.text.trim(),
          if (capacity.text.trim().isNotEmpty) 'capacity': capacity.text.trim(),
          'status': centerStatus,
        },
        if (kind == ResourceKind.guide) ...{
          if (imageUrl.text.trim().isNotEmpty) 'imageUrl': imageUrl.text.trim(),
          if (videoUrl.text.trim().isNotEmpty) 'videoUrl': videoUrl.text.trim(),
          if (referenceUrl.text.trim().isNotEmpty)
            'referenceUrl': referenceUrl.text.trim(),
        },
      },
      isActive: active,
    );
    if (existing == null) {
      await viewModel.create(draft);
    } else {
      await viewModel.update(existing.id, draft);
    }
  }
  title.dispose();
  description.dispose();
  details.dispose();
  address.dispose();
  capacity.dispose();
  imageUrl.dispose();
  videoUrl.dispose();
  referenceUrl.dispose();
}

Future<void> showUserForm(
  BuildContext context,
  WorkspaceViewModel viewModel, {
  AppUser? existing,
  bool allowRoleChange = true,
}) async {
  final name = TextEditingController(text: existing?.displayName);
  final email = TextEditingController(text: existing?.email);
  final password = TextEditingController();
  var role = existing?.role ?? UserRole.responder;
  ModalRoute<dynamic>? formRoute;
  final submitted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      formRoute ??= ModalRoute.of(dialogContext);
      return StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Create user' : 'Edit user'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: existing == null
                          ? 'Temporary password'
                          : 'New password (optional)',
                      helperText: existing == null
                          ? null
                          : 'Leave blank to keep the current password',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<UserRole>(
                    initialValue: role,
                    decoration: const InputDecoration(
                      labelText: 'Role',
                      border: OutlineInputBorder(),
                    ),
                    items: UserRole.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value.name),
                          ),
                        )
                        .toList(),
                    onChanged: !allowRoleChange
                        ? null
                        : (value) {
                            if (value != null) {
                              setDialogState(() => role = value);
                            }
                          },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(existing == null ? 'Create' : 'Save changes'),
            ),
          ],
        ),
      );
    },
  );
  await formRoute?.completed;
  if (submitted == true) {
    if (existing == null) {
      await viewModel.createUser(
        name: name.text,
        email: email.text,
        password: password.text,
        role: role,
      );
    } else {
      await viewModel.updateUser(
        id: existing.id,
        name: name.text,
        email: email.text,
        role: role,
        password: password.text.isEmpty ? null : password.text,
      );
    }
  }
  name.dispose();
  email.dispose();
  password.dispose();
}

String _capacityLabel(EmergencyResource item) {
  final capacity = item.metadata['capacity']?.trim();
  if (capacity == null || capacity.isEmpty) return 'Capacity not set';
  final parsed = int.tryParse(capacity.replaceAll(',', ''));
  if (parsed == null) return '$capacity persons';
  final formatted = parsed.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
  return '$formatted persons';
}

String _relativeTime(DateTime timestamp) {
  final elapsed = DateTime.now().difference(timestamp.toLocal());
  if (elapsed.inMinutes < 1) return 'Just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} mins ago';
  if (elapsed.inHours < 24) {
    return '${elapsed.inHours} ${elapsed.inHours == 1 ? 'hour' : 'hours'} ago';
  }
  return '${elapsed.inDays} ${elapsed.inDays == 1 ? 'day' : 'days'} ago';
}

Color _resourceAccent(EmergencyResource item) {
  final severity = item.metadata['severity']?.toLowerCase();
  return switch (severity) {
    'critical' => const Color(0xffd9222a),
    'advisory' => const Color(0xffcc9200),
    'info' => const Color(0xff397bd1),
    _ => const Color(0xffed6c0a),
  };
}

class DashboardPage extends StatelessWidget {
  final WorkspaceState state;

  final AppUser user;
  final VoidCallback onOpenContent;
  const DashboardPage({
    super.key,
    required this.state,
    required this.user,
    required this.onOpenContent,
  });

  @override
  Widget build(BuildContext context) => PageFrame(
    title: '${user.role.name.toUpperCase()} dashboard',
    subtitle: 'Welcome, ${user.displayName}. All figures come from SQLite.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: ResourceKind.values.length,
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 320,
            mainAxisExtent: 150,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
          ),
          itemBuilder: (context, index) {
            final kind = ResourceKind.values[index];
            return Card(
              child: InkWell(
                onTap: onOpenContent,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(kindIcon(kind), color: _orange),
                      const Spacer(),
                      Text(
                        '${state.count(kind)}',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        kindLabel(kind),
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
        if (state.syncInfo.isConfigured) ...[
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: Icon(
                state.syncInfo.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: state.syncInfo.isOnline ? Colors.green : Colors.orange,
              ),
              title: Text(
                state.syncInfo.isOnline
                    ? 'Online and ready to synchronize'
                    : 'Offline - using local SQLite',
              ),
              subtitle: Text(
                '${state.syncInfo.pendingOperations} pending operation(s)',
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  final IconData icon;

  final String title;
  final String message;
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 54),
    child: Column(
      children: [
        Icon(icon, size: 58, color: Colors.grey),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
        ),
      ],
    ),
  );
}

class PageFrame extends StatelessWidget {
  final String title;

  final String subtitle;
  final Widget child;
  final Widget? action;
  const PageFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        sliver: SliverToBoxAdapter(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        sliver: SliverToBoxAdapter(child: child),
      ),
    ],
  );
}

class ResourcesPage extends StatelessWidget {
  final WorkspaceState state;

  final WorkspaceViewModel viewModel;
  const ResourcesPage({
    super.key,
    required this.state,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedKind ?? ResourceKind.alert;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          sliver: SliverToBoxAdapter(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 760),
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: const Color(0xffe1e4e8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 12,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Manage Data',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: state.canManageSelected
                            ? () =>
                                  showResourceForm(context, viewModel, selected)
                            : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _orange,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xffe5e7eb),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(Icons.add, size: 24),
                        label: const Text(
                          'Add New',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _ResourceKindSelector(
                    selected: selected,
                    onSelected: viewModel.selectKind,
                  ),
                  const SizedBox(height: 30),
                  if (state.visibleResources.isEmpty)
                    EmptyState(
                      icon: kindIcon(selected),
                      title: 'No ${kindTabLabel(selected).toLowerCase()} yet',
                      message: state.canManageSelected
                          ? 'Use Add New to create the first record. It will be saved locally and synchronized when a connection is available.'
                          : 'There are no records in this category.',
                    )
                  else
                    ...state.visibleResources.map(
                      (item) => _ResourceTile(
                        item: item,
                        canManage: state.canManage(item),
                        onEdit: () => showResourceForm(
                          context,
                          viewModel,
                          item.kind,
                          existing: item,
                        ),
                        onDelete: () => confirmDelete(context, viewModel, item),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class SyncPage extends StatelessWidget {
  final WorkspaceState state;

  final WorkspaceViewModel viewModel;
  const SyncPage({super.key, required this.state, required this.viewModel});

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'Online and offline availability',
    subtitle: 'Local writes never wait for the network.',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  state.syncInfo.isOnline ? Icons.cloud_done : Icons.cloud_off,
                  size: 56,
                  color: state.syncInfo.isOnline ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),
                Text(
                  state.syncInfo.isConfigured
                      ? (state.syncInfo.isOnline
                            ? 'Sync server available'
                            : 'Working offline')
                      : 'Server not configured',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${state.syncInfo.pendingOperations} local operation(s) waiting',
                ),
                if (state.syncInfo.lastSyncedAt != null)
                  Text(
                    'Last synchronized: ${state.syncInfo.lastSyncedAt!.toLocal()}',
                  ),
                if (state.syncInfo.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      state.syncInfo.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed:
                      !state.syncInfo.isConfigured || state.syncInfo.isSyncing
                      ? null
                      : viewModel.synchronize,
                  icon: const Icon(Icons.sync),
                  label: Text(
                    state.syncInfo.isSyncing
                        ? 'Synchronizing...'
                        : 'Synchronize now',
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Start with --dart-define=API_BASE_URL=https://your-server.example/api to enable the real HTTP sync gateway. Without it, the app remains fully operational using SQLite.',
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
}

class UsersPage extends StatelessWidget {
  final WorkspaceState state;

  final WorkspaceViewModel viewModel;
  final String currentUserId;
  const UsersPage({
    super.key,
    required this.state,
    required this.viewModel,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) => PageFrame(
    title: 'User administration',
    subtitle: 'Create, update, activate, and remove local accounts.',
    action: FilledButton.icon(
      onPressed: () => showUserForm(context, viewModel),
      icon: const Icon(Icons.person_add),
      label: const Text('Add user'),
    ),
    child: state.users.isEmpty
        ? const EmptyState(
            icon: Icons.people_outline,
            title: 'No users',
            message: 'No accounts are available.',
          )
        : Column(
            children: state.users
                .map(
                  (user) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                      leading: CircleAvatar(
                        backgroundColor: user.role == UserRole.admin
                            ? const Color(0xffffeadb)
                            : null,
                        child: Icon(
                          user.role == UserRole.admin
                              ? Icons.admin_panel_settings_outlined
                              : Icons.person_outline,
                          color: user.role == UserRole.admin ? _orange : null,
                        ),
                      ),
                      title: Text(user.displayName),
                      subtitle: Text(
                        '${user.email}\n${user.role.name.toUpperCase()} • ${user.isActive ? 'Active' : 'Disabled'}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      isThreeLine: true,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: user.isActive,
                            onChanged: user.id == currentUserId
                                ? null
                                : (value) =>
                                      viewModel.setUserActive(user.id, value),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Actions for ${user.displayName}',
                            onSelected: (action) {
                              if (action == 'edit') {
                                showUserForm(
                                  context,
                                  viewModel,
                                  existing: user,
                                  allowRoleChange: user.id != currentUserId,
                                );
                              } else if (action == 'delete') {
                                confirmDeleteUser(context, viewModel, user);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'edit',
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(Icons.edit_outlined),
                                  title: Text('Edit user'),
                                ),
                              ),
                              if (user.role != UserRole.admin &&
                                  user.id != currentUserId)
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Icon(
                                      Icons.delete_outline,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                                    title: const Text('Delete user'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
  );
}

class _GuideMedia extends StatelessWidget {
  final EmergencyResource item;

  const _GuideMedia({required this.item});

  @override
  Widget build(BuildContext context) {
    final imageUrl = _validWebUri(item.metadata['imageUrl']);
    final videoUrl = _validWebUri(item.metadata['videoUrl']);
    final referenceUrl = _validWebUri(item.metadata['referenceUrl']);
    if (imageUrl == null && videoUrl == null && referenceUrl == null) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imageUrl != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl.toString(),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 84,
                color: const Color(0xfff3f4f6),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.broken_image_outlined,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (imageUrl != null)
              _MediaLink(
                label: 'View image',
                icon: Icons.image_outlined,
                uri: imageUrl,
              ),
            if (videoUrl != null)
              _MediaLink(
                label: 'Watch video',
                icon: Icons.play_circle_outline,
                uri: videoUrl,
              ),
            if (referenceUrl != null)
              _MediaLink(
                label: 'Open guide',
                icon: Icons.open_in_new,
                uri: referenceUrl,
              ),
          ],
        ),
      ],
    );
  }
}

class _MediaLink extends StatelessWidget {
  final String label;

  final IconData icon;
  final Uri uri;
  const _MediaLink({
    required this.label,
    required this.icon,
    required this.uri,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => _launchGuideUrl(context, uri),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    ),
    icon: Icon(icon, size: 18),
    label: Text(label),
  );
}

class _ResourceKindSelector extends StatelessWidget {
  final ResourceKind selected;

  final ValueChanged<ResourceKind?> onSelected;
  const _ResourceKindSelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const gap = 10.0;
      final width = (constraints.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        runSpacing: 12,
        children: ResourceKind.values.map((kind) {
          final isSelected = kind == selected;
          final fullWidth = kind == ResourceKind.goBagItem;
          return SizedBox(
            width: fullWidth ? constraints.maxWidth : width,
            height: 56,
            child: Material(
              color: isSelected ? _orange : const Color(0xfff3f4f6),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSelected(kind),
                child: Center(
                  child: Text(
                    kindTabLabel(kind),
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xff5e626b),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    },
  );
}

class _ResourceTile extends StatelessWidget {
  final EmergencyResource item;

  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _ResourceTile({
    required this.item,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isCenter = item.kind == ResourceKind.evacuationCenter;
    final accent = _resourceAccent(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: isCenter
            ? null
            : Border(left: BorderSide(color: accent, width: 6)),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0d000000),
            blurRadius: 9,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: canManage ? onEdit : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 0, 18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xff252a32),
                      ),
                    ),
                    const SizedBox(height: 7),
                    if (isCenter)
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 20,
                            color: Color(0xff6d727a),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              item.metadata['address'] ?? item.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff72767d),
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xff72767d),
                          height: 1.25,
                          fontSize: 16,
                        ),
                      ),
                    if (item.kind == ResourceKind.guide) ...[
                      const SizedBox(height: 12),
                      _GuideMedia(item: item),
                    ],
                    const SizedBox(height: 13),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        Text(
                          isCenter
                              ? _capacityLabel(item)
                              : _relativeTime(item.updatedAt),
                          style: const TextStyle(
                            color: Color(0xff9a9da2),
                            fontSize: 15,
                          ),
                        ),
                        _StatusChip(item: item),
                      ],
                    ),
                  ],
                ),
              ),
              if (canManage) ...[
                if (isCenter)
                  _TileAction(
                    icon: Icons.sync,
                    color: const Color(0xff397bd1),
                    background: const Color(0xfff0f6ff),
                    tooltip: 'Update center',
                    onPressed: onEdit,
                  ),
                _TileAction(
                  icon: Icons.delete_outline,
                  color: const Color(0xffe4545d),
                  background: const Color(0xffffe9ea),
                  tooltip: 'Delete ${item.title}',
                  onPressed: onDelete,
                ),
                const SizedBox(width: 2),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final EmergencyResource item;
  const _StatusChip({required this.item});

  @override
  Widget build(BuildContext context) {
    final value = item.kind == ResourceKind.evacuationCenter
        ? (item.metadata['status'] ?? (item.isActive ? 'Open' : 'Closed'))
        : (item.isActive ? 'Active' : 'Inactive');
    final normalized = value.toLowerCase();
    final (background, foreground) = switch (normalized) {
      'open' || 'active' => (const Color(0xffdcfce7), const Color(0xff289951)),
      'preparing' => (const Color(0xfffff4cc), const Color(0xffd7a51a)),
      'full' || 'closed' => (const Color(0xffffe1e2), const Color(0xffdf535b)),
      _ => (const Color(0xfff0f1f3), const Color(0xff777b82)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        value,
        style: TextStyle(color: foreground, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _TileAction extends StatelessWidget {
  final IconData icon;

  final Color color;
  final Color background;
  final String tooltip;
  final VoidCallback onPressed;
  const _TileAction({
    required this.icon,
    required this.color,
    required this.background,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 8),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: background,
        foregroundColor: color,
        minimumSize: const Size(50, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      icon: Icon(icon),
    ),
  );
}
