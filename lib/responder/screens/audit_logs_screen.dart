import 'dart:convert';

import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/async_state_widgets.dart';
import '../core/responder_providers.dart';
import '../models/responder_models.dart';

class AuditLogsScreen extends ConsumerStatefulWidget {
  const AuditLogsScreen({super.key});

  @override
  ConsumerState<AuditLogsScreen> createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends ConsumerState<AuditLogsScreen> {
  String _search = '';
  String _action = 'All actions';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(managedRecordsProvider('audit-logs'));

    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 900;
          final horizontal = desktop ? 24.0 : 14.0;
          return Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 14),
                child: _Header(
                  onRefresh: () =>
                      ref.invalidate(managedRecordsProvider('audit-logs')),
                ),
              ),
              Expanded(
                child: state.when(
                  loading: () => const AppLoading(),
                  error: (error, _) => AppError(
                    message: error.toString(),
                    onRetry: () =>
                        ref.invalidate(managedRecordsProvider('audit-logs')),
                  ),
                  data: (rows) => _buildData(
                    context,
                    rows,
                    desktop: desktop,
                    horizontal: horizontal,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildData(
    BuildContext context,
    List<ManagedRecord> rows, {
    required bool desktop,
    required double horizontal,
  }) {
    final actions = {
      'All actions',
      ...rows
          .map((row) => _read(row, 'action'))
          .where((value) => value.isNotEmpty),
    }.toList();
    if (!actions.contains(_action)) _action = 'All actions';

    final normalized = _search.toLowerCase();
    final filtered = rows.where((row) {
      final data = row.data;
      final matchesAction =
          _action == 'All actions' || _read(row, 'action') == _action;
      final matchesSearch =
          normalized.isEmpty ||
          [
            data['action'],
            data['module'],
            data['user_email'],
            data['record_description'],
            data['record_id'],
          ].any((value) => value.toString().toLowerCase().contains(normalized));
      return matchesAction && matchesSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
          child: _SummaryStrip(
            total: rows.length,
            filtered: filtered.length,
            modules: rows
                .map((row) => _read(row, 'module'))
                .where((value) => value.isNotEmpty)
                .toSet()
                .length,
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
          child: desktop
              ? Row(
                  children: [
                    Expanded(child: _searchField()),
                    const SizedBox(width: 12),
                    SizedBox(width: 220, child: _actionPicker(actions)),
                  ],
                )
              : Column(
                  children: [
                    _searchField(),
                    const SizedBox(height: 10),
                    _actionPicker(actions),
                  ],
                ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmpty(message: 'No audit entries match this view.')
              : desktop
              ? _desktopTable(filtered, horizontal)
              : _mobileList(filtered, horizontal),
        ),
      ],
    );
  }

  Widget _searchField() => SearchBar(
    hintText: 'Search user, module, record, or action',
    leading: const Icon(Icons.search_rounded),
    trailing: [
      if (_search.isNotEmpty)
        IconButton(
          tooltip: 'Clear search',
          onPressed: () => setState(() => _search = ''),
          icon: const Icon(Icons.close_rounded),
        ),
    ],
    onChanged: (value) => setState(() => _search = value.trim()),
  );

  Widget _actionPicker(List<String> actions) => DropdownButtonFormField<String>(
    initialValue: _action,
    decoration: const InputDecoration(
      labelText: 'Action type',
      prefixIcon: Icon(Icons.tune_rounded),
    ),
    items: [
      for (final action in actions)
        DropdownMenuItem(
          value: action,
          child: Text(_label(action), overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: (value) => setState(() => _action = value ?? 'All actions'),
  );

  Widget _desktopTable(List<ManagedRecord> rows, double horizontal) => Padding(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
    child: Card(
      child: DataTable2(
        minWidth: 860,
        columnSpacing: 16,
        horizontalMargin: 20,
        headingRowHeight: 52,
        dataRowHeight: 66,
        fixedTopRows: 1,
        columns: const [
          DataColumn2(label: Text('ACTIVITY'), size: ColumnSize.L),
          DataColumn2(label: Text('MODULE'), size: ColumnSize.M),
          DataColumn2(label: Text('PERFORMED BY'), size: ColumnSize.L),
          DataColumn2(label: Text('DATE & TIME'), size: ColumnSize.M),
          DataColumn2(label: Text(''), fixedWidth: 48),
        ],
        rows: [
          for (final row in rows)
            DataRow2(
              onTap: () => _showDetails(row),
              cells: [
                DataCell(
                  Row(
                    children: [
                      _ActionIcon(action: _read(row, 'action')),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _label(_read(row, 'action')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              _read(row, 'record_description').isEmpty
                                  ? 'Record ${_shortId(_read(row, 'record_id'))}'
                                  : _read(row, 'record_description'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xff76515b),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(_ModuleChip(label: _read(row, 'module'))),
                DataCell(Text(_actor(row))),
                DataCell(Text(_dateTime(_read(row, 'created_at')))),
                DataCell(
                  IconButton(
                    tooltip: 'View audit details',
                    onPressed: () => _showDetails(row),
                    icon: const Icon(Icons.open_in_new_rounded, size: 19),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _mobileList(
    List<ManagedRecord> rows,
    double horizontal,
  ) => ListView.separated(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 28),
    itemCount: rows.length,
    separatorBuilder: (_, _) => const SizedBox(height: 9),
    itemBuilder: (context, index) {
      final row = rows[index];
      return Card(
        child: InkWell(
          onTap: () => _showDetails(row),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActionIcon(action: _read(row, 'action')),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _label(_read(row, 'action')),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          _ModuleChip(label: _read(row, 'module')),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _read(row, 'record_description').isEmpty
                            ? 'Record ${_shortId(_read(row, 'record_id'))}'
                            : _read(row, 'record_description'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_actor(row)} • ${_dateTime(_read(row, 'created_at'))}',
                        style: const TextStyle(
                          color: Color(0xff76515b),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _showDetails(ManagedRecord row) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: _ActionIcon(action: _read(row, 'action')),
      title: Text('${_label(_read(row, 'action'))} activity'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 560),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _DetailRow(label: 'Module', value: _label(_read(row, 'module'))),
              _DetailRow(label: 'Performed by', value: _actor(row)),
              _DetailRow(
                label: 'Date and time',
                value: _dateTime(_read(row, 'created_at')),
              ),
              _DetailRow(
                label: 'Record',
                value: _read(row, 'record_description').isEmpty
                    ? _read(row, 'record_id')
                    : _read(row, 'record_description'),
              ),
              if (_read(row, 'ip_address').isNotEmpty)
                _DetailRow(
                  label: 'IP address',
                  value: _read(row, 'ip_address'),
                ),
              const SizedBox(height: 12),
              _JsonPanel(
                title: 'Previous values',
                value: row.data['previous_values'],
              ),
              const SizedBox(height: 10),
              _JsonPanel(title: 'New values', value: row.data['new_values']),
            ],
          ),
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xfffce8ec),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.history_rounded, color: Color(0xffdd2d4a)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Audit activity',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(
              'Review changes made across responder-managed content.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xff76515b)),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Refresh activity',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.total,
    required this.filtered,
    required this.modules,
  });
  final int total;
  final int filtered;
  final int modules;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      child: Wrap(
        spacing: 26,
        runSpacing: 10,
        children: [
          _SummaryValue(
            icon: Icons.receipt_long_rounded,
            label: 'Total activity',
            value: '$total',
          ),
          _SummaryValue(
            icon: Icons.filter_alt_rounded,
            label: 'Visible results',
            value: '$filtered',
          ),
          _SummaryValue(
            icon: Icons.dashboard_customize_rounded,
            label: 'Modules touched',
            value: '$modules',
          ),
        ],
      ),
    ),
  );
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 19, color: const Color(0xffdd2d4a)),
      const SizedBox(width: 8),
      Text('$label  ', style: const TextStyle(color: Color(0xff76515b))),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.action});
  final String action;

  @override
  Widget build(BuildContext context) {
    final normalized = action.toLowerCase();
    final (icon, foreground, background) = normalized.contains('delete')
        ? (
            Icons.delete_outline_rounded,
            const Color(0xffb91c1c),
            const Color(0xfffee2e2),
          )
        : normalized.contains('create')
        ? (
            Icons.add_circle_outline_rounded,
            const Color(0xff047857),
            const Color(0xffd1fae5),
          )
        : normalized.contains('publish')
        ? (
            Icons.campaign_outlined,
            const Color(0xff1d4ed8),
            const Color(0xffdbeafe),
          )
        : (
            Icons.edit_note_rounded,
            const Color(0xffa91f38),
            const Color(0xfffce8ec),
          );
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: foreground, size: 21),
    );
  }
}

class _ModuleChip extends StatelessWidget {
  const _ModuleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: const Color(0xfffce8ec),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Text(
      _label(label),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Color(0xffa91f38),
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xff76515b),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value.isEmpty ? 'Not recorded' : value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _JsonPanel extends StatelessWidget {
  const _JsonPanel({required this.title, required this.value});
  final String title;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final empty =
        value == null ||
        (value is Map && (value! as Map).isEmpty) ||
        (value is List && (value! as List).isEmpty);
    final formatted = empty
        ? 'No values recorded'
        : const JsonEncoder.withIndent('  ').convert(value);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xfffff7f8),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xfff0d8de)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 7),
          SelectableText(
            formatted,
            style: const TextStyle(
              color: Color(0xff76515b),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

String _read(ManagedRecord row, String key) =>
    row.data[key]?.toString().trim() ?? '';

String _actor(ManagedRecord row) {
  final email = _read(row, 'user_email');
  return email.isEmpty ? 'System' : email;
}

String _label(String value) {
  if (value.isEmpty) return 'Unknown';
  final normalized = value.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  return normalized
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _shortId(String value) {
  if (value.isEmpty) return 'not recorded';
  return value.length <= 8 ? value : '${value.substring(0, 8)}…';
}

String _dateTime(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value.isEmpty ? 'Not recorded' : value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final hour = parsed.hour == 0
      ? 12
      : parsed.hour > 12
      ? parsed.hour - 12
      : parsed.hour;
  final minute = parsed.minute.toString().padLeft(2, '0');
  final period = parsed.hour >= 12 ? 'PM' : 'AM';
  return '${months[parsed.month - 1]} ${parsed.day}, ${parsed.year} • $hour:$minute $period';
}
