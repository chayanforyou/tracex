import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

class TraceXFabState {
  TraceXFabState._internal();

  static final TraceXFabState _instance = TraceXFabState._internal();

  factory TraceXFabState() => _instance;

  final ValueNotifier<bool> _isOpened = ValueNotifier(false);

  ValueListenable<bool> get listener => _isOpened;

  bool get isOpened => _isOpened.value;

  void open() {
    _deferUpdate(true);
  }

  void close() {
    _deferUpdate(false);
  }

  void _deferUpdate(bool value) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _isOpened.value = value;
    });
  }
}