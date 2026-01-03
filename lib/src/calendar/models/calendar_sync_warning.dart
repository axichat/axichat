// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/foundation.dart';

@immutable
class CalendarSyncWarning {
  const CalendarSyncWarning({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;
}
