import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/empty_state.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the icon and title', (tester) async {
    await pumpWithLocalizations(tester, const EmptyState(icon: Icons.inbox, title: 'No clients yet'));
    expect(find.byIcon(Icons.inbox), findsOneWidget);
    expect(find.text('No clients yet'), findsOneWidget);
  });

  testWidgets('shows the subtitle only when provided', (tester) async {
    await pumpWithLocalizations(
      tester,
      const EmptyState(icon: Icons.inbox, title: 'No clients yet', subtitle: 'Add your first one'),
    );
    expect(find.text('Add your first one'), findsOneWidget);
  });

  testWidgets('shows the action button only when both label and callback are given', (tester) async {
    await pumpWithLocalizations(tester, const EmptyState(icon: Icons.inbox, title: 'No clients yet'));
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('tapping the action button calls onAction', (tester) async {
    var tapped = false;
    await pumpWithLocalizations(
      tester,
      EmptyState(icon: Icons.inbox, title: 'No clients yet', actionLabel: 'Add client', onAction: () => tapped = true),
    );

    expect(find.text('Add client'), findsOneWidget);
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    expect(tapped, isTrue);
  });
}
