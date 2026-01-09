// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:animations/animations.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/schedule_range_utils.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'models/task_context_action.dart';
import 'controllers/task_checklist_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/critical_path_panel.dart';
import 'widgets/calendar_invitation_status_field.dart';
import 'widgets/calendar_ics_diagnostics_section.dart';
import 'widgets/calendar_categories_field.dart';
import 'widgets/calendar_attachments_field.dart';
import 'widgets/calendar_link_geo_fields.dart';
import 'widgets/calendar_participants_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_field_character_hint.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_checklist.dart';
import 'widgets/reminder_preferences_field.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAttachment> _emptyAttachments = <CalendarAttachment>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];
const List<CalendarRawProperty> _emptyRawProperties = <CalendarRawProperty>[];
const List<TaskChecklistItem> _emptyChecklistItems = <TaskChecklistItem>[];
const List<TaskContextAction> _emptyInlineActions = <TaskContextAction>[];
const double _taskPopoverMinWidth = 320.0;
const Alignment _taskPopoverTransformAlignment = Alignment.centerLeft;
const int _initialPopoverRevision = 0;
const int _popoverRevisionStep = 1;
const String _occurrenceScopeTitle = 'Apply changes to';
const String _occurrenceScopeInstanceLabel = 'This instance';
const String _occurrenceScopeFutureLabel = 'This and future';
const String _occurrenceScopeHint = 'Schedule edits affect the selected range.';

enum TaskEditMode {
  full,
  checklistOnly,
  readOnly;

  bool get allowsAnyEdits => this != TaskEditMode.readOnly;

  bool get allowsChecklistEdits =>
      this == TaskEditMode.full || this == TaskEditMode.checklistOnly;

  bool get allowsFullEdits => this == TaskEditMode.full;

  bool get isReadOnly => this == TaskEditMode.readOnly;

  bool get isChecklistOnly => this == TaskEditMode.checklistOnly;
}

const TaskEditMode _defaultTaskEditMode = TaskEditMode.full;

enum OccurrenceUpdateScope {
  thisInstance,
  thisAndFuture;

  bool get isThisInstance => this == OccurrenceUpdateScope.thisInstance;

  bool get isThisAndFuture => this == OccurrenceUpdateScope.thisAndFuture;

  RecurrenceRange? get range =>
      isThisAndFuture ? RecurrenceRange.thisAndFuture : null;

  String get label => switch (this) {
        OccurrenceUpdateScope.thisInstance => _occurrenceScopeInstanceLabel,
        OccurrenceUpdateScope.thisAndFuture => _occurrenceScopeFutureLabel,
      };
}

enum _TaskEditField {
  title,
  description,
  location,
  priority,
  completion,
  schedule,
  deadline,
  recurrence,
  reminders,
  advancedAlarms,
  categories,
  url,
  geo,
  organizer,
  attendees,
  checklist,
}

