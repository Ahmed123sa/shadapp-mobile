import '../data/dashboard_repository.dart';

/// Thin pass-through over DashboardRepository, mirroring SettingsProvider —
/// no shared list state to cache, just the badge-counts fetch that both
/// dashboard screens need.
// See docs/state-layer-migration-plan.md, بند ٤: no notifyListeners() calls
// here and nothing listens to this class reactively.
class DashboardProvider {
  final DashboardRepository _repo;
  DashboardProvider({DashboardRepository? repository}) : _repo = repository ?? DashboardRepository();

  Future<Map<String, dynamic>> fetchBadgeCounts() => _repo.fetchBadgeCounts();
}
