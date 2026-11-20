import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/async_state_widgets.dart';
import '../core/responder_providers.dart';
import '../widgets/backend_connection_chip.dart';

class LanguagesScreen extends ConsumerStatefulWidget {
  const LanguagesScreen({super.key});

  @override
  ConsumerState<LanguagesScreen> createState() => _LanguagesScreenState();
}

class _LanguagesScreenState extends ConsumerState<LanguagesScreen> {
  late Future<List<Map<String, dynamic>>> _languages = _load();
  final Set<String> _saving = {};

  Future<List<Map<String, dynamic>>> _load() =>
      ref.read(responderApiProvider).list('languages');

  void _refresh() {
    ref.invalidate(backendHealthProvider);
    setState(() => _languages = _load());
  }

  Future<void> _setActive(Map<String, dynamic> language, bool active) async {
    final id = language['id'].toString();
    if (_saving.contains(id)) return;
    setState(() => _saving.add(id));
    try {
      await ref.read(responderApiProvider).update('languages', id, {
        'is_active': active,
      });
      if (!mounted) return;
      setState(() => _saving.remove(id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${language['name']} is now ${active ? 'available' : 'hidden'} in the citizen app.',
          ),
        ),
      );
      _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving.remove(id));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final horizontal = constraints.maxWidth < 600 ? 14.0 : 24.0;
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _languages,
          builder: (context, snapshot) {
            return ListView(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 36),
              children: [
                _Header(onRefresh: _refresh),
                const SizedBox(height: 14),
                const _ExplanationCard(),
                const SizedBox(height: 14),
                if (snapshot.connectionState != ConnectionState.done)
                  const SizedBox(height: 280, child: AppLoading())
                else if (snapshot.hasError)
                  SizedBox(
                    height: 280,
                    child: AppError(
                      message: snapshot.error.toString(),
                      onRetry: _refresh,
                    ),
                  )
                else if ((snapshot.data ?? const []).isEmpty)
                  const SizedBox(
                    height: 280,
                    child: AppEmpty(
                      message: 'No languages are configured in the backend.',
                    ),
                  )
                else
                  ...snapshot.data!.map(_languageCard),
              ],
            );
          },
        );
      },
    ),
  );

  Widget _languageCard(Map<String, dynamic> language) {
    final id = language['id'].toString();
    final active = language['is_active'] == true;
    final isDefault = language['is_default'] == true;
    final saving = _saving.contains(id);
    final code = language['language_code']?.toString().toUpperCase() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: active
                  ? const Color(0xffdcfce7)
                  : const Color(0xfff1f5f9),
              foregroundColor: active
                  ? const Color(0xff166534)
                  : const Color(0xff64748b),
              child: Text(
                code,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        language['name']?.toString() ?? code,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (isDefault)
                        const Chip(
                          label: Text('DEFAULT'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  Text(
                    language['native_name']?.toString() ?? '',
                    style: const TextStyle(color: Color(0xff76515b)),
                  ),
                ],
              ),
            ),
            if (saving)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
              )
            else
              Switch.adaptive(
                value: active,
                onChanged: isDefault
                    ? null
                    : (value) => _setActive(language, value),
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 560;
      final identity = Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xfffce8ec),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.language_rounded, color: Color(0xffdd2d4a)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Citizen languages',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const Text(
                  'Control which translations citizens can request.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Color(0xff76515b), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const BackendConnectionChip(compact: true),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: 'Refresh languages',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: actions),
              ],
            )
          : Row(
              children: [
                Expanded(child: identity),
                const SizedBox(width: 12),
                actions,
              ],
            );
    },
  );
}

class _ExplanationCard extends StatelessWidget {
  const _ExplanationCard();

  @override
  Widget build(BuildContext context) => const Card(
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: Color(0xffdd2d4a)),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'English is the required default language. Filipino and Bisaya can be disabled without deleting their prepared translations.',
            ),
          ),
        ],
      ),
    ),
  );
}
