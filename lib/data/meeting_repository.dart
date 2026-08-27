import '../core/api_client.dart';
import '../models/meeting.dart';

/// Read-only wrapper for the meetings list endpoints. The mutating flows
/// (create/update/cancel/complete in am/workspace/meetings_tab.dart) aren't
/// covered yet — see lib/models/meeting.dart for why.
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
}