class EditTaskDropdown<B extends BaseCalendarBloc> extends StatefulWidget {
  const EditTaskDropdown({
    super.key,
    required this.task,
    required this.onClose,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.maxHeight = 520,
    this.onOccurrenceUpdated,
    this.scaffoldMessenger,
    this.isSheet = false,
    this.inlineActions = _emptyInlineActions,
    this.collectionMethod,
    this.editMode = _defaultTaskEditMode,
    required this.locationHelper,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;
  final void Function(
    CalendarTask task,
    OccurrenceUpdateScope scope, {
    required bool scheduleTouched,
    required bool checklistTouched,
  })? onOccurrenceUpdated;
  final ScaffoldMessengerState? scaffoldMessenger;
  final bool isSheet;
  final List<TaskContextAction> inlineActions;
  final CalendarMethod? collectionMethod;
  final TaskEditMode editMode;
  final LocationAutocompleteHelper locationHelper;

  @override
  State<EditTaskDropdown<B>> createState() => _EditTaskDropdownState<B>();
}

class _EditTaskDropdownState<B extends BaseCalendarBloc>
    extends State<EditTaskDropdown<B>> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TaskChecklistController _checklistController;
  final FocusNode _titleFocusNode = FocusNode();
  final ValueNotifier<int> _popoverBodyRevision =
      ValueNotifier<int>(_initialPopoverRevision);
  bool _suppressFieldTracking = false;
  bool _suppressChecklistPersist = false;
  final Set<_TaskEditField> _touchedFields = <_TaskEditField>{};
  List<TaskChecklistItem> _lastChecklistSnapshot = _emptyChecklistItems;

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isCompleted = false;
  OccurrenceUpdateScope _occurrenceScope = OccurrenceUpdateScope.thisInstance;

  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;

  RecurrenceFormValue _recurrence = const RecurrenceFormValue();
  ReminderPreferences _reminders = ReminderPreferences.defaults();
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
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _checklistController = TaskChecklistController()
      ..addListener(_refresh)
      ..addListener(_handleChecklistChanged);
    _hydrateFromTask(widget.task, rebuild: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _checklistController
      ..removeListener(_refresh)
      ..removeListener(_handleChecklistChanged)
      ..dispose();
    _titleFocusNode.dispose();
    _popoverBodyRevision.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _bumpPopoverRevision() {
    _popoverBodyRevision.value += _popoverRevisionStep;
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _bumpPopoverRevision();
  }

  @override
  void didUpdateWidget(covariant EditTaskDropdown<B> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id) {
      _hydrateFromTask(widget.task, rebuild: true);
    }
  }

  void _hydrateFromTask(
    CalendarTask task, {
    required bool rebuild,
  }) {
    void apply() {
      if (_titleController.text != task.title) {
        _titleController.value = TextEditingValue(
          text: task.title,
          selection: TextSelection.collapsed(offset: task.title.length),
        );
      }

      final String descriptionText = task.description ?? '';
      if (_descriptionController.text != descriptionText) {
        _descriptionController.value = TextEditingValue(
          text: descriptionText,
          selection: TextSelection.collapsed(offset: descriptionText.length),
        );
      }

      final String locationText = task.location ?? '';
      if (_locationController.text != locationText) {
        _locationController.value = TextEditingValue(
          text: locationText,
          selection: TextSelection.collapsed(offset: locationText.length),
        );
      }

      _checklistController.setItems(task.checklist);
      _setChecklistSnapshot(_checklistController.items);

      _isImportant = task.isImportant || task.isCritical;
      _isUrgent = task.isUrgent || task.isCritical;
      _isCompleted = task.isCompleted;
      _occurrenceScope = OccurrenceUpdateScope.thisInstance;
      _startTime = task.scheduledTime;
      final Duration fallbackDuration =
          task.duration ?? calendarDefaultTaskDuration;
      _endTime =
          task.effectiveEndDate ?? task.scheduledTime?.add(fallbackDuration);
      _deadline = task.deadline;
      _recurrence = RecurrenceFormValue.fromRule(task.recurrence)
          .resolveLinkedLimits(_startTime ?? task.scheduledTime);
      final ReminderPreferences fallbackReminders = task.effectiveReminders;
      final List<CalendarAlarm> existingAlarms = List<CalendarAlarm>.from(
        task.icsMeta?.alarms ?? _emptyAdvancedAlarms,
      );
      final AlarmReminderSplit split = splitAlarmsWithFallback(
        alarms: existingAlarms,
        fallback: fallbackReminders,
      );
      _reminders = split.reminders;
      _advancedAlarms = split.advancedAlarms;
      _categories =
          List<String>.from(task.icsMeta?.categories ?? _emptyCategories);
      _url = task.icsMeta?.url;
      _geo = task.icsMeta?.geo;
      _attachments = List<CalendarAttachment>.from(
        task.icsMeta?.attachments ?? _emptyAttachments,
      );
      _organizer = task.icsMeta?.organizer;
      _attendees = List<CalendarAttendee>.from(
        task.icsMeta?.attendees ?? _emptyAttendees,
      );
    }

    _touchedFields.clear();
    _suppressFieldTracking = true;
    _suppressChecklistPersist = true;
    if (rebuild && mounted) {
      setState(apply);
    } else {
      apply();
    }
    _suppressFieldTracking = false;
    _suppressChecklistPersist = false;
  }

  void _handleChecklistChanged() {
    if (_suppressChecklistPersist || !widget.editMode.allowsChecklistEdits) {
      return;
    }
    _markTouched(_TaskEditField.checklist);
    final List<TaskChecklistItem> current =
        List<TaskChecklistItem>.from(_checklistController.items);
    final bool shouldPersist = widget.editMode.isChecklistOnly
        ? !listEquals(_lastChecklistSnapshot, current)
        : _isChecklistCompletionChange(
            previous: _lastChecklistSnapshot,
            current: current,
          );
    _setChecklistSnapshot(current);
    if (!shouldPersist) {
      return;
    }
    _persistChecklistUpdate(current);
  }

  bool _isChecklistCompletionChange({
    required List<TaskChecklistItem> previous,
    required List<TaskChecklistItem> current,
  }) {
    if (previous.length != current.length) {
      return false;
    }
    bool completionChanged = false;
    for (final MapEntry<int, TaskChecklistItem> entry
        in current.asMap().entries) {
      final TaskChecklistItem before = previous[entry.key];
      final TaskChecklistItem after = entry.value;
      if (before.id != after.id || before.label != after.label) {
        return false;
      }
      if (before.isCompleted != after.isCompleted) {
        completionChanged = true;
      }
    }
    return completionChanged;
  }

  void _persistChecklistUpdate(List<TaskChecklistItem> checklist) {
    final CalendarTask baseTask = _resolveLatestTaskSnapshot();
    final CalendarTask updatedTask = baseTask.copyWith(
      checklist: checklist,
    );
    if (widget.task.isOccurrence && widget.onOccurrenceUpdated != null) {
      widget.onOccurrenceUpdated!(
        updatedTask,
        _occurrenceScope,
        scheduleTouched: false,
        checklistTouched: true,
      );
      final CalendarTask? seriesTask = _resolveLatestSeriesSnapshot();
      if (seriesTask != null) {
        final CalendarTask seriesUpdate =
            seriesTask.copyWith(checklist: checklist);
        if (seriesUpdate != seriesTask) {
          widget.onTaskUpdated(seriesUpdate);
        }
      }
      return;
    }
    widget.onTaskUpdated(updatedTask);
  }

  void _setChecklistSnapshot(Iterable<TaskChecklistItem> items) {
    _lastChecklistSnapshot =
        List<TaskChecklistItem>.from(items, growable: false);
  }

  void _markTouched(_TaskEditField field) {
    if (_suppressFieldTracking) {
      return;
    }
    _touchedFields.add(field);
  }

  bool _isTouched(_TaskEditField field) => _touchedFields.contains(field);

  CalendarTask _resolveLatestTaskSnapshot() {
    final Map<String, CalendarTask> tasks = context.read<B>().state.model.tasks;
    final CalendarTask? directTask = tasks[widget.task.id];
    if (directTask != null) {
      return directTask;
    }
    final String baseId = baseTaskIdFrom(widget.task.id);
    final CalendarTask? baseTask = tasks[baseId];
    if (baseTask == null) {
      return widget.task;
    }
    if (!widget.task.isOccurrence) {
      return baseTask;
    }
    final CalendarTask? occurrenceTask =
        baseTask.occurrenceForId(widget.task.id);
    return occurrenceTask ?? baseTask;
  }

  CalendarTask? _resolveLatestSeriesSnapshot() {
    final String baseId = baseTaskIdFrom(widget.task.id);
    return context.read<B>().state.model.tasks[baseId];
  }

  AlarmReminderSplit _splitTaskAlarms(CalendarTask task) {
    final ReminderPreferences fallbackReminders = task.effectiveReminders;
    final List<CalendarAlarm> existingAlarms = List<CalendarAlarm>.from(
      task.icsMeta?.alarms ?? _emptyAdvancedAlarms,
    );
    return splitAlarmsWithFallback(
      alarms: existingAlarms,
      fallback: fallbackReminders,
    );
  }

  void _updateDraft(VoidCallback update) {
    if (!mounted) {
      update();
      return;
    }
    setState(update);
  }

  @override
  Widget build(BuildContext context) {
    final bool isSheet = widget.isSheet;
    final TaskEditMode editMode = widget.editMode;
    final bool allowsAnyEdits = editMode.allowsAnyEdits;
    final bool allowsChecklistEdits = editMode.allowsChecklistEdits;
    final bool allowsFullEdits = editMode.allowsFullEdits;
    final Widget popoverHeader = _EditTaskHeader(onClose: widget.onClose);
    final BorderRadius radius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(8);
    final Color background = isSheet
        ? Theme.of(context).colorScheme.surface
        : calendarContainerColor;
    const double dropdownShadowAlpha = 0.12;
    const double dropdownShadowBlurRadius = 24;
    const Offset dropdownShadowOffset = Offset(0, 8);
    final Color dropdownShadowColor =
        Theme.of(context).shadowColor.withValues(alpha: dropdownShadowAlpha);
    final List<BoxShadow>? boxShadow = isSheet
        ? null
        : [
            BoxShadow(
              color: dropdownShadowColor,
              blurRadius: dropdownShadowBlurRadius,
              offset: dropdownShadowOffset,
            ),
          ];
    final CalendarMethod? method = widget.collectionMethod;
    final CalendarIcsMeta? icsMeta = widget.task.icsMeta;
    final List<CalendarRawProperty> rawProperties =
        icsMeta?.rawProperties ?? _emptyRawProperties;
    final int? sequence = icsMeta?.sequence;
    final bool showInvitationStatus = hasInvitationStatusData(
      method: method,
      sequence: sequence,
      rawProperties: rawProperties,
    );
    final bool showDiagnostics = hasIcsDiagnosticsData(icsMeta);
    final env = EnvScope.maybeOf(context);
    final bool isDesktop = env?.isDesktopPlatform ?? false;
    final List<TaskContextAction> inlineActions = widget.inlineActions;
    Widget buildBody({
      required double keyboardInset,
      required double safeBottom,
    }) {
      final bool keyboardOpen = keyboardInset > safeBottom;
      Widget? actionRow({required bool includeTopBorder}) {
        if (!allowsAnyEdits) {
          return null;
        }
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _titleController,
          builder: (context, value, _) {
            final bool canSave =
                TaskTitleValidation.validate(value.text) == null;
            return _EditTaskActionsRow(
              task: widget.task,
              onDelete: () {
                widget.onTaskDeleted(widget.task.id);
                widget.onClose();
              },
              onCancel: _handleCancel,
              onSave: _handleSave,
              canSave: canSave,
              includeTopBorder: includeTopBorder,
              showDelete: allowsFullEdits,
            );
          },
        );
      }

      final Widget? keyboardActionRow = actionRow(includeTopBorder: true);
      final Widget? footerActionRow = actionRow(includeTopBorder: false);

      final Widget form = Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _EditTaskHeader(onClose: widget.onClose),
            const Divider(height: 1),
            Flexible(
              fit: FlexFit.loose,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  calendarGutterLg,
                  calendarGutterMd,
                  calendarGutterLg,
                  calendarGutterMd +
                      (isSheet && keyboardOpen ? keyboardInset : 0),
                ),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.manual,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isSheet)
                      _EditTaskInlineActionsSection(
                        inlineActions: inlineActions,
                      ),
                    if (widget.task.isOccurrence &&
                        widget.onOccurrenceUpdated != null) ...[
                      const SizedBox(height: calendarFormGap),
                      _EditTaskOccurrenceScopeSection(
                        scope: _occurrenceScope,
                        enabled: allowsAnyEdits,
                        onChanged: (scope) =>
                            setState(() => _occurrenceScope = scope),
                      ),
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                    ],
                    _EditTaskTitleField(
                      controller: _titleController,
                      validator: (value) =>
                          TaskTitleValidation.validate(value ?? ''),
                      onChanged: _handleTitleChanged,
                      focusNode: _titleFocusNode,
                      autovalidateMode: AutovalidateMode.disabled,
                      enabled: allowsFullEdits,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskDescriptionField(
                      controller: _descriptionController,
                      onChanged: _handleDescriptionChanged,
                      enabled: allowsFullEdits,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskLocationField(
                      controller: _locationController,
                      locationHelper: widget.locationHelper,
                      onChanged: _handleLocationChanged,
                      enabled: allowsFullEdits,
                    ),
                    const SizedBox(height: calendarFormGap),
                    _EditTaskPriorityRow(
                      isImportant: _isImportant,
                      isUrgent: _isUrgent,
                      enabled: allowsFullEdits,
                      onImportantChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.priority);
                        _isImportant = value;
                      }),
                      onUrgentChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.priority);
                        _isUrgent = value;
                      }),
                    ),
                    const SizedBox(height: calendarFormGap),
                    TaskChecklist(
                      controller: _checklistController,
                      enabled: allowsChecklistEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskScheduleSection(
                      start: _startTime,
                      end: _endTime,
                      onStartChanged: _handleStartChanged,
                      onEndChanged: _handleEndChanged,
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskDeadlineField(
                      deadline: _deadline,
                      onChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.deadline);
                        _deadline = value;
                      }),
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskReminderSection(
                      reminders: _reminders,
                      deadline: _deadline,
                      referenceStart: _startTime,
                      advancedAlarms: _advancedAlarms,
                      onChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.reminders);
                        _reminders = value;
                      }),
                      onAdvancedAlarmsChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.advancedAlarms);
                        _advancedAlarms = value;
                      }),
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskRecurrenceSection(
                      value: _recurrence,
                      fallbackWeekday: _recurrenceFallbackWeekday,
                      referenceStart: _startTime,
                      onChanged: _handleRecurrenceChanged,
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarCategoriesField(
                      categories: _categories,
                      onChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.categories);
                        _categories = value;
                      }),
                      surfaceColor: background,
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarLinkGeoFields(
                      url: _url,
                      geo: _geo,
                      onUrlChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.url);
                        _url = value;
                      }),
                      onGeoChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.geo);
                        _geo = value;
                      }),
                      enabled: allowsFullEdits,
                    ),
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    CalendarParticipantsField(
                      organizer: _organizer,
                      attendees: _attendees,
                      onOrganizerChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.organizer);
                        _organizer = value;
                      }),
                      onAttendeesChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.attendees);
                        _attendees = value;
                      }),
                      enabled: allowsFullEdits,
                    ),
                    if (showInvitationStatus) ...[
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                      CalendarInvitationStatusField(
                        method: method,
                        sequence: sequence,
                        rawProperties: rawProperties,
                      ),
                    ],
                    if (_attachments.isNotEmpty) ...[
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                      CalendarAttachmentsField(
                        attachments: _attachments,
                      ),
                    ],
                    if (showDiagnostics) ...[
                      const TaskSectionDivider(
                        verticalPadding: calendarGutterMd,
                      ),
                      CalendarIcsDiagnosticsSection(icsMeta: icsMeta),
                    ],
                    const TaskSectionDivider(
                      verticalPadding: calendarGutterMd,
                    ),
                    _EditTaskCompletionToggle(
                      value: _isCompleted,
                      enabled: allowsFullEdits,
                      onChanged: (value) => _updateDraft(() {
                        _markTouched(_TaskEditField.completion);
                        _isCompleted = value;
                      }),
                    ),
                    const SizedBox(height: calendarFormGap),
                    if (!allowsFullEdits)
                      IgnorePointer(
                        child: _TaskCriticalPathMembership<B>(
                          task: widget.task,
                        ),
                      )
                    else
                      _TaskCriticalPathMembership<B>(
                        task: widget.task,
                      ),
                    const SizedBox(height: calendarFormGap),
                    if (keyboardOpen && keyboardActionRow != null)
                      keyboardActionRow,
                  ],
                ),
              ),
            ),
            if (!keyboardOpen && allowsAnyEdits && footerActionRow != null)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  SafeArea(
                    top: false,
                    bottom: true,
                    child: footerActionRow,
                  ),
                ],
              ),
          ],
        ),
      );

      if (!isSheet) {
        return form;
      }

      return SafeArea(
        top: true,
        bottom: false,
        child: form,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double resolvedMaxHeight = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : widget.maxHeight;
        final mediaQuery = MediaQuery.of(context);
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final double safeBottom = mediaQuery.viewPadding.bottom;
        final BoxBorder? popoverBorder =
            isSheet ? null : Border.all(color: calendarBorderColor);
        final Widget surfaceBody = ValueListenableBuilder<int>(
          valueListenable: _popoverBodyRevision,
          builder: (context, _, __) {
            return buildBody(
              keyboardInset: keyboardInset,
              safeBottom: safeBottom,
            );
          },
        );
        final Widget surfaced = _TaskPopoverSurface(
          width: isSheet ? double.infinity : calendarTaskPopoverWidth,
          constraints: BoxConstraints(
            maxHeight: resolvedMaxHeight,
            minWidth: _taskPopoverMinWidth,
          ),
          radius: radius,
          background: background,
          border: popoverBorder,
          boxShadow: boxShadow ?? const <BoxShadow>[],
          child: surfaceBody,
        );

        if (!isSheet && isDesktop) {
          final Widget transformed = _TaskPopoverContainerTransform(
            header: popoverHeader,
            body: surfaceBody,
            width: calendarTaskPopoverWidth,
            maxHeight: resolvedMaxHeight,
            radius: radius,
            background: background,
            border: popoverBorder,
            boxShadow: boxShadow ?? const <BoxShadow>[],
          );
          return SafeArea(
            top: true,
            bottom: true,
            child: transformed,
          );
        }

        if (!isSheet) {
          return SafeArea(
            top: true,
            bottom: true,
            child: surfaced,
          );
        }
        return SafeArea(
          top: true,
          bottom: false,
          child: surfaced,
        );
      },
    );
  }

  void _handleTitleChanged(String value) {
    _markTouched(_TaskEditField.title);
  }

  void _handleDescriptionChanged(String value) {
    _markTouched(_TaskEditField.description);
  }

  void _handleLocationChanged(String value) {
    _markTouched(_TaskEditField.location);
  }

  int get _recurrenceFallbackWeekday =>
      _startTime?.weekday ??
      widget.task.scheduledTime?.weekday ??
      DateTime.now().weekday;

  void _handleStartChanged(DateTime? value) {
    _updateDraft(() {
      _markTouched(_TaskEditField.schedule);
      final DateTime? previousStart = _startTime;
      final DateTime? previousEnd = _endTime;
      _startTime = value;
      _endTime = shiftEndTimeWithStart(
        previousStart: previousStart,
        previousEnd: previousEnd,
        nextStart: value,
      );
      if (value == null) {
        return;
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleEndChanged(DateTime? value) {
    _updateDraft(() {
      _markTouched(_TaskEditField.schedule);
      _endTime = clampEndTime(start: _startTime, end: value);
      if (_endTime == null) {
        return;
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleRecurrenceChanged(RecurrenceFormValue next) {
    _updateDraft(() {
      _markTouched(_TaskEditField.recurrence);
      _recurrence = _normalizeRecurrence(next);
    });
  }

  RecurrenceFormValue _normalizeRecurrence(RecurrenceFormValue value) {
    final DateTime? anchor = _startTime ?? widget.task.scheduledTime;
    return value.resolveLinkedLimits(anchor);
  }

  void _handleSave() {
    final TaskEditMode editMode = widget.editMode;
    _checklistController.commitPendingEntry();
    final bool isOccurrenceEdit =
        widget.task.isOccurrence && widget.onOccurrenceUpdated != null;
    if (editMode.isChecklistOnly) {
      final CalendarTask baseTask = _resolveLatestTaskSnapshot();
      final List<TaskChecklistItem> checklistItems =
          _checklistController.items.toList();
      final CalendarTask updatedTask = baseTask.copyWith(
        checklist: checklistItems,
      );
      if (isOccurrenceEdit) {
        widget.onOccurrenceUpdated!(
          updatedTask,
          _occurrenceScope,
          scheduleTouched: false,
          checklistTouched: true,
        );
        final CalendarTask? seriesTask = _resolveLatestSeriesSnapshot();
        if (seriesTask != null) {
          final CalendarTask seriesUpdate =
              seriesTask.copyWith(checklist: checklistItems);
          if (seriesUpdate != seriesTask) {
            widget.onTaskUpdated(seriesUpdate);
          }
        }
      } else {
        widget.onTaskUpdated(updatedTask);
      }
      widget.onClose();
      return;
    }
    if (!editMode.allowsAnyEdits) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      _titleFocusNode.requestFocus();
      return;
    }

    final CalendarTask baseTask = _resolveLatestTaskSnapshot();
    final bool titleTouched = _isTouched(_TaskEditField.title);
    final String nextTitle = _titleController.text.trim();
    final String title = titleTouched ? nextTitle : baseTask.title;

    final bool priorityTouched = _isTouched(_TaskEditField.priority);
    final TaskPriority nextPriority = () {
      if (_isImportant && _isUrgent) return TaskPriority.critical;
      if (_isImportant) return TaskPriority.important;
      if (_isUrgent) return TaskPriority.urgent;
      return TaskPriority.none;
    }();
    final TaskPriority? priority =
        priorityTouched ? nextPriority : baseTask.priority;

    final bool scheduleTouched = _isTouched(_TaskEditField.schedule);
    DateTime? scheduledTime;
    Duration? duration;
    DateTime? endDate;
    if (scheduleTouched) {
      if (_startTime != null && _endTime != null) {
        final DateTime start = _startTime!;
        DateTime end = _endTime!;
        Duration computed = end.difference(start);
        if (computed.inMinutes < 15) {
          computed = const Duration(minutes: 15);
          end = start.add(computed);
          _endTime = end;
        }
        scheduledTime = start;
        duration = computed;
        endDate = end;
      }

      if (scheduledTime == null) {
        duration = null;
        endDate = null;
      }
    } else {
      scheduledTime = baseTask.scheduledTime;
      duration = baseTask.duration;
      endDate = baseTask.endDate;
    }

    final bool recurrenceTouched = _isTouched(_TaskEditField.recurrence) ||
        (!isOccurrenceEdit && scheduleTouched);
    final DateTime recurrenceAnchor =
        scheduledTime ?? baseTask.scheduledTime ?? DateTime.now();
    final RecurrenceRule? nextRecurrence = recurrenceTouched
        ? (_recurrence.isActive
            ? _recurrence
                .resolveLinkedLimits(recurrenceAnchor)
                .toRule(start: recurrenceAnchor)
            : null)
        : null;
    final RecurrenceRule? recurrence = recurrenceTouched
        ? (nextRecurrence?.isNone == true ? null : nextRecurrence)
        : baseTask.recurrence;

    final bool descriptionTouched = _isTouched(_TaskEditField.description);
    final String descriptionText = _descriptionController.text.trim();
    final String? nextDescription =
        descriptionText.isEmpty ? null : descriptionText;
    final String? description =
        descriptionTouched ? nextDescription : baseTask.description;
    final bool locationTouched = _isTouched(_TaskEditField.location);
    final String locationText = _locationController.text.trim();
    final String? nextLocation = locationText.isEmpty ? null : locationText;
    final String? location = locationTouched ? nextLocation : baseTask.location;
    final bool deadlineTouched = _isTouched(_TaskEditField.deadline);
    final DateTime? nextDeadline = _deadline;
    final DateTime? deadline =
        deadlineTouched ? nextDeadline : baseTask.deadline;
    final bool completionTouched = _isTouched(_TaskEditField.completion);
    final bool nextIsCompleted = _isCompleted;
    final bool isCompleted =
        completionTouched ? nextIsCompleted : baseTask.isCompleted;
    final bool checklistTouched = _isTouched(_TaskEditField.checklist);
    final List<TaskChecklistItem> checklistItems =
        _checklistController.items.toList();
    final List<TaskChecklistItem> checklist =
        checklistTouched ? checklistItems : baseTask.checklist;

    final bool remindersTouched = _isTouched(_TaskEditField.reminders);
    final bool advancedAlarmsTouched =
        _isTouched(_TaskEditField.advancedAlarms);
    final AlarmReminderSplit baseSplit = _splitTaskAlarms(baseTask);
    final ReminderPreferences remindersForAlarms =
        remindersTouched ? _reminders : baseSplit.reminders;
    final List<CalendarAlarm> advancedAlarmsForMerge =
        advancedAlarmsTouched ? _advancedAlarms : baseSplit.advancedAlarms;
    final bool shouldUpdateAlarms = remindersTouched || advancedAlarmsTouched;
    final List<CalendarAlarm>? alarmsOverride = shouldUpdateAlarms
        ? mergeAdvancedAlarms(
            advancedAlarms: advancedAlarmsForMerge,
            reminders: remindersForAlarms,
          )
        : null;
    final ReminderPreferences? remindersField =
        remindersTouched ? remindersForAlarms : baseTask.reminders;

    final bool categoriesTouched = _isTouched(_TaskEditField.categories);
    final bool organizerTouched = _isTouched(_TaskEditField.organizer);
    final bool attendeesTouched = _isTouched(_TaskEditField.attendees);
    final bool urlTouched = _isTouched(_TaskEditField.url);
    final bool geoTouched = _isTouched(_TaskEditField.geo);
    final bool shouldUpdateIcsMeta = categoriesTouched ||
        organizerTouched ||
        attendeesTouched ||
        urlTouched ||
        geoTouched ||
        shouldUpdateAlarms;

    CalendarIcsMeta? resolveIcsMeta(CalendarIcsMeta? base) {
      if (!shouldUpdateIcsMeta) {
        return base;
      }
      final List<String>? categoriesOverride = categoriesTouched
          ? resolveCategoryOverride(
              base: base,
              categories: _categories,
            )
          : null;
      final CalendarOrganizer? organizerOverride = organizerTouched
          ? resolveOrganizerOverride(
              base: base,
              organizer: _organizer,
            )
          : null;
      final List<CalendarAttendee>? attendeesOverride = attendeesTouched
          ? resolveAttendeeOverride(
              base: base,
              attendees: _attendees,
            )
          : null;
      return applyIcsMetaOverrides(
        base: base,
        categories: categoriesOverride,
        url: urlTouched ? _url : null,
        geo: geoTouched ? _geo : null,
        organizer: organizerOverride,
        attendees: attendeesOverride,
        alarms: alarmsOverride,
      );
    }

    final CalendarIcsMeta? icsMeta = resolveIcsMeta(baseTask.icsMeta);

    final CalendarTask updatedTask = baseTask.copyWith(
      title: title,
      description: description,
      location: location,
      scheduledTime: scheduledTime,
      duration: duration,
      endDate: endDate,
      deadline: deadline,
      priority: priority,
      isCompleted: isCompleted,
      recurrence: recurrence,
      checklist: checklist,
      reminders: remindersField,
      icsMeta: icsMeta,
    );

    if (isOccurrenceEdit) {
      if (scheduleTouched || checklistTouched) {
        widget.onOccurrenceUpdated!(
          updatedTask,
          _occurrenceScope,
          scheduleTouched: scheduleTouched,
          checklistTouched: checklistTouched,
        );
      }

      final CalendarTask? seriesTask = _resolveLatestSeriesSnapshot();
      if (seriesTask != null) {
        final ReminderPreferences? seriesReminders =
            remindersTouched ? remindersForAlarms : seriesTask.reminders;
        final CalendarIcsMeta? seriesIcsMeta =
            resolveIcsMeta(seriesTask.icsMeta);
        final CalendarTask seriesUpdate = seriesTask.copyWith(
          title: titleTouched ? nextTitle : seriesTask.title,
          description:
              descriptionTouched ? nextDescription : seriesTask.description,
          location: locationTouched ? nextLocation : seriesTask.location,
          deadline: deadlineTouched ? nextDeadline : seriesTask.deadline,
          priority: priorityTouched ? nextPriority : seriesTask.priority,
          isCompleted:
              completionTouched ? nextIsCompleted : seriesTask.isCompleted,
          checklist: checklistTouched ? checklistItems : seriesTask.checklist,
          recurrence: recurrenceTouched
              ? (nextRecurrence?.isNone == true ? null : nextRecurrence)
              : seriesTask.recurrence,
          reminders: seriesReminders,
          icsMeta: seriesIcsMeta,
        );

        if (seriesUpdate != seriesTask) {
          widget.onTaskUpdated(seriesUpdate);
        }
      }
    } else {
      widget.onTaskUpdated(updatedTask);
    }
    widget.onClose();
  }

  void _handleCancel() {
    widget.onClose();
  }
}

class _TaskPopoverSurface extends StatelessWidget {
  const _TaskPopoverSurface({
    required this.child,
    required this.width,
    required this.radius,
    required this.background,
    required this.border,
    required this.boxShadow,
    this.constraints,
  });

  final Widget child;
  final double width;
  final BorderRadius radius;
  final Color background;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          width: width,
          constraints: constraints,
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: border,
            boxShadow: boxShadow,
          ),
          child: child,
        ),
      ),
    );
  }
}

class _TaskPopoverContainerTransform extends StatefulWidget {
  const _TaskPopoverContainerTransform({
    required this.header,
    required this.body,
    required this.width,
    required this.maxHeight,
    required this.radius,
    required this.background,
    required this.border,
    required this.boxShadow,
  });

  final Widget header;
  final Widget body;
  final double width;
  final double maxHeight;
  final BorderRadius radius;
  final Color background;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;

  @override
  State<_TaskPopoverContainerTransform> createState() =>
      _TaskPopoverContainerTransformState();
}

class _TaskPopoverContainerTransformState
    extends State<_TaskPopoverContainerTransform> {
  final GlobalKey<OpenContainerState> _containerKey =
      GlobalKey<OpenContainerState>();
  bool _opened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openContainer());
  }

  void _openContainer() {
    if (_opened) {
      return;
    }
    _opened = true;
    _containerKey.currentState?.openContainer();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.maxHeight,
      child: Navigator(
        onGenerateRoute: (_) => PageRouteBuilder<void>(
          pageBuilder: (context, _, __) => _TaskPopoverTransformBody(
            containerKey: _containerKey,
            header: widget.header,
            body: widget.body,
            width: widget.width,
            maxHeight: widget.maxHeight,
            radius: widget.radius,
            background: widget.background,
            border: widget.border,
            boxShadow: widget.boxShadow,
          ),
          transitionDuration: Duration.zero,
          reverseTransitionDuration: Duration.zero,
        ),
      ),
    );
  }
}

