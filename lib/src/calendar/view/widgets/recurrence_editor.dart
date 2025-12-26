import 'dart:collection';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/widgets/deadline_picker_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _recurrenceFrequencyYearlyLabel = 'Yearly';
const String _recurrenceIntervalYearLabel = 'year(s)';

class RecurrenceFormValue {
  const RecurrenceFormValue({
    this.frequency = RecurrenceFrequency.none,
    this.interval = 1,
    Set<int>? weekdays,
    this.until,
    this.count,
  }) : weekdays = weekdays ?? const <int>{};

  factory RecurrenceFormValue.fromRule(RecurrenceRule? rule) {
    if (rule == null || rule.frequency == RecurrenceFrequency.none) {
      return const RecurrenceFormValue();
    }

    return RecurrenceFormValue(
      frequency: rule.frequency,
      interval: rule.interval,
      weekdays: rule.byWeekdays != null
          ? Set<int>.from(rule.byWeekdays!)
          : const <int>{},
      until: rule.count != null ? null : rule.until,
      count: rule.count,
    );
  }

  final RecurrenceFrequency frequency;
  final int interval;
  final Set<int> weekdays;
  final DateTime? until;
  final int? count;

  bool get isActive => frequency != RecurrenceFrequency.none;

  RecurrenceFormValue resolveLinkedLimits(DateTime? start) {
    if (start == null || !isActive) {
      return this;
    }
    final _RecurrenceLimitSolver solver = _RecurrenceLimitSolver(start, this);

    DateTime? derivedUntil = until;
    int? derivedCount = count;

    if (derivedUntil == null && derivedCount != null) {
      derivedUntil = solver.untilForCount(derivedCount);
    } else if (derivedCount == null && derivedUntil != null) {
      derivedCount = solver.countThrough(derivedUntil);
    }

    if (derivedUntil == until && derivedCount == count) {
      return this;
    }

    return copyWith(until: derivedUntil, count: derivedCount);
  }

  RecurrenceFormValue copyWith({
    RecurrenceFrequency? frequency,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    bool clearUntil = false,
    int? count,
    bool clearCount = false,
  }) {
    return RecurrenceFormValue(
      frequency: frequency ?? this.frequency,
      interval: interval ?? this.interval,
      weekdays: weekdays ?? this.weekdays,
      until: clearUntil ? null : until ?? this.until,
      count: clearCount ? null : count ?? this.count,
    );
  }

  RecurrenceRule? toRule({required DateTime start}) {
    final RecurrenceFormValue normalized = resolveLinkedLimits(start);
    if (normalized.frequency == RecurrenceFrequency.none) {
      return null;
    }

    final effectiveUntil = normalized.count != null ? null : normalized.until;

    switch (normalized.frequency) {
      case RecurrenceFrequency.none:
        return null;
      case RecurrenceFrequency.daily:
        return RecurrenceRule(
          frequency: RecurrenceFrequency.daily,
          interval: normalized.interval,
          until: effectiveUntil,
          count: normalized.count,
        );
      case RecurrenceFrequency.weekdays:
        return const RecurrenceRule(
          frequency: RecurrenceFrequency.weekdays,
          interval: 1,
          byWeekdays: [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ],
        ).copyWith(
          interval: normalized.interval,
          until: effectiveUntil,
          count: normalized.count,
        );
      case RecurrenceFrequency.weekly:
        final normalizedWeekdays = normalized.weekdays.isEmpty
            ? <int>{start.weekday}
            : SplayTreeSet.of(normalized.weekdays).toList();
        return RecurrenceRule(
          frequency: RecurrenceFrequency.weekly,
          interval: normalized.interval,
          byWeekdays: normalizedWeekdays.toList(),
          until: effectiveUntil,
          count: normalized.count,
        );
      case RecurrenceFrequency.monthly:
        return RecurrenceRule(
          frequency: RecurrenceFrequency.monthly,
          interval: normalized.interval,
          until: effectiveUntil,
          count: normalized.count,
        );
      case RecurrenceFrequency.yearly:
        return RecurrenceRule(
          frequency: RecurrenceFrequency.yearly,
          interval: normalized.interval,
          until: effectiveUntil,
          count: normalized.count,
        );
    }
  }
}

class RecurrenceEditorSpacing {
  const RecurrenceEditorSpacing({
    this.chipSpacing = 6,
    this.chipRunSpacing = 6,
    this.weekdaySpacing = 10,
    this.advancedSectionSpacing = 12,
    this.endSpacing = 14,
    this.fieldGap = 12,
  });

