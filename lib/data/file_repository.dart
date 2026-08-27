import 'dart:io';
import 'dart:typed_data';
import '../core/api_client.dart';

/// Wraps the `/workspaces/:id/files` and `/files/:id/review` calls that were
/// duplicated near-identically across four screens (client_files_page.dart,
/// contract_detail_modal.dart, contracts_page.dart, am/workspace/files_tab.dart).
///
/// Deliberately returns raw maps rather than a typed model for now: the list
/// endpoint returns three differently-shaped collections in one response
/// (files / definitions / paymentFiles), and modeling that composite shape
/// properly belongs with the first screen migration rather than being
/// guessed at here. This still removes the literal duplicated HTTP-call code
/// from all four screens and makes them mockable in tests — the rest of the
/// Files slice (typed model + actually migrating a screen) is left for a
/// follow-up, since all four candidate screens currently have zero test
/// coverage and are sizeable (see docs/state-layer-migration-plan.md).
class FileRepository {
  final ApiClient _api;
  FileRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Map<String, dynamic>> fetchWorkspaceFiles(int workspaceId) =>
      _api.get('/workspaces/$workspaceId/files');

  Future<Map<String, dynamic>> uploadFile(
    int workspaceId,
    Map<String, dynamic> fields, {
    File? file,
    Uint8List? bytes,
    String? filename,
  }) =>
      _api.multipartPost('/workspaces/$workspaceId/files', fields, file: file, bytes: bytes, filename: filename);

  Future<void> deleteFile(int workspaceId, dynamic fileId) =>
      _api.delete('/workspaces/$workspaceId/files/$fileId');

  /// action is 'approved' or 'rejected'; reason is only meaningful (and only
  /// sent) for a rejection — same as the original inline calls.
  Future<void> reviewFile(dynamic fileId, {required String action, String? reason}) => _api.post(
        '/files/$fileId/review',
        {
          'action': action,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
}
