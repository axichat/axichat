import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_attachments_field.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_categories_field.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_link_geo_fields.dart';
import 'package:axichat/src/calendar/view/widgets/ics_meta_fields.dart';
import 'package:axichat/src/calendar/view/widgets/reminder_preferences_field.dart';
import 'package:axichat/src/calendar/view/widgets/schedule_range_fields.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAttachment> _emptyAttachments = <CalendarAttachment>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];

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

  const DayEventEditorResult.deleted()
      : draft = null,
        deleted = true;

  final DayEventDraft? draft;
  final bool deleted;
}

Future<DayEventEditorResult?> showDayEventEditor({
  required BuildContext context,
  required DateTime initialDate,
  DayEvent? existing,
}) {
  final DateTime normalized =
      DateTime(initialDate.year, initialDate.month, initialDate.day);
  return showAdaptiveBottomSheet<DayEventEditorResult>(
    context: context,
    isScrollControlled: true,
    dialogMaxWidth: 720,
    surfacePadding: const EdgeInsets.symmetric(
      horizontal: calendarGutterSm,
      vertical: calendarInsetSm,
    ),
    showCloseButton: false,
    builder: (BuildContext sheetContext) {
      return _DayEventEditorForm(
        initialDate: normalized,
        existing: existing,
      );
    },
  );
}

class _DayEventEditorForm extends StatefulWidget {
  const _DayEventEditorForm({
    required this.initialDate,
    this.existing,
  });

  final DateTime initialDate;
  final DayEvent? existing;

  @override
  State<_DayEventEditorForm> createState() => _DayEventEditorFormState();
}

class _DayEventEditorFormState extends State<_DayEventEditorForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
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
    _titleController = TextEditingController(text: widget.existing?.title);
    _descriptionController =
        TextEditingController(text: widget.existing?.description);
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
    final bool isEditing = widget.existing != null;
    final colors = context.colorScheme;
    final TextStyle titleStyle = calendarTitleTextStyle.copyWith(fontSize: 18);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final bool keyboardOpen = keyboardInset > safeBottom;
    final double scrollBottomPadding = calendarGutterMd + keyboardInset;
    final Widget actions = ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final bool canSubmit = value.text.trim().isNotEmpty;
        return TaskFormActionsRow(
          includeTopBorder: true,
          gap: calendarGutterSm,
          padding: const EdgeInsets.fromLTRB(
            calendarGutterLg,
            calendarGutterMd,
            calendarGutterLg,
            calendarGutterMd,
          ),
          children: [
            const Spacer(),
            if (isEditing)
              TaskDestructiveButton(
                label: context.l10n.commonDelete,
                icon: Icons.delete_outline,
                onPressed: () => Navigator.of(context).pop(
                  const DayEventEditorResult.deleted(),
                ),
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
              label: isEditing ? 'Save' : 'Add',
              onPressed: canSubmit ? _submit : null,
            ),
          ],
        );
      },
    );

    return SafeArea(
      top: true,
      bottom: false,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterMd,
                vertical: calendarInsetSm,
              ),
              child: Row(
                children: [
                  Text(
                    isEditing ? 'Edit day event' : 'New day event',
                    style: titleStyle,
                  ),
                  const Spacer(),
                  AxiIconButton(
                    iconData: Icons.close,
                    iconSize: 16,
                    buttonSize: 34,
                    tapTargetSize: 40,
                    color: colors.mutedForeground,
                    backgroundColor: Colors.transparent,
                    borderColor: Colors.transparent,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  calendarGutterMd,
                  calendarInsetLg,
                  calendarGutterMd,
                  scrollBottomPadding,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TaskTitleField(
                      controller: _titleController,
                      autofocus: true,
                      labelText: 'Title',
                      hintText: context.l10n.calendarDayEventHint,
                      focusNode: _titleFocusNode,
                      onChanged: _handleTitleChanged,
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? context.l10n.calendarErrorTitleEmptyFriendly
                          : null,
                      autovalidateMode: AutovalidateMode.disabled,
                    ),
                    const SizedBox(height: calendarGutterMd),
                    TaskDescriptionField(
                      controller: _descriptionController,
                      hintText: context.l10n.calendarOptionalDetails,
                      borderRadius: calendarBorderRadius,
                      focusBorderColor: calendarPrimaryColor,
                      contentPadding: calendarFieldPadding,
                      minLines: 3,
                      maxLines: 3,
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    TaskSectionHeader(
                      title: context.l10n.calendarDates,
                    ),
                    const SizedBox(height: calendarInsetLg),
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
                          _endDate =
                              date.isBefore(_startDate) ? _startDate : date;
                        });
                      },
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    ReminderPreferencesField(
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
                      title: 'Reminder',
                      anchor: ReminderAnchor.start,
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarIcsMetaFields(
                      status: _status,
                      transparency: _transparency,
                      onStatusChanged: (value) =>
                          setState(() => _status = value),
                      onTransparencyChanged: (value) =>
                          setState(() => _transparency = value),
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarCategoriesField(
                      categories: _categories,
                      onChanged: (value) => setState(() => _categories = value),
                    ),
                    TaskSectionDivider(
                      color: colors.border,
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarLinkGeoFields(
                      url: _url,
                      geo: _geo,
                      onUrlChanged: (value) => setState(() => _url = value),
                      onGeoChanged: (value) => setState(() => _geo = value),
                    ),
                    if (_attachments.isNotEmpty) ...[
                      TaskSectionDivider(
                        color: colors.border,
                        verticalPadding: calendarGutterMd,
                      ),
                      CalendarAttachmentsField(
                        attachments: _attachments,
                      ),
                    ],
                    if (keyboardOpen) ...[
                      const SizedBox(height: calendarGutterMd),
                      actions,
                    ],
                  ],
                ),
              ),
            ),
            if (!keyboardOpen)
              SafeArea(
                top: false,
                bottom: true,
                child: actions,
              ),
          ],
        ),
      ),
    );
  }

  void _handleTitleChanged(String value) {}

  DayEventDraft _currentDraft() {
    final String title = _titleController.text.trim();
    final DateTime normalizedStart =
        DateTime(_startDate.year, _startDate.month, _startDate.day);
    final DateTime normalizedEnd =
        DateTime(_endDate.year, _endDate.month, _endDate.day);
    final List<String>? categories = resolveCategoryOverride(
      base: widget.existing?.icsMeta,
      categories: _categories,
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
    final String subject =
        trimmedTitle.isEmpty ? l10n.calendarExportFormatIcsTitle : trimmedTitle;
    final String shareText = '$subject (${l10n.calendarExportFormatIcsTitle})';

    try {
      final file = await _transferService.exportDayEventIcs(event: event);
      if (!mounted) return;
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
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
      FeedbackSystem.showError(
        context,
        l10n.calendarExportFailed('$error'),
      );
    }
  }
}
