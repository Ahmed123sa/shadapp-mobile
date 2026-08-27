import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shadapp_client/generated/app_localizations.dart';
import 'app_log.dart';
import 'reverb_service.dart';

/// Read before dotenv.load() has run (in plain `flutter test`, it never
/// does — there's no widget-binding bootstrap to call it) throws
/// NotInitializedError instead of returning null like a normal missing key.
/// Falling back here means both real startup ordering mistakes and the test
/// environment get the same safe default instead of a crash.
String _defaultBaseUrl() {
  try {
    return dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000/api';
  } catch (_) {
    return 'http://localhost:8000/api';
  }
}

class ApiClient {
  String baseUrl = _defaultBaseUrl();
  final Duration _timeout = const Duration(seconds: 30);
  String? _token;
  int? userId;
  int? subUserId;
  int? workspaceId;
  int get workspaceIdSafe => workspaceId ?? 1;
  String? role;
  String? userName;
  String? avatarUrl;

  final FlutterSecureStorage _secureStorage;
  final http.Client _httpClient;

  AppLocalizations? l10n;

  static final ApiClient _instance = ApiClient._();
  ApiClient._() : _httpClient = http.Client(), _secureStorage = const FlutterSecureStorage();

  /// Test-only constructor. Bypasses the app-wide singleton and never touches
  /// the real secure-storage platform channel — supplying the token directly
  /// and an injected [client]/[secureStorage] lets unit tests exercise
  /// request building and status code handling in plain `flutter test`
  /// (SharedPreferences still needs `SharedPreferences.setMockInitialValues`
  /// in the test's setUp, since that path is a static call this class
  /// doesn't own).
  @visibleForTesting
  ApiClient.forTesting({
    required http.Client client,
    FlutterSecureStorage? secureStorage,
    String? token,
    String? baseUrlOverride,
  })  : _httpClient = client,
        _secureStorage = secureStorage ?? const FlutterSecureStorage(),
        _token = token {
    if (baseUrlOverride != null) baseUrl = baseUrlOverride;
  }

  factory ApiClient() => _instance;

  Future<void> init() async {
    _token = await _secureStorage.read(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString('base_url') ?? baseUrl;
    role = prefs.getString('role');
    userId = prefs.getInt('user_id');
    subUserId = prefs.getInt('sub_user_id');
    workspaceId = prefs.getInt('workspace_id');
    userName = prefs.getString('user_name');
    avatarUrl = prefs.getString('avatar_url');
  }

  Future<void> setToken(String token) async {
    _token = token;
    await _secureStorage.write(key: 'token', value: token);
  }

  Future<String?> getToken() async {
    if (_token != null) return _token;
    _token = await _secureStorage.read(key: 'token');
    return _token;
  }

  Future<void> clearToken() async {
    _token = null;
    userId = null;
    subUserId = null;
    workspaceId = null;
    role = null;
    userName = null;
    avatarUrl = null;
    await _secureStorage.delete(key: 'token');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('role');
    await prefs.remove('user_id');
    await prefs.remove('sub_user_id');
    await prefs.remove('workspace_id');
    await prefs.remove('user_name');
  }

  Future<void> setRole(String value) async {
    role = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('role', value);
  }

  Future<String?> getRole() async {
    if (role != null) return role;
    final prefs = await SharedPreferences.getInstance();
    role = prefs.getString('role');
    return role;
  }

  Future<void> setSubUserId(int id) async {
    subUserId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('sub_user_id', id);
  }

  Future<void> clearSubUserId() async {
    subUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('sub_user_id');
  }

  Future<void> setUserData({int? id, String? name, int? workspace, String? avatar}) async {
    if (id != null) userId = id;
    if (name != null) userName = name;
    if (workspace != null) workspaceId = workspace;
    if (avatar != null) avatarUrl = avatar;
    final prefs = await SharedPreferences.getInstance();
    if (id != null) await prefs.setInt('user_id', id);
    if (name != null) await prefs.setString('user_name', name);
    if (workspace != null) await prefs.setInt('workspace_id', workspace);
    if (avatar != null) await prefs.setString('avatar_url', avatar);
  }

  Future<void> registerFcmToken(String token, String deviceType) async {
    try {
      await post('/notifications/register-token', {
        'token': token,
        'device_type': deviceType,
      });
    } catch (e, s) {
      // Non-fatal: the user just won't get push notifications on this
      // device until the token is registered on a later launch.
      AppLog.error('ApiClient.registerFcmToken', e, s);
    }
  }

  String resolveFileUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    // Anchored to the end on purpose: replaceFirst('/api', '') matched the
    // *first* occurrence anywhere in the string, which silently mangled the
    // host itself whenever the API domain contained "api" right after the
    // scheme — e.g. https://api.shadapp.com/api (a completely realistic
    // production value) lost the "/" after "https:" instead of the trailing
    // "/api", producing "https:/.shadapp.com/api/...".
    final base = RegExp(r'/api/?$').hasMatch(baseUrl)
        ? baseUrl.replaceFirst(RegExp(r'/api/?$'), '')
        : baseUrl;
    String cleaned = url;
    if (cleaned.startsWith('/')) cleaned = cleaned.substring(1);
    if (cleaned.startsWith('storage/')) {
      cleaned = cleaned.replaceFirst('storage/', 'files/');
      return '$base/$cleaned';
    }
    return '$base/files/$cleaned';
  }

