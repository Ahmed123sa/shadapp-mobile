import 'package:flutter/material.dart';
import '../data/dashboard_repository.dart';

/// Thin pass-through over DashboardRepository, mirroring SettingsProvider —
/// no shared list state to cache, just the badge-counts fetch that both
/// dashboard screens need.
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository _repo;
  DashboardProvider({DashboardRepository? repository}) : _repo = repository ?? DashboardRepository();

  Future<Map<String, dynamic>> fetchBadgeCounts() => _repo.fetchBadgeCounts();
}
