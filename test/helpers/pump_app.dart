import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

/// Every widget under test/widget reads strings via AppLocalizations.of
/// (context)! — without the same delegates/supportedLocales main.dart wires
/// up, that call returns null and the `!` throws before the widget ever
/// renders. Mirrors main.dart's MaterialApp setup, minus routing (these are
/// isolated widget tests, not navigation tests).
Future<void> pumpWithLocalizations(
  WidgetTester tester,
  Widget widget, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: widget),
    ),
  );
  // A plain pump, not pumpAndSettle: some of these widgets host a
  // continuously-animating CircularProgressIndicator, which never
  // "settles" and would make pumpAndSettle time out. One extra frame is
  // enough to let the localizations Future resolve.
  await tester.pump();
}
