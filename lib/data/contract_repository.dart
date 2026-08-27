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
}
