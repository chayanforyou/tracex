import 'dart:convert';

import 'package:dio/dio.dart';

const _encoder = JsonEncoder.withIndent('  ', _toEncodable);

/// Converts values JSON can't represent. Like the default encoder, objects
/// are converted with their `toJson()`. Values without one (DateTime,
/// enums, ...) become a string instead of failing the whole body.
Object? _toEncodable(Object? value) {
  if (value is Enum) return value.name;
  try {
    return (value as dynamic).toJson();
  } catch (_) {
    return value.toString();
  }
}

extension TraceXObjectExt on Object? {
  String get prettyJson {
    try {
      final source = this;

      if (source == null) {
        return 'null';
      }

      // Handle FormData
      if (source is FormData) {
        // A key can repeat (e.g. `tags[]` or several files), so collect
        // every value per key.
        final Map<String, List<Object?>> values = {};

        // normal fields
        for (final field in source.fields) {
          // Form fields are always strings on the wire. Only expand fields
          // holding a JSON object or array; "123" or "true" stay strings.
          Object? value = field.value;
          try {
            final decoded = jsonDecode(field.value);
            if (decoded is Map || decoded is List) value = decoded;
          } catch (_) {}
          values.putIfAbsent(field.key, () => []).add(value);
        }

        // files
        for (final file in source.files) {
          final multipart = file.value;

          values
              .putIfAbsent(file.key, () => [])
              .add(multipart.filename ?? 'file');
        }

        final data = {
          for (final entry in values.entries)
            entry.key:
                entry.value.length == 1 ? entry.value.single : entry.value,
        };

        return _encoder.convert(data);
      }

      // Handle String JSON
      if (source is String) {
        final decoded = jsonDecode(source);
        return _encoder.convert(decoded);
      }

      // Handle Map/List
      return _encoder.convert(source);
    } catch (_) {
      return toString();
    }
  }
}