class _TaskPopoverTransformBody extends StatelessWidget {
  const _TaskPopoverTransformBody({
    required this.containerKey,
    required this.header,
    required this.body,
    required this.width,
    required this.maxHeight,
    required this.radius,
    required this.background,
    required this.border,
    required this.boxShadow,
  });

  final GlobalKey<OpenContainerState> containerKey;
  final Widget header;
  final Widget body;
  final double width;
  final double maxHeight;
  final BorderRadius radius;
  final Color background;
  final BoxBorder? border;
  final List<BoxShadow> boxShadow;

  @override
  Widget build(BuildContext context) {
    final BoxConstraints openConstraints = BoxConstraints(
      maxHeight: maxHeight,
      minWidth: _taskPopoverMinWidth,
    );
    const BoxConstraints closedConstraints = BoxConstraints(
      minWidth: _taskPopoverMinWidth,
    );
    return OpenContainer(
      key: containerKey,
      tappable: false,
      closedColor: Colors.transparent,
      openColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      transitionDuration: baseAnimationDuration,
      transitionType: ContainerTransitionType.fadeThrough,
      closedBuilder: (context, action) {
        return Align(
          alignment: _taskPopoverTransformAlignment,
          child: _TaskPopoverSurface(
            width: width,
            constraints: closedConstraints,
            radius: radius,
            background: background,
            border: border,
            boxShadow: boxShadow,
            child: header,
          ),
        );
      },
      openBuilder: (context, action) {
        return Align(
          alignment: _taskPopoverTransformAlignment,
          child: _TaskPopoverSurface(
            width: width,
            constraints: openConstraints,
            radius: radius,
            background: background,
            border: border,
            boxShadow: boxShadow,
            child: body,
          ),
        );
      },
    );
  }
}

