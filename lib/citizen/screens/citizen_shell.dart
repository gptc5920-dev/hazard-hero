import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../widgets/connection_status_banner.dart';

class CitizenShell extends ConsumerStatefulWidget {
  const CitizenShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<CitizenShell> createState() => _CitizenShellState();
}

class _CitizenShellState extends ConsumerState<CitizenShell> {
  bool? _lastOnline;

  static const _wideDestinations = [
    ('home', Icons.home_outlined, '/'),
    ('alerts', Icons.warning_amber_rounded, '/alerts'),
    ('guidelines', Icons.menu_book_outlined, '/guidelines'),
    ('goBag', Icons.backpack_outlined, '/go-bag'),
    ('calamities', Icons.storm_outlined, '/calamities'),
    ('evacuation', Icons.location_on_outlined, '/evacuation-centers'),
    ('contacts', Icons.call_outlined, '/emergency-contacts'),
    ('downloads', Icons.download_outlined, '/downloads'),
  ];

  static const _mobileDestinations = [
    ('home', Icons.home_outlined, Icons.home_outlined, '/'),
    (
      'evacuation',
      Icons.location_on_outlined,
      Icons.location_on_rounded,
      '/evacuation-centers',
    ),
    (
      'hotlines',
      Icons.call_outlined,
      Icons.call_rounded,
      '/emergency-contacts',
    ),
    ('goBag', Icons.backpack_outlined, Icons.backpack_rounded, '/go-bag'),
    (
      'guides',
      Icons.menu_book_outlined,
      Icons.menu_book_rounded,
      '/guidelines',
    ),
  ];

  int _wideIndex(String path) {
    final index = _wideDestinations.indexWhere(
      (destination) => destination.$3 != '/' && path.startsWith(destination.$3),
    );
    return index < 0 ? 0 : index;
  }

  int _mobileIndex(String path) {
    if (path.startsWith('/evacuation-centers')) return 1;
    if (path.startsWith('/emergency-contacts')) return 2;
    if (path.startsWith('/go-bag')) return 3;
    if (path.startsWith('/guidelines')) return 4;
    if (path == '/') return 0;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual<AsyncValue<bool>>(connectivityProvider, (_, next) {
      final isOnline = next.asData?.value;
      if (isOnline == null || isOnline == _lastOnline) return;

      final wasOnline = _lastOnline;
      _lastOnline = isOnline;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final strings = CitizenStrings(ref.read(languageProvider));
        final sync = ref.read(citizenSyncProvider);
        CitizenConnectionNotification.show(
          context,
          online: isOnline,
          strings: strings,
          lastSync: sync.lastSync,
        );
      });

      if (isOnline && wasOnline != true) {
        ref.read(citizenSyncProvider.notifier).sync(ref.read(languageProvider));
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    ref.listen<String>(languageProvider, (previous, next) {
      if (previous != null &&
          previous != next &&
          (ref.read(connectivityProvider).asData?.value ?? false)) {
        ref.read(citizenSyncProvider.notifier).sync(next);
      }
    });

    final path = GoRouterState.of(context).uri.path;
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final content = SafeArea(bottom: false, child: widget.child);

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _wideIndex(path),
              labelType: NavigationRailLabelType.all,
              leading: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  child: const Icon(Icons.health_and_safety_rounded),
                ),
              ),
              destinations: _wideDestinations
                  .map(
                    (destination) => NavigationRailDestination(
                      icon: Icon(destination.$2),
                      label: Text(strings.text(destination.$1)),
                    ),
                  )
                  .toList(),
              onDestinationSelected: (index) =>
                  context.go(_wideDestinations[index].$3),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ],
        ),
      );
    }
    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _mobileIndex(path),
        onDestinationSelected: (index) =>
            context.go(_mobileDestinations[index].$4),
        destinations: _mobileDestinations
            .map(
              (destination) => NavigationDestination(
                icon: Icon(destination.$2),
                selectedIcon: Icon(destination.$3),
                label: strings.text(destination.$1),
              ),
            )
            .toList(),
      ),
    );
  }
}
