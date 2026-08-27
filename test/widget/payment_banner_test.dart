import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/payment_banner.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('a payment with no due_date is treated as a direct request', (tester) async {
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {'amount': '500', 'currency': 'SAR'}),
    );
    expect(find.byIcon(Icons.request_quote), findsOneWidget);
  });

  testWidgets('an overdue payment shows the warning icon and installment/date subtitle', (tester) async {
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {
        'amount': '500',
        'currency': 'SAR',
        'due_date': '2020-01-01',
        'status': 'overdue',
        'installment_label': 'Installment 2 of 4',
      }),
    );
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
    expect(find.text('Installment 2 of 4'), findsOneWidget);
  });

  testWidgets('a paid payment shows the success icon', (tester) async {
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {
        'amount': '500',
        'currency': 'SAR',
        'due_date': '2026-01-01',
        'status': 'paid',
      }),
    );
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('a pending payment shows the hourglass icon', (tester) async {
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {
        'amount': '500',
        'currency': 'SAR',
        'due_date': '2026-01-01',
        'status': 'pending',
      }),
    );
    expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
  });

  testWidgets('tapping the banner calls onTap', (tester) async {
    var tapped = false;
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {'amount': '500', 'currency': 'SAR'}, onTap: () => tapped = true),
    );

    await tester.tap(find.byType(GestureDetector));
    await tester.pump();
    expect(tapped, isTrue);
  });

  testWidgets('a direct request never shows the chevron affordance', (tester) async {
    await pumpWithLocalizations(
      tester,
      PaymentBanner(payment: {'amount': '500', 'currency': 'SAR'}),
    );
    expect(find.byIcon(Icons.chevron_left), findsNothing);
  });
}
