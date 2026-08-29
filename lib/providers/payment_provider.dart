import 'dart:io';
import 'dart:typed_data';
import '../data/payment_repository.dart';

/// Thin wrapper over [PaymentRepository]. payments_page.dart and
/// am/workspace/payments_tab.dart still call ApiClient/PaymentRepository
/// directly and are deliberately not migrated yet (see
/// docs/state-layer-migration-plan.md) — this provider backs simpler
/// screens that only need to read a workspace's payment list (or, via
/// [fetchAllPendingRaw], sa_approvals_page.dart's cross-workspace queue).
///
/// Was `extends ChangeNotifier`: no screen/test listens to this class
/// reactively. See docs/state-layer-migration-plan.md, بند ٤.
class PaymentProvider {
  final PaymentRepository _repo;
  PaymentProvider({PaymentRepository? repository}) : _repo = repository ?? PaymentRepository();

  List<dynamic> _payments = [];
  bool _isLoading = false;
  String? _error;

  List<dynamic> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// AM-side approve/reject decision — see [PaymentRepository.review].
  Future<Map<String, dynamic>> reviewPayment(int paymentId, String action) => _repo.review(paymentId, action);

  /// Creates an installment schedule — see [PaymentRepository.schedule].
  Future<void> schedulePayments(int workspaceId, List<Map<String, dynamic>> installments) =>
      _repo.schedule(workspaceId, installments);

  /// See [PaymentRepository.updateSchedule].
  Future<void> updatePaymentSchedule(int paymentId, Map<String, dynamic> data) => _repo.updateSchedule(paymentId, data);

  /// See [PaymentRepository.deleteSchedule].
  Future<void> deletePaymentSchedule(int paymentId) => _repo.deleteSchedule(paymentId);

  /// Sends a payment request to the client — see
  /// [PaymentRepository.requestPayment].
  Future<void> requestPayment(int workspaceId, double amount, String currency, {String? notes}) =>
      _repo.requestPayment(workspaceId, amount, currency, notes: notes);

  /// Raw envelope — see [PaymentRepository.fetchForWorkspaceEnvelope].
  /// payments_page.dart owns its own loading/error state for this combined
  /// load, so this pass-through doesn't touch [_payments]/[_isLoading].
  Future<Map<String, dynamic>> fetchWorkspaceEnvelope(int workspaceId) => _repo.fetchForWorkspaceEnvelope(workspaceId);

  Future<void> fetchForWorkspace(int workspaceId) async {
    _isLoading = true;
    _error = null;
    try {
      _payments = await _repo.fetchForWorkspace(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
    }
  }

  /// Every pending payment across every page — see
  /// [PaymentRepository.fetchAllPendingRaw].
  Future<List<dynamic>> fetchAllPendingRaw() => _repo.fetchAllPendingRaw();

  /// Single page of the cross-workspace pending-payments queue — see
  /// [PaymentRepository.fetchPending]. am_dashboard_page.dart only ever reads
  /// page 1 (unlike [fetchAllPendingRaw], which loops every page), so this is
  /// a distinct, narrower pass-through that matches its original inline call.
  Future<Map<String, dynamic>> fetchPendingRaw({int page = 1}) => _repo.fetchPending(page: page);

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

  /// Uploads proof for an existing (e.g. scheduled) payment — see
  /// [PaymentRepository.uploadProof].
  Future<Map<String, dynamic>> uploadPaymentProof(
    int workspaceId,
    dynamic paymentId,
    String methodType, {
    List<File>? files,
    List<Uint8List>? bytesFiles,
    List<String>? bytesNames,
  }) =>
      _repo.uploadProof(workspaceId, paymentId, methodType, files: files, bytesFiles: bytesFiles, bytesNames: bytesNames);
}
