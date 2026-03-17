// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';

enum CalendarTaskOffGridDragRegion {
  calendarShell,
  composeWindow,
  compactBottomBar,
}

class CalendarTaskOffGridDragController extends ChangeNotifier
    implements ValueListenable<bool> {
  CalendarTaskOffGridDragController()
    : _regionTokens = {
        for (final region in CalendarTaskOffGridDragRegion.values)
          region: <Object>{},
      },
      _regionNotifiers = {
        for (final region in CalendarTaskOffGridDragRegion.values)
          region: ValueNotifier<bool>(false),
      };

  final Map<CalendarTaskOffGridDragRegion, Set<Object>> _regionTokens;
  final Map<CalendarTaskOffGridDragRegion, ValueNotifier<bool>>
  _regionNotifiers;

  @override
  bool get value => _regionTokens.values.any((tokens) => tokens.isNotEmpty);

  ValueListenable<bool> listenableFor(CalendarTaskOffGridDragRegion region) {
    return _regionNotifiers[region]!;
  }

  void setRegionActive({
    required CalendarTaskOffGridDragRegion region,
    required Object token,
    required bool isActive,
  }) {
    final tokens = _regionTokens[region]!;
    final bool wasAnyActive = value;
    final bool changed = isActive ? tokens.add(token) : tokens.remove(token);
    if (!changed) {
      return;
    }
    final bool isRegionActive = tokens.isNotEmpty;
    final regionNotifier = _regionNotifiers[region]!;
    if (regionNotifier.value != isRegionActive) {
      regionNotifier.value = isRegionActive;
    }
    if (wasAnyActive != value) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final notifier in _regionNotifiers.values) {
      notifier.dispose();
    }
    super.dispose();
  }
}
