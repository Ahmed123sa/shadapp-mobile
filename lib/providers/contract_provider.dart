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