  final double chipSpacing;
  final double chipRunSpacing;
  final double weekdaySpacing;
  final double advancedSectionSpacing;
  final double endSpacing;
  final double fieldGap;
}

class RecurrenceEditor extends StatefulWidget {
  const RecurrenceEditor({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.fallbackWeekday,
    this.spacing = const RecurrenceEditorSpacing(),
    this.chipPadding = const EdgeInsets.symmetric(
        horizontal: calendarGutterMd, vertical: calendarGutterSm),
    this.weekdayChipPadding =
        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    this.intervalSelectWidth = 120,
  });

  final RecurrenceFormValue value;
  final ValueChanged<RecurrenceFormValue> onChanged;
  final bool enabled;
  final int? fallbackWeekday;
  final RecurrenceEditorSpacing spacing;
  final EdgeInsets chipPadding;
  final EdgeInsets weekdayChipPadding;
  final double intervalSelectWidth;

  @override
  State<RecurrenceEditor> createState() => _RecurrenceEditorState();
}

class _RecurrenceEditorState extends State<RecurrenceEditor> {
  late TextEditingController _countController;

  RecurrenceFormValue get value => widget.value;

  @override
  void initState() {
    super.initState();
    _countController = TextEditingController(
      text: value.count?.toString() ?? '',
    );
  }

  @override
  void didUpdateWidget(covariant RecurrenceEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value.count != widget.value.count &&
        _countController.text != (widget.value.count?.toString() ?? '')) {
      _countController.text = widget.value.count?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _countController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    final selectedFrequency = value.frequency;
    final spacing = widget.spacing;
    final children = <Widget>[
      Wrap(
        spacing: spacing.chipSpacing,
        runSpacing: spacing.chipRunSpacing,
        children: RecurrenceFrequency.values
            .map(
              (freq) => _RecurrenceFrequencyChip(
                isSelected: selectedFrequency == freq,
                enabled: enabled,
                padding: widget.chipPadding,
                label: _frequencyLabel(freq),
                onPressed: enabled
                    ? () => widget.onChanged(
                          _normalizedForFrequency(freq),
                        )
                    : null,
              ),
            )
            .toList(),
      ),
    ];

    if (selectedFrequency == RecurrenceFrequency.weekly) {
      children
        ..add(SizedBox(height: spacing.weekdaySpacing))
        ..add(
          _RecurrenceWeekdaySelector(
            enabled: enabled,
            padding: widget.weekdayChipPadding,
            selectedWeekdays: value.weekdays,
            onWeekdayToggled: _toggleWeekday,
          ),
        );
    }

    if (selectedFrequency != RecurrenceFrequency.none) {
      children
        ..add(SizedBox(height: spacing.advancedSectionSpacing))
        ..add(
          _RecurrenceIntervalRow(
            enabled: enabled,
            currentInterval: value.interval,
            intervalWidth: widget.intervalSelectWidth,
            fieldGap: spacing.fieldGap,
            unitLabel: _intervalUnitLabel(value.frequency),
            onIntervalChanged: (newValue) =>
                widget.onChanged(value.copyWith(interval: newValue)),
          ),
        )
        ..add(SizedBox(height: spacing.endSpacing))
        ..add(
          _RecurrenceEndControls(
            enabled: enabled,
            value: value,
            countController: _countController,
            onUntilChanged: (selected) {
              widget.onChanged(
                value.copyWith(
                  until: selected == null
                      ? null
                      : DateTime(
                          selected.year,
                          selected.month,
                          selected.day,
                        ),
                  clearCount: true,
                ),
              );
            },
            onCountChanged: (text) {
              final parsed = int.tryParse(text);
              widget.onChanged(
                value.copyWith(
                  count: parsed != null && parsed > 0 ? parsed : null,
                  clearUntil: parsed != null && parsed > 0,
                ),
              );
            },
          ),
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  RecurrenceFormValue _normalizedForFrequency(RecurrenceFrequency frequency) {
    var result = value.copyWith(
      frequency: frequency,
      interval: 1,
    );

    if (frequency == RecurrenceFrequency.none) {
      result = result.copyWith(clearCount: true, clearUntil: true);
    }

    if (frequency == RecurrenceFrequency.weekly) {
      if (result.weekdays.isEmpty) {
        final fallback = widget.fallbackWeekday ?? DateTime.now().weekday;
        result = result.copyWith(weekdays: {fallback});
      }
    } else {
      result = result.copyWith(weekdays: const <int>{});
    }

    return result;
  }

  void _toggleWeekday(int weekday) {
    final current = value.weekdays;
    final updated = current.contains(weekday)
        ? (current.length == 1
            ? current
            : (Set<int>.from(current)..remove(weekday)))
        : (Set<int>.from(current)..add(weekday));

    widget.onChanged(value.copyWith(weekdays: updated));
  }

  String _frequencyLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return 'Never';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekdays:
        return 'Weekdays';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
      case RecurrenceFrequency.yearly:
        return _recurrenceFrequencyYearlyLabel;
    }
  }

  String _intervalUnitLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return 'month(s)';
      case RecurrenceFrequency.yearly:
        return _recurrenceIntervalYearLabel;
      case RecurrenceFrequency.weekly:
      case RecurrenceFrequency.weekdays:
        return 'week(s)';
      case RecurrenceFrequency.daily:
        return 'day(s)';
      case RecurrenceFrequency.none:
        return 'time(s)';
    }
  }
}

