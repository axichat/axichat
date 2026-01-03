// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const double _availabilityRequestSheetSpacing = 16.0;
const double _availabilityRequestSheetGap = 8.0;
const double _availabilityRequestSheetHeaderIconSize = 18.0;
const double _availabilityRequestSheetProgressStrokeWidth = 2.0;
const double _availabilityRequestDescriptionMinHeight = 120.0;
const double _availabilityDecisionSpacing = 12.0;
const double _availabilityDecisionTextSpacing = 6.0;
const double _availabilityRequestLabelLetterSpacing = 0.4;
const int _availabilityRequestDescriptionMinLines = 4;
const int _availabilityRequestDescriptionMaxLines = 6;
const int _availabilityTextFieldDefaultMinLines = 1;
const int _availabilityTextFieldDefaultMaxLines = 1;

const String _availabilityRequestTitle = 'Request time';
const String _availabilityRequestSubtitle =
    'Choose a free slot and share details.';
const String _availabilityRequestLabel = 'Details';
const String _availabilityRequestRangeLabel = 'Range';
const String _availabilityRequestTitleLabel = 'Title';
const String _availabilityRequestTitlePlaceholder = 'What is this for?';
const String _availabilityRequestDescriptionLabel = 'Description';
const String _availabilityRequestDescriptionPlaceholder =
    'Add context (optional).';
const String _availabilityRequestSendLabel = 'Send request';
const String _availabilityRequestInvalidRangeMessage =
    'Pick a valid time range.';
const String _availabilityRequestNotFreeMessage =
    'Select a free slot before sending.';
const String _availabilityDecisionTitle = 'Accept request';
const String _availabilityDecisionSubtitle =
    'Choose which calendars should receive it.';
const String _availabilityDecisionPersonalLabel = 'Add to personal calendar';
const String _availabilityDecisionChatLabel = 'Add to chat calendar';
const String _availabilityDecisionConfirmLabel = 'Confirm';
const String _availabilityDecisionMissingSelectionMessage =
    'Select at least one calendar.';
const String _availabilityDecisionSummaryLabel = 'Requested';
const String _availabilityRangeSeparator = ' - ';
const String _availabilityRequestTitleFallback = 'Requested time';
const IconData _availabilityRequestIcon = LucideIcons.send;
const IconData _availabilityDecisionIcon = LucideIcons.check;

const Uuid _availabilityRequestIdGenerator = Uuid();

class CalendarAvailabilityDecision {
  const CalendarAvailabilityDecision({
    required this.addToPersonal,
    required this.addToChat,
  });

  final bool addToPersonal;
  final bool addToChat;
}

Future<CalendarAvailabilityRequest?> showCalendarAvailabilityRequestSheet({
  required BuildContext context,
  required CalendarAvailabilityShare share,
  required String requesterJid,
}) {
  return showAdaptiveBottomSheet<CalendarAvailabilityRequest>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarAvailabilityRequestSheet(
      share: share,
      requesterJid: requesterJid,
    ),
  );
}

Future<CalendarAvailabilityDecision?> showCalendarAvailabilityDecisionSheet({
  required BuildContext context,
  required CalendarAvailabilityRequest request,
  required bool canAddToPersonal,
  required bool canAddToChat,
}) {
  return showAdaptiveBottomSheet<CalendarAvailabilityDecision>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarAvailabilityDecisionSheet(
      request: request,
      canAddToPersonal: canAddToPersonal,
      canAddToChat: canAddToChat,
    ),
  );
}

class CalendarAvailabilityRequestSheet extends StatefulWidget {
  const CalendarAvailabilityRequestSheet({
    super.key,
    required this.share,
    required this.requesterJid,
  });

  final CalendarAvailabilityShare share;
  final String requesterJid;

  @override
  State<CalendarAvailabilityRequestSheet> createState() =>
      _CalendarAvailabilityRequestSheetState();
}

