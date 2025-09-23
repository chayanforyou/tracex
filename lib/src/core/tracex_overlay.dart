import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tracex/src/constants/tracex_colors.dart';
import 'package:tracex/src/core/tracex_fab_state.dart';
import 'package:tracex/src/widgets/tracex_home_screen.dart';
import 'package:tracex/tracex.dart';


class TraceXOverlay extends StatelessWidget {
  final TraceX instance;

  const TraceXOverlay._internal({
    required this.instance,
  });

  static OverlayEntry? _currentEntry;
  static bool _isAttached = false;

  static bool get isAttached => _isAttached;

  /// Get the current overlay entry (if attached)
  static OverlayEntry? get currentEntry => _currentEntry;

  static void attach({
    required BuildContext context,
    required TraceX instance,
  }) {
    // Remove existing overlay if already attached
    if (_isAttached && _currentEntry != null) {
      _currentEntry!.remove();
      _isAttached = false;
      _currentEntry = null;
    }

    _currentEntry = OverlayEntry(
      builder: (context) {
        return TraceXOverlay._internal(
          instance: instance,
        );
      },
    );

    Future.delayed(kThemeAnimationDuration, () {
      if (!context.mounted) return;
      final overlay = Overlay.of(context);
      overlay.insert(_currentEntry!);
      _isAttached = true;
    });
  }

  /// Detach the current overlay
  static void detach() {
    if (_isAttached && _currentEntry != null) {
      _currentEntry!.remove();
      _isAttached = false;
      _currentEntry = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DraggableFab(instance: instance);
  }
}

class _DraggableFab extends StatefulWidget {
  final TraceX instance;

  const _DraggableFab({
    required this.instance,
  });

  @override
  State<_DraggableFab> createState() => _DraggableFabState();
}

class _DraggableFabState extends State<_DraggableFab> with SingleTickerProviderStateMixin {
  // Core state
  final TraceXFabState _fabState = TraceXFabState();
  bool _isDragging = false;
  bool _isStashed = false;
  
  // Position and layout
  Offset _offset = Offset.zero;
  late final double _buttonWidth;
  late final double _edgeMargin;
  
  // Animation
  late final AnimationController _animationController;
  Animation<Offset>? _animation;
  Animation<double>? _opacityAnimation;
  
  // UI components
  final LayerLink _layerLink = LayerLink();
  
  // Timers
  Timer? _stashTimer;

