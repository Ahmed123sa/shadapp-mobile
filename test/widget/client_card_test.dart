import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/client_card.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the company name and contact person', (tester) async {
    await pumpWithLocalizations(
      tester,
      const ClientCard(companyName: 'Acme Corp', contactPerson: 'Sara Ahmed'),
    );
    expect(find.text('Acme Corp'), findsOneWidget);
    expect(find.text('Sara Ahmed'), findsOneWidget);
  });

  testWidgets('shows both a workspace and a contract status badge when given', (tester) async {
    await pumpWithLocalizations(
      tester,
      const ClientCard(
        companyName: 'Acme Corp',
        contactPerson: 'Sara Ahmed',
        workspaceStatus: 'active',
        contractStatus: 'sent',
      ),
    );
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('tapping the card calls onTap', (tester) async {
    var tapped = false;
    await pumpWithLocalizations(
      tester,
      ClientCard(companyName: 'Acme Corp', contactPerson: 'Sara Ahmed', onTap: () => tapped = true),
    );

    await tester.tap(find.byType(InkWell));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('uses the first character of the company name as the avatar initial', (tester) async {
    await pumpWithLocalizations(
      tester,
      const ClientCard(companyName: 'Zed Company', contactPerson: 'Someone'),
    );
    expect(find.text('Z'), findsOneWidget);
  });
}
