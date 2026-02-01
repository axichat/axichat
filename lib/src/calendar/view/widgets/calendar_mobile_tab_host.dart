// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

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

  CalendarMobileTabHostData? get data => _data;

  void update(CalendarMobileTabHostData data) {
    _data = data;
    notifyListeners();
  }

  void clear() {
    if (_data == null) return;
    _data = null;
    notifyListeners();
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
