import 'package:flutter/material.dart';
import '../data/system_settings_repository.dart';

class SystemSettingsProvider extends ChangeNotifier {
  final SystemSettingsRepository _repo;
  SystemSettingsProvider({SystemSettingsRepository? repository}) : _repo = repository ?? SystemSettingsRepository();

  Future<Map<String, dynamic>> fetchSettings() => _repo.fetchSettings();

  Future<void> updateSetting(String key, dynamic value) => _repo.updateSetting(key, value);
}
