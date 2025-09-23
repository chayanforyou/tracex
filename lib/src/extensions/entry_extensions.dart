import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:tracex/tracex.dart';

extension TraceXNetworkExt on TraceXNetworkEntry {
  String get asReadableDuration {
    if (request.sentAt == null || response.receivedAt == null) {
      return 'N/A ms';
    }

    return '${response.receivedAt!.difference(request.sentAt!).inMilliseconds} ms';
  }

  String toCurlCommand() {
    final buffer = StringBuffer('curl');

    buffer.write(' -X ${request.method.toUpperCase()}');

    if (request.headers != null) {
      final headers = request.headers ?? {};
      headers.forEach((key, value) {
        buffer.write(" -H '${_escape(key)}: ${_escape(value.toString())}'");
      });
    }

    if (request.body != null) {
      var body = request.body;

      // FormData can't be JSON-serialized, so keep only their fields attributes
      if (body is FormData) {
        body = Map.fromEntries(body.fields);
      }

      final bodyString = body is String ? body : jsonEncode(body);
      buffer.write(" -d '${_escape(bodyString)}'");
    }

    buffer.write(" '${request.url}'");

    return buffer.toString();
  }

  String _escape(String input) {
    return input.replaceAll("'", r"'\''");
  }
}