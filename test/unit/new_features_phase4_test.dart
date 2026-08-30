import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shadapp_client/core/api_client.dart';
import '../helpers/mock_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockHttpClient httpClient;
  late ApiClient api;

  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  setUp(() {
    httpClient = MockHttpClient();
    api = buildTestApiClient(client: httpClient);
  });

  test('ApiClient fetches /settings with show_contract_dates correctly', () async {
    when(() => httpClient.get(any(), headers: any(named: 'headers'))).thenAnswer(
      (_) async => jsonResponse(jsonEncode({
        'settings': {
          'corporate_tax_percentage': {'value': '15'},
          'show_contract_dates': {'value': '1'},
        }
      })),
    );

    final res = await api.get('/settings');
    expect(res['settings'], isNotNull);
    expect(res['settings']['show_contract_dates']['value'], equals('1'));
  });

  test('ApiClient updates show_contract_dates successfully', () async {
    when(() => httpClient.put(any(), headers: any(named: 'headers'), body: any(named: 'body'))).thenAnswer(
      (_) async => jsonResponse(jsonEncode({
        'setting': {'key': 'show_contract_dates', 'value': '0'}
      })),
    );

    final res = await api.put('/settings', {'key': 'show_contract_dates', 'value': '0'});
    expect(res['setting']['value'], equals('0'));
  });
}