class _EditTaskHeader extends StatelessWidget {
  const _EditTaskHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterLg,
        vertical: calendarGutterMd,
      ),
      child: Row(
        children: [
          Text(
            'Edit Task',
            style: calendarTitleTextStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          AxiIconButton(
            iconData: Icons.close,
            tooltip: context.l10n.calendarCloseTooltip,
            onPressed: onClose,
            color: calendarSubtitleColor,
            backgroundColor: colors.card,
            borderColor: colors.border,
            iconSize: 18,
            buttonSize: 34,
            tapTargetSize: 40,
            cornerRadius: 12,
          ),
        ],
      ),
    );
  }
}

class _EditTaskInlineActionsSection extends StatelessWidget {
  const _EditTaskInlineActionsSection({
    required this.inlineActions,
  });

  final List<TaskContextAction> inlineActions;

  @override
  Widget build(BuildContext context) {
    if (inlineActions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterLg,
            vertical: calendarGutterMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task actions',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: calendarInsetSm),
              LayoutBuilder(
                builder: (context, constraints) {
                  final double? width = constraints.maxWidth.isFinite
                      ? constraints.maxWidth
                      : null;
                  final chipWrap = Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: inlineActions
                        .map(
                          (action) => _EditTaskInlineActionChip(
                            action: action,
                          ),
                        )
                        .toList(growable: false),
                  );
                  if (width == null) {
                    return chipWrap;
                  }
                  return SizedBox(width: width, child: chipWrap);
                },
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        const SizedBox(height: calendarFormGap),
      ],
    );
  }
}

