// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

const String _invitationRequestStatusProperty = 'REQUEST-STATUS';
const String _invitationRequestStatusSeparator = ';';
const double _invitationLabelLetterSpacing = 0.2;

String _calendarMethodLabel(AppLocalizations l10n, CalendarMethod method) =>
    switch (method) {
      CalendarMethod.publish => l10n.calendarMethodPublish,
      CalendarMethod.request => l10n.calendarMethodRequest,
      CalendarMethod.reply => l10n.calendarMethodReply,
      CalendarMethod.cancel => l10n.calendarMethodCancel,
      CalendarMethod.add => l10n.calendarMethodAdd,
      CalendarMethod.refresh => l10n.calendarMethodRefresh,
      CalendarMethod.counter => l10n.calendarMethodCounter,
      CalendarMethod.declineCounter => l10n.calendarMethodDeclineCounter,
    };

bool hasInvitationStatusData({
  required CalendarMethod? method,
  required int? sequence,
  required List<CalendarRawProperty> rawProperties,
}) {
  final CalendarMethod? effectiveMethod = method != null && method.isPublish
      ? null
      : method;
  if (effectiveMethod != null || sequence != null) {
    return true;
  }
  return _parseRequestStatus(rawProperties).isNotEmpty;
}

class CalendarInvitationStatusField extends StatelessWidget {
  const CalendarInvitationStatusField({
    super.key,
    required this.method,
    required this.sequence,
    required this.rawProperties,
    this.title,
  });

  final CalendarMethod? method;
  final int? sequence;
  final List<CalendarRawProperty> rawProperties;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final CalendarMethod? effectiveMethod = method != null && method!.isPublish
        ? null
        : method;
    final List<CalendarRequestStatusEntry> entries = _parseRequestStatus(
      rawProperties,
    );
    if (!hasInvitationStatusData(
      method: effectiveMethod,
      sequence: sequence,
      rawProperties: rawProperties,
    )) {
      return const SizedBox.shrink();
    }

    final TextStyle labelStyle = context.textTheme.label.strong.copyWith(
      color: calendarSubtitleColor,
      letterSpacing: _invitationLabelLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title ?? l10n.calendarInvitationStatusTitle),
        SizedBox(height: context.spacing.s),
        if (effectiveMethod != null)
          _InvitationDetailRow(
            label: l10n.calendarInvitationMethodLabel,
            value: _calendarMethodLabel(l10n, effectiveMethod),
          ),
        if (sequence != null) ...[
          if (effectiveMethod != null) SizedBox(height: context.spacing.xs),
          _InvitationDetailRow(
            label: l10n.calendarInvitationSequenceLabel,
            value: sequence!.toString(),
          ),
        ],
        if (entries.isNotEmpty) ...[
          SizedBox(height: context.spacing.xs),
          Text(
            l10n.calendarInvitationRequestStatusLabel.toUpperCase(),
            style: labelStyle,
          ),
          SizedBox(height: context.spacing.xxs),
          ...entries.map(
            (entry) => Padding(
              padding: EdgeInsets.only(bottom: context.spacing.xxs),
              child: _RequestStatusTile(entry: entry),
            ),
          ),
        ],
      ],
    );
  }
}

class CalendarRequestStatusEntry {
  const CalendarRequestStatusEntry({
    required this.code,
    required this.rawValue,
    this.description,
    this.extra,
  });

  final String code;
  final String rawValue;
  final String? description;
  final String? extra;
}

List<CalendarRequestStatusEntry> _parseRequestStatus(
  List<CalendarRawProperty> rawProperties,
) {
  final List<CalendarRequestStatusEntry> entries =
      <CalendarRequestStatusEntry>[];
  for (final CalendarRawProperty property in rawProperties) {
    final String name = property.name.trim().toUpperCase();
    if (name != _invitationRequestStatusProperty) {
      continue;
    }
    final List<String> parts = property.value
        .split(_invitationRequestStatusSeparator)
        .map((part) => part.trim())
        .toList();
    final String code = parts.isNotEmpty ? parts.first : '';
    final String? description = parts.length > 1 && parts[1].isNotEmpty
        ? parts[1]
        : null;
    final String? extra = parts.length > 2
        ? parts.sublist(2).join(_invitationRequestStatusSeparator).trim()
        : null;
    entries.add(
      CalendarRequestStatusEntry(
        code: code,
        rawValue: property.value,
        description: description,
        extra: extra?.isEmpty == true ? null : extra,
      ),
    );
  }
  return entries;
}

class _InvitationDetailRow extends StatelessWidget {
  const _InvitationDetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = context.textTheme.label.strong.copyWith(
      color: calendarSubtitleColor,
      letterSpacing: _invitationLabelLetterSpacing,
    );
    final TextStyle valueStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        SizedBox(height: context.spacing.xxs),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _RequestStatusTile extends StatelessWidget {
  const _RequestStatusTile({required this.entry});

  final CalendarRequestStatusEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.small.strong.copyWith(
      color: calendarTitleColor,
    );
    final TextStyle subtitleStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final String code = entry.code.isNotEmpty
        ? entry.code
        : context.l10n.calendarInvitationRequestStatusLabel;
    final String description = entry.description ?? entry.rawValue;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.s,
        vertical: context.spacing.xs,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: context.radius,
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(code, style: titleStyle),
          if (description.isNotEmpty) ...[
            SizedBox(height: context.spacing.xxs),
            Text(description, style: subtitleStyle),
          ],
          if (entry.extra != null) ...[
            SizedBox(height: context.spacing.xxs),
            Text(entry.extra!, style: subtitleStyle),
          ],
        ],
      ),
    );
  }
}
