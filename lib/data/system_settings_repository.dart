import '../core/api_client.dart';

/// Wraps the global `/settings` resource (currently just
/// `corporate_tax_percentage`) — distinct from settings_repository.dart's
/// `SettingsRepository`, which is the current user's own profile editing.
/// Only am/settings/admin_settings_page.dart reads/writes this, and only for
/// super_admin users.
class SystemSettingsRepository {
  final ApiClient _api;
  SystemSettingsRepository({ApiClient? api}) : _api = api ?? ApiClient();

  Future<Map<String, dynamic>> fetchSettings() => _api.get('/settings');

  Future<void> updateSetting(String key, dynamic value) =>
      _api.put('/settings', {'key': key, 'value': value});
}
