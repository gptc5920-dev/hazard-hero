class LanguageOption {
  const LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.isDefault,
  });
  final String code, name, nativeName;
  final bool isDefault;
  factory LanguageOption.fromJson(Map<String, dynamic> j) => LanguageOption(
    code: j['language_code'] as String,
    name: j['name'] as String,
    nativeName: j['native_name'] as String,
    isDefault: j['is_default'] as bool? ?? false,
  );
}

class PublicRecord {
  const PublicRecord(this.data);
  final Map<String, dynamic> data;
  String get id => data['id']?.toString() ?? '';
  String get title =>
      (data['title'] ??
              data['name'] ??
              data['organization_name'] ??
              data['alert_code'] ??
              'Untitled')
          .toString();
  String get description =>
      (data['description'] ??
              data['summary'] ??
              data['message'] ??
              data['content'] ??
              '')
          .toString();
  String? get imageUrl =>
      (data['image'] ?? data['featured_image'] ?? data['logo'])?.toString();
  bool get usedFallback => data['used_fallback'] as bool? ?? false;
  int get version => data['version'] as int? ?? 1;

  String searchableText() {
    String flatten(Object? value) {
      if (value is Iterable) return value.map(flatten).join(' ');
      if (value is Map) return value.values.map(flatten).join(' ');
      return value?.toString() ?? '';
    }

    return flatten(data).toLowerCase();
  }

  List<String> labelsFor(String module) {
    String? value(String key) {
      final raw = data[key]?.toString().trim();
      return raw == null || raw.isEmpty ? null : raw;
    }

    return switch (module) {
      'go-bag' => [
        ?value('category'),
        ?value('priority_level'),
        if (data['is_required'] == true) 'Required',
      ],
      'guidelines' => [
        ?value('category'),
        ?value('emergency_type'),
        if (data['is_featured'] == true) 'Featured',
      ],
      'evacuation-centers' => [
        ?value('availability_status'),
        ?value('facility_type'),
      ],
      'emergency-contacts' => [?value('contact_type'), ?value('availability')],
      'alerts' => [?value('severity_level'), ?value('alert_type')],
      _ => const [],
    };
  }
}

class OfflinePackage {
  const OfflinePackage({
    required this.id,
    required this.language,
    required this.manifest,
    required this.savedAt,
    this.localPaths = const {},
  });
  final String id, language;
  final Map<String, dynamic> manifest;
  final DateTime savedAt;
  final Map<String, String> localPaths;
  Map<String, dynamic> toJson() => {
    'id': id,
    'language': language,
    'manifest': manifest,
    'saved_at': savedAt.toIso8601String(),
    'local_paths': localPaths,
  };
  factory OfflinePackage.fromJson(Map<String, dynamic> j) => OfflinePackage(
    id: j['id'] as String,
    language: j['language'] as String,
    manifest: (j['manifest'] as Map).cast<String, dynamic>(),
    savedAt: DateTime.parse(j['saved_at'] as String),
    localPaths: ((j['local_paths'] as Map?) ?? const {}).map(
      (key, value) => MapEntry(key.toString(), value.toString()),
    ),
  );
}
