import 'dart:io';
import '../core/api_client.dart';
import '../models/approval.dart';

/// Wraps the approvals read/respond/create calls
/// (`/workspaces/:id/approvals` GET+POST, `/approvals/:id/respond` POST).
class ApprovalRepository {
  final ApiClient _api;
  ApprovalRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Approval>> fetchAll(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/approvals');
    return safeList(res['approvals']).map((j) => Approval.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Every pending approval across all of the caller's workspaces in one
  /// request (`/approvals/pending`, not paginated), each with its
  /// `workspace.client` nested — raw maps, since [Approval] doesn't model
  /// the workspace/client. Used by sa_approvals_page.dart's cross-workspace
  /// queue instead of calling [fetchAll] once per workspace, which was both
  /// N+1 and capped at the first 30 approvals per workspace.
  Future<List<dynamic>> fetchAllPendingRaw() async {
    final res = await _api.get('/approvals/pending');
    return safeList(res['approvals']);
  }

  /// Creates a new approval request, optionally with attachments — matches
  /// am/workspace/approvals_tab.dart's `_create`, which switches to a
  /// multipart request only when files are attached.
  Future<Map<String, dynamic>> create(int workspaceId, Map<String, dynamic> fields, {List<File>? files}) {
    if (files != null && files.isNotEmpty) {
      return _api.multipartPostMultiple('/workspaces/$workspaceId/approvals', fields, files: files, fileField: 'files[]');
    }
    return _api.post('/workspaces/$workspaceId/approvals', fields);
  }

  /// action is 'approved', 'rejected', or 'edit_requested'; reason is only
  /// sent when the caller provides one (matches the original inline calls,
  /// which only attached a reason for edit_requested).
  Future<void> respond(int id, {required String action, String? reason}) => _api.post(
        '/approvals/$id/respond',
        {
          'action': action,
          if (reason != null) 'reason': reason,
        },
      );
}
