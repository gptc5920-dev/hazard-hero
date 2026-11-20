import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../citizen/core/citizen_providers.dart';
import '../../citizen/localization/citizen_strings.dart';
import '../../citizen/screens/citizen_menu_screen.dart';
import '../../citizen/widgets/connection_status_banner.dart';
import '../core/responder_providers.dart';

class FieldResponderShell extends ConsumerStatefulWidget {
  const FieldResponderShell({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<FieldResponderShell> createState() =>
      _FieldResponderShellState();
}

class _FieldResponderShellState extends ConsumerState<FieldResponderShell> {
  bool? _lastOnline;

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<bool>>(connectivityProvider, (_, next) {
      final online = next.asData?.value;
      if (online == null || online == _lastOnline) return;
      _lastOnline = online;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        CitizenConnectionNotification.show(
          context,
          online: online,
          strings: CitizenStrings(ref.read(languageProvider)),
          lastSync: ref.read(citizenSyncProvider).lastSync,
        );
      });
      if (online)
        ref.read(citizenSyncProvider.notifier).sync(ref.read(languageProvider));
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(languageProvider, (previous, next) {
      if (previous != next &&
          (ref.read(connectivityProvider).asData?.value ?? false)) {
        ref.read(citizenSyncProvider.notifier).sync(next);
      }
    });
    final path = GoRouterState.of(context).uri.path;
    final selected = path == '/'
        ? 0
        : path.startsWith('/inventory')
        ? 1
        : path.startsWith('/alerts')
        ? 2
        : 3;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Hazard Hero Responder',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'My account',
            onPressed: () => context.go('/account'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      body: SafeArea(top: false, bottom: false, child: widget.child),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) =>
            context.go(const ['/', '/inventory', '/alerts', '/more'][index]),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            label: 'Equipment',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning_amber_rounded),
            label: 'Alerts',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class FieldResponderMenu extends ConsumerWidget {
  const FieldResponderMenu({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    children: [
      ListTile(
        leading: const Icon(Icons.inventory_2_outlined),
        title: const Text('Equipment inventory'),
        subtitle: const Text('Track your response equipment on this device'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/inventory'),
      ),
      ListTile(
        leading: const Icon(Icons.logout),
        title: const Text('Sign out'),
        onTap: () async {
          final auth = ref.read(authProvider.notifier);
          try {
            await auth.logout();
          } catch (_) {
            // Local credentials are cleared by the repository even when the
            // server cannot be reached; finish signing out while offline too.
            auth.expire();
          }
        },
      ),
      const Divider(height: 1),
      const Expanded(child: CitizenMenuScreen()),
    ],
  );
}
