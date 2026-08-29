import '../data/system_settings_repository.dart';

// Was `extends ChangeNotifier`: nothing ever calls notifyListeners() in this
// file and no screen/test listens to an instance of this class — screens
// copy its state into local vars and call setState() instead. See
// docs/state-layer-migration-plan.md, بند ٤ for the decision record.
class SystemSettingsProvider {
  final SystemSettingsRepository _repo;
  SystemSettingsProvider({SystemSettingsRepository? repository}) : _repo = repository ?? SystemSettingsRepository();

  Future<Map<String, dynamic>> fetchSettings() => _repo.fetchSettings();

  Future<void> updateSetting(String key, dynamic value) => _repo.updateSetting(key, value);
}
