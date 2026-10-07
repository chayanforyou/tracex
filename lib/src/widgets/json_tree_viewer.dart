import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:tracex/src/widgets/json_skeleton.dart';

/// A collapsible JSON tree viewer with syntax highlighting.
///
/// Renders JSON as an interactive tree where objects and arrays
/// can be expanded/collapsed. This is a sliver: place it inside a
/// [CustomScrollView].
///
/// Rows are built lazily. Long values wrap at a fixed number of characters
/// per line (the font is monospace), so every row's height is known without
/// laying it out, and any row can be jumped to instantly. Text that isn't
/// valid JSON is shown line by line the same way.
class SliverJsonTreeViewer extends StatefulWidget {
  final String jsonString;
  final String searchQuery;

  /// Lets a parent expand or collapse every node.
  final JsonTreeController? controller;

  /// Index of the highlighted search match, or -1 for none. When it changes,
  /// the viewer expands the match's ancestors and scrolls to it.
  final int currentMatchIndex;

  /// Called with the number of search matches whenever it may have changed.
  final ValueChanged<int>? onMatchCountChanged;

  const SliverJsonTreeViewer({
    required this.jsonString,
    this.searchQuery = '',
    this.currentMatchIndex = -1,
    this.onMatchCountChanged,
    this.controller,
    super.key,
  });

  @override
  State<SliverJsonTreeViewer> createState() => _SliverJsonTreeViewerState();
}

/// Expands or collapses every node of the [SliverJsonTreeViewer] it is
/// passed to.
class JsonTreeController {
  _SliverJsonTreeViewerState? _state;

  void expandAll() => _state?._setAllExpanded(true);

  void collapseAll() => _state?._setAllExpanded(false);
}

