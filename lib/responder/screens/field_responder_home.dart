import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../citizen/screens/home_screen.dart';
import '../inventory/equipment_providers.dart';

class FieldResponderHome extends ConsumerWidget {
  const FieldResponderHome({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventory = ref.watch(equipmentProvider);
    final items = inventory.asData?.value;
    return Column(
      children: [
        Card(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.inventory_2_outlined),
            ),
            title: const Text(
              'Responder equipment',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: Text(
              items == null
                  ? 'Open your device inventory'
                  : '${items.length} equipment types · ${items.where((item) => item.available > 0).length} ready',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/inventory'),
          ),
        ),
        const Expanded(child: CitizenHomeScreen()),
      ],
    );
  }
}
