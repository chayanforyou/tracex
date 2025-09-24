import 'package:flutter/widgets.dart';
import 'package:tracex/src/highlight/themes/default.dart';

import 'package:highlight/highlight.dart' show highlight, Node;

class JsonHighlight extends StatelessWidget {
  /// The original code to be highlighted
  final String source;

  /// Highlight language
  ///
  /// It is recommended to give it a value for performance
  final String? language;

  /// Highlight theme
  final Map<String, TextStyle> theme;

  /// Padding
  final EdgeInsetsGeometry? padding;

  /// Text styles
  ///
  /// Specify text styles such as font family and font size
  final TextStyle? textStyle;

  JsonHighlight(
    String input, {
    super.key,
    this.language = 'json',
    this.theme = defaultTheme,
    this.padding,
    this.textStyle,
    int tabSize = 8, // TODO: https://github.com/flutter/flutter/issues/50087
  }) : source = input.replaceAll('\t', ' ' * tabSize);

  List<TextSpan> _convert(List<Node> nodes) {
    List<TextSpan> spans = [];
    var currentSpans = spans;
    List<List<TextSpan>> stack = [];

    traverse(Node node) {
      if (node.value != null) {
        currentSpans.add(
          node.className == null
              ? TextSpan(text: node.value)
              : TextSpan(text: node.value, style: theme[node.className!]),
        );
      } else if (node.children != null) {
        List<TextSpan> tmp = [];
        currentSpans.add(
          TextSpan(children: tmp, style: theme[node.className!]),
        );
        stack.add(currentSpans);
        currentSpans = tmp;

        for (var n in node.children!) {
          traverse(n);
          if (n == node.children!.last) {
            currentSpans = stack.isEmpty ? spans : stack.removeLast();
          }
        }
      }
    }

    for (var node in nodes) {
      traverse(node);
    }

    return spans;
  }

  static const _rootKey = 'root';
  static const _defaultFontColor = Color(0xff000000);
  static const _defaultBackgroundColor = Color(0xffffffff);

  // TODO: dart:io is not available at web platform currently
  // See: https://github.com/flutter/flutter/issues/39998
  // So we just use monospace here for now
  static const _defaultFontFamily = 'monospace';

  @override
  Widget build(BuildContext context) {
    var textStyle = TextStyle(
      fontSize: 14,
      wordSpacing: -2.0,
      letterSpacing: -0.5,
      fontFamily: _defaultFontFamily,
      color: theme[_rootKey]?.color ?? _defaultFontColor,
    );
    textStyle = textStyle.merge(this.textStyle);

    return Container(
      color: theme[_rootKey]?.backgroundColor ?? _defaultBackgroundColor,
      padding: padding,
      child: RichText(
        text: TextSpan(
          style: textStyle,
          children: _convert(
            highlight.parse(source, language: language).nodes!,
          ),
        ),
      ),
    );
  }
}