class _SliverJsonTreeViewerState extends State<SliverJsonTreeViewer>
    with AutomaticKeepAliveClientMixin {
  /// Payloads larger than this are parsed in a background isolate.
  static const _isolateThreshold = 64 * 1024;

  _JsonNode? _rootNode;
  bool _parsing = false;
  int _parseToken = 0;

  /// Visible rows, in display order.
  List<_Row> _rows = const [];

  /// Row heights for [_rows]; rebuilt when the rows or text scale change.
  _RowMetrics? _metrics;

  /// The node holding each search match, in display order.
  List<_JsonNode> _matchNodes = const [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    _parseJson();
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) widget.controller!._state = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(SliverJsonTreeViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      if (oldWidget.controller?._state == this) {
        oldWidget.controller!._state = null;
      }
      widget.controller?._state = this;
    }
    if (oldWidget.jsonString != widget.jsonString) {
      _parseJson();
      return;
    }
    if (oldWidget.searchQuery != widget.searchQuery) {
      _search();
    }
    if (oldWidget.currentMatchIndex != widget.currentMatchIndex) {
      _revealCurrentMatch();
    }
  }

  void _parseJson() {
    final token = ++_parseToken;
    final source = widget.jsonString;

    if (source.length < _isolateThreshold) {
      _applyParsed(_parseTree(source));
      return;
    }

    _parsing = true;
    compute(_parseTree, source).then((root) {
      if (!mounted || token != _parseToken) return;
      setState(() => _applyParsed(root));
    });
  }

  void _applyParsed(_JsonNode root) {
    _parsing = false;
    _rootNode = root;
    _flatten();
    _search();
  }

  void _setAllExpanded(bool expanded) {
    final root = _rootNode;
    if (root == null) return;

    void visit(_JsonNode node) {
      // Keep the root open, or "collapse all" would hide everything.
      node.isExpanded = expanded || node == root;
      for (final child in node.children) {
        visit(child);
      }
    }

    setState(() {
      visit(root);
      _flatten();
    });
  }

  void _flatten() {
    final rows = <_Row>[];

    void visit(_JsonNode node, int depth, bool isLast) {
      if (node.type == _NodeType.text) {
        for (final line in node.children) {
          rows.add(_Row(line, depth, true, _RowKind.value));
        }
        return;
      }
      if (node.type == _NodeType.value) {
        rows.add(_Row(node, depth, isLast, _RowKind.value));
        return;
      }
      rows.add(_Row(node, depth, isLast, _RowKind.open));
      if (!node.isExpanded) return;
      for (int i = 0; i < node.children.length; i++) {
        visit(node.children[i], depth + 1, i == node.children.length - 1);
      }
      rows.add(_Row(node, depth, isLast, _RowKind.close));
    }

    if (_rootNode != null) visit(_rootNode!, 0, true);
    _rows = rows;
    _metrics = null;
  }

  _RowMetrics _metricsFor(TextStyle style, TextScaler textScaler) {
    final metrics = _metrics;
    if (metrics != null &&
        metrics.style == style &&
        metrics.textScaler == textScaler) {
      return metrics;
    }
    return _metrics = _RowMetrics(_rows, style, textScaler);
  }

  // -- Search ----------------------------------------------------------------

  void _search() {
    final matches = <_JsonNode>[];
    final query = widget.searchQuery.toLowerCase();

    void visit(_JsonNode node) {
      node.keyMatchStart = -1;
      node.valueMatchStart = -1;

      if (query.isNotEmpty) {
        // Array indices are positions, not data: searching "1" would
        // otherwise match every second item.
        if (node.key != null && node != _rootNode && !node.isArrayItem) {
          final count = _countMatches(node.keyText, query);
          if (count > 0) {
            node.keyMatchStart = matches.length;
            matches.addAll(List.filled(count, node));
          }
        }
        if (node.type == _NodeType.value) {
          final count = _countMatches(node.valueText, query);
          if (count > 0) {
            node.valueMatchStart = matches.length;
            matches.addAll(List.filled(count, node));
          }
        }
      }

      for (final child in node.children) {
        visit(child);
      }
    }

    if (_rootNode != null) visit(_rootNode!);
    _matchNodes = matches;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onMatchCountChanged?.call(_matchNodes.length);
    });
  }

  static int _countMatches(String text, String lowerQuery) {
    final lowerText = text.toLowerCase();
    int count = 0, index = 0;
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      count++;
      index += lowerQuery.length;
    }
    return count;
  }

  void _revealCurrentMatch() {
    final index = widget.currentMatchIndex;
    if (index < 0 || index >= _matchNodes.length) return;

    final node = _matchNodes[index];
    bool expanded = false;
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      if (!parent.isExpanded) {
        parent.isExpanded = true;
        expanded = true;
      }
    }
    if (expanded) _flatten();

    final row = _rows.indexWhere(
      (r) => r.node == node && r.kind != _RowKind.close,
    );
    if (row >= 0) _scrollToRow(row);
  }

  /// Row heights are known up front, so the row's offset is exact and only
  /// the rows on screen get built, however far away the row is.
  void _scrollToRow(int row) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final sliver = context.findRenderObject();
      if (sliver is! _RenderSliverJsonRows) return;

      final position = Scrollable.of(context).position;
      final target = sliver.constraints.precedingScrollExtent +
          sliver.offsetOfRow(row) -
          position.viewportDimension * 0.2;

      position.animateTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  // -- Build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_parsing) {
      return const SliverToBoxAdapter(
        child: JsonSkeleton(label: 'Building tree…'),
      );
    }

    if (_rootNode == null) return const SliverToBoxAdapter();

    // Measure with the style rows actually render with: Text merges
    // _baseStyle into DefaultTextStyle, which may add letterSpacing etc.
    final metrics = _metricsFor(
      DefaultTextStyle.of(context).style.merge(_baseStyle),
      MediaQuery.textScalerOf(context),
    );

    return _SliverJsonRows(
      metrics: metrics,
      delegate: SliverChildBuilderDelegate(
        childCount: _rows.length,
        (context, index) {
          final row = _rows[index];
          switch (row.kind) {
            case _RowKind.open:
              return _expandableRow(metrics, row.node, row.depth, row.isLast);
            case _RowKind.close:
              return _closingBracket(row.node, row.depth, row.isLast);
            case _RowKind.value:
              return _valueRow(metrics, row.node, row.depth, row.isLast);
          }
        },
      ),
    );
  }

  // -- Row builders ----------------------------------------------------------

  Widget _expandableRow(
      _RowMetrics metrics, _JsonNode node, int depth, bool isLast) {
    final isRoot = node == _rootNode;

    return InkWell(
      onTap: () => setState(() {
        node.isExpanded = !node.isExpanded;
        _flatten();
      }),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = metrics.columnsPerLine(depth, constraints.maxWidth);
          final spans = _hardWrap(
            [
              if (node.key != null && !isRoot) ...[
                ..._highlighted(
                    node.keyText, _keyColorFor(node), node.keyMatchStart),
                TextSpan(text: ': ', style: _style(_punctuationColor)),
              ],
              TextSpan(
                text: node.bracketText(isLast),
                style: _style(
                    node.isExpanded ? _punctuationColor : _collapsedColor),
              ),
            ],
            columns,
          );

          return Padding(
            padding: EdgeInsets.only(left: depth * _indent),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _arrowIcon(node.isExpanded),
                Expanded(
                  child: Text.rich(
                    TextSpan(children: spans),
                    softWrap: false,
                    overflow: TextOverflow.clip,
                    style: _baseStyle,
                    strutStyle: _strutStyle,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _closingBracket(_JsonNode node, int depth, bool isLast) {
    final close = node.type == _NodeType.object ? '}' : ']';
    return Padding(
      padding: EdgeInsets.only(left: depth * _indent + _arrowSize),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$close${isLast ? '' : ','}',
          style: _style(_punctuationColor),
        ),
      ),
    );
  }

  Widget _valueRow(
      _RowMetrics metrics, _JsonNode node, int depth, bool isLast) {
    final comma = isLast ? '' : ',';

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = metrics.columnsPerLine(depth, constraints.maxWidth);
        final spans = _hardWrap(
          [
            if (node.key != null) ...[
              ..._highlighted(
                  node.keyText, _keyColorFor(node), node.keyMatchStart),
              TextSpan(text: ': ', style: _style(_punctuationColor)),
            ],
            ..._highlighted(
              node.valueText,
              node.isPlainText ? _keyColor : _colorForValue(node.value),
              node.valueMatchStart,
            ),
            if (comma.isNotEmpty)
              TextSpan(text: comma, style: _style(_punctuationColor)),
          ],
          columns,
        );

        return Padding(
          padding: EdgeInsets.only(left: depth * _indent + _arrowSize),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text.rich(
              TextSpan(children: spans),
              softWrap: false,
              overflow: TextOverflow.clip,
              style: _baseStyle,
              strutStyle: _strutStyle,
            ),
          ),
        );
      },
    );
  }

  /// Inserts a line break every [columns] columns, the same way
  /// [_RowMetrics] counts lines, so the text fits the row height exactly.
  static List<InlineSpan> _hardWrap(List<TextSpan> spans, int columns) {
    final wrapped = <InlineSpan>[];
    int column = 0;

    for (final span in spans) {
      final text = span.text ?? '';
      final buffer = StringBuffer();
      for (final rune in text.runes) {
        final width = _columnsOf(rune);
        if (column > 0 && column + width > columns) {
          buffer.write('\n');
          column = 0;
        }
        buffer.writeCharCode(rune);
        column += width;
      }
      wrapped.add(TextSpan(text: buffer.toString(), style: span.style));
    }

    return wrapped;
  }

  // -- Search highlight ------------------------------------------------------

  /// Splits [text] into spans, highlighting search matches. [matchStart] is
  /// the global index of the first match in [text], or -1 if it has none.
  List<TextSpan> _highlighted(String text, Color color, int matchStart) {
    final style = _style(color);
    if (matchStart < 0 || widget.searchQuery.isEmpty) {
      return [TextSpan(text: text, style: style)];
    }

    final spans = <TextSpan>[];
    final lowerText = text.toLowerCase();
    final lowerQuery = widget.searchQuery.toLowerCase();
    int start = 0;
    int matchIndex = matchStart;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start), style: style));
        }
        break;
      }

      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index), style: style));
      }

      final matchText = text.substring(index, index + lowerQuery.length);
      final isCurrent = widget.currentMatchIndex == matchIndex;

      spans.add(TextSpan(
        text: matchText,
        style: style.copyWith(
          backgroundColor: isCurrent ? _currentMatchBg : _matchBg,
        ),
      ));

      matchIndex++;
      start = index + lowerQuery.length;
    }

    return spans;
  }

  // -- Helpers ---------------------------------------------------------------

  Widget _arrowIcon(bool expanded) {
    // Width sets the indent of rows below; height must fit in one row.
    return SizedBox(
      width: _arrowSize,
      height: _rowExtent,
      child: Icon(
        expanded ? Icons.arrow_drop_down : Icons.arrow_right,
        size: 16,
        color: _punctuationColor,
      ),
    );
  }

  /// Array indices are greyed out so they don't read as object keys.
  Color _keyColorFor(_JsonNode node) =>
      node.isArrayItem ? _collapsedColor : _keyColor;

  Color _colorForValue(dynamic value) {
    if (value == null) return _nullColor;
    if (value is String) return _valueStringColor;
    if (value is num) return _valueNumberColor;
    if (value is bool) return _valueBoolColor;
    // An inline array whose items all share a type takes that type's color.
    if (value is List && value.isNotEmpty) {
      final color = _colorForValue(value.first);
      if (value.every((e) => _colorForValue(e) == color)) return color;
    }
    return _punctuationColor;
  }

  // -- Constants & Styles ----------------------------------------------------

  static const _keyColor = Color(0xFF1A1A1A);
  static const _valueStringColor = Color(0xFF008000);

  static const _valueNumberColor = Color(0xFFFF0000);
  static const _valueBoolColor = Color(0xFFFF8C00);
  static const _nullColor = Color(0xFF808080);
  static const _punctuationColor = Color(0xFF43474E);
  static const _collapsedColor = Color(0xFF808080);
  static const _matchBg = Color(0xFFFFFF00);
  static const _currentMatchBg = Color(0xFFFFAB40);

  static TextStyle _style(Color color) => _baseStyle.copyWith(color: color);
}

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------

