import '../models/responder_models.dart';
import '../../shared/media/media_link.dart';

class ResponderValidators {
  const ResponderValidators._();

  static final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final RegExp _phoneCharacters = RegExp(r'^\+?[0-9()\-\s.]+$');
  static final RegExp _controlCharacters = RegExp(
    r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]',
  );

  static String? field(
    FormFieldSpec spec,
    String? value, {
    required bool creating,
  }) {
    final raw = value ?? '';
    final normalized = spec.type == FormFieldDataType.password
        ? raw
        : raw.trim();
    final isRequired = spec.required || (creating && spec.requiredOnCreate);

    if (normalized.isEmpty) {
      return isRequired ? '${spec.label} is required.' : null;
    }
    if (spec.maxLength != null && normalized.length > spec.maxLength!) {
      return '${spec.label} must be ${spec.maxLength} characters or fewer.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return '${spec.label} contains unsupported characters.';
    }

    switch (spec.type) {
      case FormFieldDataType.integer:
        if (!RegExp(r'^-?\d+$').hasMatch(normalized)) {
          return '${spec.label} must be a whole number.';
        }
        return _validateRange(spec, int.parse(normalized));
      case FormFieldDataType.decimal:
        final parsed = num.tryParse(normalized);
        if (parsed == null || !parsed.isFinite) {
          return '${spec.label} must be a valid number.';
        }
        return _validateRange(spec, parsed);
      case FormFieldDataType.email:
        return email(normalized, label: spec.label);
      case FormFieldDataType.phone:
        return phone(normalized, label: spec.label);
      case FormFieldDataType.password:
        return password(normalized);
      case FormFieldDataType.choice:
        if (!spec.choices.contains(normalized)) {
          return 'Select a valid ${spec.label.toLowerCase()}.';
        }
        return null;
      case FormFieldDataType.stringList:
        return stringList(normalized, label: spec.label, required: isRequired);
      case FormFieldDataType.boolean:
      case FormFieldDataType.relation:
      case FormFieldDataType.text:
      case FormFieldDataType.dateTime:
        return null;
    }
  }

  static String? email(
    String? value, {
    String label = 'Email address',
    bool required = true,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return required ? '$label is required.' : null;
    if (normalized.length > 254 || !_emailPattern.hasMatch(normalized)) {
      return 'Enter a valid ${label.toLowerCase()}.';
    }
    return null;
  }

  static String? phone(
    String? value, {
    String label = 'Phone number',
    bool required = true,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return required ? '$label is required.' : null;
    if (!_phoneCharacters.hasMatch(normalized)) {
      return '$label contains invalid characters.';
    }
    final digitCount = normalized.replaceAll(RegExp(r'\D'), '').length;
    if (digitCount < 3 || digitCount > 15) {
      return '$label must contain between 3 and 15 digits.';
    }
    return null;
  }

  static String? password(String? value, {bool required = true}) {
    final password = value ?? '';
    if (password.isEmpty) return required ? 'Password is required.' : null;
    if (password.length < 8) {
      return 'Password must contain at least 8 characters.';
    }
    if (password.length > 128) {
      return 'Password must be 128 characters or fewer.';
    }
    if (RegExp(r'^\d+$').hasMatch(password)) {
      return 'Password cannot contain only numbers.';
    }
    return null;
  }

  static String? requiredText(
    String? value, {
    required String label,
    int? maxLength,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return '$label is required.';
    if (maxLength != null && normalized.length > maxLength) {
      return '$label must be $maxLength characters or fewer.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return '$label contains unsupported characters.';
    }
    return null;
  }

  static String? optionalText(
    String? value, {
    required String label,
    int? maxLength,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    if (maxLength != null && normalized.length > maxLength) {
      return '$label must be $maxLength characters or fewer.';
    }
    if (_controlCharacters.hasMatch(normalized)) {
      return '$label contains unsupported characters.';
    }
    return null;
  }

  static List<String> parseStringList(String? value) {
    final seen = <String>{};
    return (value ?? '')
        .split(RegExp(r'[\r\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty && seen.add(item))
        .toList();
  }

  static String? stringList(
    String? value, {
    required String label,
    bool required = false,
  }) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return required ? '$label is required.' : null;
    if (_controlCharacters.hasMatch(normalized)) {
      return '$label contains unsupported characters.';
    }
    final items = parseStringList(normalized);
    if (items.isEmpty) return '$label must contain at least one item.';
    if (items.length > 100) {
      return '$label cannot contain more than 100 entries.';
    }
    if (items.any((item) => item.length > 180)) {
      return 'Each ${label.toLowerCase()} entry must be 180 characters or fewer.';
    }
    return null;
  }

  static String? image({required String name, required int size}) {
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (!const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      return 'Choose a JPEG, PNG, or WebP image.';
    }
    if (size <= 0) return 'The selected image is empty.';
    if (size > 10 * 1024 * 1024) {
      return 'The selected image must be 10 MB or smaller.';
    }
    return null;
  }

  static String? attachment({required String name, required int size}) {
    final extension = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toLowerCase()
        : '';
    if (!const {
      'jpg',
      'jpeg',
      'png',
      'webp',
      'pdf',
      'doc',
      'docx',
    }.contains(extension)) {
      return 'Choose a JPEG, PNG, WebP, PDF, DOC, or DOCX file.';
    }
    if (size <= 0) return 'The selected attachment is empty.';
    if (size > 10 * 1024 * 1024) {
      return 'The selected attachment must be 10 MB or smaller.';
    }
    return null;
  }

  static String? mediaFile({
    required String name,
    required int size,
    required String mediaType,
  }) {
    final extension = name.contains('.')
        ? '.${name.substring(name.lastIndexOf('.') + 1).toLowerCase()}'
        : '';
    final allowed = switch (mediaType) {
      'image' => const {'.jpg', '.jpeg', '.png', '.webp'},
      'video' => const {'.mp4', '.webm', '.mov'},
      'svg' => const {'.svg'},
      'icon' => const {'.jpg', '.jpeg', '.png', '.webp', '.svg'},
      _ => const <String>{},
    };
    if (!allowed.contains(extension)) {
      return 'The selected file does not match the $mediaType media type.';
    }
    if (size <= 0) return 'The selected media file is empty.';
    final limit = mediaType == 'video'
        ? 100 * 1024 * 1024
        : mediaType == 'svg'
        ? 5 * 1024 * 1024
        : 10 * 1024 * 1024;
    if (size > limit) {
      final megabytes = limit ~/ (1024 * 1024);
      return 'The selected media file must be $megabytes MB or smaller.';
    }
    return null;
  }

  static String? mediaUrl(String? value, {required String mediaType}) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return 'Media link is required.';
    final info = MediaLinkInfo.parse(normalized);
    if (info == null) {
      return 'Enter a valid HTTPS YouTube, Vimeo, or direct media link.';
    }
    if (info.provider != EmbeddedMediaProvider.direct) {
      return mediaType == 'video'
          ? null
          : 'YouTube and Vimeo links must use the Video media type.';
    }
    final extension = info.originalUri.path.toLowerCase();
    final valid = switch (mediaType) {
      'image' => const [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
      ].any(extension.endsWith),
      'video' => const ['.mp4', '.webm', '.mov'].any(extension.endsWith),
      'svg' => extension.endsWith('.svg'),
      'icon' => const [
        '.jpg',
        '.jpeg',
        '.png',
        '.webp',
        '.svg',
      ].any(extension.endsWith),
      _ => false,
    };
    return valid
        ? null
        : 'The direct link file type does not match the selected media type.';
  }

  static String? _validateRange(FormFieldSpec spec, num value) {
    if (spec.minValue != null && value < spec.minValue!) {
      return '${spec.label} must be at least ${spec.minValue}.';
    }
    if (spec.maxValue != null && value > spec.maxValue!) {
      return '${spec.label} must be at most ${spec.maxValue}.';
    }
    return null;
  }
}
