import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/stages_stepper.dart';
import '../helpers/pump_app.dart';

void main() {
  // None of these use Icons.check as their own icon, so any Icons.check
  // found in the tree below unambiguously came from the isCompleted
  // override in _buildStep, not from a step's own configured icon.
  const steps = [
    StageStep(status: 'draft', label: 'Draft', icon: Icons.edit),
    StageStep(status: 'sent', label: 'Sent', icon: Icons.send),
    StageStep(status: 'completed', label: 'Completed', icon: Icons.flag),
  ];

  testWidgets('renders a label for every step', (tester) async {
    await pumpWithLocalizations(tester, const StagesStepper(currentStatus: 'sent', steps: steps));
    expect(find.text('Draft'), findsOneWidget);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
  });

  testWidgets('marks steps before the current one with a checkmark', (tester) async {
    await pumpWithLocalizations(tester, const StagesStepper(currentStatus: 'completed', steps: steps));
    // draft and sent are before "completed" => 2 checkmarks. The current
    // step itself (index 2) is active, not completed, so it shows its own
    // icon (flag) rather than a checkmark.
    expect(find.byIcon(Icons.check), findsNWidgets(2));
    expect(find.byIcon(Icons.flag), findsOneWidget);
  });

  testWidgets('falls back to the first step when currentStatus is unrecognized', (tester) async {
    await pumpWithLocalizations(tester, const StagesStepper(currentStatus: 'not_a_status', steps: steps));
    // activeIndex = -1 => treated as index 0 => nothing marked completed.
    expect(find.byIcon(Icons.check), findsNothing);
  });
}
