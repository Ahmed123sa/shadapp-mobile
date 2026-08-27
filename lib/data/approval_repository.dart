import '../core/api_client.dart';
import '../models/approval.dart';

/// Wraps the client-facing read/respond approvals calls
/// (`/workspaces/:id/approvals` GET, `/approvals/:id/respond` POST). The
/// AM-side creation flow in approvals_tab.dart (multipart file upload) is a
/// separate concern, left for its own migration — same reasoning as
/// FileRepository not covering every /files sub-resource yet.
class ApprovalRepository {
  final ApiClient _api;
  ApprovalRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Approval>> fetchAll(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/approvals');
    return safeList(res['approvals']).map((j) => Approval.fromJson(j as Map<String, dynamic>)).toList();
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