const _indent = 16.0;
const _arrowSize = 20.0;

/// Minimum row height; also the height of every single-line row.
const _rowExtent = 16.0;

const _fontSize = 13.0;
const _lineHeight = 1.1;

const _baseStyle = TextStyle(
  fontSize: _fontSize,
  height: _lineHeight,
  fontFamily: 'monospace',
  fontFamilyFallback: ['Menlo', 'Courier New', 'Courier'],
);

/// Forces every line to the same height, so row heights can be computed.
const _strutStyle = StrutStyle(
  fontSize: _fontSize,
  height: _lineHeight,
  forceStrutHeight: true,
);

/// How many monospace columns [rune] takes up: 2 for CJK and emoji, else 1.
int _columnsOf(int rune) {
  if (rune >= 0x1100 && rune <= 0x115F) return 2; // Hangul Jamo
  if (rune >= 0x2E80 && rune <= 0xA4CF) return 2; // CJK, Hiragana, Katakana
  if (rune >= 0xAC00 && rune <= 0xD7A3) return 2; // Hangul syllables
  if (rune >= 0xF900 && rune <= 0xFAFF) return 2; // CJK compatibility
  if (rune >= 0xFF00 && rune <= 0xFF60) return 2; // Fullwidth forms
  if (rune >= 0x1F300 && rune <= 0x1FAFF) return 2; // Emoji
  if (rune >= 0x20000 && rune <= 0x3FFFD) return 2; // CJK extensions
  return 1;
}

