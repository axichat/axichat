// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/chat/view/widgets/chat_inline_details.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
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

const EdgeInsets _fragmentCardPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 10,
);
const EdgeInsets _fragmentFooterPadding = EdgeInsets.only(top: 4);
const EdgeInsets _fragmentChecklistBulletPadding = EdgeInsets.only(top: 2);
const EdgeInsets _fragmentChecklistMorePadding = EdgeInsets.only(
  left: _fragmentChecklistIndent,
);
const EdgeInsets _fragmentCriticalPathMorePadding = EdgeInsets.only(
  left: _fragmentCriticalPathIndent,
);

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
    final bool isTaskFragment =
        fragment.maybeMap(task: (_) => true, orElse: () => false);
    if (isTaskFragment) {
      return _TaskFragmentCard(
        fragment: fragment,
        accentColor: colors.primary,
        footerDetails: footerDetails,
        onTap: onTap,
      );
    }
    const double cardRadius = _fragmentCardRadius;
    const double accentRadius = _fragmentAccentRadius;
    final card = DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CalendarFragmentAccent(
            color: colors.primary,
            radius: accentRadius,
          ),
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
        borderRadius: BorderRadius.circular(cardRadius),
        child: card,
      ),
    );
  }
}

class _TaskFragmentCard extends StatelessWidget {
  const _TaskFragmentCard({
    required this.fragment,
    required this.accentColor,
    required this.footerDetails,
    this.onTap,
  });

  final CalendarFragment fragment;
  final Color accentColor;
  final List<InlineSpan> footerDetails;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const double accentWidth = _fragmentAccentWidth;
    const double cardRadius = calendarEventRadius;
    return Container(
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(cardRadius),
        boxShadow: calendarLightShadow,
        border: Border.all(color: calendarBorderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(cardRadius),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: accentWidth,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(calendarEventRadius),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(context.spacing.m),
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
        ),
      ),
    );
  }
}

class _CalendarFragmentAccent extends StatelessWidget {
  const _CalendarFragmentAccent({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _fragmentAccentWidth,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(radius),
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
      criticalPath: (value) =>
          _CriticalPathFragmentBody(path: value.path, tasks: value.tasks),
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
    final l10n = context.l10n;
    final title = _sanitizeTitle(
      task.title,
      l10n.calendarFragmentUntitledLabel,
    );
    final description = task.description?.trim();
    final info = _taskInfo(
      l10n,
      task,
      scheduleLabel: l10n.calendarFragmentScheduledLabel,
      dueLabel: l10n.calendarFragmentDueLabel,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        _FragmentLabel(text: l10n.calendarFragmentTaskLabel),
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
                _FragmentInfoLine(label: item.label, value: item.value),
            ],
          ),
      ],
    );
  }

  String _sanitizeTitle(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : fallback;
  }

  List<_FragmentInfo> _taskInfo(
    AppLocalizations l10n,
    CalendarTask task, {
    required String scheduleLabel,
    required String dueLabel,
  }) {
    final info = <_FragmentInfo>[];
    final scheduledTime = task.scheduledTime;
    if (scheduledTime != null) {
      final endTime = _taskEndTime(task);
      final scheduleValue = endTime == null
          ? TimeFormatter.formatFriendlyDateTime(l10n, scheduledTime)
          : l10n.commonRangeLabel(
              TimeFormatter.formatFriendlyDateTime(
                l10n,
                scheduledTime,
              ),
              TimeFormatter.formatFriendlyDateTime(l10n, endTime),
            );
      info.add(
        _FragmentInfo(label: scheduleLabel, value: scheduleValue),
      );
    }
    final deadline = task.deadline;
    if (deadline != null) {
      info.add(
        _FragmentInfo(
          label: dueLabel,
          value: TimeFormatter.formatFriendlyDateTime(l10n, deadline),
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
    final l10n = context.l10n;
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
        _FragmentLabel(text: l10n.calendarFragmentChecklistLabel),
        if (visibleItems.isEmpty)
          Text(l10n.calendarFragmentUntitledLabel, style: textStyle)
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: _fragmentChecklistSpacing,
            children: [
              for (final item in visibleItems)
                _ChecklistItemRow(
                  label: item.label,
                  completed: item.isCompleted,
                  bullet: l10n.calendarFragmentChecklistBullet,
                ),
              if (remaining > 0)
                Padding(
                  padding: _fragmentChecklistMorePadding,
                  child: Text(
                    l10n.commonAndMoreLabel(remaining),
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
    required this.bullet,
  });

  final String label;
  final bool completed;
  final String bullet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: completed ? colors.mutedForeground : colors.foreground,
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    final resolvedLabel = label.trim().isEmpty
        ? context.l10n.calendarFragmentUntitledLabel
        : label;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _fragmentChecklistBulletPadding,
          child: Text(bullet, style: textStyle),
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
  const _CriticalPathFragmentBody({required this.path, required this.tasks});

  final CalendarCriticalPath path;
  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final String title = path.name.trim().isNotEmpty
        ? path.name.trim()
        : l10n.calendarFragmentUntitledLabel;
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
        _FragmentLabel(text: l10n.calendarFragmentCriticalPathLabel),
        Text(
          title,
          style: context.textTheme.large.copyWith(fontWeight: FontWeight.w600),
        ),
        if (total > 0)
          _FragmentInfoLine(
            label: l10n.calendarCriticalPathProgressLabel,
            value: l10n.calendarFragmentCriticalPathProgress(
              completed,
              total,
            ),
          )
        else
          Text(l10n.calendarCriticalPathEmptyTasks, style: emptyStyle),
        if (total > 0) _CriticalPathTaskList(tasks: orderedTasks),
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
  const _CriticalPathTaskList({required this.tasks});

  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
            bullet: l10n.commonBulletSymbol,
          ),
        if (remaining > 0)
          Padding(
            padding: _fragmentCriticalPathMorePadding,
            child: Text(
              l10n.commonAndMoreLabel(remaining),
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
    required this.bullet,
  });

  final String title;
  final bool completed;
  final String bullet;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textStyle = context.textTheme.small.copyWith(
      color: completed ? colors.mutedForeground : colors.foreground,
      decoration: completed ? TextDecoration.lineThrough : null,
    );
    final String resolvedTitle = title.trim().isNotEmpty
        ? title
        : context.l10n.calendarFragmentUntitledLabel;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: _fragmentChecklistBulletPadding,
          child: Text(bullet, style: textStyle),
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
    final l10n = context.l10n;
    final reminderText = _reminderSummary(l10n, reminders);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        _FragmentLabel(text: l10n.calendarFragmentRemindersLabel),
        Text(
          reminderText,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
      ],
    );
  }

  String _reminderSummary(
      AppLocalizations l10n, ReminderPreferences reminders) {
    if (!reminders.isEnabled) {
      return l10n.calendarRemindersEmptyLabel;
    }
    final startLabel = _offsetSummary(l10n, reminders.startOffsets);
    final deadlineLabel = _offsetSummary(l10n, reminders.deadlineOffsets);
    final parts = <String>[];
    if (startLabel.isNotEmpty) {
      parts.add(l10n.calendarFragmentReminderStartSummary(startLabel));
    }
    if (deadlineLabel.isNotEmpty) {
      parts.add(l10n.calendarFragmentReminderDeadlineSummary(deadlineLabel));
    }
    if (parts.isEmpty) {
      return l10n.calendarRemindersEmptyLabel;
    }
    return parts.join(l10n.calendarFragmentReminderSeparator);
  }

  String _offsetSummary(AppLocalizations l10n, List<Duration> offsets) {
    if (offsets.isEmpty) return '';
    final labels = offsets
        .map((duration) => TimeFormatter.formatDuration(l10n, duration))
        .toList(growable: false);
    return labels.join(l10n.calendarFragmentReminderSeparator);
  }
}

class _DayEventFragmentBody extends StatelessWidget {
  const _DayEventFragmentBody({required this.event});

  final DayEvent event;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = event.title.trim().isNotEmpty
        ? event.title.trim()
        : l10n.calendarFragmentEventTitleFallback;
    final description = event.description?.trim();
    final dateLabel = _dateRange(l10n, event.startDate, event.endDate);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        _FragmentLabel(text: l10n.calendarFragmentDayEventLabel),
        Text(
          title,
          style: context.textTheme.large.copyWith(fontWeight: FontWeight.w600),
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
          label: l10n.calendarFragmentScheduledLabel,
          value: dateLabel,
        ),
      ],
    );
  }

  String _dateRange(AppLocalizations l10n, DateTime start, DateTime? end) {
    final startLabel = TimeFormatter.formatFriendlyDate(start);
    final endLabel = end == null ? null : TimeFormatter.formatFriendlyDate(end);
    if (endLabel == null || endLabel == startLabel) {
      return startLabel;
    }
    return l10n.commonRangeLabel(startLabel, endLabel);
  }
}

