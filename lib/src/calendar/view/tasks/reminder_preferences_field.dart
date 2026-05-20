// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_alarms_field.dart';
import 'package:axichat/src/calendar/view/tasks/recurrence_editor.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Declarative reminder selector that exposes start/deadline offsets as a set
/// of toggleable chips. Designed to be reused by quick add, sidebar, and
/// day-event composers.
const String _reminderSectionTitle = 'Reminders';
const String _reminderBeforeStartLabel = 'Before start';
const String _reminderBeforeDeadlineLabel = 'Before deadline';
const String _reminderAtStartLabel = 'At start';
const String _reminderAtDeadlineLabel = 'At deadline';
const String _reminderAdvancedLabel = 'Advanced alarms';
const String _reminderAdvancedActiveLabel = 'Active';
const String _reminderAdvancedSummary = 'Advanced alarms applied';
const double _reminderAdvancedBadgeOpacity = 0.16;
const double _reminderAdvancedBadgeRadius = 10;
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];

class ReminderPreferencesField extends StatefulWidget {
  const ReminderPreferencesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = _reminderSectionTitle,
    this.headerSize = TaskSectionLabelSize.medium,
    this.showHeader = true,
    this.anchor = ReminderAnchor.start,
    this.mixed = false,
    this.showBothAnchors = false,
    this.startOptions = calendarReminderStartOptions,
    this.deadlineOptions = calendarReminderDeadlineOptions,
    this.advancedAlarms,
    this.onAdvancedAlarmsChanged,
    this.referenceStart,
    this.showAdvancedAlarms = false,
    this.enabled = true,
  });

  final ReminderPreferences value;
  final ValueChanged<ReminderPreferences> onChanged;
  final String title;
  final TaskSectionLabelSize headerSize;
  final bool showHeader;
  final ReminderAnchor anchor;
  final bool mixed;
  final bool showBothAnchors;
  final List<Duration> startOptions;
  final List<Duration> deadlineOptions;
  final List<CalendarAlarm>? advancedAlarms;
  final ValueChanged<List<CalendarAlarm>>? onAdvancedAlarmsChanged;
  final DateTime? referenceStart;
  final bool showAdvancedAlarms;
  final bool enabled;

  @override
  State<ReminderPreferencesField> createState() =>
      _ReminderPreferencesFieldState();
}

class TaskReminderRepeatSection extends StatelessWidget {
  const TaskReminderRepeatSection({
    super.key,
    required this.reminders,
    required this.onRemindersChanged,
    required this.recurrence,
    required this.onRecurrenceChanged,
    this.deadline,
    this.referenceStart,
    this.advancedAlarms,
    this.onAdvancedAlarmsChanged,
    this.reminderTitle,
    this.showReminderHeader = true,
    this.reminderHeaderSize = TaskSectionLabelSize.medium,
    this.remindersMixed = false,
    this.reminderAnchor,
    this.showBothReminderAnchors,
    this.recurrenceTitle,
    this.recurrenceHeaderSize = TaskSectionLabelSize.small,
    this.recurrencePrefix,
    this.recurrenceSpacing,
    this.spacing,
    this.fallbackWeekday,
    this.showAdvancedAlarms = false,
    this.enabled = true,
    this.recurrenceChipSpacing,
    this.recurrenceChipRunSpacing,
    this.recurrenceWeekdaySpacing,
    this.recurrenceAdvancedSectionSpacing,
    this.recurrenceEndSpacing,
    this.recurrenceFieldGap,
    this.recurrenceShowAdvancedToggle = true,
    this.recurrenceForceAdvanced = false,
    this.recurrenceIntervalSelectWidth,
  });

