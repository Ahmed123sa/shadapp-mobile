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
