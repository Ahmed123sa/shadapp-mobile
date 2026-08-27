import 'package:flutter/material.dart';
import '../data/payment_repository.dart';

class PaymentProvider extends ChangeNotifier {
  final PaymentRepository _repo;
  PaymentProvider({PaymentRepository? repository}) : _repo = repository ?? PaymentRepository();

  List<dynamic> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchForWorkspace(int workspaceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _payments = await _repo.fetchForWorkspace(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
