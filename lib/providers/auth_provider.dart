import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_log.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  AuthProvider({ApiClient? api}) : _api = api ?? ApiClient();
  bool _isLoading = false;
  String? _error;
  bool _isLoggedIn = false;
  String? _role;
  String? _userName;

  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isLoggedIn => _isLoggedIn;
  String? get role => _role;
  String? get userName => _userName;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/auth/login', {
        'email': email,
        'password': password,
      });
      await _api.setToken(res['token']);
      final user = res['user'] as Map<String, dynamic>;
      await _api.setRole(user['role']);
      await _api.setUserData(id: user['id'], name: user['name']);
      _role = user['role'];
      _userName = user['name'];
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> clientLogin(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _api.post('/auth/client/login', {
        'email': email,
        'password': password,
      });
      await _api.setToken(res['token']);
      final client = res['client'] as Map<String, dynamic>;
      await _api.setRole('client');
      await _api.setUserData(id: client['id'], workspace: res['workspace_id']);
      _role = 'client';
      _isLoggedIn = true;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (e, s) {
      // Deliberately non-blocking: the local token is cleared either way, so
      // the user is logged out of this device even if the server call fails.
      AppLog.error('AuthProvider.logout', e, s);
    }
    await _api.clearToken();
    _isLoggedIn = false;
    _role = null;
    _userName = null;
    _error = null;
    notifyListeners();
  }
}
