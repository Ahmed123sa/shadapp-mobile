import 'dart:io';
import '../core/api_client.dart';
import '../models/client.dart';

/// Wraps every `/clients` HTTP call behind a typed interface. Only covers the
/// core list/create/update/delete/detail operations for now — the various
/// `/clients/:id/sign`, `/clients/:id/sub-users`, `/clients/:id/location` etc.
/// sub-resources scattered across signature/sub-users/settings screens belong
/// to other domains and are deliberately left as direct ApiClient calls until
/// their own slices (see docs/state-layer-migration-plan.md).
class ClientRepository {
  final ApiClient _api;
  ClientRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<Client>> fetchAll() async {
    final res = await _api.get('/clients');
    return safeList(res['clients']).map((j) => Client.fromJson(j as Map<String, dynamic>)).toList();
  }

  /// Raw client list (not typed [Client]s), optionally filtered by
  /// `manager_id` — used by sa_clients_page.dart, which needs fields like
  /// `signed_at` and the nested `workspace` object that aren't part of the
  /// [Client] model (same reasoning as [fetchOneRaw]).
  Future<List<dynamic>> fetchAllRaw({int? managerId}) async {
    final query = managerId != null ? '?manager_id=$managerId' : '';
    final res = await _api.get('/clients$query');
    return safeList(res['clients']);
  }

  /// Loops through every page of the unfiltered `/clients` list, combining
  /// results into one flat raw list — used by sa_approvals_page.dart, which
  /// needs every client (regardless of manager) to build its approvals
  /// queue. Matches the original inline pagination loop exactly.
  Future<List<dynamic>> fetchAllPaginatedRaw() async {
    final all = <dynamic>[];
    var page = 1;
    while (true) {
      final res = await _api.get('/clients?page=$page');
      final batch = safeList(res['clients']);
      if (batch.isEmpty) break;
      all.addAll(batch);
      final lastPage = (res['clients'] is Map ? res['clients']['last_page'] : null) ?? 1;
      if (page >= lastPage) break;
      page++;
    }
    return all;
  }

  Future<Client> fetchOne(int id) async {
    final res = await _api.get('/clients/$id');
    final data = res['client'] as Map<String, dynamic>? ?? res;
    return Client.fromJson(data);
  }

  /// Returns the raw `/clients/:id` envelope instead of a typed [Client].
  /// Needed by dashboard_page.dart / client_dashboard_screen.dart, which read
  /// the nested `workspace` object (id, status) that isn't part of the
  /// [Client] model — modeling Workspace is out of scope here since those
  /// screens aren't being migrated this slice (see
  /// docs/state-layer-migration-plan.md, Dashboard slice notes).
  Future<Map<String, dynamic>> fetchOneRaw(int id) => _api.get('/clients/$id');

  /// Returns the raw response, not just a [Client] — callers (like
  /// create_client_page) also need the one-time-only generated
  /// `credentials.email`/`credentials.password` that the backend returns
  /// alongside the created client.
  Future<Map<String, dynamic>> create(Map<String, dynamic> body) => _api.post('/clients', body);

  Future<Client> update(int id, Map<String, dynamic> body) async {
    final res = await _api.put('/clients/$id', body);
    final data = res['client'] as Map<String, dynamic>? ?? res;
    return Client.fromJson(data);
  }

  Future<void> delete(int id) => _api.delete('/clients/$id');

  /// Raw `/clients/:id/profile` envelope (client/stats/location) — backs
  /// am/workspace/client_profile_tab.dart.
  Future<Map<String, dynamic>> fetchProfile(int clientId) => _api.get('/clients/$clientId/profile');

  /// [address] is only included when the caller resolved one (e.g. via the
  /// map picker's reverse geocoding) — matches the two original inline call
  /// sites in client_profile_tab.dart exactly.
  Future<void> updateLocation(int clientId, {required double latitude, required double longitude, String? address}) =>
      _api.post('/clients/$clientId/location', {
        'latitude': latitude,
        'longitude': longitude,
        if (address != null) 'address': address,
      });

  Future<void> uploadAvatar(int clientId, File file) =>
      _api.multipartPost('/clients/$clientId/profile', {}, file: file, fileField: 'avatar');

  /// Creates a workspace for a client that doesn't have one yet — matches
  /// am_dashboard_page.dart's `_openClient`, which lazily provisions a
  /// workspace the first time an AM/SA opens a client with none.
  Future<Map<String, dynamic>> createWorkspace(int clientId) => _api.post('/workspaces', {'client_id': clientId});
}
