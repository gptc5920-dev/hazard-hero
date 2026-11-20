import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../shared/api/api_exception.dart';
import '../services/responder_api_service.dart';
import '../validation/responder_validators.dart';

Future<void> _showGuidelineMediaErrorDialog(
  BuildContext context,
  Object error, {
  required String title,
}) async {
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        Icons.error_outline_rounded,
        color: Theme.of(dialogContext).colorScheme.error,
      ),
      title: Text(title),
      content: Text(userFacingErrorMessage(error)),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

class GuidelineMediaDialog extends StatefulWidget {
  const GuidelineMediaDialog({
    super.key,
    required this.api,
    required this.guidelineId,
    required this.guidelineTitle,
  });

  final ResponderApiService api;
  final String guidelineId;
  final String guidelineTitle;

  @override
  State<GuidelineMediaDialog> createState() => _GuidelineMediaDialogState();
}

class _GuidelineMediaDialogState extends State<GuidelineMediaDialog> {
  late Future<List<Map<String, dynamic>>> _media = _load();

  Future<List<Map<String, dynamic>>> _load() => widget.api.list(
    'guideline-media',
    query: {'guideline': widget.guidelineId},
  );

  void _refresh() => setState(() {
    _media = _load();
  });

  Future<void> _add() async {
    final added = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AddGuidelineMediaDialog(
        api: widget.api,
        guidelineId: widget.guidelineId,
      ),
    );
    if (added == true && mounted) _refresh();
  }

  Future<void> _edit(Map<String, dynamic> item) async {
    final updated = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EditGuidelineMediaDialog(api: widget.api, item: item),
    );
    if (updated == true && mounted) _refresh();
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final title = item['title']?.toString() ?? 'this media item';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete $title?'),
        content: const Text(
          'This removes the media from the guideline. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete media'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.api.delete('guideline-media', item['id'].toString());
      if (mounted) _refresh();
    } catch (error) {
      if (!mounted) return;
      await _showGuidelineMediaErrorDialog(
        context,
        error,
        title: 'Unable to delete guideline media',
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Close media manager',
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.close_rounded),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Guideline media'),
          Text(
            widget.guidelineTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Refresh media',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 8),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _add,
      icon: const Icon(Icons.add_rounded),
      label: const Text('Add media'),
    ),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: _media,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline_rounded, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    userFacingErrorMessage(snapshot.error!),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: _refresh,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final media = snapshot.data ?? const [];
        if (media.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.perm_media_outlined, size: 52),
                  const SizedBox(height: 12),
                  Text(
                    'No media added yet',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Add an uploaded image, SVG, icon, or video, or embed a YouTube, Vimeo, or direct HTTPS media link.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Add first media'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
          itemCount: media.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final item = media[index];
            final source = item['source_type']?.toString() ?? 'upload';
            final type = item['media_type']?.toString() ?? 'media';
            final location = source == 'link'
                ? item['external_url']?.toString() ?? ''
                : item['media_file']?.toString() ?? '';
            return Card(
              child: ListTile(
                onTap: () => _edit(item),
                leading: CircleAvatar(child: Icon(_mediaIcon(type))),
                title: Text(
                  item['title']?.toString() ?? 'Untitled media',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      children: [
                        Chip(label: Text(_label(type))),
                        Chip(
                          label: Text(
                            source == 'link' ? 'Embedded link' : 'Upload',
                          ),
                        ),
                      ],
                    ),
                    if (location.isNotEmpty)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Media actions',
                  onSelected: (value) {
                    if (value == 'edit') _edit(item);
                    if (value == 'delete') _delete(item);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit media'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.delete_outline_rounded),
                        title: Text('Delete media'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

class _AddGuidelineMediaDialog extends StatefulWidget {
  const _AddGuidelineMediaDialog({
    required this.api,
    required this.guidelineId,
  });

  final ResponderApiService api;
  final String guidelineId;

  @override
  State<_AddGuidelineMediaDialog> createState() =>
      _AddGuidelineMediaDialogState();
}

class _AddGuidelineMediaDialogState extends State<_AddGuidelineMediaDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _url = TextEditingController();
  final _order = TextEditingController(text: '0');
  String _source = 'upload';
  String _mediaType = 'image';
  PlatformFile? _file;
  String? _fileError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'jpg',
        'jpeg',
        'png',
        'webp',
        'svg',
        'mp4',
        'webm',
        'mov',
      ],
    );
    if (result == null || !mounted) return;
    final file = result.files.single;
    final error = file.bytes == null
        ? 'The selected media file could not be read.'
        : ResponderValidators.mediaFile(
            name: file.name,
            size: file.size,
            mediaType: _mediaType,
          );
    setState(() {
      _fileError = error;
      _file = error == null ? file : null;
    });
  }

  Future<void> _submit() async {
    final fileMissing = _source == 'upload' && _file == null;
    setState(() {
      _fileError = fileMissing ? 'Choose a media file to upload.' : _fileError;
    });
    if (_saving || fileMissing || !(_form.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
    });
    final body = <String, dynamic>{
      'guideline': widget.guidelineId,
      'source_type': _source,
      'media_type': _mediaType,
      'title': _title.text.trim(),
      'description': _description.text.trim(),
      'display_order': int.parse(_order.text.trim()),
      'is_active': true,
      if (_source == 'link') 'external_url': _url.text.trim(),
    };
    try {
      if (_source == 'upload') {
        await widget.api.upload(
          'guideline-media',
          body.map(
            (key, value) =>
                MapEntry(key, value is String ? value : jsonEncode(value)),
          ),
          'media_file',
          _file!.bytes!,
          _file!.name,
        );
      } else {
        await widget.api.create('guideline-media', body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        await _showGuidelineMediaErrorDialog(
          context,
          error,
          title: 'Unable to add guideline media',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: const Text('Add guideline media'),
    content: SizedBox(
      width: 680,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'upload',
                    icon: Icon(Icons.upload_file_rounded),
                    label: Text('Upload file'),
                  ),
                  ButtonSegment(
                    value: 'link',
                    icon: Icon(Icons.link_rounded),
                    label: Text('Embed link'),
                  ),
                ],
                selected: {_source},
                onSelectionChanged: _saving
                    ? null
                    : (selection) => setState(() {
                        _source = selection.first;
                        _fileError = null;
                      }),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _mediaType,
                decoration: const InputDecoration(labelText: 'Media type *'),
                items: const [
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'svg', child: Text('SVG')),
                  DropdownMenuItem(value: 'icon', child: Text('Icon')),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _mediaType = value ?? 'image';
                        _file = null;
                        _fileError = null;
                      }),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (value) => ResponderValidators.requiredText(
                  value,
                  label: 'Title',
                  maxLength: 255,
                ),
              ),
              const SizedBox(height: 4),
              TextFormField(
                controller: _description,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Display order *'),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null || parsed < 0) {
                    return 'Display order must be a non-negative whole number.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              if (_source == 'link') ...[
                TextFormField(
                  controller: _url,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS media link *',
                    helperText:
                        'Supports YouTube, Vimeo, and direct HTTPS image, SVG, or video URLs.',
                  ),
                  validator: (value) => ResponderValidators.mediaUrl(
                    value,
                    mediaType: _mediaType,
                  ),
                ),
              ] else ...[
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickFile,
                  icon: const Icon(Icons.attach_file_rounded),
                  label: Text(_file?.name ?? 'Choose media file'),
                ),
                if (_fileError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _fileError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  _mediaType == 'video'
                      ? 'MP4, WebM, or MOV up to 100 MB.'
                      : _mediaType == 'svg'
                      ? 'Safe SVG files up to 5 MB.'
                      : 'JPEG, PNG, WebP${_mediaType == 'icon' ? ', or SVG' : ''} up to 10 MB.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Adding...' : 'Add media'),
      ),
    ],
  );
}

