// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/reminders/alarm_reminder_bridge.dart';
import 'package:axichat/src/calendar/interop/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/tasks/location_autocomplete.dart';
import 'package:axichat/src/calendar/task/nl_parser_service.dart';
import 'package:axichat/src/calendar/task/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/view/tasks/task_title_validation.dart';
import 'package:axichat/src/calendar/view/tasks/task_checklist_controller.dart';
import 'package:axichat/src/calendar/view/tasks/task_draft_controller.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_date_time_field.dart';
import 'package:axichat/src/calendar/view/tasks/location_inline_suggestion.dart';
import 'package:axichat/src/calendar/view/tasks/recurrence_editor.dart';
import 'package:axichat/src/calendar/view/tasks/task_field_character_hint.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';
import 'package:axichat/src/calendar/view/tasks/task_checklist.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_categories_field.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_participants_field.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_link_geo_fields.dart';
import 'package:axichat/src/calendar/view/tasks/reminder_preferences_field.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'package:axichat/src/calendar/view/sidebar/critical_path_panel.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAlarm> _emptyAdvancedAlarms = <CalendarAlarm>[];
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];
const bool _calendarUseRootNavigator = false;

enum QuickAddModalSurface { dialog, bottomSheet }

class QuickAddModal extends StatefulWidget {
  final DateTime? prefilledDateTime;
  final String? prefilledText;
  final VoidCallback? onDismiss;
  final void Function(CalendarTask task, List<String> queuedCriticalPathIds)
  onTaskAdded;
  final QuickAddModalSurface surface;
  final LocationAutocompleteHelper locationHelper;
  final String? initialValidationMessage;
  final BaseCalendarBloc? Function()? locateCalendarBloc;

