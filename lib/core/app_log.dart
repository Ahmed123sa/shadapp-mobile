import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Central place for "this failed, but the app should carry on" reporting.
///
/// This codebase used to have ~40 bare `catch (_) {}` blocks. Carrying on was
/// usually the right call — a failed avatar fetch shouldn't take the screen
/// down — but swallowing the exception outright meant the only symptom was an
/// empty list or a stale header, with nothing anywhere to explain why. That
/// is the difference between "handled" and "hidden".
///
/// [error] keeps the don't-crash behaviour and adds the missing half: the
/// failure shows up in the console during development, and lands in
/// Crashlytics as a **non-fatal** in release, so a problem that only happens
/// on real users' devices is still visible.
class AppLog {
  const AppLog._();

  /// [context] should say where this came from and what was being attempted,
  /// e.g. `'chat_page._load'` — it becomes the grouping key in Crashlytics.
  static void error(String context, Object error, [StackTrace? stack]) {
    debugPrint('[$context] $error');

    // Crashlytics has no web implementation.
    if (kIsWeb) return;

    try {
      FirebaseCrashlytics.instance.recordError(
        error,
        stack,
        reason: context,
        fatal: false,
      );
    } catch (_) {
      // Firebase may not be initialised yet (unit tests, very early startup).
      // Error reporting must never itself become a source of crashes.
    }
  }
}
