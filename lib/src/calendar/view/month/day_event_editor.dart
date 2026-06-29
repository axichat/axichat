// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/reminders/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/interop/calendar_share.dart';
import 'package:axichat/src/calendar/interop/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/interop/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_attachments_field.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_categories_field.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_ics_diagnostics_section.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_invitation_status_field.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_link_geo_fields.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_participants_field.dart';
import 'package:axichat/src/calendar/view/tasks/reminder_preferences_field.dart';
import 'package:axichat/src/calendar/view/tasks/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAttachment> _emptyAttachments = <CalendarAttachment>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];
const List<CalendarRawProperty> _emptyRawProperties = <CalendarRawProperty>[];

class DayEventDraft {
  const DayEventDraft({
    required this.title,
    required this.startDate,
    required this.endDate,
    this.description,
    required this.reminders,
    this.icsMeta,
  });

  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String? description;
  final ReminderPreferences reminders;
  final CalendarIcsMeta? icsMeta;
}

class DayEventEditorResult {
  const DayEventEditorResult.save(this.draft) : deleted = false;

  const DayEventEditorResult.deleted() : draft = null, deleted = true;

  final DayEventDraft? draft;
  final bool deleted;
}

Future<DayEventEditorResult?> showDayEventEditor({
  required BuildContext context,
  required DateTime initialDate,
  DayEvent? existing,
}) {
  final DateTime normalized = DateTime(
    initialDate.year,
    initialDate.month,
    initialDate.day,
  );
  final BuildContext modalContext = context.calendarModalContext;
  return showAdaptiveBottomSheet<DayEventEditorResult>(
    context: modalContext,
    isScrollControlled: true,
    useBottomSafeArea: context.calendarUseSheetBottomSafeArea,
    dialogMaxWidth: context.sizing.dialogMaxWidth,
    surfacePadding: EdgeInsets.zero,
    showCloseButton: false,
    builder: (BuildContext sheetContext) {
      return _DayEventEditorForm(initialDate: normalized, existing: existing);
    },
  );
}

class _DayEventEditorForm extends StatefulWidget {
  const _DayEventEditorForm({required this.initialDate, this.existing});

  final DateTime initialDate;
  final DayEvent? existing;

  @override
  State<_DayEventEditorForm> createState() => _DayEventEditorFormState();
}

class _DayEventEditorFormState extends State<_DayEventEditorForm> {
  final GlobalKey<ShadFormState> _formKey = GlobalKey<ShadFormState>();
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final FocusNode _titleFocusNode = FocusNode();
  late DateTime _startDate;
  late DateTime _endDate;
  late ReminderPreferences _reminders;
  CalendarIcsStatus? _status;
  CalendarTransparency? _transparency;
  List<String> _categories = _emptyCategories;
  String? _url;
  CalendarGeo? _geo;
  List<CalendarAttachment> _attachments = _emptyAttachments;
  List<CalendarAlarm> _advancedAlarms = _emptyAdvancedAlarms;
  CalendarOrganizer? _organizer;
  List<CalendarAttendee> _attendees = _emptyAttendees;

