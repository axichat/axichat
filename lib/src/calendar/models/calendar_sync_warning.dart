// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';

@immutable
class CalendarSyncWarning {
  const CalendarSyncWarning({required this.type});

  final CalendarSyncWarningType type;
}

enum CalendarSyncWarningType { snapshotUnavailable }
