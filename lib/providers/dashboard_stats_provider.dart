import '../data/dashboard_stats_repository.dart';

/// Thin pass-through over [DashboardStatsRepository], mirroring
/// DashboardProvider — no shared list state to cache, just the one fetch the
/// AM/SA dashboard home tabs need for their summary cards.
// No notifyListeners() calls here and nothing listens to this class
// reactively, same as DashboardProvider (docs/state-layer-migration-plan.md,
// بند ٤).
class DashboardStatsProvider {
  final DashboardStatsRepository _repo;
  DashboardStatsProvider({DashboardStatsRepository? repository}) : _repo = repository ?? DashboardStatsRepository();

  Future<Map<String, dynamic>> fetchStats() => _repo.fetchStats();

  /// See [DashboardStatsRepository.fetchPendingApprovals].
  Future<Map<String, dynamic>> fetchPendingApprovals({int limit = 200}) =>
      _repo.fetchPendingApprovals(limit: limit);
}