class _CalendarAvailabilityRequestSheetState
    extends State<CalendarAvailabilityRequestSheet> {
  late DateTime? _start;
  late DateTime? _end;
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final defaults = _defaultRequestRange(widget.share.overlay);
    _start = defaults.start;
    _end = defaults.end;
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_availabilityRequestTitle),
      subtitle: const Text(_availabilityRequestSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _AvailabilitySheetSectionLabel(
            text: _availabilityRequestRangeLabel),
        ScheduleRangeFields(
          start: _start,
          end: _end,
          onStartChanged: _handleStartChanged,
          onEndChanged: _handleEndChanged,
          minDate: widget.share.overlay.rangeStart.value,
          maxDate: widget.share.overlay.rangeEnd.value,
        ),
        const SizedBox(height: _availabilityRequestSheetSpacing),
        const _AvailabilitySheetSectionLabel(text: _availabilityRequestLabel),
        _AvailabilityTextField(
          label: _availabilityRequestTitleLabel,
          placeholder: _availabilityRequestTitlePlaceholder,
          controller: _titleController,
        ),
        const SizedBox(height: _availabilityRequestSheetGap),
        _AvailabilityTextField(
          label: _availabilityRequestDescriptionLabel,
          placeholder: _availabilityRequestDescriptionPlaceholder,
          controller: _descriptionController,
          minLines: _availabilityRequestDescriptionMinLines,
          maxLines: _availabilityRequestDescriptionMaxLines,
          minHeight: _availabilityRequestDescriptionMinHeight,
        ),
        const SizedBox(height: _availabilityRequestSheetSpacing),
        _AvailabilitySheetActionRow(
          isBusy: _isSending,
          onPressed: _handleSendPressed,
          label: _availabilityRequestSendLabel,
          iconData: _availabilityRequestIcon,
        ),
      ],
    );
    return body;
  }

  void _handleStartChanged(DateTime? value) {
    setState(() {
      _start = value;
      final end = _end;
      if (value != null && end != null && !end.isAfter(value)) {
        _end = _clampEnd(value, widget.share.overlay.rangeEnd.value);
      }
    });
  }

  void _handleEndChanged(DateTime? value) {
    setState(() {
      _end = value;
    });
  }

  Future<void> _handleSendPressed() async {
    if (_isSending) {
      return;
    }
    final start = _start;
    final end = _end;
    if (start == null || end == null || !end.isAfter(start)) {
      FeedbackSystem.showError(
          context, _availabilityRequestInvalidRangeMessage);
      return;
    }
    final overlay = widget.share.overlay;
    final isFree = _isRangeFree(overlay, start, end);
    if (!isFree) {
      FeedbackSystem.showError(context, _availabilityRequestNotFreeMessage);
      return;
    }
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    final ownerJid = widget.share.overlay.owner.trim();
    final resolvedOwnerJid = ownerJid.isEmpty ? null : ownerJid;
    setState(() {
      _isSending = true;
    });
    try {
      final request = CalendarAvailabilityRequest(
        id: _availabilityRequestIdGenerator.v4(),
        shareId: widget.share.id,
        requesterJid: widget.requesterJid,
        ownerJid: resolvedOwnerJid,
        start: _wrapDateTime(overlay.rangeStart, start),
        end: _wrapDateTime(overlay.rangeStart, end),
        title: title.isEmpty ? null : title,
        description: description.isEmpty ? null : description,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(request);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }
}

class CalendarAvailabilityDecisionSheet extends StatefulWidget {
  const CalendarAvailabilityDecisionSheet({
    super.key,
    required this.request,
    required this.canAddToPersonal,
    required this.canAddToChat,
  });

  final CalendarAvailabilityRequest request;
  final bool canAddToPersonal;
  final bool canAddToChat;

  @override
  State<CalendarAvailabilityDecisionSheet> createState() =>
      _CalendarAvailabilityDecisionSheetState();
}

class _CalendarAvailabilityDecisionSheetState
    extends State<CalendarAvailabilityDecisionSheet> {
  late bool _addToPersonal;
  late bool _addToChat;

  @override
  void initState() {
    super.initState();
    _addToPersonal = widget.canAddToPersonal;
    _addToChat = widget.canAddToChat && !widget.canAddToPersonal;
  }

  @override
  Widget build(BuildContext context) {
    final header = AxiSheetHeader(
      title: const Text(_availabilityDecisionTitle),
      subtitle: const Text(_availabilityDecisionSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        const _AvailabilitySheetSectionLabel(
          text: _availabilityDecisionSummaryLabel,
        ),
        _AvailabilityDecisionSummary(request: widget.request),
        const SizedBox(height: _availabilityRequestSheetSpacing),
        if (widget.canAddToPersonal)
          _AvailabilityDecisionToggle(
            label: _availabilityDecisionPersonalLabel,
            value: _addToPersonal,
            onChanged: (value) => setState(() {
              _addToPersonal = value;
            }),
          ),
        if (widget.canAddToChat) ...[
          const SizedBox(height: _availabilityDecisionSpacing),
          _AvailabilityDecisionToggle(
            label: _availabilityDecisionChatLabel,
            value: _addToChat,
            onChanged: (value) => setState(() {
              _addToChat = value;
            }),
          ),
        ],
        const SizedBox(height: _availabilityRequestSheetSpacing),
        _AvailabilitySheetActionRow(
          isBusy: false,
          onPressed: _handleConfirmPressed,
          label: _availabilityDecisionConfirmLabel,
          iconData: _availabilityDecisionIcon,
        ),
      ],
    );
    return body;
  }

  void _handleConfirmPressed() {
    if (!_addToPersonal && !_addToChat) {
      FeedbackSystem.showError(
        context,
        _availabilityDecisionMissingSelectionMessage,
      );
      return;
    }
    Navigator.of(context).pop(
      CalendarAvailabilityDecision(
        addToPersonal: _addToPersonal,
        addToChat: _addToChat,
      ),
    );
  }
}

class _AvailabilitySheetSectionLabel extends StatelessWidget {
  const _AvailabilitySheetSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: _availabilityRequestSheetGap),
      child: Text(
        text,
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
          color: context.colorScheme.mutedForeground,
          letterSpacing: _availabilityRequestLabelLetterSpacing,
        ),
      ),
    );
  }
}