  Future<void> setBaseUrl(String url) async {
    baseUrl = url;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('base_url', url);
  }

  Future<Map<String, String>> _headers({bool multipart = false}) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };
    if (!multipart) headers['Content-Type'] = 'application/json';
    final token = await getToken();
    if (token != null) headers['Authorization'] = 'Bearer $token';
    // Lets broadcast(...)->toOthers() on the backend exclude this exact
    // connection. Without it, sending a chat message delivers it back to the
    // sender's own socket on top of whatever the HTTP response already
    // showed — a visible duplicate. Harmless to send on every request; only
    // endpoints that actually broadcast read it.
    final socketId = ReverbService().socketId;
    if (socketId != null) headers['X-Socket-Id'] = socketId;
    return headers;
  }

  /// Runs an HTTP call and converts "never got a response" failures into a
  /// [ConnectionException]. Without this, a stopped server, a DNS/CORS problem
  /// or a timeout surfaces as a raw SocketException/ClientException that
  /// callers can't distinguish from an application-level error.
  Future<Map<String, dynamic>> _send(Future<http.Response> Function() call) async {
    http.Response response;
    try {
      response = await call().timeout(_timeout);
    } on SocketException catch (e) {
      throw ConnectionException(e.message.isNotEmpty ? e.message : 'Network unreachable');
    } on http.ClientException catch (e) {
      throw ConnectionException(e.message);
    } on TimeoutException {
      throw ConnectionException('Request timed out after ${_timeout.inSeconds}s');
    }
    return _handle(response);
  }

  Future<Map<String, dynamic>> get(String path) async {
    final headers = await _headers();
    return _send(() => _httpClient.get(Uri.parse('$baseUrl$path'), headers: headers));
  }

  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic>? body]) async {
    final headers = await _headers();
    return _send(() => _httpClient.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ));
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final headers = await _headers();
    return _send(() => _httpClient.put(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: jsonEncode(body),
    ));
  }

  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic>? body]) async {
    final headers = await _headers();
    return _send(() => _httpClient.patch(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    ));
  }

  Future<Map<String, dynamic>> delete(String path) async {
    final headers = await _headers();
    return _send(() => _httpClient.delete(Uri.parse('$baseUrl$path'), headers: headers));
  }

  Future<Map<String, dynamic>> multipartPut(String path, Map<String, dynamic> fields,
      {List<File>? multipleFiles, String multipleFileField = 'files[]',
       List<Uint8List>? multipleBytes, List<String>? multipleBytesNames}) async {
    final request = http.MultipartRequest('PUT', Uri.parse('$baseUrl$path'));
    request.headers.addAll(await _headers(multipart: true));
    fields.forEach((key, value) => request.fields[key] = value.toString());
    if (multipleFiles != null) {
      for (final f in multipleFiles) {
        request.files.add(await http.MultipartFile.fromPath(multipleFileField, f.path));
      }
    } else if (multipleBytes != null) {
      for (int i = 0; i < multipleBytes.length; i++) {
        final fn = (multipleBytesNames != null && i < multipleBytesNames.length) ? multipleBytesNames[i] : null;
        request.files.add(http.MultipartFile.fromBytes(multipleFileField, multipleBytes[i], filename: fn));
      }
    }
    final streamed = await _httpClient.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> multipartPost(String path, Map<String, dynamic> fields,
      {File? file, Uint8List? bytes, String? filename, String fileField = 'file',
       List<File>? multipleFiles, String multipleFileField = 'files[]',
       List<Uint8List>? multipleBytes, List<String>? multipleBytesNames}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll(await _headers(multipart: true));
    fields.forEach((key, value) => request.fields[key] = value.toString());
    if (multipleFiles != null) {
      for (final f in multipleFiles) {
        if (kIsWeb) {
          throw UnsupportedError('multipleFiles not supported on web; use multipleBytes');
        }
        request.files.add(await http.MultipartFile.fromPath(multipleFileField, f.path));
      }
    } else if (multipleBytes != null) {
      for (int i = 0; i < multipleBytes.length; i++) {
        final fn = (multipleBytesNames != null && i < multipleBytesNames.length) ? multipleBytesNames[i] : null;
        request.files.add(http.MultipartFile.fromBytes(multipleFileField, multipleBytes[i], filename: fn));
      }
    } else if (bytes != null) {
      request.files.add(http.MultipartFile.fromBytes(fileField, bytes, filename: filename));
    } else if (file != null) {
      if (kIsWeb) {
        throw UnsupportedError('Use bytes parameter instead of File on web');
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await _httpClient.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> multipartPostMultiple(String path, Map<String, dynamic> fields, {required List<File> files, String fileField = 'files[]'}) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    request.headers.addAll(await _headers(multipart: true));
    fields.forEach((key, value) => request.fields[key] = value.toString());
    for (final file in files) {
      if (kIsWeb) {
        throw UnsupportedError('multipartPostMultiple does not support web yet');
      }
      request.files.add(await http.MultipartFile.fromPath(fileField, file.path));
    }
    final streamed = await _httpClient.send(request).timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    return _handle(response);
  }

  Future<Map<String, dynamic>> _handle(http.Response response) async {
    // A non-JSON body (an HTML error page from the web server, a proxy notice,
    // an empty 502) would otherwise blow up in jsonDecode and surface as an
    // unrelated error far from its cause.
    Map<String, dynamic> data;
    try {
      data = response.body.isNotEmpty
          ? jsonDecode(response.body) as Map<String, dynamic>
          : <String, dynamic>{};
    } catch (_) {
      data = <String, dynamic>{};
    }

    if (response.statusCode == 401) {
      await clearToken();
      throw AuthException(data['message'] ?? l10n?.sessionExpired ?? 'Session Expired');
    }
    if (response.statusCode == 422) {
      final errors = data['errors'] as Map<String, dynamic>?;
      final firstError = errors?.values.firstOrNull;
      final msg = firstError is List ? firstError.first.toString() : (data['message'] ?? l10n?.invalidData ?? 'Invalid data');
      throw ValidationException(msg);
    }
    // 429 is its own case: the credentials may be perfectly correct, the
    // caller just tripped Laravel's `throttle` middleware. Reporting it as a
    // generic server error (or worse, as bad credentials) sends people off
    // re-checking a password that was never the problem.
    if (response.statusCode == 429) {
      throw RateLimitException(data['message'] ?? 'Too many requests');
    }
    if (response.statusCode >= 400) {
      throw ServerException(data['message'] ?? l10n?.serverError ?? 'Server Error');
    }
    return data;
  }
}

List<dynamic> safeList(dynamic value) {
  if (value is List) return value;
  if (value is Map) return (value['data'] as List<dynamic>?) ?? [];
  return [];
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class ValidationException implements Exception {
  final String message;
  ValidationException(this.message);
  @override
  String toString() => message;
}

class ServerException implements Exception {
  final String message;
  ServerException(this.message);
  @override
  String toString() => message;
}

/// HTTP 429 — Laravel's `throttle` middleware rejected the request. Distinct
/// from a credential problem, which is what it used to be reported as.
class RateLimitException implements Exception {
  final String message;
  RateLimitException(this.message);
  @override
  String toString() => message;
}

/// The request never produced an HTTP response at all: server unreachable,
/// DNS/CORS failure, or timeout. Previously these fell through to a generic
/// catch that displayed "invalid email or password", which pointed users at
/// entirely the wrong problem.
class ConnectionException implements Exception {
  final String message;
  ConnectionException(this.message);
  @override
  String toString() => message;
}
