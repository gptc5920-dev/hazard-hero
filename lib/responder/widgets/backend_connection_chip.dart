import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/constants/api_config.dart';
import '../core/responder_providers.dart';

class BackendConnectionChip extends ConsumerWidget {
  const BackendConnectionChip({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final health = ref.watch(backendHealthProvider);
    final state = health.when(
      loading: () => const _ConnectionState(
        label: 'Checking API',
        icon: Icons.sync_rounded,
        background: Color(0xfffff7d6),
        foreground: Color(0xff92400e),
      ),
      error: (_, _) => const _ConnectionState(
        label: 'API unavailable',
        icon: Icons.cloud_off_outlined,
        background: Color(0xfffee2e2),
        foreground: Color(0xff991b1b),
      ),
      data: (value) => value.connected
          ? const _ConnectionState(
              label: 'Backend connected',
              icon: Icons.cloud_done_rounded,
              background: Color(0xffdcfce7),
              foreground: Color(0xff166534),
            )
          : const _ConnectionState(
              label: 'Database unavailable',
              icon: Icons.cloud_off_outlined,
              background: Color(0xfffee2e2),
              foreground: Color(0xff991b1b),
            ),
    );

    return Tooltip(
      message: '${state.label}\n${ApiConfig.normalizedBaseUrl}',
      child: Material(
        color: state.background,
        borderRadius: BorderRadius.circular(99),
        child: InkWell(
          borderRadius: BorderRadius.circular(99),
          onTap: () => ref.invalidate(backendHealthProvider),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: 8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(state.icon, size: 16, color: state.foreground),
                if (!compact) ...[
                  const SizedBox(width: 6),
                  Text(
                    state.label,
                    style: TextStyle(
                      color: state.foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConnectionState {
  const _ConnectionState({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}
