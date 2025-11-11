import 'package:flutter/material.dart';

import '../../../common/ui/ui.dart';
import '../../constants.dart';
import '../../utils/task_title_validation.dart';

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
                  padding: EdgeInsets.only(bottom: 4),
                  child: Text(
                    calendarTaskTitleLimitWarning,
                    style: TextStyle(
                      color: calendarDangerColor,
                      fontSize: 12,
                    ),
                  ),
                ),
              Text(
                '$length / $limit characters',
                style: TextStyle(
                  color: counterColor,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
