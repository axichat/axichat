// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_alarms_field.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Declarative reminder selector that exposes start/deadline offsets as a set
/// of toggleable chips. Designed to be reused by quick add, sidebar, and
/// day-event composers.
const double _reminderAdvancedBadgeOpacity = 0.16;
const double _reminderAdvancedBadgeRadius = 10;
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];

class ReminderPreferencesField extends StatefulWidget {
  const ReminderPreferencesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.onPermissionRequested,
    this.title,
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
  final VoidCallback? onPermissionRequested;
  final String? title;
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
    final l10n = context.l10n;
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
        ? l10n.calendarReminderBeforeDeadlineLabel
        : l10n.calendarReminderBeforeStartLabel;
    final String zeroLabel = usesDeadline
        ? l10n.calendarReminderAtDeadlineLabel
        : l10n.calendarReminderAtStartLabel;
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
          TaskSectionHeader(
            title: widget.title ?? l10n.calendarRemindersSection,
            size: widget.headerSize,
          ),
          SizedBox(height: context.spacing.s),
        ],
        if (!widget.showBothAnchors)
          _ReminderSection(
            label: sectionLabel,
            options: options,
            selected: selected,
            onPermissionRequested: widget.onPermissionRequested,
            onOptionToggled: (Duration offset) {
              onChanged(
                _toggled(
                  resolvedValue,
                  offset,
                  anchor: widget.anchor,
                  preserveOtherAnchors: false,
                ),
              );
            },
            mixed: widget.mixed,
            zeroLabel: zeroLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          )
        else ...[
          _ReminderSection(
            label: l10n.calendarReminderBeforeStartLabel,
            options: widget.startOptions,
            selected: resolvedValue.startOffsets,
            onPermissionRequested: widget.onPermissionRequested,
            onOptionToggled: (Duration offset) {
              onChanged(
                _toggled(
                  resolvedValue,
                  offset,
                  anchor: ReminderAnchor.start,
                  preserveOtherAnchors: true,
                ),
              );
            },
            mixed: widget.mixed,
            zeroLabel: l10n.calendarReminderAtStartLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          ),
          SizedBox(height: context.spacing.m),
          _ReminderSection(
            label: l10n.calendarReminderBeforeDeadlineLabel,
            options: widget.deadlineOptions,
            selected: resolvedValue.deadlineOffsets,
            onPermissionRequested: widget.onPermissionRequested,
            onOptionToggled: (Duration offset) {
              onChanged(
                _toggled(
                  resolvedValue,
                  offset,
                  anchor: ReminderAnchor.deadline,
                  preserveOtherAnchors: true,
                ),
              );
            },
            mixed: widget.mixed,
            zeroLabel: l10n.calendarReminderAtDeadlineLabel,
            chipPadding: EdgeInsets.symmetric(
              horizontal: context.spacing.m,
              vertical: context.spacing.s,
            ),
          ),
        ],
        if (allowAdvanced) ...[
          SizedBox(height: context.spacing.m),
          TaskSectionExpander(
            title: l10n.calendarReminderAdvancedAlarms,
            isExpanded: _advancedExpanded,
            onToggle: () => setState(() {
              if (!_advancedExpanded) {
                widget.onPermissionRequested?.call();
              }
              _advancedExpanded = !_advancedExpanded;
            }),
            badge: hasAdvancedData
                ? const _ReminderAdvancedActiveBadge()
                : null,
            collapsedHint: hasAdvancedData
                ? Text(
                    l10n.calendarReminderAdvancedAlarmsApplied,
                    style: context.textTheme.muted,
                  )
                : null,
            enabled: enabled,
            child: CalendarAlarmsField(
              alarms: resolvedAdvancedAlarms,
              title: l10n.calendarReminderAdvancedAlarms,
              referenceStart: widget.referenceStart,
              showReminderNote: false,
              showHeader: false,
              onChanged: (value) {
                if (value.isNotEmpty) {
                  widget.onPermissionRequested?.call();
                }
                onAdvancedChanged(value);
              },
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
        context.l10n.calendarReminderAdvancedAlarmsActive,
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
    this.onPermissionRequested,
    required this.onOptionToggled,
    required this.zeroLabel,
    this.mixed = false,
    this.chipPadding,
  });

  final String label;
  final List<Duration> options;
  final List<Duration> selected;
  final VoidCallback? onPermissionRequested;
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
                  l10n.calendarReminderMixedLabel,
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
              .map((Duration option) {
                final bool optionSelected = selected.contains(option);
                return _ReminderChip(
                  label: _labelFor(l10n, option),
                  selected: optionSelected,
                  onTap: () {
                    if (!optionSelected) {
                      onPermissionRequested?.call();
                    }
                    onOptionToggled(option);
                  },
                );
              })
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
