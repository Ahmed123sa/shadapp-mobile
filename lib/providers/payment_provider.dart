import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../data/payment_repository.dart';

/// Thin wrapper over [PaymentRepository]. payments_page.dart and
/// am/workspace/payments_tab.dart still call ApiClient/PaymentRepository
/// directly and are deliberately not migrated yet (see
/// docs/state-layer-migration-plan.md) — this provider backs simpler
/// screens that only need to read a workspace's payment list (or, via
/// [fetchAllPendingRaw], sa_approvals_page.dart's cross-workspace queue).
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

  /// Every pending payment across every page — see
  /// [PaymentRepository.fetchAllPendingRaw].
  Future<List<dynamic>> fetchAllPendingRaw() => _repo.fetchAllPendingRaw();

  /// Creates a new payment request — see [PaymentRepository.create].
  /// payments_page.dart owns its own sheet/loading state, so this
  /// pass-through doesn't touch [_payments].
  Future<Map<String, dynamic>> createPayment(
    int workspaceId,
    Map<String, dynamic> fields, {
    List<File>? files,
    List<Uint8List>? bytesFiles,
    List<String>? bytesNames,
  }) =>
      _repo.create(workspaceId, fields, files: files, bytesFiles: bytesFiles, bytesNames: bytesNames);
}
