import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/async_state_widgets.dart';
import '../core/responder_providers.dart';
import '../models/responder_models.dart';
import '../validation/responder_validators.dart';

class _TranslationFieldSpec {
  const _TranslationFieldSpec(
    this.name,
    this.label, {
    this.required = true,
    this.maxLength,
    this.lines = 4,
  });

  final String name;
  final String label;
  final bool required;
  final int? maxLength;
  final int lines;
}

class _TranslationModuleSpec {
  const _TranslationModuleSpec({
    required this.recordsModule,
    required this.translationsModule,
    required this.parentField,
    required this.label,
    required this.fields,
  });

  final String recordsModule;
  final String translationsModule;
  final String parentField;
  final String label;
  final List<_TranslationFieldSpec> fields;
}

const _translationModules = <_TranslationModuleSpec>[
  _TranslationModuleSpec(
    recordsModule: 'go-bag',
    translationsModule: 'go-bag-translations',
    parentField: 'item',
    label: 'Go Bag items',
    fields: [
      _TranslationFieldSpec(
        'translated_name',
        'Translated name',
        maxLength: 180,
      ),
      _TranslationFieldSpec(
        'translated_description',
        'Translated description',
        lines: 6,
      ),
    ],
  ),
  _TranslationModuleSpec(
    recordsModule: 'calamities',
    translationsModule: 'calamity-translations',
    parentField: 'calamity',
    label: 'Calamities',
    fields: [
      _TranslationFieldSpec(
        'translated_name',
        'Translated name',
        maxLength: 100,
      ),
      _TranslationFieldSpec(
        'translated_description',
        'Translated description',
        lines: 6,
      ),
    ],
  ),
  _TranslationModuleSpec(
    recordsModule: 'guidelines',
    translationsModule: 'guideline-translations',
    parentField: 'guideline',
    label: 'Guidelines',
    fields: [
      _TranslationFieldSpec(
        'translated_title',
        'Translated title',
        maxLength: 255,
      ),
      _TranslationFieldSpec('translated_summary', 'Translated summary'),
      _TranslationFieldSpec(
        'translated_content',
        'Translated content',
        lines: 10,
      ),
      _TranslationFieldSpec(
        'translated_safety_instructions',
        'Translated safety instructions',
        required: false,
        lines: 6,
      ),
    ],
  ),
  _TranslationModuleSpec(
    recordsModule: 'evacuation-centers',
    translationsModule: 'evacuation-center-translations',
    parentField: 'center',
    label: 'Evacuation centers',
    fields: [
      _TranslationFieldSpec(
        'translated_description',
        'Translated description',
        lines: 6,
      ),
      _TranslationFieldSpec(
        'translated_facility_description',
        'Translated facility description',
        required: false,
        lines: 6,
      ),
    ],
  ),
  _TranslationModuleSpec(
    recordsModule: 'emergency-contacts',
    translationsModule: 'emergency-contact-translations',
    parentField: 'contact',
    label: 'Emergency contacts',
    fields: [
      _TranslationFieldSpec(
        'translated_description',
        'Translated description',
        lines: 6,
      ),
    ],
  ),
  _TranslationModuleSpec(
    recordsModule: 'alerts',
    translationsModule: 'alert-translations',
    parentField: 'alert',
    label: 'Alerts',
    fields: [
      _TranslationFieldSpec(
        'translated_title',
        'Translated title',
        maxLength: 255,
      ),
      _TranslationFieldSpec(
        'translated_message',
        'Translated message',
        lines: 6,
      ),
      _TranslationFieldSpec(
        'translated_instructions',
        'Translated instructions',
        required: false,
        lines: 6,
      ),
      _TranslationFieldSpec(
        'translated_affected_area_description',
        'Translated affected-area description',
        required: false,
        lines: 5,
      ),
    ],
  ),
];

class TranslationsScreen extends ConsumerStatefulWidget {
  const TranslationsScreen({super.key});

  @override
  ConsumerState<TranslationsScreen> createState() => _TranslationsScreenState();
}

