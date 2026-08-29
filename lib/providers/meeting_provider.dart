import '../data/meeting_repository.dart';
import '../models/meeting.dart';

// Was `extends ChangeNotifier`: no screen/test listens to this class
// reactively. See docs/state-layer-migration-plan.md, بند ٤.
class MeetingProvider {
  final MeetingRepository _repo;
  MeetingProvider({MeetingRepository? repository}) : _repo = repository ?? MeetingRepository();

  List<Meeting> _meetings = [];
  bool _isLoading = false;
  String? _error;

  List<Meeting> get meetings => _meetings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchForWorkspace(int workspaceId) async {
    _isLoading = true;
    _error = null;
    try {
      _meetings = await _repo.fetchForWorkspace(workspaceId);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchAllWorkspaces() async {
    _isLoading = true;
    _error = null;
    try {
      _meetings = await _repo.fetchAllWorkspaces();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
    }
  }

  /// Raw meeting list — see [MeetingRepository.fetchForWorkspaceRaw].
  /// am/workspace/meetings_tab.dart owns its own loading/error state, so
  /// these pass-throughs (like the mutations below) don't touch [_meetings].
  Future<List<dynamic>> fetchForWorkspaceRaw(int workspaceId) => _repo.fetchForWorkspaceRaw(workspaceId);

  Future<List<dynamic>> fetchAllWorkspacesRaw() => _repo.fetchAllWorkspacesRaw();

  Future<void> cancelMeeting(int meetingId) => _repo.cancel(meetingId);

  Future<void> completeMeeting(int meetingId) => _repo.complete(meetingId);

  Future<void> createMeeting(int workspaceId, Map<String, dynamic> payload) => _repo.create(workspaceId, payload);

  Future<void> updateMeeting(int workspaceId, int meetingId, Map<String, dynamic> payload) =>
      _repo.update(workspaceId, meetingId, payload);
}
