import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../shared/widgets/async_state_widgets.dart';
import '../core/citizen_providers.dart';
import '../localization/citizen_strings.dart';
import '../models/citizen_models.dart';

class CitizenRecordDetailScreen extends ConsumerWidget {
  const CitizenRecordDetailScreen({
    super.key,
    required this.module,
    required this.recordId,
    required this.pageTitle,
  });

  final String module;
  final String recordId;
  final String pageTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = CitizenStrings(ref.watch(languageProvider));
    final state = ref.watch(publicRecordsProvider(module));
    return Scaffold(
      body: state.when(
        loading: () => const AppLoading(),
        error: (error, _) => AppError(
          message: error.toString(),
          onRetry: () => ref.invalidate(publicRecordsProvider(module)),
        ),
        data: (records) {
          final matches = records.where((record) => record.id == recordId);
          if (matches.isEmpty) {
            return AppEmpty(message: strings.text('notAvailable'));
          }
          return _RecordBody(
            module: module,
            record: matches.first,
            strings: strings,
          );
        },
      ),
    );
  }
}

class _RecordBody extends StatelessWidget {
  const _RecordBody({
    required this.module,
    required this.record,
    required this.strings,
  });

  final String module;
  final PublicRecord record;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => ListView(
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
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                ),
              ),
              const SizedBox(height: 4),
              _RecordHeader(module: module, record: record, strings: strings),
              const SizedBox(height: 16),
              switch (module) {
                'go-bag' => _GoBagDetails(record.data, strings),
                'calamities' => _CalamityDetails(record.data, strings),
                'evacuation-centers' => _EvacuationDetails(
                  record.data,
                  strings,
                ),
                'emergency-contacts' => _ContactDetails(record.data, strings),
                'alerts' => _AlertDetails(record.data, strings),
                _ => _AllFields(record.data),
              },
            ],
          ),
        ),
      ),
    ],
  );
}

class _RecordHeader extends StatelessWidget {
  const _RecordHeader({
    required this.module,
    required this.record,
    required this.strings,
  });

  final String module;
  final PublicRecord record;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) {
    final labels = record.labelsFor(module);
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (module != 'emergency-contacts' &&
                record.imageUrl?.isNotEmpty == true) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 16 / 8,
                  child: Image.network(
                    record.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const ColoredBox(color: Color(0xffe2e8f0)),
                  ),
                ),
              ),
              const SizedBox(height: 18),
            ],
            if (labels.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: labels
                    .map((label) => Chip(label: Text(label)))
                    .toList(),
              ),
            if (labels.isNotEmpty) const SizedBox(height: 10),
            Text(
              record.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                height: 1.15,
              ),
            ),
            if (record.usedFallback) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.translate_rounded, size: 18),
                  const SizedBox(width: 6),
                  Expanded(child: Text(strings.text('englishFallback'))),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GoBagDetails extends StatelessWidget {
  const _GoBagDetails(this.data, this.strings);
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _TextSection(
        title: strings.text('whyNeedIt'),
        text: _text(data['description']),
      ),
      _InfoCard(
        children: [
          _InfoRow(
            icon: Icons.inventory_2_outlined,
            label: strings.text('suggestedQuantity'),
            value: [
              _text(data['quantity']),
              _text(data['unit']),
            ].where((value) => value.isNotEmpty).join(' '),
          ),
          _InfoRow(
            icon: Icons.category_outlined,
            label: strings.text('category'),
            value: _text(data['category']),
          ),
          _InfoRow(
            icon: Icons.priority_high_rounded,
            label: strings.text('priority'),
            value: _text(data['priority_level']),
          ),
          _InfoRow(
            icon: Icons.task_alt_rounded,
            label: strings.text('packingGuidance'),
            value: data['is_required'] == true
                ? strings.text('requiredEveryGoBag')
                : strings.text('recommendedItem'),
          ),
        ],
      ),
    ],
  );
}

class _CalamityDetails extends StatelessWidget {
  const _CalamityDetails(this.data, this.strings);
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => _TextSection(
    title: strings.text('whatCitizensKnow'),
    text: _text(data['description']),
  );
}

