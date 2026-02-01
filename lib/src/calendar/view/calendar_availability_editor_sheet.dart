// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:uuid/uuid.dart';

const double _availabilityEditorSpacing = 16.0;
const double _availabilityEditorGap = 8.0;
const double _availabilityEditorCardSpacing = 12.0;
const double _availabilityEditorCardRadius = 12.0;
const double _availabilityEditorCardBorderWidth = 1.0;
const double _availabilityEditorHeaderIconSize = 18.0;
const double _availabilityEditorRemoveIconSize = 16.0;
const double _availabilityEditorRemoveButtonSize = 32.0;
const double _availabilityEditorRemoveTapTargetSize = 36.0;
const double _availabilityEditorRemoveCornerRadius = 12.0;
const int _availabilityEditorDescriptionMinLines = 3;
const int _availabilityEditorDescriptionMaxLines = 4;

const EdgeInsets _availabilityEditorCardPadding = EdgeInsets.symmetric(
  horizontal: 16,
  vertical: 12,
);

const Uuid _availabilityEditorIdGenerator = Uuid();

Future<CalendarAvailability?> showCalendarAvailabilityEditorSheet({
  required BuildContext context,
  required CalendarModel model,
  CalendarAvailability? availability,
}) {
  final BuildContext modalContext = context.calendarModalContext;
  return showAdaptiveBottomSheet<CalendarAvailability>(
    context: modalContext,
    isScrollControlled: true,
    builder: (sheetContext) => CalendarAvailabilityEditorSheet(
      model: model,
      availability: availability,
    ),
  );
}

class CalendarAvailabilityEditorSheet extends StatefulWidget {
  const CalendarAvailabilityEditorSheet({
    super.key,
    required this.model,
    this.availability,
  });

  final CalendarModel model;
  final CalendarAvailability? availability;

  @override
  State<CalendarAvailabilityEditorSheet> createState() =>
      _CalendarAvailabilityEditorSheetState();
}