  final ReminderPreferences reminders;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final RecurrenceFormValue recurrence;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final DateTime? deadline;
  final DateTime? referenceStart;
  final List<CalendarAlarm>? advancedAlarms;
  final ValueChanged<List<CalendarAlarm>>? onAdvancedAlarmsChanged;
  final String? reminderTitle;
  final bool showReminderHeader;
  final TaskSectionLabelSize reminderHeaderSize;
  final bool remindersMixed;
  final ReminderAnchor? reminderAnchor;
  final bool? showBothReminderAnchors;
  final String? recurrenceTitle;
  final TaskSectionLabelSize recurrenceHeaderSize;
  final Widget? recurrencePrefix;
  final double? recurrenceSpacing;
  final double? spacing;
  final int? fallbackWeekday;
  final bool showAdvancedAlarms;
  final bool enabled;
  final double? recurrenceChipSpacing;
  final double? recurrenceChipRunSpacing;
  final double? recurrenceWeekdaySpacing;
  final double? recurrenceAdvancedSectionSpacing;
  final double? recurrenceEndSpacing;
  final double? recurrenceFieldGap;
  final bool recurrenceShowAdvancedToggle;
  final bool recurrenceForceAdvanced;
  final double? recurrenceIntervalSelectWidth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ReminderAnchor resolvedAnchor =
        reminderAnchor ??
        (deadline == null ? ReminderAnchor.start : ReminderAnchor.deadline);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ReminderPreferencesField(
          value: reminders,
          onChanged: onRemindersChanged,
          advancedAlarms: advancedAlarms,
          onAdvancedAlarmsChanged: onAdvancedAlarmsChanged,
          referenceStart: referenceStart,
          title: reminderTitle ?? l10n.calendarRemindersSection,
          headerSize: reminderHeaderSize,
          showHeader: showReminderHeader,
          anchor: resolvedAnchor,
          mixed: remindersMixed,
          showBothAnchors: showBothReminderAnchors ?? deadline != null,
          showAdvancedAlarms: showAdvancedAlarms,
          enabled: enabled,
        ),
        SizedBox(height: spacing ?? context.spacing.m),
        if (recurrencePrefix != null) ...[
          recurrencePrefix!,
          SizedBox(height: context.spacing.s),
        ],
        TaskRecurrenceSection(
          title: recurrenceTitle ?? l10n.calendarRepeatLabel,
          spacing: recurrenceSpacing ?? context.spacing.s,
          headerSize: recurrenceHeaderSize,
          value: recurrence,
          fallbackWeekday: fallbackWeekday ?? referenceStart?.weekday,
          referenceStart: referenceStart,
          chipSpacing: recurrenceChipSpacing,
          chipRunSpacing: recurrenceChipRunSpacing,
          weekdaySpacing: recurrenceWeekdaySpacing,
          advancedSectionSpacing: recurrenceAdvancedSectionSpacing,
          endSpacing: recurrenceEndSpacing,
          fieldGap: recurrenceFieldGap,
          showAdvancedToggle: recurrenceShowAdvancedToggle,
          forceAdvanced: recurrenceForceAdvanced,
          intervalSelectWidth: recurrenceIntervalSelectWidth,
          onChanged: onRecurrenceChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}

class _ReminderPreferencesFieldState extends State<ReminderPreferencesField> {
  late bool _advancedExpanded;

  @override
  void initState() {
    super.initState();
    _advancedExpanded = _shouldStartExpanded(widget);
  }

  @override
  void didUpdateWidget(covariant ReminderPreferencesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_advancedExpanded && _shouldStartExpanded(widget)) {
      setState(() => _advancedExpanded = true);
    }
  }

  bool _shouldStartExpanded(ReminderPreferencesField widget) {
    if (!widget.showAdvancedAlarms) {
      return false;
    }
    return widget.advancedAlarms?.isNotEmpty == true;
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.enabled;
    final ReminderPreferences resolvedValue = widget.showBothAnchors
        ? widget.value.normalized()
        : widget.value.alignedTo(widget.anchor);
    if (enabled && resolvedValue != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(resolvedValue);
      });
    }

    final ValueChanged<ReminderPreferences> onChanged = enabled
        ? widget.onChanged
        : (_) {};
    final bool usesDeadline = widget.anchor.isDeadline;
    final List<Duration> options = usesDeadline
        ? widget.deadlineOptions
        : widget.startOptions;
    final List<Duration> selected = usesDeadline
        ? resolvedValue.deadlineOffsets
        : resolvedValue.startOffsets;
    final String sectionLabel = usesDeadline
        ? _reminderBeforeDeadlineLabel
        : _reminderBeforeStartLabel;
    final String zeroLabel = usesDeadline
        ? _reminderAtDeadlineLabel
        : _reminderAtStartLabel;
    final List<CalendarAlarm>? advancedAlarms = widget.advancedAlarms;
    final ValueChanged<List<CalendarAlarm>>? baseAdvancedChanged =
        widget.onAdvancedAlarmsChanged;
    final ValueChanged<List<CalendarAlarm>>? onAdvancedChanged = enabled
        ? baseAdvancedChanged
        : baseAdvancedChanged == null
        ? null
        : (_) {};
    final bool allowAdvanced =
        widget.showAdvancedAlarms &&
        advancedAlarms != null &&
        onAdvancedChanged != null;
    final List<CalendarAlarm> resolvedAdvancedAlarms =
        advancedAlarms ?? _emptyAdvancedAlarms;
    final bool hasAdvancedData =
        allowAdvanced && resolvedAdvancedAlarms.isNotEmpty;

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showHeader) ...[
          TaskSectionHeader(title: widget.title, size: widget.headerSize),
          SizedBox(height: context.spacing.s),
        ],
        if (!widget.showBothAnchors)
          _ReminderSection(
            label: sectionLabel,
            options: options,
            selected: selected,
            onOptionToggled: (Duration offset) => onChanged(
              _toggled(
                resolvedValue,
                offset,
                anchor: widget.anchor,
                preserveOtherAnchors: false,
              ),
            ),
            mixed: widget.mixed,
            zeroLabel: zeroLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          )
        else ...[
          _ReminderSection(
            label: _reminderBeforeStartLabel,
            options: widget.startOptions,
            selected: resolvedValue.startOffsets,
            onOptionToggled: (Duration offset) => onChanged(
              _toggled(
                resolvedValue,
                offset,
                anchor: ReminderAnchor.start,
                preserveOtherAnchors: true,
              ),
            ),
            mixed: widget.mixed,
            zeroLabel: _reminderAtStartLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          ),
          SizedBox(height: context.spacing.m),
          _ReminderSection(
            label: _reminderBeforeDeadlineLabel,
            options: widget.deadlineOptions,
            selected: resolvedValue.deadlineOffsets,
            onOptionToggled: (Duration offset) => onChanged(
              _toggled(
                resolvedValue,
                offset,
                anchor: ReminderAnchor.deadline,
                preserveOtherAnchors: true,
              ),
            ),
            mixed: widget.mixed,
            zeroLabel: _reminderAtDeadlineLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          ),
        ],
        if (allowAdvanced) ...[
          SizedBox(height: context.spacing.m),
          TaskSectionExpander(
            title: _reminderAdvancedLabel,
            isExpanded: _advancedExpanded,
            onToggle: () => setState(() {
              _advancedExpanded = !_advancedExpanded;
            }),
            badge: hasAdvancedData
                ? const _ReminderAdvancedActiveBadge()
                : null,
            collapsedHint: hasAdvancedData
                ? Text(_reminderAdvancedSummary, style: context.textTheme.muted)
                : null,
            enabled: enabled,
            child: CalendarAlarmsField(
              alarms: resolvedAdvancedAlarms,
              title: _reminderAdvancedLabel,
              referenceStart: widget.referenceStart,
              showReminderNote: false,
              showHeader: false,
              onChanged: onAdvancedChanged,
            ),
          ),
        ],
      ],
    );
    if (enabled) {
      return content;
    }
    return IgnorePointer(child: content);
  }

  ReminderPreferences _toggled(
    ReminderPreferences prefs,
    Duration offset, {
    required ReminderAnchor anchor,
    required bool preserveOtherAnchors,
  }) {
    final List<Duration> nextStart = List<Duration>.from(prefs.startOffsets);
    final List<Duration> nextDeadline = List<Duration>.from(
      prefs.deadlineOffsets,
    );
    final List<Duration> targetOffsets = anchor.isDeadline
        ? nextDeadline
        : nextStart;

    if (targetOffsets.contains(offset)) {
      targetOffsets.remove(offset);
    } else {
      targetOffsets.add(offset);
    }

    if (!preserveOtherAnchors) {
      if (anchor.isDeadline) {
        nextStart.clear();
      } else {
        nextDeadline.clear();
      }
    }

    return prefs
        .copyWith(
          enabled: true,
          startOffsets: nextStart,
          deadlineOffsets: nextDeadline,
        )
        .normalized(forceEnabled: true);
  }
}

