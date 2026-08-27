import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/data/client_repository.dart';
import 'package:shadapp_client/features/am/workspace/client_profile_tab.dart';
import 'package:shadapp_client/generated/app_localizations.dart';
import 'package:shadapp_client/providers/client_provider.dart';
import 'package:shadapp_client/providers/contract_provider.dart';
import '../helpers/mock_http_client.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  Future<void> pumpTab(
    WidgetTester tester,
    ClientProvider clientProvider,
    ContractProvider contractProvider,
    dynamic api,
  ) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: ClientProfileTab(
          workspaceId: 5,
          clientProvider: clientProvider,
          contractProvider: contractProvider,
          api: api,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('loads the workspace then the client profile and shows company info', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer((inv) async {
      final path = (inv.positionalArguments[0] as Uri).path;
      if (path == '/workspaces/5') {
        return jsonResponse('{"workspace":{"id":5,"client":{"id":9}}}');
      }
      if (path == '/clients/9/profile') {
        return jsonResponse(
          '{"client":{"company_name":"Acme","contact_person":"Sara"},"stats":{"total_contracts":3},"location":{}}',
        );
      }
      return jsonResponse('{}');
    });
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, clientProvider, contractProvider, api);

    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Sara'), findsOneWidget);
    expect(find.text('Location not recorded yet'), findsOneWidget);
  });

  testWidgets('shows an error snackbar when the workspace fails to load', (tester) async {
    final httpClient = MockHttpClient();
    final api = buildTestApiClient(client: httpClient);
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse('{"message":"Server error"}', 500),
    );
    final clientProvider = ClientProvider(repository: ClientRepository(api: api));
    final contractProvider = ContractProvider(api: api);

    await pumpTab(tester, clientProvider, contractProvider, api);

    expect(find.text('Failed to load profile'), findsOneWidget);
  });
}
