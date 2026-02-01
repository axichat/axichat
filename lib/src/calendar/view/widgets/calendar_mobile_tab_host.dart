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
