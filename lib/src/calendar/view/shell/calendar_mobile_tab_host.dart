// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';

class CalendarMobileTabHostData {
  const CalendarMobileTabHostData({
    required this.tabSwitcher,
    required this.cancelBucket,
  });

  final Widget tabSwitcher;
  final Widget cancelBucket;
}

class CalendarMobileTabHostController extends ChangeNotifier {
  CalendarMobileTabHostData? _data;
  bool _notificationScheduled = false;
  bool _disposed = false;

  CalendarMobileTabHostData? get data => _data;

  void update(CalendarMobileTabHostData data) {
    if (identical(_data, data)) {
      return;
    }
    _data = data;
    _notifyListenersSafely();
  }

  void clear() {
    if (_data == null) return;
    _data = null;
    _notifyListenersSafely();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  void _notifyListenersSafely() {
    if (_disposed || !hasListeners) {
      return;
    }
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
      return;
    }
    if (_notificationScheduled) {
      return;
    }
    _notificationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationScheduled = false;
      if (_disposed || !hasListeners) {
        return;
      }
      notifyListeners();
    });
  }
}

class CalendarMobileTabHostPublisher extends StatefulWidget {
  const CalendarMobileTabHostPublisher({
    super.key,
    required this.data,
    required this.child,
  });

  final CalendarMobileTabHostData data;
  final Widget child;

  @override
  State<CalendarMobileTabHostPublisher> createState() =>
      _CalendarMobileTabHostPublisherState();
}

class _CalendarMobileTabHostPublisherState
    extends State<CalendarMobileTabHostPublisher> {
  CalendarMobileTabHostController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = CalendarMobileTabHostScope.maybeOf(context);
    if (controller != _controller) {
      _controller?.clear();
      _controller = controller;
    }
    _publish();
  }

  @override
  void didUpdateWidget(covariant CalendarMobileTabHostPublisher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data) {
      _publish();
    }
  }

  @override
  void dispose() {
    _controller?.clear();
    super.dispose();
  }

  void _publish() {
    final controller = _controller;
    if (controller == null) {
      return;
    }
    controller.update(widget.data);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class CalendarMobileTabHostScope
    extends InheritedNotifier<CalendarMobileTabHostController> {
  const CalendarMobileTabHostScope({
    super.key,
    required CalendarMobileTabHostController controller,
    required super.child,
  }) : super(notifier: controller);

  static CalendarMobileTabHostController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<CalendarMobileTabHostScope>()
        ?.notifier;
  }
}