int _columnsOfText(String text) {
  int columns = 0;
  for (final rune in text.runes) {
    columns += _columnsOf(rune);
  }
  return columns;
}

/// Computes every row's height arithmetically, from its character count and
/// the width of one monospace column, and keeps prefix sums of them so that
/// offset and index lookups are O(1) and O(log n).
class _RowMetrics {
  final List<_Row> rows;
  final TextStyle style;
  final TextScaler textScaler;
  late final double columnWidth;
  late final double lineExtent;
  late final double singleRowExtent;

  _RowMetrics(this.rows, this.style, this.textScaler) {
    final painter = TextPainter(
      text: TextSpan(text: 'M' * 100, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
      strutStyle: _strutStyle,
    )..layout();
    columnWidth = painter.width / 100;
    lineExtent = painter.height;
    painter.dispose();
    singleRowExtent = math.max(_rowExtent, lineExtent);
  }

  double? _width;
  Float64List? _offsets;

  int get rowCount => rows.length;

  int columnsPerLine(int depth, double width) {
    // 1px of slack so sub-pixel glyph rounding never clips the last column.
    final available = width - depth * _indent - _arrowSize - 1.0;
    return math.max(1, (available / columnWidth).floor());
  }

  /// Columns of text in [row], matching what the row builders render.
  static int _columnsOfRow(_Row row) {
    final node = row.node;
    final keyColumns =
        node.key != null && node.parent != null ? node.keyColumns + 2 : 0;
    switch (row.kind) {
      case _RowKind.close:
        return 2;
      case _RowKind.open:
        return keyColumns + _columnsOfText(node.bracketText(row.isLast));
      case _RowKind.value:
        return keyColumns + node.valueColumns + (row.isLast ? 0 : 1);
    }
  }

  double _extentOf(_Row row, double width) {
    final columns = _columnsOfRow(row);
    final lines = (columns / columnsPerLine(row.depth, width)).ceil();
    if (lines <= 1) return singleRowExtent;
    return lines * lineExtent + (singleRowExtent - lineExtent);
  }

  /// `offsets[i]` is where row `i` starts; `offsets[rowCount]` is the total.
  Float64List offsetsFor(double width) {
    if (_offsets != null && _width == width) return _offsets!;

    final offsets = Float64List(rows.length + 1);
    for (int i = 0; i < rows.length; i++) {
      offsets[i + 1] = offsets[i] + _extentOf(rows[i], width);
    }
    _width = width;
    return _offsets = offsets;
  }

  /// The row containing [offset], clamped to the last row.
  int indexAt(double offset, double width) {
    if (offset <= 0.0 || rows.isEmpty) return 0;
    final offsets = offsetsFor(width);
    int low = 0, high = rows.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (offsets[mid] < offset - precisionErrorTolerance) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return low;
  }
}

class _SliverJsonRows extends SliverMultiBoxAdaptorWidget {
  final _RowMetrics metrics;

