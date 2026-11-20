import '../../shared/api/api_client.dart';
import '../../shared/constants/api_config.dart';

class BackendHealth {
  const BackendHealth({required this.status, required this.database});

  final String status;
  final String database;

  bool get connected => status == 'ok' && database == 'ok';

  factory BackendHealth.fromJson(Map<String, dynamic> json) => BackendHealth(
    status: json['status']?.toString() ?? 'unavailable',
    database: json['database']?.toString() ?? 'unavailable',
  );
}

class ResponderApiService {
  const ResponderApiService(this.client);
  final ApiClient client;
  String url(String path) => '${ApiConfig.responderBase}/$path/';
  Future<void> signup({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirm,
    String phoneNumber = '',
    String office = '',
  }) async {
    await client.post(url('auth/signup'), {
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'email': email.trim().toLowerCase(),
      'password': password,
      'password_confirm': passwordConfirm,
      'phone_number': phoneNumber.trim(),
      'office': office.trim(),
    });
  }

  Future<BackendHealth> health() async => BackendHealth.fromJson(
    (await client.get(ApiConfig.healthUrl) as Map).cast<String, dynamic>(),
  );
  Future<Map<String, dynamic>> login(String email, String password) async =>
      (await client.post(url('auth/login'), {
                'email': email,
                'password': password,
              })
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> profile() async =>
      (await client.get(url('auth/profile'), authenticated: true) as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async =>
      (await client.patch(url('auth/profile'), body, authenticated: true)
              as Map)
          .cast<String, dynamic>();
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await client.post(url('auth/change-password'), {
      'old_password': oldPassword,
      'new_password': newPassword,
    }, authenticated: true);
  }

  Future<void> forgotPassword(String email) async {
    await client.post(url('auth/forgot-password'), {'email': email});
  }

  Future<void> resetPassword({
    required String uid,
    required String token,
    required String newPassword,
  }) async {
    await client.post(url('auth/reset-password'), {
      'uid': uid,
      'token': token,
      'new_password': newPassword,
    });
  }

  Future<void> logout(String refresh) async => client.post(url('auth/logout'), {
    'refresh': refresh,
  }, authenticated: true);
  Future<List<Map<String, dynamic>>> list(
    String module, {
    Map<String, String>? query,
  }) async {
    final parameters = Map<String, String>.of(query ?? const {});
    final includeDeleted = parameters.remove('deleted') == 'true';
    parameters.putIfAbsent('page_size', () => '100');
    final records = <Map<String, dynamic>>[];
    String? next = Uri.parse(
      url(includeDeleted ? '$module/deleted' : module),
    ).replace(queryParameters: parameters).toString();
    final visited = <String>{};
    while (next != null && visited.add(next)) {
      final current = Uri.parse(next);
      final data = await client.get(next, authenticated: true);
      final rows =
          ((data is Map ? data['results'] : data) as List?) ?? const [];
      records.addAll(rows.map((row) => (row as Map).cast<String, dynamic>()));
      final nextValue = data is Map ? data['next']?.toString() : null;
      next = nextValue == null ? null : current.resolve(nextValue).toString();
    }
    return records;
  }

  Future<Map<String, dynamic>> create(
    String module,
    Map<String, dynamic> body,
  ) async => (await client.post(url(module), body, authenticated: true) as Map)
      .cast<String, dynamic>();
  Future<Map<String, dynamic>> update(
    String module,
    String id,
    Map<String, dynamic> body,
  ) async =>
      (await client.patch(url('$module/$id'), body, authenticated: true) as Map)
          .cast<String, dynamic>();
  Future<void> delete(String module, String id) async =>
      client.delete(url('$module/$id'), authenticated: true);
  Future<void> permanentDelete(String module, String id) async =>
      client.delete(url('$module/$id/permanent-delete'), authenticated: true);
  Future<dynamic> action(
    String module,
    String id,
    String action, [
    Map<String, dynamic>? body,
  ]) =>
      client.post(url('$module/$id/$action'), body ?? {}, authenticated: true);
  Future<dynamic> restore(String module, String id) =>
      action(module, id, 'restore');
  Future<Map<String, dynamic>> patchAction(
    String module,
    String id,
    String action,
    Map<String, dynamic> body,
  ) async =>
      (await client.patch(url('$module/$id/$action'), body, authenticated: true)
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> copyEnglishTranslation({
    required String translationModule,
    required String parentField,
    required String parentId,
    required String language,
  }) async =>
      (await client.post(url('$translationModule/copy-english'), {
                parentField: parentId,
                'language': language,
              }, authenticated: true)
              as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> upload(
    String module,
    Map<String, String> fields,
    String fileField,
    List<int> bytes,
    String fileName, {
    String? id,
  }) => uploadFiles(
    module,
    fields,
    {fileField: bytes},
    {fileField: fileName},
    id: id,
  );

  Future<Map<String, dynamic>> uploadFiles(
    String module,
    Map<String, String> fields,
    Map<String, List<int>> files,
    Map<String, String> fileNames, {
    String? id,
  }) async =>
      (await client.multipart(
                url(id == null ? module : '$module/$id'),
                fields: fields,
                files: files,
                fileNames: fileNames,
                method: id == null ? 'POST' : 'PATCH',
              )
              as Map)
          .cast<String, dynamic>();
}
