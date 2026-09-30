// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracex/src/widgets/tracex_home_screen.dart';
import 'package:tracex/tracex.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    // Tap to open console
    await tester.tap(find.text('TraceX console'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Network'), findsOneWidget);
  });

  testWidgets('TraceXHomeScreen builds safely without MaterialApp ancestor', (WidgetTester tester) async {
    final localTracex = TraceX(
      logger: TraceXPrettyLogger(enabled: false),
    );

    await tester.pumpWidget(
      WidgetsApp(
        color: const Color(0xFF000000),
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (_) => TraceXHomeScreen(localTracex),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Network'), findsOneWidget);
  });

  test('TraceX network buffer honors limit and drops oldest entries', () {
    final localTracex = TraceX(
      logBufferLength: 2,
      logger: TraceXPrettyLogger(enabled: false),
    );

    localTracex.network(
      request: const NetworkRequestEntry(method: 'GET', url: 'https://test.com/1', headers: {}),
      response: NetworkResponseEntry(statusCode: 200, headers: const {}, body: ''),
    );
    localTracex.network(
      request: const NetworkRequestEntry(method: 'GET', url: 'https://test.com/2', headers: {}),
      response: NetworkResponseEntry(statusCode: 200, headers: const {}, body: ''),
    );
    localTracex.network(
      request: const NetworkRequestEntry(method: 'GET', url: 'https://test.com/3', headers: {}),
      response: NetworkResponseEntry(statusCode: 200, headers: const {}, body: ''),
    );

    // Buffer capped at 2
    expect(localTracex.logs.value.length, 2);
    // Newest log is at index 0
    expect((localTracex.logs.value[0] as TraceXNetworkEntry).request.url, 'https://test.com/3');
    // Previous log is at index 1
    expect((localTracex.logs.value[1] as TraceXNetworkEntry).request.url, 'https://test.com/2');
  });
}
