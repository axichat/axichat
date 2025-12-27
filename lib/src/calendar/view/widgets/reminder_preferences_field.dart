import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_alarms_field.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
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
const double _reminderAdvancedLabelLetterSpacing = 0.4;
const double _reminderAdvancedBadgeOpacity = 0.16;
const double _reminderAdvancedBadgeFontSize = 11;
const double _reminderAdvancedBadgeRadius = 10;
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];

class ReminderPreferencesField extends StatefulWidget {
  const ReminderPreferencesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = _reminderSectionTitle,
    this.anchor = ReminderAnchor.start,
    this.mixed = false,
    this.showBothAnchors = false,
    this.startOptions = calendarReminderStartOptions,
    this.deadlineOptions = calendarReminderDeadlineOptions,
    this.advancedAlarms,
    this.onAdvancedAlarmsChanged,
    this.referenceStart,
    this.showAdvancedAlarms = true,
  });

  final ReminderPreferences value;
  final ValueChanged<ReminderPreferences> onChanged;
  final String title;
  final ReminderAnchor anchor;
  final bool mixed;
  final bool showBothAnchors;
  final List<Duration> startOptions;
  final List<Duration> deadlineOptions;
  final List<CalendarAlarm>? advancedAlarms;
  final ValueChanged<List<CalendarAlarm>>? onAdvancedAlarmsChanged;
  final DateTime? referenceStart;
  final bool showAdvancedAlarms;

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
    final ReminderPreferences resolvedValue = widget.showBothAnchors
        ? widget.value.normalized()
        : widget.value.alignedTo(widget.anchor);
    if (resolvedValue != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onChanged(resolvedValue);
      });
    }

    final ValueChanged<ReminderPreferences> onChanged = widget.onChanged;
    final bool usesDeadline = widget.anchor.isDeadline;
    final List<Duration> options =
        usesDeadline ? widget.deadlineOptions : widget.startOptions;
    final List<Duration> selected = usesDeadline
        ? resolvedValue.deadlineOffsets
        : resolvedValue.startOffsets;
    final String sectionLabel =
        usesDeadline ? _reminderBeforeDeadlineLabel : _reminderBeforeStartLabel;
    final String zeroLabel =
        usesDeadline ? _reminderAtDeadlineLabel : _reminderAtStartLabel;
    final List<CalendarAlarm>? advancedAlarms = widget.advancedAlarms;
    final ValueChanged<List<CalendarAlarm>>? onAdvancedChanged =
        widget.onAdvancedAlarmsChanged;
    final bool allowAdvanced = widget.showAdvancedAlarms &&
        advancedAlarms != null &&
        onAdvancedChanged != null;
    final List<CalendarAlarm> resolvedAdvancedAlarms =
        advancedAlarms ?? _emptyAdvancedAlarms;
    final bool hasAdvancedData =
        allowAdvanced && resolvedAdvancedAlarms.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(
          title: widget.title,
        ),
        const SizedBox(height: calendarGutterSm),
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
            chipPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
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
            chipPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
          ),
          const SizedBox(height: calendarGutterMd),
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
            chipPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
          ),
        ],
        if (allowAdvanced) ...[
          const SizedBox(height: calendarGutterMd),
          _ReminderAdvancedToggle(
            isExpanded: _advancedExpanded,
            hasAdvancedData: hasAdvancedData,
            onPressed: () {
              setState(() => _advancedExpanded = !_advancedExpanded);
            },
          ),
          if (_advancedExpanded) ...[
            const SizedBox(height: calendarGutterSm),
            CalendarAlarmsField(
              alarms: resolvedAdvancedAlarms,
              title: _reminderAdvancedLabel,
              referenceStart: widget.referenceStart,
              showReminderNote: false,
              onChanged: onAdvancedChanged,
            ),
          ] else if (hasAdvancedData) ...[
            const SizedBox(height: calendarGutterSm),
            Text(
              _reminderAdvancedSummary,
              style: context.textTheme.muted.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ],
    );
  }

  ReminderPreferences _toggled(
    ReminderPreferences prefs,
    Duration offset, {
    required ReminderAnchor anchor,
    required bool preserveOtherAnchors,
  }) {
    final List<Duration> nextStart = List<Duration>.from(prefs.startOffsets);
    final List<Duration> nextDeadline =
        List<Duration>.from(prefs.deadlineOffsets);
    final List<Duration> targetOffsets =
        anchor.isDeadline ? nextDeadline : nextStart;

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

class _ReminderAdvancedToggle extends StatelessWidget {
  const _ReminderAdvancedToggle({
    required this.isExpanded,
    required this.hasAdvancedData,
    required this.onPressed,
  });

  final bool isExpanded;
  final bool hasAdvancedData;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w700,
      letterSpacing: _reminderAdvancedLabelLetterSpacing,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterSm,
            vertical: calendarGutterSm,
          ),
          child: Row(
            children: [
              Text(
                _reminderAdvancedLabel.toUpperCase(),
                style: labelStyle,
              ),
              if (hasAdvancedData) ...[
                const SizedBox(width: calendarInsetSm),
                const _ReminderAdvancedActiveBadge(),
              ],
              const Spacer(),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                size: calendarGutterMd,
                color: calendarSubtitleColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderAdvancedActiveBadge extends StatelessWidget {
  const _ReminderAdvancedActiveBadge();

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarInsetSm,
        vertical: calendarInsetSm,
      ),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: _reminderAdvancedBadgeOpacity),
        borderRadius: BorderRadius.circular(_reminderAdvancedBadgeRadius),
      ),
      child: Text(
        _reminderAdvancedActiveLabel,
        style: TextStyle(
          color: colors.mutedForeground,
          fontSize: _reminderAdvancedBadgeFontSize,
          fontWeight: FontWeight.w600,
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
    final ShadColorScheme colors = context.colorScheme;
    final TextStyle labelStyle = context.textTheme.small.copyWith(
      fontSize: 10,
      color: colors.mutedForeground,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label.toUpperCase(), style: labelStyle),
            if (mixed)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.muted.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Mixed',
                  style: TextStyle(
                    color: colors.mutedForeground,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options
              .map(
                (Duration option) => _ReminderChip(
                  label: _labelFor(option),
                  selected: selected.contains(option),
                  padding: chipPadding ??
                      const EdgeInsets.symmetric(
                        horizontal: calendarGutterMd,
                        vertical: calendarGutterSm,
                      ),
                  onTap: () => onOptionToggled(option),
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }

  String _labelFor(Duration offset) {
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
    return TimeFormatter.formatDuration(offset);
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Color unselectedBackground =
        colors.muted.withValues(alpha: 0.12); // light grey that adapts to theme
    final Color unselectedHover =
        colors.muted.withValues(alpha: 0.2); // slightly darker on hover
    final Color selectedForeground = colors.primaryForeground;
    return ShadButton.raw(
      variant: selected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: padding,
      backgroundColor: selected ? calendarPrimaryColor : unselectedBackground,
      hoverBackgroundColor:
          selected ? calendarPrimaryHoverColor : unselectedHover,
      foregroundColor: selected ? selectedForeground : calendarPrimaryColor,
      hoverForegroundColor:
          selected ? selectedForeground : calendarPrimaryHoverColor,
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    ).withTapBounce();
  }
}
