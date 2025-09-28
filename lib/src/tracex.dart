import 'package:flutter/material.dart';
import 'package:tracex/src/core/tracex_overlay.dart';
import 'package:tracex/src/widgets/tracex_home_screen.dart';
import 'package:tracex/tracex.dart';

class TraceX {
  final TraceXPrettyLogger logger;
  final Widget Function(bool isOpen)? customFab;
  final double buttonSize;
  final double edgeMargin;
  final int logBufferLength;

  TraceX({
    required this.logger,
    this.customFab,
    this.buttonSize = 48.0,
    this.edgeMargin = 6.0,
    this.logBufferLength = 2500,
  });

  final logs = ValueNotifier(<TraceXEntry>[]);

  void _add(TraceXEntry entry) {
    if (logs.value.length > logBufferLength) {
      logs.value.removeAt(0);
    }
    logs.value = [entry, ...logs.value];
  }

  void log(Object? message, {StackTrace? stackTrace}) {
    logger.logMessage(message.toString(), stackTrace: stackTrace);
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

      logger.logNetwork(entry);
      _add(entry);
    } catch (_) {}
  }

  void attach({
    required BuildContext context,
    required bool visible,
  }) {
    if (visible) {
      TraceXOverlay.attach(
        context: context,
        instance: this,
      );
    }
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
