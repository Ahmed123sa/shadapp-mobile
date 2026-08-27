import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/approval_repository.dart';
import 'package:shadapp_client/data/meeting_repository.dart';
import 'package:shadapp_client/data/payment_repository.dart';
import 'package:shadapp_client/features/am/workspace/calendar_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/approval_provider.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import 'package:shadapp_client/providers/meeting_provider.dart';
import 'package:shadapp_client/providers/payment_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(
    WidgetTester tester,
    MeetingProvider meetingProvider,
    ContractProvider contractProvider,
    PaymentProvider paymentProvider,
    ApprovalProvider approvalProvider,
    dynamic api,
  ) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: CalendarTab(
          workspaceId: 5,
          meetingProvider: meetingProvider,
          contractProvider: contractProvider,
          paymentProvider: paymentProvider,
          approvalProvider: approvalProvider,
          api: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('merges meetings, contract dates, payments, and approvals into one sorted list', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path.endsWith('/meetings')) {
        return jsonResponse('{"meetings":[{"id":1,"title":"Kickoff","status":"scheduled","scheduled_at":"2026-09-01T10:00:00Z"}]}');
      }
      if (path.endsWith('/contracts')) {
        return jsonResponse(
          '{"contracts":[{"id":2,"title":"MSA","status":"sent","start_date":"2026-09-02","end_date":"2026-12-01","reference_no":"REF-1"}]}',
        );
      }
      if (path.endsWith('/payments')) {
        return jsonResponse('{"payments":[{"id":3,"amount":500,"currency":"SAR","status":"pending","created_at":"2026-09-03","method_type":"cash"}]}');
      }
      if (path.endsWith('/approvals')) {
        return jsonResponse('{"approvals":[{"id":4,"title":"Extra Clause","status":"pending","created_at":"2026-09-04","reference_no":"APR-1"}]}');
      }
      return jsonResponse('{}');
    });
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, meetingProvider, contractProvider, paymentProvider, approvalProvider, api);

    expect(find.textContaining('Kickoff'), findsOneWidget);
    expect(find.textContaining('Start: MSA'), findsOneWidget);
    expect(find.textContaining('End: MSA'), findsOneWidget);
    expect(find.textContaining('Payment:'), findsOneWidget);
    expect(find.textContaining('Approval: Extra Clause'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no events', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"meetings":[],"contracts":[],"payments":[],"approvals":[]}'),
    );
    final meetingProvider = MeetingProvider(repository: MeetingRepository(api: api));
    final contractProvider = ContractProvider(api: api);
    final paymentProvider = PaymentProvider(repository: PaymentRepository(api: api));
    final approvalProvider = ApprovalProvider(repository: ApprovalRepository(api: api));

    await pumpTab(tester, meetingProvider, contractProvider, paymentProvider, approvalProvider, api);

    expect(find.text('No events'), findsOneWidget);
  });
}