class _EvacuationDetails extends StatelessWidget {
  const _EvacuationDetails(this.data, this.strings);
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) {
    final address = _address(data, strings);
    final latitude = double.tryParse(_text(data['latitude']));
    final longitude = double.tryParse(_text(data['longitude']));
    final location =
        latitude != null &&
            longitude != null &&
            latitude >= -90 &&
            latitude <= 90 &&
            longitude >= -180 &&
            longitude <= 180
        ? LatLng(latitude, longitude)
        : null;
    final facilities = <String, String>{
      'has_electricity': 'Electricity',
      'has_water_supply': 'Water supply',
      'has_restroom': 'Restrooms',
      'has_medical_area': 'Medical area',
      'has_kitchen': 'Kitchen',
      'has_parking': 'Parking',
      'is_pwd_accessible': 'PWD accessible',
      'accepts_pets': 'Accepts pets',
    }.entries.where((entry) => data[entry.key] == true).map((e) => e.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusPanel(
          icon: Icons.people_alt_outlined,
          title: data['available_slots'] == null
              ? strings.text('capacityUnavailable')
              : '${_text(data['available_slots'])} ${strings.text('spacesAvailable')}',
          message: _text(
            data['availability_status'],
            fallback: strings.text('capacityUnavailable'),
          ),
        ),
        _TextSection(
          title: strings.text('aboutCenter'),
          text: _text(data['description']),
        ),
        if (_text(data['facility_description']).isNotEmpty)
          _TextSection(
            title: strings.text('facilityInformation'),
            text: _text(data['facility_description']),
          ),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: strings.text('address'),
              value: address,
            ),
            _InfoRow(
              icon: Icons.domain_outlined,
              label: strings.text('facilityType'),
              value: _text(data['facility_type']),
            ),
            _InfoRow(
              icon: Icons.call_outlined,
              label: strings.text('contactNumber'),
              value: _text(data['contact_number']),
            ),
            if (_text(data['distance_km']).isNotEmpty)
              _InfoRow(
                icon: Icons.near_me_outlined,
                label: strings.text('distance'),
                value: '${_text(data['distance_km'])} km',
              ),
          ],
        ),
        if (location != null) ...[
          const SizedBox(height: 16),
          _EvacuationMap(
            location: location,
            address: address,
            data: data,
            strings: strings,
          ),
        ],
        if (facilities.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TagSection(
            title: strings.text('availableFacilities'),
            values: facilities.toList(),
          ),
        ],
        if (_strings(data['supported_emergency_types']).isNotEmpty) ...[
          const SizedBox(height: 16),
          _TagSection(
            title: strings.text('supportsEmergencies'),
            values: _strings(data['supported_emergency_types']),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_text(data['contact_number']).isNotEmpty)
              FilledButton.icon(
                onPressed: () => _open(
                  Uri(scheme: 'tel', path: _text(data['contact_number'])),
                ),
                icon: const Icon(Icons.call),
                label: Text(strings.text('callCenter')),
              ),
          ],
        ),
      ],
    );
  }
}

class _EvacuationMap extends StatelessWidget {
  const _EvacuationMap({
    required this.location,
    required this.address,
    required this.data,
    required this.strings,
  });

