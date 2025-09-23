import 'package:tracex/src/extensions/entry_extensions.dart';
import 'package:tracex/src/extensions/object_extensions.dart';
import 'package:tracex/src/extensions/string_extensions.dart';

abstract class TraceXEntry {
  final DateTime _date;

  TraceXEntry() : _date = DateTime.now();

  DateTime get date => _date;

  String get timeFormatted =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}:${date.second}';

  List<String> get contents;
}

class TraceXNetworkEntry extends TraceXEntry {
  final NetworkRequestEntry request;
  final NetworkResponseEntry response;

  TraceXNetworkEntry({
    required this.request,
    required this.response,
  }) : super();

  @override
  List<String> get contents => [
        request.url,
        request.method,
        if (request.headers != null) request.headers!.toString(),
        if (request.body != null) request.body.toString(),
        if (request.sentAt != null) request.sentAt.toString(),
        if (response.statusCode != null) response.statusCode.toString(),
        if (response.headers != null) response.headers!.toString(),
        if (response.body != null) response.body.toString(),
        if (response.receivedAt != null) response.receivedAt.toString(),
      ];

  @override
  String toString() {
    final duration = asReadableDuration;
    final size = response.body?.toString().asReadableSize ?? '0B';
    final statusText =
        response.statusCode != null ? '${response.statusCode} ${_getStatusText(response.statusCode!)}' : 'No Response';

    return '''[NETWORK] ${request.method} ${request.url}
STATUS: $statusText • $duration • $size
HEADERS: ${request.headers.prettyJson}
BODY: ${request.body.prettyJson}
RESPONSE: ${response.body.prettyJson}''';
  }

  String _getStatusText(int code) {
    if (code >= 200 && code < 300) return 'OK';
    if (code >= 400 && code < 500) return 'Client Error';
    if (code >= 500) return 'Server Error';
    return 'Unknown';
  }
}

class NetworkRequestEntry {
  final String url;
  final String method;
  final Map<String, dynamic>? headers;
  final Object? body;
  final DateTime? sentAt;

  const NetworkRequestEntry({
    required this.url,
    required this.method,
    required this.headers,
    this.body,
    this.sentAt,
  });
}

class NetworkResponseEntry {
  final int? statusCode;
  final Map<String, String>? headers;
  final Object? body;
  final DateTime? receivedAt;

  NetworkResponseEntry({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.receivedAt,
  });
}
