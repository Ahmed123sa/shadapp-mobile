import '../core/api_client.dart';

/// Wraps `/reports`, the single stats endpoint backing reports_tab.dart.
class ReportRepository {
  final ApiClient _api;
  ReportRepository({ApiClient? api}) : _api = api ?? ApiClient();

  /// Returns the raw stats envelope. On failure returns
  /// `{'error': true, 'message': ...}` instead of throwing — matches the
  /// original inline `.catchError` exactly, since reports_tab.dart displays
  /// that message directly rather than treating it as an unexpected error.
  Future<Map<String, dynamic>> fetch({
    String? dateFrom,
    String? dateTo,
    int? clientId,
    String? clientType,
    int? managerId,
  }) {
    final params = <String, String>{};
    if (dateFrom != null) params['date_from'] = dateFrom;
    if (dateTo != null) params['date_to'] = dateTo;
    if (clientId != null) params['client_id'] = clientId.toString();
    if (clientType != null) params['client_type'] = clientType;
    if (managerId != null) params['manager_id'] = managerId.toString();

    final query = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    return _api.get('/reports$query').catchError((e) => <String, dynamic>{'error': true, 'message': e.toString()});
  }
}
