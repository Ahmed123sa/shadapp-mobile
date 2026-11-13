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
  // plans/notifications-badges-toasts-plan.md ن6 — every push already
  // carries a `notification` block (FirebaseService::sendMessage on the
  // backend always sets one), which Android's FCM SDK auto-displays in the
  // system tray whenever the app isn't in the foreground — this handler
  // used to ALSO call _showLocalNotification() for the same message,
  // stacking two entries in the tray for one push. Tapping the
  // system-displayed one is already routed via
  // FirebaseMessaging.onMessageOpenedApp / getInitialMessage() (see init()
  // below), so nothing is lost by not showing a local one here too.
  await Firebase.initializeApp();
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
  factory NotificationService.forTesting({required ApiClient api}) =>
      NotificationService._(api: api);

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

  /// Language of this device's push texts ('ar'/'en'), sent with the token so
  /// the server pushes in it. Set from the app language (main.dart).
  static String localeCode = 'en';

  /// The instance that owns the cached token, so a language change can
  /// re-register it from anywhere.
  static NotificationService? instance;
  bool _initialized = false;
  StreamSubscription? _messageSubscription;

  void Function(RemoteMessage)? onMessageOpenedApp;
  void Function(Map<String, String>)? onLocalNotificationTapped;

  /// How long the deferred messaging work waits on the platform before giving
  /// up for this launch. Both the APNs device token and `getInitialMessage()`
  /// normally settle in well under a second; if they haven't after this long,
  /// they are not going to.
  static const _messagingTimeout = Duration(seconds: 10);

  /// Sets up notifications. **Never throws, never blocks on the network.**
  ///
  /// This is awaited by `main()` before `runApp()`, so anything that escapes
  /// here stops the app from ever drawing a frame. That is not hypothetical:
  /// the unguarded `getToken()` this used to start with threw
  /// `[firebase_messaging/apns-token-not-set]` on any build that couldn't
  /// register with APNs, which took `runApp()` down with it and launched the
  /// app to a permanently blank screen — the App Store rejected 1.0 (3) for
  /// exactly that. Push is optional; being able to open the app is not.
  Future<void> init() async {
    if (_initialized) return;
    instance = this;

    await _initLocalNotifications();
    await _requestPermission();

    // No token work here. Fetching the FCM token used to happen inline at
    // this point too — an up-to-10s APNs poll and then an awaited getToken()
    // — on top of the deferred _acquireFcmToken() below. That held the first
    // frame for the full wait on any iOS build without APNs (the simulator, a
    // profile missing aps-environment) and registered the token twice.
    // _acquireFcmToken() is now the only path: bounded and off the startup
    // path. Until it lands, registerCurrentToken() is a silent no-op — which
    // is fine either way round: a token that lands before main.dart sets
    // localeCode gets re-sent by main.dart's own registerCurrentToken() call,
    // and one that lands after is registered with the right locale (and, if
    // the user logged in meanwhile, the right session) to begin with.

    // Wired before the token work below: these are local stream hookups that
    // can't fail, and they need to be live whether or not this device ever
    // gets a push token.
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    _messageSubscription = FirebaseMessaging.onMessage.listen(_showLocalNotification);

    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      onMessageOpenedApp?.call(message);
    });

    _firebaseMessaging.onTokenRefresh.listen((token) {
      _fcmToken = token;
      _registerToken(token);
    });

    _initialized = true;

    // Deliberately not awaited. Both of these depend on messaging state that
    // a device may never reach; the first screen depends on neither, and must
    // not wait for them.
    unawaited(_handleInitialMessage());
    unawaited(_acquireFcmToken());
  }

  /// Delivers the notification that cold-started the app, if there was one.
  ///
  /// Kept off the startup path and bounded, because on iOS
  /// `getInitialMessage()` can simply never complete — it waits on messaging
  /// state that a device without APNs registration never reaches. Awaiting it
  /// inline was the second of the two ways this method used to stop
  /// `runApp()` from ever running. Routing a tapped notification a moment
  /// late costs nothing: `main` queues it if the router isn't up yet and
  /// replays it once it is.
  Future<void> _handleInitialMessage() async {
    try {
      final initialMessage =
          await _firebaseMessaging.getInitialMessage().timeout(_messagingTimeout);
      if (initialMessage != null) {
        onMessageOpenedApp?.call(initialMessage);
      }
    } on TimeoutException {
      // Expected whenever push isn't wired up on this device. Not a
      // Crashlytics non-fatal — see AppLog.info's doc comment.
      AppLog.info(
        'NotificationService',
        'getInitialMessage() did not settle in $_messagingTimeout; '
            'no cold-start notification to route.',
      );
    } catch (e, s) {
      AppLog.error('NotificationService._handleInitialMessage', e, s);
    }
  }

  /// Registers this device for push, out of band and failure-tolerant.
  ///
  /// On iOS `getToken()` throws until APNs has handed the app a device token,
  /// and on plenty of perfectly good builds that never happens: the simulator
  /// never completes APNs registration, and neither does a build whose
  /// provisioning profile is missing the `aps-environment` entitlement. So
  /// the APNs token is waited for explicitly, with a bound, and everything is
  /// caught. The worst case is an app that runs without push.
  Future<void> _acquireFcmToken() async {
    try {
      if (!kIsWeb && Platform.isIOS && !await _waitForApnsToken()) {
        // Expected on the simulator and on any build without the push
        // entitlement — AppLog.info rather than error, so it stays out of
        // Crashlytics instead of firing a non-fatal on every single launch.
        AppLog.info(
          'NotificationService',
          'No APNs token after $_messagingTimeout — skipping push registration for this launch.',
        );
        return;
      }

      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        _fcmToken = token;
        await _registerToken(token);
      }
    } catch (e, s) {
      AppLog.error('NotificationService._acquireFcmToken', e, s);
    }
  }

  /// Polls for the iOS APNs token until it shows up or [_messagingTimeout]
  /// elapses. Returns whether one arrived.
  Future<bool> _waitForApnsToken() async {
    final deadline = DateTime.now().add(_messagingTimeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await _firebaseMessaging.getAPNSToken() != null) return true;
      } catch (e, s) {
        AppLog.error('NotificationService._waitForApnsToken', e, s);
        return false;
      }
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }
    return false;
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
      // Startup (the deferred FCM fetch and main.dart's locale call) runs
      // whether or not anyone is logged in. Without a session the endpoint
      // can only answer 401, which ApiClient treats as an expired session:
      // it wipes stored auth and bounces to /login, and a 401 landing just
      // after a login could wipe the brand-new token. The FCM token stays
      // cached; AuthProvider re-sends it via registerCurrentToken() on login.
      if (await _api.getToken() == null) return;
      await _api.post('/notifications/register-token', {
        'token': token,
        'device_type': deviceType,
        'locale': localeCode,
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
