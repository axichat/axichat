import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/utils/calendar_ics_meta_utils.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'controllers/quick_add_controller.dart';
import 'controllers/task_checklist_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/location_inline_suggestion.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/recurrence_spacing_tokens.dart';
import 'widgets/task_field_character_hint.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_checklist.dart';
import 'widgets/calendar_categories_field.dart';
import 'widgets/calendar_link_geo_fields.dart';
import 'widgets/ics_meta_fields.dart';
import 'widgets/reminder_preferences_field.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'widgets/critical_path_panel.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';

const List<String> _emptyCategories = <String>[];

enum QuickAddModalSurface { dialog, bottomSheet }

class QuickAddModal extends StatefulWidget {
  final DateTime? prefilledDateTime;
  final String? prefilledText;
  final VoidCallback? onDismiss;
  final void Function(CalendarTask task) onTaskAdded;
  final QuickAddModalSurface surface;
  final LocationAutocompleteHelper locationHelper;
  final String? initialValidationMessage;
  final bool hasCalendarBloc;
  final BaseCalendarBloc? calendarBloc;

  const QuickAddModal({
    super.key,
    this.prefilledDateTime,
    this.prefilledText,
    this.onDismiss,
    required this.onTaskAdded,
    this.surface = QuickAddModalSurface.dialog,
    required this.locationHelper,
    this.initialValidationMessage,
    this.hasCalendarBloc = false,
    this.calendarBloc,
  });

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late final TaskChecklistController _checklistController;
  final _taskNameFocusNode = FocusNode();
  final List<String> _queuedCriticalPathIds = <String>[];
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  String? _initialTitleValidationMessage;

  late final QuickAddController _formController;
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

