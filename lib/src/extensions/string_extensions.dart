import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tracex/src/widgets/tracex_top_snackbar.dart';

/// Android sends clipboard data through Binder, whose buffer is about 1 MB
/// per process. Text is UTF-16 (2 bytes per character), so larger copies
/// fail with TransactionTooLargeException.
const _androidClipboardMaxLength = 256 * 1024;

extension TraceXStringExt on String {
  Future<void> copyToClipboard(BuildContext context) async {
    if (defaultTargetPlatform == TargetPlatform.android &&
        length > _androidClipboardMaxLength) {
      TraceXTopSnackBar.show(
        context,
        'Too large to copy ($asReadableSize)',
      );
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: this));
    } on PlatformException {
      if (context.mounted) TraceXTopSnackBar.show(context, 'Copy failed');
      return;
    }

    HapticFeedback.lightImpact();
    if (context.mounted) TraceXTopSnackBar.show(context, 'Copied');
  }

  Future<void> shareText() async {
    // await Share.share(this);
  }

  String get asReadableSize {
    final encoded = utf8.encode(this);
    return '${(encoded.length / 1024).toStringAsFixed(2)} kb';
  }
}
