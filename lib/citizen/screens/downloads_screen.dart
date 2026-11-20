import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../models/citizen_models.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    final state = ref.watch(downloadsProvider);
    return Scaffold(
      body: state.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppError(
          message: error.toString(),
          onRetry: () => ref.invalidate(downloadsProvider),
        ),
        data: (items) => items.isEmpty
            ? AppEmpty(
                message: strings.text('offlineEmpty'),
                icon: Icons.download_done,
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer.withAlpha(70),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.offline_bolt_rounded,
                                    size: 34,
                                  ),
                                  const SizedBox(width: 13),
                                  Expanded(
                                    child: Text(
                                      strings.text('offlineDescription'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...items.map(
                            (item) => Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                minTileHeight: 76,
                                leading: const CircleAvatar(
                                  child: Icon(Icons.offline_pin_rounded),
                                ),
                                title: Text(
                                  item.manifest['title']?.toString() ??
                                      strings.text('guideline'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  '${item.language.toUpperCase()} · ${strings.text('saved')} ${_date(item.savedAt)}',
                                ),
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        _OfflineGuidelineScreen(item: item),
                                  ),
                                ),
                                trailing: IconButton(
                                  tooltip: strings.text('removeDownload'),
                                  onPressed: () => _confirmDelete(
                                    context,
                                    ref,
                                    item,
                                    strings,
                                  ),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    OfflinePackage item,
    CitizenStrings strings,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.text('removeOfflineTitle')),
        content: Text(
          '${item.manifest['title'] ?? strings.text('guideline')} ${strings.text('removeOfflineMessage')}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('keep')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('remove')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(downloadsProvider.notifier).delete(item.id, item.language);
    }
  }
}

class _OfflineGuidelineScreen extends StatelessWidget {
  const _OfflineGuidelineScreen({required this.item});
  final OfflinePackage item;

  @override
  Widget build(BuildContext context) {
    final strings = CitizenStrings(item.language);
    final manifest = item.manifest;
    final media = manifest['media'] as List? ?? const [];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(
                            Icons.offline_pin_rounded,
                            size: 18,
                          ),
                          label: Text(
                            '${item.language.toUpperCase()} · ${strings.text('offline')}',
                          ),
                        ),
                        if (manifest['used_fallback'] == true)
                          Chip(
                            label: Text(strings.text('englishFallbackShort')),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      manifest['title']?.toString() ??
                          strings.text('guideline'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    _OfflineText(
                      title: strings.text('atGlance'),
                      text: manifest['summary']?.toString() ?? '',
                    ),
                    _OfflineText(
                      title: strings.text('completeGuidance'),
                      text: manifest['content']?.toString() ?? '',
                    ),
                    _OfflineText(
                      title: strings.text('safetyInstructions'),
                      text: manifest['safety_instructions']?.toString() ?? '',
                      emphasized: true,
                    ),
                    if (media.isNotEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                strings.text('savedMedia'),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 8),
                              ...media.map((raw) {
                                final mediaItem = raw as Map;
                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    mediaItem['type'] == 'video'
                                        ? Icons.play_circle_outline
                                        : Icons.image_outlined,
                                  ),
                                  title: Text(
                                    mediaItem['type'] == 'video'
                                        ? strings.text('savedVideo')
                                        : strings.text('savedImage'),
                                  ),
                                  subtitle:
                                      (mediaItem['caption_text']?.toString() ??
                                              '')
                                          .isEmpty
                                      ? null
                                      : Text(
                                          mediaItem['caption_text'].toString(),
                                        ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(
                      '${strings.text('saved')} ${_date(item.savedAt)} · ${strings.text('guidelineVersion')} ${manifest['guideline_version'] ?? 1}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineText extends StatelessWidget {
  const _OfflineText({
    required this.title,
    required this.text,
    this.emphasized = false,
  });
  final String title;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    return Card(
      color: emphasized
          ? Theme.of(context).colorScheme.tertiaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            SelectableText(text, style: const TextStyle(height: 1.55)),
          ],
        ),
      ),
    );
  }
}

String _date(DateTime value) {
  final local = value.toLocal();
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
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}
