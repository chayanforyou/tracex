import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tracex/src/models/tracex_entry.dart';

/// A pretty logger for TraceX
/// It will print request/response info with a beautiful format
class TraceXPrettyLogger {
  /// Print request info
  final bool request;

  /// Print request headers
  final bool requestHeader;

  /// Print request body
  final bool requestBody;

  /// Print response body
  final bool responseBody;

  /// Print response headers
  final bool responseHeader;

  /// Print error message
  final bool error;

  /// Initial tab count to log print json response
  static const int kInitialTab = 1;

  /// 1 tab length
  static const String tabStep = '    ';

  /// Print compact json response
  final bool compact;

  /// Width size per log print
  final int maxWidth;

  /// Size in which the Uint8List will be split
  static const int chunkSize = 20;

  /// Log printer; defaults log print to console.
  /// In flutter, you'd better use debugPrint.
  /// you can also write log in a file.
  final void Function(Object object) logPrint;

  /// Enable log print
  final bool enabled;

  /// Default constructor
  TraceXPrettyLogger({
    this.request = true,
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = true,
    this.responseBody = true,
    this.error = true,
    this.maxWidth = 90,
    this.compact = true,
    this.logPrint = print,
    this.enabled = true,
  });

  /// Log a network entry with pretty format
  void logNetwork(TraceXNetworkEntry entry) {
    if (!enabled) return;

    final request = entry.request;
    final response = entry.response;
    final timestamp = DateTime.now().toIso8601String();

    // Print main header
    _printBoxed(
      header: 'TraceX Network Log ║ ${request.method} ║ ${response.statusCode} ║ $timestamp',
      text: request.url,
    );

    // Print request section
    if (this.request) {
      _printRequestHeader(request);
    }

    if (requestHeader && request.headers != null) {
      _printMapAsTable(request.headers, header: 'Request Headers');
    }

    if (requestBody && request.body != null) {
      _printDataBlock(request.body, header: 'Request Body');
    }

    // Print response section
    _printResponseHeader(response);

    if (responseHeader && response.headers != null) {
      _printMapAsTable(response.headers, header: 'Response Headers');
    }

    if (responseBody && response.body != null) {
      _printDataBlock(response.body, header: 'Response Body');
    }

    _printLine('╚');
    logPrint('');
  }

  /// Log a general message with pretty format
  void logMessage(String message, {StackTrace? stackTrace}) {
    if (!enabled) return;

    final timestamp = DateTime.now().toIso8601String();

    _printBoxed(
      header: 'TraceX Log ║ $timestamp',
      text: message,
    );

    if (stackTrace != null) {
      _printBlock('Stack Trace: $stackTrace');
    }

    _printLine('╚');
    logPrint('');
  }

  void _printRequestHeader(NetworkRequestEntry request) {
    _printBoxed(
      header: 'Request ║ ${request.method}',
      text: request.url,
    );
  }

  void _printResponseHeader(NetworkResponseEntry response) {
    _printBoxed(
      header: 'Response ║ Status: ${response.statusCode}',
      text: 'Response received',
    );
  }

  void _printDataBlock(dynamic data, {String? header}) {
    if (data == null) return;

    if (header != null) {
      logPrint('╔ $header');
      logPrint('║');
    }

    if (data is Map) {
      _printPrettyMap(data);
    } else if (data is List) {
      logPrint('║${_indent()}[');
      _printList(data);
      logPrint('║${_indent()}]');
    } else if (data is Uint8List) {
      logPrint('║${_indent()}[');
      _printUint8List(data);
      logPrint('║${_indent()}]');
    } else {
      _printBlock(data.toString());
    }

    if (header != null) {
      logPrint('║');
      _printLine('╚');
    }
  }

  void _printBoxed({String? header, String? text}) {
    logPrint('');
    logPrint('╔╣ $header');
    logPrint('║  $text');
    _printLine('╚');
  }

  void _printLine([String pre = '', String suf = '╝']) =>
      logPrint('$pre${'═' * maxWidth}$suf');

  void _printKV(String? key, Object? v) {
    final pre = '╟ $key: ';
    final msg = v.toString();

    if (pre.length + msg.length > maxWidth) {
      logPrint(pre);
      _printBlock(msg);
    } else {
      logPrint('$pre$msg');
    }
  }

