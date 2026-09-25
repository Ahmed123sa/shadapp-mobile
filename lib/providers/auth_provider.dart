import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/api_client.dart';
import '../core/app_log.dart';
import '../core/notification_service.dart';

class AuthProvider extends ChangeNotifier {
  final ApiClient _api;
  final NotificationService _notificationService;
  AuthProvider({ApiClient? api, NotificationService? notificationService})
      : _api = api ?? ApiClient(),
        _notificationService = notificationService ?? NotificationService();
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
      // plans/notifications-badges-toasts-plan.md ن1 — the token
      // NotificationService.init() registered at app startup (main.dart) was
      // sent unauthenticated and 401'd silently, since nothing retried it
      // once a user actually logged in. This resends the already-cached
      // token now that there's a session for it to attach to; a no-op if
      // there isn't one yet (registerCurrentToken swallows its own errors).
      await _notificationService.registerCurrentToken();
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
      // See the matching comment in login() above — plans/notifications-
      // badges-toasts-plan.md ن1.
      await _notificationService.registerCurrentToken();
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

      // 19 Sept 2026 — a fresh login must start from a clean session, not
      // build on top of whatever the previous account left behind on this
      // device. setUserData()/setRole() below only ever WRITE a field when
      // the new value is non-null (see ApiClient.setUserData), so if this
      // response's workspace_id happens to be null (client has no workspace
      // yet — see AuthController::clientLogin's null-safe lookup), the
      // *previous* session's workspaceId silently survived untouched. Every
      // workspace-scoped screen (contracts/chat/payments/meetings/files)
      // reads that same stale value directly, so a sub-user or client could
      // end up making every workspace-scoped request against someone else's
      // workspace — 403ing on all of them since ScopeWorkspace correctly
      // rejects the mismatch, but confusingly so, and only by luck rather
      // than by anything actually clearing the old value.
      await _api.clearToken();
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
      // See the matching comment in login() above — plans/notifications-
      // badges-toasts-plan.md ن1. This is the path LoginPage actually calls.
      await _notificationService.registerCurrentToken();
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Raw `/auth/me` envelope — backs profile_page.dart's initial load.
  Future<Map<String, dynamic>> fetchCurrentUser() => _api.get('/auth/me');

  /// Uploads a new avatar image, matching profile_page.dart's `_pickAvatar`.
  Future<Map<String, dynamic>> uploadAvatar(File file) =>
      _api.multipartPost('/auth/me', {}, file: file, fileField: 'avatar');

  Future<Map<String, dynamic>> updateProfile({required String name}) => _api.put('/auth/me', {'name': name});

  /// Raw PUT /auth/me — used when the caller needs to send more than just
  /// `name` (e.g. am/settings/admin_settings_page.dart also sends
  /// `official_email` for non-account-manager roles). [updateProfile] above
  /// is left untouched since profile_page.dart already relies on its
  /// narrower signature.
  Future<Map<String, dynamic>> updateProfileRaw(Map<String, dynamic> body) => _api.put('/auth/me', body);

  /// Uploads a new avatar from in-memory bytes (e.g. web, or a FilePicker
  /// result that only has `.bytes`) — see [uploadAvatar] for the File-based
  /// variant profile_page.dart uses.
  Future<Map<String, dynamic>> uploadAvatarBytes({Uint8List? bytes, String? filename}) =>
      _api.multipartPost('/auth/me', {}, bytes: bytes, filename: filename, fileField: 'avatar');

  /// Staff-side password reset request — forgot_password_page.dart calls
  /// this and [requestClientPasswordReset] together, since it has no way to
  /// know upfront which table the email belongs to.
  Future<void> requestPasswordReset(String email) => _api.post('/auth/forgot-password', {'email': email});

  Future<void> requestClientPasswordReset(String email) => _api.post('/auth/client/forgot-password', {'email': email});

  Future<void> logout() async {
    // plans/notifications-badges-toasts-plan.md ن1 — without this, the
    // device's FCM token stayed registered to this account after logout, so
    // whoever logged in next on the same phone kept receiving the previous
    // person's push notifications until the app was fully closed and
    // reopened. Must happen *before* /auth/logout below: that call revokes
    // the Sanctum token this request needs to authenticate.
    final fcmToken = _notificationService.fcmToken;
    if (fcmToken != null) {
      try {
        await _api.post('/notifications/unregister-token', {'token': fcmToken});
      } catch (e, s) {
        // Non-fatal, same reasoning as the /auth/logout failure below: worst
        // case this device keeps getting push for the account that just
        // logged out until FcmChannel's own unregistered-token cleanup
        // catches it server-side.
        AppLog.error('AuthProvider.logout.unregisterToken', e, s);
      }
    }
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
