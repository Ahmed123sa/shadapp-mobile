import '../core/api_client.dart';

/// Company staff members (STAFF_TEAMS_PLAN.md): the super admin's `/company-staff`
/// CRUD and the per-client assign / unassign under `/workspaces/:id/staff`.
/// Raw maps on purpose, like the other repositories' `...Raw` methods — the
/// screens only read a handful of fields.
class StaffRepository {
  final ApiClient _api;
  StaffRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Map<String, dynamic>>> fetchAll({bool includeArchived = false}) async {
    final res = await _api.get('/company-staff${includeArchived ? '?include_archived=1' : ''}');
    return safeList(res['staff']).whereType<Map<String, dynamic>>().toList();
  }

  Future<void> create({
    required String name,
    required String email,
    required String password,
    String? phone,
    String? dateOfBirth,
    bool sendEmail = true,
  }) =>
      _api.post('/company-staff', {
        'name': name,
        'email': email,
        'password': password,
        'phone': phone,
        'date_of_birth': dateOfBirth,
        'send_email': sendEmail,
      });

  Future<void> update(int id, {required String name, required String email, String? phone, String? dateOfBirth}) =>
      _api.put('/company-staff/$id', {
        'name': name,
        'email': email,
        'phone': phone,
        'date_of_birth': dateOfBirth,
      });

  Future<void> changePassword(int id, String password) => _api.patch('/company-staff/$id/password', {'password': password});

  Future<void> archive(int id) => _api.post('/company-staff/$id/archive');

  Future<void> unarchive(int id) => _api.post('/company-staff/$id/unarchive');

  /// The clients one staff member is on (super admin's view).
  Future<List<Map<String, dynamic>>> clientsOf(int id) async {
    final res = await _api.get('/company-staff/$id/clients');
    return safeList(res['clients']).whereType<Map<String, dynamic>>().toList();
  }

  /// Every active staff member, each flagged with `assigned` for this client.
  Future<List<Map<String, dynamic>>> forWorkspace(int workspaceId) async {
    final res = await _api.get('/workspaces/$workspaceId/staff');
    return safeList(res['staff']).whereType<Map<String, dynamic>>().toList();
  }

  /// Assigns (or, when already assigned, updates) a member on a client. Without
  /// [permissions] a new assignment gets the defaults (everything on).
  Future<void> assign(int workspaceId, int memberId, {Map<String, bool>? permissions}) =>
      _api.put('/workspaces/$workspaceId/staff/$memberId', permissions == null ? {} : {'permissions': permissions});

  Future<void> unassign(int workspaceId, int memberId) => _api.delete('/workspaces/$workspaceId/staff/$memberId');

  // ── The manager's own team (PLAN_2_MANAGER_TEAMS.md) ──

  /// `GET /my-team` → `{team: [...], others: [...]}`.
  Future<Map<String, dynamic>> myTeam() => _api.get('/my-team');

  Future<void> addToTeam(int memberId) => _api.post('/my-team/$memberId');

  /// `{count, clients: [names]}` — who loses what if [memberId] leaves the team.
  Future<Map<String, dynamic>> removalImpact(int memberId) => _api.get('/my-team/$memberId/removal-impact');

  Future<void> removeFromTeam(int memberId) => _api.delete('/my-team/$memberId');

  /// The manager's clients that have a workspace, as `{workspace_id, name}` —
  /// what the "link to a client" sheet offers.
  Future<List<Map<String, dynamic>>> workspaceChoices() async {
    final res = await _api.get('/clients?per_page=100');
    final raw = res['clients'];
    final rows = raw is Map ? raw['data'] : raw;
    return safeList(rows)
        .whereType<Map<String, dynamic>>()
        .where((c) => c['workspace'] is Map && (c['workspace'] as Map)['id'] != null)
        .map((c) => <String, dynamic>{
              'workspace_id': (c['workspace'] as Map)['id'] as int,
              'name': (c['company_name'] ?? c['contact_person'] ?? '#${c['id']}').toString(),
            })
        .toList();
  }
}
