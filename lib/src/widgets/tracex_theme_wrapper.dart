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
    // Always use English. The default delegates support only 'en', so the
    // host app's locale (e.g. bn_BD) would cause a missing localizations error.
    Widget content = Localizations(
      locale: const Locale('en', 'US'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: child,
    );

    return Theme(
      data: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: TraceXColors.blue,
        dividerColor: TraceXColors.grey,
        dividerTheme: DividerThemeData(
          color: TraceXColors.grey,
        ),
        listTileTheme: ListTileThemeData(
          titleTextStyle: TextStyle(
            height: 1.5,
            fontWeight: FontWeight.bold,
            color: TraceXColors.textPrimary,
          ),
          subtitleTextStyle: TextStyle(
            height: 1.43,
            fontWeight: FontWeight.normal,
            color: TraceXColors.textSecondary,
          ),
        ),
      ),
      child: content,
    );
  }
}
