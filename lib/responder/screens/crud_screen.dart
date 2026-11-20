import 'dart:convert';
import 'package:data_table_2/data_table_2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/api/api_exception.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/responder_providers.dart';
import '../models/responder_models.dart';
import '../validation/responder_validators.dart';
import 'guideline_media_dialog.dart';

class CrudScreen extends ConsumerStatefulWidget {
  const CrudScreen({super.key, required this.module});
  final CrudModule module;

  @override
  ConsumerState<CrudScreen> createState() => _CrudState();
}

class _CrudState extends ConsumerState<CrudScreen> {
  String search = '';
  bool deleted = false;
  late Future<List<ManagedRecord>> _records;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _records = _load();
  }

  @override
  void didUpdateWidget(covariant CrudScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.module.path != widget.module.path) {
      search = '';
      deleted = false;
      _searchController.clear();
      _records = _load();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<List<ManagedRecord>> _load() => ref
      .read(responderRepositoryProvider)
      .records(
        widget.module.path,
        query: {
          if (deleted) 'deleted': 'true',
          if (search.isNotEmpty) 'search': search,
        },
      );

  void refresh() => setState(() => _records = _load());

  Future<void> _showErrorDialog(
    Object error, {
    String title = 'Unable to complete request',
    BuildContext? fromContext,
  }) async {
    final dialogContext = fromContext ?? context;
    if (!dialogContext.mounted) return;
    await showDialog<void>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.error_outline_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text(title),
        content: Text(userFacingErrorMessage(error)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 820;
        final horizontal = desktop ? 24.0 : 14.0;
        return Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 20, horizontal, 14),
              child: _ModuleHeader(
                label: widget.module.label,
                icon: widget.module.icon as IconData,
                onAdd: () => _form(),
                onRefresh: refresh,
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 14),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, filterConstraints) {
                      final searchField = SearchBar(
                        controller: _searchController,
                        hintText: 'Search ${widget.module.label.toLowerCase()}',
                        leading: const Icon(Icons.search_rounded),
                        trailing: [
                          if (search.isNotEmpty)
                            IconButton(
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchController.clear();
                                search = '';
                                refresh();
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          IconButton.filledTonal(
                            tooltip: 'Apply search',
                            onPressed: refresh,
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => search = value.trim()),
                        onSubmitted: (_) => refresh(),
                      );
                      final deletedFilter = FilterChip(
                        avatar: Icon(
                          deleted
                              ? Icons.delete_rounded
                              : Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        selected: deleted,
                        onSelected: (value) {
                          deleted = value;
                          refresh();
                        },
                        label: const Text('Deleted records'),
                      );
                      if (!widget.module.supportsSoftDelete) return searchField;
                      return filterConstraints.maxWidth >= 560
                          ? Row(
                              children: [
                                Expanded(child: searchField),
                                const SizedBox(width: 12),
                                deletedFilter,
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                searchField,
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: deletedFilter,
                                ),
                              ],
                            );
                    },
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<ManagedRecord>>(
                future: _records,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const AppLoading();
                  }
                  if (snapshot.hasError) {
                    return AppError(
                      message: snapshot.error.toString(),
                      onRetry: refresh,
                    );
                  }
                  final rows = snapshot.data!;
                  if (rows.isEmpty) {
                    return AppEmpty(
                      message:
                          'No ${widget.module.label.toLowerCase()} found for this view.',
                    );
                  }
                  return desktop
                      ? _desktopTable(rows, horizontal)
                      : _mobileCards(rows, horizontal);
                },
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _desktopTable(List<ManagedRecord> rows, double horizontal) => Padding(
    padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 24),
    child: Card(
      margin: EdgeInsets.zero,
      child: DataTable2(
        minWidth: 720,
        columnSpacing: 18,
        horizontalMargin: 20,
        headingRowHeight: 52,
        dataRowHeight: 62,
        fixedTopRows: 1,
        columns: const [
          DataColumn2(label: Text('RECORD'), size: ColumnSize.L),
          DataColumn2(label: Text('DETAILS'), size: ColumnSize.L),
          DataColumn2(label: Text('STATE'), size: ColumnSize.S),
          DataColumn2(
            label: Align(
              alignment: Alignment.centerRight,
              child: Text('ACTIONS'),
            ),
            fixedWidth: 88,
          ),
        ],
        rows: [
          for (final (index, record) in rows.indexed)
            DataRow2(
              color: WidgetStatePropertyAll(
                index.isEven ? Colors.white : const Color(0xfffffafb),
              ),
              onTap: () => _form(record),
              cells: [
                DataCell(
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          widget.module.icon as IconData,
                          size: 20,
                          color: Theme.of(
                            context,
                          ).colorScheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          record.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                DataCell(
                  Text(
                    _subtitle(record.data).isEmpty
                        ? 'No additional details'
                        : _subtitle(record.data),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(_StateChip(label: _stateLabel(record.data))),
                DataCell(
                  Align(
                    alignment: Alignment.centerRight,
                    child: _recordMenu(record),
                  ),
                ),
              ],
            ),
        ],
      ),
    ),
  );

  Widget _mobileCards(List<ManagedRecord> rows, double horizontal) =>
      ListView.separated(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 32),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final record = rows[index];
          return Card(
            margin: EdgeInsets.zero,
            child: InkWell(
              onTap: () => _form(record),
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.module.icon as IconData),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            record.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          if (_subtitle(record.data).isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              _subtitle(record.data),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 10),
                          _StateChip(label: _stateLabel(record.data)),
                        ],
                      ),
                    ),
                    _recordMenu(record),
                  ],
                ),
              ),
            ),
          );
        },
      );

  PopupMenuButton<String> _recordMenu(ManagedRecord record) =>
      PopupMenuButton<String>(
        tooltip: 'Record actions',
        onSelected: (value) => _action(value, record),
        itemBuilder: (_) => [
          if (!deleted)
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit_outlined),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!deleted && widget.module.path == 'guidelines')
            const PopupMenuItem(
              value: 'manage-media',
              child: ListTile(
                leading: Icon(Icons.perm_media_outlined),
                title: Text('Manage media'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!deleted && widget.module.canDelete)
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete_outline_rounded),
                title: Text(
                  widget.module.supportsSoftDelete
                      ? 'Move to deleted records'
                      : 'Delete permanently',
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (deleted && widget.module.supportsSoftDelete)
            PopupMenuItem(
              value: 'restore',
              child: ListTile(
                leading: Icon(Icons.restore_rounded),
                title: Text('Restore'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (deleted && widget.module.supportsSoftDelete)
            const PopupMenuItem(
              value: 'permanent-delete',
              child: ListTile(
                leading: Icon(Icons.delete_forever_rounded),
                title: Text('Delete permanently'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          if (!deleted)
            ..._availableActions(record).map(
              (action) => PopupMenuItem(
                value: action,
                child: ListTile(
                  leading: Icon(_actionIcon(action)),
                  title: Text(_actionLabel(action)),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
        ],
      );

  List<String> _availableActions(ManagedRecord record) {
    final data = record.data;
    return widget.module.actions.where((action) {
      if (action == 'verify') return data['is_verified'] != true;
      if (action == 'activate') return data['is_active'] == false;
      if (action == 'deactivate') return data['is_active'] != false;
      final status = data['status']?.toString();
      if (widget.module.path == 'guidelines') {
        if (action == 'publish') return status != 'Published';
        if (action == 'archive') return status != 'Archived';
      }
      if (widget.module.path == 'alerts') {
        return switch (action) {
          'publish' => status == 'Draft' || status == 'Scheduled',
          'resolve' => status == 'Active' || status == 'Scheduled',
          'cancel' => status == 'Active' || status == 'Scheduled',
          'archive' => status != 'Archived',
          _ => true,
        };
      }
      return true;
    }).toList();
  }

  String _subtitle(Map<String, dynamic> data) => [
    data['status'],
    data['category'],
    data['severity_level'],
    data['is_active'] == false ? 'Inactive' : null,
  ].whereType<Object>().join(' • ');

  String _stateLabel(Map<String, dynamic> data) {
    if (deleted) return 'Deleted';
    if (data['is_active'] == false) return 'Inactive';
    return (data['status'] ?? data['availability_status'] ?? 'Active')
        .toString();
  }

  Future<void> _action(String action, ManagedRecord record) async {
    if (action == 'edit') {
      _form(record);
      return;
    }
    if (action == 'manage-media') {
      await _mediaManager(record);
      return;
    }
    if (action == 'status') {
      await _evacuationQuickUpdate(action, record);
      return;
    }
    final api = ref.read(responderApiProvider);
    try {
      if (action == 'delete') {
        final softDelete = widget.module.supportsSoftDelete;
        final confirmed = await _confirmAction(
          title: 'Delete ${record.title}?',
          message: softDelete
              ? 'The record will move to Deleted records, where it can be restored or permanently removed.'
              : 'This permanently deletes the record and cannot be undone.',
          actionLabel: softDelete ? 'Move to deleted' : 'Delete permanently',
        );
        if (!confirmed) return;
        await api.delete(widget.module.path, record.id);
      } else if (action == 'restore') {
        await api.restore(widget.module.path, record.id);
      } else if (action == 'permanent-delete') {
        final confirmed = await _confirmAction(
          title: 'Permanently delete ${record.title}?',
          message:
              'This record and its related data will be removed permanently. This action cannot be undone.',
          actionLabel: 'Delete permanently',
        );
        if (!confirmed) return;
        await api.permanentDelete(widget.module.path, record.id);
      } else {
        if (_confirmationMessage(action, record) case final message?) {
          final confirmed = await _confirmAction(
            title: '${_actionLabel(action)} ${record.title}?',
            message: message,
            actionLabel: _actionLabel(action),
            destructive: const {
              'archive',
              'cancel',
              'deactivate',
            }.contains(action),
          );
          if (!confirmed) return;
        }
        await api.action(widget.module.path, record.id, action);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_actionLabel(action)} completed')),
        );
        refresh();
      }
    } catch (error) {
      await _showErrorDialog(error);
    }
  }

  Future<void> _evacuationQuickUpdate(
    String action,
    ManagedRecord record,
  ) async {
    final formKey = GlobalKey<FormState>();
    final operatingChoices = widget.module.fields
        .singleWhere((field) => field.name == 'operating_status')
        .choices;
    final availabilityChoices = widget.module.fields
        .singleWhere((field) => field.name == 'availability_status')
        .choices;
    var operatingStatus = record.data['operating_status']?.toString();
    var availabilityStatus = record.data['availability_status']?.toString();
    if (!operatingChoices.contains(operatingStatus)) {
      operatingStatus = operatingChoices.first;
    }
    if (!availabilityChoices.contains(availabilityStatus)) {
      availabilityStatus = availabilityChoices.first;
    }
    var isActive = record.data['is_active'] != false;
    var saving = false;
    ModalRoute<dynamic>? formRoute;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        formRoute ??= ModalRoute.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialog) {
            Future<void> submit() async {
              if (saving || !(formKey.currentState?.validate() ?? false)) {
                return;
              }
              setDialog(() {
                saving = true;
              });
              try {
                final body = <String, dynamic>{
                  'operating_status': operatingStatus,
                  'availability_status': availabilityStatus,
                  'is_active': isActive,
                };
                await ref
                    .read(responderApiProvider)
                    .patchAction(widget.module.path, record.id, action, body);
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext, true);
                }
              } catch (error) {
                if (dialogContext.mounted) {
                  setDialog(() {
                    saving = false;
                  });
                  await _showErrorDialog(
                    error,
                    title: 'Unable to update evacuation center',
                    fromContext: dialogContext,
                  );
                }
              }
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
              icon: const Icon(Icons.settings_suggest_outlined),
              title: const Text('Update operating status'),
              content: SizedBox(
                width: 480,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          record.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: operatingStatus,
                          decoration: const InputDecoration(
                            labelText: 'Operating status',
                          ),
                          items: [
                            for (final value in operatingChoices)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) => operatingStatus = value,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: availabilityStatus,
                          decoration: const InputDecoration(
                            labelText: 'Availability',
                          ),
                          items: [
                            for (final value in availabilityChoices)
                              DropdownMenuItem(
                                value: value,
                                child: Text(value),
                              ),
                          ],
                          onChanged: saving
                              ? null
                              : (value) => availabilityStatus = value,
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Visible to citizens'),
                          subtitle: const Text(
                            'Inactive centers are hidden from public results.',
                          ),
                          value: isActive,
                          onChanged: saving
                              ? null
                              : (value) => setDialog(() => isActive = value),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton.icon(
                  onPressed: saving ? null : submit,
                  icon: saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(saving ? 'Saving...' : 'Save update'),
                ),
              ],
            );
          },
        );
      },
    );
    await formRoute?.completed;
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Operating status updated successfully.')),
      );
      refresh();
    }
  }

  Future<void> _mediaManager(ManagedRecord guideline) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => GuidelineMediaDialog(
            api: ref.read(responderApiProvider),
            guidelineId: guideline.id,
            guidelineTitle: guideline.title,
          ),
        ),
      );

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = true,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: Icon(
            destructive
                ? Icons.warning_amber_rounded
                : Icons.help_outline_rounded,
            color: const Color(0xffdd2d4a),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: const Color(0xffb91c1c),
                    )
                  : null,
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(actionLabel),
            ),
          ],
        ),
      ) ??
      false;

  String? _confirmationMessage(
    String action,
    ManagedRecord record,
  ) => switch (action) {
    'publish' =>
      'This will make the record available through the citizen API when its other visibility rules are satisfied.',
    'archive' =>
      'Archived content is removed from active citizen views until it is published again.',
    'resolve' =>
      'This marks the alert as resolved and removes it from active citizen alerts.',
    'cancel' =>
      'This cancels the alert and removes it from active citizen alerts.',
    'deactivate' =>
      'This account will immediately lose access. You cannot deactivate your own account.',
    'activate' => 'This account will be allowed to sign in once verified.',
    'verify' => 'This confirms that ${record.title} is trusted and verified.',
    _ => null,
  };

  Future<void> _form([ManagedRecord? existing]) async {
    final now = DateTime.now();
    final creating = existing == null;
    final defaults = _defaults(widget.module.path);
    final relationOptions = <String, List<ManagedRecord>>{};
    try {
      for (final field in widget.module.fields.where(
        (field) => field.isRelation,
      )) {
        relationOptions[field.name] = await ref
            .read(responderRepositoryProvider)
            .records(field.relationModule!);
      }
    } catch (error) {
      await _showErrorDialog(error, title: 'Unable to load form options');
      return;
    }
    if (!mounted) return;

    dynamic initialValue(FormFieldSpec field) =>
        existing?.data[field.name] ?? defaults[field.name];
    final selectedDateTimes = <String, DateTime?>{};
    for (final field in widget.module.fields.where((field) => field.dateTime)) {
      final savedValue = DateTime.tryParse(
        initialValue(field)?.toString() ?? '',
      )?.toLocal();
      selectedDateTimes[field.name] =
          savedValue ??
          (existing == null && field.required
              ? field.name == 'expires_at'
                    ? now.add(const Duration(days: 1))
                    : now
              : null);
    }
    final controllers = {
      for (final field in widget.module.fields.where(
        (field) => !field.isBoolean,
      ))
        field.name: TextEditingController(
          text: field.dateTime
              ? _formatFormDateTime(selectedDateTimes[field.name])
              : field.isStringList
              ? _formatStringList(initialValue(field))
              : initialValue(field)?.toString() ?? '',
        ),
    };
    final booleanValues = {
      for (final field in widget.module.fields.where(
        (field) => field.isBoolean,
      ))
        field.name: _asBool(initialValue(field)),
    };
    void disposeControllers() {
      for (final controller in controllers.values) {
        controller.dispose();
      }
    }

    PlatformFile? picked;
    PlatformFile? attachmentPicked;
    ManagedRecord? savedRecord;
    String? fileError;
    String? attachmentError;
    bool saving = false;
    final key = GlobalKey<FormState>();
    final imageField = {
      'go-bag': 'image',
      'guidelines': 'featured_image',
      'evacuation-centers': 'image',
      'alerts': 'image',
    }[widget.module.path];

    String? validateInput(FormFieldSpec field, String? value) {
      final error = ResponderValidators.field(field, value, creating: creating);
      if (error != null) return error;

      if (widget.module.path == 'alerts' &&
          field.name == 'instructions' &&
          controllers['severity_level']!.text == 'Critical' &&
          (value == null || value.trim().isEmpty)) {
        return 'Critical alerts require safety instructions.';
      }
      if (widget.module.path == 'alerts' &&
          (field.name == 'latitude' || field.name == 'longitude')) {
        final latitude = controllers['latitude']!.text.trim();
        final longitude = controllers['longitude']!.text.trim();
        if (latitude.isEmpty != longitude.isEmpty) {
          return 'Latitude and longitude must be provided together.';
        }
      }
      if (widget.module.path == 'alerts' &&
          field.name == 'affected_areas' &&
          booleanValues['evacuation_required'] == true &&
          ResponderValidators.parseStringList(value).isEmpty) {
        return 'Evacuation alerts require at least one affected area.';
      }
      if (field.isRelation && (value?.trim().isNotEmpty ?? false)) {
        final validIds = relationOptions[field.name]!
            .map((record) => record.id)
            .toSet();
        if (!validIds.contains(value!.trim())) {
          return 'Select a valid ${field.label.toLowerCase()}.';
        }
      }
      if (field.name == 'expires_at') {
        final startsAt = selectedDateTimes['starts_at'];
        final expiresAt = selectedDateTimes['expires_at'];
        if (startsAt != null &&
            expiresAt != null &&
            !expiresAt.isAfter(startsAt)) {
          return 'Expiration must be later than the start date.';
        }
      }
      return null;
    }

    Map<String, dynamic> buildBody() {
      final body = <String, dynamic>{};
      for (final field in widget.module.fields) {
        if (field.isBoolean) {
          body[field.name] = booleanValues[field.name] ?? false;
          continue;
        }
        if (field.dateTime) {
          final value = selectedDateTimes[field.name];
          if (value != null) body[field.name] = value.toUtc().toIso8601String();
          continue;
        }
        final controllerValue = controllers[field.name]!.text;
        final raw = field.type == FormFieldDataType.password
            ? controllerValue
            : controllerValue.trim();
        if (field.isStringList) {
          body[field.name] = ResponderValidators.parseStringList(raw);
          continue;
        }
        if (field.isRelation) {
          if (raw.isNotEmpty) {
            body[field.name] = raw;
          } else if (!creating) {
            body[field.name] = null;
          }
          continue;
        }
        if (raw.isEmpty) {
          final canClearOnUpdate =
              !creating &&
              !field.number &&
              !field.isChoice &&
              field.type != FormFieldDataType.password;
          if (canClearOnUpdate) body[field.name] = '';
          continue;
        }
        body[field.name] = switch (field.type) {
          FormFieldDataType.integer => int.parse(raw),
          FormFieldDataType.decimal => num.parse(raw),
          _ => raw,
        };
      }
      if (creating) {
        for (final entry in defaults.entries) {
          body.putIfAbsent(entry.key, () => entry.value);
        }
      }
      return body;
    }

    Future<void> submit(
      BuildContext dialogContext,
      StateSetter setDialog,
    ) async {
      if (saving ||
          fileError != null ||
          attachmentError != null ||
          !(key.currentState?.validate() ?? false)) {
        return;
      }
      setDialog(() {
        saving = true;
      });
      try {
        final api = ref.read(responderApiProvider);
        final body = buildBody();
        Map<String, dynamic> savedData;
        final files = <String, List<int>>{
          if (picked?.bytes != null && imageField != null)
            imageField: picked!.bytes!,
          if (attachmentPicked?.bytes != null)
            'attachment': attachmentPicked!.bytes!,
        };
        if (files.isNotEmpty) {
          savedData = await api.uploadFiles(
            widget.module.path,
            body.map(
              (key, value) => MapEntry(
                key,
                value is String
                    ? value
                    : value == null
                    ? ''
                    : jsonEncode(value),
              ),
            ),
            files,
            {
              if (picked != null && imageField != null)
                imageField: picked!.name,
              if (attachmentPicked != null)
                'attachment': attachmentPicked!.name,
            },
            id: existing?.id,
          );
        } else if (creating) {
          savedData = await api.create(widget.module.path, body);
        } else {
          savedData = await api.update(widget.module.path, existing.id, body);
        }
        savedRecord = ManagedRecord(savedData);
        if (dialogContext.mounted) Navigator.pop(dialogContext, true);
      } catch (error) {
        if (dialogContext.mounted) {
          setDialog(() {
            saving = false;
          });
          await _showErrorDialog(
            error,
            title: creating
                ? 'Unable to add ${widget.module.label.toLowerCase()}'
                : 'Unable to save changes',
            fromContext: dialogContext,
          );
        }
      }
    }

    ModalRoute<dynamic>? formRoute;
    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        formRoute ??= ModalRoute.of(context);
        return StatefulBuilder(
          builder: (context, setDialog) => AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            icon: Icon(
              existing == null
                  ? Icons.add_circle_outline_rounded
                  : Icons.edit_rounded,
              color: const Color(0xffdd2d4a),
            ),
            title: Text(
              existing == null
                  ? 'Add ${widget.module.label}'
                  : 'Edit ${existing.title}',
            ),
            content: SizedBox(
              width: 680,
              child: Form(
                key: key,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xfffff7f8),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: const Color(0xfff0d8de)),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 19,
                              color: Color(0xffdd2d4a),
                            ),
                            SizedBox(width: 9),
                            Expanded(
                              child: Text(
                                'Complete the public information below. Required fields must be filled before saving.',
                                style: TextStyle(
                                  color: Color(0xff76515b),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...widget.module.fields.map((field) {
                        final required =
                            field.required ||
                            (creating && field.requiredOnCreate);
                        final label = '${field.label}${required ? ' *' : ''}';
                        final controller = controllers[field.name];
                        late final Widget input;
                        if (field.isBoolean) {
                          input = Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xffe7cbd2),
                              ),
                            ),
                            child: SwitchListTile.adaptive(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              title: Text(field.label),
                              value: booleanValues[field.name] ?? false,
                              onChanged: saving
                                  ? null
                                  : (value) => setDialog(
                                      () => booleanValues[field.name] = value,
                                    ),
                            ),
                          );
                        } else if (field.isChoice || field.isRelation) {
                          final items = field.isChoice
                              ? field.choices
                                    .map((choice) => MapEntry(choice, choice))
                                    .toList()
                              : relationOptions[field.name]!
                                    .map(
                                      (record) => MapEntry(
                                        record.id,
                                        (record.data[field
                                                    .relationLabelField] ??
                                                record.title)
                                            .toString(),
                                      ),
                                    )
                                    .toList();
                          final controllerValue = controller?.text ?? '';
                          final selectedValue =
                              items.any((item) => item.key == controllerValue)
                              ? controllerValue
                              : null;
                          input = DropdownButtonFormField<String>(
                            key: ValueKey(field.name),
                            initialValue: selectedValue,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: label,
                              helperText: field.helperText,
                            ),
                            items: [
                              if (!required)
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('None'),
                                ),
                              for (final item in items)
                                DropdownMenuItem(
                                  value: item.key,
                                  child: Text(
                                    item.value,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: saving
                                ? null
                                : (value) => controller!.text = value ?? '',
                            validator: (value) => validateInput(field, value),
                          );
                        } else {
                          input = TextFormField(
                            controller: controller,
                            enabled: !saving,
                            maxLines: field.multiline ? 5 : 1,
                            obscureText:
                                field.type == FormFieldDataType.password,
                            readOnly: field.dateTime,
                            keyboardType: switch (field.type) {
                              FormFieldDataType.integer => TextInputType.number,
                              FormFieldDataType.decimal =>
                                const TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                              FormFieldDataType.email =>
                                TextInputType.emailAddress,
                              FormFieldDataType.phone => TextInputType.phone,
                              _ => null,
                            },
                            maxLength: field.maxLength,
                            decoration: InputDecoration(
                              labelText: label,
                              suffixIcon: field.dateTime
                                  ? const Icon(Icons.event_rounded)
                                  : null,
                              helperText:
                                  field.helperText ??
                                  (field.dateTime
                                      ? 'Select a date and time'
                                      : field.type ==
                                                FormFieldDataType.password &&
                                            !creating
                                      ? 'Leave blank to keep the current password'
                                      : null),
                            ),
                            onTap: field.dateTime
                                ? () async {
                                    final value = await _selectDateTime(
                                      context,
                                      selectedDateTimes[field.name],
                                    );
                                    if (value != null && context.mounted) {
                                      setDialog(() {
                                        selectedDateTimes[field.name] = value;
                                        controller!.text = _formatFormDateTime(
                                          value,
                                        );
                                      });
                                    }
                                  }
                                : null,
                            validator: (value) => validateInput(field, value),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: input,
                        );
                      }),
                      if (imageField != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfffffafb),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xfff0d8de)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0xfffce8ec),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: const Icon(
                                  Icons.image_outlined,
                                  color: Color(0xffdd2d4a),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      picked?.name ??
                                          'No optional image selected',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (fileError != null)
                                      Text(
                                        fileError!,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.error,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final result =
                                            await FilePicker.pickFiles(
                                              withData: true,
                                              type: FileType.custom,
                                              allowedExtensions: [
                                                'jpg',
                                                'jpeg',
                                                'png',
                                                'webp',
                                              ],
                                            );
                                        if (result != null && context.mounted) {
                                          final file = result.files.single;
                                          final error = file.bytes == null
                                              ? 'The selected image could not be read.'
                                              : ResponderValidators.image(
                                                  name: file.name,
                                                  size: file.size,
                                                );
                                          setDialog(() {
                                            fileError = error;
                                            picked = error == null
                                                ? file
                                                : null;
                                          });
                                        }
                                      },
                                icon: const Icon(
                                  Icons.upload_file_rounded,
                                  size: 18,
                                ),
                                label: const Text('Choose'),
                              ),
                            ],
                          ),
                        ),
                      if (widget.module.path == 'alerts') ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xfffffafb),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xfff0d8de)),
                          ),
                          child: Row(
                            children: [
                              const SizedBox.square(
                                dimension: 40,
                                child: Icon(
                                  Icons.attach_file_rounded,
                                  color: Color(0xffdd2d4a),
                                ),
                              ),
                              const SizedBox(width: 11),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attachmentPicked?.name ??
                                          'No optional attachment selected',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      attachmentError ??
                                          'JPEG, PNG, WebP, PDF, DOC, or DOCX up to 10 MB.',
                                      style: TextStyle(
                                        color: attachmentError == null
                                            ? const Color(0xff76515b)
                                            : Theme.of(
                                                context,
                                              ).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton.icon(
                                onPressed: saving
                                    ? null
                                    : () async {
                                        final result =
                                            await FilePicker.pickFiles(
                                              withData: true,
                                              type: FileType.custom,
                                              allowedExtensions: const [
                                                'jpg',
                                                'jpeg',
                                                'png',
                                                'webp',
                                                'pdf',
                                                'doc',
                                                'docx',
                                              ],
                                            );
                                        if (result != null && context.mounted) {
                                          final file = result.files.single;
                                          final error = file.bytes == null
                                              ? 'The selected attachment could not be read.'
                                              : ResponderValidators.attachment(
                                                  name: file.name,
                                                  size: file.size,
                                                );
                                          setDialog(() {
                                            attachmentError = error;
                                            attachmentPicked = error == null
                                                ? file
                                                : null;
                                          });
                                        }
                                      },
                                icon: const Icon(
                                  Icons.upload_file_rounded,
                                  size: 18,
                                ),
                                label: const Text('Choose'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: saving ? null : () => submit(context, setDialog),
                icon: saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(saving ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        );
      },
    );
    // Navigator.pop completes the dialog result before its exit animation has
    // removed the route. Keep its controllers alive, and do not open the media
    // page, until the dialog is fully detached from the inherited widget tree.
    await formRoute?.completed;
    disposeControllers();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            creating
                ? '${widget.module.label} created successfully.'
                : '${widget.module.label} updated successfully.',
          ),
        ),
      );
      refresh();
      if (creating &&
          widget.module.path == 'guidelines' &&
          savedRecord != null) {
        await _mediaManager(savedRecord!);
      }
    }
  }

  Future<DateTime?> _selectDateTime(
    BuildContext context,
    DateTime? current,
  ) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 20, 12, 31),
      helpText: 'Select date',
    );
    if (date == null || !context.mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Select time',
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _formatFormDateTime(DateTime? value) {
    if (value == null) return '';
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
    final hour = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = value.hour >= 12 ? 'PM' : 'AM';
    return '${months[value.month - 1]} ${value.day}, ${value.year} at '
        '$hour:$minute $period';
  }

  String _formatStringList(dynamic value) {
    if (value is Iterable) {
      return value.map((item) => item.toString().trim()).join('\n');
    }
    return value?.toString() ?? '';
  }

  bool _asBool(dynamic value) {
    if (value is bool) return value;
    return const {
      'true',
      '1',
      'yes',
      'on',
    }.contains(value?.toString().trim().toLowerCase());
  }

  Map<String, dynamic> _defaults(String module) => switch (module) {
    'go-bag' => {'is_active': true, 'is_required': false, 'display_order': 0},
    'calamities' => {'is_active': true},
    'guidelines' => {'is_featured': false, 'is_active': true},
    'evacuation-centers' => {
      'operating_status': 'Operational',
      'availability_status': 'Available',
      'supported_emergency_types': <String>[],
      'is_active': true,
    },
    'emergency-contacts' => {'emergency_types': <String>[], 'is_active': true},
    'alerts' => {
      'status': 'Draft',
      'affected_areas': <String>[],
      'evacuation_required': false,
      'is_public': true,
      'is_active': true,
    },
    _ => {},
  };
}

