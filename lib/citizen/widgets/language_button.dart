import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';

class CitizenLanguageButton extends ConsumerWidget {
  const CitizenLanguageButton({super.key, this.iconOnly = false});

  final bool iconOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final language = ref.watch(languageProvider);
    final strings = CitizenStrings(language);
    if (iconOnly) {
      return Material(
        color: const Color(0xfffce8ec),
        elevation: 4,
        shadowColor: const Color(0x33a91f38),
        shape: const CircleBorder(),
        child: IconButton(
          key: const Key('language-selector'),
          tooltip:
              '${strings.text('chooseLanguage')} (${language.toUpperCase()})',
          onPressed: () => _showLanguages(context),
          color: const Color(0xffdd2d4a),
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.translate_rounded, size: 20),
        ),
      );
    }
    return TextButton.icon(
      onPressed: () => _showLanguages(context),
      style: TextButton.styleFrom(
        minimumSize: const Size(0, 30),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      icon: const Icon(Icons.translate_rounded, size: 16),
      label: Text(
        language.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }

  void _showLanguages(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final strings = CitizenStrings(ref.watch(languageProvider));
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.text('chooseLanguage'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ref
                      .watch(languagesProvider)
                      .when(
                        loading: () =>
                            const SizedBox(height: 160, child: AppLoading()),
                        error: (_, __) => const Column(
                          children: [
                            _FallbackLanguageTile(
                              code: 'en',
                              name: 'English',
                              nativeName: 'English',
                            ),
                            _FallbackLanguageTile(
                              code: 'fil',
                              name: 'Filipino',
                              nativeName: 'Filipino',
                            ),
                            _FallbackLanguageTile(
                              code: 'ceb',
                              name: 'Bisaya',
                              nativeName: 'Bisaya',
                            ),
                          ],
                        ),
                        data: (items) => Column(
                          children: items
                              .map(
                                (item) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    ref.watch(languageProvider) == item.code
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_off,
                                  ),
                                  title: Text(item.name),
                                  subtitle: item.nativeName == item.name
                                      ? null
                                      : Text(item.nativeName),
                                  onTap: () {
                                    ref
                                        .read(languageProvider.notifier)
                                        .select(item.code);
                                    Navigator.pop(context);
                                  },
                                ),
                              )
                              .toList(),
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
}

class _FallbackLanguageTile extends ConsumerWidget {
  const _FallbackLanguageTile({
    required this.code,
    required this.name,
    required this.nativeName,
  });

  final String code;
  final String name;
  final String nativeName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(languageProvider) == code;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(name),
      subtitle: name == nativeName ? null : Text(nativeName),
      onTap: () {
        ref.read(languageProvider.notifier).select(code);
        Navigator.pop(context);
      },
    );
  }
}
