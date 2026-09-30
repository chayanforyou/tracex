import 'package:flutter/material.dart';

class TextHighlight extends StatelessWidget {
  final String text;
  final String searchQuery;
  final int? currentMatchIndex;
  final Color highlightColor;
  final Color currentMatchColor;
  final TextStyle? style;
  final bool selectable;

  const TextHighlight({
    required this.text,
    required this.searchQuery,
    this.currentMatchIndex,
    this.highlightColor = const Color(0xFFFFFF00),
    this.currentMatchColor = const Color(0xFFFFAB40),
    this.style,
    this.selectable = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (searchQuery.isEmpty || text.isEmpty) {
      return selectable
          ? SelectableText(text, style: style)
          : Text(text, style: style);
    }

    final spans = _buildTextSpans();

    return selectable
        ? SelectableText.rich(
            TextSpan(children: spans, style: style),
          )
        : Text.rich(
            TextSpan(children: spans, style: style),
          );
  }

  List<TextSpan> _buildTextSpans() {
    final List<TextSpan> spans = [];
    final lowerText = text.toLowerCase();
    final lowerQuery = searchQuery.toLowerCase();

    int start = 0;
    int matchIndex = 0;

    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        // Add remaining text
        if (start < text.length) {
          spans.add(TextSpan(text: text.substring(start)));
        }
        break;
      }

      // Add text before match
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }

      // Add highlighted match
      final isCurrentMatch = currentMatchIndex != null && 
                             matchIndex == currentMatchIndex;
      
      spans.add(
        TextSpan(
          text: text.substring(index, index + searchQuery.length),
          style: TextStyle(
            backgroundColor: isCurrentMatch ? currentMatchColor : highlightColor,
            color: Colors.black87,
            fontWeight: isCurrentMatch ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );

      matchIndex++;
      start = index + searchQuery.length;
    }

    return spans;
  }
}