  const _SliverJsonRows({
    required super.delegate,
    required this.metrics,
  });

  @override
  _RenderSliverJsonRows createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return _RenderSliverJsonRows(childManager: element, metrics: metrics);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverJsonRows renderObject,
  ) {
    renderObject.metrics = metrics;
  }
}

/// Like [RenderSliverVariedExtentList], but looks offsets up in
/// [_RowMetrics] instead of summing every preceding row's extent.
class _RenderSliverJsonRows extends RenderSliverFixedExtentBoxAdaptor {
  _RenderSliverJsonRows({
    required super.childManager,
    required _RowMetrics metrics,
  }) : _metrics = metrics;

  _RowMetrics _metrics;

  set metrics(_RowMetrics value) {
    if (identical(_metrics, value)) return;
    _metrics = value;
    markNeedsLayout();
  }

  double get _width => constraints.crossAxisExtent;

  double offsetOfRow(int index) => _metrics.offsetsFor(_width)[index];

  @override
  double? get itemExtent => null;

  @override
  ItemExtentBuilder get itemExtentBuilder => _extentAt;

  double? _extentAt(int index, SliverLayoutDimensions dimensions) {
    if (index >= _metrics.rowCount) return null;
    final offsets = _metrics.offsetsFor(dimensions.crossAxisExtent);
    return offsets[index + 1] - offsets[index];
  }

  @override
  double indexToLayoutOffset(double itemExtent, int index) {
    final offsets = _metrics.offsetsFor(_width);
    return offsets[index.clamp(0, _metrics.rowCount)];
  }

  @override
  int getMinChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return _metrics.indexAt(scrollOffset, _width);
  }

  @override
  int getMaxChildIndexForScrollOffset(double scrollOffset, double itemExtent) {
    return _metrics.indexAt(scrollOffset, _width);
  }

  @override
  double computeMaxScrollOffset(
    SliverConstraints constraints,
    double itemExtent,
  ) {
    return _metrics.offsetsFor(constraints.crossAxisExtent).last;
  }

  @override
  double estimateMaxScrollOffset(
    SliverConstraints constraints, {
    int? firstIndex,
    int? lastIndex,
    double? leadingScrollOffset,
    double? trailingScrollOffset,
  }) {
    return _metrics.offsetsFor(constraints.crossAxisExtent).last;
  }
}

// ---------------------------------------------------------------------------
// Internal data model
// ---------------------------------------------------------------------------

/// Top-level so it can run in a background isolate via [compute].
_JsonNode _parseTree(String source) {
  final Object? decoded;
  try {
    decoded = jsonDecode(source);
  } catch (_) {
    return _JsonNode.plainText(source);
  }

  return _JsonNode.build(null, decoded, null);
}

