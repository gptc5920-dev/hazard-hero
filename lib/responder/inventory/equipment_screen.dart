import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../shared/widgets/async_state_widgets.dart';
import 'equipment.dart';
import 'equipment_providers.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  const EquipmentScreen({super.key});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  String search = '';
  String? condition;

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(equipmentProvider);
    return Scaffold(
      floatingActionButton: inventory.hasValue
          ? FloatingActionButton.extended(
              onPressed: () => _edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add equipment'),
            )
          : null,
      body: inventory.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppError(
          message: 'Could not load your saved inventory. $error',
          onRetry: () => ref.read(equipmentProvider.notifier).reload(),
        ),
        data: (items) {
          final query = search.trim().toLowerCase();
          final filtered = items
              .where(
                (item) =>
                    (condition == null || item.condition == condition) &&
                    '${item.name} ${item.location} ${item.notes}'
                        .toLowerCase()
                        .contains(query),
              )
              .toList();
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                children: [
                  Text(
                    'Equipment inventory',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Your equipment, saved on this device for your account. Available offline; not shared with other devices or responders.',
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _Summary(label: 'Equipment types', value: items.length),
                      _Summary(
                        label: 'Ready types',
                        value: items.where((item) => item.available > 0).length,
                      ),
                      _Summary(
                        label: 'Need attention',
                        value: items
                            .where((item) => item.condition != 'Ready')
                            .length,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    onChanged: (value) => setState(() => search = value),
                    decoration: const InputDecoration(
                      labelText: 'Search equipment or location',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: condition == null,
                        onSelected: (_) => setState(() => condition = null),
                      ),
                      for (final value in Equipment.conditions)
                        ChoiceChip(
                          label: Text(value),
                          selected: condition == value,
                          onSelected: (_) => setState(() => condition = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (filtered.isEmpty)
                    AppEmpty(
                      icon: Icons.inventory_2_outlined,
                      message: items.isEmpty
                          ? 'No equipment yet. Add your first item to start tracking your supplies.'
                          : 'No equipment matches your search or filter.',
                    ),
                  for (final item in filtered)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.inventory_2_outlined),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    item.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w800),
                                  ),
                                ),
                                PopupMenuButton<String>(
                                  tooltip: 'Equipment actions',
                                  onSelected: (action) => action == 'edit'
                                      ? _edit(item)
                                      : _delete(item),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              item.condition,
                              style: TextStyle(
                                color: item.condition == 'Ready'
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${item.quantity} ${item.unit} total · ${item.inUse} in use · ${item.available} available',
                            ),
                            if (item.location.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('Location: ${item.location}'),
                            ],
                            if (item.notes.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(item.notes),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _edit([Equipment? item]) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => EquipmentEditor(
      item: item,
      onSave: ref.read(equipmentProvider.notifier).upsert,
    ),
  );

  Future<void> _delete(Equipment item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete equipment?'),
        content: Text('Remove ${item.name} from this device’s inventory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(equipmentProvider.notifier).remove(item.id);
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete equipment. $error')),
        );
    }
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.label, required this.value});
  final String label;
  final int value;
  @override
  Widget build(BuildContext context) => Container(
    width: 150,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value', style: Theme.of(context).textTheme.headlineMedium),
        Text(label),
      ],
    ),
  );
}

class EquipmentEditor extends StatefulWidget {
  const EquipmentEditor({super.key, this.item, required this.onSave});
  final Equipment? item;
  final Future<void> Function(Equipment) onSave;
  @override
  State<EquipmentEditor> createState() => _EquipmentEditorState();
}

class _EquipmentEditorState extends State<EquipmentEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.item?.name);
  late final quantity = TextEditingController(
    text: '${widget.item?.quantity ?? 1}',
  );
  late final inUse = TextEditingController(text: '${widget.item?.inUse ?? 0}');
  late final unit = TextEditingController(text: widget.item?.unit ?? 'pcs');
  late final location = TextEditingController(text: widget.item?.location);
  late final notes = TextEditingController(text: widget.item?.notes);
  late String condition = widget.item?.condition ?? 'Ready';
  bool saving = false;
  String? error;

  @override
  void dispose() {
    for (final controller in [name, quantity, inUse, unit, location, notes]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !saving,
    child: AlertDialog(
      title: Text(widget.item == null ? 'Add equipment' : 'Edit equipment'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Equipment name',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter an equipment name.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: quantity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Total quantity',
                  ),
                  validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1
                      ? 'Enter a whole number of at least 1.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: inUse,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Quantity in use',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value ?? '');
                    final total = int.tryParse(quantity.text) ?? 0;
                    return count == null || count < 0 || count > total
                        ? 'Enter a whole number between 0 and $total.'
                        : null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: unit,
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Unit (pcs, sets, kits)',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a unit.'
                      : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Condition'),
                  items: Equipment.conditions
                      .map(
                        (value) =>
                            DropdownMenuItem(value: value, child: Text(value)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setState(() => condition = value ?? condition),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: location,
                  maxLength: 180,
                  decoration: const InputDecoration(
                    labelText: 'Storage location',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: notes,
                  maxLength: 1000,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: saving ? null : _save,
          child: Text(saving ? 'Saving…' : 'Save equipment'),
        ),
      ],
    ),
  );

  Future<void> _save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.onSave(
        Equipment(
          id: widget.item?.id ?? const Uuid().v4(),
          name: name.text,
          quantity: int.parse(quantity.text),
          inUse: int.parse(inUse.text),
          unit: unit.text,
          condition: condition,
          location: location.text,
          notes: notes.text,
        ),
      );
      if (mounted) {
        setState(() => saving = false);
        Navigator.pop(context);
      }
    } catch (failure) {
      if (mounted)
        setState(() {
          saving = false;
          error = 'Could not save equipment. $failure';
        });
    }
  }
}
