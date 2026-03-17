// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';

/// Displays paired date/time inputs for start and end selections, matching the
/// original calendar styling. Stacks vertically on narrow layouts.
class ScheduleRangeFields extends StatelessWidget {
  const ScheduleRangeFields({
    super.key,
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    this.startLabel,
    this.endLabel,
    this.startPlaceholder,
    this.endPlaceholder,
    this.showTimeSelectors = true,
    this.minDate,
    this.maxDate,
    this.enabled = true,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final String? startLabel;
  final String? endLabel;
  final String? startPlaceholder;
  final String? endPlaceholder;
  final bool showTimeSelectors;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final l10n = context.l10n;
        final String resolvedStartLabel = startLabel ?? l10n.commonStart;
        final String resolvedEndLabel = endLabel ?? l10n.commonEnd;
        final String resolvedStartPlaceholder =
            startPlaceholder ?? l10n.commonSelectStart;
        final String resolvedEndPlaceholder =
            endPlaceholder ?? l10n.commonSelectEnd;
        final bool shouldStack = constraints.maxWidth < 420;
        final spacing = context.spacing;
        final Widget startField = _ScheduleField(
          label: resolvedStartLabel,
          placeholder: resolvedStartPlaceholder,
          value: start,
          onChanged: onStartChanged,
          showTimeSelectors: showTimeSelectors,
          minDate: minDate,
          maxDate: maxDate,
          enabled: enabled,
        );
        final Widget endField = _ScheduleField(
          label: resolvedEndLabel,
          placeholder: resolvedEndPlaceholder,
          value: end,
          onChanged: onEndChanged,
          showTimeSelectors: showTimeSelectors,
          minDate: start ?? minDate,
          maxDate: maxDate,
          enabled: enabled,
        );

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              startField,
              SizedBox(height: spacing.m),
              endField,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: startField),
            SizedBox(width: spacing.m),
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
    required this.enabled,
  });

  final String label;
  final String placeholder;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool showTimeSelectors;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.labelSm.strong.copyWith(
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        SizedBox(height: spacing.s),
        CalendarDateTimeField(
          value: value,
          placeholder: placeholder,
          showStatusColors: false,
          showTimeSelectors: showTimeSelectors,
          minDate: minDate,
          maxDate: maxDate,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}
