import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/signature_pad_screen.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SignaturePadScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders signature pad screen with draw area and buttons', (tester) async {
    await pumpScreen(tester);

    expect(find.byType(SignaturePadScreen), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.widgetWithText(ElevatedButton, 'Save Signature'), findsOneWidget);
  });

  testWidgets('drawing a stroke and clearing resets the strokes', (tester) async {
    await pumpScreen(tester);

    final gestureFinder = find.byType(GestureDetector).last;
    await tester.drag(gestureFinder, const Offset(100, 50));
    await tester.pumpAndSettle();

    final clearBtn = find.text('Clear');
    expect(clearBtn, findsOneWidget);
    await tester.tap(clearBtn);
    await tester.pumpAndSettle();

    // After clearing, Save Signature button is disabled
    final saveButton = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Save Signature'));
    expect(saveButton.onPressed, isNull);
  });
}
