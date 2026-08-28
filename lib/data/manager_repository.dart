import '../core/api_client.dart';
import '../models/manager.dart';

/// Wraps every `/account-managers` HTTP call behind a typed interface.
class ManagerRepository {
  final ApiClient _api;
  ManagerRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Manager>> fetchAll() async {
    final res = await _api.get('/account-managers');
    return safeList(res['managers']).map((j) => Manager.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Raw manager list (not typed [Manager]s) — am_dashboard_page.dart's SA
  /// branch reads fields like `managed_clients_count` directly off the
  /// dynamic map, same reasoning as ClientRepository's `...Raw` methods.
  Future<List<dynamic>> fetchAllRaw() async {
    final res = await _api.get('/account-managers');
    return safeList(res['managers']);
  }

  Future<Manager> fetchOne(int id) async {
    final res = await _api.get('/account-managers/$id');
    final data = res['manager'] as Map<String, dynamic>? ?? res;
    return Manager.fromJson(data);
  }

  /// Raw `/account-managers/:id` envelope instead of a typed [Manager] —
  /// manager_detail_page.dart also needs the sibling `clients` list from the
  /// same response, which isn't part of the [Manager] model.
  Future<Map<String, dynamic>> fetchOneRaw(int id) => _api.get('/account-managers/$id');

  /// `/account-managers/:id/stats` returns a different, dashboard-shaped
  /// payload (revenue/workspace counts, charts data), not a Manager — raw
  /// map, no model, same reasoning as DashboardRepository.fetchBadgeCounts.
  Future<Map<String, dynamic>> fetchStats(int id) => _api.get('/account-managers/$id/stats');

  /// Returns the raw response — callers need the one-time `credentials`
  /// alongside the created manager, same reasoning as ClientRepository.create.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) => _api.post('/account-managers', body);

  Future<Map<String, dynamic>> update(int id, Map<String, dynamic> body) =>
      _api.put('/account-managers/$id', body);

  Future<void> delete(int id) => _api.delete('/account-managers/$id');
}
