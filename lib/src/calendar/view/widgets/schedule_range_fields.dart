import 'package:flutter/material.dart';

import '../../../common/ui/ui.dart';
import 'deadline_picker_field.dart';

/// Displays paired date/time inputs for start and end selections, matching the
/// original calendar styling. Stacks vertically on narrow layouts.
class ScheduleRangeFields extends StatelessWidget {
  const ScheduleRangeFields({
    super.key,
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    this.startLabel = 'START',
    this.endLabel = 'END',
    this.startPlaceholder = 'Select start',
    this.endPlaceholder = 'Select end',
    this.showTimeSelectors = true,
    this.minDate,
    this.maxDate,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final String startLabel;
  final String endLabel;
  final String startPlaceholder;
  final String endPlaceholder;
  final bool showTimeSelectors;
  final DateTime? minDate;
  final DateTime? maxDate;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool shouldStack = constraints.maxWidth < 420;
        final Widget startField = _ScheduleField(
          label: startLabel,
          placeholder: startPlaceholder,
          value: start,
          onChanged: onStartChanged,
          showTimeSelectors: showTimeSelectors,
          minDate: minDate,
          maxDate: end ?? maxDate,
        );
        final Widget endField = _ScheduleField(
          label: endLabel,
          placeholder: endPlaceholder,
          value: end,
          onChanged: onEndChanged,
          showTimeSelectors: showTimeSelectors,
          minDate: start ?? minDate,
          maxDate: maxDate,
        );

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              startField,
              const SizedBox(height: calendarGutterMd),
              endField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: startField),
            const SizedBox(width: calendarGutterMd),
            Expanded(child: endField),
          ],
        );
      },
    );
  }
}

class _ScheduleField extends StatelessWidget {
  const _ScheduleField({
    required this.label,
    required this.placeholder,
    required this.value,
    required this.onChanged,
    required this.showTimeSelectors,
    this.minDate,
    this.maxDate,
  });

  final String label;
  final String placeholder;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool showTimeSelectors;
  final DateTime? minDate;
  final DateTime? maxDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: calendarInsetLg),
        DeadlinePickerField(
          value: value,
          placeholder: placeholder,
          showStatusColors: false,
          showTimeSelectors: showTimeSelectors,
          minDate: minDate,
          maxDate: maxDate,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
