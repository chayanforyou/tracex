import 'package:flutter/material.dart';
import 'package:tracex/src/core/tracex_overlay.dart';
import 'package:tracex/src/widgets/tracex_home_screen.dart';
import 'package:tracex/tracex.dart';

class TraceX {
  /// Prints logs to the console.
  final TraceXPrettyLogger logger;

  /// Custom floating button; [isOpen] is true while the console is open.
  final Widget Function(bool isOpen)? customFab;

  /// Called with the text to share from the details screen.
  final Function(String data)? onShare;

  /// Size of the floating button.
  final double buttonSize;

  /// Gap between the floating button and the screen edge.
  final double edgeMargin;

  /// Max logs kept in memory; older ones are dropped.
  final int logBufferLength;

  TraceX({
    required this.logger,
    this.customFab,
    this.onShare,
    this.buttonSize = 48.0,
    this.edgeMargin = 6.0,
    this.logBufferLength = 100,
  });

  /// Recent logs, newest first.
  final logs = ValueNotifier(<TraceXEntry>[]);

  void _add(TraceXEntry entry) {
    if (logBufferLength <= 0) return;
    final updated = [entry, ...logs.value];
    if (updated.length > logBufferLength) {
      updated.removeRange(logBufferLength, updated.length);
    }
    logs.value = updated;
  }

  /// Prints [message] to the console. It is not shown in the TraceX console.
  void log(Object? message, {StackTrace? stackTrace}) {
    logger.logMessage(message.toString(), stackTrace: stackTrace);
  }

  /// Records a network call: prints it and adds it to [logs].
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

  /// Shows the floating button when [visible] is true.
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

  /// Opens the TraceX console screen.
  Future<void> openConsole(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TraceXHomeScreen(this),
      ),
    );
  }

  /// Removes all logs.
  void clear() {
    logs.value = [];
  }
}
