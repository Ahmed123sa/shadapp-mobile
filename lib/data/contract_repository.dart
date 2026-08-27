import '../core/api_client.dart';

/// Wraps the read side of `/workspaces/:id/contracts` and `/contracts`.
///
/// Deliberately returns raw maps, not a typed model: contracts carry a
/// materially richer and more varied shape (clauses, required_documents,
/// payment progress, PDF/signature state, etc.) than the domains modeled so
/// far in this migration, and modeling it properly belongs with an actual
/// screen migration, not this pass. The four screens that own contract
/// records (contracts_page.dart, contract_detail_modal.dart,
/// contract_builder.dart, am/workspace/contracts_tab.dart) are all large
/// (400-850 lines) and currently have zero test coverage, so none of them
/// are touched here — see docs/state-layer-migration-plan.md. This
/// repository only backs the existing ContractProvider, which several
/// simpler screens already fetch contracts through indirectly.
class ContractRepository {
  final ApiClient _api;
  ContractRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<dynamic>> fetchForWorkspace(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/contracts');
    return safeList(res['contracts']);
  }

  Future<List<dynamic>> fetchAll() async {
    final res = await _api.get('/contracts');
    return safeList(res['contracts']);
  }

  /// Raw `/workspaces/:id` envelope — contracts_page.dart and
  /// am/workspace/contracts_tab.dart both load this alongside the contract
  /// list (e.g. to read the client's `client_type` for VAT display).
  Future<Map<String, dynamic>> fetchWorkspace(int workspaceId) => _api.get('/workspaces/$workspaceId');

  /// Client-side approve/reject/edit-request action on a contract.
  /// [reason] is only sent when non-null and non-empty, matching the
  /// original inline call in contracts_page.dart.
  Future<void> clientAction(int contractId, String action, {String? reason}) => _api.post(
        '/contracts/$contractId/client-action',
        {
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );

  /// AM-side generic action (e.g. 'archive', 'complete') — the action name
  /// itself is the last path segment, same as the original
  /// `_api.post('/contracts/$id/$action')` call in
  /// am/workspace/contracts_tab.dart.
  Future<void> performAction(int id, String action) => _api.post('/contracts/$id/$action');

  Future<void> delete(int id) => _api.delete('/contracts/$id');

  /// Not really a contracts endpoint, but the only current caller
  /// (am/workspace/contracts_tab.dart's company-approve-with-signature flow,
  /// which checks for a saved signature before falling back to a manual
  /// signature pad) lives entirely in this domain, so it's kept here rather
  /// than starting a whole new repository for one read.
  Future<Map<String, dynamic>> fetchCurrentUser() => _api.get('/auth/me');

  /// [signature] is only included when the caller collected one manually;
  /// the "use my saved signature" path posts an empty body, matching the
  /// two original call sites in am/workspace/contracts_tab.dart.
  Future<void> companyApprove(int id, {String? signature}) => _api.post(
        '/contracts/$id/company-approve',
        signature != null ? {'signature': signature} : {},
      );

  Future<Map<String, dynamic>> fetchClauseTemplates() => _api.get('/contract-clause-templates');

  /// Returns the raw response — the caller (contract_builder.dart) reads
  /// back `res['contract']['id']` to immediately send the newly created
  /// contract.
  Future<Map<String, dynamic>> create(int workspaceId, Map<String, dynamic> payload) =>
      _api.post('/workspaces/$workspaceId/contracts', payload);

  Future<void> update(int id, Map<String, dynamic> payload) => _api.put('/contracts/$id', payload);

  Future<void> send(int id) => _api.post('/contracts/$id/send');
}
