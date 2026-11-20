import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/responder_providers.dart';
import '../widgets/backend_connection_chip.dart';

final _adminNavigationForeground = WidgetStateColor.resolveWith((states) {
  if (states.contains(WidgetState.selected) ||
      states.contains(WidgetState.hovered) ||
      states.contains(WidgetState.focused)) {
    return const Color(0xffdd2d4a);
  }
  return const Color(0xfffff3f5);
});

class ResponderShell extends ConsumerStatefulWidget {
  const ResponderShell({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<ResponderShell> createState() => _ResponderShellState();
}

class _ResponderShellState extends ConsumerState<ResponderShell> {
  bool expanded = true;

  static const links = [
    ('Dashboard', Icons.dashboard_rounded, '/dashboard'),
    ('Go Bag', Icons.backpack_rounded, '/go-bag'),
    ('Calamities', Icons.storm_rounded, '/calamities'),
    ('Guidelines', Icons.menu_book_rounded, '/guidelines'),
    ('Translations', Icons.translate_rounded, '/translations'),
    ('Languages', Icons.language_rounded, '/languages'),
    ('Evacuation', Icons.location_on_rounded, '/evacuation-centers'),
    ('Contacts', Icons.call_rounded, '/emergency-contacts'),
    ('Alerts', Icons.warning_amber_rounded, '/alerts'),
    ('Responders', Icons.groups_rounded, '/responders'),
    ('Audit Logs', Icons.history_rounded, '/audit-logs'),
    ('My Account', Icons.manage_accounts_rounded, '/account'),
  ];

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final index = links.indexWhere((item) => path.startsWith(item.$3));
    return index < 0 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final selected = _selectedIndex(context);
    final user = ref.watch(authProvider).user;

    if (wide) {
      return Scaffold(
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: expanded ? 252 : 80,
              color: const Color(0xffdd2d4a),
              child: _NavigationMenu(
                expanded: expanded,
                links: links,
                selected: selected,
                userName: user?.name ?? 'Responder',
                userOffice: user?.office ?? '',
                onToggle: () => setState(() => expanded = !expanded),
                onNavigate: (path) => context.go(path),
                onLogout: _logout,
              ),
            ),
            Expanded(
              child: ColoredBox(
                color: const Color(0xfffffbfc),
                child: Column(
                  children: [
                    _DesktopTopBar(
                      title: links[selected].$1,
                      userName: user?.name ?? 'Responder',
                      userOffice: user?.office ?? '',
                    ),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Text(links[selected].$1),
        actions: [
          const BackendConnectionChip(compact: true),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 9),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xfffce8ec),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Text(
              'ADMIN',
              style: TextStyle(
                color: Color(0xffa91f38),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              radius: 17,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(_initials(user?.name ?? 'Responder')),
            ),
          ),
        ],
      ),
      drawer: Drawer(
        width: 278,
        backgroundColor: const Color(0xffdd2d4a),
        child: _NavigationMenu(
          expanded: true,
          links: links,
          selected: selected,
          userName: user?.name ?? 'Responder',
          userOffice: user?.office ?? '',
          onNavigate: (path) {
            Navigator.of(context).pop();
            context.go(path);
          },
          onLogout: _logout,
        ),
      ),
      body: ColoredBox(color: const Color(0xfffffbfc), child: widget.child),
    );
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Sign out?'),
        content: const Text('Your secure responder session will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldLogout == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.userName,
    required this.userOffice,
  });
  final String title;
  final String userName;
  final String userOffice;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 24),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: Color(0xfff0d8de))),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              Text(
                'Admin workspace',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: const Color(0xff8f6b74)),
              ),
            ],
          ),
        ),
        const BackendConnectionChip(),
        const SizedBox(width: 14),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
            Text(
              userOffice.isEmpty ? 'Responder' : userOffice,
              style: const TextStyle(color: Color(0xff8f6b74), fontSize: 10),
            ),
          ],
        ),
        const SizedBox(width: 9),
        CircleAvatar(
          radius: 18,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(_initials(userName)),
        ),
      ],
    ),
  );
}

class _NavigationMenu extends StatelessWidget {
  const _NavigationMenu({
    required this.expanded,
    required this.links,
    required this.selected,
    required this.userName,
    required this.userOffice,
    required this.onNavigate,
    required this.onLogout,
    this.onToggle,
  });
  final bool expanded;
  final List<(String, IconData, String)> links;
  final int selected;
  final String userName;
  final String userOffice;
  final ValueChanged<String> onNavigate;
  final VoidCallback onLogout;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        SizedBox(
          height: 70,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                const CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundColor: Color(0xffdd2d4a),
                  child: Icon(Icons.health_and_safety_rounded),
                ),
                if (expanded) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hazard Hero',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Operations console',
                          style: TextStyle(
                            color: Color(0xffffd9e0),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onToggle != null)
                    IconButton(
                      tooltip: 'Collapse navigation',
                      onPressed: onToggle,
                      color: Colors.white,
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                ],
              ],
            ),
          ),
        ),
        if (!expanded && onToggle != null)
          IconButton(
            tooltip: 'Expand navigation',
            onPressed: onToggle,
            color: Colors.white,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        const Divider(color: Color(0xffea7085), height: 1),
        if (expanded)
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 14, 18, 3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'WORKSPACE',
                style: TextStyle(
                  color: Color(0xffffd9e0),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.fromLTRB(10, expanded ? 6 : 12, 10, 12),
            itemCount: links.length,
            itemBuilder: (context, index) {
              final item = links[index];
              final isSelected = selected == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Tooltip(
                  message: expanded ? '' : item.$1,
                  child: ListTile(
                    minTileHeight: 46,
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: Colors.white,
                    hoverColor: Colors.white,
                    focusColor: Colors.white,
                    iconColor: _adminNavigationForeground,
                    textColor: _adminNavigationForeground,
                    selectedColor: const Color(0xffdd2d4a),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: Icon(item.$2, size: 21),
                    title: expanded
                        ? Text(
                            item.$1,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          )
                        : null,
                    onTap: () => onNavigate(item.$3),
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(color: Color(0xffea7085), height: 1),
        if (expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(0xffb5233c),
                  foregroundColor: Colors.white,
                  child: Text(_initials(userName)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        userName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        userOffice.isEmpty
                            ? 'Authorized responder'
                            : userOffice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xffffd9e0),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 12),
          child: Tooltip(
            message: expanded ? '' : 'Sign out',
            child: ListTile(
              minTileHeight: 46,
              hoverColor: Colors.white,
              focusColor: Colors.white,
              textColor: _adminNavigationForeground,
              iconColor: _adminNavigationForeground,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              leading: const Icon(Icons.logout_rounded),
              title: expanded ? const Text('Sign out') : null,
              onTap: onLogout,
            ),
          ),
        ),
      ],
    ),
  );
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .toList();
  if (parts.isEmpty) return 'R';
  return parts.map((part) => part[0].toUpperCase()).join();
}
