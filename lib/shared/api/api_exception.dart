class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.errors});
  final String message;
  final int? statusCode;
  final Object? errors;
  bool get isUnauthorized => statusCode == 401;

  List<String> get validationMessages {
    final messages = <String>[];
    _collectMessages(errors, messages);
    return messages.toSet().toList();
  }

  @override
  String toString() {
    final details = validationMessages;
    if (details.isNotEmpty) return details.join('\n');
    return _isMarkup(message)
        ? 'The request could not be completed. Please try again.'
        : message;
  }

  static void _collectMessages(
    Object? value,
    List<String> output, {
    String? field,
  }) {
    if (value == null) return;
    if (value is Map) {
      for (final entry in value.entries) {
        final key = entry.key.toString();
        _collectMessages(
          entry.value,
          output,
          field: key == 'non_field_errors' || key == 'detail'
              ? null
              : _fieldLabel(key),
        );
      }
      return;
    }
    if (value is Iterable) {
      for (final item in value) {
        _collectMessages(item, output, field: field);
      }
      return;
    }
    final text = value.toString().trim();
    if (text.isNotEmpty && !_isMarkup(text)) {
      output.add(field == null ? text : '$field: $text');
    }
  }

  static String _fieldLabel(String value) {
    final words = value.replaceAll('_', ' ').trim();
    if (words.isEmpty) return 'Field';
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  static bool _isMarkup(String value) {
    final text = value.trimLeft();
    final containsKnownMarkup = RegExp(
      r'<!doctype\s+html\b|<html\b|<\?xml\b|<error(?:\s|>)',
      caseSensitive: false,
    ).hasMatch(text);
    return containsKnownMarkup ||
        (text.startsWith('<') && RegExp(r'<[^>]+>').hasMatch(text));
  }
}

/// Converts an exception into text that is safe to present in the UI.
///
/// In particular, proxy, storage, and framework error pages are often HTML or
/// XML. Those responses are implementation details and must not be rendered to
/// users.
String userFacingErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (error is ApiException) return error.toString();

  final message = error
      .toString()
      .replaceFirst(RegExp(r'^(?:Exception|Error):\s*'), '')
      .trim();
  if (message.isEmpty || ApiException._isMarkup(message)) return fallback;
  return message;
}
