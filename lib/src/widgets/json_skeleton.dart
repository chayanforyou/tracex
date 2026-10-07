import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';

/// Pulsing placeholder lines shaped like indented JSON, shown while a body
/// is being prepared.
class JsonSkeleton extends StatefulWidget {
  /// What is happening, e.g. "Formatting body…".
  final String label;

  const JsonSkeleton({required this.label, super.key});

  @override
  State<JsonSkeleton> createState() => _JsonSkeletonState();
}

class _JsonSkeletonState extends State<JsonSkeleton>
    with SingleTickerProviderStateMixin {
  /// (indent level, width as a fraction of the available width) per line.
  static const _lines = [
    (0, 0.04),
    (1, 0.45),
    (1, 0.62),
    (1, 0.30),
    (2, 0.52),
    (2, 0.38),
    (2, 0.58),
    (1, 0.04),
    (1, 0.48),
    (0, 0.04),
  ];

  static const _indent = 16.0;
  static const _lineHeight = 10.0;
  static const _lineGap = 10.0;
  static const _lineColor = Color(0xFFE0E4E8);

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  )..repeat(reverse: true);

  late final Animation<double> _opacity =
      Tween<double>(begin: 0.4, end: 1.0).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 12.0,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              ),
              const SizedBox(width: 8.0),
              Text(
                widget.label,
                style: const TextStyle(
                  fontSize: 12.0,
                  color: TraceXColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12.0),
          FadeTransition(
            opacity: _opacity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (depth, fraction) in _lines)
                      Padding(
                        padding: EdgeInsets.only(
                          left: depth * _indent,
                          bottom: _lineGap,
                        ),
                        child: Container(
                          width: constraints.maxWidth * fraction,
                          height: _lineHeight,
                          decoration: BoxDecoration(
                            color: _lineColor,
                            borderRadius: BorderRadius.circular(4.0),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
