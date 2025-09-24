import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

extension TraceXStringExt on String {
  Future<void> copyToClipboard(BuildContext context) {
    final snackBar = SnackBar(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      dismissDirection: DismissDirection.startToEnd,
      content: Text(
        'Copied',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: Colors.white),
        textAlign: TextAlign.center,
      ),
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height - 160,
        right: 20,
        left: 20,
      ),
    );

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(snackBar);

    HapticFeedback.lightImpact();

    return Clipboard.setData(ClipboardData(text: this));
  }

  String get asReadableSize {
    final encoded = utf8.encode(this);
    return '${(encoded.length / 1024).toStringAsFixed(2)} kb';
  }
}
