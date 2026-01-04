// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/controllers/task_checklist_controller.dart';
import 'package:axichat/src/calendar/view/widgets/task_checklist.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'widgets/calendar_categories_field.dart';
import 'widgets/calendar_attachments_field.dart';
import 'widgets/calendar_invitation_status_field.dart';
import 'widgets/calendar_ics_diagnostics_section.dart';
import 'widgets/calendar_link_geo_fields.dart';
import 'widgets/calendar_participants_field.dart';
import 'widgets/ics_meta_fields.dart';
import 'widgets/reminder_preferences_field.dart';
import 'error_display.dart';
import 'widgets/critical_path_panel.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_field_character_hint.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAttachment> _emptyAttachments = <CalendarAttachment>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];
const List<CalendarRawProperty> _emptyRawProperties = <CalendarRawProperty>[];

class UnifiedTaskInput<T extends BaseCalendarBloc> extends StatefulWidget {
  final CalendarTask? editingTask;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;

  const UnifiedTaskInput({
    super.key,
    this.editingTask,
    this.initialDate,
    this.initialTime,
  });

  @override
  State<UnifiedTaskInput<T>> createState() => _UnifiedTaskInputState<T>();
}

class _UnifiedTaskInputState<T extends BaseCalendarBloc>
    extends State<UnifiedTaskInput<T>> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TaskChecklistController _checklistController;
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

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Duration? _selectedDuration;
  bool _isSubmitting = false;
  bool _hasAttemptedSave = false;

  final _formKey = GlobalKey<FormState>();

  static const List<Duration> _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
  ];

  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(text: widget.editingTask?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.editingTask?.description ?? '');
    _checklistController = TaskChecklistController(
      initialItems: widget.editingTask?.checklist ?? const [],
    );
    _titleController.addListener(_handleTitleChanged);
    final ReminderPreferences fallbackReminders =
        widget.editingTask?.effectiveReminders ??
            ReminderPreferences.defaults();
    final List<CalendarAlarm> existingAlarms = List<CalendarAlarm>.from(
      widget.editingTask?.icsMeta?.alarms ?? _emptyAdvancedAlarms,
    );
    final AlarmReminderSplit split = splitAlarmsWithFallback(
      alarms: existingAlarms,
      fallback: fallbackReminders,
    );
    _reminders = split.reminders;
    _advancedAlarms = split.advancedAlarms;
    _status = widget.editingTask?.icsMeta?.status;
    _transparency = widget.editingTask?.icsMeta?.transparency;
    _categories = List<String>.from(
      widget.editingTask?.icsMeta?.categories ?? _emptyCategories,
    );
    _url = widget.editingTask?.icsMeta?.url;
    _geo = widget.editingTask?.icsMeta?.geo;
    _attachments = List<CalendarAttachment>.from(
      widget.editingTask?.icsMeta?.attachments ?? _emptyAttachments,
    );
    _organizer = widget.editingTask?.icsMeta?.organizer;
    _attendees = List<CalendarAttendee>.from(
      widget.editingTask?.icsMeta?.attendees ?? _emptyAttendees,
    );

    if (widget.editingTask != null) {
      _selectedDate = widget.editingTask!.scheduledTime != null
          ? DateTime(
              widget.editingTask!.scheduledTime!.year,
              widget.editingTask!.scheduledTime!.month,
              widget.editingTask!.scheduledTime!.day,
            )
          : null;
      _selectedTime = widget.editingTask!.scheduledTime != null
          ? TimeOfDay.fromDateTime(widget.editingTask!.scheduledTime!)
          : null;
      _selectedDuration = widget.editingTask!.duration;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = widget.initialTime ?? TimeOfDay.now();
      _selectedDuration = const Duration(hours: 1);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_handleTitleChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _checklistController.dispose();
    super.dispose();
  }

  void _handleTitleChanged() {
    setState(() {});
  }

  AutovalidateMode get _titleAutovalidateMode =>
      _hasAttemptedSave ? AutovalidateMode.always : AutovalidateMode.disabled;

  bool get _canSubmit =>
      TaskTitleValidation.validate(_titleController.text) == null;

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.editingTask != null;
    final l10n = context.l10n;
    final T bloc = context.read<T>();
    final CalendarMethod? method = bloc.state.model.collection?.method;
    final List<CalendarRawProperty> rawProperties =
        widget.editingTask?.icsMeta?.rawProperties ?? _emptyRawProperties;
    final int? sequence = widget.editingTask?.icsMeta?.sequence;
    final Widget form = _UnifiedTaskForm(
      formKey: _formKey,
      titleController: _titleController,
      titleAutovalidateMode: _titleAutovalidateMode,
      descriptionController: _descriptionController,
      selectedDate: _selectedDate,
      selectedTime: _selectedTime,
      selectedDuration: _selectedDuration,
      durationOptions: _durationOptions,
      onSelectDate: _selectDate,
      onSelectTime: _selectTime,
      onDurationChanged: (duration) {
        setState(() => _selectedDuration = duration);
      },
      formatDate: (date) => _formatDate(l10n, date),
      formatDuration: _formatDuration,
      checklistController: _checklistController,
      reminders: _reminders,
      onRemindersChanged: (value) {
        setState(() {
          _reminders = value;
        });
      },
      advancedAlarms: _advancedAlarms,
      onAdvancedAlarmsChanged: (value) {
        setState(() {
          _advancedAlarms = value;
        });
      },
      status: _status,
      transparency: _transparency,
      onStatusChanged: (value) => setState(() => _status = value),
      onTransparencyChanged: (value) => setState(() => _transparency = value),
      categories: _categories,
      onCategoriesChanged: (value) => setState(() => _categories = value),
      url: _url,
      geo: _geo,
      onUrlChanged: (value) => setState(() => _url = value),
      onGeoChanged: (value) => setState(() => _geo = value),
      attachments: _attachments,
      organizer: _organizer,
      attendees: _attendees,
      onOrganizerChanged: (value) => setState(() => _organizer = value),
      onAttendeesChanged: (value) => setState(() => _attendees = value),
      invitationMethod: method,
      invitationSequence: sequence,
      invitationRawProperties: rawProperties,
      icsMeta: widget.editingTask?.icsMeta,
    );
    final Widget saveButton = _UnifiedTaskSaveButton<T>(
      isSubmitting: _isSubmitting,
      canSubmit: _canSubmit,
      onSave: _saveTask,
    );
    final Widget dialogActions = _UnifiedTaskDialogActions<T>(
      editingTask: widget.editingTask,
      isSubmitting: _isSubmitting,
      canSubmit: _canSubmit,
      onSave: _saveTask,
      onSubmissionReset: () => setState(() => _isSubmitting = false),
      onClearError: () => context.read<T>().add(
            const CalendarEvent.errorCleared(),
          ),
    );
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _UnifiedTaskMobileLayout(
        isEditing: isEditing,
        saveButton: saveButton,
        form: form,
      ),
      tablet: _UnifiedTaskDialogLayout(
        width: 500,
        isEditing: isEditing,
        form: form,
        dialogActions: dialogActions,
      ),
      desktop: _UnifiedTaskDialogLayout(
        width: 600,
        isEditing: isEditing,
        form: form,
        dialogActions: dialogActions,
      ),
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (dialogContext, child) => InBoundsFadeScaleChild(child: child),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
      builder: (dialogContext, child) => InBoundsFadeScaleChild(child: child),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _activateTitleValidation() {
    if (_hasAttemptedSave) {
      return;
    }
    setState(() {
      _hasAttemptedSave = true;
    });
  }

  void _saveTask() {
    _activateTitleValidation();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;
    final List<TaskChecklistItem> checklist =
        List<TaskChecklistItem>.from(_checklistController.items);

    DateTime? scheduledTime;
    if (_selectedDate != null && _selectedTime != null) {
      scheduledTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    final List<String>? categories = resolveCategoryOverride(
      base: widget.editingTask?.icsMeta,
      categories: _categories,
    );
    final CalendarOrganizer? organizer = resolveOrganizerOverride(
      base: widget.editingTask?.icsMeta,
      organizer: _organizer,
    );
    final List<CalendarAttendee>? attendees = resolveAttendeeOverride(
      base: widget.editingTask?.icsMeta,
      attendees: _attendees,
    );
    final List<CalendarAlarm> mergedAlarms = mergeAdvancedAlarms(
      advancedAlarms: _advancedAlarms,
      reminders: _reminders,
    );
    final List<CalendarAlarm>? alarms = resolveAlarmOverride(
      base: widget.editingTask?.icsMeta,
      alarms: mergedAlarms,
    );
    final CalendarIcsMeta? icsMeta = applyIcsMetaOverrides(
      base: widget.editingTask?.icsMeta,
      status: _status,
      transparency: _transparency,
      categories: categories,
      url: _url,
      geo: _geo,
      organizer: organizer,
      attendees: attendees,
      alarms: alarms,
    );

    // Clear any previous errors
    context.read<T>().add(const CalendarEvent.errorCleared());

    if (widget.editingTask != null) {
      final updatedTask = widget.editingTask!.copyWith(
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        duration: _selectedDuration,
        modifiedAt: DateTime.now(),
        checklist: checklist,
        reminders: _reminders.normalized(),
        icsMeta: icsMeta,
      );

      context.read<T>().add(
            CalendarEvent.taskUpdated(task: updatedTask),
          );
    } else {
      context.read<T>().add(
            CalendarEvent.taskAdded(
              title: title,
              description: description,
              scheduledTime: scheduledTime,
              duration: _selectedDuration,
              checklist: checklist,
              reminders: _reminders.normalized(),
              icsMeta: icsMeta,
            ),
          );
    }
  }

  String _formatDate(AppLocalizations l10n, DateTime? date) {
    if (date == null) return l10n.calendarSelectDate;
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    return TimeFormatter.formatDuration(duration);
  }
}

