// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/calendar_fragment_policy.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:flutter/material.dart';

const double _fragmentCardRadius = 18.0;
const double _fragmentAccentWidth = 4.0;
const double _fragmentAccentRadius = 14.0;
const double _fragmentContentSpacing = 6.0;
const double _fragmentLabelSpacing = 2.0;
const double _fragmentInfoSpacing = 4.0;
const double _fragmentChecklistSpacing = 4.0;
const double _fragmentChecklistIndent = 12.0;
const double _fragmentCriticalPathIndent = 14.0;
const double _fragmentLabelLetterSpacing = 1.1;
const int _fragmentDescriptionMaxLines = 3;
const int _fragmentChecklistMaxLines = 4;
const int _fragmentChecklistPreviewLimit = 4;
const int _fragmentCriticalPathPreviewLimit = 4;

const EdgeInsets _fragmentCardPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 10);
const EdgeInsets _fragmentFooterPadding = EdgeInsets.only(top: 4);
const EdgeInsets _fragmentChecklistBulletPadding = EdgeInsets.only(top: 2);
const EdgeInsets _fragmentChecklistMorePadding =
    EdgeInsets.only(left: _fragmentChecklistIndent);
const EdgeInsets _fragmentCriticalPathMorePadding =
    EdgeInsets.only(left: _fragmentCriticalPathIndent);

const String _fragmentLabelTask = 'Task';
const String _fragmentLabelChecklist = 'Checklist';
const String _fragmentLabelReminder = 'Reminder';
const String _fragmentLabelDayEvent = 'Day event';
const String _fragmentLabelCriticalPath = 'Critical path';
const String _fragmentLabelFreeBusy = 'Free/busy';
const String _fragmentLabelAvailability = 'Availability';

const String _fragmentFallbackTitle = 'Untitled';
const String _fragmentChecklistBullet = '- ';
const String _fragmentCriticalPathBullet = '• ';
const String _fragmentChecklistMorePrefix = 'and ';
const String _fragmentChecklistMoreSuffix = ' more';
const String _fragmentCriticalPathMorePrefix = 'and ';
const String _fragmentCriticalPathMoreSuffix = ' more';
const String _fragmentReminderEmptyLabel = 'No reminders';
const String _fragmentScheduleLabel = 'Scheduled';
const String _fragmentDueLabel = 'Due';
const String _fragmentCriticalPathProgressLabel = 'Progress';
const String _fragmentCriticalPathEmptyLabel = 'No tasks yet';
const String _fragmentCriticalPathProgressSeparator = ' / ';
const String _fragmentRangeSeparator = ' - ';
const String _fragmentReminderSeparator = ', ';
const String _fragmentReminderStartLabel = 'Start';
const String _fragmentReminderDeadlineLabel = 'Deadline';
const String _fragmentInfoSeparator = ': ';
const String _emptyText = '';

const List<InlineSpan> _emptyInlineSpans = <InlineSpan>[];

class CalendarFragmentCard extends StatelessWidget {
  const CalendarFragmentCard({
    super.key,
    required this.fragment,
    this.footerDetails = _emptyInlineSpans,
    this.onTap,
  });

  final CalendarFragment fragment;
  final List<InlineSpan> footerDetails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final accentColor = colors.primary;
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(_fragmentCardRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarFragmentAccent(color: accentColor),
          Expanded(
            child: Padding(
              padding: _fragmentCardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: _fragmentContentSpacing,
                children: [
                  _CalendarFragmentBody(fragment: fragment),
                  if (footerDetails.isNotEmpty)
                    Padding(
                      padding: _fragmentFooterPadding,
                      child: ChatInlineDetails(details: footerDetails),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return card;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_fragmentCardRadius),
        child: card,
      ),
    );
  }
}

class _CalendarFragmentAccent extends StatelessWidget {
  const _CalendarFragmentAccent({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _fragmentAccentWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(_fragmentAccentRadius),
        ),
      ),
    );
  }
}

class _CalendarFragmentBody extends StatelessWidget {
  const _CalendarFragmentBody({required this.fragment});

  final CalendarFragment fragment;

