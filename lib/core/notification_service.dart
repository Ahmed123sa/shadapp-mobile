import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'api_client.dart';
import 'app_log.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  final notifService = NotificationService();
  await notifService._initLocalNotifications();
  await notifService._showLocalNotification(message);
}

class NotificationService {
  AppLocalizations? l10n;

  static final NotificationService _instance = NotificationService._();
  NotificationService._({ApiClient? api}) : _api = api ?? ApiClient();

  factory NotificationService() => _instance;

  /// A separate instance from the app-wide singleton above, with an injected
  /// [ApiClient] — for tests that need to exercise [registerCurrentToken]'s
  /// network call without touching the real `ApiClient()` singleton (which
  /// [NotificationService()] always uses) or the real Firebase plugins (never
  /// touched here since [init] is never called on this instance).
  @visibleForTesting
  factory NotificationService.forTesting({required ApiClient api}) => NotificationService._(api: api);

  // `late` matters here, not just style: an eager `final _firebaseMessaging =
  // FirebaseMessaging.instance;` ran the instant ANY NotificationService was
  // constructed — including the app-wide singleton's very first reference
  // and every NotificationService.forTesting() instance — and
  // FirebaseMessaging.instance throws outside a real Firebase.initializeApp()
  // context, which plain `flutter test` never provides. That made
  // registerCurrentToken() (which never touches Firebase messaging, only
  // _api and _fcmToken) crash on construction anyway, and broke every test
  // that builds an AuthProvider — not just the ones that call
  // login()/logout(). `late` defers the actual FirebaseMessaging.instance
  // call to init()'s first real use of it, which nothing in
  // registerCurrentToken()'s path ever triggers.
  late final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  final ApiClient _api;

  String? _fcmToken;
  bool _initialized = false;
  StreamSubscription? _messageSubscription;

  void Function(RemoteMessage)? onMessageOpenedApp;
  void Function(Map<String, String>)? onLocalNotificationTapped;

  Future<void> init() async {
    if (_initialized) return;

    await _initLocalNotifications();
    await _requestPermission();

    try {
      // On iOS, FCM's getToken() throws
      // firebase_messaging/apns-token-not-set if it's called before iOS has
      // handed the app its APNs device token, which can take a moment right
      // after launch. Wait for it first so getToken() doesn't throw here.
      if (!kIsWeb && Platform.isIOS) {
        String? apnsToken = await _firebaseMessaging.getAPNSToken();
        var attempts = 0;
        while (apnsToken == null && attempts < 10) {
          await Future.delayed(const Duration(seconds: 1));
          apnsToken = await _firebaseMessaging.getAPNSToken();
          attempts++;
        }
      }

      _fcmToken = await _firebaseMessaging.getToken();
      if (_fcmToken != null) {
        _registerToken(_fcmToken!);
      }
    } catch (e, s) {
      // Push notifications are a nice-to-have, not something app startup
      // should ever crash over — any failure here (this case or otherwise)
      // is logged and swallowed instead of propagating.
      AppLog.error('NotificationService.init.getToken', e, s);
    }

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerToken(token);
    });

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _messageSubscription = FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpenedApp?.call(message);
    });

    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      onMessageOpenedApp?.call(initialMessage);
    }

    _initialized = true;
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _localNotifications.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: (response) {
        final payloadStr = response.payload;
        if (payloadStr != null) {
          try {
            final data = Map<String, String>.from(jsonDecode(payloadStr));
            onLocalNotificationTapped?.call(data);
          } catch (e, s) {
            // A malformed payload means the tap can't be routed anywhere.
            // Worth knowing about: it means the sender and this app disagree
            // about the notification data shape.
            AppLog.error('NotificationService.onNotificationTapped', e, s);
          }
        }
      },
    );
  }

  Future<void> _requestPermission() async {
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    final data = message.data;

    final title = notification?.title ?? data['title'] as String? ?? 'ShadApp';
    final body = notification?.body ?? data['body'] as String?;
    if (body == null) return;

    final payload = data.isNotEmpty ? jsonEncode(data) : null;

    final id = DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF;

    await _localNotifications.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'shadapp_channel_v2',
          l10n?.notificationChannelName ?? 'ShadApp Notifications',
          channelDescription: l10n?.notificationChannelDescription ?? 'App notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: payload,
    );
  }

  Future<void> _registerToken(String token) async {
    final deviceType = _getDeviceType();
    try {
      await _api.post('/notifications/register-token', {
        'token': token,
        'device_type': deviceType,
      });
    } catch (e, s) {
      AppLog.error('NotificationService._registerToken', e, s);
    }
  }

  String _getDeviceType() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  /// Re-sends this device's FCM token to the backend. [init] registers it
  /// once at app startup (see main.dart), which runs regardless of whether
  /// anyone is logged in yet — for a user who isn't, that first attempt hits
  /// `/notifications/register-token` unauthenticated, gets a 401, and is
  /// silently swallowed by [_registerToken]'s own catch. Nothing retried it
  /// afterwards, so a freshly logged-in user got no push notifications until
  /// the app was fully closed and relaunched (plans/notifications-badges-
  /// toasts-plan.md, ن1). AuthProvider calls this right after a successful
  /// login/authenticate so the token gets attached to the now-authenticated
  /// session immediately.
  ///
  /// [token] is optional so tests can exercise the POST without needing a
  /// real cached [_fcmToken] (which only [init] — never called in tests —
  /// ever sets). Production callers omit it and the cached token is used; if
  /// there isn't one yet (permission still pending, Firebase still
  /// initializing), this is a silent no-op rather than something worth
  /// blocking login on.
  Future<void> registerCurrentToken({String? token}) async {
    final t = token ?? _fcmToken;
    if (t != null) await _registerToken(t);
  }

  String? get fcmToken => _fcmToken;

  /// Test-only seam so a [forTesting] instance can simulate having already
  /// obtained an FCM token, the way a real instance's [init] would after
  /// talking to Firebase — which tests never exercise. Lets a test verify
  /// [registerCurrentToken]'s no-arg (cached-token) path, the one production
  /// callers (AuthProvider) actually use, instead of only its explicit
  /// [token] override.
  @visibleForTesting
  set fcmTokenForTesting(String? value) => _fcmToken = value;

  void dispose() {
    _messageSubscription?.cancel();
  }
}