class _RecurrenceFrequencyChip extends StatelessWidget {
  const _RecurrenceFrequencyChip({
    required this.isSelected,
    required this.enabled,
    required this.padding,
    required this.label,
    this.onPressed,
  });

  final bool isSelected;
  final bool enabled;
  final EdgeInsets padding;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: padding,
      backgroundColor:
          isSelected ? calendarPrimaryColor : calendarContainerColor,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: enabled ? 0.08 : 0.04),
      foregroundColor: isSelected
          ? colors.primaryForeground
          : enabled
              ? calendarPrimaryColor
              : calendarSubtitleColor,
      hoverForegroundColor:
          isSelected ? colors.primaryForeground : calendarPrimaryHoverColor,
      onPressed: enabled ? onPressed : null,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    ).withTapBounce();
  }
}

class _RecurrenceWeekdaySelector extends StatelessWidget {
  const _RecurrenceWeekdaySelector({
    required this.selectedWeekdays,
    required this.padding,
    required this.enabled,
    required this.onWeekdayToggled,
  });

  final Set<int> selectedWeekdays;
  final EdgeInsets padding;
  final bool enabled;
  final ValueChanged<int> onWeekdayToggled;

  static const _labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const _values = [
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
    DateTime.saturday,
    DateTime.sunday,
  ];

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Color unselectedBackground =
        colors.muted.withValues(alpha: enabled ? 0.12 : 0.08);
    final Color unselectedHover =
        colors.muted.withValues(alpha: enabled ? 0.18 : 0.1);
    final Color selectedForeground = colors.primaryForeground;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(_values.length, (index) {
        final weekday = _values[index];
        final isSelected = selectedWeekdays.contains(weekday);
        return ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: padding,
          backgroundColor:
              isSelected ? calendarPrimaryColor : unselectedBackground,
          hoverBackgroundColor:
              isSelected ? calendarPrimaryHoverColor : unselectedHover,
          foregroundColor:
              isSelected ? selectedForeground : calendarPrimaryColor,
          hoverForegroundColor:
              isSelected ? selectedForeground : calendarPrimaryHoverColor,
          onPressed: enabled ? () => onWeekdayToggled(weekday) : null,
          child: Text(
            _labels[index],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ).withTapBounce();
      }),
    );
  }
}

class _RecurrenceIntervalRow extends StatelessWidget {
  const _RecurrenceIntervalRow({
    required this.enabled,
    required this.currentInterval,
    required this.intervalWidth,
    required this.fieldGap,
    required this.unitLabel,
    required this.onIntervalChanged,
  });

  final bool enabled;
  final int currentInterval;
  final double intervalWidth;
  final double fieldGap;
  final String unitLabel;
  final ValueChanged<int> onIntervalChanged;

