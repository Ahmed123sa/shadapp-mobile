import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/password_field.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('starts obscured and toggles to visible via the suffix icon', (tester) async {
    final controller = TextEditingController();
    await pumpWithLocalizations(tester, PasswordField(controller: controller));

    // TextFormField doesn't expose obscureText as a public getter of its
    // own (it just forwards the value into an internal TextField/
    // EditableText) — EditableText, the actual rendering leaf, does.
    var editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isTrue);

    await tester.tap(find.byIcon(Icons.visibility_off));
    await tester.pump();

    editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.obscureText, isFalse);
  });

  testWidgets('hides the strength meter until text is entered', (tester) async {
    final controller = TextEditingController();
    await pumpWithLocalizations(tester, PasswordField(controller: controller));
    expect(find.byType(LinearProgressIndicator), findsNothing);

    controller.text = 'abc';
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('reports Weak / Medium / Strong as requirements are met', (tester) async {
    final controller = TextEditingController();
    await pumpWithLocalizations(tester, PasswordField(controller: controller));

    controller.text = 'abc'; // short, no digit => 1/3
    await tester.pump();
    expect(find.text('Weak'), findsOneWidget);

    controller.text = 'abcdefgh'; // 8 letters, no digit => 2/3
    await tester.pump();
    expect(find.text('Medium'), findsOneWidget);

    controller.text = 'abcdefg1'; // 8 chars, letter, digit => 3/3
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
  });

  testWidgets('the requirement checklist reflects met/unmet state', (tester) async {
    final controller = TextEditingController();
    await pumpWithLocalizations(tester, PasswordField(controller: controller));

    controller.text = 'abcdefg1';
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
    expect(find.byIcon(Icons.cancel), findsNothing);
  });

  testWidgets('rejects an empty value when required', (tester) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await pumpWithLocalizations(
      tester,
      Form(key: formKey, child: PasswordField(controller: controller)),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('rejects a value missing a digit', (tester) async {
    final controller = TextEditingController(text: 'abcdefgh');
    final formKey = GlobalKey<FormState>();
    await pumpWithLocalizations(
      tester,
      Form(key: formKey, child: PasswordField(controller: controller)),
    );

    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('Must contain a number'), findsOneWidget);
  });

  testWidgets('accepts a value meeting all requirements', (tester) async {
    final controller = TextEditingController(text: 'abcdefg1');
    final formKey = GlobalKey<FormState>();
    await pumpWithLocalizations(
      tester,
      Form(key: formKey, child: PasswordField(controller: controller)),
    );

    expect(formKey.currentState!.validate(), isTrue);
  });
}
