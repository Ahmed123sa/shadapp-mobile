import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show FlutterError, kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/theme.dart';
import 'core/api_client.dart';
import 'core/router.dart';
import 'core/locale_provider.dart';
import 'core/notification_routing.dart';
import 'core/notification_service.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: 'assets/env.txt');

  // Fail loudly instead of silently shipping a release build that talks to
  // localhost. assets/env.txt is a local dev file (gitignored) — a real
  // deployment must bundle a production env.txt with a real API_BASE_URL
  // before running `flutter build`. See assets/env.txt.example.
  if (kReleaseMode) {
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

  Map<String, String>? pendingNotifData;
  GoRouter? router;

  if (!kIsWeb) {
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
    await FirebaseCrashlytics.instance
        .setCrashlyticsCollectionEnabled(kReleaseMode);

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
  }

  final api = ApiClient();
  await api.init();
  final token = await api.getToken();
  final loggedIn = token != null;
  String initialLocation;
  if (!loggedIn) {
    initialLocation = '/login';
  } else {
    final role = await api.getRole();
    initialLocation = (role == 'client' || role == 'sub_user') ? '/dashboard' : '/am/dashboard';
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
  await localeProvider.init();
  runApp(
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
    ChangeNotifierProvider.value(
      value: localeProvider,
      child: ShadApp(router: router, localeProvider: localeProvider),
    ),
  );
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
        title: 'ShadApp',
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
