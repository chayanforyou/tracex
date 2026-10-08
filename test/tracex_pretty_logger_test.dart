import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracex/tracex.dart';

class _Item {
  final int id;
  const _Item(this.id);
  Map<String, dynamic> toJson() => {'id': id};
}

void main() {
  List<String> logBody(Object? body) {
    final lines = <String>[];
    TraceXPrettyLogger(logPrint: (line) => lines.add('$line')).logNetwork(
      TraceXNetworkEntry(
        request: NetworkRequestEntry(
          url: 'https://example.com',
          method: 'POST',
          headers: const {},
          body: body,
        ),
        response: NetworkResponseEntry(
          statusCode: 200,
          headers: const {},
          body: null,
        ),
      ),
    );
    return lines;
  }

  test('prints objects in the body with their toJson()', () {
    final output = logBody({
      'items': const [_Item(1), _Item(2)],
      'professional': const _Item(3),
    }).join('\n');

    expect(output, isNot(contains('Instance of')));
    expect(output, contains('id: 1'));
    expect(output, contains('id: 3'));
  });

  test('prints a top-level object and FormData', () {
    expect(logBody(const _Item(7)).join('\n'), contains('"id": 7'));

    final form = FormData()..fields.add(const MapEntry('title', 'Hello'));
    final output = logBody(form).join('\n');
    expect(output, isNot(contains('Instance of')));
    expect(output, contains('"title": "Hello"'));
  });
}
