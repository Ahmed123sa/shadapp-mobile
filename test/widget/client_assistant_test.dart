import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/features/assistant/client_assistant_sheet.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  const enabled = '{"enabled":true,'
      '"assistant":{"name":{"ar":"مساعد شاد","en":"Shad assistant"},"welcome":{"ar":"أهلاً أحمد","en":"Hi Ahmed"}},'
      '"questions":['
      '{"id":2,"key":"balance","kind":"data","question":{"ar":"فاضل عليّا كام؟","en":"How much do I still owe?"},'
      '"answer":{"ar":"فاضل عليك 12,500.00 SAR","en":"You still owe 12,500.00 SAR"},'
      '"progress":{"paid":37500,"total":50000},"actions":[{"target":"payments"}]},'
      '{"id":11,"key":null,"kind":"faq","question":{"ar":"مواعيد العمل؟","en":"Working hours?"},'
      '"answer":{"ar":"من 9 لـ 5","en":"9 to 5"},"actions":[]}]}';

  Future<List<String>> pump(WidgetTester tester, {String body = enabled, Locale locale = const Locale('en'), bool fail = false}) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    final opened = <String>[];
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((_) async {
      if (fail) return jsonResponse('{"message":"boom"}', 500);
      return jsonResponse(body);
    });
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        floatingActionButton: ClientAssistantFab(api: api, workspaceId: 22, onNavigate: opened.add),
      ),
    ));
    await tester.pumpAndSettle();
    return opened;
  }

  testWidgets('draws nothing while the server has it switched off', (tester) async {
    await pump(tester, body: '{"enabled":false}');
    expect(find.byKey(const ValueKey('assistant-fab')), findsNothing);
  });

  testWidgets('draws nothing, and no error, when the request fails', (tester) async {
    await pump(tester, fail: true);
    expect(find.byKey(const ValueKey('assistant-fab')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens with the welcome and every question, then answers a tap with a button to the right tab', (tester) async {
    final opened = await pump(tester);

    await tester.tap(find.byKey(const ValueKey('assistant-fab')));
    await tester.pumpAndSettle();

    expect(find.text('Shad assistant'), findsOneWidget);
    expect(find.text('Hi Ahmed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-q-balance-2')));
    await tester.pumpAndSettle();

    expect(find.text('You still owe 12,500.00 SAR'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-progress')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-go-payments')));
    await tester.pumpAndSettle();

    expect(opened, ['payments']);
    expect(find.text('Hi Ahmed'), findsNothing); // the sheet closed
  });

  testWidgets('a FAQ answer has no button when it has no target', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('assistant-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assistant-q-faq-11')));
    await tester.pumpAndSettle();

    expect(find.text('9 to 5'), findsOneWidget);
    expect(find.byKey(const ValueKey('assistant-go-payments')), findsNothing);
  });

  testWidgets('reads the wording in the app language', (tester) async {
    await pump(tester, locale: const Locale('ar'));
    await tester.tap(find.byKey(const ValueKey('assistant-fab')));
    await tester.pumpAndSettle();

    expect(find.text('أهلاً أحمد'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('assistant-q-balance-2')));
    await tester.pumpAndSettle();

    expect(find.text('فاضل عليك 12,500.00 SAR'), findsOneWidget);
    expect(find.text('افتح المدفوعات'), findsOneWidget);
  });

  testWidgets('the close button closes the sheet', (tester) async {
    await pump(tester);
    await tester.tap(find.byKey(const ValueKey('assistant-fab')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('assistant-close')));
    await tester.pumpAndSettle();

    expect(find.text('Hi Ahmed'), findsNothing);
  });
}