  @override
  Widget build(BuildContext context) {
    final options = List.generate(12, (index) => index + 1)
        .map(
          (value) => ShadOption<int>(
            value: value,
            child: Text('$value'),
          ),
        )
        .toList();

    return Row(
      children: [
        Text(
          'Repeat every',
          style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
        SizedBox(width: fieldGap),
        SizedBox(
          width: intervalWidth,
          child: ShadSelect<int>(
            enabled: enabled,
            initialValue: currentInterval.clamp(1, 12),
            onChanged: (newValue) {
              if (newValue == null) return;
              onIntervalChanged(newValue);
            },
            options: options,
            selectedOptionBuilder: (context, selected) => Text('$selected'),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(10),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        SizedBox(width: fieldGap),
        Text(
          unitLabel,
          style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
    );
  }
}

class _RecurrenceEndControls extends StatelessWidget {
  const _RecurrenceEndControls({
    required this.enabled,
    required this.value,
    required this.countController,
    required this.onUntilChanged,
    required this.onCountChanged,
  });

  final bool enabled;
  final RecurrenceFormValue value;
  final TextEditingController countController;
  final ValueChanged<DateTime?> onUntilChanged;
  final ValueChanged<String> onCountChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'END DATE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: calendarInsetLg),
        DeadlinePickerField(
          value: value.until,
          placeholder: 'End',
          showStatusColors: false,
          showTimeSelectors: false,
          onChanged: enabled ? onUntilChanged : (_) {},
        ),
        const SizedBox(height: calendarGutterLg),
        Text(
          'COUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: calendarInsetLg),
        TextField(
          controller: countController,
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: context.l10n.calendarRepeatTimes,
            hintStyle: TextStyle(
              color: calendarSubtitleColor.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide: BorderSide(color: calendarBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide: BorderSide(color: calendarBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide: BorderSide(color: calendarPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: calendarContainerColor,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: onCountChanged,
        ),
      ],
    );
  }
}

class _RecurrenceLimitSolver {
  _RecurrenceLimitSolver(this.anchor, this.value)
      : _effectiveWeekdays = value.frequency == RecurrenceFrequency.weekdays
            ? const {
                DateTime.monday,
                DateTime.tuesday,
                DateTime.wednesday,
                DateTime.thursday,
                DateTime.friday,
              }
            : (value.weekdays.isNotEmpty
                ? Set<int>.from(value.weekdays)
                : {anchor.weekday}),
        _anchorDay = anchor.day,
        _anchorMonth = anchor.month;

  final DateTime anchor;
  final RecurrenceFormValue value;
  final Set<int> _effectiveWeekdays;
  final int _anchorDay;
  final int _anchorMonth;

  static const int _maxIterations = 5000;

  DateTime? untilForCount(int count) {
    if (count <= 1) return anchor;
    var current = anchor;
    for (var produced = 1;
        produced < count && produced < _maxIterations;
        produced++) {
      current = _nextOccurrence(current);
    }
    return current;
  }

  int? countThrough(DateTime until) {
    if (until.isBefore(anchor)) {
      return 1;
    }
    var current = anchor;
    var occurrences = 1;
    for (var guard = 0; guard < _maxIterations; guard++) {
      final next = _nextOccurrence(current);
      if (next.isAfter(until)) {
        break;
      }
      current = next;
      occurrences++;
      if (!next.isBefore(until)) {
        break;
      }
    }
    return occurrences;
  }

  DateTime _nextOccurrence(DateTime current) {
    switch (value.frequency) {
      case RecurrenceFrequency.none:
        return current;
      case RecurrenceFrequency.daily:
        return current.add(Duration(days: math.max(value.interval, 1)));
      case RecurrenceFrequency.weekdays:
      case RecurrenceFrequency.weekly:
        return _advanceWeekly(current);
      case RecurrenceFrequency.monthly:
        return _advanceMonthly(current);
      case RecurrenceFrequency.yearly:
        return _advanceYearly(current);
    }
  }

  DateTime _advanceWeekly(DateTime current) {
    final sorted = _effectiveWeekdays.toList()..sort();
    if (sorted.isEmpty) {
      sorted.add(anchor.weekday);
    }
    for (final day in sorted) {
      if (day > current.weekday) {
        return current.add(Duration(days: day - current.weekday));
      }
    }
    final int firstDay = sorted.first;
    final int intervalWeeks = math.max(value.interval, 1);
    final int daysToNextCycle = ((intervalWeeks - 1) * 7) +
        ((DateTime.sunday - current.weekday + 7) % 7) +
        firstDay;
    return current.add(Duration(days: daysToNextCycle));
  }

  DateTime _advanceMonthly(DateTime current) {
    final int intervalMonths = math.max(value.interval, 1);
    final int newMonthIndex = (current.month - 1) + intervalMonths;
    final int year = current.year + (newMonthIndex ~/ 12);
    final int month = (newMonthIndex % 12) + 1;
    final int day = _clampDay(_anchorDay, year, month);
    return DateTime(
      year,
      month,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  DateTime _advanceYearly(DateTime current) {
    final int intervalYears = math.max(value.interval, 1);
    final int year = current.year + intervalYears;
    final int day = _clampDay(_anchorDay, year, _anchorMonth);
    return DateTime(
      year,
      _anchorMonth,
      day,
      current.hour,
      current.minute,
      current.second,
      current.millisecond,
      current.microsecond,
    );
  }

  int _clampDay(int desiredDay, int year, int month) {
    return math.min(desiredDay, _daysInMonth(year, month));
  }

  int _daysInMonth(int year, int month) {
    final DateTime firstNext =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    return firstNext.subtract(const Duration(days: 1)).day;
  }
}
