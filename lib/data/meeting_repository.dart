import '../core/api_client.dart';
import '../models/meeting.dart';

/// Wraps every `/meetings`-related HTTP call.
class MeetingRepository {
  final ApiClient _api;
  MeetingRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Meeting>> fetchForWorkspace(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/meetings');
    return safeList(res['meetings']).map((j) => Meeting.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<List<Meeting>> fetchAllWorkspaces() async {
    final res = await _api.get('/all-meetings');
    return safeList(res['meetings']).map((j) => Meeting.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Raw (untyped) meeting list — am/workspace/meetings_tab.dart reads
  /// fields like `notes`, `contract`, `passcode` that aren't part of the
  /// [Meeting] model, same reasoning as ClientRepository's `...Raw` methods.
  Future<List<dynamic>> fetchForWorkspaceRaw(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/meetings');
    return safeList(res['meetings']);
  }

  Future<List<dynamic>> fetchAllWorkspacesRaw() async {
    final res = await _api.get('/all-meetings');
    return safeList(res['meetings']);
  }

  Future<void> cancel(int meetingId) => _api.patch('/meetings/$meetingId/cancel', {});

  Future<void> complete(int meetingId) => _api.patch('/meetings/$meetingId/complete', {});

  Future<void> create(int workspaceId, Map<String, dynamic> payload) =>
      _api.post('/workspaces/$workspaceId/meetings', payload);

  Future<void> update(int workspaceId, int meetingId, Map<String, dynamic> payload) =>
      _api.put('/workspaces/$workspaceId/meetings/$meetingId', payload);
}
