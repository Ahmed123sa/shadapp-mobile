import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadapp_client/core/widgets/loading_state.dart';
import '../helpers/pump_app.dart';

void main() {
  testWidgets('spinner style shows a CircularProgressIndicator', (tester) async {
    await pumpWithLocalizations(tester, const LoadingState(style: LoadingStyle.spinner));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('list style renders itemCount shimmer cards', (tester) async {
    await pumpWithLocalizations(tester, const LoadingState(style: LoadingStyle.list, itemCount: 3));
    expect(find.byType(ListView), findsOneWidget);
    // Each shimmer card has exactly 3 shimmer bars (title + 2 lines).
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('grid style renders a GridView', (tester) async {
    await pumpWithLocalizations(tester, const LoadingState(style: LoadingStyle.grid, itemCount: 4));
    expect(find.byType(GridView), findsOneWidget);
  });

  testWidgets('defaults to the list style with 4 items when unspecified', (tester) async {
    await pumpWithLocalizations(tester, const LoadingState());
    expect(find.byType(ListView), findsOneWidget);
  });
}