class _CalendarAvailabilityEditorSheetState
    extends State<CalendarAvailabilityEditorSheet> {
  late CalendarAvailability? _baseAvailability;
  late String _availabilityId;
  late List<_AvailabilityWindowDraft> _windowDrafts;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _baseAvailability = widget.availability ??
        _resolvePrimaryAvailability(widget.model.availability);
    _availabilityId =
        _baseAvailability?.id ?? _availabilityEditorIdGenerator.v4();
    _windowDrafts = _seedWindowDrafts(_baseAvailability);
  }

  @override
  void dispose() {
    for (final draft in _windowDrafts) {
      draft.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final header = AxiSheetHeader(
      title: Text(l10n.calendarAvailabilityWindowsTitle),
      subtitle: Text(l10n.calendarAvailabilityWindowsSubtitle),
      onClose: () => Navigator.of(context).maybePop(),
    );
    final body = AxiSheetScaffold.scroll(
      header: header,
      children: [
        TaskSectionHeader(
          title: l10n.calendarAvailabilityWindowsLabel,
          trailing: _AvailabilityEditorAddButton(onPressed: _handleAddWindow),
        ),
        const SizedBox(height: calendarGutterSm),
        if (_windowDrafts.isEmpty)
          Text(
            l10n.calendarAvailabilityNoWindows,
            style: context.textTheme.small.copyWith(
              color: context.colorScheme.mutedForeground,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final _AvailabilityWindowDraft draft in _windowDrafts)
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: _availabilityEditorCardSpacing,
                  ),
                  child: _AvailabilityWindowCard(
                    key: ValueKey<String>(draft.id),
                    draft: draft,
                    onStartChanged: (value) =>
                        _handleWindowStartChanged(draft, value),
                    onEndChanged: (value) =>
                        _handleWindowEndChanged(draft, value),
                    onRemove: () => _handleWindowRemoved(draft),
                  ),
                ),
            ],
          ),
        const SizedBox(height: _availabilityEditorSpacing),
        _AvailabilityEditorActionRow(
          isBusy: _isSaving,
          onPressed: _handleSavePressed,
        ),
      ],
    );
    return body;
  }

  void _handleAddWindow() {
    setState(() {
      _windowDrafts.add(_AvailabilityWindowDraft.create());
    });
  }

  void _handleWindowRemoved(_AvailabilityWindowDraft draft) {
    setState(() {
      _windowDrafts.remove(draft);
      draft.dispose();
    });
  }

  void _handleWindowStartChanged(
    _AvailabilityWindowDraft draft,
    DateTime? value,
  ) {
    setState(() {
      draft.start = value;
      final DateTime? end = draft.end;
      if (value != null && end != null && !end.isAfter(value)) {
        draft.end = value.add(calendarDefaultTaskDuration);
      }
    });
  }

  void _handleWindowEndChanged(
    _AvailabilityWindowDraft draft,
    DateTime? value,
  ) {
    setState(() {
      draft.end = value;
    });
  }

  Future<void> _handleSavePressed() async {
    if (_isSaving) {
      return;
    }
    if (_windowDrafts.isEmpty) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityEmptyWindowsError,
      );
      return;
    }
    final List<_AvailabilityWindowDraft> drafts = List.from(_windowDrafts);
    final bool hasInvalid = drafts.any(
      (draft) =>
          draft.start == null ||
          draft.end == null ||
          !draft.end!.isAfter(draft.start!),
    );
    if (hasInvalid) {
      FeedbackSystem.showError(
        context,
        context.l10n.calendarAvailabilityInvalidRangeError,
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });
    try {
      final CalendarAvailability availability = _buildAvailabilityFromDrafts(
        drafts,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(availability);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  CalendarAvailability _buildAvailabilityFromDrafts(
    List<_AvailabilityWindowDraft> drafts,
  ) {
    final String? tzid = _resolveTimeZone(widget.model);
    final List<CalendarAvailabilityWindow> windows = drafts
        .map(
          (draft) => CalendarAvailabilityWindow(
            start: _wrapDateTime(draft.start!, tzid),
            end: _wrapDateTime(draft.end!, tzid),
            summary: draft.summary,
            description: draft.description,
          ),
        )
        .toList(growable: false);
    DateTime rangeStart = drafts.first.start!;
    DateTime rangeEnd = drafts.first.end!;
    for (final draft in drafts.skip(1)) {
      final DateTime start = draft.start!;
      final DateTime end = draft.end!;
      if (start.isBefore(rangeStart)) {
        rangeStart = start;
      }
      if (end.isAfter(rangeEnd)) {
        rangeEnd = end;
      }
    }
    final CalendarIcsMeta nextMeta = _updatedAvailabilityMeta(
      _baseAvailability?.icsMeta,
    );
    return CalendarAvailability(
      id: _availabilityId,
      start: _wrapDateTime(rangeStart, tzid),
      end: _wrapDateTime(rangeEnd, tzid),
      summary: _baseAvailability?.summary,
      description: _baseAvailability?.description,
      windows: windows,
      icsMeta: nextMeta,
    );
  }

  CalendarIcsMeta _updatedAvailabilityMeta(CalendarIcsMeta? meta) {
    final now = DateTime.now();
    final CalendarIcsMeta base = meta ??
        CalendarIcsMeta(
          uid: _availabilityId,
          created: now,
          componentType: CalendarIcsComponentType.availability,
        );
    return base.copyWith(
      uid: base.uid ?? _availabilityId,
      created: base.created ?? now,
      dtStamp: now,
      lastModified: now,
      componentType:
          base.componentType ?? CalendarIcsComponentType.availability,
    );
  }
}

class _AvailabilityWindowCard extends StatelessWidget {
  const _AvailabilityWindowCard({
    super.key,
    required this.draft,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRemove,
  });

  final _AvailabilityWindowDraft draft;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: _availabilityEditorCardPadding,
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(_availabilityEditorCardRadius),
        border: Border.all(
          color: calendarBorderColor,
          width: _availabilityEditorCardBorderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskSectionHeader(
            title: l10n.calendarAvailabilityWindowLabel,
            trailing: _AvailabilityWindowRemoveButton(onPressed: onRemove),
          ),
          const SizedBox(height: _availabilityEditorGap),
          ScheduleRangeFields(
            start: draft.start,
            end: draft.end,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
          ),
          const SizedBox(height: _availabilityEditorSpacing),
          TaskTextField(
            controller: draft.summaryController,
            labelText: l10n.calendarAvailabilitySummaryLabel,
            hintText: l10n.calendarAvailabilitySummaryHint,
          ),
          const SizedBox(height: _availabilityEditorGap),
          TaskTextField(
            controller: draft.descriptionController,
            labelText: l10n.calendarAvailabilityNotesLabel,
            hintText: l10n.calendarAvailabilityNotesHint,
            minLines: _availabilityEditorDescriptionMinLines,
            maxLines: _availabilityEditorDescriptionMaxLines,
          ),
        ],
      ),
    );
  }
}

