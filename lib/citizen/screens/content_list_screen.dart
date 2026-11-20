import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../models/citizen_models.dart';
import '../widgets/public_record_card.dart';

class ContentListScreen extends ConsumerStatefulWidget {
  const ContentListScreen({
    super.key,
    required this.module,
    required this.title,
    required this.icon,
  });

  final String module;
  final String title;
  final IconData icon;

  @override
  ConsumerState<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends ConsumerState<ContentListScreen> {
  static const _goBagChecklistKey = 'citizen_go_bag_checked_items';

  final _searchController = TextEditingController();
  late Set<String> _checkedGoBagItems;
  String query = '';

  @override
  void initState() {
    super.initState();
    _checkedGoBagItems = {
      ...?ref.read(preferencesProvider).getStringList(_goBagChecklistKey),
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(publicRecordsProvider(widget.module));
    final strings = CitizenStrings(ref.watch(languageProvider));
    final title = strings.moduleTitle(widget.module);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.refresh(publicRecordsProvider(widget.module).future),
        child: state.when(
          loading: () => const AppLoading(),
          error: (error, _) => AppError(
            message: error.toString(),
            onRetry: () => ref.invalidate(publicRecordsProvider(widget.module)),
          ),
          data: (items) => _buildList(context, items, strings, title),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<PublicRecord> items,
    CitizenStrings strings,
    String title,
  ) {
    final normalized = query.trim().toLowerCase();
    final filtered = normalized.isEmpty
        ? items
        : items
              .where((record) => record.searchableText().contains(normalized))
              .toList();
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ListIntro(
                  icon: widget.icon,
                  title: title,
                  count: items.length,
                  strings: strings,
                ),
                if (widget.module == 'go-bag') ...[
                  const SizedBox(height: 12),
                  _GoBagProgress(
                    completed: items
                        .where(
                          (item) =>
                              _checkedGoBagItems.contains(_checklistId(item)),
                        )
                        .length,
                    total: items.length,
                    strings: strings,
                    onClear: _checkedGoBagItems.isEmpty
                        ? null
                        : _clearGoBagChecklist,
                  ),
                ],
                const SizedBox(height: 14),
                SearchBar(
                  controller: _searchController,
                  leading: const Icon(Icons.search_rounded),
                  hintText: '${strings.text('search')} ${title.toLowerCase()}',
                  trailing: [
                    if (query.isNotEmpty)
                      IconButton(
                        tooltip: strings.text('clearSearch'),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => query = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                  ],
                  onChanged: (value) => setState(() => query = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        normalized.isEmpty
                            ? '${items.length} ${strings.text(items.length == 1 ? 'publishedItem' : 'publishedItems')}'
                            : '${filtered.length} ${strings.text(filtered.length == 1 ? 'result' : 'results')}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Icon(Icons.swipe_down_alt_rounded, size: 18),
                    const SizedBox(width: 5),
                    Text(
                      strings.text('pullToRefresh'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  SizedBox(
                    height: 320,
                    child: AppEmpty(
                      message: strings.text('noPublished'),
                      icon: widget.icon,
                    ),
                  )
                else if (filtered.isEmpty)
                  SizedBox(
                    height: 280,
                    child: AppEmpty(
                      message: strings.text('noSearchResults'),
                      icon: Icons.search_off_rounded,
                    ),
                  )
                else
                  ...filtered.map(
                    (item) => widget.module == 'go-bag'
                        ? _goBagChecklistCard(context, item, strings)
                        : _recordCard(context, item, strings),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _goBagChecklistCard(
    BuildContext context,
    PublicRecord item,
    CitizenStrings strings,
  ) {
    final itemId = _checklistId(item);
    final checked = _checkedGoBagItems.contains(itemId);
    final quantity = [
      item.data['quantity']?.toString(),
      item.data['unit']?.toString(),
    ].where((value) => value != null && value.trim().isNotEmpty).join(' ');

    return Card(
      key: ValueKey('go-bag-check-$itemId'),
      margin: const EdgeInsets.only(bottom: 10),
      color: checked ? const Color(0xfffce8ec) : Colors.white,
      child: CheckboxListTile(
        value: checked,
        onChanged: (value) => _setGoBagPrepared(itemId, value ?? false),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: const Color(0xffdd2d4a),
        checkboxShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
        contentPadding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        title: Text(
          item.title,
          style: TextStyle(
            color: checked ? const Color(0xff76515b) : const Color(0xff35141d),
            fontWeight: FontWeight.w800,
            decoration: checked ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (quantity.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                quantity,
                style: const TextStyle(
                  color: Color(0xffdd2d4a),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
            if (item.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        secondary: IconButton(
          tooltip: strings.text('viewItemDetails'),
          onPressed: () => context.push('/go-bag/${item.id}'),
          icon: const Icon(Icons.info_outline_rounded),
        ),
      ),
    );
  }

  String _checklistId(PublicRecord item) =>
      item.id.isNotEmpty ? item.id : item.title;

  Future<void> _setGoBagPrepared(String itemId, bool prepared) async {
    setState(() {
      if (prepared) {
        _checkedGoBagItems.add(itemId);
      } else {
        _checkedGoBagItems.remove(itemId);
      }
    });
    final saved = _checkedGoBagItems.toList()..sort();
    await ref
        .read(preferencesProvider)
        .setStringList(_goBagChecklistKey, saved);
  }

  Future<void> _clearGoBagChecklist() async {
    setState(_checkedGoBagItems.clear);
    await ref.read(preferencesProvider).remove(_goBagChecklistKey);
  }

  Widget _recordCard(
    BuildContext context,
    PublicRecord item,
    CitizenStrings strings,
  ) {
    final path = widget.module == 'guidelines'
        ? '/guidelines/${item.data['slug']}'
        : '/${widget.module}/${item.id}';
    return PublicRecordCard(
      record: item,
      module: widget.module,
      onTap: () => context.push(path),
      trailing: widget.module == 'emergency-contacts'
          ? IconButton.filledTonal(
              tooltip: '${strings.text('call')} ${item.title}',
              onPressed: () {
                final raw =
                    (item.data['hotline_uri'] ?? item.data['primary_phone_uri'])
                        ?.toString();
                if (raw != null && raw.isNotEmpty) {
                  launchUrl(
                    Uri.parse(raw),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
              icon: const Icon(Icons.call_rounded),
            )
          : null,
    );
  }
}

class _GoBagProgress extends StatelessWidget {
  const _GoBagProgress({
    required this.completed,
    required this.total,
    required this.strings,
    required this.onClear,
  });

  final int completed;
  final int total;
  final CitizenStrings strings;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;
    final complete = total > 0 && completed == total;

    return Card(
      color: const Color(0xffdd2d4a),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.checklist_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        complete
                            ? strings.text('goBagReady')
                            : strings.text('goBagChecklist'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$completed / $total ${strings.text('itemsPrepared')}',
                        style: const TextStyle(
                          color: Color(0xffffe8ed),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onClear != null)
                  TextButton(
                    onPressed: onClear,
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: Text(strings.text('clearChecklist')),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              borderRadius: BorderRadius.circular(99),
              backgroundColor: Colors.white.withValues(alpha: .25),
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
            const SizedBox(height: 10),
            Text(
              strings.text('checkItemsInstruction'),
              style: const TextStyle(color: Color(0xffffe8ed), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListIntro extends StatelessWidget {
  const _ListIntro({
    required this.icon,
    required this.title,
    required this.count,
    required this.strings,
  });

  final IconData icon;
  final String title;
  final int count;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => Card(
    color: Theme.of(context).colorScheme.primaryContainer.withAlpha(75),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
            child: Icon(icon),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  count == 0
                      ? strings.text('officialUpdatesEmpty')
                      : strings.text('officialUpdatesReady'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