class _TranslationsScreenState extends ConsumerState<TranslationsScreen>
    with SingleTickerProviderStateMixin {
  static const _codes = ['en', 'fil', 'ceb'];
  static const _labels = ['English', 'Filipino', 'Bisaya'];

  _TranslationModuleSpec _module = _translationModules[2];
  String? _recordId;
  late final TabController _tabs = TabController(length: 3, vsync: this);
  late Future<List<ManagedRecord>> _records = _loadRecords();

  Future<List<ManagedRecord>> _loadRecords() =>
      ref.read(responderRepositoryProvider).records(_module.recordsModule);

  void _refresh() => setState(() => _records = _loadRecords());

  void _selectModule(_TranslationModuleSpec value) {
    setState(() {
      _module = value;
      _recordId = null;
      _records = _loadRecords();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 900;
        final horizontal = desktop ? 24.0 : 14.0;
        return FutureBuilder<List<ManagedRecord>>(
          future: _records,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoading();
            }
            if (snapshot.hasError) {
              return AppError(
                message: snapshot.error.toString(),
                onRetry: _refresh,
              );
            }
            final records = snapshot.data ?? const <ManagedRecord>[];
            final selectedId = records.any((item) => item.id == _recordId)
                ? _recordId
                : records.firstOrNull?.id;
            _recordId = selectedId;
            final selected = selectedId == null
                ? null
                : records.firstWhere((item) => item.id == selectedId);

            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 14),
                  child: _PageHeader(onRefresh: _refresh),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
                  child: _RecordSelector(
                    module: _module,
                    records: records,
                    selectedId: selectedId,
                    onModuleChanged: _selectModule,
                    onRecordChanged: (value) =>
                        setState(() => _recordId = value),
                  ),
                ),
                if (selected == null)
                  Expanded(
                    child: AppEmpty(
                      message:
                          'Create a ${_module.label.toLowerCase()} record before preparing its translations.',
                    ),
                  )
                else ...[
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: horizontal),
                    child: Card(
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: !desktop,
                        tabAlignment: !desktop ? TabAlignment.start : null,
                        dividerColor: Colors.transparent,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: const Color(0xffdd2d4a),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: const Color(0xff76515b),
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                        padding: const EdgeInsets.all(5),
                        tabs: [
                          for (final label in _labels)
                            Tab(
                              height: 44,
                              icon: const Icon(
                                Icons.language_rounded,
                                size: 18,
                              ),
                              text: label,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      controller: _tabs,
                      children: [
                        for (var i = 0; i < _codes.length; i++)
                          _TranslationEditor(
                            key: ValueKey(
                              '${_module.translationsModule}-${selected.id}-${_codes[i]}',
                            ),
                            module: _module,
                            record: selected,
                            code: _codes[i],
                            languageLabel: _labels[i],
                            horizontalPadding: horizontal,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        );
      },
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.onRefresh});
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
        child: const Icon(Icons.translate_rounded, color: Color(0xffdd2d4a)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Content translations',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
            ),
            const Text(
              'Prepare English, Filipino, and Bisaya citizen content.',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Color(0xff76515b), fontSize: 12),
            ),
          ],
        ),
      ),
      IconButton.filledTonal(
        tooltip: 'Refresh records',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
      ),
    ],
  );
}

class _RecordSelector extends StatelessWidget {
  const _RecordSelector({
    required this.module,
    required this.records,
    required this.selectedId,
    required this.onModuleChanged,
    required this.onRecordChanged,
  });

  final _TranslationModuleSpec module;
  final List<ManagedRecord> records;
  final String? selectedId;
  final ValueChanged<_TranslationModuleSpec> onModuleChanged;
  final ValueChanged<String?> onRecordChanged;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final modulePicker = DropdownButtonFormField<_TranslationModuleSpec>(
            initialValue: module,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Content type',
              prefixIcon: Icon(Icons.category_outlined),
            ),
            items: [
              for (final item in _translationModules)
                DropdownMenuItem(value: item, child: Text(item.label)),
            ],
            onChanged: (value) {
              if (value != null) onModuleChanged(value);
            },
          );
          final recordPicker = DropdownButtonFormField<String>(
            key: ValueKey('${module.recordsModule}-$selectedId'),
            initialValue: selectedId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: records.isEmpty
                  ? 'No records available'
                  : 'Record to translate',
              prefixIcon: const Icon(Icons.article_outlined),
            ),
            items: [
              for (final record in records)
                DropdownMenuItem(
                  value: record.id,
                  child: Text(record.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: records.isEmpty ? null : onRecordChanged,
          );
          if (constraints.maxWidth >= 720) {
            return Row(
              children: [
                Expanded(child: modulePicker),
                const SizedBox(width: 14),
                Expanded(flex: 2, child: recordPicker),
              ],
            );
          }
          return Column(
            children: [modulePicker, const SizedBox(height: 12), recordPicker],
          );
        },
      ),
    ),
  );
}

class _TranslationEditor extends ConsumerStatefulWidget {
  const _TranslationEditor({
    super.key,
    required this.module,
    required this.record,
    required this.code,
    required this.languageLabel,
    required this.horizontalPadding,
  });

  final _TranslationModuleSpec module;
  final ManagedRecord record;
  final String code;
  final String languageLabel;
  final double horizontalPadding;

  @override
  ConsumerState<_TranslationEditor> createState() => _TranslationEditorState();
}

