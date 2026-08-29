import 'dart:io';
import 'dart:typed_data';
import '../data/file_repository.dart';

/// Thin pass-through over FileRepository — mirrors SettingsProvider/
/// DashboardProvider, no shared list state, just the four operations
/// client_files_page.dart and am/workspace/files_tab.dart both need.
// See docs/state-layer-migration-plan.md, بند ٤: no notifyListeners() calls
// here and nothing listens to this class reactively.
class FileProvider {
  final FileRepository _repo;
  FileProvider({FileRepository? repository}) : _repo = repository ?? FileRepository();

  Future<Map<String, dynamic>> fetchWorkspaceFiles(int workspaceId) => _repo.fetchWorkspaceFiles(workspaceId);

  Future<Map<String, dynamic>> uploadFile(
    int workspaceId,
    Map<String, dynamic> fields, {
    File? file,
    Uint8List? bytes,
    String? filename,
  }) =>
      _repo.uploadFile(workspaceId, fields, file: file, bytes: bytes, filename: filename);

  Future<void> deleteFile(int workspaceId, dynamic fileId) => _repo.deleteFile(workspaceId, fileId);

  Future<void> reviewFile(dynamic fileId, {required String action, String? reason}) =>
      _repo.reviewFile(fileId, action: action, reason: reason);

  Future<Map<String, dynamic>> createDefinition(int workspaceId, Map<String, dynamic> body) =>
      _repo.createDefinition(workspaceId, body);

  Future<void> deleteDefinition(int workspaceId, int definitionId) => _repo.deleteDefinition(workspaceId, definitionId);
}
