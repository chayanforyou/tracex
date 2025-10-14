import 'package:flutter/material.dart';

class TraceXTopSnackBar extends StatelessWidget {
  final String message;

  const TraceXTopSnackBar._({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 4),
          )
        ],
      ),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    final topInset = MediaQuery.of(context).viewPadding.top;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        top: topInset + 12.0,
        left: 20,
        right: 20,
        child: SafeArea(
          child: Material(
            color: Colors.transparent,
            child: AnimatedSlide(
              offset: const Offset(0, -0.3),
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOut,
              child: TraceXTopSnackBar._(message: message),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 1), () {
      entry.remove();
    });
  }
}
