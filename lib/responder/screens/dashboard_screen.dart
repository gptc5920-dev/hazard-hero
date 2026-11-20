import 'package:auto_size_text/auto_size_text.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/responder_providers.dart';
import '../models/responder_models.dart';
import '../widgets/backend_connection_chip.dart';

class ResponderDashboardScreen extends ConsumerWidget {
  const ResponderDashboardScreen({super.key});

  static const _metrics = [
    _DashboardMetric(
      'Alerts',
      'alerts',
      '/alerts',
      Icons.warning_amber_rounded,
      Color(0xffdc2626),
    ),
    _DashboardMetric(
      'Guidelines',
      'guidelines',
      '/guidelines',
      Icons.menu_book_rounded,
      Color(0xff2563eb),
    ),
    _DashboardMetric(
      'Evacuation centers',
      'evacuation-centers',
      '/evacuation-centers',
      Icons.location_on_rounded,
      Color(0xff059669),
    ),
    _DashboardMetric(
      'Emergency contacts',
      'emergency-contacts',
      '/emergency-contacts',
      Icons.call_rounded,
      Color(0xff0891b2),
    ),
    _DashboardMetric(
      'Go Bag items',
      'go-bag',
      '/go-bag',
      Icons.backpack_rounded,
      Color(0xffea580c),
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = {
      for (final metric in _metrics)
        metric.path: ref.watch(managedRecordsProvider(metric.path)),
    };
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    Future<void> refresh() async {
      ref.invalidate(backendHealthProvider);
      for (final metric in _metrics) {
        ref.invalidate(managedRecordsProvider(metric.path));
      }
      await Future.wait(
        _metrics.map(
          (metric) => ref.read(managedRecordsProvider(metric.path).future),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1080;
            final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 24.0;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                8,
                horizontalPadding,
                40,
              ),
              children: [
                _DashboardHeader(onRefresh: refresh),
                const SizedBox(height: 20),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _metrics.length,
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280,
                    mainAxisExtent: 154,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                  ),
                  itemBuilder: (context, index) {
                    final metric = _metrics[index];
                    final card = _MetricCard(
                      metric: metric,
                      snapshot: snapshots[metric.path]!,
                      onTap: () => context.go(metric.route),
                    );
                    if (disableAnimations) return card;
                    return card
                        .animate(delay: Duration(milliseconds: index * 55))
                        .fadeIn(duration: 280.ms)
                        .slideY(begin: .05, end: 0);
                  },
                ),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: _ResourceComposition(
                          metrics: _metrics,
                          snapshots: snapshots,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: _RecentAlerts(
                          alerts: snapshots['alerts']!,
                          onViewAll: () => context.go('/alerts'),
                        ),
                      ),
                    ],
                  )
                else ...[
                  _ResourceComposition(metrics: _metrics, snapshots: snapshots),
                  const SizedBox(height: 16),
                  _RecentAlerts(
                    alerts: snapshots['alerts']!,
                    onViewAll: () => context.go('/alerts'),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.onRefresh});
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) => Card(
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xfffff7f8), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final title = Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xffdd2d4a),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33dd2d4a),
                      blurRadius: 18,
                      offset: Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.health_and_safety_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Emergency operations overview',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -.4,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Monitor public safety content and operational resources.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xff76515b),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          final controls = Wrap(
            spacing: 9,
            runSpacing: 9,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const BackendConnectionChip(),
              FilledButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.sync_rounded, size: 19),
                label: const Text('Sync snapshot'),
              ),
            ],
          );
          return compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [title, const SizedBox(height: 16), controls],
                )
              : Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 20),
                    controls,
                  ],
                );
        },
      ),
    ),
  );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.metric,
    required this.snapshot,
    required this.onTap,
  });
  final _DashboardMetric metric;
  final AsyncValue<List<ManagedRecord>> snapshot;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: '${metric.label}. Open records.',
    child: Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: snapshot.when(
            data: (rows) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: metric.color.withAlpha(24),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(metric.icon, color: metric.color),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 19,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${rows.length}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                AutoSizeText(
                  metric.label,
                  maxLines: 1,
                  minFontSize: 12,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Loaded records',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.cloud_off_rounded, color: metric.color),
                const Spacer(),
                const Text(
                  'Unavailable',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text('Tap to open this module.'),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ResourceComposition extends StatelessWidget {
  const _ResourceComposition({required this.metrics, required this.snapshots});
  final List<_DashboardMetric> metrics;
  final Map<String, AsyncValue<List<ManagedRecord>>> snapshots;

  @override
  Widget build(BuildContext context) {
    final values = [
      for (final metric in metrics)
        snapshots[metric.path]!.asData?.value.length ?? 0,
    ];
    final total = values.fold<int>(0, (sum, value) => sum + value);
    final ready = snapshots.values.every((value) => value.hasValue);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Published resource mix',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'A composition of the records currently available.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (!ready)
              const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (total == 0)
              const SizedBox(
                height: 220,
                child: Center(child: Text('No resource records to chart yet.')),
              )
            else
              Semantics(
                label: [
                  for (var i = 0; i < metrics.length; i++)
                    '${metrics[i].label}: ${values[i]}',
                ].join(', '),
                child: SizedBox(
                  height: 220,
                  child: Row(
                    children: [
                      Expanded(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            PieChart(
                              PieChartData(
                                centerSpaceRadius: 52,
                                sectionsSpace: 3,
                                startDegreeOffset: -90,
                                pieTouchData: PieTouchData(enabled: false),
                                sections: [
                                  for (var i = 0; i < metrics.length; i++)
                                    PieChartSectionData(
                                      value: values[i].toDouble(),
                                      color: metrics[i].color,
                                      radius: 31,
                                      showTitle: false,
                                    ),
                                ],
                              ),
                            ),
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$total',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const Text('records'),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < metrics.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: metrics[i].color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        metrics[i].shortLabel,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Text(
                                      '${values[i]}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
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
}

class _RecentAlerts extends StatelessWidget {
  const _RecentAlerts({required this.alerts, required this.onViewAll});
  final AsyncValue<List<ManagedRecord>> alerts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Latest alert records',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              TextButton(onPressed: onViewAll, child: const Text('View all')),
            ],
          ),
          Text(
            'The latest warning records available to responders.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          alerts.when(
            loading: () => const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => const SizedBox(
              height: 200,
              child: Center(child: Text('Alerts could not be loaded.')),
            ),
            data: (rows) => rows.isEmpty
                ? const SizedBox(
                    height: 200,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.verified_user_outlined,
                            size: 40,
                            color: Color(0xff059669),
                          ),
                          SizedBox(height: 10),
                          Text('No alert records in this snapshot.'),
                        ],
                      ),
                    ),
                  )
                : Column(
                    children: [
                      for (final row in rows.take(4))
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xfffee2e2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: Color(0xffdc2626),
                            ),
                          ),
                          title: Text(
                            row.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            (row.data['severity_level'] ??
                                    row.data['status'] ??
                                    'Review details')
                                .toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    ),
  );
}

class _DashboardMetric {
  const _DashboardMetric(
    this.label,
    this.path,
    this.route,
    this.icon,
    this.color,
  );
  final String label;
  final String path;
  final String route;
  final IconData icon;
  final Color color;

  String get shortLabel => switch (path) {
    'evacuation-centers' => 'Centers',
    'emergency-contacts' => 'Contacts',
    'go-bag' => 'Go Bag',
    _ => label,
  };
}