  @override
  void initState() {
    super.initState();
    _startDate = widget.existing?.normalizedStart ?? widget.initialDate;
    _endDate = widget.existing?.normalizedEnd ?? widget.initialDate;
    final ReminderPreferences fallbackReminders =
        widget.existing?.effectiveReminders ?? ReminderPreferences.defaults();
    final List<CalendarAlarm> existingAlarms = List<CalendarAlarm>.from(
      widget.existing?.icsMeta?.alarms ?? _emptyAdvancedAlarms,
    );
    final AlarmReminderSplit split = splitAlarmsWithFallback(
      alarms: existingAlarms,
      fallback: fallbackReminders,
    );
    _reminders = split.reminders;
    _advancedAlarms = split.advancedAlarms;
    _status = widget.existing?.icsMeta?.status;
    _transparency = widget.existing?.icsMeta?.transparency;
    _categories = List<String>.from(
      widget.existing?.icsMeta?.categories ?? _emptyCategories,
    );
    _url = widget.existing?.icsMeta?.url;
    _geo = widget.existing?.icsMeta?.geo;
    _attachments = List<CalendarAttachment>.from(
      widget.existing?.icsMeta?.attachments ?? _emptyAttachments,
    );
    _organizer = widget.existing?.icsMeta?.organizer;
    _attendees = List<CalendarAttendee>.from(
      widget.existing?.icsMeta?.attendees ?? _emptyAttendees,
    );
    _titleController = TextEditingController(text: widget.existing?.title);
    _descriptionController = TextEditingController(
      text: widget.existing?.description,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool isEditing = widget.existing != null;
    final colors = context.colorScheme;
    final CalendarIcsMeta? icsMeta = widget.existing?.icsMeta;
    final List<CalendarRawProperty> rawProperties =
        icsMeta?.rawProperties ?? _emptyRawProperties;
    final int? sequence = icsMeta?.sequence;
    final bool showInvitationStatus = hasInvitationStatusData(
      method: null,
      sequence: sequence,
      rawProperties: rawProperties,
    );
    final bool showDiagnostics = hasIcsDiagnosticsData(icsMeta);
    final Widget actions = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final bool canSubmit = value.text.trim().isNotEmpty;
        return AxiSheetActions(
          gap: context.spacing.s,
          children: [
            if (isEditing)
              TaskDestructiveButton(
                label: context.l10n.commonDelete,
                icon: Icons.delete_outline,
                onPressed: () => Navigator.of(
                  context,
                ).pop(const DayEventEditorResult.deleted()),
              ),
            TaskSecondaryButton(
              label: context.l10n.calendarExportFormatIcsTitle,
              icon: Icons.file_download_outlined,
              onPressed: canSubmit ? _exportIcs : null,
            ),
            TaskSecondaryButton(
              label: context.l10n.commonCancel,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            TaskPrimaryButton(
              label: isEditing ? l10n.commonSave : l10n.commonAdd,
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        );
      },
    );

    return SafeArea(
      top: false,
      bottom: false,
      child: ShadForm(
        key: _formKey,
        autovalidateMode: ShadAutovalidateMode.disabled,
        fieldIdSeparator: null,
        child: AxiSheetScaffold.sections(
          header: AxiSheetHeader(
            title: Text(
              isEditing
                  ? l10n.calendarEditDayEventTitle
                  : l10n.calendarNewDayEventTitle,
            ),
            onClose: () => Navigator.of(context).maybePop(),
          ),
          footer: actions,
          sections: [
            AxiSheetSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskTitleField(
                    controller: _titleController,
                    autofocus: false,
                    labelText: l10n.commonTitle,
                    hintText: context.l10n.calendarDayEventHint,
                    focusNode: _titleFocusNode,
                    onChanged: _handleTitleChanged,
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? context.l10n.calendarErrorTitleEmptyFriendly
                        : null,
                    autovalidateMode: AutovalidateMode.disabled,
                  ),
                  SizedBox(height: context.spacing.m),
                  TaskDescriptionField(
                    controller: _descriptionController,
                    hintText: context.l10n.calendarOptionalDetails,
                    minLines: 3,
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            AxiSheetSection(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TaskSectionHeader(title: context.l10n.calendarDates),
                  SizedBox(height: context.spacing.s),
                  ScheduleRangeFields(
                    start: _startDate,
                    end: _endDate,
                    showTimeSelectors: false,
                    onStartChanged: (DateTime? date) {
                      if (date == null) {
                        return;
                      }
                      setState(() {
                        _startDate = date;
                        if (_endDate.isBefore(date)) {
                          _endDate = date;
                        }
                      });
                    },
                    onEndChanged: (DateTime? date) {
                      if (date == null) {
                        return;
                      }
                      setState(() {
                        _endDate = date.isBefore(_startDate)
                            ? _startDate
                            : date;
                      });
                    },
                  ),
                ],
              ),
            ),
            AxiSheetSection(
              child: ReminderPreferencesField(
                value: _reminders,
                onChanged: (ReminderPreferences next) {
                  setState(() {
                    _reminders = next;
                  });
                },
                advancedAlarms: _advancedAlarms,
                onAdvancedAlarmsChanged: (value) =>
                    setState(() => _advancedAlarms = value),
                referenceStart: _startDate,
                title: l10n.calendarReminderLabel,
                anchor: ReminderAnchor.start,
              ),
            ),
            AxiSheetSection(
              child: CalendarCategoriesField(
                categories: _categories,
                onChanged: (value) => setState(() => _categories = value),
                surfaceColor: colors.background,
              ),
            ),
            AxiSheetSection(
              child: CalendarLinkGeoFields(
                url: _url,
                geo: _geo,
                onUrlChanged: (value) => setState(() => _url = value),
                onGeoChanged: (value) => setState(() => _geo = value),
              ),
            ),
            AxiSheetSection(
              child: CalendarParticipantsField(
                organizer: _organizer,
                attendees: _attendees,
                onOrganizerChanged: (value) =>
                    setState(() => _organizer = value),
                onAttendeesChanged: (value) =>
                    setState(() => _attendees = value),
              ),
            ),
            if (showInvitationStatus)
              AxiSheetSection(
                child: CalendarInvitationStatusField(
                  method: null,
                  sequence: sequence,
                  rawProperties: rawProperties,
                ),
              ),
            if (_attachments.isNotEmpty)
              AxiSheetSection(
                child: CalendarAttachmentsField(attachments: _attachments),
              ),
            if (showDiagnostics)
              AxiSheetSection(
                child: CalendarIcsDiagnosticsSection(icsMeta: icsMeta),
              ),
          ],
        ),
      ),
    );
  }

  void _handleTitleChanged(String value) {}

  DayEventDraft _currentDraft() {
    final String title = _titleController.text.trim();
    final DateTime normalizedStart = DateTime(
      _startDate.year,
      _startDate.month,
      _startDate.day,
    );
    final DateTime normalizedEnd = DateTime(
      _endDate.year,
      _endDate.month,
      _endDate.day,
    );
    final List<String>? categories = resolveCategoryOverride(
      base: widget.existing?.icsMeta,
      categories: _categories,
    );
    final CalendarOrganizer? organizer = resolveOrganizerOverride(
      base: widget.existing?.icsMeta,
      organizer: _organizer,
    );
    final List<CalendarAttendee>? attendees = resolveAttendeeOverride(
      base: widget.existing?.icsMeta,
      attendees: _attendees,
    );
    final List<CalendarAlarm> mergedAlarms = mergeAdvancedAlarms(
      advancedAlarms: _advancedAlarms,
      reminders: _reminders,
    );
    final List<CalendarAlarm>? alarms = resolveAlarmOverride(
      base: widget.existing?.icsMeta,
      alarms: mergedAlarms,
    );
    final CalendarIcsMeta? icsMeta = applyIcsMetaOverrides(
      base: widget.existing?.icsMeta,
      status: _status,
      transparency: _transparency,
      categories: categories,
      url: _url,
      geo: _geo,
      organizer: organizer,
      attendees: attendees,
      alarms: alarms,
    );
    return DayEventDraft(
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      startDate: normalizedStart,
      endDate: normalizedEnd,
      reminders: _reminders.normalized(),
      icsMeta: icsMeta,
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _titleFocusNode.requestFocus();
      return;
    }
    final DayEventDraft draft = _currentDraft();
    Navigator.of(context).pop(DayEventEditorResult.save(draft));
  }

  Future<void> _exportIcs() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _titleFocusNode.requestFocus();
      return;
    }
    final DayEventDraft draft = _currentDraft();
    final DayEvent event = widget.existing == null
        ? DayEvent.create(
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate,
            description: draft.description,
            reminders: draft.reminders,
            icsMeta: draft.icsMeta,
          )
        : widget.existing!.normalizedCopy(
            title: draft.title,
            startDate: draft.startDate,
            endDate: draft.endDate,
            description: draft.description,
            reminders: draft.reminders,
            icsMeta: draft.icsMeta,
            modifiedAt: DateTime.now(),
          );
    final l10n = context.l10n;
    final String trimmedTitle = draft.title.trim();
    final String subject = trimmedTitle.isEmpty
        ? l10n.calendarExportFormatIcsTitle
        : trimmedTitle;
    final String shareText = '$subject (${l10n.calendarExportFormatIcsTitle})';

    try {
      final file = await _transferService.exportDayEventIcs(event: event);
      if (!mounted) return;
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        context: context,
        file: file,
        subject: subject,
        text: shareText,
      );
      if (!mounted) return;
      FeedbackSystem.showSuccess(
        context,
        calendarShareSuccessMessage(
          outcome: shareOutcome,
          filePath: file.path,
          sharedText: l10n.calendarExportReady,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      FeedbackSystem.showError(context, l10n.calendarExportFailed('$error'));
    }
  }
}