  @override
  Widget build(BuildContext context) {
    return fragment.map(
      task: (value) => _TaskFragmentBody(task: value.task),
      checklist: (value) => _ChecklistFragmentBody(checklist: value.checklist),
      reminder: (value) => _ReminderFragmentBody(reminders: value.reminders),
      dayEvent: (value) => _DayEventFragmentBody(event: value.event),
      criticalPath: (value) => _CriticalPathFragmentBody(
        path: value.path,
        tasks: value.tasks,
      ),
      freeBusy: (value) => _FreeBusyFragmentBody(interval: value.interval),
      availability: (value) => _AvailabilityFragmentBody(window: value.window),
    );
  }
}

class _TaskFragmentBody extends StatelessWidget {
  const _TaskFragmentBody({required this.task});

  final CalendarTask task;

  @override
  Widget build(BuildContext context) {
    final title = _sanitizeTitle(task.title);
    final description = task.description?.trim();
    final info = _taskInfo(task);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelTask),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: _fragmentLabelSpacing,
          children: [
            Text(
              title,
              style: context.textTheme.large.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (description != null && description.isNotEmpty)
              Text(
                description,
                style: context.textTheme.small.copyWith(
                  color: context.colorScheme.mutedForeground,
                ),
                maxLines: _fragmentDescriptionMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        if (info.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _fragmentInfoSpacing,
            children: [
              for (final item in info)
                _FragmentInfoLine(
                  label: item.label,
                  value: item.value,
                ),
            ],
          ),
      ],
    );
  }

  String _sanitizeTitle(String value) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : _fragmentFallbackTitle;
  }

  List<_FragmentInfo> _taskInfo(CalendarTask task) {
    final info = <_FragmentInfo>[];
    final scheduledTime = task.scheduledTime;
    if (scheduledTime != null) {
      final endTime = _taskEndTime(task);
      final scheduleValue = endTime == null
          ? TimeFormatter.formatFriendlyDateTime(scheduledTime)
          : '${TimeFormatter.formatFriendlyDateTime(scheduledTime)}'
              '$_fragmentRangeSeparator'
              '${TimeFormatter.formatFriendlyDateTime(endTime)}';
      info.add(
        _FragmentInfo(
          label: _fragmentScheduleLabel,
          value: scheduleValue,
        ),
      );
    }
    final deadline = task.deadline;
    if (deadline != null) {
      info.add(
        _FragmentInfo(
          label: _fragmentDueLabel,
          value: TimeFormatter.formatFriendlyDateTime(deadline),
        ),
      );
    }
    return info;
  }

  DateTime? _taskEndTime(CalendarTask task) {
    final endDate = task.endDate;
    if (endDate != null) {
      return endDate;
    }
    final scheduled = task.scheduledTime;
    final duration = task.duration;
    if (scheduled != null && duration != null) {
      return scheduled.add(duration);
    }
    return null;
  }
}

class _ChecklistFragmentBody extends StatelessWidget {
  const _ChecklistFragmentBody({required this.checklist});

  final List<TaskChecklistItem> checklist;