class _AvailabilityWindowRemoveButton extends StatelessWidget {
  const _AvailabilityWindowRemoveButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton(
      iconData: Icons.delete_outline,
      tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
      onPressed: onPressed,
      color: calendarDangerColor,
      backgroundColor: calendarContainerColor,
      borderColor: calendarBorderColor,
      iconSize: _availabilityEditorRemoveIconSize,
      buttonSize: _availabilityEditorRemoveButtonSize,
      tapTargetSize: _availabilityEditorRemoveTapTargetSize,
      cornerRadius: _availabilityEditorRemoveCornerRadius,
    );
  }
}

class _AvailabilityEditorAddButton extends StatelessWidget {
  const _AvailabilityEditorAddButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.ghost(
      size: AxiButtonSize.sm,
      onPressed: onPressed,
      leading:
          const Icon(LucideIcons.plus, size: _availabilityEditorHeaderIconSize),
      child: Text(context.l10n.calendarAvailabilityAddWindow),
    );
  }
}

class _AvailabilityEditorActionRow extends StatelessWidget {
  const _AvailabilityEditorActionRow({
    required this.isBusy,
    required this.onPressed,
  });

  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: AxiButton.primary(
        size: AxiButtonSize.sm,
        onPressed: isBusy ? null : onPressed,
        loading: isBusy,
        leading: const Icon(
          LucideIcons.check,
          size: _availabilityEditorHeaderIconSize,
        ),
        child: Text(context.l10n.calendarAvailabilitySaveWindows),
      ),
    );
  }
}

class _AvailabilityWindowDraft {
  _AvailabilityWindowDraft({
    required this.id,
    required this.start,
    required this.end,
    required this.summaryController,
    required this.descriptionController,
  });

  factory _AvailabilityWindowDraft.create() {
    final DateTime now = DateTime.now();
    final DateTime normalized = _normalizeDateTime(now);
    return _AvailabilityWindowDraft(
      id: _availabilityEditorIdGenerator.v4(),
      start: normalized,
      end: normalized.add(calendarDefaultTaskDuration),
      summaryController: TextEditingController(),
      descriptionController: TextEditingController(),
    );
  }

  factory _AvailabilityWindowDraft.fromWindow(
    CalendarAvailabilityWindow window,
  ) {
    return _AvailabilityWindowDraft(
      id: _availabilityEditorIdGenerator.v4(),
      start: window.start.value,
      end: window.end.value,
      summaryController: TextEditingController(text: window.summary ?? ''),
      descriptionController: TextEditingController(
        text: window.description ?? '',
      ),
    );
  }

  final String id;
  DateTime? start;
  DateTime? end;
  final TextEditingController summaryController;
  final TextEditingController descriptionController;

  String? get summary {
    final String value = summaryController.text.trim();
    return value.isEmpty ? null : value;
  }

  String? get description {
    final String value = descriptionController.text.trim();
    return value.isEmpty ? null : value;
  }

  void dispose() {
    summaryController.dispose();
    descriptionController.dispose();
  }
}

CalendarAvailability? _resolvePrimaryAvailability(
  Map<String, CalendarAvailability> availability,
) {
  if (availability.isEmpty) {
    return null;
  }
  final List<String> ids = availability.keys.toList()..sort();
  return availability[ids.first];
}

List<_AvailabilityWindowDraft> _seedWindowDrafts(
  CalendarAvailability? availability,
) {
  if (availability == null) {
    return <_AvailabilityWindowDraft>[];
  }
  final List<CalendarAvailabilityWindow> windows = _availabilityWindowsFor(
    availability,
  );
  return windows
      .map(_AvailabilityWindowDraft.fromWindow)
      .toList(growable: false);
}

List<CalendarAvailabilityWindow> _availabilityWindowsFor(
  CalendarAvailability availability,
) {
  if (availability.windows.isNotEmpty) {
    return availability.windows;
  }
  return <CalendarAvailabilityWindow>[
    CalendarAvailabilityWindow(
      start: availability.start,
      end: availability.end,
      summary: availability.summary,
      description: availability.description,
    ),
  ];
}

CalendarDateTime _wrapDateTime(DateTime value, String? tzid) {
  return CalendarDateTime(value: value, tzid: tzid);
}

DateTime _normalizeDateTime(DateTime now) {
  return DateTime(now.year, now.month, now.day, now.hour, now.minute);
}

String? _resolveTimeZone(CalendarModel model) {
  final raw = model.collection?.timeZone?.trim();
  if (raw == null || raw.isEmpty) {
    return null;
  }
  return raw;
}
