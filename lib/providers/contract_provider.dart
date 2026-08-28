import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../data/contract_repository.dart';

class ContractProvider extends ChangeNotifier {
  final ContractRepository _repo;
  // Constructor signature deliberately unchanged (still takes ApiClient?,
  // not ContractRepository?) — this provider is already wired into
  // main.dart and covered by an existing test file; building the
  // repository internally means neither has to change for this refactor.
  ContractProvider({ApiClient? api}) : _repo = ContractRepository(api: api);
  List<dynamic> _contracts = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get contracts => _contracts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchContracts(int workspaceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _contracts = await _repo.fetchForWorkspace(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Raw `/workspaces/:id` envelope — am_workspace_page.dart's header reads
  /// the client's name/avatar/status/type from it. Lives here rather than a
  /// dedicated one-method repository since [ContractRepository] already
  /// wraps this exact endpoint for contracts_page.dart/contracts_tab.dart.
  Future<Map<String, dynamic>> fetchWorkspaceRaw(int workspaceId) => _repo.fetchWorkspace(workspaceId);

  /// Every contract in a single workspace across every page — see
  /// [ContractRepository.fetchForWorkspacePaginatedRaw].
  Future<List<dynamic>> fetchWorkspaceContractsPaginatedRaw(int workspaceId) =>
      _repo.fetchForWorkspacePaginatedRaw(workspaceId);

  /// Single-page raw contract list for a workspace — see
  /// [ContractRepository.fetchForWorkspace]. Unlike [fetchContracts], this
  /// doesn't touch [_contracts]/[_isLoading]/[_error]: payments_page.dart
  /// uses it as one leg of a combined load where it owns its own state and
  /// silently treats a contracts-fetch failure as "no contracts" rather than
  /// a fatal error.
  Future<List<dynamic>> fetchWorkspaceContractsRaw(int workspaceId) => _repo.fetchForWorkspace(workspaceId);

  /// Client-side approve/reject/edit-request decision on a contract — see
  /// [ContractRepository.clientAction]. chat_page.dart's inline "Approve"
  /// button on a contract-card message uses this without touching
  /// [_contracts]/[_isLoading].
  Future<void> clientAction(int contractId, String action, {String? reason}) =>
      _repo.clientAction(contractId, action, reason: reason);

  /// `/all-contracts` — see [ContractRepository.fetchAllAcrossCompany].
  /// am_dashboard_page.dart owns its own loading/error state, so this
  /// pass-through doesn't touch [_contracts]/[_isLoading].
  Future<List<dynamic>> fetchAllContractsAcrossCompanyRaw() => _repo.fetchAllAcrossCompany();

  /// AM-side generic action (archive/complete/send/etc.) — see
  /// [ContractRepository.performAction]. am/workspace/contracts_tab.dart.
  Future<void> performAction(int id, String action) => _repo.performAction(id, action);

  /// See [ContractRepository.delete]. Named `deleteContract` here (not
  /// `delete`) since a bare `delete` reads ambiguously on a provider that
  /// also exposes list-mutating methods.
  Future<void> deleteContract(int id) => _repo.delete(id);

  /// `/auth/me` — am/workspace/contracts_tab.dart reads the signed-in
  /// account manager's saved signature off this before falling back to a
  /// manual signature pad. See [ContractRepository.fetchCurrentUser].
  Future<Map<String, dynamic>> fetchCurrentUser() => _repo.fetchCurrentUser();

  /// See [ContractRepository.companyApprove].
  Future<void> companyApprove(int id, {String? signature}) => _repo.companyApprove(id, signature: signature);

  Future<void> fetchAllContracts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _contracts = await _repo.fetchAll();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
