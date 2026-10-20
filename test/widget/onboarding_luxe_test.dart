import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/features/onboarding/client_onboarding_stages.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('waiting stage is one card plus a numbered "next steps" card', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => buildWaitingStage(
          context: ctx,
          icon: Icons.verified,
          iconColor: Colors.purple,
          title: 'Waiting',
          subtitle: 'Hang on',
          nextSteps: const ['Payment proof', 'Activate'],
          nextStepsTitle: 'Next steps',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('waiting-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('next-steps-card')), findsOneWidget);
    expect(find.text('Next steps'), findsOneWidget);
    expect(find.text('Payment proof'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('waiting stage without next steps hides that card', (tester) async {
    await pumpWithLocalizations(
      tester,
      Builder(
        builder: (ctx) => buildWaitingStage(
          context: ctx,
          icon: Icons.hourglass_top,
          iconColor: Colors.amber,
          title: 'Reviewing',
          subtitle: 'Soon',
        ),
      ),
    );
    expect(find.byKey(const ValueKey('next-steps-card')), findsNothing);
  });
}
