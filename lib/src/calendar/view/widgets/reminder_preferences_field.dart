import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

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
    final ShadColorScheme colors = context.colorScheme;
    final bool enabled = !showEnabledToggle || value.enabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(
          title: title,
          trailing: showEnabledToggle
              ? ShadSwitch(
                  value: value.enabled,
                  label: const SizedBox.shrink(),
                  hoverColor: colors.primary.withValues(alpha: 0.08),
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
                  mixed: mixed,
                  zeroLabel: 'At start',
                  chipPadding: const EdgeInsets.symmetric(
                    horizontal: calendarGutterMd,
                    vertical: calendarGutterSm,
                  ),
                ),
                if (showDeadlineOptions) ...[
                  const SizedBox(height: 8),
                  _ReminderSection(
                    label: 'Before deadline',
                    options: deadlineOptions,
                    selected: value.deadlineOffsets,
                    onOptionToggled: (Duration offset) =>
                        onChanged(_toggled(value, offset, isStart: false)),
                    mixed: mixed,
                    zeroLabel: 'At deadline',
                    chipPadding: const EdgeInsets.symmetric(
                      horizontal: calendarGutterMd,
                      vertical: calendarGutterSm,
                    ),
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
      color: colors.mutedForeground,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );
    final Color inactiveBackground = colors.secondary.withValues(alpha: 0.04);
    final BorderRadius radius = BorderRadius.circular(calendarBorderRadius);

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
                  activeColor: colors.primary,
                  borderColor: colors.border,
                  inactiveBackground: inactiveBackground,
                  radius: radius,
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
    required this.radius,
    required this.padding,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color activeColor;
  final Color borderColor;
  final Color inactiveBackground;
  final BorderRadius radius;
  final EdgeInsets padding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Color textColor =
        selected ? Colors.white : colors.foreground.withValues(alpha: 0.9);

    return ShadButton.raw(
      size: ShadButtonSize.sm,
      padding: padding,
      backgroundColor:
          selected ? activeColor : inactiveBackground.withValues(alpha: 0.7),
      hoverBackgroundColor: selected
          ? activeColor.withValues(alpha: 0.9)
          : inactiveBackground.withValues(alpha: 0.9),
      foregroundColor: textColor,
      hoverForegroundColor: textColor,
      border: ShadBorder.all(
        color: selected ? activeColor : borderColor,
        radius: radius,
      ),
      onPressed: onTap,
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
