import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/api_config.dart';
import '../storage/secure_token_storage.dart';
import 'api_exception.dart';

typedef SessionExpired = FutureOr<void> Function();

class ApiClient {
  ApiClient({http.Client? client, this.tokens, this.onSessionExpired})
    : _client = client ?? http.Client();
  final http.Client _client;
  final SecureTokenStorage? tokens;
  final SessionExpired? onSessionExpired;
  Future<bool>? _refreshFuture;

  Future<Map<String, String>> _headers({bool authenticated = false}) async {
    final accessToken = authenticated ? await tokens?.accessToken : null;
    return {
      'accept': 'application/json',
      'content-type': 'application/json',
      if (accessToken != null) 'authorization': 'Bearer $accessToken',
    };
  }

  void close() => _client.close();

  Future<dynamic> get(String url, {bool authenticated = false}) =>
      _request('GET', url, authenticated: authenticated);
  Future<dynamic> post(
    String url,
    Object? body, {
    bool authenticated = false,
  }) => _request('POST', url, body: body, authenticated: authenticated);
  Future<dynamic> patch(
    String url,
    Object? body, {
    bool authenticated = false,
  }) => _request('PATCH', url, body: body, authenticated: authenticated);
  Future<dynamic> put(String url, Object? body, {bool authenticated = false}) =>
      _request('PUT', url, body: body, authenticated: authenticated);
  Future<dynamic> delete(String url, {bool authenticated = false}) =>
      _request('DELETE', url, authenticated: authenticated);
  Future<dynamic> multipart(
    String url, {
    required Map<String, String> fields,
    required Map<String, List<int>> files,
    required Map<String, String> fileNames,
    String method = 'POST',
    bool retry = true,
  }) async {
    try {
      final request = http.MultipartRequest(method, Uri.parse(url));
      request.headers.addAll(
        await _headers(authenticated: true)
          ..remove('content-type'),
      );
      request.fields.addAll(fields);
      for (final entry in files.entries) {
        request.files.add(
          http.MultipartFile.fromBytes(
            entry.key,
            entry.value,
            filename: fileNames[entry.key],
          ),
        );
      }
      final response = await http.Response.fromStream(
        await _client.send(request).timeout(ApiConfig.timeout),
      );
      if (response.statusCode == 401 && retry && await _refresh()) {
        return multipart(
          url,
          fields: fields,
          files: files,
          fileNames: fileNames,
          method: method,
          retry: false,
        );
      }
      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final envelope = decoded is Map ? decoded : const {};
        throw ApiException(
          envelope['message']?.toString() ?? 'File upload failed.',
          statusCode: response.statusCode,
          errors: _errorDetails(decoded),
        );
      }
      return decoded is Map && decoded.containsKey('success')
          ? decoded['data']
          : decoded;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException(
        'The API server is unavailable. Check your connection.',
      );
    }
  }

  Future<dynamic> _request(
    String method,
    String url, {
    Object? body,
    bool authenticated = false,
    bool retry = true,
  }) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(authenticated: authenticated);
      final encoded = body == null ? null : jsonEncode(body);
      final response = await (switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: encoded),
        'PATCH' => _client.patch(uri, headers: headers, body: encoded),
        'PUT' => _client.put(uri, headers: headers, body: encoded),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported method $method'),
      }).timeout(ApiConfig.timeout);
      if (response.statusCode == 401 &&
          authenticated &&
          retry &&
          await _refresh()) {
        return _request(
          method,
          url,
          body: body,
          authenticated: true,
          retry: false,
        );
      }
      if (response.statusCode == 204) return null;
      final decoded = _decode(response);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final envelope = decoded is Map ? decoded : const {};
        throw ApiException(
          envelope['message']?.toString() ??
              'The request could not be completed.',
          statusCode: response.statusCode,
          errors: _errorDetails(decoded),
        );
      }
      if (decoded is Map && decoded.containsKey('success'))
        return decoded['data'];
      return decoded;
    } on TimeoutException {
      throw const ApiException('The server took too long to respond.');
    } on http.ClientException {
      throw const ApiException(
        'The API server is unavailable. Check your connection.',
      );
    }
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } on FormatException {
      return response.body;
    }
  }

  Object? _errorDetails(dynamic decoded) {
    if (decoded is Map && decoded.containsKey('errors')) {
      return decoded['errors'];
    }
    return decoded is Map || decoded is List ? decoded : null;
  }

  Future<bool> _refresh() {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) return activeRefresh;
    final refresh = _performRefresh();
    _refreshFuture = refresh;
    refresh.whenComplete(() {
      if (identical(_refreshFuture, refresh)) _refreshFuture = null;
    });
    return refresh;
  }

  Future<bool> _performRefresh() async {
    final refresh = await tokens?.refreshToken;
    if (refresh == null) return false;
    try {
      final response = await _client
          .post(
            Uri.parse('${ApiConfig.responderBase}/auth/refresh/'),
            headers: {'content-type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode != 200)
        throw const ApiException('Session expired.');
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final data =
          (decoded['data'] as Map?)?.cast<String, dynamic>() ?? decoded;
      await tokens!.save(
        access: data['access'] as String,
        refresh: data['refresh'] as String? ?? refresh,
      );
      return true;
    } catch (_) {
      await tokens?.clear();
      await onSessionExpired?.call();
      return false;
    }
  }
}
