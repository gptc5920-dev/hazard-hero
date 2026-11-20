import 'dart:convert';
import 'package:http/http.dart' as http;
import '../local/app_database.dart';

class PullResponse {
  const PullResponse({required this.records, required this.cursor});
  final List<Map<String, dynamic>> records;
  final String? cursor;
}

abstract interface class RemoteSyncGateway {
  bool get isConfigured;
  Future<bool> healthCheck();
  Future<void> push(List<SyncOutboxData> operations);
  Future<PullResponse> pull({String? cursor});
}

class HttpRemoteSyncGateway implements RemoteSyncGateway {
  HttpRemoteSyncGateway({
    required String baseUrl,
    required String bearerToken,
    http.Client? client,
  }) : _baseUrl = baseUrl.replaceAll(RegExp(r'/$'), ''),
       _bearerToken = bearerToken,
       _client = client ?? http.Client();

  final String _baseUrl;
  final String _bearerToken;
  final http.Client _client;

  @override
  bool get isConfigured => _baseUrl.isNotEmpty;

  Map<String, String> get _headers => {
    'content-type': 'application/json',
    if (_bearerToken.isNotEmpty) 'authorization': 'Bearer $_bearerToken',
  };

  @override
  Future<bool> healthCheck() async {
    if (!isConfigured) return false;
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/health'), headers: _headers)
          .timeout(const Duration(seconds: 8));
      return response.statusCode >= 200 && response.statusCode < 300;
    } on Object {
      return false;
    }
  }

  @override
  Future<void> push(List<SyncOutboxData> operations) async {
    if (operations.isEmpty) return;
    final body = {
      'operations': operations
          .map(
            (item) => {
              'clientMutationId': item.id,
              'entityId': item.entityId,
              'entityType': item.entityType,
              'operation': item.operation,
              'payload': jsonDecode(item.payloadJson),
              'createdAt': item.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
    };
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/sync/push'),
          headers: _headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteSyncException('Push failed (${response.statusCode}).');
    }
  }

  @override
  Future<PullResponse> pull({String? cursor}) async {
    final uri = Uri.parse(
      '$_baseUrl/sync/pull',
    ).replace(queryParameters: cursor == null ? null : {'cursor': cursor});
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RemoteSyncException('Pull failed (${response.statusCode}).');
    }
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return PullResponse(
      records: ((json['records'] as List?) ?? const [])
          .cast<Map<String, dynamic>>(),
      cursor: json['cursor'] as String?,
    );
  }
}

class RemoteSyncException implements Exception {
  const RemoteSyncException(this.message);
  final String message;
  @override
  String toString() => message;
}
