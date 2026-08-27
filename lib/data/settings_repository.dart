import 'dart:io';
import '../core/api_client.dart';

/// Backs settings_page.dart's own profile-editing flow — the current user
/// (client or sub_user) editing their own name/email/phone/avatar/DOB.
///
/// This is a different concern from ClientRepository (an account manager
/// managing *other* clients): the endpoints don't even overlap except for
/// the avatar upload shape, and the sub_user resource isn't covered by any
/// existing repository at all. admin_settings_page.dart (971 lines: global
/// app settings, contract clause templates, AM profile, signature
/// management) is a separate, much larger concern left for its own future
/// migration — see docs/state-layer-migration-plan.md.
class SettingsRepository {
  final ApiClient _api;
  SettingsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Map<String, dynamic>> fetchSubUser(int id) async {
    final res = await _api.get('/sub-users/$id');
    return res['sub_user'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateSubUserProfile(int id, Map<String, dynamic> body) =>
      _api.put('/sub-users/$id/profile', body);

  Future<void> uploadSubUserAvatar(int id, File file) =>
      _api.multipartPost('/sub-users/$id/profile', {}, file: file, fileField: 'avatar');

  Future<Map<String, dynamic>> fetchClient(int id) async {
    final res = await _api.get('/clients/$id');
    return res['client'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateClientProfile(int id, Map<String, dynamic> body) =>
      _api.put('/clients/$id/profile', body);

  Future<void> uploadClientAvatar(int id, File file) =>
      _api.multipartPost('/clients/$id/profile', {}, file: file, fileField: 'avatar');
}
