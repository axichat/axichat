import 'dart:async';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/widgets.dart';

class CalendarHoverTitleController extends ChangeNotifier {
  CalendarHoverTitleController({
    this.settleDuration = calendarHoverTitleSettleDuration,
  });

  final Duration settleDuration;

  Timer? _settleTimer;
  bool _isInteracting = false;
  String? _title;
  String? _pendingTitle;

  String? get title => _title;

  void beginInteraction() {
    _isInteracting = true;
    clear();
  }

  void endInteraction() {
    _isInteracting = false;
  }

  void hover(String title) {
    final String trimmed = title.trim();
    if (_isInteracting || trimmed.isEmpty) {
      return;
    }

    _pendingTitle = trimmed;
    _settleTimer?.cancel();
    _settleTimer = Timer(settleDuration, () {
      if (_isInteracting) {
        return;
      }
      final String? pending = _pendingTitle;
      if (pending == null || pending.isEmpty || pending == _title) {
        return;
      }
      _title = pending;
      notifyListeners();
    });
  }

  void clear() {
    _pendingTitle = null;
    _settleTimer?.cancel();
    _settleTimer = null;
    if (_title == null) {
      return;
    }
    _title = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _settleTimer?.cancel();
    _settleTimer = null;
    super.dispose();
  }
}

class CalendarHoverTitleScope
    extends InheritedNotifier<CalendarHoverTitleController> {
  const CalendarHoverTitleScope({
    super.key,
    required CalendarHoverTitleController controller,
    required super.child,
  }) : super(notifier: controller);

  static CalendarHoverTitleController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<CalendarHoverTitleScope>()
      ?.notifier;
}
