import '../core/api_client.dart';
import '../models/manager.dart';

/// Wraps every `/account-managers` HTTP call behind a typed interface.
/// The `/account-managers/:id/stats` sub-resource (manager_detail_page.dart)
/// is left as a direct ApiClient call for now — it returns a different,
/// dashboard-shaped payload, not a Manager, and doesn't belong in this
/// repository.
class ManagerRepository {
  final ApiClient _api;
  ManagerRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Manager>> fetchAll() async {
    final res = await _api.get('/account-managers');
    return safeList(res['managers']).map((j) => Manager.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<Manager> fetchOne(int id) async {
    final res = await _api.get('/account-managers/$id');
    final data = res['manager'] as Map<String, dynamic>? ?? res;
    return Manager.fromJson(data);
  }

  /// Returns the raw response — callers need the one-time `credentials`
  /// alongside the created manager, same reasoning as ClientRepository.create.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) => _api.post('/account-managers', body);

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) =>
      _api.put('/account-managers/$id', body);

  Future<void> delete(int id) => _api.delete('/account-managers/$id');
}
