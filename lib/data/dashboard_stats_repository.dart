import '../core/api_client.dart';

/// Wraps `GET /dashboard/stats` (server-side-stats-plan.md) — the
/// server-computed dashboard summary cards (client/contract/payment/approval
/// counts, this month's approved-payment revenue by currency), scoped to
/// what the signed-in user is allowed to see, the same as `/reports`. Kept
/// separate from [DashboardRepository] (which wraps the unrelated
/// `/badge-counts`) to mirror the web dashboard's own separate
/// `useDashboardStats` hook — this is a distinct concern from the
/// nav-badge unread counts even though both live under "dashboard".
class DashboardStatsRepository {
  final ApiClient _api;
  DashboardStatsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// Raw response, not a model — same reasoning as
  /// [DashboardRepository.fetchBadgeCounts]: a small, stable, nested bag of
  /// counts/sums with no behavior worth wrapping in a class. See the web's
  /// `DashboardStats` type (src/types/index.ts) for the exact shape:
  /// `{clients:{total}, contracts:{active,awaiting_client},
  /// payments:{pending}, approvals:{pending_requests,pending_contracts,
  /// pending_payments,total}, revenue_this_month:{<currency>:amount},
  /// period:{month,timezone}}`.
  Future<Map<String, dynamic>> fetchStats() => _api.get('/dashboard/stats');
}
