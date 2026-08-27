import '../core/api_client.dart';

/// Wraps `/audit-logs`, the single endpoint backing audit_log_page.dart.
class AuditLogRepository {
  final ApiClient _api;
  AuditLogRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// Returns the raw paginated envelope. Filter params are only included
  /// when non-empty, matching the original inline query-building exactly.
  Future<Map<String, dynamic>> fetch({
    String? search,
    String? action,
    String? dateFrom,
    String? dateTo,
    int page = 1,
  }) {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (action != null && action.isNotEmpty) params['action'] = action;
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    params['page'] = page.toString();

    final qs = params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&');
    return _api.get('/audit-logs?$qs');
  }
}
