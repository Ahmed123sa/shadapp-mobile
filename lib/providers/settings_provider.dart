import 'dart:io';
import 'package:flutter/material.dart';
import '../data/settings_repository.dart';

/// Thin pass-through over SettingsRepository — there's no shared list state
/// to cache here (unlike ClientProvider/ManagerProvider/etc.), just the
/// current user's own profile actions, so this mostly exists to keep
/// settings_page.dart consistent with the rest of the app: screens read
/// from a Provider, never call ApiClient/a Repository directly.
class SettingsProvider extends ChangeNotifier {
  final SettingsRepository _repo;
  SettingsProvider({SettingsRepository? repository}) : _repo = repository ?? SettingsRepository();

  Future<Map<String, dynamic>> fetchSubUser(int id) => _repo.fetchSubUser(id);
  Future<void> updateSubUserProfile(int id, Map<String, dynamic> body) => _repo.updateSubUserProfile(id, body);
  Future<void> uploadSubUserAvatar(int id, File file) => _repo.uploadSubUserAvatar(id, file);

  Future<Map<String, dynamic>> fetchClient(int id) => _repo.fetchClient(id);
  Future<void> updateClientProfile(int id, Map<String, dynamic> body) => _repo.updateClientProfile(id, body);
  Future<void> uploadClientAvatar(int id, File file) => _repo.uploadClientAvatar(id, file);
}
