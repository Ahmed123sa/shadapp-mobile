import 'package:flutter/material.dart';
import '../data/approval_repository.dart';
import '../models/approval.dart';

class ApprovalProvider extends ChangeNotifier {
  final ApprovalRepository _repo;
  ApprovalProvider({ApprovalRepository? repository}) : _repo = repository ?? ApprovalRepository();

  List<Approval> _approvals = [];
  bool _isLoading = false;
  String? _error;

  List<Approval> get approvals => _approvals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchApprovals(int workspaceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _approvals = await _repo.fetchAll(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> respond(int id, {required String action, String? reason}) =>
      _repo.respond(id, action: action, reason: reason);
}