  const QuickAddModal({
    super.key,
    this.prefilledDateTime,
    this.prefilledText,
    this.onDismiss,
    required this.onTaskAdded,
    this.surface = QuickAddModalSurface.dialog,
    required this.locationHelper,
    this.initialValidationMessage,
    this.locateCalendarBloc,
  });

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal> {
  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late final TaskChecklistController _checklistController;
  final _taskNameFocusNode = FocusNode();
  final List<String> _queuedCriticalPathIds = <String>[];
  final GlobalKey<ShadFormState> _formKey = GlobalKey<ShadFormState>();
  String? _initialTitleValidationMessage;

  late final TaskDraftController _formController;
  late final NlScheduleParserService _parserService;
  Timer? _parserDebounce;
  int _parserRequestId = 0;
  String _lastParserInput = '';
  bool _isApplyingParser = false;

  bool _locationLocked = false;
  bool _scheduleLocked = false;
  bool _deadlineLocked = false;
  bool _recurrenceLocked = false;
  bool _priorityLocked = false;
  bool _remindersLocked = false;
  NlAdapterResult? _lastParserResult;
  String? _formError;
  bool _awaitingTaskCreation = false;
  bool _awaitingCriticalPathCreate = false;

  @override
  void initState() {
    super.initState();
    _initialTitleValidationMessage = widget.initialValidationMessage;
    _checklistController = TaskChecklistController();

    final prefilled = widget.prefilledDateTime;

    _formController = TaskDraftController(
      initialStart: prefilled,
      initialEnd: prefilled?.add(calendarDefaultTaskDuration),
    );
    _parserService = NlScheduleParserService();
    _applyPrefill(prefilled);

    final seededText = widget.prefilledText?.trim();
    if (seededText != null && seededText.isNotEmpty) {
      _taskNameController.value = TextEditingValue(
        text: seededText,
        selection: TextSelection.collapsed(offset: seededText.length),
      );
      _initialTitleValidationMessage = null;
      _scheduleParserRun(seededText, clearFieldsWhenEmpty: false);
    }
  }

  @override
  void dispose() {
    _parserDebounce?.cancel();
    _taskNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _checklistController.dispose();
    _taskNameFocusNode.dispose();
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QuickAddModalShell(
      formKey: _formKey,
      bloc: _locateCalendarBloc(),
      onCalendarStateChanged: _handleCalendarStateChanged,
      contentBuilder: (context, isSubmitting) => _QuickAddModalContent(
        isSheet: widget.surface == QuickAddModalSurface.bottomSheet,
        formController: _formController,
        isSubmitting: isSubmitting,
        taskNameController: _taskNameController,
        descriptionController: _descriptionController,
        locationController: _locationController,
        checklistController: _checklistController,
        taskNameFocusNode: _taskNameFocusNode,
        locationHelper: widget.locationHelper,
        onTaskNameChanged: _handleTaskNameChanged,
        onTaskSubmit: _submitTask,
        onClose: _requestDismiss,
        onCancel: _requestDismiss,
        onLocationChanged: _handleLocationEdited,
        onStartChanged: _onUserStartChanged,
        onEndChanged: _onUserEndChanged,
        onScheduleCleared: _onUserScheduleCleared,
        onDeadlineChanged: _onUserDeadlineChanged,
        onRecurrenceChanged: _onUserRecurrenceChanged,
        onImportantChanged: _onUserImportantChanged,
        onUrgentChanged: _onUserUrgentChanged,
        onRemindersChanged: _onRemindersChanged,
        onAdvancedAlarmsChanged: _onAdvancedAlarmsChanged,
        onCategoriesChanged: _onCategoriesChanged,
        onUrlChanged: _onUrlChanged,
        onGeoChanged: _onGeoChanged,
        onOrganizerChanged: _onOrganizerChanged,
        onAttendeesChanged: _onAttendeesChanged,
        fallbackDate: widget.prefilledDateTime,
        onAddToCriticalPath: _queueCriticalPathForDraft,
        queuedPaths: _queuedPaths(),
        onRemoveQueuedPath: _removeQueuedCriticalPath,
        hasCalendarBloc: widget.locateCalendarBloc != null,
        formError: _formError,
        titleValidator: _validateTaskTitle,
        titleAutovalidateMode: _titleAutovalidateMode,
      ),
    );
  }

  AutovalidateMode get _titleAutovalidateMode => AutovalidateMode.disabled;

  String? _validateTaskTitle(String? raw) {
    return _initialTitleValidationMessage ??
        TaskTitleValidation.validate(raw ?? '', context.l10n);
  }

  void _clearInitialValidationMessage() {
    if (_initialTitleValidationMessage == null) {
      return;
    }
    setState(() {
      _initialTitleValidationMessage = null;
    });
  }

  void _handleTaskNameChanged(String value) {
    _setFormError(null);
    _clearInitialValidationMessage();
    _scheduleParserRun(value, clearFieldsWhenEmpty: true);
  }

  void _scheduleParserRun(String value, {required bool clearFieldsWhenEmpty}) {
    final trimmed = value.trim();
    _parserDebounce?.cancel();
    if (trimmed.isEmpty) {
      if (clearFieldsWhenEmpty) {
        _clearParserState(clearFields: true);
      }
      return;
    }
    if (trimmed == _lastParserInput) {
      return;
    }
    _parserDebounce = Timer(calendarQuickAddParserDebounceDelay, () {
      _runParser(trimmed);
    });
  }

  Future<void> _runParser(String input) async {
    final requestId = ++_parserRequestId;
    try {
      final result = await _parserService.parse(input);
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = input;
      _lastParserResult = result;
      _applyParserResult(result);
      _setFormError(null);
    } catch (error) {
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = '';
      _lastParserResult = null;
      _clearParserDrivenFields();
      _setFormError(
        context.l10n.calendarParserUnavailable(error.runtimeType.toString()),
      );
    }
  }

  void _applyParserResult(NlAdapterResult result) {
    final CalendarTask task = result.task;
    _lastParserResult = result;
    _isApplyingParser = true;

    if (!_scheduleLocked) {
      final DateTime? start = task.scheduledTime;
      final DateTime? end =
          task.endDate ??
          (start != null && task.duration != null
              ? start.add(task.duration!)
              : null);
      if (start != null) {
        _formController.updateStart(start);
        if (end != null) {
          _formController.updateEnd(end);
        }
      } else {
        _formController.clearSchedule();
      }
    }

    if (!_deadlineLocked) {
      _formController.setDeadline(task.deadline);
    }

    if (!_recurrenceLocked) {
      final RecurrenceFormValue value = RecurrenceFormValue.fromRule(
        task.recurrence,
      );
      _formController.setRecurrence(value);
    }

    if (!_priorityLocked) {
      final TaskPriority priority = task.priority ?? TaskPriority.none;
      _formController.setImportant(
        priority == TaskPriority.important || priority == TaskPriority.critical,
      );
      _formController.setUrgent(
        priority == TaskPriority.urgent || priority == TaskPriority.critical,
      );
    }

    if (!_remindersLocked) {
      _formController.setReminders(task.effectiveReminders);
    }

    if (!_locationLocked) {
      _setLocationField(task.location);
    }

    _isApplyingParser = false;
  }

  void _setLocationField(String? value) {
    final String next = value?.trim() ?? '';
    if (_locationController.text == next) {
      return;
    }
    final selection = TextSelection.collapsed(offset: next.length);
    _locationController.value = TextEditingValue(
      text: next,
      selection: selection,
    );
  }

  String _effectiveParserTitle(String fallback) {
    final trimmed = fallback.trim();
    if (_lastParserResult == null) return trimmed;
    if (_lastParserInput != trimmed) return trimmed;
    final parserTitle = _lastParserResult!.task.title.trim();
    return parserTitle.isEmpty ? trimmed : parserTitle;
  }

  void _clearParserState({bool clearFields = false}) {
    _parserDebounce?.cancel();
    _parserRequestId++;
    _lastParserInput = '';
    _lastParserResult = null;
    if (clearFields) {
      _clearParserDrivenFields();
      _resetParserLocks();
    }
  }

  void _clearParserDrivenFields() {
    _isApplyingParser = true;
    if (!_scheduleLocked) {
      _formController.clearSchedule();
    }
    if (!_deadlineLocked) {
      _formController.setDeadline(null);
    }
    if (!_recurrenceLocked) {
      _formController.setRecurrence(const RecurrenceFormValue());
    }
    if (!_priorityLocked) {
      _formController.setImportant(false);
      _formController.setUrgent(false);
    }
    if (!_remindersLocked) {
      _formController.setReminders(ReminderPreferences.defaults());
    }
    _formController
      ..setStatus(null)
      ..setTransparency(null)
      ..setCategories(_emptyCategories)
      ..setUrl(null)
      ..setGeo(null)
      ..setAdvancedAlarms(_emptyAdvancedAlarms)
      ..setOrganizer(null)
      ..setAttendees(_emptyAttendees);
    if (!_locationLocked && _locationController.text.isNotEmpty) {
      _locationController.clear();
    }
    _isApplyingParser = false;
  }

  void _handleLocationEdited(String value) {
    if (_isApplyingParser) {
      return;
    }
    _locationLocked = value.trim().isNotEmpty;
  }

  void _onUserStartChanged(DateTime? value) {
    _scheduleLocked = value != null || _formController.endTime != null;
    _formController.updateStart(value);
    if (value == null && _formController.endTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserEndChanged(DateTime? value) {
    _scheduleLocked = value != null || _formController.startTime != null;
    _formController.updateEnd(value);
    if (value == null && _formController.startTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserScheduleCleared() {
    _scheduleLocked = false;
    _formController.clearSchedule();
  }

  void _onUserDeadlineChanged(DateTime? value) {
    _deadlineLocked = value != null;
    _formController.setDeadline(value);
    if (value == null) {
      _deadlineLocked = false;
    }
  }

  void _onUserRecurrenceChanged(RecurrenceFormValue value) {
    _recurrenceLocked = value.isActive;
    _formController.setRecurrence(value);
    if (!value.isActive) {
      _recurrenceLocked = false;
    }
  }

  void _onUserImportantChanged(bool value) {
    _priorityLocked = true;
    _formController.setImportant(value);
  }

  void _onUserUrgentChanged(bool value) {
    _priorityLocked = true;
    _formController.setUrgent(value);
  }

  void _onRemindersChanged(ReminderPreferences value) {
    _remindersLocked = true;
    _formController.setReminders(value);
  }

  void _onAdvancedAlarmsChanged(List<CalendarAlarm> value) {
    _formController.setAdvancedAlarms(value);
  }

  void _onCategoriesChanged(List<String> value) {
    _formController.setCategories(value);
  }

  void _onUrlChanged(String? value) {
    _formController.setUrl(value);
  }

  void _onGeoChanged(CalendarGeo? value) {
    _formController.setGeo(value);
  }

  void _onOrganizerChanged(CalendarOrganizer? value) {
    _formController.setOrganizer(value);
  }

  void _onAttendeesChanged(List<CalendarAttendee> value) {
    _formController.setAttendees(value);
  }

  void _resetParserLocks() {
    _locationLocked = false;
    _scheduleLocked = false;
    _deadlineLocked = false;
    _recurrenceLocked = false;
    _priorityLocked = false;
    _remindersLocked = false;
  }

  void _applyPrefill(DateTime? prefilled) {
    _resetParserLocks();
    if (prefilled != null) {
      _scheduleLocked = true;
    }
  }

  BaseCalendarBloc? _locateCalendarBloc() {
    final resolveBloc = widget.locateCalendarBloc;
    return resolveBloc?.call();
  }

  List<CalendarCriticalPath> _queuedPaths() {
    final Map<String, CalendarCriticalPath>? byId =
        _locateCalendarBloc()?.state.model.criticalPaths;
    if (byId == null) {
      return const [];
    }
    return _queuedCriticalPathIds
        .map((id) => byId[id])
        .whereType<CalendarCriticalPath>()
        .toList();
  }

  void _addQueuedCriticalPath(String pathId) {
    if (_queuedCriticalPathIds.contains(pathId)) {
      return;
    }
    setState(() {
      _queuedCriticalPathIds.add(pathId);
    });
  }

  void _removeQueuedCriticalPath(String pathId) {
    if (!_queuedCriticalPathIds.contains(pathId)) {
      return;
    }
    setState(() {
      _queuedCriticalPathIds.removeWhere((id) => id == pathId);
    });
  }

  Future<void> _handleCalendarStateChanged(
    BuildContext context,
    CalendarState state,
  ) async {
    final l10n = context.l10n;
    if (_awaitingTaskCreation && !state.isTaskCreationSubmitting) {
      _awaitingTaskCreation = false;
      final String? error = state.taskCreationError;
      if (error != null) {
        _setFormError(error);
        return;
      }
      final String? createdTaskId = state.lastCreatedTaskId;
      if (createdTaskId == null) {
        _setFormError(l10n.calendarCriticalPathAddAfterSaveFailed);
        return;
      }
      if (_queuedCriticalPathIds.isNotEmpty) {
        setState(() => _queuedCriticalPathIds.clear());
      }
      if (state.criticalPathMutationError != null) {
        FeedbackSystem.showError(
          context,
          l10n.calendarCriticalPathAddAfterSaveFailed,
        );
      }
      await _dismissModal();
      return;
    }

    if (!state.isCriticalPathMutating) {
      if (_awaitingCriticalPathCreate) {
        _awaitingCriticalPathCreate = false;
        final String? createdPathId = state.criticalPathMutationError == null
            ? state.lastCreatedCriticalPathId
            : null;
        if (createdPathId != null) {
          _addQueuedCriticalPath(createdPathId);
        } else if (state.criticalPathMutationError != null) {
          _setFormError(l10n.calendarCriticalPathCreateFailed);
        }
        return;
      }
    }
  }

  Future<void> _queueCriticalPathForDraft() async {
    _setFormError(null);
    if (_locateCalendarBloc() == null) {
      _setFormError(context.l10n.calendarCriticalPathUnavailable);
      return;
    }
    final List<CalendarCriticalPath> paths =
        _locateCalendarBloc()?.state.model.criticalPaths.values.toList() ??
        const <CalendarCriticalPath>[];
    await showCriticalPathPicker(
      context: context,
      paths: paths,
      bloc: _locateCalendarBloc(),
      stayOpen: true,
      onPathSelected: (pickerContext, path) async {
        _addQueuedCriticalPath(path.id);
        return pickerContext.l10n.calendarCriticalPathQueuedAdd(path.name);
      },
      onCreateNewPath: (pickerContext) async {
        final String? name = await promptCriticalPathName(
          context: pickerContext,
          title: pickerContext.l10n.calendarCriticalPathsNew,
        );
        if (!mounted || !pickerContext.mounted || name == null) {
          return null;
        }
        _awaitingCriticalPathCreate = true;
        _locateCalendarBloc()?.add(
          CalendarEvent.criticalPathCreated(name: name),
        );
        return null;
      },
    );
  }

  Future<void> _submitTask() async {
    _setFormError(null);
    _checklistController.commitPendingEntry();
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _taskNameFocusNode.requestFocus();
      return;
    }

    final BaseCalendarBloc? bloc = _locateCalendarBloc();
    final List<String> queuedPathIds = List<String>.from(
      _queuedCriticalPathIds,
    );
    final bool hasQueuedPaths = queuedPathIds.isNotEmpty;
    if (hasQueuedPaths && bloc == null) {
      _setFormError(context.l10n.calendarCriticalPathUnavailable);
      return;
    }

    final taskName = _taskNameController.text.trim();
    final taskTitle = _effectiveParserTitle(taskName);
    final description = _descriptionController.text.trim();
    final scheduledTime = _formController.startTime;

    final recurrence = scheduledTime != null
        ? _formController.buildRecurrence()
        : null;

    final duration =
        _formController.effectiveDuration ??
        (scheduledTime != null ? calendarDefaultTaskDuration : null);
    final List<String>? categories = resolveCategoryOverride(
      base: null,
      categories: _formController.categories,
    );
    final CalendarOrganizer? organizer = resolveOrganizerOverride(
      base: null,
      organizer: _formController.organizer,
    );
    final List<CalendarAttendee>? attendees = resolveAttendeeOverride(
      base: null,
      attendees: _formController.attendees,
    );
    final List<CalendarAlarm> mergedAlarms = mergeAdvancedAlarms(
      advancedAlarms: _formController.advancedAlarms,
      reminders: _formController.reminders,
    );
    final List<CalendarAlarm>? alarms = resolveAlarmOverride(
      base: null,
      alarms: mergedAlarms,
    );
    final CalendarIcsMeta? icsMeta = applyIcsMetaOverrides(
      base: null,
      status: _formController.status,
      transparency: _formController.transparency,
      categories: categories,
      url: _formController.url,
      geo: _formController.geo,
      organizer: organizer,
      attendees: attendees,
      alarms: alarms,
    );

    final task = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: taskTitle,
      description: description.isNotEmpty ? description : null,
      scheduledTime: scheduledTime,
      duration: duration,
      priority: _formController.selectedPriority,
      isCompleted: false,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      deadline: _formController.deadline,
      recurrence: recurrence,
      startHour: null,
      checklist: _checklistController.items.toList(),
      reminders: _formController.reminders.normalized(),
      icsMeta: icsMeta,
    );

    _awaitingTaskCreation = true;
    widget.onTaskAdded(task, queuedPathIds);
    if (bloc == null) {
      await _dismissModal();
    }
  }

  Future<void> _dismissModal() async {
    if (!mounted) {
      return;
    }

    widget.onDismiss?.call();

    if (!mounted) {
      return;
    }
    final navigator = Navigator.maybeOf(context);
    final route = ModalRoute.of(context);
    if (navigator == null || !navigator.canPop()) {
      return;
    }
    if (route is! PopupRoute<dynamic> || !route.isCurrent) {
      return;
    }
    navigator.pop();
  }

  void _requestDismiss() {
    if (widget.surface == QuickAddModalSurface.bottomSheet) {
      closeSheetWithKeyboardDismiss(context, widget.onDismiss ?? () {});
      return;
    }
    unawaited(_dismissModal());
  }

  void _setFormError(String? message) {
    if (_formError == message) {
      return;
    }
    setState(() {
      _formError = message;
    });
  }
}

class _QuickAddModalShell extends StatelessWidget {
  const _QuickAddModalShell({
    required this.formKey,
    required this.bloc,
    required this.onCalendarStateChanged,
    required this.contentBuilder,
  });

  final GlobalKey<ShadFormState> formKey;
  final BaseCalendarBloc? bloc;
  final void Function(BuildContext context, CalendarState state)
  onCalendarStateChanged;
  final Widget Function(BuildContext context, bool isSubmitting) contentBuilder;

  @override
  Widget build(BuildContext context) {
    final BaseCalendarBloc? calendarBloc = bloc;
    return SafeArea(
      top: false,
      bottom: false,
      child: ShadForm(
        key: formKey,
        autovalidateMode: ShadAutovalidateMode.disabled,
        fieldIdSeparator: null,
        child: calendarBloc == null
            ? contentBuilder(context, false)
            : BlocConsumer<BaseCalendarBloc, CalendarState>(
                bloc: calendarBloc,
                listenWhen: (previous, current) =>
                    previous.isTaskCreationSubmitting !=
                        current.isTaskCreationSubmitting ||
                    previous.isCriticalPathMutating !=
                        current.isCriticalPathMutating,
                listener: onCalendarStateChanged,
                builder: (context, state) =>
                    contentBuilder(context, state.isTaskCreationSubmitting),
              ),
      ),
    );
  }
}

class _QuickAddModalContent extends StatelessWidget {
  const _QuickAddModalContent({
    required this.isSheet,
    required this.formController,
    required this.isSubmitting,
    required this.taskNameController,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.taskNameFocusNode,
    required this.locationHelper,
    required this.onTaskNameChanged,
    required this.onTaskSubmit,
    required this.onClose,
    required this.onCancel,
    required this.onLocationChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onScheduleCleared,
    required this.onDeadlineChanged,
    required this.onRecurrenceChanged,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.onRemindersChanged,
    required this.onAdvancedAlarmsChanged,
    required this.onCategoriesChanged,
    required this.onUrlChanged,
    required this.onGeoChanged,
    required this.onOrganizerChanged,
    required this.onAttendeesChanged,
    required this.fallbackDate,
    required this.onAddToCriticalPath,
    required this.queuedPaths,
    required this.onRemoveQueuedPath,
    required this.hasCalendarBloc,
    required this.formError,
    required this.titleValidator,
    required this.titleAutovalidateMode,
  });

  final bool isSheet;
  final TaskDraftController formController;
  final bool isSubmitting;
  final TextEditingController taskNameController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final FocusNode taskNameFocusNode;
  final LocationAutocompleteHelper locationHelper;
  final ValueChanged<String> onTaskNameChanged;
  final VoidCallback onTaskSubmit;
  final VoidCallback onClose;
  final VoidCallback onCancel;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onScheduleCleared;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final ValueChanged<List<CalendarAlarm>> onAdvancedAlarmsChanged;
  final ValueChanged<List<String>> onCategoriesChanged;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<CalendarGeo?> onGeoChanged;
  final ValueChanged<CalendarOrganizer?> onOrganizerChanged;
  final ValueChanged<List<CalendarAttendee>> onAttendeesChanged;
  final DateTime? fallbackDate;
  final Future<void> Function() onAddToCriticalPath;
  final List<CalendarCriticalPath> queuedPaths;
  final ValueChanged<String> onRemoveQueuedPath;
  final bool hasCalendarBloc;
  final String? formError;
  final FormFieldValidator<String> titleValidator;
  final AutovalidateMode titleAutovalidateMode;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final Widget header = AxiSheetHeader(
      title: Text(context.l10n.calendarAddTaskTitle),
      onClose: onClose,
    );
    final Widget actions = ValueListenableBuilder<TextEditingValue>(
      valueListenable: taskNameController,
      builder: (context, value, _) {
        final bool canSubmit = titleValidator(value.text) == null;
        return _QuickAddActions(
          isSubmitting: isSubmitting,
          onCancel: onCancel,
          onSubmit: onTaskSubmit,
          canSubmit: canSubmit,
        );
      },
    );

    return AxiSheetScaffold.sections(
      header: header,
      footer: actions,
      sections: [
        AxiSheetSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: baseAnimationDuration,
                child: formError == null
                    ? const SizedBox.shrink()
                    : Container(
                        key: const ValueKey('quick-add-error'),
                        margin: EdgeInsets.only(bottom: spacing.s),
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.m,
                          vertical: spacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: calendarDangerColor.withValues(
                            alpha: context.motion.tapHoverAlpha,
                          ),
                          borderRadius: context.radius,
                          border: Border.fromBorderSide(
                            context.borderSide.copyWith(
                              color: calendarDangerColor.withValues(
                                alpha: context.motion.tapFocusAlpha,
                              ),
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: calendarDangerColor,
                              size: context.sizing.menuItemIconSize,
                            ),
                            SizedBox(width: spacing.xxs),
                            Expanded(
                              child: Text(
                                formError!,
                                style: context.textTheme.label.strong.copyWith(
                                  color: calendarDangerColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
              _QuickAddTaskNameField(
                controller: taskNameController,
                focusNode: taskNameFocusNode,
                helper: locationHelper,
                validator: titleValidator,
                autovalidateMode: titleAutovalidateMode,
                onChanged: onTaskNameChanged,
                onSubmit: onTaskSubmit,
              ),
              SizedBox(height: spacing.m),
              _QuickAddPriorityToggles(
                formController: formController,
                onImportantChanged: onImportantChanged,
                onUrgentChanged: onUrgentChanged,
              ),
              SizedBox(height: spacing.m),
              _QuickAddDescriptionField(controller: descriptionController),
              SizedBox(height: spacing.m),
              _QuickAddLocationField(
                controller: locationController,
                helper: locationHelper,
                onChanged: onLocationChanged,
              ),
            ],
          ),
        ),
        AxiSheetSection(
          child: TaskChecklist(
            controller: checklistController,
            showDivider: false,
          ),
        ),
        AxiSheetSection(
          child: _QuickAddScheduleSection(
            formController: formController,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
            onClear: onScheduleCleared,
          ),
        ),
        AxiSheetSection(
          child: _QuickAddDeadlineSection(
            formController: formController,
            onChanged: onDeadlineChanged,
          ),
        ),
        AxiSheetSection(
          child: AnimatedBuilder(
            animation: formController,
            builder: (context, _) {
              return TaskReminderRepeatSection(
                reminders: formController.reminders,
                onRemindersChanged: onRemindersChanged,
                recurrence: formController.recurrence,
                onRecurrenceChanged: onRecurrenceChanged,
                deadline: formController.deadline,
                advancedAlarms: formController.advancedAlarms,
                onAdvancedAlarmsChanged: onAdvancedAlarmsChanged,
                referenceStart: formController.startTime,
                fallbackWeekday:
                    formController.startTime?.weekday ??
                    fallbackDate?.weekday ??
                    DateTime.now().weekday,
                recurrenceChipSpacing: spacing.s,
                recurrenceChipRunSpacing: spacing.s,
                recurrenceWeekdaySpacing: spacing.s,
                recurrenceAdvancedSectionSpacing: spacing.m,
                recurrenceEndSpacing: spacing.m,
                recurrenceFieldGap: spacing.m,
              );
            },
          ),
        ),
        AxiSheetSection(
          child: AnimatedBuilder(
            animation: formController,
            builder: (context, _) {
              return CalendarCategoriesField(
                categories: formController.categories,
                onChanged: onCategoriesChanged,
                surfaceColor: context.colorScheme.card,
              );
            },
          ),
        ),
        AxiSheetSection(
          child: AnimatedBuilder(
            animation: formController,
            builder: (context, _) {
              return CalendarLinkGeoFields(
                url: formController.url,
                geo: formController.geo,
                onUrlChanged: onUrlChanged,
                onGeoChanged: onGeoChanged,
              );
            },
          ),
        ),
        AxiSheetSection(
          child: AnimatedBuilder(
            animation: formController,
            builder: (context, _) {
              return CalendarParticipantsField(
                organizer: formController.organizer,
                attendees: formController.attendees,
                onOrganizerChanged: onOrganizerChanged,
                onAttendeesChanged: onAttendeesChanged,
              );
            },
          ),
        ),
        AxiSheetSection(
          child: CriticalPathMembershipControls(
            addButton: TaskSecondaryButton(
              label: context.l10n.calendarAddToCriticalPath,
              icon: Icons.route,
              onPressed: isSubmitting || !hasCalendarBloc
                  ? null
                  : onAddToCriticalPath,
            ),
            paths: queuedPaths,
            onRemovePath: onRemoveQueuedPath,
          ),
        ),
      ],
    );
  }
}

class _QuickAddTaskNameField extends StatelessWidget {
  const _QuickAddTaskNameField({
    required this.controller,
    required this.focusNode,
    required this.helper,
    required this.validator,
    required this.autovalidateMode,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LocationAutocompleteHelper helper;
  final FormFieldValidator<String> validator;
  final AutovalidateMode autovalidateMode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final padding = EdgeInsets.symmetric(
      horizontal: context.spacing.m,
      vertical: context.spacing.s,
    );
    final field = Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          onSubmit();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TaskTitleField(
        controller: controller,
        focusNode: focusNode,
        autofocus: false,
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: autovalidateMode,
        onSubmitted: onSubmit,
        hintText: l10n.calendarTaskNameHint,
        textInputAction: TextInputAction.done,
      ),
    );

    final suggestionField = LocationInlineSuggestion(
      controller: controller,
      helper: helper,
      contentPadding: padding,
      child: field,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        suggestionField,
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _QuickAddDescriptionField extends StatelessWidget {
  const _QuickAddDescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TaskDescriptionField(
      controller: controller,
      hintText: l10n.calendarDescriptionHint,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _QuickAddLocationField extends StatelessWidget {
  const _QuickAddLocationField({
    required this.controller,
    required this.helper,
    required this.onChanged,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper helper;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TaskLocationField(
      controller: controller,
      hintText: l10n.calendarLocationHint,
      textCapitalization: TextCapitalization.words,
      onChanged: onChanged,
      autocomplete: helper,
    );
  }
}

class _QuickAddPriorityToggles extends StatelessWidget {
  const _QuickAddPriorityToggles({
    required this.formController,
    required this.onImportantChanged,
    required this.onUrgentChanged,
  });

  final TaskDraftController formController;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: formController,
      builder: (context, _) {
        return TaskPriorityToggles(
          isImportant: formController.isImportant,
          isUrgent: formController.isUrgent,
          spacing: context.spacing.s,
          onImportantChanged: onImportantChanged,
          onUrgentChanged: onUrgentChanged,
        );
      },
    );
  }
}

class _QuickAddScheduleSection extends StatelessWidget {
  const _QuickAddScheduleSection({
    required this.formController,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onClear,
  });

  final TaskDraftController formController;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: formController,
      builder: (context, _) {
        return TaskScheduleSection(
          title: l10n.calendarScheduleLabel,
          headerSize: TaskSectionLabelSize.medium,
          spacing: context.spacing.s,
          start: formController.startTime,
          end: formController.endTime,
          onStartChanged: onStartChanged,
          onEndChanged: onEndChanged,
          onClear: onClear,
        );
      },
    );
  }
}

class _QuickAddDeadlineSection extends StatelessWidget {
  const _QuickAddDeadlineSection({
    required this.formController,
    required this.onChanged,
  });

  final TaskDraftController formController;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: formController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskSectionHeader(
              title: l10n.calendarDeadlineLabel,
              size: TaskSectionLabelSize.medium,
            ),
            SizedBox(height: context.spacing.s),
            CalendarDateTimeField(
              value: formController.deadline,
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }
}

class _QuickAddActions extends StatelessWidget {
  const _QuickAddActions({
    required this.isSubmitting,
    required this.onCancel,
    required this.onSubmit,
    required this.canSubmit,
  });

  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool disabled = isSubmitting || !canSubmit;
    return AxiSheetActions(
      gap: context.spacing.m,
      children: [
        Expanded(
          child: TaskSecondaryButton(
            label: l10n.calendarCancel,
            onPressed: isSubmitting ? null : onCancel,
            widthBehavior: AxiButtonWidth.expand,
          ),
        ),
        Expanded(
          child: TaskPrimaryButton(
            label: l10n.commonAdd,
            onPressed: disabled ? null : onSubmit,
            isBusy: isSubmitting,
            widthBehavior: AxiButtonWidth.expand,
            showEnterKeyIndicator: true,
          ),
        ),
      ],
    );
  }
}

// Helper function to show the modal
Future<void> showQuickAddModal({
  required BuildContext context,
  DateTime? prefilledDateTime,
  String? prefilledText,
  required void Function(CalendarTask task, List<String> queuedCriticalPathIds)
  onTaskAdded,
  required LocationAutocompleteHelper locationHelper,
  String? initialValidationMessage,
  BaseCalendarBloc? Function()? locateCalendarBloc,
}) {
  final commandSurface = resolveCommandSurface(context);
  final bool useSheet = commandSurface == CommandSurface.sheet;
  final surface = useSheet
      ? QuickAddModalSurface.bottomSheet
      : QuickAddModalSurface.dialog;
  final responsive = ResponsiveHelper.spec(context);
  final BuildContext modalContext = context.calendarModalContext;
  return showAdaptiveBottomSheet<void>(
    context: modalContext,
    isScrollControlled: true,
    showDragHandle: useSheet,
    isDismissible: true,
    useBottomSafeArea: context.calendarUseSheetBottomSafeArea,
    surfacePadding: EdgeInsets.zero,
    dialogMaxWidth:
        responsive.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth,
    showCloseButton: false,
    useRootNavigator: _calendarUseRootNavigator,
    builder: (sheetContext) {
      return QuickAddModal(
        surface: surface,
        prefilledDateTime: prefilledDateTime,
        prefilledText: prefilledText,
        onTaskAdded: onTaskAdded,
        locationHelper: locationHelper,
        initialValidationMessage: initialValidationMessage,
        locateCalendarBloc: locateCalendarBloc,
        onDismiss: () {
          if (Navigator.of(sheetContext).canPop()) {
            Navigator.of(sheetContext).maybePop();
          }
        },
      );
    },
  );
}