class _ModuleHeader extends StatelessWidget {
  const _ModuleHeader({
    required this.label,
    required this.icon,
    required this.onAdd,
    required this.onRefresh,
  });
  final String label;
  final IconData icon;
  final VoidCallback onAdd;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 520;
      final identity = Row(
        mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xfffce8ec),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: const Color(0xffdd2d4a)),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manage $label',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  'Create, review, and update shared public information.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xff76515b),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      final actions = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: 'Refresh records',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: Text(compact ? 'Add' : 'Add record'),
          ),
        ],
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: 12),
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

class _StateChip extends StatelessWidget {
  const _StateChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.toLowerCase();
    final warning =
        normalized.contains('draft') ||
        normalized.contains('pending') ||
        normalized.contains('review');
    final negative =
        normalized.contains('delete') ||
        normalized.contains('inactive') ||
        normalized.contains('cancel');
    final background = negative
        ? const Color(0xfffee2e2)
        : warning
        ? const Color(0xfffff7d6)
        : const Color(0xffdcfce7);
    final foreground = negative
        ? const Color(0xff991b1b)
        : warning
        ? const Color(0xff92400e)
        : const Color(0xff166534);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

String _sentenceCase(String value) {
  final words = value.replaceAll('-', ' ');
  return '${words[0].toUpperCase()}${words.substring(1)}';
}

String _actionLabel(String action) => switch (action) {
  'status' => 'Update status',
  'permanent-delete' => 'Permanent delete',
  _ => _sentenceCase(action),
};

IconData _actionIcon(String action) => switch (action) {
  'publish' => Icons.publish_rounded,
  'archive' => Icons.archive_outlined,
  'resolve' => Icons.task_alt_rounded,
  'cancel' => Icons.cancel_outlined,
  'activate' => Icons.person_add_alt_1_rounded,
  'deactivate' => Icons.person_off_outlined,
  'verify' => Icons.verified_outlined,
  'status' => Icons.settings_suggest_outlined,
  _ => Icons.play_arrow_rounded,
};