  final LatLng location;
  final String address;
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 280,
          child: FlutterMap(
            options: MapOptions(initialCenter: location, initialZoom: 15.5),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.hazard_hero.citizen',
                maxNativeZoom: 19,
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: location,
                    width: 58,
                    height: 58,
                    alignment: Alignment.topCenter,
                    child: Semantics(
                      label: address,
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Color(0xffdd2d4a),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x44000000),
                              blurRadius: 10,
                              offset: Offset(0, 5),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () => _open(
                      Uri.parse('https://www.openstreetmap.org/copyright'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Color(0xffdd2d4a)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      strings.text('location'),
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    if (address.isNotEmpty)
                      Text(
                        address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.icon(
                onPressed: () => _openDirections(data),
                icon: const Icon(Icons.directions_rounded),
                label: Text(strings.text('getDirections')),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails(this.data, this.strings);
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) {
    final primary = _text(data['primary_phone_number']);
    final hotline = _text(data['hotline_number']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hotline.isNotEmpty || primary.isNotEmpty)
          _StatusPanel(
            icon: Icons.emergency_share_outlined,
            title: hotline.isNotEmpty ? 'Hotline $hotline' : primary,
            message: _text(
              data['availability'],
              fallback: strings.text('contactAvailabilityUnknown'),
            ),
          ),
        _TextSection(
          title: strings.text('aboutService'),
          text: _text(data['description']),
        ),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.badge_outlined,
              label: strings.text('contactPerson'),
              value: _text(data['contact_person']),
            ),
            _InfoRow(
              icon: Icons.call_outlined,
              label: strings.text('primaryPhone'),
              value: primary,
            ),
            _InfoRow(
              icon: Icons.phone_forwarded_outlined,
              label: strings.text('secondaryPhone'),
              value: _text(data['secondary_phone_number']),
            ),
            _InfoRow(
              icon: Icons.schedule_outlined,
              label: strings.text('officeHours'),
              value: _text(
                data['office_hours'],
                fallback: _text(data['availability']),
              ),
            ),
            _InfoRow(
              icon: Icons.email_outlined,
              label: strings.text('email'),
              value: _text(data['email']),
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: strings.text('address'),
              value: _address(data, strings),
            ),
          ],
        ),
        if (_strings(data['emergency_types']).isNotEmpty) ...[
          const SizedBox(height: 16),
          _TagSection(
            title: strings.text('emergencyServices'),
            values: _strings(data['emergency_types']),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (hotline.isNotEmpty)
              FilledButton.icon(
                onPressed: () => _open(Uri.parse(_text(data['hotline_uri']))),
                icon: const Icon(Icons.call),
                label: Text(strings.text('callHotline')),
              ),
            if (primary.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () =>
                    _open(Uri.parse(_text(data['primary_phone_uri']))),
                icon: const Icon(Icons.phone_outlined),
                label: Text(strings.text('callPrimary')),
              ),
            if (_text(data['email']).isNotEmpty)
              OutlinedButton.icon(
                onPressed: () =>
                    _open(Uri(scheme: 'mailto', path: _text(data['email']))),
                icon: const Icon(Icons.email_outlined),
                label: Text(strings.text('sendEmail')),
              ),
          ],
        ),
      ],
    );
  }
}

class _AlertDetails extends StatelessWidget {
  const _AlertDetails(this.data, this.strings);
  final Map<String, dynamic> data;
  final CitizenStrings strings;

  @override
  Widget build(BuildContext context) {
    final severity = _text(data['severity_level'], fallback: 'Alert');
    final affected = _strings(data['affected_areas']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusPanel(
          icon: Icons.warning_amber_rounded,
          title: '$severity alert',
          message: _text(data['alert_code']),
          color: _severityColor(severity),
        ),
        _TextSection(
          title: strings.text('officialMessage'),
          text: _text(data['message']),
        ),
        if (_text(data['instructions']).isNotEmpty)
          _TextSection(
            title: strings.text('whatToDoNow'),
            text: _text(data['instructions']),
            emphasized: true,
          ),
        if (_text(data['affected_area_description']).isNotEmpty)
          _TextSection(
            title: strings.text('affectedArea'),
            text: _text(data['affected_area_description']),
          ),
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.campaign_outlined,
              label: strings.text('source'),
              value: _text(data['source']),
            ),
            _InfoRow(
              icon: Icons.location_on_outlined,
              label: strings.text('location'),
              value: _address(data, strings),
            ),
            _InfoRow(
              icon: Icons.play_circle_outline,
              label: strings.text('starts'),
              value: _date(data['starts_at']),
            ),
            _InfoRow(
              icon: Icons.event_busy_outlined,
              label: strings.text('expires'),
              value: _date(data['expires_at']),
            ),
            if (_text(data['radius_km']).isNotEmpty)
              _InfoRow(
                icon: Icons.radar,
                label: strings.text('coverageRadius'),
                value: '${_text(data['radius_km'])} km',
              ),
          ],
        ),
        if (affected.isNotEmpty) ...[
          const SizedBox(height: 16),
          _TagSection(
            title: strings.text('affectedCommunities'),
            values: affected,
          ),
        ],
        if (data['evacuation_required'] == true) ...[
          const SizedBox(height: 16),
          _StatusPanel(
            icon: Icons.directions_run_rounded,
            title: strings.text('evacuationRequired'),
            message: _text(
              data['recommended_evacuation_center_name'],
              fallback: strings.text('followLocalOfficials'),
            ),
            color: Colors.red,
          ),
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (_text(data['attachment']).isNotEmpty)
              FilledButton.icon(
                onPressed: () => _open(Uri.parse(_text(data['attachment']))),
                icon: const Icon(Icons.attach_file),
                label: Text(strings.text('openAttachment')),
              ),
            if (_text(data['latitude']).isNotEmpty &&
                _text(data['longitude']).isNotEmpty)
              OutlinedButton.icon(
                onPressed: () => _openMap(data),
                icon: const Icon(Icons.map_outlined),
                label: Text(strings.text('viewAffectedLocation')),
              ),
          ],
        ),
      ],
    );
  }
}

