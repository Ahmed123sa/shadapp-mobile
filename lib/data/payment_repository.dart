import '../core/api_client.dart';

/// Read-only wrapper for the payments list endpoints. Deliberately raw maps,
/// not a typed model — same reasoning as ContractRepository: payments_page.dart
/// (850+ lines) and am/workspace/payments_tab.dart (700+ lines) both own rich,
/// varied payment/schedule/proof-file shapes with zero test coverage today,
/// so modeling and migrating them is left for a dedicated future session
/// (see docs/state-layer-migration-plan.md). This repository only covers the
/// two plain list reads that several other screens already fetch as
/// supporting data (calendar_tab.dart, am_dashboard_page.dart,
/// sa_approvals_page.dart) — none of the create/update/review/schedule
/// mutations are wrapped yet.
class PaymentRepository {
  final ApiClient _api;
  PaymentRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<dynamic>> fetchForWorkspace(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/payments');
    return safeList(res['payments']);
  }

  /// Cross-workspace pending-payments list (used to build an approvals
  /// queue), one page at a time — matches the pagination shape the callers
  /// already loop over manually.
  Future<Map<String, dynamic>> fetchPending({int page = 1}) => _api.get('/payments/pending?page=$page');
}