  @override
  void initState() {
    super.initState();
    _initialTitleValidationMessage = widget.initialValidationMessage;
    _checklistController = TaskChecklistController();

    _animationController = AnimationController(
      duration: baseAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    if (widget.surface == QuickAddModalSurface.dialog) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }

    final prefilled = widget.prefilledDateTime;

    _formController = QuickAddController(
      initialStart: prefilled,
      initialEnd: prefilled?.add(const Duration(hours: 1)),
    );
    _parserService = NlScheduleParserService();
    _resetParserLocks();
    if (prefilled != null) {
      _scheduleLocked = true;
    }

    final seededText = widget.prefilledText?.trim();
    if (seededText != null && seededText.isNotEmpty) {
      _taskNameController.value = TextEditingValue(
        text: seededText,
        selection: TextSelection.collapsed(offset: seededText.length),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _handleTaskNameChanged(seededText);
      });
    }
  }

  @override
  void dispose() {
    _parserDebounce?.cancel();
    _animationController.dispose();
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
    if (widget.surface == QuickAddModalSurface.bottomSheet) {
      return SafeArea(
        top: true,
        bottom: false,
        child: Form(
          key: _formKey,
          child: _QuickAddModalContent(
            isSheet: true,
            formController: _formController,
            taskNameController: _taskNameController,
            descriptionController: _descriptionController,
            locationController: _locationController,
            checklistController: _checklistController,
            taskNameFocusNode: _taskNameFocusNode,
            locationHelper: widget.locationHelper,
            onTaskNameChanged: _handleTaskNameChanged,
            onTaskSubmit: () {
              _submitTask();
            },
            onClose: _dismissModal,
            onLocationChanged: _handleLocationEdited,
            onStartChanged: _onUserStartChanged,
            onEndChanged: _onUserEndChanged,
            onScheduleCleared: _onUserScheduleCleared,
            onDeadlineChanged: _onUserDeadlineChanged,
            onRecurrenceChanged: _onUserRecurrenceChanged,
            onImportantChanged: _onUserImportantChanged,
            onUrgentChanged: _onUserUrgentChanged,
            onRemindersChanged: _onRemindersChanged,
            onStatusChanged: _onStatusChanged,
            onTransparencyChanged: _onTransparencyChanged,
            onCategoriesChanged: _onCategoriesChanged,
            onUrlChanged: _onUrlChanged,
            onGeoChanged: _onGeoChanged,
            actionInsetBuilder: _quickAddActionInset,
            fallbackDate: widget.prefilledDateTime,
            onAddToCriticalPath: _queueCriticalPathForDraft,
            queuedPaths: _queuedPaths(),
            onRemoveQueuedPath: _removeQueuedCriticalPath,
            hasCalendarBloc: widget.hasCalendarBloc,
            formError: _formError,
            titleValidator: _validateTaskTitle,
            titleAutovalidateMode: _titleAutovalidateMode,
          ),
        ),
      );
    }
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Center(
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: Form(
            key: _formKey,
            child: _QuickAddModalContent(
              isSheet: false,
              formController: _formController,
              taskNameController: _taskNameController,
              descriptionController: _descriptionController,
              locationController: _locationController,
              checklistController: _checklistController,
              taskNameFocusNode: _taskNameFocusNode,
              locationHelper: widget.locationHelper,
              onTaskNameChanged: _handleTaskNameChanged,
              onTaskSubmit: () {
                _submitTask();
              },
              onClose: _dismissModal,
              onLocationChanged: _handleLocationEdited,
              onStartChanged: _onUserStartChanged,
              onEndChanged: _onUserEndChanged,
              onScheduleCleared: _onUserScheduleCleared,
              onDeadlineChanged: _onUserDeadlineChanged,
              onRecurrenceChanged: _onUserRecurrenceChanged,
              onImportantChanged: _onUserImportantChanged,
              onUrgentChanged: _onUserUrgentChanged,
              onRemindersChanged: _onRemindersChanged,
              onStatusChanged: _onStatusChanged,
              onTransparencyChanged: _onTransparencyChanged,
              onCategoriesChanged: _onCategoriesChanged,
              onUrlChanged: _onUrlChanged,
              onGeoChanged: _onGeoChanged,
              actionInsetBuilder: _quickAddActionInset,
              fallbackDate: widget.prefilledDateTime,
              onAddToCriticalPath: _queueCriticalPathForDraft,
              queuedPaths: _queuedPaths(),
              onRemoveQueuedPath: _removeQueuedCriticalPath,
              hasCalendarBloc: widget.hasCalendarBloc,
              formError: _formError,
              titleValidator: _validateTaskTitle,
              titleAutovalidateMode: _titleAutovalidateMode,
            ),
          ),
        ),
      ),
    );
  }

  double _quickAddActionInset(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double safeBottom = mediaQuery.viewPadding.bottom;
    if (keyboardInset <= safeBottom) {
      return 0;
    }
    final double inset =
        keyboardInset > safeBottom ? keyboardInset - safeBottom : 0;
    return calendarGutterSm + inset;
  }

  AutovalidateMode get _titleAutovalidateMode => AutovalidateMode.disabled;

  String? _validateTaskTitle(String? raw) {
    return _initialTitleValidationMessage ??
        TaskTitleValidation.validate(raw ?? '');
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
    final trimmed = value.trim();
    _parserDebounce?.cancel();
    if (trimmed.isEmpty) {
      _clearParserState(clearFields: true);
      return;
    }
    if (trimmed == _lastParserInput) {
      return;
    }
    _parserDebounce = Timer(const Duration(milliseconds: 350), () {
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
      final DateTime? end = task.endDate ??
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
      final RecurrenceFormValue value =
          RecurrenceFormValue.fromRule(task.recurrence);
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
      ..setGeo(null);
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

  void _onStatusChanged(CalendarIcsStatus? value) {
    _formController.setStatus(value);
  }

  void _onTransparencyChanged(CalendarTransparency? value) {
    _formController.setTransparency(value);
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

  void _resetParserLocks() {
    _locationLocked = false;
    _scheduleLocked = false;
    _deadlineLocked = false;
    _recurrenceLocked = false;
    _priorityLocked = false;
    _remindersLocked = false;
  }

  List<CalendarCriticalPath> _queuedPaths() {
    final BaseCalendarBloc? bloc = widget.calendarBloc;
    if (bloc == null) {
      return const [];
    }
    final Map<String, CalendarCriticalPath> byId =
        bloc.state.model.criticalPaths;
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

  Future<void> _queueCriticalPathForDraft() async {
    _setFormError(null);
    final BaseCalendarBloc? bloc = widget.calendarBloc;
    if (bloc == null) {
      _setFormError('Critical paths are unavailable in this view.');
      return;
    }
    await showCriticalPathPicker(
      context: context,
      paths: bloc.state.model.criticalPaths.values.toList(),
      stayOpen: true,
      onPathSelected: (path) async {
        _addQueuedCriticalPath(path.id);
        return 'Will add to "${path.name}" on save';
      },
      onCreateNewPath: () async {
        final String? name = await promptCriticalPathName(
          context: context,
          title: 'New critical path',
        );
        if (!mounted || name == null) {
          return null;
        }
        final Set<String> previousIds =
            bloc.state.model.criticalPaths.keys.toSet();
        bloc.add(CalendarEvent.criticalPathCreated(name: name));
        final String? createdId = await waitForNewPathId(
          bloc: bloc,
          previousIds: previousIds,
        );
        if (!mounted || createdId == null) {
          return null;
        }
        _addQueuedCriticalPath(createdId);
        return 'Created "$name" and queued';
      },
    );
  }

  Future<void> _submitTask() async {
    if (_formController.isSubmitting) {
      return;
    }

    _setFormError(null);
    final bool isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      _taskNameFocusNode.requestFocus();
      return;
    }

    _formController.setSubmitting(true);
    final BaseCalendarBloc? calendarBloc = widget.calendarBloc;
    final List<String> queuedPathIds =
        List<String>.from(_queuedCriticalPathIds);
    final bool hasQueuedPaths = queuedPathIds.isNotEmpty;
    final Set<String>? previousIds =
        hasQueuedPaths ? calendarBloc?.state.model.tasks.keys.toSet() : null;
    if (hasQueuedPaths && calendarBloc == null) {
      _formController.setSubmitting(false);
      _setFormError('Critical paths are unavailable in this view.');
      return;
    }

    final taskName = _taskNameController.text.trim();
    final taskTitle = _effectiveParserTitle(taskName);
    final description = _descriptionController.text.trim();
    final scheduledTime = _formController.startTime;

    final recurrence =
        scheduledTime != null ? _formController.buildRecurrence() : null;

    final duration = _formController.effectiveDuration ??
        (scheduledTime != null ? const Duration(hours: 1) : null);
    final List<String>? categories = resolveCategoryOverride(
      base: null,
      categories: _formController.categories,
    );
    final CalendarIcsMeta? icsMeta = applyIcsMetaOverrides(
      base: null,
      status: _formController.status,
      transparency: _formController.transparency,
      categories: categories,
      url: _formController.url,
      geo: _formController.geo,
    );

    // Create the task
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

    widget.onTaskAdded(task);

    if (hasQueuedPaths && calendarBloc != null && previousIds != null) {
      final CalendarTask? createdTask =
          await _waitForNewTask(calendarBloc, previousIds);
      if (!mounted) {
        return;
      }
      if (createdTask != null) {
        for (final String pathId in queuedPathIds) {
          calendarBloc.add(
            CalendarEvent.criticalPathTaskAdded(
              pathId: pathId,
              taskId: createdTask.id,
            ),
          );
        }
      } else {
        _setFormError(
          'Task saved but could not be added to a critical path.',
        );
      }
    }

    if (hasQueuedPaths) {
      setState(() {
        _queuedCriticalPathIds.clear();
      });
    }

    if (!mounted) return;
    await _dismissModal();
  }

  Future<CalendarTask?> _waitForNewTask(
    BaseCalendarBloc bloc,
    Set<String> previousIds,
  ) async {
    try {
      final Set<String> difference = (await bloc.stream
              .firstWhere(
                (state) => state.model.tasks.length > previousIds.length,
              )
              .timeout(const Duration(seconds: 2)))
          .model
          .tasks
          .keys
          .toSet()
          .difference(previousIds);
      if (difference.isEmpty) {
        return null;
      }
      final String taskId = difference.first;
      if (!mounted) {
        return null;
      }
      return bloc.state.model.tasks[taskId];
    } on TimeoutException {
      return null;
    }
  }

  Future<void> _dismissModal() async {
    Future<void> popSelfIfPossible() async {
      if (!mounted) {
        return;
      }
      final navigator = Navigator.maybeOf(context);
      if (navigator == null) {
        return;
      }
      await navigator.maybePop();
    }

    if (widget.surface == QuickAddModalSurface.dialog) {
      await _animationController.reverse();
    }

    if (!mounted) {
      return;
    }

    widget.onDismiss?.call();

    if (!mounted) {
      return;
    }

    await popSelfIfPossible();
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

class _QuickAddModalContent extends StatelessWidget {
  const _QuickAddModalContent({
    required this.isSheet,
    required this.formController,
    required this.taskNameController,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.taskNameFocusNode,
    required this.locationHelper,
    required this.onTaskNameChanged,
    required this.onTaskSubmit,
    required this.onClose,
    required this.onLocationChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onScheduleCleared,
    required this.onDeadlineChanged,
    required this.onRecurrenceChanged,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.onRemindersChanged,
    required this.onStatusChanged,
    required this.onTransparencyChanged,
    required this.onCategoriesChanged,
    required this.onUrlChanged,
    required this.onGeoChanged,
    required this.actionInsetBuilder,
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
  final QuickAddController formController;
  final TextEditingController taskNameController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final FocusNode taskNameFocusNode;
  final LocationAutocompleteHelper locationHelper;
  final ValueChanged<String> onTaskNameChanged;
  final VoidCallback onTaskSubmit;
  final VoidCallback onClose;
  final ValueChanged<String> onLocationChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onScheduleCleared;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final ValueChanged<CalendarIcsStatus?> onStatusChanged;
  final ValueChanged<CalendarTransparency?> onTransparencyChanged;
  final ValueChanged<List<String>> onCategoriesChanged;
  final ValueChanged<String?> onUrlChanged;
  final ValueChanged<CalendarGeo?> onGeoChanged;
  final double Function(BuildContext context) actionInsetBuilder;
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
    final responsive = ResponsiveHelper.spec(context);
    final double maxWidth =
        responsive.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;
    final mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double safeBottom = mediaQuery.viewPadding.bottom;
    final bool keyboardOpen = isSheet && keyboardInset > safeBottom;
    final EdgeInsets contentPadding =
        responsive.contentPadding.resolve(Directionality.of(context));
    final EdgeInsets scrollPadding = isSheet
        ? contentPadding.copyWith(
            bottom: contentPadding.bottom + keyboardInset,
          )
        : contentPadding;
    final BorderRadius borderRadius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(calendarBorderRadius);
    final Color background = isSheet
        ? Theme.of(context).colorScheme.surface
        : calendarContainerColor;
    final List<BoxShadow>? boxShadow = isSheet ? null : calendarMediumShadow;
    final Widget actions = ValueListenableBuilder<TextEditingValue>(
      valueListenable: taskNameController,
      builder: (context, value, _) {
        final bool canSubmit = titleValidator(value.text) == null;
        return _QuickAddActions(
          formController: formController,
          onCancel: onClose,
          onSubmit: onTaskSubmit,
          canSubmit: canSubmit,
        );
      },
    );

    Widget shell = LayoutBuilder(
      builder: (context, constraints) {
        final double resolvedMaxHeight = isSheet && constraints.hasBoundedHeight
            ? constraints.maxHeight
            : responsive.quickAddMaxHeight;
        return Container(
          margin: isSheet ? EdgeInsets.zero : responsive.modalMargin,
          constraints: BoxConstraints(
            maxWidth: isSheet ? double.infinity : maxWidth,
            maxHeight: resolvedMaxHeight,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: borderRadius,
            boxShadow: boxShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: borderRadius,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _QuickAddHeader(onClose: onClose),
                Flexible(
                  child: SingleChildScrollView(
                    padding: scrollPadding,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: baseAnimationDuration,
                          child: formError == null
                              ? const SizedBox.shrink()
                              : Container(
                                  key: const ValueKey('quick-add-error'),
                                  margin: const EdgeInsets.only(
                                      bottom: calendarGutterSm),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: calendarGutterMd,
                                    vertical: calendarInsetMd,
                                  ),
                                  decoration: BoxDecoration(
                                    color: calendarDangerColor.withValues(
                                        alpha: 0.08),
                                    borderRadius: BorderRadius.circular(
                                      calendarBorderRadius,
                                    ),
                                    border: Border.all(
                                      color: calendarDangerColor.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: calendarDangerColor,
                                        size: 18,
                                      ),
                                      const SizedBox(width: calendarInsetSm),
                                      Expanded(
                                        child: Text(
                                          formError!,
                                          style: TextStyle(
                                            color: calendarDangerColor,
                                            fontWeight: FontWeight.w600,
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
                        const SizedBox(height: calendarGutterMd),
                        _QuickAddDescriptionField(
                          controller: descriptionController,
                        ),
                        const SizedBox(height: calendarGutterMd),
                        _QuickAddLocationField(
                          controller: locationController,
                          helper: locationHelper,
                          onChanged: onLocationChanged,
                        ),
                        const SizedBox(height: calendarGutterMd),
                        _QuickAddPriorityToggles(
                          formController: formController,
                          onImportantChanged: onImportantChanged,
                          onUrgentChanged: onUrgentChanged,
                        ),
                        const SizedBox(height: calendarGutterMd),
                        TaskChecklist(controller: checklistController),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        _QuickAddScheduleSection(
                          formController: formController,
                          onStartChanged: onStartChanged,
                          onEndChanged: onEndChanged,
                          onClear: onScheduleCleared,
                        ),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        _QuickAddDeadlineSection(
                          formController: formController,
                          onChanged: onDeadlineChanged,
                        ),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        AnimatedBuilder(
                          animation: formController,
                          builder: (context, _) {
                            return _QuickAddReminderSection(
                              reminders: formController.reminders,
                              deadline: formController.deadline,
                              onChanged: onRemindersChanged,
                            );
                          },
                        ),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        AnimatedBuilder(
                          animation: formController,
                          builder: (context, _) {
                            return CalendarIcsMetaFields(
                              status: formController.status,
                              transparency: formController.transparency,
                              onStatusChanged: onStatusChanged,
                              onTransparencyChanged: onTransparencyChanged,
                            );
                          },
                        ),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        AnimatedBuilder(
                          animation: formController,
                          builder: (context, _) {
                            return CalendarCategoriesField(
                              categories: formController.categories,
                              onChanged: onCategoriesChanged,
                            );
                          },
                        ),
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        AnimatedBuilder(
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
                        const TaskSectionDivider(
                          verticalPadding: calendarGutterMd,
                        ),
                        _QuickAddRecurrenceSection(
                          formController: formController,
                          onChanged: onRecurrenceChanged,
                          fallbackDate: fallbackDate,
                        ),
                        const SizedBox(height: calendarGutterMd),
                        TaskSecondaryButton(
                          label: 'Add to critical path',
                          icon: Icons.route,
                          onPressed:
                              formController.isSubmitting || !hasCalendarBloc
                                  ? null
                                  : onAddToCriticalPath,
                        ),
                        const SizedBox(height: calendarInsetSm),
                        CriticalPathMembershipList(
                          paths: queuedPaths,
                          onRemovePath: onRemoveQueuedPath,
                        ),
                        if (keyboardOpen) ...[
                          const SizedBox(height: calendarGutterMd),
                          actions,
                        ],
                      ],
                    ),
                  ),
                ),
                if (!keyboardOpen)
                  AnimatedPadding(
                    duration: baseAnimationDuration,
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.only(
                      bottom: actionInsetBuilder(context),
                    ),
                    child: SafeArea(
                      top: false,
                      bottom: true,
                      child: actions,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
    if (isSheet) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: shell,
      );
    }
    return shell;
  }
}

class _QuickAddHeader extends StatelessWidget {
  const _QuickAddHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterLg,
        vertical: calendarGutterMd,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.add_task,
            color: calendarTitleColor,
            size: 20,
          ),
          const SizedBox(width: calendarGutterSm),
          Text(
            l10n.calendarAddTaskTitle,
            style: calendarTitleTextStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: calendarSubtitleColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
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
    const padding = calendarFieldPadding;
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
        autofocus: true,
        onChanged: onChanged,
        validator: validator,
        autovalidateMode: autovalidateMode,
        onSubmitted: onSubmit,
        labelText: l10n.calendarTaskNameRequired,
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
  const _QuickAddDescriptionField({
    required this.controller,
  });

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
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.words,
      contentPadding: calendarFieldPadding,
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

  final QuickAddController formController;
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
          spacing: 10,
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

  final QuickAddController formController;
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
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarGutterSm,
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

  final QuickAddController formController;
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
              textStyle: calendarSubtitleTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: calendarGutterSm),
            DeadlinePickerField(
              value: formController.deadline,
              onChanged: onChanged,
            ),
          ],
        );
      },
    );
  }
}

class _QuickAddReminderSection extends StatelessWidget {
  const _QuickAddReminderSection({
    required this.reminders,
    required this.deadline,
    required this.onChanged,
  });

  final ReminderPreferences reminders;
  final DateTime? deadline;
  final ValueChanged<ReminderPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReminderPreferencesField(
      value: reminders,
      onChanged: onChanged,
      title: context.l10n.calendarRemindersSection,
      anchor: deadline == null ? ReminderAnchor.start : ReminderAnchor.deadline,
      showBothAnchors: deadline != null,
    );
  }
}

class _QuickAddRecurrenceSection extends StatelessWidget {
  const _QuickAddRecurrenceSection({
    required this.formController,
    required this.onChanged,
    required this.fallbackDate,
  });

  final QuickAddController formController;
  final ValueChanged<RecurrenceFormValue> onChanged;
  final DateTime? fallbackDate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: formController,
      builder: (context, _) {
        final fallbackWeekday = formController.startTime?.weekday ??
            fallbackDate?.weekday ??
            DateTime.now().weekday;
        return TaskRecurrenceSection(
          title: l10n.calendarRepeatLabel,
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarGutterSm,
          value: formController.recurrence,
          fallbackWeekday: fallbackWeekday,
          spacingConfig: calendarRecurrenceSpacingCompact,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _QuickAddActions extends StatelessWidget {
  const _QuickAddActions({
    required this.formController,
    required this.onCancel,
    required this.onSubmit,
    required this.canSubmit,
  });

  final QuickAddController formController;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final bool canSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: formController,
      builder: (context, _) {
        final bool isSubmitting = formController.isSubmitting;
        final bool disabled = isSubmitting || !canSubmit;
        return TaskFormActionsRow(
          includeTopBorder: true,
          padding: calendarPaddingXl,
          gap: calendarGutterMd,
          children: [
            Expanded(
              child: TaskSecondaryButton(
                label: l10n.calendarCancel,
                onPressed: isSubmitting ? null : onCancel,
                foregroundColor: calendarSubtitleColor,
                hoverForegroundColor: calendarPrimaryColor,
                hoverBackgroundColor:
                    calendarPrimaryColor.withValues(alpha: 0.06),
              ),
            ),
            Expanded(
              child: TaskPrimaryButton(
                label: l10n.calendarAddTaskAction,
                onPressed: disabled ? null : onSubmit,
                isBusy: isSubmitting,
              ),
            ),
          ],
        );
      },
    );
  }
}

// Helper function to show the modal
Future<void> showQuickAddModal<B extends BaseCalendarBloc>({
  required BuildContext context,
  DateTime? prefilledDateTime,
  String? prefilledText,
  required void Function(CalendarTask task) onTaskAdded,
  required LocationAutocompleteHelper locationHelper,
  String? initialValidationMessage,
  B? calendarBloc,
  T Function<T>()? locate,
}) {
  B? resolveBloc() {
    if (locate != null) {
      try {
        return locate<B>();
      } catch (_) {
        // Fall back to the explicitly provided bloc when locate cannot resolve.
      }
    }
    return calendarBloc;
  }

  final commandSurface = resolveCommandSurface(context);
  final bool isDesktop = !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);
  final bool useSheet = !isDesktop && commandSurface == CommandSurface.sheet;
  final surface =
      useSheet ? QuickAddModalSurface.bottomSheet : QuickAddModalSurface.dialog;

  if (!useSheet) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final B? resolvedBloc = resolveBloc();
        final bool hasBloc = resolvedBloc != null;
        Widget child = QuickAddModal(
          surface: surface,
          prefilledDateTime: prefilledDateTime,
          prefilledText: prefilledText,
          onTaskAdded: onTaskAdded,
          locationHelper: locationHelper,
          initialValidationMessage: initialValidationMessage,
          hasCalendarBloc: hasBloc,
          calendarBloc: resolvedBloc,
          onDismiss: () {
            if (Navigator.of(dialogContext).canPop()) {
              Navigator.of(dialogContext).maybePop();
            }
          },
        );
        return child;
      },
    );
  }

  return showAdaptiveBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: useSheet,
    isDismissible: true,
    barrierColor: Colors.black54,
    backgroundColor: Colors.transparent,
    surfacePadding: EdgeInsets.zero,
    dialogMaxWidth: 760,
    showCloseButton: false,
    builder: (sheetContext) {
      final B? resolvedBloc = resolveBloc();
      final bool hasBloc = resolvedBloc != null;
      Widget child = QuickAddModal(
        surface: surface,
        prefilledDateTime: prefilledDateTime,
        prefilledText: prefilledText,
        onTaskAdded: onTaskAdded,
        locationHelper: locationHelper,
        initialValidationMessage: initialValidationMessage,
        hasCalendarBloc: hasBloc,
        calendarBloc: resolvedBloc,
        onDismiss: useSheet
            ? null
            : () {
                if (Navigator.of(sheetContext).canPop()) {
                  Navigator.of(sheetContext).maybePop();
                }
              },
      );
      return child;
    },
  );
}
