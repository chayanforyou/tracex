import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tracex/src/extensions/object_extensions.dart';

enum _Status { attended }

class _Item {
  final int id;
  const _Item(this.id);
  Map<String, dynamic> toJson() => {'id': id};
}

void main() {
  test('encodes objects with their toJson(), and enums by name', () {
    final body = {
      'items': const [_Item(1), _Item(2)],
      'status': _Status.attended,
    };

    final decoded = jsonDecode(body.prettyJson) as Map;

    expect(decoded['items'], [
      {'id': 1},
      {'id': 2},
    ]);
    expect(decoded['status'], 'attended');
  });

  test('keeps JSON structure when a value is not encodable', () {
    final body = {
      'id': 1,
      'createdAt': DateTime.utc(2026, 10, 8),
    };

    final decoded = jsonDecode(body.prettyJson) as Map;

    expect(decoded['id'], 1);
    expect(decoded['createdAt'], '2026-10-08 00:00:00.000Z');
  });

  test('formats FormData fields and repeated keys', () {
    final form = FormData()
      ..fields.addAll(const [
        MapEntry('title', 'Hello'),
        MapEntry('count', '123'),
        MapEntry('meta', '{"a": 1}'),
        MapEntry('tags[]', 'a'),
        MapEntry('tags[]', 'b'),
      ])
      ..files.addAll([
        MapEntry('images', MultipartFile.fromBytes([1], filename: '1.jpg')),
        MapEntry('images', MultipartFile.fromBytes([2], filename: '2.jpg')),
      ]);

    final decoded = jsonDecode(form.prettyJson) as Map;

    expect(decoded['title'], 'Hello');
    expect(decoded['count'], '123');
    expect(decoded['meta'], {'a': 1});
    expect(decoded['tags[]'], ['a', 'b']);
    expect(decoded['images'], ['1.jpg', '2.jpg']);
  });
}
