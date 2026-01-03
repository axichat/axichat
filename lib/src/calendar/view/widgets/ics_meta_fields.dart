// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const String _icsMetaSectionTitle = 'Status & visibility';
const String _icsMetaVisibilityTitle = 'Visibility';
const String _icsMetaStatusLabel = 'Status';
const String _icsMetaTransparencyLabel = 'Availability';
const String _icsMetaDefaultLabel = 'Default';
const double _icsMetaLabelFontSize = 12;
const double _icsMetaLabelLetterSpacing = 0.2;
const double _icsMetaSelectIconSize = 16;

class CalendarIcsMetaFields extends StatelessWidget {
  const CalendarIcsMetaFields({
    super.key,
    required this.status,
    required this.transparency,
    required this.onStatusChanged,
    required this.onTransparencyChanged,
    this.title = _icsMetaSectionTitle,
    this.showStatus = true,
    this.enabled = true,
  });

  final CalendarIcsStatus? status;
  final CalendarTransparency? transparency;
  final ValueChanged<CalendarIcsStatus?> onStatusChanged;
  final ValueChanged<CalendarTransparency?> onTransparencyChanged;
  final String title;
  final bool showStatus;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final String resolvedTitle = showStatus || title != _icsMetaSectionTitle
        ? title
        : _icsMetaVisibilityTitle;
    final List<ShadOption<CalendarIcsStatus?>> statusOptions = [
      const ShadOption<CalendarIcsStatus?>(
        value: null,
        child: Text(_icsMetaDefaultLabel),
      ),
      ...CalendarIcsStatus.values.map(
        (status) => ShadOption<CalendarIcsStatus?>(
          value: status,
          child: Text(status.label),
        ),
      ),
    ];
    final List<ShadOption<CalendarTransparency?>> transparencyOptions = [
      const ShadOption<CalendarTransparency?>(
        value: null,
        child: Text(_icsMetaDefaultLabel),
      ),
      ...CalendarTransparency.values.map(
        (transparency) => ShadOption<CalendarTransparency?>(
          value: transparency,
          child: Text(transparency.label),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: resolvedTitle),
        const SizedBox(height: calendarGutterSm),
        if (showStatus) ...[
          _IcsSelectField<CalendarIcsStatus?>(
            label: _icsMetaStatusLabel,
            value: status,
            options: statusOptions,
            selectedLabel: (status) => status?.label ?? _icsMetaDefaultLabel,
            onChanged: enabled ? onStatusChanged : null,
            enabled: enabled,
          ),
          const SizedBox(height: calendarGutterMd),
        ],
        _IcsSelectField<CalendarTransparency?>(
          label: _icsMetaTransparencyLabel,
          value: transparency,
          options: transparencyOptions,
          selectedLabel: (transparency) =>
              transparency?.label ?? _icsMetaDefaultLabel,
          onChanged: enabled ? onTransparencyChanged : null,
          enabled: enabled,
        ),
      ],
    );
  }
}

class _IcsSelectField<T> extends StatelessWidget {
  const _IcsSelectField({
    required this.label,
    required this.value,
    required this.options,
    required this.selectedLabel,
    required this.onChanged,
    required this.enabled,
  });

  final String label;
  final T value;
  final List<ShadOption<T>> options;
  final String Function(T value) selectedLabel;
  final ValueChanged<T?>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _icsMetaLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _icsMetaLabelLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: calendarGutterSm),
        IgnorePointer(
          ignoring: !enabled,
          child: ShadSelect<T>(
            initialValue: value,
            onChanged: onChanged,
            options: options,
            selectedOptionBuilder: (context, selected) => Text(
              selected == null ? _icsMetaDefaultLabel : selectedLabel(selected),
            ),
            decoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                radius: BorderRadius.circular(calendarBorderRadius),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterMd,
              vertical: calendarGutterSm,
            ),
            trailing: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: _icsMetaSelectIconSize,
              color: calendarSubtitleColor,
            ),
          ),
        ),
      ],
    );
  }
}
