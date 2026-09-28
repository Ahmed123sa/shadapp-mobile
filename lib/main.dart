import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

import 'core/api_client.dart';
import 'core/app_log.dart';
import 'core/locale_provider.dart';
import 'core/notification_routing.dart';
import 'core/notification_service.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // `runApp` has to happen on every path out of here. Anything that escapes
  // startup leaves the engine with nothing to draw and no way to recover, so
  // the user just stares at a blank screen — which is how 1.0 (3) failed App
  // Store review: an unguarded FCM `getToken()` threw
  // `[firebase_messaging/apns-token-not-set]` on a review device that never
  // completed APNs registration, and `runApp` below was simply never reached.
  //
  // Everything optional (push, Crashlytics, saved session, saved locale) is
  // guarded individually inside `_bootstrap` so it degrades instead of
  // failing. This catch is the backstop for the genuinely unrecoverable —
  // chiefly a missing or bogus assets/env.txt, where there is no API to talk
  // to and an explanatory screen beats a blank one.
  try {
    runApp(await _bootstrap());
  } catch (error, stack) {
    AppLog.error('main.bootstrap', error, stack);
    runApp(StartupErrorApp(error: error));
  }
}

/// Builds the configured app. Returns the root widget rather than calling
/// `runApp` itself, so [main] keeps a single, unmissable call site for it.
Future<Widget> _bootstrap() async {
  // Deliberately unguarded: without an API base URL nothing in the app works,
  // so this is one of the few failures worth surfacing as an error screen.
  await dotenv.load(fileName: 'assets/env.txt');
  _assertReleaseConfig();

  Map<String, String>? pendingNotifData;
  GoRouter? router;

  if (!kIsWeb) {
    // Push and crash reporting are both nice-to-haves. Neither is worth
    // holding the first frame hostage, so the whole block is non-fatal.
    try {
      await Firebase.initializeApp();

      // Crashlytics has no web implementation, so this whole block stays
      // inside the !kIsWeb branch. Two handlers are needed and they catch
      // different things: FlutterError.onError covers errors thrown inside
      // the widget/framework layer, while PlatformDispatcher.onError covers
      // everything else that reaches the root zone (async gaps, isolate
      // errors). Wiring only the first one silently misses most real crashes.
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        FirebaseCrashlytics.instance.recordFlutterFatalError(details);
      };
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
      // Debug runs would otherwise fill the dashboard with crashes from code
      // that is actively being edited.
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(kReleaseMode);

      final notificationService = NotificationService();

      // Called when a notification is tapped (including cold start)
      void handleNotificationData(Map<String, String> data) {
        if (router != null) {
          _navigateFromNotification(data, router);
        } else {
          pendingNotifData = data;
        }
      }

      notificationService.onMessageOpenedApp = (message) {
        handleNotificationData(message.data.cast<String, String>());
      };

      notificationService.onLocalNotificationTapped = handleNotificationData;

      await notificationService.init();
    } catch (e, s) {
      AppLog.error('main.firebase', e, s);
    }
  }

  final api = ApiClient();
  // Restoring the saved session reads the keychain and shared preferences,
  // either of which can fail on a device. Falling back to the login screen is
  // a recoverable outcome; not starting at all is not.
  String initialLocation = '/login';
  try {
    await api.init();
    if (await api.getToken() != null) {
      final role = await api.getRole();
      initialLocation = (role == 'client' || role == 'sub_user') ? '/dashboard' : '/am/dashboard';
    }
  } catch (e, s) {
    AppLog.error('main.restoreSession', e, s);
  }

  router = createRouter(api, initialLocation: initialLocation);
  // Only fires on a server-forced 401 (see api_client.dart's onSessionExpired
  // doc comment) — a manual logout already navigates itself and never hits
  // this. Without it the app sat on the dead screen until force-closed; see
  // docs/mobile-review-2026-08.md, P0 #1.
  api.onSessionExpired = () => router!.go('/login');

  if (pendingNotifData != null) {
    await _navigateFromNotification(pendingNotifData!, router);
  }

  final localeProvider = LocaleProvider();
  try {
    await localeProvider.init();
  } catch (e, s) {
    // Leaves the provider on its default locale, which is a fine app.
    AppLog.error('main.localeProvider', e, s);
  }

  // Only LocaleProvider is actually read via the provider tree
  // (context.read<LocaleProvider>() in login_page.dart,
  // client_onboarding_screen.dart, client_dashboard_screen.dart, and
  // am_dashboard_page.dart, to toggle the app language). Every other
  // provider used to be registered here too via a MultiProvider, but no
  // screen ever read them from the tree — each screen builds its own
  // instance instead (see the `XProvider? xProvider` testability-seam
  // pattern used throughout `features/`). That MultiProvider was dead
  // weight: 17 duplicate provider instances in memory for nothing. See
  // docs/state-layer-migration-plan.md, بند ٣ for the decision record.
  return ChangeNotifierProvider.value(
    value: localeProvider,
    child: ShadApp(router: router, localeProvider: localeProvider),
  );
}

/// Refuses to run a release build that still points at a dev backend.
///
/// assets/env.txt is a local dev file (gitignored) — a real deployment must
/// bundle a production env.txt with a real API_BASE_URL before running
/// `flutter build`. See assets/env.txt.example.
void _assertReleaseConfig() {
  if (!kReleaseMode) return;

  final apiBaseUrl = dotenv.env['API_BASE_URL'] ?? '';
  final isLocalOrInsecure = apiBaseUrl.contains('localhost') ||
      apiBaseUrl.contains('127.0.0.1') ||
      apiBaseUrl.startsWith('http://');
  if (apiBaseUrl.isEmpty || isLocalOrInsecure) {
    throw StateError(
      'Refusing to run a release build with API_BASE_URL="$apiBaseUrl". '
      'Bundle a production assets/env.txt (HTTPS, real host) before building for release.',
    );
  }
}

/// Shown when [_bootstrap] can't produce an app at all.
///
/// Intentionally dependency-free: no l10n (the localisation delegates may
/// never have loaded), no theme, no router. Whatever went wrong, this has to
/// be able to draw.
class StartupErrorApp extends StatelessWidget {
  final Object error;

  const StartupErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 16),
                const Text(
                  "ShadApp couldn't start",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please close the app and open it again. If this keeps '
                  'happening, contact support.',
                  textAlign: TextAlign.center,
                ),
                // The underlying error is useful on a QA or TestFlight build
                // and noise to a real user, so it only shows outside release.
                if (!kReleaseMode) ...[
                  const SizedBox(height: 16),
                  Text('$error', textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Logic moved to core/notification_routing.dart (fcmTabIndex,
// notificationTarget) so it's unit-testable — this file itself has no
// widget/integration test, which is exactly how P0 #2's missing sub_user
// branch went unnoticed. See docs/mobile-review-2026-08.md, P0 #2.
Future<void> _navigateFromNotification(Map<String, String> data, GoRouter router) async {
  router.go(await notificationTarget(data));
}

class ShadApp extends StatefulWidget {
  final GoRouter router;
  final LocaleProvider localeProvider;

  const ShadApp({super.key, required this.router, required this.localeProvider});

  @override
  State<ShadApp> createState() => _ShadAppState();
}

class _ShadAppState extends State<ShadApp> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.localeProvider,
      builder: (context, _) => MaterialApp.router(
        title: 'Shad',
        debugShowCheckedModeBanner: false,
        theme: shadTheme(),
        locale: widget.localeProvider.locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('ar'),
          Locale('en'),
        ],
        routerConfig: widget.router,
      ),
    );
  }
}
