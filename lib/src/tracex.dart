import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:tracex/src/core/tracex_overlay.dart';
import 'package:tracex/src/widgets/tracex_home_screen.dart';
import 'package:tracex/tracex.dart';

class TraceX {
  final int logBufferLength;
  final Widget Function(bool isOpen)? customFab;
  final double buttonSize;
  final double edgeMargin;
  final TraceXPrettyLogger? logger;

  TraceX({
    this.buttonSize = 48.0,
    this.edgeMargin = 6.0,
    this.logBufferLength = 2500,
    this.customFab,
    this.logger,
  });

  final logs = ValueNotifier(<TraceXEntry>[]);

  void _add(TraceXEntry entry) {
    if (logs.value.length > logBufferLength) {
      logs.value.removeAt(0);
    }
    logs.value = [entry, ...logs.value];
  }

  void log(Object? message, {StackTrace? stackTrace}) {
    if (logger != null) {
      logger!.logMessage(message.toString(), stackTrace: stackTrace);
    } else {
      developer.log(
        message.toString(),
        name: 'tracex',
        stackTrace: stackTrace,
      );
    }
  }

  void network({
    required NetworkRequestEntry request,
    required NetworkResponseEntry response,
  }) {
    try {
      final entry = TraceXNetworkEntry(
        request: request,
        response: response,
      );

      if (logger != null) {
        logger!.logNetwork(entry);
      }

      _add(entry);
    } catch (_) {}
  }

  void attach(BuildContext context) {
    TraceXOverlay.attach(
      context: context,
      instance: this,
    );
  }

  /// Check if Overlay is currently attached
  bool get isOverlayAttached => TraceXOverlay.isAttached;

  /// Detach the Overlay if it's currently attached
  void detachOverlay() {
    TraceXOverlay.detach();
  }

  Future<void> openConsole(BuildContext context) async {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TraceXHomeScreen(this),
      ),
    );
  }

  void clear() {
    logs.value = [];
  }
}
