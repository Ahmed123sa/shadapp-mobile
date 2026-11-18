// The client's "where do I transfer" picker: the company's methods for his
// account type, their details with a copy button, and the wallet fee + total.
// With no methods configured (or a failed load) the old fixed chips stay.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/features/payments/payment_method_picker.dart';
import 'package:shadapp_client/generated/app_localizations.dart';

void main() {
  final wallet = <String, dynamic>{
    'id': 1,
    'kind': 'wallet',
    'label': 'Vodafone Cash',
    'details': {'phone': '01012345678', 'account_name': 'Shad Co', 'instructions': 'Send then upload the receipt'},
    'fee_percent': 1,
  };
  final bank = <String, dynamic>{
    'id': 2,
    'kind': 'bank_account',
    'label': 'CIB',
    'details': {'bank_name': 'CIB', 'iban': 'EG123'},
    'fee_percent': 0,
  };

  Future<void> pump(
    WidgetTester tester, {
    required PaymentMethodChoice choice,
    required Future<List<Map<String, dynamic>>> Function(String) fetch,
    String currency = 'EGP',
    TextEditingController? amount,
  }) async {
    final ctrl = amount ?? TextEditingController(text: '2000');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: PaymentMethodPicker(
            choice: choice,
            currency: currency,
            fetch: fetch,
            amount: () => double.tryParse(ctrl.text),
            amountListenable: ctrl,
            fallback: const Text('legacy chips', key: ValueKey('legacy')),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the configured methods and requires a pick', (tester) async {
    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => [wallet, bank]);

    expect(find.text('Vodafone Cash'), findsOneWidget);
    expect(find.text('CIB'), findsOneWidget);
    expect(find.byKey(const ValueKey('legacy')), findsNothing);
    expect(choice.required, isTrue);
    expect(choice.methodId, isNull);
    expect(find.byKey(const ValueKey('pay-method-details')), findsNothing);
  });

  testWidgets('picking a wallet shows its details, the 1% fee and the total to transfer', (tester) async {
    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => [wallet, bank]);

    await tester.tap(find.byKey(const ValueKey('pay-method-id-1')));
    await tester.pumpAndSettle();

    expect(choice.methodId, 1);
    expect(find.text('01012345678'), findsOneWidget);
    expect(find.text('Shad Co'), findsOneWidget);
    expect(find.text('Send then upload the receipt'), findsOneWidget);
    expect(find.text('Fee (1%)'), findsOneWidget);
    expect(find.text('+ 20 EGP'), findsOneWidget);
    expect(find.text('2,020 EGP'), findsOneWidget);
  });

  testWidgets('the total follows the amount being typed', (tester) async {
    final choice = PaymentMethodChoice();
    final amount = TextEditingController(text: '2000');
    await pump(tester, choice: choice, amount: amount, fetch: (_) async => [wallet]);
    await tester.tap(find.byKey(const ValueKey('pay-method-id-1')));
    await tester.pumpAndSettle();

    amount.text = '500';
    await tester.pumpAndSettle();

    expect(find.text('+ 5 EGP'), findsOneWidget);
    expect(find.text('505 EGP'), findsOneWidget);
  });

  testWidgets('a method without a fee shows no fee or total block', (tester) async {
    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => [wallet, bank]);

    await tester.tap(find.byKey(const ValueKey('pay-method-id-2')));
    await tester.pumpAndSettle();

    expect(find.text('EG123'), findsOneWidget);
    expect(find.byKey(const ValueKey('pay-method-fee')), findsNothing);
  });

  testWidgets('copy puts the value on the clipboard', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => [wallet]);
    await tester.tap(find.byKey(const ValueKey('pay-method-id-1')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pm-copy-phone')));
    await tester.pump();

    expect(copied, ['01012345678']);
    // The "copied" tick clears on its own.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('no configured methods keeps the old chips and requires nothing', (tester) async {
    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => []);

    expect(find.byKey(const ValueKey('legacy')), findsOneWidget);
    expect(choice.required, isFalse);
  });

  testWidgets('a failed load keeps the old chips', (tester) async {
    final choice = PaymentMethodChoice();
    await pump(tester, choice: choice, fetch: (_) async => throw Exception('offline'));

    expect(find.byKey(const ValueKey('legacy')), findsOneWidget);
    expect(choice.required, isFalse);
  });

  testWidgets('a currency change reloads and drops a pick that is no longer offered', (tester) async {
    final choice = PaymentMethodChoice();
    final calls = <String>[];
    Future<List<Map<String, dynamic>>> fetch(String cur) async {
      calls.add(cur);
      return cur == 'EGP' ? [wallet, bank] : [bank];
    }

    Widget host(String cur) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: PaymentMethodPicker(
                choice: choice,
                currency: cur,
                fetch: fetch,
                amount: () => 100,
                fallback: const SizedBox.shrink(),
              ),
            ),
          ),
        );

    await tester.pumpWidget(host('EGP'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pay-method-id-1')));
    await tester.pumpAndSettle();
    expect(choice.methodId, 1);

    await tester.pumpWidget(host('USD'));
    await tester.pumpAndSettle();

    expect(calls, ['EGP', 'USD']);
    expect(find.text('Vodafone Cash'), findsNothing);
    expect(choice.methodId, isNull);
  });
}