class _EditGuidelineMediaDialog extends StatefulWidget {
  const _EditGuidelineMediaDialog({required this.api, required this.item});

  final ResponderApiService api;
  final Map<String, dynamic> item;

  @override
  State<_EditGuidelineMediaDialog> createState() =>
      _EditGuidelineMediaDialogState();
}

class _EditGuidelineMediaDialogState extends State<_EditGuidelineMediaDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _url;
  late final TextEditingController _order;
  late String _mediaType;
  late final String _source;
  late bool _active;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _title = TextEditingController(text: item['title']?.toString() ?? '');
    _description = TextEditingController(
      text: item['description']?.toString() ?? '',
    );
    _url = TextEditingController(text: item['external_url']?.toString() ?? '');
    _order = TextEditingController(
      text: item['display_order']?.toString() ?? '0',
    );
    _mediaType = item['media_type']?.toString() ?? 'image';
    _source = item['source_type']?.toString() ?? 'upload';
    _active = item['is_active'] != false;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _url.dispose();
    _order.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.api.update('guideline-media', widget.item['id'].toString(), {
        'media_type': _mediaType,
        'title': _title.text.trim(),
        'description': _description.text.trim(),
        'display_order': int.parse(_order.text.trim()),
        'is_active': _active,
        if (_source == 'link') 'external_url': _url.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        await _showGuidelineMediaErrorDialog(
          context,
          error,
          title: 'Unable to save guideline media',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
    title: const Text('Edit guideline media'),
    content: SizedBox(
      width: 620,
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      _source == 'link'
                          ? Icons.link_rounded
                          : Icons.upload_file_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _source == 'link' ? 'Embedded link' : 'Uploaded file',
                    ),
                  ),
                  const Spacer(),
                  Switch.adaptive(
                    value: _active,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _active = value),
                  ),
                  const Text('Active'),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _mediaType,
                decoration: const InputDecoration(labelText: 'Media type *'),
                items: const [
                  DropdownMenuItem(value: 'image', child: Text('Image')),
                  DropdownMenuItem(value: 'video', child: Text('Video')),
                  DropdownMenuItem(value: 'svg', child: Text('SVG')),
                  DropdownMenuItem(value: 'icon', child: Text('Icon')),
                ],
                onChanged: _saving
                    ? null
                    : (value) =>
                          setState(() => _mediaType = value ?? _mediaType),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _title,
                enabled: !_saving,
                maxLength: 255,
                decoration: const InputDecoration(labelText: 'Title *'),
                validator: (value) => ResponderValidators.requiredText(
                  value,
                  label: 'Title',
                  maxLength: 255,
                ),
              ),
              TextFormField(
                controller: _description,
                enabled: !_saving,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) => ResponderValidators.optionalText(
                  value,
                  label: 'Description',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _order,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Display order *'),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  return parsed == null || parsed < 0
                      ? 'Display order must be a non-negative whole number.'
                      : null;
                },
              ),
              if (_source == 'link') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _url,
                  enabled: !_saving,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'HTTPS media link *',
                  ),
                  validator: (value) => ResponderValidators.mediaUrl(
                    value,
                    mediaType: _mediaType,
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                const Text(
                  'To replace the uploaded file, delete this media item and add the replacement.',
                  style: TextStyle(color: Color(0xff76515b), fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('Cancel'),
      ),
      FilledButton.icon(
        onPressed: _saving ? null : _submit,
        icon: _saving
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save_outlined),
        label: Text(_saving ? 'Saving...' : 'Save changes'),
      ),
    ],
  );
}

IconData _mediaIcon(String type) => switch (type) {
  'video' => Icons.play_circle_outline_rounded,
  'svg' => Icons.polyline_rounded,
  'icon' => Icons.emoji_symbols_rounded,
  _ => Icons.image_outlined,
};

String _label(String value) => '${value[0].toUpperCase()}${value.substring(1)}';
