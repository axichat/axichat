// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/widgets.dart';

@immutable
class CalendarDragExcludeMarker {
  const CalendarDragExcludeMarker();
}

class CalendarDragExclude extends StatelessWidget {
  const CalendarDragExclude({
    super.key,
    required this.child,
  });

  static const CalendarDragExcludeMarker marker = CalendarDragExcludeMarker();

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: marker,
      behavior: HitTestBehavior.deferToChild,
      child: child,
    );
  }
}
