import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../models/citizen_models.dart';
import '../widgets/language_button.dart';
import '../widgets/public_record_card.dart';

class CitizenHomeScreen extends ConsumerStatefulWidget {
  const CitizenHomeScreen({super.key});

  @override
  ConsumerState<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends ConsumerState<CitizenHomeScreen> {
  static const _viewedAlertsKey = 'citizen_viewed_alert_versions';

  late Set<String> _viewedAlerts;

  @override
  void initState() {
    super.initState();
    _viewedAlerts = {
      ...?ref.read(preferencesProvider).getStringList(_viewedAlertsKey),
    };
  }

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(publicRecordsProvider('alerts'));
    final guidelines = ref.watch(publicRecordsProvider('guidelines'));
    final strings = CitizenStrings(ref.watch(languageProvider));
    final alertItems = alerts.asData?.value ?? const <PublicRecord>[];
    final unreadCount = alertItems
        .where((item) => !_viewedAlerts.contains(_alertVersionKey(item)))
        .length;
    return Scaffold(
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              final online =
                  ref.read(connectivityProvider).asData?.value ?? false;
              if (online) {
                await ref
                    .read(citizenSyncProvider.notifier)
                    .sync(ref.read(languageProvider));
              } else {
                ref.invalidate(publicRecordsProvider('alerts'));
                ref.invalidate(publicRecordsProvider('guidelines'));
                await Future.wait([
                  ref.read(publicRecordsProvider('alerts').future),
                  ref.read(publicRecordsProvider('guidelines').future),
                ]);
              }
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
                  sliver: SliverToBoxAdapter(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1040),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _EmergencyHero(alerts: alerts, strings: strings),
                            const SizedBox(height: 22),
                            Text(
                              strings.text('findOfficialInformation'),
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              strings.text('officialInformationDescription'),
                            ),
                            const SizedBox(height: 14),
                            _QuickGrid(strings: strings),
                            const SizedBox(height: 26),
                            _SectionHeading(
                              title: strings.text('activeAlerts'),
                              actionLabel: strings.text('viewAll'),
                              onTap: () => context.go('/alerts'),
                            ),
                            const SizedBox(height: 8),
                            alerts.when(
                              data: (items) => items.isEmpty
                                  ? _EmptyPanel(
                                      icon: Icons.verified_user_outlined,
                                      text: strings.text('noActiveAlerts'),
                                    )
                                  : Column(
                                      children: items
                                          .take(3)
                                          .map(
                                            (item) => PublicRecordCard(
                                              record: item,
                                              module: 'alerts',
                                              onTap: () => context.push(
                                                '/alerts/${item.id}',
                                              ),
                                            ),
                                          )
                                          .toList(),
                                    ),
                              loading: () => const LinearProgressIndicator(),
                              error: (error, _) => _LoadError(
                                message: error.toString(),
                                retryLabel: strings.text('retry'),
                                onRetry: () => ref.invalidate(
                                  publicRecordsProvider('alerts'),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _SectionHeading(
                              title: strings.text('preparednessGuidelines'),
                              actionLabel: strings.text('browseAll'),
                              onTap: () => context.go('/guidelines'),
                            ),
                            const SizedBox(height: 8),
                            guidelines.when(
                              data: (items) {
                                final featured = items
                                    .where(
                                      (item) =>
                                          item.data['is_featured'] == true,
                                    )
                                    .toList();
                                final visible = featured.isEmpty
                                    ? items
                                    : featured;
                                return visible.isEmpty
                                    ? _EmptyPanel(
                                        icon: Icons.menu_book_outlined,
                                        text: strings.text('noGuidelines'),
                                      )
                                    : Column(
                                        children: visible
                                            .take(3)
                                            .map(
                                              (item) => PublicRecordCard(
                                                record: item,
                                                module: 'guidelines',
                                                onTap: () => context.push(
                                                  '/guidelines/${item.data['slug']}',
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (error, _) => _LoadError(
                                message: error.toString(),
                                retryLabel: strings.text('retry'),
                                onRetry: () => ref.invalidate(
                                  publicRecordsProvider('guidelines'),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CitizenLanguageButton(iconOnly: true),
                const SizedBox(width: 8),
                _NotificationBell(
                  count: unreadCount,
                  strings: strings,
                  onTap: () => _openNotifications(alertItems),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _alertVersionKey(PublicRecord item) {
    final identity = item.id.isNotEmpty ? item.id : item.title;
    return '$identity:${item.version}';
  }

  Future<void> _openNotifications(List<PublicRecord> items) async {
    final visibleVersions = items.map(_alertVersionKey).toSet();
    if (visibleVersions.isNotEmpty) {
      setState(() => _viewedAlerts.addAll(visibleVersions));
      final saved = _viewedAlerts.toList()..sort();
      await ref
          .read(preferencesProvider)
          .setStringList(_viewedAlertsKey, saved);
    }
    if (mounted) context.go('/alerts');
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.count,
    required this.strings,
    required this.onTap,
  });

  final int count;
  final CitizenStrings strings;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visibleCount = count > 99 ? '99+' : '$count';
    final label = count == 0
        ? strings.text('alertsAndNews')
        : '$count ${strings.text('activeAlerts')}';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: strings.text('alertsAndNews'),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: const Color(0xfffce8ec),
              elevation: 4,
              shadowColor: const Color(0x33a91f38),
              shape: const CircleBorder(),
              child: IconButton(
                key: const Key('home-notifications'),
                onPressed: onTap,
                color: const Color(0xffdd2d4a),
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  count > 0
                      ? Icons.notifications_rounded
                      : Icons.notifications_none_rounded,
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: -4,
                top: -5,
                child: Container(
                  key: const Key('home-notification-badge'),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xffdd2d4a),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    visibleCount,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmergencyHero extends StatelessWidget {
  final AsyncValue<List<PublicRecord>> alerts;
  final CitizenStrings strings;
  const _EmergencyHero({required this.alerts, required this.strings});

  @override
  Widget build(BuildContext context) {
    final alertCount = alerts.asData?.value.length;
    final hasAlerts = (alertCount ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xffa91f38), Color(0xffdd2d4a)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33a91f38),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: hasAlerts ? Colors.white : const Color(0xfffce8ec),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  hasAlerts
                      ? '$alertCount ${strings.text(alertCount == 1 ? 'activeAlert' : 'activeAlertsUpper')}'
                      : strings.text('noActiveAlertsUpper'),
                  style: const TextStyle(
                    color: Color(0xffa91f38),
                    fontWeight: FontWeight.w900,
                    letterSpacing: .5,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              AutoSizeText(
                hasAlerts
                    ? strings.text('stayReady')
                    : strings.text('preparedStarts'),
                maxLines: 2,
                minFontSize: 24,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                hasAlerts
                    ? strings.text('alertHeroDescription')
                    : strings.text('preparedHeroDescription'),
                style: const TextStyle(color: Color(0xffffe8ed), height: 1.45),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xffdd2d4a),
                ),
                onPressed: () => context.go(hasAlerts ? '/alerts' : '/go-bag'),
                icon: Icon(
                  hasAlerts
                      ? Icons.warning_amber_rounded
                      : Icons.backpack_outlined,
                ),
                label: Text(
                  hasAlerts
                      ? strings.text('reviewAlerts')
                      : strings.text('buildGoBag'),
                ),
              ),
            ],
          );
          final art = Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.health_and_safety_rounded,
              color: Colors.white,
              size: 64,
            ),
          );
          return compact
              ? copy
              : Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 28),
                    art,
                  ],
                );
        },
      ),
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyPanel({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    ),
  );
}

class _LoadError extends StatelessWidget {
  final String message;
  final String retryLabel;
  final VoidCallback onRetry;
  const _LoadError({
    required this.message,
    required this.retryLabel,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined),
          const SizedBox(width: 10),
          Expanded(child: Text(message)),
          TextButton(onPressed: onRetry, child: Text(retryLabel)),
        ],
      ),
    ),
  );
}

class _QuickGrid extends StatelessWidget {
  static const links = [
    ('alerts', Icons.warning_amber_rounded, '/alerts', Color(0xffdc2626)),
    ('guidelines', Icons.menu_book_rounded, '/guidelines', Color(0xff2563eb)),
    ('goBag', Icons.backpack_rounded, '/go-bag', Color(0xffea580c)),
    ('calamities', Icons.storm_rounded, '/calamities', Color(0xff7c3aed)),
    (
      'evacuation',
      Icons.location_on_rounded,
      '/evacuation-centers',
      Color(0xff059669),
    ),
    ('hotlines', Icons.call_rounded, '/emergency-contacts', Color(0xff0891b2)),
  ];
  final CitizenStrings strings;

  const _QuickGrid({required this.strings});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 900
          ? 6
          : constraints.maxWidth >= 560
          ? 3
          : 2;
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: columns >= 3 ? 1.15 : 1.35,
        children: links
            .map(
              (link) => Card(
                margin: EdgeInsets.zero,
                child: InkWell(
                  onTap: () => context.go(link.$3),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          backgroundColor: link.$4.withAlpha(24),
                          foregroundColor: link.$4,
                          child: Icon(link.$2),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.text(link.$1),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      );
    },
  );
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      TextButton(onPressed: onTap, child: Text(actionLabel)),
    ],
  );
}