  void _printBlock(String msg) {
    final lines = (msg.length / maxWidth).ceil();
    for (var i = 0; i < lines; ++i) {
      logPrint((i >= 0 ? '║ ' : '') +
          msg.substring(i * maxWidth,
              math.min<int>(i * maxWidth + maxWidth, msg.length)));
    }
  }

  String _indent([int tabCount = kInitialTab]) => tabStep * tabCount;

  void _printPrettyMap(
    Map data, {
    int initialTab = kInitialTab,
    bool isListItem = false,
    bool isLast = false,
  }) {
    var tabs = initialTab;
    final isRoot = tabs == kInitialTab;
    final initialIndent = _indent(tabs);
    tabs++;

    if (isRoot || isListItem) logPrint('║$initialIndent{');

    for (var index = 0; index < data.length; index++) {
      final isLast = index == data.length - 1;
      final key = '"${data.keys.elementAt(index)}"';
      dynamic value = data[data.keys.elementAt(index)];
      if (value is String) {
        value = '"${value.toString().replaceAll(RegExp(r'([\r\n])+'), " ")}"';
      }
      if (value is Map) {
        if (compact && _canFlattenMap(value)) {
          logPrint('║${_indent(tabs)} $key: $value${!isLast ? ',' : ''}');
        } else {
          logPrint('║${_indent(tabs)} $key: {');
          _printPrettyMap(value, initialTab: tabs);
        }
      } else if (value is List) {
        if (compact && _canFlattenList(value)) {
          logPrint('║${_indent(tabs)} $key: ${value.toString()}');
        } else {
          logPrint('║${_indent(tabs)} $key: [');
          _printList(value, tabs: tabs);
          logPrint('║${_indent(tabs)} ]${isLast ? '' : ','}');
        }
      } else {
        final msg = value.toString().replaceAll('\n', '');
        final indent = _indent(tabs);
        final linWidth = maxWidth - indent.length;
        if (msg.length + indent.length > linWidth) {
          final lines = (msg.length / linWidth).ceil();
          for (var i = 0; i < lines; ++i) {
            final multilineKey = i == 0 ? "$key:" : "";
            logPrint(
                '║${_indent(tabs)} $multilineKey ${msg.substring(i * linWidth, math.min<int>(i * linWidth + linWidth, msg.length))}');
          }
        } else {
          logPrint('║${_indent(tabs)} $key: $msg${!isLast ? ',' : ''}');
        }
      }
    }

    logPrint('║$initialIndent}${isListItem && !isLast ? ',' : ''}');
  }

  void _printList(List list, {int tabs = kInitialTab}) {
    for (var i = 0; i < list.length; i++) {
      final element = list[i];
      final isLast = i == list.length - 1;
      if (element is Map) {
        if (compact && _canFlattenMap(element)) {
          logPrint('║${_indent(tabs)}  $element${!isLast ? ',' : ''}');
        } else {
          _printPrettyMap(
            element,
            initialTab: tabs + 1,
            isListItem: true,
            isLast: isLast,
          );
        }
      } else {
        logPrint('║${_indent(tabs + 2)} $element${isLast ? '' : ','}');
      }
    }
  }

  void _printUint8List(Uint8List list, {int tabs = kInitialTab}) {
    var chunks = [];
    for (var i = 0; i < list.length; i += chunkSize) {
      chunks.add(
        list.sublist(
            i, i + chunkSize > list.length ? list.length : i + chunkSize),
      );
    }
    for (var element in chunks) {
      logPrint('║${_indent(tabs)} ${element.join(", ")}');
    }
  }

  bool _canFlattenMap(Map map) {
    return map.values
            .where((dynamic val) => val is Map || val is List)
            .isEmpty &&
        map.toString().length < maxWidth;
  }

  bool _canFlattenList(List list) {
    return list.length < 10 && list.toString().length < maxWidth;
  }

  void _printMapAsTable(Map? map, {String? header}) {
    if (map == null || map.isEmpty) return;
    logPrint('╔ $header ');
    for (final entry in map.entries) {
      _printKV(entry.key.toString(), entry.value);
    }
    _printLine('╚');
  }
}
