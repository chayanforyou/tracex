import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracex/src/widgets/json_tree_viewer.dart';

/// Builds a JSON document with [count] items, each holding one
/// "Mock Product" match and a value long enough to wrap.
String _sampleJson({int count = 200}) {
  return const JsonEncoder.withIndent('  ').convert({
    'long': 'word ' * 60,
    'escaped': 'a\nb\tc',
    'items': List.generate(
      count,
      (i) => {
        'id': i,
        'name': 'Mock Product $i',
        'description': 'Description for mock product number $i ' * 3,
        'price': i * 1.5,
        'active': i.isEven,
        'note': null,
      },
    ),
  });
}

void main() {
  late int matchCount;

  Widget viewer(
    String json, {
    String query = '',
    int matchIndex = -1,
    JsonTreeController? controller,
    bool showArrayIndices = false,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: CustomScrollView(
          slivers: [
            SliverJsonTreeViewer(
              jsonString: json,
              searchQuery: query,
              currentMatchIndex: matchIndex,
              onMatchCountChanged: (count) => matchCount = count,
              controller: controller,
              showArrayIndices: showArrayIndices,
            ),
          ],
        ),
      ),
    );
  }

  Iterable<String> visibleTexts(WidgetTester tester) {
    return tester
        .widgetList<RichText>(find.byType(RichText))
        .map((text) => text.text.toPlainText());
  }

  setUp(() => matchCount = -1);

  testWidgets('wraps long values onto several lines', (tester) async {
    await tester.pumpWidget(viewer(_sampleJson()));

    final longRow = visibleTexts(tester).firstWhere((t) => t.contains('word'));
    expect(longRow.split('\n').length, greaterThan(1));
  });

  testWidgets('shows control characters escaped', (tester) async {
    await tester.pumpWidget(viewer(_sampleJson()));

    expect(visibleTexts(tester).any((t) => t.contains(r'"a\nb\tc"')), isTrue);
  });

  testWidgets('reports the search match count', (tester) async {
    await tester.pumpWidget(viewer(_sampleJson(), query: 'mock product'));
    await tester.pump();

    // Each item matches in "name" and in "description" three times.
    expect(matchCount, 200 * 4);
  });

  testWidgets('jumps to the last match and back', (tester) async {
    final json = _sampleJson();
    await tester.pumpWidget(viewer(json, query: 'Mock Product'));
    await tester.pump();

    await tester.pumpWidget(
      viewer(json, query: 'Mock Product', matchIndex: matchCount - 1),
    );
    await tester.pumpAndSettle();

    final position =
        tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.pixels, greaterThan(position.maxScrollExtent * 0.9));
    expect(
      visibleTexts(tester).any((t) => t.contains('Mock Product 199')),
      isTrue,
    );

    await tester.pumpWidget(
      viewer(json, query: 'Mock Product', matchIndex: 0),
    );
    await tester.pumpAndSettle();

    expect(position.pixels, lessThan(position.maxScrollExtent * 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('collapses and expands a node on tap', (tester) async {
    await tester.pumpWidget(viewer(_sampleJson(count: 2)));

    expect(find.textContaining('Mock Product 0', findRichText: true),
        findsOneWidget);

    await tester.tap(find.textContaining('"items"', findRichText: true));
    await tester.pump();

    expect(find.textContaining('Mock Product 0', findRichText: true),
        findsNothing);
    expect(
        find.textContaining('[ 2 items ]', findRichText: true), findsOneWidget);

    await tester.tap(find.textContaining('"items"', findRichText: true));
    await tester.pump();

    expect(find.textContaining('Mock Product 0', findRichText: true),
        findsOneWidget);
  });

  testWidgets('shows invalid JSON as plain text lines', (tester) async {
    await tester.pumpWidget(
      viewer('<html>\n\t<body>Not found</body>\n</html>', query: 'found'),
    );
    await tester.pump();

    final texts = visibleTexts(tester).toList();
    expect(texts, contains('<html>'));
    expect(texts, contains('    <body>Not found</body>'));
    expect(matchCount, 1);
  });

  testWidgets('shows array items without indices', (tester) async {
    await tester.pumpWidget(
      viewer('{"tags": [{"x": "a"}, {"x": "b"}]}', query: '1'),
    );
    await tester.pump();

    final texts = visibleTexts(tester);
    expect(texts, contains('"tags": ['));
    expect(texts, contains('{'));
    expect(texts.any((t) => t.startsWith('0')), isFalse);
    expect(matchCount, 0);
  });

  testWidgets('shows array indices when enabled, without searching them',
      (tester) async {
    const json = '{"tags": [{"x": "a"}, {"x": "b"}]}';
    await tester.pumpWidget(viewer(json, query: '1', showArrayIndices: true));
    await tester.pump();

    final texts = visibleTexts(tester);
    expect(texts, contains('0: {'));
    expect(texts, contains('1: {'));
    expect(matchCount, 0);
  });

  testWidgets('shows short arrays of primitives on one line', (tester) async {
    final longList = List.generate(20, (i) => 'item$i');
    await tester.pumpWidget(viewer(jsonEncode({
      'attachments': ['notes.txt', 'itinerary.pdf'],
      'empty': [],
      'none': {},
      'long': longList,
    })));

    final texts = visibleTexts(tester);
    expect(texts, contains('"attachments": ["notes.txt", "itinerary.pdf"],'));
    expect(texts, contains('"empty": [],'));
    expect(texts, contains('"none": {},'));
    expect(texts, contains('"long": ['));
  });

  testWidgets('wraps a long key on an object row', (tester) async {
    final key = 'k' * 200;
    await tester.pumpWidget(viewer('{"$key": {"a": 1}}'));

    final row = visibleTexts(tester).firstWhere((t) => t.contains('kkk'));
    expect(row.split('\n').length, greaterThan(1));
    expect(row.replaceAll('\n', ''), '"$key": {');
  });

  testWidgets('expands and collapses all nodes', (tester) async {
    final controller = JsonTreeController();
    await tester.pumpWidget(
      viewer(_sampleJson(count: 2), controller: controller),
    );

    controller.collapseAll();
    await tester.pump();
    expect(find.textContaining('Mock Product 0', findRichText: true),
        findsNothing);
    expect(find.textContaining('"items": [ 2 items ]', findRichText: true),
        findsOneWidget);

    controller.expandAll();
    await tester.pump();
    expect(find.textContaining('Mock Product 0', findRichText: true),
        findsOneWidget);
  });
}
