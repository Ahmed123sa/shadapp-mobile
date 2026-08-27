import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/error_state.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('shows the translated heading and the given message', (tester) async {
    await pumpWithLocalizations(tester, const ErrorState(message: 'Connection refused'));
    expect(find.text('Could not load data'), findsOneWidget);
    expect(find.text('Connection refused'), findsOneWidget);
  });

  testWidgets('hides the retry button when onRetry is not given', (tester) async {
    await pumpWithLocalizations(tester, const ErrorState(message: 'Connection refused'));
    expect(find.byType(OutlinedButton), findsNothing);
  });

  testWidgets('tapping Retry calls onRetry', (tester) async {
    var retried = false;
    await pumpWithLocalizations(
      tester,
      ErrorState(message: 'Connection refused', onRetry: () => retried = true),
    );

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    expect(retried, isTrue);
  });
}
