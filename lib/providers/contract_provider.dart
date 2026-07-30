import 'package:flutter/material.dart';
import '../core/api_client.dart';

class ContractProvider extends ChangeNotifier {
  final ApiClient _api = ApiClient();
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
      final res = await _api.get('/workspaces/$workspaceId/contracts');
      _contracts = safeList(res['contracts']);
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
      final res = await _api.get('/contracts');
      _contracts = safeList(res['contracts']);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
