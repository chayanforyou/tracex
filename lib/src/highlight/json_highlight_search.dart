import 'package:flutter/material.dart';
import 'package:highlight/highlight.dart' show highlight, Node;
import 'package:tracex/src/highlight/themes/default.dart';

class JsonHighlightSearch extends StatelessWidget {
  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final String searchQuery;
  final int? currentMatchIndex;
  final GlobalKey? currentMatchKey;

  const JsonHighlightSearch(
      this.source, {
        super.key,
        this.language = 'json',
        this.theme = defaultTheme,
        this.padding,
        this.textStyle,
        this.searchQuery = '',
        this.currentMatchIndex,
        this.currentMatchKey,
      });

  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xFF000000);
  static const _defaultBackgroundColor = Color(0xFFFFFFFF);
  static const _defaultHighlightColor = Color(0xFFFFFF00);
  static const _defaultMatchColor = Color(0xFFFFAB40);
  static const _defaultFontFamily = 'monospace';

  @override
  Widget build(BuildContext context) {
    final parsedNodes = highlight.parse(source, language: language).nodes ?? [];

    final baseStyle = TextStyle(
      fontSize: 14,
      wordSpacing: -2.0,
      letterSpacing: -0.4,
      fontFamily: _defaultFontFamily,
      color: theme[_rootKey]?.color ?? _defaultFontColor,
    ).merge(textStyle);

    final spans = _convertNodes(parsedNodes);
    return Container(
      color: theme[_rootKey]?.backgroundColor ?? _defaultBackgroundColor,
      padding: padding,
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: spans,
        ),
      ),
    );
  }

  // === Core fix: build spans with both syntax & search highlights ===
  List<InlineSpan> _convertNodes(List<Node> nodes) {
    final spans = <InlineSpan>[];
    var matchIndex = 0;

    void traverse(Node node, List<InlineSpan> output) {
      if (node.value != null) {
        final value = node.value!;
        final style = node.className != null ? theme[node.className!] : null;

        // Apply search highlighting only if query present
        if (searchQuery.isNotEmpty) {
          final lowerValue = value.toLowerCase();
          final queryLower = searchQuery.toLowerCase();
          int start = 0;
          while (true) {
            final index = lowerValue.indexOf(queryLower, start);
            if (index == -1) {
              if (start < value.length) {
                output.add(TextSpan(text: value.substring(start), style: style));
              }
              break;
            }

            // add text before match
            if (index > start) {
              output.add(TextSpan(
                text: value.substring(start, index),
                style: style,
              ));
            }

            // add highlighted match span
            final isCurrent = (currentMatchIndex ?? -1) == matchIndex;
            
            if (isCurrent && currentMatchKey != null) {
              output.add(
                WidgetSpan(
                  child: Container(
                    key: currentMatchKey,
                    color: _defaultMatchColor,
                    child: Text(
                      value.substring(index, index + searchQuery.length),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: style?.fontSize ?? 14,
                        fontFamily: style?.fontFamily ?? _defaultFontFamily,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              );
            } else {
              output.add(
                TextSpan(
                  text: value.substring(index, index + searchQuery.length),
                  style: TextStyle(
                    backgroundColor: _defaultHighlightColor,
                    color: Colors.black,
                    fontSize: style?.fontSize,
                    fontFamily: style?.fontFamily,
                    fontWeight: style?.fontWeight,
                  ),
                ),
              );
            }
            
            matchIndex++;
            start = index + searchQuery.length;
          }
        } else {
          output.add(TextSpan(text: value, style: style));
        }
      } else if (node.children != null) {
        final childrenSpans = <InlineSpan>[];
        for (var child in node.children!) {
          traverse(child, childrenSpans);
        }
        output.add(TextSpan(children: childrenSpans, style: theme[node.className ?? '']));
      }
    }

    for (var node in nodes) {
      traverse(node, spans);
    }
    return spans;
  }

  // Optional: helper to count matches
  static int countMatches(String lowerText, String lowerQuery) {
    if (lowerQuery.isEmpty) return 0;
    int count = 0, index = 0;
    while ((index = lowerText.indexOf(lowerQuery, index)) != -1) {
      count++;
      index += lowerQuery.length;
    }
    return count;
  }
}