class _FreeBusyFragmentBody extends StatelessWidget {
  const _FreeBusyFragmentBody({required this.interval});

  final CalendarFreeBusyInterval interval;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rangeLabel =
        _dateTimeRange(l10n, interval.start.value, interval.end.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        _FragmentLabel(text: l10n.calendarFragmentFreeBusyLabel),
        Text(
          interval.type.label(l10n),
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.foreground,
          ),
        ),
        _FragmentInfoLine(
          label: l10n.calendarFragmentScheduledLabel,
          value: rangeLabel,
        ),
      ],
    );
  }

  String _dateTimeRange(AppLocalizations l10n, DateTime start, DateTime end) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(l10n, start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return l10n.commonRangeLabel(startLabel, endLabel);
  }
}

class _AvailabilityFragmentBody extends StatelessWidget {
  const _AvailabilityFragmentBody({required this.window});

  final CalendarAvailabilityWindow window;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = window.summary?.trim();
    final description = window.description?.trim();
    final rangeLabel =
        _dateTimeRange(l10n, window.start.value, window.end.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _fragmentContentSpacing,
      children: [
        _FragmentLabel(text: l10n.calendarFragmentAvailabilityLabel),
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
          label: l10n.calendarFragmentScheduledLabel,
          value: rangeLabel,
        ),
      ],
    );
  }

  String _dateTimeRange(AppLocalizations l10n, DateTime start, DateTime end) {
    final startLabel = TimeFormatter.formatFriendlyDateTime(l10n, start);
    final endLabel = TimeFormatter.formatFriendlyDateTime(l10n, end);
    if (startLabel == endLabel) {
      return startLabel;
    }
    return l10n.commonRangeLabel(startLabel, endLabel);
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
  const _FragmentInfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final labelStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final valueStyle = context.textTheme.small.copyWith(
      color: colors.foreground,
    );
    return Text.rich(
      TextSpan(
        text: '$label${l10n.commonLabelSeparator}',
        style: labelStyle,
        children: [TextSpan(text: value, style: valueStyle)],
      ),
    );
  }
}

class _FragmentInfo {
  const _FragmentInfo({required this.label, required this.value});

  final String label;
  final String value;
}
