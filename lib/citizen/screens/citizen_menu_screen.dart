import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';

class CitizenMenuScreen extends ConsumerWidget {
  const CitizenMenuScreen({super.key});

  static const items = [
    ('module.go-bag', 'menu.goBag', Icons.backpack_rounded, '/go-bag'),
    (
      'module.calamities',
      'menu.calamities',
      Icons.storm_rounded,
      '/calamities',
    ),
    (
      'module.guidelines',
      'menu.guidelines',
      Icons.menu_book_rounded,
      '/guidelines',
    ),
    (
      'module.evacuation-centers',
      'menu.evacuation',
      Icons.location_on_rounded,
      '/evacuation-centers',
    ),
    (
      'module.emergency-contacts',
      'menu.contacts',
      Icons.call_rounded,
      '/emergency-contacts',
    ),
    ('module.alerts', 'menu.alerts', Icons.warning_amber_rounded, '/alerts'),
    (
      'module.downloads',
      'menu.downloads',
      Icons.download_done_rounded,
      '/downloads',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.text('officialPublicResources'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(strings.text('allResourcesDescription')),
                  const SizedBox(height: 18),
                  ...items.map(
                    (item) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        minTileHeight: 78,
                        leading: CircleAvatar(child: Icon(item.$3)),
                        title: Text(
                          strings.text(item.$1),
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(strings.text(item.$2)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => context.go(item.$4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
