import 'dart:io';
import 'dart:typed_data';
import '../core/api_client.dart';

/// Wraps the payments list/read endpoints plus the create/review/schedule
/// mutations. Deliberately raw maps, not a typed model — same reasoning as
/// ContractRepository: payments_page.dart (900+ lines) and
/// am/workspace/payments_tab.dart (700+ lines) both own rich, varied
/// payment/schedule/proof-file shapes with zero test coverage today, so
/// modeling and migrating the screens themselves is left for a dedicated
/// future session (see docs/state-layer-migration-plan.md). This repository
/// now covers every endpoint those two screens call, so a future migration
/// pass only has to touch the screens, not add plumbing.
class PaymentRepository {
  final ApiClient _api;
  PaymentRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<dynamic>> fetchForWorkspace(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/payments');
    return safeList(res['payments']);
  }

  /// Cross-workspace pending-payments list (used to build an approvals
  /// queue), one page at a time — matches the pagination shape the callers
  /// already loop over manually.
  Future<Map<String, dynamic>> fetchPending({int page = 1}) => _api.get('/payments/pending?page=$page');

  /// Loops through every page of [fetchPending], combining results into one
  /// flat raw list — used by sa_approvals_page.dart while building its
  /// cross-workspace approvals queue. Matches the original inline pagination
  /// loop exactly.
  Future<List<dynamic>> fetchAllPendingRaw() async {
    final all = <dynamic>[];
    var page = 1;
    while (true) {
      final res = await fetchPending(page: page);
      final batch = safeList(res['payments']);
      if (batch.isEmpty) break;
      all.addAll(batch);
      final lastPage = (res['payments'] is Map ? res['payments']['last_page'] : null) ?? 1;
      if (page >= lastPage) break;
      page++;
    }
    return all;
  }

  /// Creates a payment request with optional proof files, matching
  /// payments_page.dart's `_submitPayment`: native `File`s take priority
  /// over in-memory bytes, and a plain JSON POST is used when there are no
  /// files at all.
  Future<Map<String, dynamic>> create(
    int workspaceId,
    Map<String, dynamic> fields, {
    List<File>? files,
    List<Uint8List>? bytesFiles,
    List<String>? bytesNames,
  }) {
    if (files != null && files.isNotEmpty) {
      return _api.multipartPost(
        '/workspaces/$workspaceId/payments',
        fields,
        multipleFiles: files,
        multipleFileField: 'proof_files[]',
      );
    } else if (bytesFiles != null && bytesFiles.isNotEmpty) {
      return _api.multipartPost(
        '/workspaces/$workspaceId/payments',
        fields,
        multipleBytes: bytesFiles,
        multipleBytesNames: bytesNames,
        multipleFileField: 'proof_files[]',
      );
    }
    return _api.post('/workspaces/$workspaceId/payments', fields);
  }

  /// Uploads proof of payment for an existing (e.g. scheduled) installment —
  /// matches payments_page.dart's `_uploadProof`. [paymentId] is left
  /// `dynamic` because the original call site never constrains its type.
  Future<Map<String, dynamic>> uploadProof(
    int workspaceId,
    dynamic paymentId,
    String methodType, {
    List<File>? files,
    List<Uint8List>? bytesFiles,
    List<String>? bytesNames,
  }) {
    final fields = <String, dynamic>{'method_type': methodType};
    if (files != null && files.isNotEmpty) {
      return _api.multipartPut(
        '/workspaces/$workspaceId/payments/$paymentId',
        fields,
        multipleFiles: files,
        multipleFileField: 'proof_files[]',
      );
    } else if (bytesFiles != null && bytesFiles.isNotEmpty) {
      return _api.multipartPut(
        '/workspaces/$workspaceId/payments/$paymentId',
        fields,
        multipleBytes: bytesFiles,
        multipleBytesNames: bytesNames,
        multipleFileField: 'proof_files[]',
      );
    }
    return _api.put('/workspaces/$workspaceId/payments/$paymentId', fields);
  }

  /// AM-side approve/reject decision — matches am/workspace/payments_tab.dart.
  Future<Map<String, dynamic>> review(int paymentId, String action) =>
      _api.post('/payments/$paymentId/review', {'action': action});

  /// Creates an installment schedule for a workspace.
  Future<void> schedule(int workspaceId, List<Map<String, dynamic>> installments) =>
      _api.post('/workspaces/$workspaceId/payments/schedule', {'installments': installments});

  Future<void> updateSchedule(int paymentId, Map<String, dynamic> data) =>
      _api.put('/payments/$paymentId/schedule', data);

  Future<void> deleteSchedule(int paymentId) => _api.delete('/payments/$paymentId/schedule');

  /// Sends a payment request to the client. [notes] is only included when
  /// non-empty, matching the original inline call.
  Future<void> requestPayment(int workspaceId, double amount, String currency, {String? notes}) => _api.post(
        '/workspaces/$workspaceId/payments/request',
        {
          'amount': amount,
          'currency': currency,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
}