class _UnifiedTaskMobileLayout extends StatelessWidget {
  const _UnifiedTaskMobileLayout({
    required this.isEditing,
    required this.saveButton,
    required this.form,
  });

  final bool isEditing;
  final Widget saveButton;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colorScheme.background,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: AxiIconButton.kDefaultSize,
                    height: AxiIconButton.kDefaultSize,
                    child: AxiIconButton.ghost(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: l10n.commonBack,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(
          isEditing ? l10n.calendarEditTaskTitle : l10n.calendarAddTaskTitle,
        ),
        actions: [saveButton],
      ),
      body: form,
    );
  }
}

class _UnifiedTaskDialogLayout extends StatelessWidget {
  const _UnifiedTaskDialogLayout({
    required this.width,
    required this.isEditing,
    required this.form,
    required this.dialogActions,
  });

  final double width;
  final bool isEditing;
  final Widget form;
  final Widget dialogActions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnifiedTaskDialogHeader(isEditing: isEditing),
            Flexible(child: form),
            dialogActions,
          ],
        ),
      ),
    );
  }
}

class _UnifiedTaskDialogHeader extends StatelessWidget {
  const _UnifiedTaskDialogHeader({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    return Container(
      padding: calendarPaddingXl,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEditing
                  ? l10n.calendarEditTaskTitle
                  : l10n.calendarAddTaskTitle,
              style: calendarTitleTextStyle.copyWith(fontSize: 18),
            ),
          ),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).maybePop(),
            backgroundColor: colors.card,
            borderColor: colors.border,
          ),
        ],
      ),
    );
  }
}

