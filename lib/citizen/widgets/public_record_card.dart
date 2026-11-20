import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../models/citizen_models.dart';

class PublicRecordCard extends ConsumerWidget {
  const PublicRecordCard({
    super.key,
    required this.record,
    this.module,
    this.onTap,
    this.trailing,
  });
  final PublicRecord record;
  final String? module;
  final VoidCallback? onTap;
  final Widget? trailing;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    final labels = module == null
        ? const <String>[]
        : record.labelsFor(module!);
    final showImage =
        module != 'emergency-contacts' && record.imageUrl?.isNotEmpty == true;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    record.imageUrl!,
                    width: 92,
                    height: 92,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              if (showImage) const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        if (record.usedFallback)
                          Tooltip(
                            message: strings.text('englishFallback'),
                            child: Icon(Icons.translate, size: 18),
                          ),
                      ],
                    ),
                    if (labels.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: labels
                            .take(3)
                            .map(
                              (label) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  label,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    if (record.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        record.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                trailing!
              else if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(left: 6, top: 30),
                  child: Icon(Icons.chevron_right_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