/// [text] is a non-JSON body: its children are one plain-text node per line.
enum _NodeType { object, array, value, text }

enum _RowKind { open, close, value }

class _Row {
  final _JsonNode node;
  final int depth;
  final bool isLast;
  final _RowKind kind;

  const _Row(this.node, this.depth, this.isLast, this.kind);
}

class _JsonNode {
  final String? key;
  final _NodeType type;
  final dynamic value;
  final _JsonNode? parent;
  final List<_JsonNode> children = [];
  bool isExpanded = true;

  /// A line of a non-JSON body, shown as-is rather than as a JSON value.
  final bool isPlainText;

  /// Global index of the first search match in [keyText] / [valueText],
  /// or -1 if there is none.
  int keyMatchStart = -1;
  int valueMatchStart = -1;

  _JsonNode({
    this.key,
    required this.type,
    this.value,
    this.parent,
    this.isPlainText = false,
    this.inlineText,
  });

  factory _JsonNode.plainText(String source) {
    final root = _JsonNode(type: _NodeType.text);
    for (final line in const LineSplitter().convert(source)) {
      root.children.add(_JsonNode(
        type: _NodeType.value,
        // Tabs have no fixed column width, so expand them.
        value: line.replaceAll('\t', '    '),
        parent: root,
        isPlainText: true,
      ));
    }
    return root;
  }

  static _JsonNode build(String? key, dynamic value, _JsonNode? parent) {
    final inline = _inlineText(value);
    if (inline != null) {
      return _JsonNode(
        key: key,
        type: _NodeType.value,
        value: value,
        parent: parent,
        inlineText: inline,
      );
    }
    if (value is Map) {
      final node = _JsonNode(key: key, type: _NodeType.object, parent: parent);
      for (final e in value.entries) {
        node.children.add(build(e.key.toString(), e.value, node));
      }
      return node;
    } else if (value is List) {
      final node = _JsonNode(key: key, type: _NodeType.array, parent: parent);
      for (int i = 0; i < value.length; i++) {
        node.children.add(build(i.toString(), value[i], node));
      }
      return node;
    } else {
      return _JsonNode(
        key: key,
        type: _NodeType.value,
        value: value,
        parent: parent,
      );
    }
  }

  /// Arrays longer than this when written on one line are shown as a tree.
  static const _inlineMaxLength = 60;

  /// One-line text for an empty object/array, or a short array of
  /// primitives, e.g. `["notes.txt", "itinerary.pdf"]`. Null otherwise.
  static String? _inlineText(dynamic value) {
    if (value is Map && value.isEmpty) return '{}';
    if (value is! List) return null;
    if (value.isEmpty) return '[]';
    if (!value
        .every((e) => e == null || e is String || e is num || e is bool)) {
      return null;
    }
    final text = '[${value.map(jsonEncode).join(', ')}]';
    return text.length <= _inlineMaxLength ? text : null;
  }

  /// Set for values shown on one line by [_inlineText].
  final String? inlineText;

  int get childCount => children.length;

  bool get isArrayItem => parent?.type == _NodeType.array;

  /// Keys and string values are shown JSON-escaped, so a newline or tab in
  /// the data shows as `\n` / `\t` instead of breaking the row layout.
  /// Array indices are shown unquoted.
  late final String keyText = isArrayItem ? '$key' : jsonEncode(key);

  late final String valueText = inlineText ??
      (isPlainText
          ? value as String
          : value is String
              ? jsonEncode(value)
              : '$value');

  late final int keyColumns = _columnsOfText(keyText);

  late final int valueColumns = _columnsOfText(valueText);

  /// The bracket part of this node's opening row: `{` when expanded,
  /// `{ 3 fields }` when collapsed.
  String bracketText(bool isLast) {
    final open = type == _NodeType.object ? '{' : '[';
    final close = type == _NodeType.object ? '}' : ']';
    if (isExpanded) return open;
    return '$open $collapsedPreview $close${isLast ? '' : ','}';
  }

  String get collapsedPreview {
    switch (type) {
      case _NodeType.object:
        return '$childCount ${childCount == 1 ? 'field' : 'fields'}';
      case _NodeType.array:
        return '$childCount ${childCount == 1 ? 'item' : 'items'}';
      case _NodeType.value:
      case _NodeType.text:
        return valueText;
    }
  }
}