class _UnifiedTaskForm extends StatelessWidget {
  const _UnifiedTaskForm({
    required this.formKey,
    required this.titleController,
    required this.titleAutovalidateMode,
    required this.descriptionController,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.durationOptions,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onDurationChanged,
    required this.formatDate,
    required this.formatDuration,
    required this.checklistController,
    required this.reminders,
    required this.onRemindersChanged,
    required this.advancedAlarms,
    required this.onAdvancedAlarmsChanged,
    required this.status,
    required this.transparency,
    required this.onStatusChanged,
    required this.onTransparencyChanged,
    required this.categories,
    required this.onCategoriesChanged,
    required this.url,
    required this.geo,
    required this.onUrlChanged,
    required this.onGeoChanged,
    required this.attachments,
    required this.organizer,
    required this.attendees,
    required this.onOrganizerChanged,
    required this.onAttendeesChanged,
    required this.invitationMethod,
    required this.invitationSequence,
    required this.invitationRawProperties,
    required this.icsMeta,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final AutovalidateMode titleAutovalidateMode;
  final TextEditingController descriptionController;
  final TaskChecklistController checklistController;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final Duration? selectedDuration;
  final List<Duration> durationOptions;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final ValueChanged<Duration?> onDurationChanged;
  final String Function(DateTime?) formatDate;
  final String Function(Duration) formatDuration;
  final ReminderPreferences reminders;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final List<CalendarAlarm> advancedAlarms;
  final ValueChanged<List<CalendarAlarm>> onAdvancedAlarmsChanged;
  final CalendarIcsStatus? status;
  final CalendarTransparency? transparency;
  final ValueChanged<CalendarIcsStatus?> onStatusChanged;
  final ValueChanged<CalendarTransparency?> onTransparencyChanged;
  final List<String> categories;
  final ValueChanged<List<String>> onCategoriesChanged;
  final String? url;
  final CalendarGeo? geo;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<CalendarGeo?> onGeoChanged;
  final List<CalendarAttachment> attachments;
  final CalendarOrganizer? organizer;
  final List<CalendarAttendee> attendees;
  final ValueChanged<CalendarOrganizer?> onOrganizerChanged;
  final ValueChanged<List<CalendarAttendee>> onAttendeesChanged;
  final CalendarMethod? invitationMethod;
  final int? invitationSequence;
  final List<CalendarRawProperty> invitationRawProperties;
  final CalendarIcsMeta? icsMeta;

  @override
  Widget build(BuildContext context) {
    final bool showInvitationStatus = hasInvitationStatusData(
      method: invitationMethod,
      sequence: invitationSequence,
      rawProperties: invitationRawProperties,
    );
    final bool showDiagnostics = hasIcsDiagnosticsData(icsMeta);
    return SingleChildScrollView(
      padding: calendarPaddingXl,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UnifiedTaskTitleField(
              controller: titleController,
              autovalidateMode: titleAutovalidateMode,
            ),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDescriptionField(
              controller: descriptionController,
            ),
            const SizedBox(height: calendarGutterLg),
            TaskChecklist(controller: checklistController),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDateTimeSection(
              selectedDate: selectedDate,
              selectedTime: selectedTime,
              onSelectDate: onSelectDate,
              onSelectTime: onSelectTime,
              formatDate: formatDate,
            ),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDurationField(
              selectedDuration: selectedDuration,
              durationOptions: durationOptions,
              onDurationChanged: onDurationChanged,
              formatDuration: formatDuration,
            ),
            const SizedBox(height: calendarGutterLg),
            ReminderPreferencesField(
              value: reminders,
              onChanged: onRemindersChanged,
              advancedAlarms: advancedAlarms,
              onAdvancedAlarmsChanged: onAdvancedAlarmsChanged,
              referenceStart: selectedDate != null && selectedTime != null
                  ? DateTime(
                      selectedDate!.year,
                      selectedDate!.month,
                      selectedDate!.day,
                      selectedTime!.hour,
                      selectedTime!.minute,
                    )
                  : null,
            ),
            const SizedBox(height: calendarGutterLg),
            CalendarIcsMetaFields(
              status: status,
              transparency: transparency,
              showStatus: false,
              onStatusChanged: onStatusChanged,
              onTransparencyChanged: onTransparencyChanged,
            ),
            const SizedBox(height: calendarGutterLg),
            CalendarCategoriesField(
              categories: categories,
              onChanged: onCategoriesChanged,
            ),
            const SizedBox(height: calendarGutterLg),
            CalendarLinkGeoFields(
              url: url,
              geo: geo,
              onUrlChanged: onUrlChanged,
              onGeoChanged: onGeoChanged,
            ),
            const SizedBox(height: calendarGutterLg),
            CalendarParticipantsField(
              organizer: organizer,
              attendees: attendees,
              onOrganizerChanged: onOrganizerChanged,
              onAttendeesChanged: onAttendeesChanged,
            ),
            if (showInvitationStatus) ...[
              const SizedBox(height: calendarGutterLg),
              CalendarInvitationStatusField(
                method: invitationMethod,
                sequence: invitationSequence,
                rawProperties: invitationRawProperties,
              ),
            ],
            if (attachments.isNotEmpty) ...[
              const SizedBox(height: calendarGutterLg),
              CalendarAttachmentsField(
                attachments: attachments,
              ),
            ],
            if (showDiagnostics) ...[
              const SizedBox(height: calendarGutterLg),
              CalendarIcsDiagnosticsSection(icsMeta: icsMeta),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnifiedTaskTitleField extends StatelessWidget {
  const _UnifiedTaskTitleField({
    required this.controller,
    required this.autovalidateMode,
  });

  final TextEditingController controller;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTitleField(
          controller: controller,
          hintText: l10n.calendarTaskNameHint,
          validator: (value) => TaskTitleValidation.validate(value ?? ''),
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.next,
        ),
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _UnifiedTaskDescriptionField extends StatelessWidget {
  const _UnifiedTaskDescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TaskDescriptionField(
      controller: controller,
      hintText: l10n.calendarDescriptionHint,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      contentPadding: calendarFieldPadding,
      minLines: 3,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _UnifiedTaskDateTimeSection extends StatelessWidget {
  const _UnifiedTaskDateTimeSection({
    required this.selectedDate,
    required this.selectedTime,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.formatDate,
  });

  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.calendarDateTimeLabel,
          style: textTheme.muted,
        ),
        const SizedBox(height: calendarGutterSm),
        TaskDateTimeToolbar(
          primaryField: TaskDateTimeToolbarField(
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            onSelectDate: onSelectDate,
            onSelectTime: onSelectTime,
            emptyDateLabel: context.l10n.calendarSelectDate,
            emptyTimeLabel: context.l10n.calendarSelectTime,
            dateLabelBuilder: (context, date) => formatDate(date),
            timeLabelBuilder: (context, time) =>
                TimeFormatter.formatTimeOfDay(context, time),
          ),
        ),
      ],
    );
  }
}

class _UnifiedTaskDurationField extends StatelessWidget {
  const _UnifiedTaskDurationField({
    required this.selectedDuration,
    required this.durationOptions,
    required this.onDurationChanged,
    required this.formatDuration,
  });

  final Duration? selectedDuration;
  final List<Duration> durationOptions;
  final ValueChanged<Duration?> onDurationChanged;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.calendarDurationLabel,
          style: textTheme.muted,
        ),
        const SizedBox(height: calendarGutterSm),
        AxiSelect<Duration>(
          placeholder: Text(context.l10n.calendarSelectDuration),
          options: durationOptions
              .map(
                (duration) => ShadOption(
                  value: duration,
                  child: Text(formatDuration(duration)),
                ),
              )
              .toList(),
          selectedOptionBuilder: (context, value) =>
              Text(formatDuration(value)),
          onChanged: onDurationChanged,
        ),
      ],
    );
  }
}

class _UnifiedTaskSaveButton<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _UnifiedTaskSaveButton({
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSave,
  });

  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<T, CalendarState>(
      builder: (context, state) {
        final bool disabled = state.isLoading || isSubmitting || !canSubmit;
        final bool busy = state.isLoading || isSubmitting;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarGutterSm),
          child: TaskPrimaryButton(
            label: context.l10n.commonSave,
            onPressed: disabled ? null : onSave,
            isBusy: busy,
          ),
        );
      },
    );
  }
}

