import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/status_badge.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the translated label for a known status', (tester) async {
    await pumpWithLocalizations(tester, const StatusBadge(status: 'client_approved'));
    expect(find.text('Client Approved'), findsOneWidget);
  });

  testWidgets('falls back to the raw status string for an unrecognized value', (tester) async {
    await pumpWithLocalizations(tester, const StatusBadge(status: 'totally_made_up'));
    expect(find.text('totally_made_up'), findsOneWidget);
  });

  testWidgets('renders in Arabic when the locale is ar', (tester) async {
    await pumpWithLocalizations(tester, const StatusBadge(status: 'draft'), locale: const Locale('ar'));
    expect(find.text('مسودة'), findsOneWidget);
  });
}
