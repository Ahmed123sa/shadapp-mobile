import '../core/api_client.dart';

/// Wraps the one endpoint that's genuinely dashboard-specific and shared by
/// both the client dashboard and the AM dashboard: `/badge-counts`. Every
/// other piece of data those two screens show (clients, contracts, payments,
/// meetings, managers, notifications...) already has its own repository from
/// an earlier slice — this file deliberately does not duplicate any of that.
class DashboardRepository {
  final ApiClient _api;
  DashboardRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// Raw response, not a model — the badge-counts shape is a flat bag of
  /// per-section unread counts (e.g. `{"notifications": 3, "chat": 1, ...}`)
  /// with no shared identity/behavior worth wrapping in a class.
  Future<Map<String, dynamic>> fetchBadgeCounts() => _api.get('/badge-counts');
}
