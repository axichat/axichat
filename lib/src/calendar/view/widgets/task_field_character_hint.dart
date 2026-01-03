// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';

const double _taskTitleLimitWarningBottomPadding = 4;
const double _taskTitleLimitWarningFontSize = 12;

/// Displays a live-updating character count for title fields and surfaces a
/// warning when the task title exceeds the configured limit.
class TaskFieldCharacterHint extends StatelessWidget {
  const TaskFieldCharacterHint({
    super.key,
    required this.controller,
    this.limit = calendarTaskTitleMaxLength,
    this.padding = const EdgeInsets.only(top: 6),
    this.showWarningText = true,
  });

  final TextEditingController controller;
  final int limit;
  final EdgeInsetsGeometry padding;
  final bool showWarningText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final int length = TaskTitleValidation.characterCount(value.text);
        final bool overLimit = length > limit;
        final Color counterColor =
            overLimit ? calendarDangerColor : calendarSubtitleColor;

        return Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showWarningText && overLimit)
                const Padding(
                  padding: EdgeInsets.only(
                    bottom: _taskTitleLimitWarningBottomPadding,
                  ),
                  child: _TaskTitleLimitWarningText(),
                ),
              Text(
                '$length / $limit characters',
                style: TextStyle(
                  color: counterColor,
                  fontSize: _taskTitleLimitWarningFontSize,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskTitleLimitWarningText extends StatelessWidget {
  const _TaskTitleLimitWarningText();

  @override
  Widget build(BuildContext context) {
    return Text(
      calendarTaskTitleLimitWarning,
      style: TextStyle(
        color: calendarDangerColor,
        fontSize: _taskTitleLimitWarningFontSize,
      ),
    );
  }
}