class _UnifiedTaskDialogActions<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _UnifiedTaskDialogActions({
    required this.editingTask,
    required this.isSubmitting,
    required this.canSubmit,
    required this.onSave,
    required this.onSubmissionReset,
    required this.onClearError,
  });

  final CalendarTask? editingTask;
  final bool isSubmitting;
  final bool canSubmit;
  final VoidCallback onSave;
  final VoidCallback onSubmissionReset;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return BlocConsumer<T, CalendarState>(
      listener: (context, state) {
        if (state.error != null && isSubmitting) {
          onSubmissionReset();
        } else if (!state.isLoading && isSubmitting) {
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        CalendarTask? resolvedTask = editingTask;
        if (editingTask != null) {
          resolvedTask = state.model.tasks[editingTask!.id] ?? editingTask;
        }
        final bool canAddToCriticalPath =
            resolvedTask != null && !(state.isLoading || isSubmitting);
        final CalendarTask? activeTask = resolvedTask;
        final membershipPaths = resolvedTask != null
            ? state.criticalPathsForTask(resolvedTask)
            : const <CalendarCriticalPath>[];
        return Container(
          padding: calendarPaddingXl,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: colors.border),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null && isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: calendarGutterLg),
                  child: ErrorDisplay(
                    error: state.error!,
                    onRetry: onSave,
                    onDismiss: onClearError,
                  ),
                ),
              TaskFormActionsRow(
                padding: EdgeInsets.zero,
                gap: calendarGutterMd,
                children: [
                  TaskSecondaryButton(
                    label: context.l10n.calendarAddToCriticalPath,
                    icon: Icons.route,
                    onPressed: canAddToCriticalPath
                        ? () => addTaskToCriticalPath(
                              context: context,
                              bloc: context.read<T>(),
                              task: resolvedTask!,
                            )
                        : null,
                  ),
                  const Spacer(),
                  TaskSecondaryButton(
                    label: context.l10n.commonCancel,
                    onPressed: (state.isLoading || isSubmitting)
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                  TaskPrimaryButton(
                    label: context.l10n.commonSave,
                    onPressed: (state.isLoading || isSubmitting || !canSubmit)
                        ? null
                        : onSave,
                    isBusy: state.isLoading || isSubmitting,
                  ),
                ],
              ),
              const SizedBox(height: calendarInsetSm),
              CriticalPathMembershipList(
                paths: membershipPaths,
                onRemovePath: activeTask == null
                    ? null
                    : (pathId) => context.read<T>().add(
                          CalendarEvent.criticalPathTaskRemoved(
                            pathId: pathId,
                            taskId: activeTask.id,
                          ),
                        ),
                emptyLabel: context.l10n.calendarNoCriticalPathMembership,
              ),
            ],
          ),
        );
      },
    );
  }
}

// Generic helper function to show the unified task input
void showUnifiedTaskInput<T extends BaseCalendarBloc>(
  BuildContext context, {
  CalendarTask? editingTask,
  DateTime? initialDate,
  TimeOfDay? initialTime,
}) {
  final locate = context.read;
  Widget buildTaskInput() => BlocProvider.value(
        value: locate<T>(),
        child: UnifiedTaskInput<T>(
          editingTask: editingTask,
          initialDate: initialDate,
          initialTime: initialTime,
        ),
      );

  if (ResponsiveHelper.isCompact(context)) {
    final Duration animationDuration =
        context.read<SettingsCubit>().animationDuration;
    Navigator.of(context).push(
      AxiFadePageRoute<void>(
        duration: animationDuration,
        builder: (context) => buildTaskInput(),
      ),
    );
  } else {
    showFadeScaleDialog<void>(
      context: context,
      builder: (context) => buildTaskInput(),
    );
  }
}
