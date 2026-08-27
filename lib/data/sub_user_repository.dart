import '../core/api_client.dart';

/// Wraps the `/clients/:id/sub-users` and `/sub-users/:id` HTTP calls used by
/// subusers_page.dart. Raw maps throughout, no model — a sub-user's
/// `permissions` map is a flat set of booleans keyed by permission name
/// (see `_permissionKeys` in the screen) that's edited in place, which fits
/// a plain map far better than a fixed class would.
class SubUserRepository {
  final ApiClient _api;
  SubUserRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<dynamic>> fetchForClient(int clientId) async {
    final res = await _api.get('/clients/$clientId/sub-users');
    return safeList(res['sub_users']);
  }

  /// Returns the raw response — callers need `res['sub_user']`, the newly
  /// created record.
  Future<Map<String, dynamic>> create(int clientId, Map<String, dynamic> body) =>
      _api.post('/clients/$clientId/sub-users', body);

  Future<void> delete(int id) => _api.delete('/sub-users/$id');

  /// Returns the raw response — callers read back `res['sub_user']['permissions']`
  /// to confirm what the server actually persisted.
  Future<Map<String, dynamic>> updatePermissions(int id, Map<String, dynamic> permissions) =>
      _api.patch('/sub-users/$id/permissions', {'permissions': permissions});
}