class _AllFields extends StatelessWidget {
  const _AllFields(this.data);
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) => _InfoCard(
    children: data.entries
        .where((entry) => _text(entry.value).isNotEmpty)
        .map(
          (entry) => _InfoRow(
            icon: Icons.info_outline,
            label: entry.key.replaceAll('_', ' '),
            value: _text(entry.value),
          ),
        )
        .toList(),
  );
}

class _TextSection extends StatelessWidget {
  const _TextSection({
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
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            SelectableText(text, style: const TextStyle(height: 1.55)),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final visible = children
        .where((child) => child is! _InfoRow || child.value.isNotEmpty)
        .toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        child: Column(
          children: [
            for (var index = 0; index < visible.length; index++) ...[
              visible[index],
              if (index != visible.length - 1) const Divider(height: 1),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 13),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 2),
              SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _TagSection extends StatelessWidget {
  const _TagSection({required this.title, required this.values});
  final String title;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: values.map((value) => Chip(label: Text(value))).toList(),
          ),
        ],
      ),
    ),
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? Theme.of(context).colorScheme.primary;
    return Card(
      color: accent.withAlpha(24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: accent.withAlpha(35),
              foregroundColor: accent,
              child: Icon(icon),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: accent,
                    ),
                  ),
                  if (message.isNotEmpty) Text(message),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _text(Object? value, {String fallback = ''}) {
  if (value == null) return fallback;
  if (value is Iterable) {
    final joined = value.map((item) => item.toString()).join(', ');
    return joined.isEmpty ? fallback : joined;
  }
  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

List<String> _strings(Object? value) => value is Iterable
    ? value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList()
    : const [];

String _address(Map<String, dynamic> data, CitizenStrings strings) {
  final parts = [
    data['street_address'],
    data['barangay'],
    data['city_municipality'],
    data['province'],
    data['region'],
  ].map(_text).where((part) => part.isNotEmpty).toList();
  return parts.isEmpty ? strings.text('locationUnknown') : parts.join(', ');
}

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
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour < 12 ? 'AM' : 'PM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $period';
}

Color _severityColor(String severity) => switch (severity.toLowerCase()) {
  'critical' => const Color(0xffb91c1c),
  'severe' => const Color(0xffc2410c),
  'warning' => const Color(0xffd97706),
  'advisory' => const Color(0xff0369a1),
  _ => const Color(0xff475569),
};

Future<void> _open(Uri uri) async {
  if (uri.toString().isEmpty) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

Future<void> _openMap(Map<String, dynamic> data) async {
  final latitude = _text(data['latitude']);
  final longitude = _text(data['longitude']);
  final uri = Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': '$latitude,$longitude',
  });
  await _open(uri);
}

Future<void> _openDirections(Map<String, dynamic> data) async {
  final latitude = _text(data['latitude']);
  final longitude = _text(data['longitude']);
  if (latitude.isEmpty || longitude.isEmpty) return;
  final uri = Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': '$latitude,$longitude',
    'travelmode': 'driving',
  });
  await _open(uri);
}
