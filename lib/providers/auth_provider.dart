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

  /// Full login flow, moved here from LoginPage so the screen no longer talks
  /// to ApiClient directly. Tries the staff endpoint first; a credential
  /// rejection (ValidationException/AuthException only — not a rate limit or
  /// a connection failure) falls back to the client endpoint, which itself
  /// may resolve to either a client or a sub_user account. Mirrors the
  /// branching that used to live inline in LoginPage._login() exactly.
  ///
  /// On failure the original exception is rethrown (after resetting loading
  /// state) instead of being swallowed into a string, so the caller keeps
  /// full control over which l10n message and UI reaction each exception
  /// type gets — that mapping is a UI concern, not this provider's.
  Future<void> authenticate(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final body = {'email': email, 'password': password};
      Map<String, dynamic> data;
      bool isClient = false;
      try {
        data = await _api.post('/auth/login', body);
      } on ValidationException {
        data = await _api.post('/auth/client/login', body);
        isClient = true;
      } on AuthException {
        data = await _api.post('/auth/client/login', body);
        isClient = true;
      }

      await _api.setToken(data['token']);

      if (isClient) {
        final loginType = data['login_type'] as String? ?? 'client';
        if (loginType == 'sub_user') {
          final subUser = data['sub_user'] as Map<String, dynamic>;
          final clientData = data['client'] as Map<String, dynamic>;
          final wsId = data['workspace_id'] as int?;
          await _api.setRole('sub_user');
          await _api.setUserData(id: clientData['id'] as int, name: subUser['name'] as String, workspace: wsId);
          await _api.setSubUserId(subUser['id'] as int);
          _role = 'sub_user';
          _userName = subUser['name'] as String;
        } else {
          final client = data['client'] as Map<String, dynamic>;
          final wsId = data['workspace_id'] as int?;
          await _api.setRole('client');
          await _api.setUserData(id: client['id'], name: client['company_name'], workspace: wsId);
          _role = 'client';
          _userName = client['company_name'] as String?;
        }
      } else {
        final user = data['user'] as Map<String, dynamic>;
        final role = user['role'] as String;
        await _api.setRole(role);
        await _api.setUserData(id: user['id'], name: user['name'], avatar: user['avatar_url'] as String?);
        _role = role;
        _userName = user['name'] as String?;
      }
      _isLoggedIn = true;
    } catch (e) {
      _error = e.toString();
      rethrow;
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
