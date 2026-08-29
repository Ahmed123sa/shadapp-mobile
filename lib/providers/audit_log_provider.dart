import '../data/audit_log_repository.dart';

/// Thin pass-through — audit_log_page.dart already owns its own
/// loading/pagination/error state, so this provider doesn't duplicate it.
// See docs/state-layer-migration-plan.md, بند ٤: no notifyListeners() calls
// here and nothing listens to this class reactively.
class AuditLogProvider {
  final AuditLogRepository _repo;
  AuditLogProvider({AuditLogRepository? repository}) : _repo = repository ?? AuditLogRepository();

  Future<Map<String, dynamic>> fetch({
    String? search,
    String? action,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) =>
      _repo.fetch(search: search, action: action, dateFrom: dateFrom, dateTo: dateTo, page: page);
}
