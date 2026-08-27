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

  Future<Client> fetchOne(int id) async {
    final res = await _api.get('/clients/$id');
    final data = res['client'] as Map<String, dynamic>? ?? res;
    return Client.fromJson(data);
  }

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

  Future<void> uploadAvatar(int clientId, File file) =>
      _api.multipartPost('/clients/$clientId/profile', {}, file: file, fileField: 'avatar');
}