class _AvailabilityTextField extends StatelessWidget {
  const _AvailabilityTextField({
    required this.label,
    required this.placeholder,
    required this.controller,
    this.minLines = _availabilityTextFieldDefaultMinLines,
    this.maxLines = _availabilityTextFieldDefaultMaxLines,
    this.minHeight,
  });

  final String label;
  final String placeholder;
  final TextEditingController controller;
  final int minLines;
  final int maxLines;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    final field = AxiTextFormField(
      controller: controller,
      placeholder: Text(placeholder),
      minLines: minLines,
      maxLines: maxLines,
    );
    final Widget content = minHeight == null
        ? field
        : ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight!),
            child: field,
          );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
            color: context.colorScheme.mutedForeground,
          ),
        ),
        const SizedBox(height: _availabilityRequestSheetGap),
        content,
      ],
    );
  }
}

class _AvailabilityDecisionSummary extends StatelessWidget {
  const _AvailabilityDecisionSummary({required this.request});

  final CalendarAvailabilityRequest request;

  @override
  Widget build(BuildContext context) {
    final title = request.title?.trim().isNotEmpty == true
        ? request.title!.trim()
        : _availabilityRequestTitleFallback;
    final range = _formatRange(request.start.value, request.end.value);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.small.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: _availabilityDecisionTextSpacing),
        Text(
          range,
          style: context.textTheme.small.copyWith(
            color: context.colorScheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityDecisionToggle extends StatelessWidget {
  const _AvailabilityDecisionToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AxiCheckboxFormField(
      initialValue: value,
      inputLabel: Text(label),
      onChanged: onChanged,
    );
  }
}

class _AvailabilitySheetActionRow extends StatelessWidget {
  const _AvailabilitySheetActionRow({
    required this.isBusy,
    required this.onPressed,
    required this.label,
    required this.iconData,
  });

  final bool isBusy;
  final VoidCallback onPressed;
  final String label;
  final IconData iconData;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: isBusy ? null : onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isBusy)
              const SizedBox(
                width: _availabilityRequestSheetHeaderIconSize,
                height: _availabilityRequestSheetHeaderIconSize,
                child: CircularProgressIndicator(
                  strokeWidth: _availabilityRequestSheetProgressStrokeWidth,
                ),
              )
            else
              Icon(
                iconData,
                size: _availabilityRequestSheetHeaderIconSize,
              ),
            const SizedBox(width: _availabilityRequestSheetGap),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _RequestRangeDefaults {
  const _RequestRangeDefaults({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;
}

_RequestRangeDefaults _defaultRequestRange(
    CalendarAvailabilityOverlay overlay) {
  final List<CalendarFreeBusyInterval> freeIntervals = overlay.intervals
      .where((interval) => interval.type == CalendarFreeBusyType.free)
      .toList()
    ..sort((a, b) => a.start.value.compareTo(b.start.value));
  if (freeIntervals.isNotEmpty) {
    final interval = freeIntervals.first;
    final start = interval.start.value;
    final end = _clampEnd(start, interval.end.value);
    return _RequestRangeDefaults(start: start, end: end);
  }
  final start = overlay.rangeStart.value;
  final end = _clampEnd(start, overlay.rangeEnd.value);
  return _RequestRangeDefaults(start: start, end: end);
}

DateTime _clampEnd(DateTime start, DateTime maxEnd) {
  final DateTime proposed = start.add(calendarDefaultTaskDuration);
  if (proposed.isAfter(maxEnd)) {
    return maxEnd;
  }
  return proposed;
}

bool _isRangeFree(
  CalendarAvailabilityOverlay overlay,
  DateTime start,
  DateTime end,
) {
  if (!end.isAfter(start)) {
    return false;
  }
  for (final interval in overlay.intervals) {
    if (interval.type != CalendarFreeBusyType.free) {
      continue;
    }
    final intervalStart = interval.start.value;
    final intervalEnd = interval.end.value;
    final bool startsInInterval =
        !start.isBefore(intervalStart) && start.isBefore(intervalEnd);
    final bool endsInInterval =
        end.isAfter(intervalStart) && !end.isAfter(intervalEnd);
    if (startsInInterval && endsInInterval) {
      return true;
    }
  }
  return false;
}

CalendarDateTime _wrapDateTime(CalendarDateTime template, DateTime value) {
  return CalendarDateTime(
    value: value,
    tzid: template.tzid,
    isAllDay: template.isAllDay,
    isFloating: template.isFloating,
  );
}

String _formatRange(DateTime start, DateTime end) {
  final String startLabel = TimeFormatter.formatFriendlyDateTime(start);
  final String endLabel = TimeFormatter.formatFriendlyDateTime(end);
  if (startLabel == endLabel) {
    return startLabel;
  }
  return '$startLabel$_availabilityRangeSeparator$endLabel';
}