  @override
  Widget build(BuildContext context) {
    final visibleItems = checklist.length <= _fragmentChecklistPreviewLimit
        ? checklist
        : checklist.sublist(0, _fragmentChecklistPreviewLimit);
    final remaining = checklist.length - visibleItems.length;
    final textStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.foreground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelChecklist),
        if (visibleItems.isEmpty)
          Text(
            _fragmentFallbackTitle,
            style: textStyle,
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _fragmentChecklistSpacing,
            children: [
              for (final item in visibleItems)
                _ChecklistItemRow(
                  label: item.label,
                  completed: item.isCompleted,
                ),
              if (remaining > 0)
                Padding(
                  padding: _fragmentChecklistMorePadding,
                  child: Text(
                    '$_fragmentChecklistMorePrefix$remaining'
                    '$_fragmentChecklistMoreSuffix',
                    style: context.textTheme.small.copyWith(
                      color: context.colorScheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _ChecklistItemRow extends StatelessWidget {
  const _ChecklistItemRow({
    required this.label,
    required this.completed,
  });

  final String label;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: completed ? colors.mutedForeground : colors.foreground,
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    final resolvedLabel = label.trim().isEmpty ? _fragmentFallbackTitle : label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _fragmentChecklistBulletPadding,
          child: Text(
            _fragmentChecklistBullet,
            style: textStyle,
          ),
        ),
        Expanded(
          child: Text(
            resolvedLabel,
            style: textStyle,
            maxLines: _fragmentChecklistMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _CriticalPathFragmentBody extends StatelessWidget {
  const _CriticalPathFragmentBody({
    required this.path,
    required this.tasks,
  });

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context) {
    final String title =
        path.name.trim().isNotEmpty ? path.name.trim() : _fragmentFallbackTitle;
    final List<CalendarTask> orderedTasks = _orderedTasks();
    final int total = orderedTasks.length;
    final int completed = orderedTasks.where((task) => task.isCompleted).length;
    final TextStyle emptyStyle = context.textTheme.small.copyWith(
      color: context.colorScheme.mutedForeground,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelCriticalPath),
        Text(
          title,
          style: context.textTheme.large.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (total > 0)
          _FragmentInfoLine(
            label: _fragmentCriticalPathProgressLabel,
            value: '$completed$_fragmentCriticalPathProgressSeparator$total',
          )
        else
          Text(
            _fragmentCriticalPathEmptyLabel,
            style: emptyStyle,
          ),
        if (total > 0)
          _CriticalPathTaskList(
            tasks: orderedTasks,
          ),
      ],
    );
  }

  List<CalendarTask> _orderedTasks() {
    if (tasks.isEmpty) {
      return const <CalendarTask>[];
    }
    final Map<String, CalendarTask> taskById = <String, CalendarTask>{
      for (final task in tasks) task.id: task,
    };
    final List<CalendarTask> ordered = <CalendarTask>[];
    for (final String id in path.taskIds) {
      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? task = taskById[baseId] ?? taskById[id];
      if (task != null) {
        ordered.add(task);
      }
    }
    if (ordered.isNotEmpty) {
      return ordered;
    }
    return tasks;
  }
}

class _CriticalPathTaskList extends StatelessWidget {
  const _CriticalPathTaskList({
    required this.tasks,
  });

  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context) {
    final List<CalendarTask> visible =
        tasks.length <= _fragmentCriticalPathPreviewLimit
            ? tasks
            : tasks.sublist(0, _fragmentCriticalPathPreviewLimit);
    final int remaining = tasks.length - visible.length;
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentChecklistSpacing,
      children: [
        for (final task in visible)
          _CriticalPathTaskRow(
            title: task.title,
            completed: task.isCompleted,
          ),
        if (remaining > 0)
          Padding(
            padding: _fragmentCriticalPathMorePadding,
            child: Text(
              '$_fragmentCriticalPathMorePrefix$remaining'
              '$_fragmentCriticalPathMoreSuffix',
              style: textTheme.small.copyWith(
                color: context.colorScheme.mutedForeground,
              ),
            ),
          ),
      ],
    );
  }
}

class _CriticalPathTaskRow extends StatelessWidget {
  const _CriticalPathTaskRow({
    required this.title,
    required this.completed,
  });

  final String title;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: completed ? colors.mutedForeground : colors.foreground,
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    final String resolvedTitle =
        title.trim().isEmpty ? _fragmentFallbackTitle : title;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _fragmentChecklistBulletPadding,
          child: Text(
            _fragmentCriticalPathBullet,
            style: textStyle,
          ),
        ),
        Expanded(
          child: Text(
            resolvedTitle,
            style: textStyle,
            maxLines: _fragmentChecklistMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _ReminderFragmentBody extends StatelessWidget {
  const _ReminderFragmentBody({required this.reminders});

  final ReminderPreferences reminders;

  @override
  Widget build(BuildContext context) {
    final reminderText = _reminderSummary(reminders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelReminder),
        Text(
          reminderText,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
      ],
    );
  }

  String _reminderSummary(ReminderPreferences reminders) {
    if (!reminders.isEnabled) {
      return _fragmentReminderEmptyLabel;
    }
    final startLabel = _offsetSummary(reminders.startOffsets);
    final deadlineLabel = _offsetSummary(reminders.deadlineOffsets);
    final parts = <String>[];
    if (startLabel.isNotEmpty) {
      parts.add(
        '$_fragmentReminderStartLabel$_fragmentInfoSeparator$startLabel',
      );
    }
    if (deadlineLabel.isNotEmpty) {
      parts.add(
        '$_fragmentReminderDeadlineLabel$_fragmentInfoSeparator$deadlineLabel',
      );
    }
    if (parts.isEmpty) {
      return _fragmentReminderEmptyLabel;
    }
    return parts.join(_fragmentReminderSeparator);
  }

  String _offsetSummary(List<Duration> offsets) {
    if (offsets.isEmpty) return _emptyText;
    final labels =
        offsets.map(TimeFormatter.formatDuration).toList(growable: false);
    return labels.join(_fragmentReminderSeparator);
  }
}

class _DayEventFragmentBody extends StatelessWidget {
  const _DayEventFragmentBody({required this.event});

  final DayEvent event;

  @override
  Widget build(BuildContext context) {
    final title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : _fragmentFallbackTitle;
    final description = event.description?.trim();
    final dateLabel = _dateRange(event.startDate, event.endDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelDayEvent),
        Text(
          title,
          style: context.textTheme.large.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (description != null && description.isNotEmpty)
          Text(
            description,
            style: context.textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
            maxLines: _fragmentDescriptionMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        _FragmentInfoLine(
          label: _fragmentScheduleLabel,
          value: dateLabel,
        ),
      ],
    );
  }

  String _dateRange(DateTime start, DateTime? end) {
    final startLabel = TimeFormatter.formatFriendlyDate(start);
    final endLabel = end == null ? null : TimeFormatter.formatFriendlyDate(end);
    if (endLabel == null || endLabel == startLabel) {
      return startLabel;
    }
    return '$startLabel$_fragmentRangeSeparator$endLabel';
  }
}

class _FreeBusyFragmentBody extends StatelessWidget {
  const _FreeBusyFragmentBody({required this.interval});

  final CalendarFreeBusyInterval interval;

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _dateTimeRange(
      interval.start.value,
      interval.end.value,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelFreeBusy),
        Text(
          interval.type.label,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
        _FragmentInfoLine(
          label: _fragmentScheduleLabel,
          value: rangeLabel,
        ),
      ],
    );
  }

  String _dateTimeRange(DateTime start, DateTime end) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return '$startLabel$_fragmentRangeSeparator$endLabel';
  }
}

class _AvailabilityFragmentBody extends StatelessWidget {
  const _AvailabilityFragmentBody({required this.window});

  final CalendarAvailabilityWindow window;

  @override
  Widget build(BuildContext context) {
    final summary = window.summary?.trim();
    final description = window.description?.trim();
    final rangeLabel = _dateTimeRange(window.start.value, window.end.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        const _FragmentLabel(text: _fragmentLabelAvailability),
        if (summary != null && summary.isNotEmpty)
          Text(
            summary,
            style: context.textTheme.large.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        if (description != null && description.isNotEmpty)
          Text(
            description,
            style: context.textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
            maxLines: _fragmentDescriptionMaxLines,
            overflow: TextOverflow.ellipsis,
          ),
        _FragmentInfoLine(
          label: _fragmentScheduleLabel,
          value: rangeLabel,
        ),
      ],
    );
  }

  String _dateTimeRange(DateTime start, DateTime end) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return '$startLabel$_fragmentRangeSeparator$endLabel';
  }
}

class _FragmentLabel extends StatelessWidget {
  const _FragmentLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Text(
      text.toUpperCase(),
      style: context.textTheme.muted.copyWith(
        color: colors.mutedForeground,
        letterSpacing: _fragmentLabelLetterSpacing,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _FragmentInfoLine extends StatelessWidget {
  const _FragmentInfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final labelStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
    );
    return Text.rich(
      TextSpan(
        text: '$label$_fragmentInfoSeparator',
        style: labelStyle,
        children: [
          TextSpan(
            text: value,
            style: valueStyle,
          ),
        ],
      ),
    );
  }
}

class _FragmentInfo {
  const _FragmentInfo({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}