  @override
  void initState() {
    super.initState();
    _buttonWidth = widget.instance.buttonSize;
    _edgeMargin = widget.instance.edgeMargin;

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final size = MediaQuery.of(context).size;
        setState(() {
          _offset = Offset(
            size.width - _buttonWidth - _edgeMargin,
            (size.height / 2) - _edgeMargin,
          );
        });
        _startStashTimer();
      }
    });
  }

  @override
  void dispose() {
    _stashTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startStashTimer() {
    _stashTimer?.cancel();
    _stashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isDragging && !_isStashed && !_fabState.isOpened) {
        _stashToEdge();
      }
    });
  }

  void _stashToEdge() {
    if (!mounted) return;
    
    final size = MediaQuery.of(context).size;
    final isLeftSide = _offset.dx < size.width / 2;
    final targetX = isLeftSide 
        ? -_buttonWidth + 15 // Show small part on left edge
        : size.width - 15; // Show small part on right edge
    
    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    _opacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    _animation!.addListener(() {
      if (mounted) {
        setState(() {
          _offset = _animation!.value;
        });
      }
    });

    _animation!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isStashed = true;
        });
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _unstash() {
    if (!mounted || !_isStashed) return;
    
    final size = MediaQuery.of(context).size;
    final isLeftSide = _offset.dx < size.width / 2;
    final targetX = isLeftSide 
        ? _edgeMargin // Move to left edge
        : size.width - _buttonWidth - _edgeMargin; // Move to right edge
    
    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ));

    _animation!.addListener(() {
      if (mounted) {
        setState(() {
          _offset = _animation!.value;
        });
      }
    });

    _animation!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _isStashed = false;
        });
        _startStashTimer();
      }
    });

    _animationController.reset();
    _animationController.forward();
  }

  void _updatePosition(DragUpdateDetails details) {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    setState(() {
      _offset = Offset(
        (_offset.dx + details.delta.dx).clamp(0, size.width - _buttonWidth),
        (_offset.dy + details.delta.dy).clamp(0, size.height - _buttonWidth),
      );
    });
    _startStashTimer();
  }

  void _snapToEdge(DragEndDetails details) {
    final size = MediaQuery.of(context).size;

    // Determine which edge is closest
    final distanceToLeft = _offset.dx;
    final distanceToRight = size.width - (_offset.dx + _buttonWidth);

    // Calculate target position with margin
    final targetX = distanceToLeft < distanceToRight
        ? _edgeMargin
        : size.width - _buttonWidth - _edgeMargin;

    // Create and configure animation
    _animation = Tween<Offset>(
      begin: _offset,
      end: Offset(targetX, _offset.dy),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutExpo,
    ))
      ..addListener(() {
        if (mounted) {
          setState(() {
            _offset = _animation!.value;
          });
        }
      });

    // Start animation
    _animationController.reset();
    _animationController.forward();

    setState(() => _isDragging = false);
    _startStashTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: _offset.dx,
      top: _offset.dy,
      child: CompositedTransformTarget(
        link: _layerLink,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onPanStart: (_) {
              if (!_isStashed) {
                setState(() => _isDragging = true);
              }
            },
            onPanUpdate: _isStashed ? null : _updatePosition,
            onPanEnd: _isStashed ? null : _snapToEdge,
            onTap: _isStashed ? _unstash : null,
            child: AnimatedBuilder(
              animation: _opacityAnimation ?? const AlwaysStoppedAnimation(1.0),
              builder: (context, child) {
                return Opacity(
                  opacity: _opacityAnimation?.value ?? 1.0,
                  child: _TraceXFab(
                    onConsoleClosed: _startStashTimer,
                    instance: widget.instance,
                    isDragging: _isDragging,
                    isStashed: _isStashed,
                    fabState: _fabState,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TraceXFab extends StatefulWidget {
  final TraceX instance;
  final TraceXFabState fabState;
  final VoidCallback? onConsoleClosed;
  final bool isDragging;
  final bool isStashed;

  const _TraceXFab({
    required this.instance,
    required this.fabState,
    this.onConsoleClosed,
    this.isDragging = false,
    this.isStashed = false,
  });

  @override
  _TraceXFabState createState() => _TraceXFabState();
}

class _TraceXFabState extends State<_TraceXFab> {
  @override
  void setState(VoidCallback fn) {
    if (mounted) super.setState(fn);
  }

  Future<void> _onPressed() async {
    if (widget.isDragging) return;

    if (widget.fabState.isOpened) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => TraceXHomeScreen(widget.instance),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.fabState.listener,
      builder: (_, bool isOpen, Widget? child) {
        if (!isOpen) widget.onConsoleClosed?.call();

        final buttonSize = widget.instance.buttonSize;
        final floatingButton = widget.instance.customFab?.call(isOpen) ?? 
            _DefaultFab(isOpen: isOpen);

        return SizedBox(
          width: buttonSize,
          height: buttonSize,
          child: widget.isStashed
              ? floatingButton
              : GestureDetector(
                  onTap: _onPressed,
                  child: floatingButton,
                ),
        );
      },
    );
  }
}

class _DefaultFab extends StatelessWidget {
  const _DefaultFab({required this.isOpen});

  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isOpen ? TraceXColors.red : TraceXColors.blue,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isOpen ? Icons.close : Icons.terminal,
        size: 28,
        color: Colors.white,
      ),
    );
  }
}

