// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

class TaskDeadlineBadge extends StatelessWidget {
  const TaskDeadlineBadge({super.key, required this.deadline});

  final DateTime deadline;

  @override
  Widget build(BuildContext context) {
    final color = _deadlineColor(deadline);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: _deadlineBackgroundColor(deadline),
        borderRadius: context.radius,
      ),
      child: Text(
        '${context.l10n.calendarFragmentDueLabel}: '
        '${TimeFormatter.formatFriendlyDateTime(context.l10n, deadline)}',
        style: context.textTheme.label.strong.copyWith(color: color),
      ),
    );
  }
}

Color _deadlineColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor;
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor;
  }
  return calendarPrimaryColor;
}

Color _deadlineBackgroundColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor.withValues(alpha: 0.1);
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor.withValues(alpha: 0.1);
  }
  return calendarPrimaryColor.withValues(alpha: 0.08);
}