class _EditTaskInlineActionChip extends StatelessWidget {
  const _EditTaskInlineActionChip({
    required this.action,
  });

  final TaskContextAction action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color baseColor =
        action.destructive ? scheme.error : calendarPrimaryColor;
    final Color background = baseColor.withValues(alpha: 0.12);
    return TextButton.icon(
      onPressed: action.onSelected,
      style: TextButton.styleFrom(
        foregroundColor: baseColor,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(action.icon, size: 16),
      label: Text(
        action.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EditTaskTitleField extends StatelessWidget {
  const _EditTaskTitleField({
    required this.controller,
    required this.validator,
    required this.onChanged,
    this.focusNode,
    required this.autovalidateMode,
    required this.enabled,
  });

  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;
  final FocusNode? focusNode;
  final AutovalidateMode autovalidateMode;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTitleField(
          controller: controller,
          focusNode: focusNode,
          autofocus: enabled,
          hintText: context.l10n.calendarTaskTitleHint,
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: autovalidateMode,
          textInputAction: TextInputAction.done,
          enabled: enabled,
        ),
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _EditTaskDescriptionField extends StatelessWidget {
  const _EditTaskDescriptionField({
    required this.controller,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskDescriptionField(
      controller: controller,
      onChanged: onChanged,
      hintText: context.l10n.calendarDescriptionOptionalHint,
      minLines: 2,
      maxLines: 4,
      textCapitalization: TextCapitalization.sentences,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      contentPadding: calendarFieldPadding,
      enabled: enabled,
    );
  }
}

class _EditTaskLocationField extends StatelessWidget {
  const _EditTaskLocationField({
    required this.controller,
    required this.locationHelper,
    required this.onChanged,
    required this.enabled,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper locationHelper;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskLocationField(
      controller: controller,
      hintText: context.l10n.calendarLocationOptionalHint,
      textCapitalization: TextCapitalization.words,
      contentPadding: calendarFieldPadding,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      autocomplete: locationHelper,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class _EditTaskScheduleSection extends StatelessWidget {
  const _EditTaskScheduleSection({
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.enabled,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskScheduleSection(
      spacing: calendarInsetLg,
      start: start,
      end: end,
      onStartChanged: onStartChanged,
      onEndChanged: onEndChanged,
      enabled: enabled,
    );
  }
}

class _EditTaskOccurrenceScopeSection extends StatelessWidget {
  const _EditTaskOccurrenceScopeSection({
    required this.scope,
    required this.onChanged,
    required this.enabled,
  });

  final OccurrenceUpdateScope scope;
  final ValueChanged<OccurrenceUpdateScope> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final TextStyle hintStyle = context.textTheme.muted.copyWith(
      fontWeight: FontWeight.w500,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: _occurrenceScopeTitle),
        const SizedBox(height: calendarInsetSm),
        Text(
          _occurrenceScopeHint,
          style: hintStyle,
        ),
        const SizedBox(height: calendarGutterSm),
        Wrap(
          spacing: calendarGutterSm,
          runSpacing: calendarGutterSm,
          children: OccurrenceUpdateScope.values
              .map(
                (option) => _OccurrenceScopeChip(
                  label: option.label,
                  isSelected: option == scope,
                  onPressed: enabled ? () => onChanged(option) : null,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _OccurrenceScopeChip extends StatelessWidget {
  const _OccurrenceScopeChip({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: calendarGutterSm,
      ),
      backgroundColor:
          isSelected ? calendarPrimaryColor : calendarContainerColor,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: 0.08),
      foregroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : calendarPrimaryColor,
      hoverForegroundColor: isSelected
          ? context.colorScheme.primaryForeground
          : calendarPrimaryHoverColor,
      onPressed: onPressed,
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
    ).withTapBounce();
  }
}

class _EditTaskDeadlineField extends StatelessWidget {
  const _EditTaskDeadlineField({
    required this.deadline,
    required this.onChanged,
    required this.enabled,
  });

  final DateTime? deadline;
  final ValueChanged<DateTime?> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Deadline'),
        const SizedBox(height: calendarInsetMd),
        DeadlinePickerField(
          value: deadline,
          onChanged: onChanged,
          enabled: enabled,
        ),
      ],
    );
  }
}

class _EditTaskReminderSection extends StatelessWidget {
  const _EditTaskReminderSection({
    required this.reminders,
    required this.deadline,
    required this.referenceStart,
    required this.advancedAlarms,
    required this.onChanged,
    required this.onAdvancedAlarmsChanged,
    required this.enabled,
  });

  final ReminderPreferences reminders;
  final DateTime? deadline;
  final DateTime? referenceStart;
  final List<CalendarAlarm> advancedAlarms;
  final ValueChanged<ReminderPreferences> onChanged;
  final ValueChanged<List<CalendarAlarm>> onAdvancedAlarmsChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ReminderPreferencesField(
      value: reminders,
      onChanged: onChanged,
      advancedAlarms: advancedAlarms,
      onAdvancedAlarmsChanged: onAdvancedAlarmsChanged,
      referenceStart: referenceStart,
      anchor: deadline == null ? ReminderAnchor.start : ReminderAnchor.deadline,
      showBothAnchors: deadline != null,
      enabled: enabled,
    );
  }
}

class _EditTaskRecurrenceSection extends StatelessWidget {
  const _EditTaskRecurrenceSection({
    required this.value,
    required this.fallbackWeekday,
    required this.referenceStart,
    required this.onChanged,
    required this.enabled,
  });

  final RecurrenceFormValue value;
  final int fallbackWeekday;
  final DateTime? referenceStart;
  final ValueChanged<RecurrenceFormValue> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskRecurrenceSection(
      spacing: calendarInsetMd,
      value: value,
      fallbackWeekday: fallbackWeekday,
      referenceStart: referenceStart,
      spacingConfig: const RecurrenceEditorSpacing(
        chipSpacing: 6,
        chipRunSpacing: 6,
        weekdaySpacing: 10,
        advancedSectionSpacing: 12,
        endSpacing: 14,
        fieldGap: 12,
      ),
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class _EditTaskPriorityRow extends StatelessWidget {
  const _EditTaskPriorityRow({
    required this.isImportant,
    required this.isUrgent,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.enabled,
  });

  final bool isImportant;
  final bool isUrgent;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskPriorityToggles(
      isImportant: isImportant,
      isUrgent: isUrgent,
      onImportantChanged: enabled ? onImportantChanged : null,
      onUrgentChanged: enabled ? onUrgentChanged : null,
    );
  }
}

class _EditTaskCompletionToggle extends StatelessWidget {
  const _EditTaskCompletionToggle({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return TaskCompletionToggle(
      value: value,
      onChanged: onChanged,
      enabled: enabled,
    );
  }
}

class _TaskCriticalPathMembership<B extends BaseCalendarBloc>
    extends StatelessWidget {
  const _TaskCriticalPathMembership({
    required this.task,
  });

  final CalendarTask task;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<B, CalendarState>(
      builder: (context, state) {
        final paths = state.criticalPathsForTask(task);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskSecondaryButton(
              label: context.l10n.calendarAddToCriticalPath,
              icon: Icons.route,
              onPressed: () => addTaskToCriticalPath(
                context: context,
                bloc: context.read<B>(),
                task: task,
              ),
            ),
            const SizedBox(height: calendarInsetSm),
            CriticalPathMembershipList(
              paths: paths,
              onRemovePath: (pathId) => context.read<B>().add(
                    CalendarEvent.criticalPathTaskRemoved(
                      pathId: pathId,
                      taskId: task.id,
                    ),
                  ),
              emptyLabel: context.l10n.calendarNoCriticalPathMembership,
            ),
          ],
        );
      },
    );
  }
}

class _EditTaskActionsRow extends StatelessWidget {
  const _EditTaskActionsRow({
    required this.task,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
    required this.canSave,
    required this.includeTopBorder,
    required this.showDelete,
  });

  final CalendarTask task;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;
  final bool canSave;
  final bool includeTopBorder;
  final bool showDelete;

  @override
  Widget build(BuildContext context) {
    return TaskFormActionsRow(
      includeTopBorder: includeTopBorder,
      padding: calendarPaddingLg,
      gap: 8,
      children: [
        if (showDelete)
          TaskDestructiveButton(
            label: context.l10n.commonDelete,
            onPressed: onDelete,
          ),
        const Spacer(),
        TaskSecondaryButton(
          label: context.l10n.commonCancel,
          onPressed: onCancel,
          foregroundColor: calendarPrimaryColor,
          hoverForegroundColor: calendarPrimaryHoverColor,
          hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        ),
        TaskPrimaryButton(
          label: context.l10n.commonSave,
          onPressed: canSave ? onSave : null,
        ),
      ],
    );
  }
}
