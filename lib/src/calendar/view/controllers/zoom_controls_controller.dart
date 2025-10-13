import 'dart:async';

import 'package:flutter/foundation.dart';

/// Handles the auto-hide lifecycle for zoom controls so the widget tree can
/// remain declarative.
class ZoomControlsController extends ChangeNotifier {
  ZoomControlsController({
    Duration autoHideDuration = const Duration(seconds: 6),
  })  : _autoHideDuration = autoHideDuration,
        _isVisible = false;

  final Duration _autoHideDuration;
  bool _isVisible;
  Timer? _autoHideTimer;
  bool _disposed = false;

  bool get isVisible => _isVisible;

  void show() {
    _startTimer();
    _setVisible(true);
  }

  void hide() {
    _autoHideTimer?.cancel();
    _setVisible(false);
  }

  void _startTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(_autoHideDuration, () {
      if (_disposed) return;
      _setVisible(false);
    });
  }

  void _setVisible(bool next) {
    if (_isVisible == next || _disposed) {
      return;
    }
    _isVisible = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _autoHideTimer?.cancel();
    super.dispose();
  }
}
