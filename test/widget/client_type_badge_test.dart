import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/client_type_badge.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('renders nothing for a null clientType', (tester) async {
    await pumpWithLocalizations(tester, const ClientTypeBadge());
    expect(find.byIcon(Icons.business), findsNothing);
    expect(find.byIcon(Icons.person), findsNothing);
    expect(find.text('Company'), findsNothing);
    expect(find.text('Individual'), findsNothing);
  });

  testWidgets('renders nothing for an empty clientType', (tester) async {
    await pumpWithLocalizations(tester, const ClientTypeBadge(clientType: ''));
    expect(find.text('Company'), findsNothing);
    expect(find.text('Individual'), findsNothing);
  });

  testWidgets('shows "Company" with a business icon', (tester) async {
    await pumpWithLocalizations(tester, const ClientTypeBadge(clientType: 'business'));
    expect(find.text('Company'), findsOneWidget);
    expect(find.byIcon(Icons.business), findsOneWidget);
  });

  testWidgets('shows "Individual" with a person icon for any other value', (tester) async {
    await pumpWithLocalizations(tester, const ClientTypeBadge(clientType: 'individual'));
    expect(find.text('Individual'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