class _ReminderAdvancedActiveBadge extends StatelessWidget {
  const _ReminderAdvancedActiveBadge();

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.xxs,
        vertical: context.spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: _reminderAdvancedBadgeOpacity),
        borderRadius: BorderRadius.circular(_reminderAdvancedBadgeRadius),
      ),
      child: Text(
        _reminderAdvancedActiveLabel,
        style: context.textTheme.label.strong.copyWith(
          color: colors.mutedForeground,
        ),
      ),
    );
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onOptionToggled,
    required this.zeroLabel,
    this.mixed = false,
    this.chipPadding,
  });

  final String label;
  final List<Duration> options;
  final List<Duration> selected;
  final ValueChanged<Duration> onOptionToggled;
  final bool mixed;
  final String zeroLabel;
  final EdgeInsets? chipPadding;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ShadColorScheme colors = context.colorScheme;
    final TextStyle labelStyle = context.textTheme.labelSm.strong;
    final spacing = context.spacing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: labelStyle),
            if (mixed)
              Container(
                margin: EdgeInsets.only(left: spacing.s),
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.s,
                  vertical: spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(context.radii.container),
                ),
                child: Text(
                  'Mixed',
                  style: context.textTheme.label.strong.copyWith(
                    color: colors.mutedForeground,
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: spacing.xs),
        Wrap(
          spacing: spacing.s,
          runSpacing: spacing.s,
          children: options
              .map(
                (Duration option) => _ReminderChip(
                  label: _labelFor(l10n, option),
                  selected: selected.contains(option),
                  onTap: () => onOptionToggled(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  String _labelFor(AppLocalizations l10n, Duration offset) {
    if (offset == Duration.zero) {
      return zeroLabel;
    }
    if (offset.inDays >= 1) {
      final int days = offset.inDays;
      return '${days}d';
    }
    if (offset.inHours >= 1) {
      final int hours = offset.inHours;
      return '${hours}h';
    }
    if (offset.inMinutes >= 1) {
      return '${offset.inMinutes}m';
    }
    return TimeFormatter.formatDuration(l10n, offset);
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AxiButton(
      variant: selected ? AxiButtonVariant.primary : AxiButtonVariant.outline,
      selected: selected,
      onPressed: onTap,
      child: Text(label),
    );
  }
}
