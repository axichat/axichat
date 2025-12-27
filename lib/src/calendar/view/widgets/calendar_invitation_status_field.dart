import 'package:flutter/material.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';

const String _invitationSectionTitle = 'Invitation status';
const String _invitationMethodLabel = 'Message';
const String _invitationSequenceLabel = 'Sequence';
const String _invitationRequestStatusLabel = 'Request status';
const String _invitationRequestStatusProperty = 'REQUEST-STATUS';
const String _invitationRequestStatusSeparator = ';';
const String _invitationRequestStatusFallbackLabel = 'Request status';
const double _invitationLabelLetterSpacing = 0.2;
const double _invitationLabelFontSize = 12;

bool hasInvitationStatusData({
  required CalendarMethod? method,
  required int? sequence,
  required List<CalendarRawProperty> rawProperties,
}) {
  final CalendarMethod? effectiveMethod =
      method != null && method.isPublish ? null : method;
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
    this.title = _invitationSectionTitle,
  });

  final CalendarMethod? method;
  final int? sequence;
  final List<CalendarRawProperty> rawProperties;
  final String title;

  @override
  Widget build(BuildContext context) {
    final CalendarMethod? effectiveMethod =
        method != null && method!.isPublish ? null : method;
    final List<CalendarRequestStatusEntry> entries =
        _parseRequestStatus(rawProperties);
    if (!hasInvitationStatusData(
      method: effectiveMethod,
      sequence: sequence,
      rawProperties: rawProperties,
    )) {
      return const SizedBox.shrink();
    }

    final TextStyle labelStyle = context.textTheme.small.copyWith(
      color: calendarSubtitleColor,
      fontWeight: FontWeight.w600,
      letterSpacing: _invitationLabelLetterSpacing,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: title),
        const SizedBox(height: calendarGutterSm),
        if (effectiveMethod != null)
          _InvitationDetailRow(
            label: _invitationMethodLabel,
            value: effectiveMethod.label,
          ),
        if (sequence != null) ...[
          if (effectiveMethod != null) const SizedBox(height: calendarInsetMd),
          _InvitationDetailRow(
            label: _invitationSequenceLabel,
            value: sequence!.toString(),
          ),
        ],
        if (entries.isNotEmpty) ...[
          const SizedBox(height: calendarInsetMd),
          Text(_invitationRequestStatusLabel.toUpperCase(), style: labelStyle),
          const SizedBox(height: calendarInsetSm),
          ...entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetSm),
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
    final String? description =
        parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
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
  const _InvitationDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle labelStyle = TextStyle(
      fontSize: _invitationLabelFontSize,
      fontWeight: FontWeight.w600,
      color: calendarSubtitleColor,
      letterSpacing: _invitationLabelLetterSpacing,
    );
    final TextStyle valueStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: labelStyle),
        const SizedBox(height: calendarInsetSm),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _RequestStatusTile extends StatelessWidget {
  const _RequestStatusTile({
    required this.entry,
  });

  final CalendarRequestStatusEntry entry;

  @override
  Widget build(BuildContext context) {
    final TextStyle titleStyle = context.textTheme.small.copyWith(
      color: calendarTitleColor,
      fontWeight: FontWeight.w600,
    );
    final TextStyle subtitleStyle = context.textTheme.muted.copyWith(
      color: calendarSubtitleColor,
    );
    final String code = entry.code.isNotEmpty
        ? entry.code
        : _invitationRequestStatusFallbackLabel;
    final String description = entry.description ?? entry.rawValue;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(code, style: titleStyle),
          if (description.isNotEmpty) ...[
            const SizedBox(height: calendarInsetSm),
            Text(description, style: subtitleStyle),
          ],
          if (entry.extra != null) ...[
            const SizedBox(height: calendarInsetSm),
            Text(entry.extra!, style: subtitleStyle),
          ],
        ],
      ),
    );
  }
}
