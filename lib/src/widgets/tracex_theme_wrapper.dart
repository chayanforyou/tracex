import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';

class TraceXThemeWrapper extends StatelessWidget {
  final Widget child;

  const TraceXThemeWrapper({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: TraceXColors.blue,
        dividerTheme: DividerThemeData(
          color: TraceXColors.grey,
        ),
      ),
      child: child,
    );
  }
}