class _TranslationEditorState extends ConsumerState<_TranslationEditor> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers = {
    for (final field in widget.module.fields)
      field.name: TextEditingController(),
  };
  String? _id;
  String? _status;
  String? _error;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await ref
          .read(responderApiProvider)
          .list(
            widget.module.translationsModule,
            query: {
              widget.module.parentField: widget.record.id,
              'language__language_code': widget.code,
            },
          );
      if (!mounted) return;
      final data = rows.firstOrNull;
      setState(() {
        _id = data?['id']?.toString();
        _status = data?['status']?.toString();
        _error = null;
        for (final field in widget.module.fields) {
          _controllers[field.name]!.text = data?[field.name]?.toString() ?? '';
        }
        _loading = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
        _saving = false;
      });
    }
  }

  Future<bool> _save({
    bool showConfirmation = true,
    String? targetStatus,
  }) async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return false;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final body = <String, dynamic>{
        widget.module.parentField: widget.record.id,
        'language': widget.code,
        if (targetStatus != null) 'status': targetStatus,
        for (final field in widget.module.fields)
          field.name: _controllers[field.name]!.text.trim(),
      };
      final api = ref.read(responderApiProvider);
      final data = _id == null
          ? await api.create(widget.module.translationsModule, body)
          : await api.update(widget.module.translationsModule, _id!, body);
      if (!mounted) return true;
      setState(() {
        _id = data['id'].toString();
        _status = data['status']?.toString() ?? _status ?? 'Draft';
      });
      if (showConfirmation) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              targetStatus == 'Draft'
                  ? '${widget.languageLabel} translation saved as a draft.'
                  : '${widget.languageLabel} translation saved.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
      return false;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _transition(String action, String label) async {
    if (!await _save(showConfirmation: false) || _id == null) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(responderApiProvider)
          .action(widget.module.translationsModule, _id!, action);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.languageLabel} translation $label.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  Future<void> _copyEnglish() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(responderApiProvider)
          .copyEnglishTranslation(
            translationModule: widget.module.translationsModule,
            parentField: widget.module.parentField,
            parentId: widget.record.id,
            language: widget.code,
          );
      await _load();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoading();
    return ListView(
      padding: EdgeInsets.fromLTRB(
        widget.horizontalPadding,
        0,
        widget.horizontalPadding,
        30,
      ),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1120),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.languageLabel,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(
                                width: 320,
                                child: Text(
                                  widget.record.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _StatusChip(label: _status ?? 'Not started'),
                              if (widget.code != 'en')
                                OutlinedButton.icon(
                                  onPressed: _saving ? null : _copyEnglish,
                                  icon: const Icon(
                                    Icons.content_copy_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Copy English'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          for (final field in widget.module.fields)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: TextFormField(
                                controller: _controllers[field.name],
                                enabled: !_saving,
                                minLines: field.lines == 1 ? 1 : 3,
                                maxLines: field.lines,
                                maxLength: field.maxLength,
                                decoration: InputDecoration(
                                  labelText:
                                      '${field.label}${field.required ? ' *' : ''}',
                                  alignLabelWithHint: field.lines > 1,
                                ),
                                validator: field.required
                                    ? (value) =>
                                          ResponderValidators.requiredText(
                                            value,
                                            label: field.label,
                                            maxLength: field.maxLength,
                                          )
                                    : (value) =>
                                          ResponderValidators.optionalText(
                                            value,
                                            label: field.label,
                                            maxLength: field.maxLength,
                                          ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (_saving)
                            const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            ),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _save(targetStatus: 'Draft'),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text('Save draft'),
                          ),
                          FilledButton.tonalIcon(
                            onPressed: _saving
                                ? null
                                : () => _transition(
                                    'needs-review',
                                    'sent for review',
                                  ),
                            icon: const Icon(
                              Icons.rate_review_outlined,
                              size: 18,
                            ),
                            label: const Text('Send for review'),
                          ),
                          if (_status != 'Archived')
                            OutlinedButton.icon(
                              onPressed: _saving
                                  ? null
                                  : () => _transition('archive', 'archived'),
                              icon: const Icon(
                                Icons.archive_outlined,
                                size: 18,
                              ),
                              label: const Text('Archive'),
                            ),
                          FilledButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _transition('publish', 'published'),
                            icon: const Icon(Icons.publish_rounded, size: 18),
                            label: const Text('Publish'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final published = label == 'Published';
    return Chip(
      avatar: Icon(
        published ? Icons.public_rounded : Icons.edit_note_rounded,
        size: 17,
      ),
      label: Text(label),
      backgroundColor: published
          ? const Color(0xffdcfce7)
          : const Color(0xfffff7d6),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xfffee2e2),
      borderRadius: BorderRadius.circular(13),
      border: Border.all(color: const Color(0xfffecaca)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xffb91c1c)),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(
              color: Color(0xff991b1b),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}
