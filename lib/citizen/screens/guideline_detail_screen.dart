import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../widgets/embedded_media_player.dart';

class GuidelineDetailScreen extends ConsumerWidget {
  const GuidelineDetailScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    final state = ref.watch(publicRecordsProvider('guidelines'));
    return Scaffold(
      body: state.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppError(
          message: error.toString(),
          onRetry: () => ref.invalidate(publicRecordsProvider('guidelines')),
        ),
        data: (items) {
          final matches = items.where((item) => item.data['slug'] == slug);
          if (matches.isEmpty) {
            return AppEmpty(message: strings.text('notAvailable'));
          }
          final item = matches.first;
          final data = item.data;
          final media = data['media'] as List? ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
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
                      Card(
                        color: Theme.of(
                          context,
                        ).colorScheme.primaryContainer.withAlpha(85),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((item.imageUrl ?? '').isNotEmpty) ...[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: AspectRatio(
                                    aspectRatio: 16 / 8,
                                    child: Image.network(
                                      item.imageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const ColoredBox(
                                            color: Color(0xffe2e8f0),
                                          ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                              ],
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (_text(data['category']).isNotEmpty)
                                    Chip(label: Text(_text(data['category']))),
                                  if (_text(data['emergency_type']).isNotEmpty)
                                    Chip(
                                      avatar: const Icon(
                                        Icons.warning_amber_rounded,
                                        size: 17,
                                      ),
                                      label: Text(
                                        _text(data['emergency_type']),
                                      ),
                                    ),
                                  if (data['is_featured'] == true)
                                    Chip(label: Text(strings.text('featured'))),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                              ),
                              if (item.usedFallback) ...[
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.translate_rounded,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        strings.text('englishFallback'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _TextCard(
                        title: strings.text('atGlance'),
                        text: _text(data['summary']),
                      ),
                      _TextCard(
                        title: strings.text('completeGuidance'),
                        text: _text(data['content']),
                      ),
                      if (_text(data['safety_instructions']).isNotEmpty)
                        _TextCard(
                          title: strings.text('safetyInstructions'),
                          text: _text(data['safety_instructions']),
                          emphasized: true,
                        ),
                      if (media.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          strings.text('photosVideos'),
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        ...media.map((raw) {
                          final item = (raw as Map).cast<String, dynamic>();
                          return _MediaCard(data: item, strings: strings);
                        }),
                      ],
                      const SizedBox(height: 16),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.history_rounded, size: 19),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${strings.text('version')} ${item.version}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              if (_text(data['published_at']).isNotEmpty) ...[
                                const SizedBox(height: 5),
                                Text(
                                  '${strings.text('published')} ${_date(data['published_at'])}',
                                ),
                              ],
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                onPressed: () async {
                                  await ref
                                      .read(downloadsProvider.notifier)
                                      .download(
                                        slug,
                                        ref.read(languageProvider),
                                      );
                                  if (!context.mounted) return;
                                  final result = ref.read(downloadsProvider);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        result.hasError
                                            ? strings.text(
                                                'guidelineDownloadFailed',
                                              )
                                            : strings.text('savedOffline'),
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.download_rounded),
                                label: Text(strings.text('saveOffline')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TextCard extends StatelessWidget {
  const _TextCard({
    required this.title,
    required this.text,
    this.emphasized = false,
  });
  final String title;
  final String text;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();
    return Card(
      color: emphasized
          ? Theme.of(context).colorScheme.tertiaryContainer
          : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
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

class _MediaCard extends StatelessWidget {
  const _MediaCard({required this.data, required this.strings});
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) {
    final url = _text(data['media_url']);
    final subtitles = _text(data['subtitle_url']);
    final mediaType = _text(data['media_type']);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_text(data['title']).isNotEmpty)
              Text(
                _text(data['title']),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            if (_text(data['description']).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_text(data['description'])),
            ],
            if (url.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _mediaWidget(url, mediaType),
              ),
            ],
            if (_text(data['caption_text']).isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                _text(data['caption_text']),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (data['used_fallback'] == true) ...[
              const SizedBox(height: 8),
              Text(
                strings.text('englishMediaShown'),
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
            if (subtitles.isNotEmpty) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(subtitles),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.subtitles_outlined),
                label: Text(strings.text('openSubtitles')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _mediaWidget(String url, String mediaType) {
    if (mediaType == 'video') {
      return EmbeddedVideoPlayer(key: ValueKey(url), url: url);
    }
    final isSvg =
        mediaType == 'svg' ||
        (mediaType == 'icon' &&
            Uri.tryParse(url)?.path.toLowerCase().endsWith('.svg') == true);
    if (isSvg) {
      return SizedBox(
        height: mediaType == 'icon' ? 140 : 260,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SvgPicture.network(
            url,
            fit: BoxFit.contain,
            placeholderBuilder: (_) =>
                const Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }
    return AspectRatio(
      aspectRatio: mediaType == 'icon' ? 2 : 16 / 9,
      child: Image.network(
        url,
        fit: mediaType == 'icon' ? BoxFit.contain : BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            const Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

String _date(Object? value) {
  final parsed = DateTime.tryParse(_text(value));
  if (parsed == null) return _text(value);
  final local = parsed.toLocal();
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
