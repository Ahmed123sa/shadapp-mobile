import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'app_log.dart';

/// Firebase Remote Config feature flags.
///
/// Flags are exposed as [ValueNotifier]s so widgets can read them without
/// touching Firebase directly — plain `flutter test` has no real
/// `Firebase.initializeApp()`, so tests just set `.value` themselves.
class RemoteConfigService {
  RemoteConfigService._();

  static const _kDeleteAccount = 'delete_account';
  static const _kRegisterScreen = 'register_screen';

  /// Shows the in-app "delete account" section when true. Stays false until
  /// [init] runs (web, tests) or when the key is false / missing in Remote Config.
  static final ValueNotifier<bool> deleteAccountEnabled = ValueNotifier(false);

  /// Shows the "register now" button on the login page when true. Stays false
  /// until [init] runs (web, tests) or when the key is false / missing.
  static final ValueNotifier<bool> registerEnabled = ValueNotifier(false);

  /// Call once after `Firebase.initializeApp()`. Never throws: if the fetch
  /// fails (offline, throttled) the last cached values, or the defaults
  /// below, are used.
  static Future<void> init() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: kReleaseMode ? const Duration(hours: 1) : Duration.zero,
      ));
      await rc.setDefaults(const {_kDeleteAccount: false, _kRegisterScreen: false});
      try {
        await rc.fetchAndActivate();
      } catch (e, st) {
        AppLog.error('remoteConfig.fetch', e, st);
      }
      _apply(rc);
      // Pick up changes published while the app is open.
      rc.onConfigUpdated.listen((_) async {
        await rc.activate();
        _apply(rc);
      }, onError: (Object e, StackTrace st) => AppLog.error('remoteConfig.listen', e, st));
    } catch (e, st) {
      AppLog.error('remoteConfig.init', e, st);
    }
  }

  static void _apply(FirebaseRemoteConfig rc) {
    deleteAccountEnabled.value = rc.getBool(_kDeleteAccount);
    registerEnabled.value = rc.getBool(_kRegisterScreen);
  }
}
