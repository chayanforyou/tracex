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

    return Container(
      color: theme[_rootKey]?.backgroundColor ?? _defaultBackgroundColor,
      padding: padding,
      child: RichText(
        text: TextSpan(
          style: baseStyle,
          children: _buildSpans(parsedNodes),
        ),
      ),
    );
  }

  List<InlineSpan> _buildSpans(List<Node> nodes) {
    final spans = <InlineSpan>[];
    int matchIndex = 0;

    void traverse(Node node, TextStyle? parentStyle) {
      final style = (node.className != null ? theme[node.className!] : null) ?? parentStyle;

      if (node.value != null) {
        final value = node.value!;
        if (searchQuery.isEmpty) {
          spans.add(TextSpan(text: value, style: style));
          return;
        }

        int start = 0;
        final lowerValue = value.toLowerCase();
        final queryLower = searchQuery.toLowerCase();

        while (true) {
          final index = lowerValue.indexOf(queryLower, start);
          if (index == -1) {
            if (start < value.length) spans.add(TextSpan(text: value.substring(start), style: style));
            break;
          }

          if (index > start) spans.add(TextSpan(text: value.substring(start, index), style: style));

          final matchText = value.substring(index, index + searchQuery.length);
          final isCurrent = (currentMatchIndex ?? -1) == matchIndex;

          if (isCurrent && currentMatchKey != null) {
            spans.add(
              WidgetSpan(
                child: Container(
                  key: currentMatchKey,
                  color: _defaultMatchColor,
                  child: Text(
                    matchText,
                    style: style?.copyWith(height: 1.0),
                  ),
                ),
              ),
            );
          } else {
            spans.add(
              TextSpan(
                text: matchText,
                style: style?.copyWith(
                  backgroundColor: _defaultHighlightColor,
                ),
              ),
            );
          }

          matchIndex++;
          start = index + searchQuery.length;
        }
      } else if (node.children != null) {
        for (var child in node.children!) {
          traverse(child, style);
        }
      }
    }

    for (var node in nodes) {
      traverse(node, null);
    }
    return spans;
  }
}
