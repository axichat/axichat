import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';

/// Declarative reminder selector that exposes start/deadline offsets as a set
/// of toggleable chips. Designed to be reused by quick add, sidebar, and
/// day-event composers.
class ReminderPreferencesField extends StatelessWidget {
  const ReminderPreferencesField({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Reminders',
    this.showDeadlineOptions = true,
    this.showEnabledToggle = true,
    this.mixed = false,
    this.startOptions = calendarReminderStartOptions,
    this.deadlineOptions = calendarReminderDeadlineOptions,
  });

  final ReminderPreferences value;
  final ValueChanged<ReminderPreferences> onChanged;
  final String title;
  final bool showDeadlineOptions;
  final bool showEnabledToggle;
  final bool mixed;
  final List<Duration> startOptions;
  final List<Duration> deadlineOptions;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = !showEnabledToggle || value.enabled;
    final TextStyle labelStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: colors.secondary,
      letterSpacing: 0.2,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(
          title: title,
          trailing: showEnabledToggle
              ? Switch(
                  value: value.enabled,
                  activeThumbColor: colors.primary,
                  onChanged: (bool next) => onChanged(
                    value
                        .copyWith(enabled: next)
                        .normalized(forceEnabled: next),
                  ),
                )
              : null,
        ),
        const SizedBox(height: 8),
        IgnorePointer(
          ignoring: !enabled,
          child: Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReminderSection(
                  label: 'Before start',
                  options: startOptions,
                  selected: value.startOffsets,
                  onOptionToggled: (Duration offset) =>
                      onChanged(_toggled(value, offset, isStart: true)),
                  labelStyle: labelStyle,
                  mixed: mixed,
                  zeroLabel: 'At start',
                ),
                if (showDeadlineOptions) ...[
                  const SizedBox(height: 8),
                  _ReminderSection(
                    label: 'Before deadline',
                    options: deadlineOptions,
                    selected: value.deadlineOffsets,
                    onOptionToggled: (Duration offset) =>
                        onChanged(_toggled(value, offset, isStart: false)),
                    labelStyle: labelStyle,
                    mixed: mixed,
                    zeroLabel: 'At deadline',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  ReminderPreferences _toggled(
    ReminderPreferences prefs,
    Duration offset, {
    required bool isStart,
  }) {
    final List<Duration> nextOffsets = List<Duration>.from(
      isStart ? prefs.startOffsets : prefs.deadlineOffsets,
    );
    if (nextOffsets.contains(offset)) {
      nextOffsets.remove(offset);
    } else {
      nextOffsets.add(offset);
    }
    return prefs
        .copyWith(
          enabled: true,
          startOffsets: isStart ? nextOffsets : prefs.startOffsets,
          deadlineOffsets: isStart ? prefs.deadlineOffsets : nextOffsets,
        )
        .normalized(forceEnabled: true);
  }
}

class _ReminderSection extends StatelessWidget {
  const _ReminderSection({
    required this.label,
    required this.options,
    required this.selected,
    required this.onOptionToggled,
    required this.labelStyle,
    required this.zeroLabel,
    this.mixed = false,
  });

  final String label;
  final List<Duration> options;
  final List<Duration> selected;
  final ValueChanged<Duration> onOptionToggled;
  final TextStyle labelStyle;
  final bool mixed;
  final String zeroLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color borderColor = colors.outline.withValues(alpha: 0.4);
    final Color activeColor = colors.primary;
    final Color inactiveBackground = colors.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: labelStyle),
            if (mixed)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Mixed',
                  style: TextStyle(
                    color: colors.onSecondaryContainer,
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
                  activeColor: activeColor,
                  borderColor: borderColor,
                  inactiveBackground: inactiveBackground,
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
      return '$days day${days == 1 ? '' : 's'} before';
    }
    if (offset.inHours >= 1) {
      final int hours = offset.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} before';
    }
    return '${TimeFormatter.formatDuration(offset)} before';
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.borderColor,
    required this.inactiveBackground,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final Color borderColor;
  final Color inactiveBackground;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color textColor = selected ? colors.onPrimary : colors.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? activeColor : inactiveBackground,
          border: Border.all(
            color: selected ? activeColor : borderColor,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}
