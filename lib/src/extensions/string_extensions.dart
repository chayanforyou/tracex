import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tracex/src/widgets/tracex_top_snackbar.dart';

extension TraceXStringExt on String {
  Future<void> copyToClipboard(BuildContext context) async {
    TraceXTopSnackBar.show(context, 'Copied');
    HapticFeedback.lightImpact();
    return Clipboard.setData(ClipboardData(text: this));
  }

  Future<void> shareText() async {
    // await Share.share(this);
  }

  String get asReadableSize {
    final encoded = utf8.encode(this);
    return '${(encoded.length / 1024).toStringAsFixed(2)} kb';
  }
}
