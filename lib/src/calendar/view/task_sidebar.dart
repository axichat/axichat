import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart'
    show
        ParentData,
        RenderBox,
        RendererBinding,
        SliverMultiBoxAdaptorParentData;
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/calendar_share.dart';
import 'package:axichat/src/calendar/utils/calendar_transfer_service.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/utils/task_share_formatter.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'calendar_task_search.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'widgets/calendar_task_title_tooltip.dart';
import 'calendar_transfer_sheet.dart';
import 'controllers/calendar_sidebar_controller.dart';
import 'controllers/task_checklist_controller.dart';
import 'controllers/task_draft_controller.dart';
import 'edit_task_dropdown.dart';
import 'feedback_system.dart';
import 'layout/calendar_layout.dart';
import 'models/task_context_action.dart';
import 'widgets/calendar_drag_target.dart';
import 'widgets/calendar_sidebar_draggable.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/location_inline_suggestion.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/recurrence_spacing_tokens.dart';
import 'widgets/task_field_character_hint.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_checklist.dart';
import 'widgets/task_text_field.dart';
import 'widgets/critical_path_panel.dart';
import 'widgets/calendar_completion_checkbox.dart';
import 'widgets/reminder_preferences_field.dart';
import 'task_edit_session_tracker.dart';

class TaskSidebar<B extends BaseCalendarBloc> extends StatefulWidget {
  const TaskSidebar({
    super.key,
    this.onDragSessionStarted,
    this.onDragSessionEnded,
    this.onDragGlobalPositionChanged,
  });

  final VoidCallback? onDragSessionStarted;
  final VoidCallback? onDragSessionEnded;
  final ValueChanged<Offset>? onDragGlobalPositionChanged;

  @override
  State<TaskSidebar<B>> createState() => TaskSidebarState<B>();
}

class TaskSidebarState<B extends BaseCalendarBloc> extends State<TaskSidebar<B>>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  late final CalendarSidebarController _sidebarController;
  late final TaskDraftController _draftController;
  late final TaskChecklistController _checklistController;
  final GlobalKey<FormState> _addTaskFormKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode(debugLabel: 'sidebarTitleInput');
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  late final Listenable _formActivityListenable;
  final TextEditingController _selectionTitleController =
      TextEditingController();
  final TextEditingController _selectionDescriptionController =
      TextEditingController();
  final TextEditingController _selectionLocationController =
      TextEditingController();
  late final TaskChecklistController _selectionChecklistController;
  static const Duration _selectionTimeStep = Duration(minutes: 15);
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _scrollViewportKey = GlobalKey();
  final Map<CalendarSidebarSection, GlobalKey> _sectionKeys = {
    CalendarSidebarSection.unscheduled:
        GlobalKey(debugLabel: 'sidebar-unscheduled-section'),
    CalendarSidebarSection.reminders:
        GlobalKey(debugLabel: 'sidebar-reminders-section'),
  };
  Ticker? _sidebarAutoScrollTicker;
  double _sidebarAutoScrollOffsetPerFrame = 0;
  static const double _autoScrollHorizontalSlop = 32.0;
  final CalendarTransferService _transferService =
      const CalendarTransferService();
  bool _criticalPathsExpanded = false;
  String? _activeCriticalPathId;
  List<String> _unscheduledOrder = <String>[];
  List<String> _reminderOrder = <String>[];
  bool _hideCompletedCriticalPath = false;
  final List<String> _queuedCriticalPathIds = <String>[];

  String _selectionRecurrenceSignature = '';
  late final ValueNotifier<RecurrenceFormValue> _selectionRecurrenceNotifier;
  late final ValueNotifier<bool> _selectionRecurrenceMixedNotifier;
  late final ValueNotifier<ReminderPreferences> _selectionRemindersNotifier;
  late final ValueNotifier<bool> _selectionRemindersMixedNotifier;
  late final ValueNotifier<ReminderAnchor> _selectionReminderAnchorNotifier;
  String? _selectionMessage;
  Timer? _selectionMessageTimer;

  late final NlScheduleParserService _nlParserService;
  Timer? _parserDebounce;
  int _parserRequestId = 0;
  String _lastParserInput = '';
  bool _isApplyingParser = false;
  NlAdapterResult? _lastParserResult;

  bool _locationLocked = false;
  bool _scheduleLocked = false;
  bool _deadlineLocked = false;
  bool _recurrenceLocked = false;
  bool _priorityLocked = false;
  bool _remindersLocked = false;
  String? _quickTaskError;
  bool _hasAttemptedQuickTaskSubmit = false;
  bool _preserveDraftFieldsOnTitleClear = false;

  RecurrenceFormValue get _advancedRecurrence => _draftController.recurrence;

  RecurrenceFormValue get _selectionRecurrence =>
      _selectionRecurrenceNotifier.value;
  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  bool _selectionTitleDirty = false;
  bool _selectionDescriptionDirty = false;
  bool _selectionLocationDirty = false;
  bool _selectionChecklistDirty = false;
  String _selectionFieldsSignature = '';
  String _selectionTitleInitialValue = '';
  String _selectionDescriptionInitialValue = '';
  String _selectionLocationInitialValue = '';
  List<TaskChecklistItem> _selectionChecklistInitialValue = const [];
  bool _isUpdatingSelectionTitle = false;
  bool _isUpdatingSelectionDescription = false;
  bool _isUpdatingSelectionLocation = false;
  bool _isUpdatingSelectionChecklist = false;
  int? _activeResizePointerId;

  bool get _hasPendingSelectionEdits =>
      _selectionTitleDirty ||
      _selectionDescriptionDirty ||
      _selectionLocationDirty ||
      _selectionChecklistDirty;

  bool _externalGridDragActive = false;

  bool get _hasPrecisePointerInput =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  bool get _isTouchOnlyInput => !_hasPrecisePointerInput;

  bool get _hasSidebarFormValues =>
      _titleController.text.trim().isNotEmpty ||
      _descriptionController.text.trim().isNotEmpty ||
      _locationController.text.trim().isNotEmpty ||
      _checklistController.hasItems ||
      _draftController.startTime != null ||
      _draftController.endTime != null ||
      _draftController.deadline != null ||
      _draftController.recurrence.isActive ||
      _draftController.isImportant ||
      _draftController.isUrgent ||
      _draftController.reminders != ReminderPreferences.defaults();

  void handleExternalGridDragStarted({required bool isTouchMode}) {
    if (_externalGridDragActive) {
      return;
    }
    _externalGridDragActive = true;
    if (!isTouchMode) {
      return;
    }
    final CalendarSidebarSection? current =
        _sidebarController.state.expandedSection;
    if (current == CalendarSidebarSection.unscheduled) {
      return;
    }
    _sidebarController.expandSection(CalendarSidebarSection.unscheduled);
  }

  void handleExternalGridDragPosition(Offset globalPosition) {
    if (!_externalGridDragActive) {
      return;
    }
    if (!_isTouchOnlyInput) {
      return;
    }
    final CalendarSidebarSection? hoveredSection =
        _sectionForGlobalPosition(globalPosition);
    if (hoveredSection == null) {
      return;
    }
    if (_sidebarController.state.expandedSection == hoveredSection) {
      return;
    }
    _sidebarController.expandSection(hoveredSection);
  }

  void handleExternalGridDragEnded() {
    if (!_externalGridDragActive) {
      return;
    }
    _externalGridDragActive = false;
  }

  CalendarSidebarSection? _sectionForGlobalPosition(Offset globalPosition) {
    for (final MapEntry<CalendarSidebarSection, GlobalKey> entry
        in _sectionKeys.entries) {
      final BuildContext? context = entry.value.currentContext;
      if (context == null) {
        continue;
      }
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) {
        continue;
      }
      final Size size = box.size;
      final bool hasSize = size.isFinite && size.width > 0 && size.height > 0;
      if (!hasSize) {
        continue;
      }
      final Offset origin = box.localToGlobal(Offset.zero);
      final Rect rect = origin & size;
      if (rect.contains(globalPosition)) {
        return entry.key;
      }
    }
    return null;
  }

  void _handleQuickTaskInputChanged(String value, {bool validate = true}) {
    if (_quickTaskError != null) {
      setState(() {
        _quickTaskError = null;
      });
    }
    if (validate && _shouldValidateQuickTask) {
      _addTaskFormKey.currentState?.validate();
    }
    final trimmed = value.trim();
    _parserDebounce?.cancel();
    if (trimmed.isEmpty) {
      final bool preserveDraftFields = _preserveDraftFieldsOnTitleClear;
      _preserveDraftFieldsOnTitleClear = false;
      _clearParserState(clearFields: !preserveDraftFields);
      return;
    }
    if (_preserveDraftFieldsOnTitleClear) {
      _preserveDraftFieldsOnTitleClear = false;
    }
    if (trimmed == _lastParserInput) {
      return;
    }
    _parserDebounce = Timer(const Duration(milliseconds: 350), () {
      _runParser(trimmed);
    });
  }

  void _handleAdvancedToggle() {
    _sidebarController.toggleAdvancedOptions();
  }

  Future<void> _runParser(String input) async {
    final requestId = ++_parserRequestId;
    try {
      final result = await _nlParserService.parse(input);
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = input;
      _lastParserResult = result;
      _applyParserResult(result);
    } catch (error) {
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _lastParserInput = '';
      _lastParserResult = null;
      _clearParserDrivenFields();
      setState(() {
        _quickTaskError =
            context.l10n.calendarParserUnavailable(error.runtimeType);
      });
      _addTaskFormKey.currentState?.validate();
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
      if (start == null && end == null) {
        _draftController.clearSchedule();
      } else {
        _draftController.updateStart(start);
        _draftController.updateEnd(end);
      }
    }

    if (!_deadlineLocked) {
      _draftController.setDeadline(task.deadline);
    }

    if (!_recurrenceLocked) {
      _draftController.setRecurrence(
        RecurrenceFormValue.fromRule(task.recurrence),
      );
    }

    if (!_priorityLocked) {
      final TaskPriority priority = task.priority ?? TaskPriority.none;
      _draftController.setImportant(
        priority == TaskPriority.important || priority == TaskPriority.critical,
      );
      _draftController.setUrgent(
        priority == TaskPriority.urgent || priority == TaskPriority.critical,
      );
    }

    if (!_remindersLocked) {
      _draftController.setReminders(task.effectiveReminders);
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
    }
  }

  void _clearParserDrivenFields() {
    _isApplyingParser = true;
    if (!_scheduleLocked) {
      _draftController.clearSchedule();
    }
    if (!_deadlineLocked) {
      _draftController.setDeadline(null);
    }
    if (!_recurrenceLocked) {
      _draftController.setRecurrence(const RecurrenceFormValue());
    }
    if (!_priorityLocked) {
      _draftController.setImportant(false);
      _draftController.setUrgent(false);
    }
    if (!_remindersLocked) {
      _draftController.setReminders(ReminderPreferences.defaults());
    }
    if (!_locationLocked && _locationController.text.isNotEmpty) {
      _locationController.clear();
    }
    _isApplyingParser = false;
  }

  void _handleLocationEdited() {
    if (_isApplyingParser) {
      return;
    }
    _locationLocked = _locationController.text.trim().isNotEmpty;
  }

  void _onUserStartChanged(DateTime? value) {
    _scheduleLocked = value != null || _draftController.endTime != null;
    _draftController.updateStart(value);
    if (value == null && _draftController.endTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserEndChanged(DateTime? value) {
    _scheduleLocked = value != null || _draftController.startTime != null;
    _draftController.updateEnd(value);
    if (value == null && _draftController.startTime == null) {
      _scheduleLocked = false;
    }
  }

  void _onUserScheduleCleared() {
    _scheduleLocked = false;
    _draftController.clearSchedule();
  }

  void _onUserDeadlineChanged(DateTime? value) {
    _deadlineLocked = value != null;
    _draftController.setDeadline(value);
    if (value == null) {
      _deadlineLocked = false;
    }
  }

  void _onUserRecurrenceChanged(RecurrenceFormValue value) {
    _recurrenceLocked = value.isActive;
    _draftController.setRecurrence(value);
    if (!value.isActive) {
      _recurrenceLocked = false;
    }
  }

  void _onUserImportantChanged(bool value) {
    _priorityLocked = true;
    _draftController.setImportant(value);
  }

  void _onUserUrgentChanged(bool value) {
    _priorityLocked = true;
    _draftController.setUrgent(value);
  }

  void _onRemindersChanged(ReminderPreferences value) {
    _remindersLocked = true;
    _draftController.setReminders(value);
  }

  void _resetParserLocks() {
    _locationLocked = false;
    _scheduleLocked = false;
    _deadlineLocked = false;
    _recurrenceLocked = false;
    _priorityLocked = false;
    _remindersLocked = false;
  }

  void _pruneTaskPopoverControllers(Set<String> activeTaskIds) {
    final List<String> staleIds = <String>[];
    _taskPopoverControllers.forEach((id, controller) {
      if (!activeTaskIds.contains(id)) {
        controller.hide();
        controller.dispose();
        staleIds.add(id);
      }
    });
    if (staleIds.isNotEmpty) {
      for (final id in staleIds) {
        _taskPopoverControllers.remove(id);
      }
    }
    final String? activeId = _sidebarController.state.activePopoverTaskId;
    if (activeId != null && !activeTaskIds.contains(activeId)) {
      _sidebarController.setActivePopoverTaskId(null);
    }
  }

  @override
  void initState() {
    super.initState();
    _sidebarController = CalendarSidebarController(
      width: _layoutTheme.sidebarMinWidth,
      minWidth: _layoutTheme.sidebarMinWidth,
      maxWidth: _layoutTheme.sidebarMinWidth,
    );
    _draftController = TaskDraftController();
    _checklistController = TaskChecklistController();
    _selectionChecklistController = TaskChecklistController();
    _formActivityListenable = Listenable.merge([
      _titleController,
      _descriptionController,
      _locationController,
      _draftController,
      _checklistController,
    ]);
    _selectionRecurrenceNotifier =
        ValueNotifier<RecurrenceFormValue>(const RecurrenceFormValue());
    _selectionRecurrenceMixedNotifier = ValueNotifier<bool>(false);
    _selectionRemindersNotifier =
        ValueNotifier<ReminderPreferences>(ReminderPreferences.defaults());
    _selectionRemindersMixedNotifier = ValueNotifier<bool>(false);
    _selectionReminderAnchorNotifier =
        ValueNotifier<ReminderAnchor>(ReminderAnchor.start);
    _nlParserService = NlScheduleParserService();
    _locationController.addListener(_handleLocationEdited);
    _selectionChecklistController.addListener(_handleSelectionChecklistChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    TaskEditSessionTracker.instance.endForOwner(this);
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _locationController.removeListener(_handleLocationEdited);
    _locationController.dispose();
    _checklistController.dispose();

    _selectionTitleController.dispose();
    _selectionDescriptionController.dispose();
    _selectionLocationController.dispose();
    _selectionChecklistController
      ..removeListener(_handleSelectionChecklistChanged)
      ..dispose();
    _scrollController.dispose();
    _draftController.dispose();
    _selectionRecurrenceNotifier.dispose();
    _selectionRecurrenceMixedNotifier.dispose();
    _selectionRemindersNotifier.dispose();
    _selectionRemindersMixedNotifier.dispose();
    _selectionReminderAnchorNotifier.dispose();
    _sidebarAutoScrollTicker?.dispose();
    _parserDebounce?.cancel();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    _sidebarController.dispose();
    _selectionMessageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final sidebarDimensions = ResponsiveHelper.sidebarDimensions(context);
    _sidebarController.syncBounds(
      minWidth: sidebarDimensions.minWidth,
      maxWidth: sidebarDimensions.maxWidth,
      defaultWidth: sidebarDimensions.defaultWidth,
    );

    return AnimatedBuilder(
      animation: _sidebarController,
      builder: (context, _) {
        final CalendarSidebarState uiState = _sidebarController.state;
        final mediaQuery = MediaQuery.of(context);
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final EdgeInsetsGeometry scrollPadding =
            calendarSidebarScrollPadding.add(
          EdgeInsets.only(bottom: keyboardInset),
        );
        return Container(
          width: uiState.width,
          decoration: const BoxDecoration(
            color: sidebarBackgroundColor,
            border: Border(
              top: BorderSide(
                color: calendarBorderColor,
                width: calendarBorderStroke,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: BlocBuilder<B, CalendarState>(
                  builder: (context, state) {
                    final locationHelper =
                        LocationAutocompleteHelper.fromState(state);
                    final SettingsCubit settings =
                        context.watch<SettingsCubit>();
                    final SettingsState settingsState = settings.state;
                    List<CalendarTask> selectionTasks = const [];
                    if (state.isSelectionMode) {
                      selectionTasks = _selectedTasks(state);
                      _syncSelectionRecurrenceState(selectionTasks);
                      _syncSelectionRemindersState(selectionTasks);
                      _syncSelectionFieldControllers(selectionTasks);
                      selectionTasks = selectionTasks.where((task) {
                        if (!state.isTaskInFocusedPath(task)) {
                          return false;
                        }
                        if (_hideCompletedCriticalPath &&
                            _isTaskOnlyInCompletedPaths(task, state)) {
                          return false;
                        }
                        if (task.scheduledTime != null &&
                            context
                                .watch<SettingsCubit>()
                                .state
                                .hideCompletedScheduled &&
                            task.isCompleted) {
                          return false;
                        }
                        if (task.scheduledTime == null &&
                            task.deadline != null &&
                            context
                                .watch<SettingsCubit>()
                                .state
                                .hideCompletedReminders &&
                            task.isCompleted) {
                          return false;
                        }
                        if (task.scheduledTime == null &&
                            task.deadline == null &&
                            context
                                .watch<SettingsCubit>()
                                .state
                                .hideCompletedUnscheduled &&
                            task.isCompleted) {
                          return false;
                        }
                        return true;
                      }).toList();
                    }
                    final String? activeOrderingPathId =
                        state.model.criticalPaths[_activeCriticalPathId] != null
                            ? _activeCriticalPathId
                            : null;
                    final bool showAddTaskSection = !_criticalPathsExpanded;
                    final Widget criticalPathsPanel = CriticalPathPanel(
                      paths: state.criticalPaths,
                      tasks: state.model.tasks,
                      focusedPathId: state.focusedCriticalPathId,
                      orderingPathId: activeOrderingPathId,
                      animationDuration:
                          context.watch<SettingsCubit>().animationDuration,
                      onCreatePath: _handleCreateCriticalPath,
                      onRenamePath: _handleRenameCriticalPath,
                      onDeletePath: _handleDeleteCriticalPath,
                      onFocusPath: _handleFocusCriticalPath,
                      onOpenPath: _handleOpenCriticalPath,
                      onReorderPath: _handleCriticalPathReorder,
                      taskTileBuilder: (task, trailing,
                              {bool requiresLongPress = false}) =>
                          _buildDraggableSidebarTaskTile(
                        task,
                        trailing: trailing,
                        requiresLongPress: requiresLongPress,
                        uiState: uiState,
                      ),
                      isExpanded: _criticalPathsExpanded,
                      onToggleExpanded: _toggleCriticalPathsExpanded,
                      requiresLongPressForReorder: _isTouchOnlyInput,
                      hideCompleted: _hideCompletedCriticalPath,
                      onToggleHideCompleted: (value) =>
                          setState(() => _hideCompletedCriticalPath = value),
                      onCloseOrdering: _closeActiveCriticalPath,
                      onAddTaskToFocusedPath: _openCriticalPathSearch,
                    );

                    List<CalendarTask> unscheduledTasks = const [];
                    List<CalendarTask> reminderTasks = const [];
                    List<CalendarTask> orderedUnscheduled = const [];
                    List<CalendarTask> orderedReminders = const [];
                    final List<CalendarCriticalPath> queuedCriticalPaths =
                        _queuedPathsForState(state);
                    Widget contentBody;
                    if (state.isSelectionMode) {
                      contentBody = _SelectionPanel<B>(
                        tasks: selectionTasks,
                        uiState: uiState,
                        locationHelper: locationHelper,
                        selectionMessage: _selectionMessage,
                        onExitSelection: () => context.read<B>().add(
                              const CalendarEvent.selectionCleared(),
                            ),
                        onClearSelection: () => context.read<B>().add(
                              const CalendarEvent.selectionCleared(),
                            ),
                        onExportSelected: () =>
                            _exportSelectedTasks(selectionTasks),
                        onDeleteSelected: () => context.read<B>().add(
                              const CalendarEvent.selectionDeleted(),
                            ),
                        selectionTitleController: _selectionTitleController,
                        selectionDescriptionController:
                            _selectionDescriptionController,
                        selectionLocationController:
                            _selectionLocationController,
                        selectionChecklistController:
                            _selectionChecklistController,
                        onSelectionTitleChanged: _handleSelectionTitleChanged,
                        onSelectionDescriptionChanged:
                            _handleSelectionDescriptionChanged,
                        onSelectionLocationChanged:
                            _handleSelectionLocationChanged,
                        hasPendingSelectionEdits: _hasPendingSelectionEdits,
                        onApplySelectionChanges: _applySelectionBatchChanges,
                        timeAdjustCallbacks: _SelectionTimeAdjustCallbacks(
                          onStartMinus: () => _shiftSelectionTime(
                            startDelta: -_selectionTimeStep,
                          ),
                          onStartPlus: () => _shiftSelectionTime(
                            startDelta: _selectionTimeStep,
                          ),
                          onEndMinus: () => _shiftSelectionTime(
                            endDelta: -_selectionTimeStep,
                          ),
                          onEndPlus: () => _shiftSelectionTime(
                            endDelta: _selectionTimeStep,
                          ),
                        ),
                        onPriorityChanged: (priority) => context.read<B>().add(
                              CalendarEvent.selectionPriorityChanged(
                                priority: priority,
                              ),
                            ),
                        onCompletionChanged: (completed) =>
                            context.read<B>().add(
                                  CalendarEvent.selectionCompletedToggled(
                                    completed: completed,
                                  ),
                                ),
                        remindersNotifier: _selectionRemindersNotifier,
                        remindersMixedNotifier:
                            _selectionRemindersMixedNotifier,
                        onRemindersChanged: _handleSelectionRemindersChanged,
                        reminderAnchorNotifier:
                            _selectionReminderAnchorNotifier,
                        recurrenceNotifier: _selectionRecurrenceNotifier,
                        recurrenceMixedNotifier:
                            _selectionRecurrenceMixedNotifier,
                        fallbackWeekday:
                            _defaultSelectionWeekday(selectionTasks),
                        onRecurrenceChanged: _handleSelectionRecurrenceChanged,
                        scheduleLabelBuilder: _selectionScheduleLabel,
                        onFocusTask: _focusTask,
                        onRemoveTask: (task) => context.read<B>().add(
                              CalendarEvent.selectionIdsRemoved(
                                taskIds: {task.id},
                              ),
                            ),
                        onToggleCompletion: _toggleSidebarTaskCompletion,
                      );
                    } else {
                      unscheduledTasks = _sortTasksByDeadline(
                        state.unscheduledTasks.where((task) {
                          if (!state.isTaskInFocusedPath(task)) {
                            return false;
                          }
                          if (task.deadline != null) {
                            return false;
                          }
                          if (settingsState.hideCompletedUnscheduled &&
                              task.isCompleted) {
                            return false;
                          }
                          return true;
                        }).toList(),
                      );
                      final List<String> settingsUnscheduledOrder =
                          settingsState.unscheduledSidebarOrder;
                      if (!listEquals(
                        settingsUnscheduledOrder,
                        _unscheduledOrder,
                      )) {
                        _unscheduledOrder =
                            List<String>.from(settingsUnscheduledOrder);
                      }
                      final List<String> unscheduledOrder =
                          _deriveOrder(unscheduledTasks, _unscheduledOrder);
                      if (!listEquals(_unscheduledOrder, unscheduledOrder)) {
                        _unscheduledOrder = List<String>.from(unscheduledOrder);
                      }
                      if (!listEquals(
                        settingsUnscheduledOrder,
                        unscheduledOrder,
                      )) {
                        settings.saveUnscheduledSidebarOrder(
                          unscheduledOrder,
                        );
                      }
                      orderedUnscheduled = _orderedTasksFromOrder(
                        unscheduledTasks,
                        unscheduledOrder,
                      );
                      reminderTasks = _sortTasksByDeadline(
                        state.unscheduledTasks.where((task) {
                          if (!state.isTaskInFocusedPath(task)) {
                            return false;
                          }
                          if (task.deadline == null) {
                            return false;
                          }
                          if (settingsState.hideCompletedReminders &&
                              task.isCompleted) {
                            return false;
                          }
                          return true;
                        }).toList(),
                      );
                      final List<String> settingsReminderOrder =
                          settingsState.reminderSidebarOrder;
                      if (!listEquals(settingsReminderOrder, _reminderOrder)) {
                        _reminderOrder = List<String>.from(
                          settingsReminderOrder,
                        );
                      }
                      final List<String> reminderOrder =
                          _deriveOrder(reminderTasks, _reminderOrder);
                      if (!listEquals(_reminderOrder, reminderOrder)) {
                        _reminderOrder = List<String>.from(reminderOrder);
                      }
                      if (!listEquals(settingsReminderOrder, reminderOrder)) {
                        settings.saveReminderSidebarOrder(reminderOrder);
                      }
                      orderedReminders = _orderedTasksFromOrder(
                        reminderTasks,
                        reminderOrder,
                      );
                      unscheduledTasks = orderedUnscheduled;
                      reminderTasks = orderedReminders;
                      contentBody = _UnscheduledSidebarContent(
                        uiState: uiState,
                        locationHelper: locationHelper,
                        formActivityListenable: _formActivityListenable,
                        hasSidebarFormValues: () => _hasSidebarFormValues,
                        onClearFieldsPressed: _handleClearFieldsPressed,
                        titleController: _titleController,
                        titleFocusNode: _titleFocusNode,
                        addTaskFormKey: _addTaskFormKey,
                        quickTaskValidator: _validateQuickTaskTitle,
                        quickTaskAutovalidateMode: _quickTaskAutovalidateMode,
                        onQuickTaskChanged: _handleQuickTaskInputChanged,
                        onQuickTaskSubmitted: () {
                          _addTask();
                        },
                        draftController: _draftController,
                        onImportantChanged: _onUserImportantChanged,
                        onUrgentChanged: _onUserUrgentChanged,
                        sidebarController: _sidebarController,
                        onAdvancedToggle: _handleAdvancedToggle,
                        descriptionController: _descriptionController,
                        locationController: _locationController,
                        checklistController: _checklistController,
                        onDeadlineChanged: _onUserDeadlineChanged,
                        onStartChanged: _onUserStartChanged,
                        onEndChanged: _onUserEndChanged,
                        onScheduleCleared: _onUserScheduleCleared,
                        onRecurrenceChanged: _onUserRecurrenceChanged,
                        onRemindersChanged: _onRemindersChanged,
                        queuedCriticalPaths: queuedCriticalPaths,
                        onRemoveQueuedCriticalPath: _removeQueuedCriticalPath,
                        onAddTask: () {
                          _addTask();
                        },
                        onAddToCriticalPath: _queueCriticalPathForDraft,
                        onShowAddTaskSection: _showAddTaskSection,
                        showAddTaskSection: showAddTaskSection,
                        unscheduledTasks: orderedUnscheduled,
                        reminderTasks: orderedReminders,
                        hideCompletedUnscheduled:
                            settingsState.hideCompletedUnscheduled,
                        hideCompletedReminders:
                            settingsState.hideCompletedReminders,
                        onToggleHideCompletedUnscheduled:
                            settings.toggleHideCompletedUnscheduled,
                        onToggleHideCompletedReminders:
                            settings.toggleHideCompletedReminders,
                        sectionKeys: _sectionKeys,
                        onToggleSection: _sidebarController.toggleSection,
                        onSectionDragEnter: _handleSidebarSectionDragEnter,
                        onTaskDropped: _handleTaskDroppedIntoSidebar,
                        onTaskListHover: _handleSidebarDragTargetHover,
                        onTaskListLeave: _stopSidebarAutoScroll,
                        onTaskListDrop: (details) {
                          _stopSidebarAutoScroll();
                          _forwardSidebarGlobalPosition(
                            details.globalPosition,
                            notifyParent: false,
                          );
                          _handleTaskDroppedIntoSidebar(
                            details.payload.task,
                          );
                        },
                        onUnscheduledReorder: (oldIndex, newIndex) {
                          _handleTaskListReorder(
                            tasks: orderedUnscheduled,
                            cache: _unscheduledOrder,
                            updateCache: (next) {
                              _unscheduledOrder = next;
                              settings.saveUnscheduledSidebarOrder(next);
                            },
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          );
                        },
                        onReminderReorder: (oldIndex, newIndex) {
                          _handleTaskListReorder(
                            tasks: orderedReminders,
                            cache: _reminderOrder,
                            updateCache: (next) {
                              _reminderOrder = next;
                              settings.saveReminderSidebarOrder(next);
                            },
                            oldIndex: oldIndex,
                            newIndex: newIndex,
                          );
                        },
                        requiresLongPressForReorder: _isTouchOnlyInput,
                        taskTileBuilder: (task, trailing,
                                {bool requiresLongPress = false}) =>
                            _buildDraggableSidebarTaskTile(
                          task,
                          uiState: uiState,
                          trailing: trailing,
                          requiresLongPress: requiresLongPress,
                        ),
                      );
                    }

                    final Widget content = Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        criticalPathsPanel,
                        contentBody,
                      ],
                    );

                    final Set<String> activeTaskIds = state.isSelectionMode
                        ? selectionTasks.map((task) => task.id).toSet()
                        : {
                            ...unscheduledTasks.map((task) => task.id),
                            ...reminderTasks.map((task) => task.id),
                          };
                    _pruneTaskPopoverControllers(activeTaskIds);

                    final bool enableKeyboardDismiss =
                        _supportsDragDismiss(context);
                    return Scrollbar(
                      controller: _scrollController,
                      radius:
                          const Radius.circular(calendarSidebarScrollbarRadius),
                      thickness: _layoutTheme.sidebarScrollbarThickness,
                      child: SingleChildScrollView(
                        key: _scrollViewportKey,
                        controller: _scrollController,
                        padding: scrollPadding,
                        keyboardDismissBehavior: enableKeyboardDismiss
                            ? ScrollViewKeyboardDismissBehavior.onDrag
                            : ScrollViewKeyboardDismissBehavior.manual,
                        physics: const ClampingScrollPhysics(),
                        child: content,
                      ),
                    );
                  },
                ),
              ),
              if (ResponsiveHelper.isExpanded(context))
                _SidebarResizeHandle(
                  uiState: uiState,
                  onPointerDown: _handleResizePointerDown,
                  onPointerMove: _handleResizePointerMove,
                  onPointerUp: _handleResizePointerUp,
                  onPointerCancel: _handleResizePointerCancel,
                ),
            ],
          ),
        );
      },
    );
  }

  bool _supportsDragDismiss(BuildContext context) {
    final TargetPlatform platform = Theme.of(context).platform;
    return platform == TargetPlatform.android || platform == TargetPlatform.iOS;
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _exportSelectedTasks(List<CalendarTask> tasks) async {
    final l10n = context.l10n;
    if (tasks.isEmpty) {
      FeedbackSystem.showInfo(context, l10n.calendarSelectionNone);
      return;
    }
    final format = await showCalendarExportFormatSheet(
      context,
      title: l10n.calendarExportSelected,
    );
    if (!mounted || format == null) return;
    try {
      final File file = await _transferService.exportTasks(
        tasks: tasks,
        format: format,
        fileNamePrefix: 'axichat_tasks',
      );
      final CalendarShareOutcome shareOutcome = await shareCalendarExport(
        file: file,
        subject: l10n.calendarExportSelected,
        text: '${l10n.calendarExportSelected} (${format.label})',
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

  void _dispatchSelectionRecurrence() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      return;
    }

    context.read<B>().add(
          CalendarEvent.selectionRecurrenceChanged(
            recurrence: _selectionRecurrence.isActive
                ? _selectionRecurrence.toRule(
                    start: context.read<B>().state.selectedDate,
                  )
                : null,
          ),
        );
  }

  RecurrenceFormValue _normalizeSelectionRecurrence(RecurrenceFormValue value) {
    return value.resolveLinkedLimits(
      context.read<B>().state.selectedDate,
    );
  }

  void _handleSelectionRecurrenceChanged(RecurrenceFormValue next) {
    final normalized = _normalizeSelectionRecurrence(next);
    _selectionRecurrenceNotifier.value = normalized;
    if (_selectionRecurrenceMixedNotifier.value) {
      _selectionRecurrenceMixedNotifier.value = false;
    }
    _dispatchSelectionRecurrence();
  }

  void _syncSelectionRecurrenceState(List<CalendarTask> tasks) {
    final signature = tasks
        .map(
          (task) => '${task.id}:${_recurrenceSignature(task.recurrence)}',
        )
        .join('|');

    if (signature == _selectionRecurrenceSignature) {
      return;
    }

    _selectionRecurrenceSignature = signature;

    if (tasks.isEmpty) {
      _selectionRecurrenceNotifier.value = const RecurrenceFormValue();
      _selectionRecurrenceMixedNotifier.value = false;
      return;
    }

    final firstRule = tasks.first.recurrence ?? RecurrenceRule.none;
    final allSame = tasks.every((task) {
      final rule = task.recurrence ?? RecurrenceRule.none;
      return _recurrenceEquals(firstRule, rule);
    });

    final effectiveRule = allSame ? firstRule : RecurrenceRule.none;
    var nextValue = _formValueFromRule(
      effectiveRule == RecurrenceRule.none ? null : effectiveRule,
    );

    if (nextValue.frequency == RecurrenceFrequency.weekly &&
        nextValue.weekdays.isEmpty) {
      nextValue = nextValue.copyWith(
        weekdays: {_defaultSelectionWeekday(tasks)},
      );
    }
    nextValue = _normalizeSelectionRecurrence(nextValue);

    final currentValue = _selectionRecurrenceNotifier.value;
    if (!_formValuesEqual(currentValue, nextValue)) {
      _selectionRecurrenceNotifier.value = nextValue;
    }

    final shouldFlagMixed = !allSame;
    if (_selectionRecurrenceMixedNotifier.value != shouldFlagMixed) {
      _selectionRecurrenceMixedNotifier.value = shouldFlagMixed;
    }
  }

  void _dispatchSelectionReminders() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return;
    }
    context.read<B>().add(
          CalendarEvent.selectionRemindersChanged(
            reminders: _selectionRemindersNotifier.value,
          ),
        );
  }

  void _handleSelectionRemindersChanged(ReminderPreferences next) {
    final ReminderPreferences normalized =
        next.alignedTo(_selectionReminderAnchorNotifier.value).normalized();
    _selectionRemindersNotifier.value = normalized;
    if (_selectionRemindersMixedNotifier.value) {
      _selectionRemindersMixedNotifier.value = false;
    }
    _dispatchSelectionReminders();
  }

  void _syncSelectionRemindersState(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      _selectionRemindersNotifier.value = ReminderPreferences.defaults();
      _selectionRemindersMixedNotifier.value = false;
      _selectionReminderAnchorNotifier.value = ReminderAnchor.start;
      return;
    }
    final bool hasDeadline = tasks.any((task) => task.deadline != null);
    final ReminderAnchor anchor =
        hasDeadline ? ReminderAnchor.deadline : ReminderAnchor.start;

    final ReminderPreferences first =
        tasks.first.effectiveReminders.alignedTo(anchor);
    bool mixed = false;
    for (final CalendarTask task in tasks.skip(1)) {
      if (task.effectiveReminders.alignedTo(anchor) != first) {
        mixed = true;
        break;
      }
    }

    final ReminderPreferences normalizedFirst = first.normalized();
    if (_selectionRemindersNotifier.value != normalizedFirst) {
      _selectionRemindersNotifier.value = normalizedFirst;
    }
    _selectionRemindersMixedNotifier.value = mixed;
    if (_selectionReminderAnchorNotifier.value != anchor) {
      _selectionReminderAnchorNotifier.value = anchor;
    }
  }

  void _handleSelectionTitleChanged(String value) {
    if (_isUpdatingSelectionTitle) {
      _isUpdatingSelectionTitle = false;
      return;
    }
    setState(() {
      final normalized = value.trim();
      final baseline = _selectionTitleInitialValue.trim();
      _selectionTitleDirty = normalized.isNotEmpty && normalized != baseline;
    });
  }

  void _handleSelectionDescriptionChanged(String value) {
    if (_isUpdatingSelectionDescription) {
      _isUpdatingSelectionDescription = false;
      return;
    }
    setState(() {
      final normalized = value.trim();
      final baseline = _selectionDescriptionInitialValue.trim();
      _selectionDescriptionDirty = normalized != baseline;
    });
  }

  void _handleSelectionLocationChanged(String value) {
    if (_isUpdatingSelectionLocation) {
      _isUpdatingSelectionLocation = false;
      return;
    }
    setState(() {
      final normalized = value.trim();
      final baseline = _selectionLocationInitialValue.trim();
      _selectionLocationDirty = normalized != baseline;
    });
  }

  void _handleSelectionChecklistChanged() {
    if (_isUpdatingSelectionChecklist) {
      _isUpdatingSelectionChecklist = false;
      return;
    }
    setState(() {
      final String normalized =
          _checklistSignature(_selectionChecklistController.items);
      final String baseline = _checklistSignature(
        _selectionChecklistInitialValue,
      );
      _selectionChecklistDirty = normalized != baseline;
    });
  }

  void _applySelectionBatchChanges() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return;
    }

    bool applied = false;
    bool hadError = false;

    if (_selectionTitleDirty) {
      if (_applySelectionTitle()) {
        applied = true;
      } else {
        hadError = true;
      }
    }

    if (_selectionDescriptionDirty && _applySelectionDescription()) {
      applied = true;
    }

    if (_selectionLocationDirty && _applySelectionLocation()) {
      applied = true;
    }

    if (_selectionChecklistDirty && _applySelectionChecklist()) {
      applied = true;
    }

    if (applied && !hadError) {
      _setSelectionMessage(context.l10n.calendarSelectionChangesApplied);
    } else if (!applied && !hadError) {
      _setSelectionMessage(context.l10n.calendarSelectionNoPending);
    }
  }

  bool _applySelectionTitle() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return false;
    }
    final title = _selectionTitleController.text.trim();
    if (title.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionTitleBlank);
      return false;
    }
    context.read<B>().add(CalendarEvent.selectionTitleChanged(title: title));
    setState(() {
      _selectionTitleDirty = false;
    });
    return true;
  }

  bool _applySelectionDescription() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return false;
    }
    final raw = _selectionDescriptionController.text.trim();
    final description = raw.isEmpty ? null : raw;
    context.read<B>().add(
          CalendarEvent.selectionDescriptionChanged(description: description),
        );
    setState(() {
      _selectionDescriptionDirty = false;
    });
    return true;
  }

  bool _applySelectionLocation() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return false;
    }
    final raw = _selectionLocationController.text.trim();
    final location = raw.isEmpty ? null : raw;
    context.read<B>().add(
          CalendarEvent.selectionLocationChanged(location: location),
        );
    setState(() {
      _selectionLocationDirty = false;
    });
    return true;
  }

  bool _applySelectionChecklist() {
    if (context.read<B>().state.selectedTaskIds.isEmpty) {
      _setSelectionMessage(context.l10n.calendarSelectionRequired);
      return false;
    }
    final List<TaskChecklistItem> checklist =
        List<TaskChecklistItem>.from(_selectionChecklistController.items);
    context.read<B>().add(
          CalendarEvent.selectionChecklistChanged(
            checklist: checklist,
          ),
        );
    setState(() {
      _selectionChecklistDirty = false;
      _selectionChecklistInitialValue = checklist;
    });
    return true;
  }

  void _shiftSelectionTime({
    Duration startDelta = Duration.zero,
    Duration endDelta = Duration.zero,
  }) {
    if (startDelta == Duration.zero && endDelta == Duration.zero) {
      return;
    }
    context.read<B>().add(
          CalendarEvent.selectionTimeShifted(
            startDelta: startDelta,
            endDelta: endDelta,
          ),
        );
  }

  void _setSelectionMessage(String message) {
    _selectionMessageTimer?.cancel();
    setState(() {
      _selectionMessage = message;
    });
    _selectionMessageTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _selectionMessage = null;
      });
    });
  }

  void _syncSelectionFieldControllers(List<CalendarTask> tasks) {
    final signature = _selectionFieldsSignatureFor(tasks);
    final bool selectionChanged = signature != _selectionFieldsSignature;
    if (selectionChanged) {
      _selectionFieldsSignature = signature;
      final sharedTitle = _sharedRequiredField(tasks, (task) => task.title);
      final sharedDescription =
          _sharedOptionalField(tasks, (task) => task.description);
      final sharedLocation =
          _sharedOptionalField(tasks, (task) => task.location);
      final List<TaskChecklistItem>? sharedChecklist = _sharedChecklist(tasks);
      _selectionTitleInitialValue = sharedTitle ?? '';
      _selectionDescriptionInitialValue = sharedDescription ?? '';
      _selectionLocationInitialValue = sharedLocation ?? '';
      if (_selectionTitleDirty ||
          _selectionDescriptionDirty ||
          _selectionLocationDirty ||
          _selectionChecklistDirty) {
        _selectionTitleDirty = false;
        _selectionDescriptionDirty = false;
        _selectionLocationDirty = false;
        _selectionChecklistDirty = false;
      }
      _selectionChecklistInitialValue = sharedChecklist ?? const [];
    }

    _updateSelectionController(
      controller: _selectionTitleController,
      nextValue: _selectionTitleInitialValue,
      isDirty: _selectionTitleDirty,
      setUpdating: (value) => _isUpdatingSelectionTitle = value,
      forceUpdate: selectionChanged,
    );
    _updateSelectionController(
      controller: _selectionDescriptionController,
      nextValue: _selectionDescriptionInitialValue,
      isDirty: _selectionDescriptionDirty,
      setUpdating: (value) => _isUpdatingSelectionDescription = value,
      forceUpdate: selectionChanged,
    );
    _updateSelectionController(
      controller: _selectionLocationController,
      nextValue: _selectionLocationInitialValue,
      isDirty: _selectionLocationDirty,
      setUpdating: (value) => _isUpdatingSelectionLocation = value,
      forceUpdate: selectionChanged,
    );

    if (selectionChanged || !_selectionChecklistDirty) {
      _isUpdatingSelectionChecklist = true;
      _selectionChecklistController.setItems(_selectionChecklistInitialValue);
      _isUpdatingSelectionChecklist = false;
    }
  }

  void _updateSelectionController({
    required TextEditingController controller,
    required String nextValue,
    required bool isDirty,
    required ValueChanged<bool> setUpdating,
    bool forceUpdate = false,
  }) {
    final target = nextValue;
    if (!forceUpdate && isDirty) {
      return;
    }
    if (controller.text == target) {
      return;
    }
    setUpdating(true);
    controller.value = TextEditingValue(
      text: target,
      selection: TextSelection.collapsed(offset: target.length),
    );
  }

  String _selectionFieldsSignatureFor(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final task in tasks) {
      buffer
        ..write(task.id)
        ..write('|')
        ..write(task.modifiedAt.microsecondsSinceEpoch)
        ..write('|')
        ..write(task.title.trim())
        ..write('|')
        ..write((task.description ?? '').trim())
        ..write('|')
        ..write((task.location ?? '').trim())
        ..write('|')
        ..write(_checklistSignature(task.checklist))
        ..write(';');
    }
    return buffer.toString();
  }

  String _checklistSignature(List<TaskChecklistItem> items) {
    final StringBuffer buffer = StringBuffer();
    for (final TaskChecklistItem item in items) {
      final String label = item.label.trim();
      if (label.isEmpty) {
        continue;
      }
      buffer
        ..write(label)
        ..write('-')
        ..write(item.isCompleted ? '1' : '0')
        ..write(';');
    }
    return buffer.toString();
  }

  String? _sharedRequiredField(
    List<CalendarTask> tasks,
    String Function(CalendarTask task) resolver,
  ) {
    if (tasks.isEmpty) {
      return null;
    }
    final first = resolver(tasks.first).trim();
    final allMatch = tasks.every(
      (task) => resolver(task).trim() == first,
    );
    return allMatch ? first : null;
  }

  String? _sharedOptionalField(
    List<CalendarTask> tasks,
    String? Function(CalendarTask task) resolver,
  ) {
    if (tasks.isEmpty) {
      return null;
    }
    final first = (resolver(tasks.first) ?? '').trim();
    final allMatch = tasks.every(
      (task) => (resolver(task) ?? '').trim() == first,
    );
    return allMatch ? first : null;
  }

  List<TaskChecklistItem>? _sharedChecklist(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      return null;
    }
    final List<TaskChecklistItem> baseline =
        TaskChecklistController.normalize(tasks.first.checklist);
    for (final CalendarTask task in tasks.skip(1)) {
      final List<TaskChecklistItem> candidate =
          TaskChecklistController.normalize(task.checklist);
      if (!_checklistsEqual(baseline, candidate)) {
        return null;
      }
    }
    return baseline;
  }

  bool _checklistsEqual(
    List<TaskChecklistItem> a,
    List<TaskChecklistItem> b,
  ) {
    if (identical(a, b)) {
      return true;
    }
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      final TaskChecklistItem left = a[i];
      final TaskChecklistItem right = b[i];
      if (left.label.trim() != right.label.trim() ||
          left.isCompleted != right.isCompleted) {
        return false;
      }
    }
    return true;
  }

  bool _formValuesEqual(
    RecurrenceFormValue a,
    RecurrenceFormValue b,
  ) {
    if (a.frequency != b.frequency) return false;
    if (a.interval != b.interval) return false;
    if (a.count != b.count) return false;
    final aUntil = a.until;
    final bUntil = b.until;
    if (aUntil != null && bUntil != null) {
      if (!aUntil.isAtSameMomentAs(bUntil)) return false;
    } else if (aUntil != null || bUntil != null) {
      return false;
    }
    if (a.weekdays.length != b.weekdays.length) return false;
    for (final day in a.weekdays) {
      if (!b.weekdays.contains(day)) {
        return false;
      }
    }
    return true;
  }

  RecurrenceFormValue _formValueFromRule(RecurrenceRule? rule) {
    return RecurrenceFormValue.fromRule(rule);
  }

  int _defaultSelectionWeekday(List<CalendarTask> tasks) {
    for (final task in tasks) {
      final scheduled = task.scheduledTime;
      if (scheduled != null) {
        return scheduled.weekday;
      }
    }
    return DateTime.monday;
  }

  String _recurrenceSignature(RecurrenceRule? rule) {
    final effective = rule ?? RecurrenceRule.none;
    final weekdays = List<int>.from(effective.byWeekdays ?? const []);
    weekdays.sort();
    final weekdayString = weekdays.join(',');
    final until = effective.until?.toIso8601String() ?? '';
    final count = effective.count?.toString() ?? '';
    return '${effective.frequency.name}:${effective.interval}:$weekdayString:$until:$count';
  }

  bool _recurrenceEquals(RecurrenceRule a, RecurrenceRule b) {
    if (identical(a, b)) return true;
    if (a.frequency != b.frequency) return false;
    if (a.interval != b.interval) return false;
    final aUntil = a.until;
    final bUntil = b.until;
    if (aUntil != null && bUntil != null) {
      if (!aUntil.isAtSameMomentAs(bUntil)) return false;
    } else if (aUntil != null || bUntil != null) {
      return false;
    }
    if (a.count != b.count) return false;
    final aWeekdays = List<int>.from(a.byWeekdays ?? const []);
    final bWeekdays = List<int>.from(b.byWeekdays ?? const []);
    aWeekdays.sort();
    bWeekdays.sort();
    if (aWeekdays.length != bWeekdays.length) return false;
    for (var index = 0; index < aWeekdays.length; index += 1) {
      if (aWeekdays[index] != bWeekdays[index]) {
        return false;
      }
    }
    return true;
  }

  void _focusTask(CalendarTask task) {
    context.read<B>().add(
          CalendarEvent.taskFocusRequested(taskId: task.id),
        );
  }

  String _selectionScheduleLabel(CalendarTask task) {
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      return context.l10n.draftTaskNoSchedule;
    }

    final DateTime? end = task.effectiveEndDate;
    if (end != null && end.isAfter(start)) {
      if (DateUtils.isSameDay(start, end)) {
        final String dateLabel = TimeFormatter.formatFriendlyDate(start);
        final String startTime = TimeFormatter.formatTime(start);
        final String endTime = TimeFormatter.formatTime(end);
        return '$dateLabel · $startTime – $endTime';
      }
      final String startLabel = TimeFormatter.formatFriendlyDate(start);
      final String endLabel = TimeFormatter.formatFriendlyDate(end);
      return '$startLabel → $endLabel';
    }

    return TimeFormatter.formatFriendlyDateTime(start);
  }

  List<CalendarTask> _selectedTasks(CalendarState state) {
    final tasks = <CalendarTask>[];

    for (final id in state.selectedTaskIds) {
      final CalendarTask? directTask = state.model.tasks[id];
      if (directTask != null) {
        tasks.add(directTask);
        continue;
      }

      final String baseId = baseTaskIdFrom(id);
      final CalendarTask? baseTask = state.model.tasks[baseId];
      if (baseTask == null) {
        continue;
      }

      final CalendarTask? occurrence = baseTask.occurrenceForId(id);
      if (occurrence != null) {
        tasks.add(occurrence);
      }
    }

    tasks.sort((a, b) {
      final aTime = a.scheduledTime;
      final bTime = b.scheduledTime;
      if (aTime == null && bTime == null) {
        return a.title.compareTo(b.title);
      }
      if (aTime == null) return 1;
      if (bTime == null) return -1;
      final comparison = aTime.compareTo(bTime);
      return comparison != 0 ? comparison : a.title.compareTo(b.title);
    });
    return tasks;
  }

  bool _isCriticalPathCompleted(
    CalendarCriticalPath path,
    CalendarState state,
  ) {
    if (path.taskIds.isEmpty) {
      return false;
    }
    for (final String id in path.taskIds) {
      final CalendarTask? task =
          state.model.tasks[baseTaskIdFrom(id)] ?? state.model.tasks[id];
      if (task == null || !task.isCompleted) {
        return false;
      }
    }
    return true;
  }

  bool _isTaskOnlyInCompletedPaths(CalendarTask task, CalendarState state) {
    final List<CalendarCriticalPath> paths = state.criticalPathsForTask(task);
    if (paths.isEmpty) {
      return false;
    }
    return paths.every((path) => _isCriticalPathCompleted(path, state));
  }

  void _handleSidebarSectionDragEnter(CalendarSidebarSection section) {
    _sidebarController.expandSection(section);
  }

  void _handleTaskDroppedIntoSidebar(CalendarTask dropped) {
    CalendarTask? source = context.read<B>().state.model.tasks[dropped.id] ??
        context.read<B>().state.model.tasks[dropped.baseId];
    source ??= context.read<B>().state.model.resolveTaskInstance(dropped.id);
    if (source == null) {
      FeedbackSystem.showError(context, context.l10n.calendarTaskNotFound);
      return;
    }
    final CalendarTask unscheduled = source.copyWith(
      scheduledTime: null,
      duration: null,
      endDate: null,
      startHour: null,
      modifiedAt: DateTime.now(),
    );
    context.read<B>().add(
          CalendarEvent.taskUpdated(
            task: unscheduled,
          ),
        );
  }

  void _handleSidebarDragSessionStarted() {
    if (_isTouchOnlyInput) {
      _sidebarController.expandSection(CalendarSidebarSection.unscheduled);
    }
    widget.onDragSessionStarted?.call();
  }

  void _handleSidebarDragSessionEnded() {
    _stopSidebarAutoScroll();
    widget.onDragSessionEnded?.call();
  }

  void _forwardSidebarGlobalPosition(
    Offset globalPosition, {
    bool notifyParent = true,
  }) {
    _handleSidebarAutoScroll(globalPosition);
    if (notifyParent) {
      widget.onDragGlobalPositionChanged?.call(globalPosition);
    }
  }

  void _handleSidebarDragTargetHover(CalendarDropDetails details) {
    _forwardSidebarGlobalPosition(
      details.globalPosition,
      notifyParent: false,
    );
  }

  void _handleSidebarAutoScroll(Offset globalPosition) {
    if (!_scrollController.hasClients) {
      _stopSidebarAutoScroll();
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (!position.hasPixels ||
        (position.maxScrollExtent - position.minScrollExtent).abs() <= 0.5) {
      _stopSidebarAutoScroll();
      return;
    }
    final BuildContext? viewportContext = _scrollViewportKey.currentContext;
    final RenderBox? viewport =
        viewportContext?.findRenderObject() as RenderBox?;
    if (viewport == null || !viewport.hasSize) {
      _stopSidebarAutoScroll();
      return;
    }
    final Size viewportSize = viewport.size;
    final double height = viewportSize.height;
    if (!height.isFinite || height <= 0) {
      _stopSidebarAutoScroll();
      return;
    }
    final double width = viewportSize.width;
    if (!width.isFinite || width <= 0) {
      _stopSidebarAutoScroll();
      return;
    }
    final Offset local = viewport.globalToLocal(globalPosition);
    final double pointerX = local.dx;
    final bool isPointerWithinSidebar =
        pointerX >= -_autoScrollHorizontalSlop &&
            pointerX <= width + _autoScrollHorizontalSlop;
    if (!isPointerWithinSidebar) {
      _stopSidebarAutoScroll();
      return;
    }
    if (local.dy < 0 || local.dy > height) {
      _stopSidebarAutoScroll();
      return;
    }

    final double fastBandHeight =
        math.min(_layoutTheme.edgeScrollFastBandHeight, height / 2);
    final double slowBandHeight =
        math.min(_layoutTheme.edgeScrollSlowBandHeight, height / 2);
    final double fastSpeed = _layoutTheme.edgeScrollFastOffsetPerFrame;
    final double slowSpeed = _layoutTheme.edgeScrollSlowOffsetPerFrame;

    double? offsetPerFrame;
    if (local.dy <= fastBandHeight || local.dy < 0) {
      offsetPerFrame = -fastSpeed;
    } else if (local.dy <= fastBandHeight + slowBandHeight) {
      offsetPerFrame = -slowSpeed;
    } else if (local.dy >= height - fastBandHeight || local.dy > height) {
      offsetPerFrame = fastSpeed;
    } else if (local.dy >= height - (fastBandHeight + slowBandHeight)) {
      offsetPerFrame = slowSpeed;
    }

    if (offsetPerFrame == null) {
      _stopSidebarAutoScroll();
      return;
    }

    final double currentOffset = position.pixels;
    if ((offsetPerFrame < 0 &&
            currentOffset <= position.minScrollExtent + 0.5) ||
        (offsetPerFrame > 0 &&
            currentOffset >= position.maxScrollExtent - 0.5)) {
      _stopSidebarAutoScroll();
      return;
    }

    _startSidebarAutoScroll(offsetPerFrame);
  }

  void _startSidebarAutoScroll(double offsetPerFrame) {
    _sidebarAutoScrollOffsetPerFrame = offsetPerFrame;
    _sidebarAutoScrollTicker ??= createTicker(_onSidebarAutoScrollTick);
    if (!(_sidebarAutoScrollTicker!.isActive)) {
      _sidebarAutoScrollTicker!.start();
    }
  }

  void _onSidebarAutoScrollTick(Duration elapsed) {
    if (_sidebarAutoScrollOffsetPerFrame.abs() < 0.01 ||
        !_scrollController.hasClients) {
      _stopSidebarAutoScroll();
      return;
    }
    final ScrollPosition position = _scrollController.position;
    if (!position.hasPixels) {
      _stopSidebarAutoScroll();
      return;
    }
    final double currentOffset = _scrollController.offset;
    final double nextOffset = (currentOffset + _sidebarAutoScrollOffsetPerFrame)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((nextOffset - currentOffset).abs() <= 0.1) {
      _stopSidebarAutoScroll();
      return;
    }
    _scrollController.jumpTo(nextOffset);
  }

  void _stopSidebarAutoScroll() {
    _sidebarAutoScrollOffsetPerFrame = 0;
    if (_sidebarAutoScrollTicker?.isActive ?? false) {
      _sidebarAutoScrollTicker!.stop();
    }
  }

  void _handleResizePointerDown(PointerDownEvent event) {
    if (_activeResizePointerId != null) {
      return;
    }
    _activeResizePointerId = event.pointer;
    _sidebarController.beginResize();
  }

  void _handleResizePointerMove(PointerMoveEvent event) {
    if (_activeResizePointerId != event.pointer) {
      return;
    }
    final double deltaX = event.delta.dx;
    if (deltaX == 0) {
      return;
    }
    _sidebarController.adjustWidth(deltaX);
  }

  void _handleResizePointerUp(PointerUpEvent event) {
    if (_activeResizePointerId != event.pointer) {
      return;
    }
    _activeResizePointerId = null;
    _sidebarController.endResize();
  }

  void _handleResizePointerCancel(PointerCancelEvent event) {
    if (_activeResizePointerId != event.pointer) {
      return;
    }
    _activeResizePointerId = null;
    _sidebarController.endResize();
  }

  Widget _wrapWithSidebarContextMenu({
    required CalendarTask task,
    required Widget child,
  }) {
    return ShadContextMenuRegion(
      items: _sidebarContextMenuItems(task),
      child: child,
    );
  }

  Widget _buildDraggableSidebarTaskTile(
    CalendarTask task, {
    required CalendarSidebarState uiState,
    Widget? trailing,
    bool requiresLongPress = false,
  }) {
    return _SidebarDraggableTaskTile<B>(
      host: this,
      task: task,
      uiState: uiState,
      trailing: trailing,
      requiresLongPress: requiresLongPress,
    );
  }

  Widget buildSearchTaskTile(
    CalendarTask task, {
    Widget? trailing,
    bool requiresLongPress = false,
    VoidCallback? onTap,
    VoidCallback? onDragStart,
    bool allowContextMenu = false,
  }) {
    return _SidebarDraggableTaskTile<B>(
      host: this,
      task: task,
      uiState: _sidebarController.state,
      trailing: trailing,
      requiresLongPress: requiresLongPress,
      enableInteraction: true,
      onTapOverride: onTap,
      allowContextMenu: allowContextMenu,
      onDragStart: onDragStart,
    );
  }

  bool get requiresLongPressForDrag => _isTouchOnlyInput;

  List<TaskContextAction> _sidebarInlineActions(CalendarTask task) {
    return [
      TaskContextAction(
        icon: Icons.copy_outlined,
        label: context.l10n.chatActionCopy,
        onSelected: () => _copyTaskDetails(task),
      ),
      TaskContextAction(
        icon: Icons.share_outlined,
        label: context.l10n.calendarCopyToClipboardAction,
        onSelected: () => _copyTaskShareText(task),
      ),
      TaskContextAction(
        icon: Icons.route,
        label: 'Add to critical path',
        onSelected: () => _showAddToCriticalPathPicker(task),
      ),
    ];
  }

  void _copyTaskDetails(CalendarTask task) {
    final buffer = StringBuffer();
    if (task.title.trim().isNotEmpty) {
      buffer.writeln(task.title.trim());
    }
    final description = task.description?.trim();
    if (description != null && description.isNotEmpty) {
      buffer.writeln(description);
    }
    final location = task.location?.trim();
    if (location != null && location.isNotEmpty) {
      buffer.writeln(context.l10n.calendarCopyLocation(location));
    }
    final deadline = task.deadline;
    if (deadline != null) {
      buffer.writeln(
        context.l10n.draftTaskDue(
          TimeFormatter.formatFriendlyDateTime(deadline),
        ),
      );
    }
    final payload = buffer.toString().trim().isEmpty
        ? task.title.trim()
        : buffer.toString().trim();
    Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      FeedbackSystem.showSuccess(context, context.l10n.calendarTaskCopied);
    }
  }

  Future<void> _copyTaskShareText(CalendarTask task) async {
    final String payload = task.toShareText();
    await Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      FeedbackSystem.showSuccess(
        context,
        context.l10n.calendarTaskCopiedClipboard,
      );
    }
  }

  Future<void> _handleCreateCriticalPath({String? taskId}) async {
    await _promptForCriticalPathName(
      title: 'New critical path',
      onSubmit: (name) {
        context.read<B>().add(
              CalendarEvent.criticalPathCreated(
                name: name,
                taskId: taskId,
              ),
            );
      },
    );
  }

  Future<void> _handleRenameCriticalPath(CalendarCriticalPath path) async {
    await _promptForCriticalPathName(
      title: 'Rename critical path',
      initialValue: path.name,
      onSubmit: (name) {
        context.read<B>().add(
              CalendarEvent.criticalPathRenamed(
                pathId: path.id,
                name: name,
              ),
            );
      },
    );
    if (!mounted) {
      return;
    }
  }

  Future<void> _handleDeleteCriticalPath(CalendarCriticalPath path) async {
    final bool confirmed = await _confirmCriticalPathDeletion(path);
    if (!mounted) {
      return;
    }
    if (!confirmed) {
      return;
    }
    if (_activeCriticalPathId == path.id) {
      setState(() {
        _activeCriticalPathId = null;
      });
    }
    context.read<B>().add(
          CalendarEvent.criticalPathDeleted(pathId: path.id),
        );
  }

  void _handleFocusCriticalPath(CalendarCriticalPath? path) {
    context.read<B>().add(
          CalendarEvent.criticalPathFocused(pathId: path?.id),
        );
  }

  void _handleOpenCriticalPath(CalendarCriticalPath path) {
    setState(() {
      if (_activeCriticalPathId == path.id) {
        _activeCriticalPathId = null;
        return;
      }
      _criticalPathsExpanded = true;
      _activeCriticalPathId = path.id;
    });
  }

  void _closeActiveCriticalPath() {
    if (_activeCriticalPathId == null) {
      return;
    }
    setState(() {
      _activeCriticalPathId = null;
    });
  }

  void _toggleCriticalPathsExpanded() {
    setState(() {
      _criticalPathsExpanded = !_criticalPathsExpanded;
      if (!_criticalPathsExpanded) {
        _activeCriticalPathId = null;
      }
    });
  }

  void _showAddTaskSection() {
    setState(() {
      _criticalPathsExpanded = false;
      _activeCriticalPathId = null;
    });
  }

  void _handleCriticalPathReorder(
    String pathId,
    List<String> orderedTaskIds,
  ) {
    context.read<B>().add(
          CalendarEvent.criticalPathReordered(
            pathId: pathId,
            orderedTaskIds: orderedTaskIds,
          ),
        );
  }

  Future<void> _openCriticalPathSearch() async {
    final CalendarCriticalPath? targetPath = _activeCriticalPathId != null
        ? context.read<B>().state.model.criticalPaths[_activeCriticalPathId!]
        : context.read<B>().state.focusedCriticalPath;
    if (targetPath == null) {
      return;
    }
    await showCalendarTaskSearch(
      context: context,
      bloc: context.read<B>(),
      locate: context.read,
      targetPath: targetPath,
      requiresLongPressForDrag: requiresLongPressForDrag,
      taskTileBuilder: (
        CalendarTask task, {
        Widget? trailing,
        bool requiresLongPress = false,
        VoidCallback? onTap,
        VoidCallback? onDragStart,
        bool allowContextMenu = false,
      }) =>
          buildSearchTaskTile(
        task,
        trailing: trailing,
        requiresLongPress: requiresLongPress,
        onTap: onTap,
        onDragStart: onDragStart,
        allowContextMenu: allowContextMenu,
      ),
    );
  }

  Future<void> _showAddToCriticalPathPicker(CalendarTask task) async {
    final CriticalPathPickerResult? result = await showCriticalPathPicker(
      context: context,
      paths: context.read<B>().state.criticalPaths,
    );
    if (!mounted) {
      return;
    }
    if (result == null) {
      return;
    }
    if (result.createNew) {
      await _handleCreateCriticalPath(taskId: task.id);
      return;
    }
    final String? pathId = result.pathId;
    if (pathId != null) {
      context.read<B>().add(
            CalendarEvent.criticalPathTaskAdded(
              pathId: pathId,
              taskId: task.id,
            ),
          );
    }
  }

  void _toggleSidebarTaskCompletion(CalendarTask task, bool completed) {
    context.read<B>().add(
          CalendarEvent.taskCompleted(
            taskId: task.baseId,
            completed: completed,
          ),
        );
  }

  Future<void> _promptForCriticalPathName({
    required String title,
    String? initialValue,
    required ValueChanged<String> onSubmit,
  }) async {
    final String? name = await promptCriticalPathName(
      context: context,
      title: title,
      initialValue: initialValue,
    );
    if (name != null) {
      onSubmit(name);
    }
  }

  Future<bool> _confirmCriticalPathDeletion(CalendarCriticalPath path) async {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final result = await showAdaptiveBottomSheet<bool>(
      context: context,
      dialogMaxWidth: 420,
      surfacePadding: const EdgeInsets.all(calendarGutterLg),
      builder: (sheetContext) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Delete critical path',
                    style: textTheme.h3.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                AxiIconButton(
                  iconData: Icons.close,
                  iconSize: 16,
                  buttonSize: 34,
                  tapTargetSize: 40,
                  backgroundColor: Colors.transparent,
                  borderColor: Colors.transparent,
                  color: colors.mutedForeground,
                  onPressed: () => Navigator.of(sheetContext).maybePop(false),
                ),
              ],
            ),
            const SizedBox(height: calendarGutterSm),
            Text(
              context.l10n.calendarRemovePathConfirm(path.name),
              style: textTheme.muted,
            ),
            const SizedBox(height: calendarGutterMd),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ShadButton.ghost(
                  onPressed: () => Navigator.of(sheetContext).maybePop(false),
                  child: Text(context.l10n.commonCancel),
                ).withTapBounce(),
                const SizedBox(width: calendarInsetSm),
                ShadButton.destructive(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text('Delete'),
                ).withTapBounce(),
              ],
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  void _deleteSidebarTask(CalendarTask task) {
    context.read<B>().add(CalendarEvent.taskDeleted(taskId: task.id));
    _closeTaskPopover(task.id);
    _taskPopoverControllers.remove(task.id)?.dispose();
  }

  List<Widget> _sidebarContextMenuItems(CalendarTask task) {
    return [
      ShadContextMenuItem(
        leading: const Icon(Icons.copy_outlined),
        onPressed: () => _copyTaskDetails(task),
        child: Text(context.l10n.calendarCopyTask),
      ),
      ShadContextMenuItem(
        leading: const Icon(Icons.share_outlined),
        onPressed: () => _copyTaskShareText(task),
        child: Text(context.l10n.calendarCopyToClipboardAction),
      ),
      ShadContextMenuItem(
        leading: const Icon(Icons.route),
        onPressed: () => _showAddToCriticalPathPicker(task),
        child: Text(context.l10n.calendarCriticalPathAddToTitle),
      ),
      ShadContextMenuItem(
        leading: const Icon(Icons.delete_outline),
        onPressed: () => _deleteSidebarTask(task),
        child: Text(context.l10n.calendarDeleteTask),
      ),
    ];
  }

  bool _shouldUseSheetMenus(BuildContext context) {
    final bool hasMouse =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    final commandSurface = resolveCommandSurface(context);
    if (commandSurface == CommandSurface.menu) {
      return false;
    }
    return ResponsiveHelper.isCompact(context) || !hasMouse;
  }

  Future<void> _showTaskEditSheet(
    BuildContext context,
    CalendarTask task,
  ) async {
    if (!TaskEditSessionTracker.instance.begin(task.id, this)) {
      return;
    }

    final String baseId = task.baseId;
    final locate = context.read;
    final CalendarTask latestTask =
        locate<B>().state.model.tasks[baseId] ?? task;
    final CalendarTask? storedTask = locate<B>().state.model.tasks[task.id];
    final CalendarTask? occurrenceTask = storedTask == null && task.isOccurrence
        ? latestTask.occurrenceForId(task.id)
        : null;
    final CalendarTask displayTask = storedTask ?? occurrenceTask ?? latestTask;
    final bool shouldUpdateOccurrence =
        storedTask == null && occurrenceTask != null;
    final scaffoldMessenger = ScaffoldMessenger.maybeOf(context);
    final MediaQueryData hostMediaQuery = MediaQuery.of(context);
    final MediaQueryData viewMedia = MediaQueryData.fromView(View.of(context));
    final double safeTopInset = viewMedia.viewPadding.top;
    final double safeBottomInset = viewMedia.viewPadding.bottom;

    try {
      await showAdaptiveBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          final mediaQuery = MediaQuery.of(sheetContext);
          final double keyboardInset = mediaQuery.viewInsets.bottom;
          final double bottomInset = math.max(safeBottomInset, keyboardInset);
          final double availableHeight =
              hostMediaQuery.size.height - safeTopInset - bottomInset;
          final double maxHeight = availableHeight > 0
              ? availableHeight
              : hostMediaQuery.size.height - safeTopInset;
          void closeSheet() {
            _sidebarController.setActivePopoverTaskId(null);
            TaskEditSessionTracker.instance.end(task.id, this);
            Navigator.of(sheetContext).maybePop();
          }

          return BlocProvider.value(
            value: locate<B>(),
            child: Builder(
              builder: (context) => AnimatedPadding(
                padding: EdgeInsets.only(
                  top: safeTopInset,
                  bottom: bottomInset,
                  left: hostMediaQuery.padding.left,
                  right: hostMediaQuery.padding.right,
                ),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: EditTaskDropdown<B>(
                  task: displayTask,
                  maxHeight: maxHeight,
                  isSheet: true,
                  inlineActionsBloc: locate<B>(),
                  inlineActionsBuilder: (_) =>
                      _sidebarInlineActions(displayTask),
                  onClose: closeSheet,
                  scaffoldMessenger: scaffoldMessenger,
                  locationHelper: LocationAutocompleteHelper.fromState(
                    locate<B>().state,
                  ),
                  onTaskUpdated: (updatedTask) {
                    locate<B>().add(
                      CalendarEvent.taskUpdated(
                        task: updatedTask,
                      ),
                    );
                  },
                  onOccurrenceUpdated: shouldUpdateOccurrence
                      ? (updatedTask) {
                          locate<B>().add(
                            CalendarEvent.taskOccurrenceUpdated(
                              taskId: baseId,
                              occurrenceId: task.id,
                              scheduledTime: updatedTask.scheduledTime,
                              duration: updatedTask.duration,
                              endDate: updatedTask.endDate,
                              checklist: updatedTask.checklist,
                            ),
                          );

                          final CalendarTask seriesUpdate = latestTask.copyWith(
                            title: updatedTask.title,
                            description: updatedTask.description,
                            location: updatedTask.location,
                            deadline: updatedTask.deadline,
                            priority: updatedTask.priority,
                            isCompleted: updatedTask.isCompleted,
                            checklist: updatedTask.checklist,
                            modifiedAt: DateTime.now(),
                          );

                          if (seriesUpdate != latestTask) {
                            locate<B>().add(
                              CalendarEvent.taskUpdated(
                                task: seriesUpdate,
                              ),
                            );
                          }
                        }
                      : null,
                  onTaskDeleted: (taskId) {
                    locate<B>().add(
                      CalendarEvent.taskDeleted(
                        taskId: taskId,
                      ),
                    );
                    _taskPopoverControllers.remove(task.id)?.dispose();
                    _sidebarController.setActivePopoverTaskId(null);
                    Navigator.of(sheetContext).maybePop();
                  },
                ),
              ),
            ),
          );
        },
      );
    } finally {
      TaskEditSessionTracker.instance.end(task.id, this);
    }
  }

  @visibleForTesting
  CalendarSidebarState get debugSidebarState => _sidebarController.state;

  List<CalendarTask> _sortTasksByDeadline(List<CalendarTask> tasks) {
    final List<CalendarTask> tasksCopy = List.from(tasks);
    tasksCopy.sort((a, b) {
      final now = DateTime.now();

      int getDeadlineCategory(DateTime? deadline) {
        if (deadline == null) return 4; // No deadline
        if (deadline.isBefore(now)) return 1; // Overdue
        if (deadline.isBefore(now.add(const Duration(hours: 24)))) return 2;
        return 3; // Future
      }

      final categoryA = getDeadlineCategory(a.deadline);
      final categoryB = getDeadlineCategory(b.deadline);

      if (categoryA != categoryB) {
        return categoryA.compareTo(categoryB);
      }

      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }

      return b.createdAt.compareTo(a.createdAt);
    });

    return tasksCopy;
  }

  List<String> _deriveOrder(List<CalendarTask> tasks, List<String> cache) {
    final Set<String> presentIds = tasks.map((task) => task.id).toSet();
    final Set<String> seen = <String>{};
    final List<String> order = <String>[];
    for (final String id in cache) {
      if (presentIds.contains(id) && seen.add(id)) {
        order.add(id);
      }
    }
    for (final CalendarTask task in tasks) {
      if (seen.add(task.id)) {
        order.add(task.id);
      }
    }
    return order;
  }

  List<CalendarTask> _orderedTasksFromOrder(
    List<CalendarTask> tasks,
    List<String> order,
  ) {
    final Map<String, int> positions = {
      for (var i = 0; i < order.length; i++) order[i]: i,
    };
    final List<CalendarTask> ordered = tasks.toList()
      ..sort(
        (a, b) {
          final int indexA = positions[a.id] ?? order.length;
          final int indexB = positions[b.id] ?? order.length;
          return indexA.compareTo(indexB);
        },
      );
    return ordered;
  }

  void _handleTaskListReorder({
    required List<CalendarTask> tasks,
    required List<String> cache,
    required void Function(List<String> nextOrder) updateCache,
    required int oldIndex,
    required int newIndex,
  }) {
    if (tasks.isEmpty) {
      return;
    }
    final List<String> order = _deriveOrder(tasks, cache);
    if (oldIndex < 0 || oldIndex >= order.length) {
      return;
    }
    int targetIndex = newIndex;
    if (newIndex > oldIndex) {
      targetIndex -= 1;
    }
    if (targetIndex < 0 || targetIndex > order.length) {
      return;
    }
    setState(() {
      final List<String> nextOrder = List<String>.from(order);
      final String moved = nextOrder.removeAt(oldIndex);
      nextOrder.insert(targetIndex, moved);
      updateCache(nextOrder);
    });
  }

  TaskPriority _currentPriority() {
    return _draftController.selectedPriority;
  }

  bool get _shouldValidateQuickTask =>
      _hasAttemptedQuickTaskSubmit || _quickTaskError != null;

  AutovalidateMode get _quickTaskAutovalidateMode => _shouldValidateQuickTask
      ? AutovalidateMode.always
      : AutovalidateMode.disabled;

  String? _validateQuickTaskTitle(String? raw) {
    if (_quickTaskError != null) {
      return _quickTaskError;
    }
    return TaskTitleValidation.validate(raw ?? '');
  }

  List<CalendarCriticalPath> _queuedPathsForState(CalendarState state) {
    final Map<String, CalendarCriticalPath> byId = state.model.criticalPaths;
    return _queuedCriticalPathIds
        .map((id) => byId[id])
        .whereType<CalendarCriticalPath>()
        .toList();
  }

  void _activateQuickTaskValidation() {
    if (_hasAttemptedQuickTaskSubmit) {
      return;
    }
    setState(() {
      _hasAttemptedQuickTaskSubmit = true;
    });
  }

  void _clearQuickTaskValidationState() {
    if (!_hasAttemptedQuickTaskSubmit && _quickTaskError == null) {
      return;
    }
    setState(() {
      _hasAttemptedQuickTaskSubmit = false;
      _quickTaskError = null;
    });
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

  void _clearQueuedCriticalPaths() {
    if (_queuedCriticalPathIds.isEmpty) {
      return;
    }
    setState(() => _queuedCriticalPathIds.clear());
  }

  Future<void> _queueCriticalPathForDraft() async {
    final locate = context.read;
    await showCriticalPathPicker(
      context: context,
      paths: locate<B>().state.criticalPaths,
      stayOpen: true,
      onPathSelected: (path) async {
        _addQueuedCriticalPath(path.id);
        return 'Will add to "${path.name}" on save';
      },
      onCreateNewPath: () async {
        final String? name = await promptCriticalPathName(
          context: context,
          title: context.l10n.calendarCriticalPathsNew,
        );
        if (!mounted || name == null) {
          return null;
        }
        final Set<String> previousIds =
            locate<B>().state.criticalPaths.map((path) => path.id).toSet();
        locate<B>().add(CalendarEvent.criticalPathCreated(name: name));
        final String? createdId = await waitForNewPathId(
          bloc: locate<B>(),
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

  Future<void> _addTask() async {
    _activateQuickTaskValidation();
    final bool isValid = _addTaskFormKey.currentState?.validate() ?? false;
    if (!isValid) {
      _titleFocusNode.requestFocus();
      return;
    }

    final rawTitle = _titleController.text.trim();
    if (rawTitle.isEmpty) return;
    if (_quickTaskError != null) {
      setState(() {
        _quickTaskError = null;
      });
      _addTaskFormKey.currentState?.validate();
    }
    final title = _effectiveParserTitle(rawTitle);

    final priority = _currentPriority();
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSchedule =
        _draftController.startTime != null && _draftController.endTime != null;
    final hasRecurrence = _advancedRecurrence.isActive;

    final List<String> queuedPathIds =
        List<String>.from(_queuedCriticalPathIds);
    final bool hasQueuedCriticalPaths = queuedPathIds.isNotEmpty;
    final locate = context.read;
    final Set<String>? previousIds = hasQueuedCriticalPaths
        ? locate<B>().state.model.tasks.keys.toSet()
        : null;

    if (!hasLocation && !hasSchedule && !hasRecurrence) {
      locate<B>().add(
        CalendarEvent.quickTaskAdded(
          text: title,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          deadline: _draftController.deadline,
          priority: priority,
          checklist: _checklistController.items.toList(),
          reminders: _draftController.reminders,
        ),
      );
    } else {
      final DateTime? scheduledTime = _draftController.startTime;
      final Duration? duration = hasSchedule
          ? _draftController.effectiveDuration ?? const Duration(minutes: 15)
          : null;

      RecurrenceRule? recurrence;
      if (hasRecurrence) {
        final reference = scheduledTime ?? DateTime.now();
        recurrence = _advancedRecurrence.toRule(start: reference);
      }

      locate<B>().add(
        CalendarEvent.taskAdded(
          title: title,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          scheduledTime: scheduledTime,
          duration: duration,
          deadline: _draftController.deadline,
          location: hasLocation ? _locationController.text.trim() : null,
          priority: priority,
          recurrence: recurrence,
          checklist: _checklistController.items.toList(),
          reminders: _draftController.reminders,
        ),
      );
    }

    _clearQuickTaskTitle();

    if (hasQueuedCriticalPaths && previousIds != null) {
      final CalendarTask? createdTask = await _waitForNewTask(previousIds);
      if (!mounted) return;
      if (createdTask != null) {
        for (final String pathId in queuedPathIds) {
          locate<B>().add(
            CalendarEvent.criticalPathTaskAdded(
              pathId: pathId,
              taskId: createdTask.id,
            ),
          );
        }
      } else {
        setState(() {
          _quickTaskError =
              'Task saved but could not be added to a critical path.';
        });
        _addTaskFormKey.currentState?.validate();
      }
    }
  }

  void _clearQuickTaskTitle() {
    _preserveDraftFieldsOnTitleClear = true;
    _clearQuickTaskValidationState();
    _titleController.clear();
    _addTaskFormKey.currentState?.reset();
    _handleQuickTaskInputChanged('', validate: false);
    _titleFocusNode.requestFocus();
  }

  void _handleClearFieldsPressed() {
    _resetForm();
  }

  void _resetForm() {
    _clearParserState(clearFields: true);
    _resetParserLocks();
    _clearQuickTaskValidationState();
    _clearQueuedCriticalPaths();
    _addTaskFormKey.currentState?.reset();
    if (_titleController.text.isNotEmpty) {
      _titleController.clear();
    }
    if (_descriptionController.text.isNotEmpty) {
      _descriptionController.clear();
    }
    if (_locationController.text.isNotEmpty) {
      _locationController.clear();
    }
    _checklistController.clear();
    if (mounted) {
      FocusScope.of(context).requestFocus(_titleFocusNode);
    }
  }

  Future<CalendarTask?> _waitForNewTask(Set<String> previousIds) async {
    try {
      final Set<String> difference = (await context
              .read<B>()
              .stream
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
      return context.read<B>().state.model.tasks[taskId];
    } on TimeoutException {
      return null;
    }
  }

  ShadPopoverController _popoverControllerFor(String taskId) {
    if (_taskPopoverControllers.containsKey(taskId)) {
      return _taskPopoverControllers[taskId]!;
    }
    final controller = ShadPopoverController();
    controller.addListener(() {
      if (!mounted) return;
      if (!controller.isOpen) {
        if (_sidebarController.state.activePopoverTaskId == taskId) {
          _sidebarController.setActivePopoverTaskId(null);
        }
        TaskEditSessionTracker.instance.end(taskId, this);
      }
    });
    _taskPopoverControllers[taskId] = controller;
    return controller;
  }

  void _toggleTaskPopover(String taskId) {
    final controller = _popoverControllerFor(taskId);
    if (controller.isOpen) {
      _closeTaskPopover(taskId);
    } else {
      _openTaskPopover(taskId);
    }
  }

  void _openTaskPopover(String taskId) {
    if (!TaskEditSessionTracker.instance.begin(taskId, this)) {
      return;
    }

    final controller = _popoverControllerFor(taskId);
    final String? activeId = _sidebarController.state.activePopoverTaskId;
    if (activeId != null && activeId != taskId) {
      final activeController = _taskPopoverControllers[activeId];
      activeController?.hide();
    }
    controller.show();
    if (activeId != taskId) {
      _sidebarController.setActivePopoverTaskId(taskId);
    }
  }

  void _closeTaskPopover([String? taskId]) {
    final String? id = taskId ?? _sidebarController.state.activePopoverTaskId;
    if (id == null) {
      return;
    }
    final controller = _taskPopoverControllers[id];
    controller?.hide();
    if (_sidebarController.state.activePopoverTaskId == id && mounted) {
      _sidebarController.setActivePopoverTaskId(null);
    }
    TaskEditSessionTracker.instance.end(id, this);
  }
}

class _SelectionAdjustButton extends StatelessWidget {
  const _SelectionAdjustButton({
    required this.label,
    this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TaskSecondaryButton(
      label: label,
      onPressed: onPressed,
    );
  }
}

class _SelectionPanel<B extends BaseCalendarBloc> extends StatelessWidget {
  const _SelectionPanel({
    required this.tasks,
    required this.uiState,
    required this.locationHelper,
    required this.onExitSelection,
    required this.onClearSelection,
    required this.onExportSelected,
    required this.onDeleteSelected,
    required this.selectionTitleController,
    required this.selectionDescriptionController,
    required this.selectionLocationController,
    required this.selectionChecklistController,
    required this.onSelectionTitleChanged,
    required this.onSelectionDescriptionChanged,
    required this.onSelectionLocationChanged,
    required this.hasPendingSelectionEdits,
    required this.onApplySelectionChanges,
    required this.timeAdjustCallbacks,
    required this.onPriorityChanged,
    required this.onCompletionChanged,
    required this.remindersNotifier,
    required this.remindersMixedNotifier,
    required this.onRemindersChanged,
    required this.recurrenceNotifier,
    required this.recurrenceMixedNotifier,
    required this.fallbackWeekday,
    required this.onRecurrenceChanged,
    required this.scheduleLabelBuilder,
    required this.onFocusTask,
    required this.onRemoveTask,
    required this.onToggleCompletion,
    required this.reminderAnchorNotifier,
    this.selectionMessage,
  });

  final List<CalendarTask> tasks;
  final CalendarSidebarState uiState;
  final LocationAutocompleteHelper locationHelper;
  final VoidCallback onExitSelection;
  final VoidCallback onClearSelection;
  final VoidCallback onExportSelected;
  final VoidCallback onDeleteSelected;
  final TextEditingController selectionTitleController;
  final TextEditingController selectionDescriptionController;
  final TextEditingController selectionLocationController;
  final TaskChecklistController selectionChecklistController;
  final ValueChanged<String> onSelectionTitleChanged;
  final ValueChanged<String> onSelectionDescriptionChanged;
  final ValueChanged<String> onSelectionLocationChanged;
  final bool hasPendingSelectionEdits;
  final VoidCallback onApplySelectionChanges;
  final _SelectionTimeAdjustCallbacks timeAdjustCallbacks;
  final ValueChanged<TaskPriority> onPriorityChanged;
  final ValueChanged<bool> onCompletionChanged;
  final ValueListenable<ReminderPreferences> remindersNotifier;
  final ValueListenable<bool> remindersMixedNotifier;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final ValueListenable<RecurrenceFormValue> recurrenceNotifier;
  final ValueListenable<bool> recurrenceMixedNotifier;
  final int fallbackWeekday;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final String Function(CalendarTask task) scheduleLabelBuilder;
  final ValueChanged<CalendarTask> onFocusTask;
  final ValueChanged<CalendarTask> onRemoveTask;
  final void Function(CalendarTask task, bool completed) onToggleCompletion;
  final ValueListenable<ReminderAnchor> reminderAnchorNotifier;
  final String? selectionMessage;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final total = tasks.length;
    final hasTasks = total > 0;
    final bool allCompleted =
        hasTasks && tasks.every((task) => task.isCompleted);
    final bool anyCompleted = tasks.any((task) => task.isCompleted);
    final bool completionIndeterminate =
        hasTasks && anyCompleted && !allCompleted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSwitcher(
          duration: baseAnimationDuration,
          child: selectionMessage == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                      calendarGutterLg, 0, calendarGutterLg, calendarGutterSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: calendarGutterMd,
                      vertical: calendarInsetLg,
                    ),
                    decoration: BoxDecoration(
                      color: calendarPrimaryColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(calendarBorderRadius),
                      border: Border.all(
                        color: calendarPrimaryColor.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: calendarPrimaryColor,
                        ),
                        const SizedBox(width: calendarInsetLg),
                        Expanded(
                          child: Text(
                            selectionMessage!,
                            style: context.textTheme.small.copyWith(
                              color: calendarPrimaryColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterLg,
            vertical: calendarGutterLg,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: calendarBorderColor,
                width: calendarBorderStroke,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskSectionHeader(
                title: l10n.calendarSelectionMode,
                padding: const EdgeInsets.only(bottom: calendarGutterSm),
                trailing: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: onExitSelection,
                  child: Text(l10n.calendarExit),
                ),
              ),
              Text(
                l10n.calendarTasksSelected(total).replaceAll(
                      '#',
                      '$total',
                    ),
                style: calendarSubtitleTextStyle,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              TaskSectionHeader(title: l10n.calendarActions),
              const SizedBox(height: calendarGutterSm),
              _SelectionActionsRow<B>(
                hasTasks: hasTasks,
                tasks: tasks,
                onClearSelection: onClearSelection,
                onExportSelected: onExportSelected,
                onDeleteSelected: onDeleteSelected,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              _SelectionBatchEditSection(
                hasTasks: hasTasks,
                titleController: selectionTitleController,
                descriptionController: selectionDescriptionController,
                locationController: selectionLocationController,
                checklistController: selectionChecklistController,
                locationHelper: locationHelper,
                onTitleChanged: onSelectionTitleChanged,
                onDescriptionChanged: onSelectionDescriptionChanged,
                onLocationChanged: onSelectionLocationChanged,
                hasPendingSelectionEdits: hasPendingSelectionEdits,
                onApplyChanges: onApplySelectionChanges,
                timeAdjustCallbacks: timeAdjustCallbacks,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              TaskSectionHeader(title: l10n.calendarSetPriority),
              const SizedBox(height: calendarGutterSm),
              _SelectionPriorityControls(
                tasks: tasks,
                onPriorityChanged: onPriorityChanged,
              ),
              const SizedBox(height: calendarGutterMd),
              _SelectionCompletionToggle(
                hasTasks: hasTasks,
                allCompleted: allCompleted,
                isIndeterminate: completionIndeterminate,
                onChanged: onCompletionChanged,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              _SelectionReminderSection(
                hasTasks: hasTasks,
                remindersListenable: remindersNotifier,
                mixedListenable: remindersMixedNotifier,
                anchorListenable: reminderAnchorNotifier,
                onChanged: onRemindersChanged,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              _SelectionRecurrenceSection(
                hasTasks: hasTasks,
                fallbackWeekday: fallbackWeekday,
                recurrenceListenable: recurrenceNotifier,
                mixedListenable: recurrenceMixedNotifier,
                onChanged: onRecurrenceChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: calendarGutterLg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarGutterLg),
          child: _SelectedTaskList(
            tasks: tasks,
            uiState: uiState,
            scheduleLabelBuilder: scheduleLabelBuilder,
            onFocusTask: onFocusTask,
            onRemoveTask: onRemoveTask,
            onToggleCompletion: onToggleCompletion,
          ),
        ),
      ],
    );
  }
}

class _SelectionActionsRow<B extends BaseCalendarBloc> extends StatelessWidget {
  const _SelectionActionsRow({
    required this.hasTasks,
    required this.tasks,
    required this.onClearSelection,
    required this.onExportSelected,
    required this.onDeleteSelected,
  });

  final bool hasTasks;
  final List<CalendarTask> tasks;
  final VoidCallback onClearSelection;
  final VoidCallback onExportSelected;
  final VoidCallback onDeleteSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TaskFormActionsRow(
      padding: EdgeInsets.zero,
      gap: calendarGutterSm,
      children: [
        TaskSecondaryButton(
          label: 'Add to critical path',
          icon: Icons.route,
          onPressed: hasTasks
              ? () => addTasksToCriticalPath(
                    context: context,
                    bloc: context.read<B>(),
                    tasks: tasks,
                  )
              : null,
        ),
        TaskSecondaryButton(
          label: l10n.calendarClearSelection,
          onPressed: hasTasks ? onClearSelection : null,
        ),
        TaskSecondaryButton(
          label: l10n.calendarExportSelected,
          onPressed: hasTasks ? onExportSelected : null,
        ),
        TaskDestructiveButton(
          label: l10n.calendarDeleteSelected,
          onPressed: hasTasks ? onDeleteSelected : null,
        ),
      ],
    );
  }
}

class _SelectionBatchEditSection extends StatelessWidget {
  const _SelectionBatchEditSection({
    required this.hasTasks,
    required this.titleController,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.locationHelper,
    required this.onTitleChanged,
    required this.onDescriptionChanged,
    required this.onLocationChanged,
    required this.hasPendingSelectionEdits,
    required this.onApplyChanges,
    required this.timeAdjustCallbacks,
  });

  final bool hasTasks;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final LocationAutocompleteHelper locationHelper;
  final ValueChanged<String> onTitleChanged;
  final ValueChanged<String> onDescriptionChanged;
  final ValueChanged<String> onLocationChanged;
  final bool hasPendingSelectionEdits;
  final VoidCallback onApplyChanges;
  final _SelectionTimeAdjustCallbacks timeAdjustCallbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(title: l10n.calendarBatchEdit),
        const SizedBox(height: calendarGutterSm),
        _SelectionTextField(
          label: l10n.calendarBatchTitle,
          controller: titleController,
          hint: l10n.calendarBatchTitleHint,
          enabled: hasTasks,
          onChanged: onTitleChanged,
        ),
        const SizedBox(height: calendarGutterSm),
        _SelectionTextField(
          label: l10n.calendarBatchDescription,
          controller: descriptionController,
          hint: l10n.calendarBatchDescriptionHint,
          enabled: hasTasks,
          minLines: 2,
          maxLines: 3,
          onChanged: onDescriptionChanged,
        ),
        const SizedBox(height: calendarGutterSm),
        IgnorePointer(
          ignoring: !hasTasks,
          child: Opacity(
            opacity: hasTasks ? 1 : 0.6,
            child: TaskChecklist(controller: checklistController),
          ),
        ),
        const SizedBox(height: calendarGutterSm),
        _SelectionLocationField(
          controller: locationController,
          helper: locationHelper,
          enabled: hasTasks,
          onChanged: onLocationChanged,
          label: l10n.calendarBatchLocation,
          hint: l10n.calendarBatchLocationHint,
        ),
        const SizedBox(height: calendarGutterMd),
        Align(
          alignment: Alignment.centerLeft,
          child: TaskPrimaryButton(
            label: l10n.calendarApplyChanges,
            size: ShadButtonSize.sm,
            onPressed:
                hasTasks && hasPendingSelectionEdits ? onApplyChanges : null,
          ),
        ),
        const SizedBox(height: calendarGutterMd),
        const TaskSectionDivider(
          verticalPadding: calendarGutterMd,
        ),
        TaskSectionHeader(title: l10n.calendarAdjustTime),
        const SizedBox(height: calendarGutterSm),
        _SelectionTimeAdjustRow(
          enabled: hasTasks,
          callbacks: timeAdjustCallbacks,
        ),
      ],
    );
  }
}

class _SelectionTextField extends StatelessWidget {
  const _SelectionTextField({
    required this.label,
    required this.controller,
    required this.hint,
    required this.enabled,
    this.minLines = 1,
    this.maxLines,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final int minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: calendarInsetMd),
        TaskTextField(
          controller: controller,
          hintText: hint,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines ?? minLines,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SelectionLocationField extends StatelessWidget {
  const _SelectionLocationField({
    required this.controller,
    required this.helper,
    required this.enabled,
    required this.onChanged,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper helper;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: calendarInsetMd),
        TaskLocationField(
          controller: controller,
          hintText: hint,
          textCapitalization: TextCapitalization.words,
          enabled: enabled,
          onChanged: onChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
          ),
          autocomplete: helper,
        ),
      ],
    );
  }
}

class _SelectionTimeAdjustRow extends StatelessWidget {
  const _SelectionTimeAdjustRow({
    required this.enabled,
    required this.callbacks,
  });

  final bool enabled;
  final _SelectionTimeAdjustCallbacks callbacks;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarGutterSm,
      children: [
        _SelectionAdjustButton(
          label: l10n.calendarAdjustStartMinus,
          onPressed: enabled ? callbacks.onStartMinus : null,
        ),
        _SelectionAdjustButton(
          label: l10n.calendarAdjustStartPlus,
          onPressed: enabled ? callbacks.onStartPlus : null,
        ),
        _SelectionAdjustButton(
          label: l10n.calendarAdjustEndMinus,
          onPressed: enabled ? callbacks.onEndMinus : null,
        ),
        _SelectionAdjustButton(
          label: l10n.calendarAdjustEndPlus,
          onPressed: enabled ? callbacks.onEndPlus : null,
        ),
      ],
    );
  }
}

class _SelectionTimeAdjustCallbacks {
  const _SelectionTimeAdjustCallbacks({
    required this.onStartMinus,
    required this.onStartPlus,
    required this.onEndMinus,
    required this.onEndPlus,
  });

  final VoidCallback onStartMinus;
  final VoidCallback onStartPlus;
  final VoidCallback onEndMinus;
  final VoidCallback onEndPlus;
}

class _SelectionPriorityControls extends StatelessWidget {
  const _SelectionPriorityControls({
    required this.tasks,
    required this.onPriorityChanged,
  });

  final List<CalendarTask> tasks;
  final ValueChanged<TaskPriority> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    final bool hasTasks = tasks.isNotEmpty;
    final bool allImportant =
        hasTasks && tasks.every((task) => task.isImportant || task.isCritical);
    final bool anyImportant =
        tasks.any((task) => task.isImportant || task.isCritical);

    final bool allUrgent =
        hasTasks && tasks.every((task) => task.isUrgent || task.isCritical);
    final bool anyUrgent =
        tasks.any((task) => task.isUrgent || task.isCritical);

    TaskPriority targetPriority({
      required bool important,
      required bool urgent,
    }) {
      if (important && urgent) return TaskPriority.critical;
      if (important) return TaskPriority.important;
      if (urgent) return TaskPriority.urgent;
      return TaskPriority.none;
    }

    return TaskPriorityToggles(
      isImportant: allImportant,
      isUrgent: allUrgent,
      isImportantIndeterminate: anyImportant && !allImportant,
      isUrgentIndeterminate: anyUrgent && !allUrgent,
      onImportantChanged: hasTasks
          ? (selected) => onPriorityChanged(
                targetPriority(
                  important: selected,
                  urgent: allUrgent,
                ),
              )
          : null,
      onUrgentChanged: hasTasks
          ? (selected) => onPriorityChanged(
                targetPriority(
                  important: allImportant,
                  urgent: selected,
                ),
              )
          : null,
    );
  }
}

class _SelectionCompletionToggle extends StatelessWidget {
  const _SelectionCompletionToggle({
    required this.hasTasks,
    required this.allCompleted,
    required this.isIndeterminate,
    required this.onChanged,
  });

  final bool hasTasks;
  final bool allCompleted;
  final bool isIndeterminate;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskCompletionToggle(
      value: allCompleted,
      isIndeterminate: isIndeterminate,
      enabled: hasTasks,
      onChanged: hasTasks ? onChanged : null,
    );
  }
}

class _SelectionReminderSection extends StatelessWidget {
  const _SelectionReminderSection({
    required this.hasTasks,
    required this.remindersListenable,
    required this.mixedListenable,
    required this.anchorListenable,
    required this.onChanged,
  });

  final bool hasTasks;
  final ValueListenable<ReminderPreferences> remindersListenable;
  final ValueListenable<bool> mixedListenable;
  final ValueListenable<ReminderAnchor> anchorListenable;
  final ValueChanged<ReminderPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!hasTasks) {
      return Text(
        context.l10n.calendarSelectionNoneShort,
        style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    return ValueListenableBuilder<ReminderAnchor>(
      valueListenable: anchorListenable,
      builder: (context, anchor, _) {
        return ValueListenableBuilder<ReminderPreferences>(
          valueListenable: remindersListenable,
          builder: (context, reminders, __) {
            return ValueListenableBuilder<bool>(
              valueListenable: mixedListenable,
              builder: (context, mixed, ___) {
                return ReminderPreferencesField(
                  value: reminders,
                  onChanged: onChanged,
                  mixed: mixed,
                  anchor: anchor,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SelectionRecurrenceSection extends StatelessWidget {
  const _SelectionRecurrenceSection({
    required this.hasTasks,
    required this.fallbackWeekday,
    required this.recurrenceListenable,
    required this.mixedListenable,
    required this.onChanged,
  });

  final bool hasTasks;
  final int fallbackWeekday;
  final ValueListenable<RecurrenceFormValue> recurrenceListenable;
  final ValueListenable<bool> mixedListenable;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!hasTasks) {
      return Text(
        context.l10n.calendarSelectionNoneShort,
        style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    return ValueListenableBuilder<RecurrenceFormValue>(
      valueListenable: recurrenceListenable,
      builder: (context, recurrence, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: mixedListenable,
          builder: (context, isMixed, __) {
            final children = <Widget>[];
            if (isMixed) {
              children.add(
                Container(
                  margin: const EdgeInsets.only(bottom: calendarGutterSm),
                  padding: const EdgeInsets.symmetric(
                    horizontal: calendarGutterMd,
                    vertical: calendarGutterSm,
                  ),
                  decoration: BoxDecoration(
                    color: calendarWarningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: calendarWarningColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Text(
                    context.l10n.calendarSelectionMixedRecurrence,
                    style: const TextStyle(
                      fontSize: 12,
                      color: calendarSubtitleColor,
                    ),
                  ),
                ),
              );
            }

            children.add(
              TaskRecurrenceSection(
                value: recurrence,
                enabled: hasTasks,
                fallbackWeekday: fallbackWeekday,
                spacingConfig: calendarRecurrenceSpacingStandard,
                intervalSelectWidth: 118,
                onChanged: onChanged,
              ),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            );
          },
        );
      },
    );
  }
}

class _SelectedTaskList extends StatelessWidget {
  const _SelectedTaskList({
    required this.tasks,
    required this.uiState,
    required this.scheduleLabelBuilder,
    required this.onFocusTask,
    required this.onRemoveTask,
    required this.onToggleCompletion,
  });

  final List<CalendarTask> tasks;
  final CalendarSidebarState uiState;
  final String Function(CalendarTask task) scheduleLabelBuilder;
  final ValueChanged<CalendarTask> onFocusTask;
  final ValueChanged<CalendarTask> onRemoveTask;
  final void Function(CalendarTask task, bool completed) onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(calendarGutterLg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(calendarBorderRadius + 2),
          border: Border.all(color: calendarBorderColor),
        ),
        child: Text(
          context.l10n.calendarSelectionNoTasksHint,
          style: const TextStyle(
            fontSize: 12,
            color: calendarSubtitleColor,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final task in tasks)
          _SelectionTaskTile(
            task: task,
            uiState: uiState,
            scheduleLabel: scheduleLabelBuilder(task),
            onFocusTask: onFocusTask,
            onRemoveTask: onRemoveTask,
            onToggleCompletion: onToggleCompletion,
          ),
      ],
    );
  }
}

class _SelectionTaskTile extends StatelessWidget {
  const _SelectionTaskTile({
    required this.task,
    required this.uiState,
    required this.scheduleLabel,
    required this.onFocusTask,
    required this.onRemoveTask,
    required this.onToggleCompletion,
  });

  final CalendarTask task;
  final CalendarSidebarState uiState;
  final String scheduleLabel;
  final ValueChanged<CalendarTask> onFocusTask;
  final ValueChanged<CalendarTask> onRemoveTask;
  final void Function(CalendarTask task, bool completed) onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    final borderColor = task.priorityColor;
    final bool isActive = uiState.activePopoverTaskId == task.id;

    return CalendarTaskTitleTooltip(
      title: task.title,
      enabled: !isActive,
      child: Container(
        margin: const EdgeInsets.only(bottom: calendarGutterSm),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onFocusTask(task),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      isActive ? calendarSidebarBackgroundColor : Colors.white,
                  border: Border(
                    left: BorderSide(color: borderColor, width: 3),
                    top: const BorderSide(color: calendarBorderColor),
                    right: const BorderSide(color: calendarBorderColor),
                    bottom: const BorderSide(color: calendarBorderColor),
                  ),
                ),
                child: _SidebarTaskTileBody(
                  task: task,
                  scheduleLabel: scheduleLabel,
                  onToggleCompletion: (completed) =>
                      onToggleCompletion(task, completed),
                  trailing: AxiTooltip(
                    builder: (_) => Text(context.l10n.calendarSelectionRemove),
                    child: ShadIconButton.ghost(
                      onPressed: () => onRemoveTask(task),
                      icon: const Icon(
                        Icons.close,
                        size: 16,
                        color: calendarSubtitleColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SidebarTaskTileBody extends StatelessWidget {
  const _SidebarTaskTileBody({
    required this.task,
    this.trailing,
    this.scheduleLabel,
    this.onToggleCompletion,
  });

  final CalendarTask task;
  final Widget? trailing;
  final String? scheduleLabel;
  final ValueChanged<bool>? onToggleCompletion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: task.isCompleted
                              ? calendarPrimaryColor
                              : calendarTitleColor,
                          decoration: task.isCompleted
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      if (scheduleLabel != null) ...[
                        const SizedBox(height: calendarInsetSm),
                        Text(
                          scheduleLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            color: task.isCompleted
                                ? calendarPrimaryColor
                                : calendarSubtitleColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: calendarInsetMd),
                if (trailing != null) ...[
                  trailing!,
                  const SizedBox(width: calendarInsetMd),
                ],
                CalendarCompletionCheckbox(
                  value: task.isCompleted,
                  onChanged: onToggleCompletion,
                ),
              ],
            ),
            if (task.description?.isNotEmpty == true) ...[
              const SizedBox(height: calendarInsetMd),
              Text(
                task.description!.length > 50
                    ? '${task.description!.substring(0, 50)}...'
                    : task.description!,
                style: const TextStyle(
                  fontSize: 11,
                  color: calendarSubtitleColor,
                ),
              ),
            ],
            if (task.hasChecklist) ...[
              const SizedBox(height: calendarInsetMd),
              TaskChecklistProgressBar(
                progress: task.checklistProgress,
                activeColor: colors.primary,
                backgroundColor: colors.muted.withValues(alpha: 0.2),
              ),
            ],
            if (task.deadline != null) ...[
              const SizedBox(height: calendarInsetLg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterSm,
                  vertical: calendarInsetMd,
                ),
                decoration: BoxDecoration(
                  color: _sidebarDeadlineBackgroundColor(task.deadline!),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: _sidebarDeadlineColor(task.deadline!),
                    ),
                    const SizedBox(width: calendarInsetMd),
                    Text(
                      _sidebarDeadlineLabel(task.deadline!),
                      style: TextStyle(
                        fontSize: 11,
                        color: _sidebarDeadlineColor(task.deadline!),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (task.location?.isNotEmpty == true) ...[
              const SizedBox(height: calendarInsetMd),
              Row(
                children: [
                  const Text('📍 ', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Text(
                      task.location!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: calendarSubtitleColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Color _sidebarDeadlineColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor;
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor;
  }
  return calendarPrimaryColor;
}

Color _sidebarDeadlineBackgroundColor(DateTime deadline) {
  final now = DateTime.now();
  if (deadline.isBefore(now)) {
    return calendarDangerColor.withValues(alpha: 0.1);
  } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
    return calendarWarningColor.withValues(alpha: 0.1);
  }
  return calendarPrimaryColor.withValues(alpha: 0.08);
}

String _sidebarDeadlineLabel(DateTime deadline) {
  return TimeFormatter.formatFriendlyDateTime(deadline);
}

const TextStyle _sidebarSectionHeaderStyle = TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w700,
  color: calendarSubtitleColor,
  letterSpacing: 0.6,
);

class _AddTaskSection extends StatelessWidget {
  const _AddTaskSection({
    required this.uiState,
    required this.locationHelper,
    required this.formActivityListenable,
    required this.hasSidebarFormValues,
    required this.onClearFieldsPressed,
    required this.titleController,
    required this.titleFocusNode,
    required this.addTaskFormKey,
    required this.quickTaskValidator,
    required this.quickTaskAutovalidateMode,
    required this.onQuickTaskChanged,
    required this.onQuickTaskSubmitted,
    required this.draftController,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.sidebarController,
    required this.onAdvancedToggle,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.onDeadlineChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onScheduleCleared,
    required this.onRecurrenceChanged,
    required this.addTask,
    required this.onAddToCriticalPath,
    required this.onRemindersChanged,
    required this.queuedCriticalPaths,
    required this.onRemoveQueuedCriticalPath,
  });

  final CalendarSidebarState uiState;
  final LocationAutocompleteHelper locationHelper;
  final Listenable formActivityListenable;
  final ValueGetter<bool> hasSidebarFormValues;
  final VoidCallback onClearFieldsPressed;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final GlobalKey<FormState> addTaskFormKey;
  final FormFieldValidator<String> quickTaskValidator;
  final AutovalidateMode quickTaskAutovalidateMode;
  final ValueChanged<String> onQuickTaskChanged;
  final VoidCallback onQuickTaskSubmitted;
  final TaskDraftController draftController;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final CalendarSidebarController sidebarController;
  final VoidCallback onAdvancedToggle;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onScheduleCleared;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final VoidCallback addTask;
  final Future<void> Function() onAddToCriticalPath;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final List<CalendarCriticalPath> queuedCriticalPaths;
  final ValueChanged<String> onRemoveQueuedCriticalPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: calendarSidebarSectionPadding,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: calendarBorderColor,
            width: calendarBorderStroke,
          ),
        ),
      ),
      child: Form(
        key: addTaskFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TaskSectionHeader(
              title: l10n.calendarAddTaskAction,
              textStyle: _sidebarSectionHeaderStyle,
              trailing: AnimatedBuilder(
                animation: formActivityListenable,
                builder: (context, _) {
                  final bool enabled = hasSidebarFormValues();
                  final button = ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: enabled ? onClearFieldsPressed : null,
                    child: Text(l10n.commonClear),
                  );
                  final decorated = button.withTapBounce(enabled: enabled);
                  return AnimatedOpacity(
                    duration: baseAnimationDuration,
                    opacity: enabled ? 1 : 0.5,
                    child: MouseRegion(
                      cursor: enabled
                          ? SystemMouseCursors.click
                          : SystemMouseCursors.basic,
                      child: decorated,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: calendarSidebarSectionSpacing),
            _QuickTaskInput(
              controller: titleController,
              focusNode: titleFocusNode,
              helper: locationHelper,
              onChanged: onQuickTaskChanged,
              onSubmitted: onQuickTaskSubmitted,
              validator: quickTaskValidator,
              autovalidateMode: quickTaskAutovalidateMode,
            ),
            const SizedBox(height: calendarSidebarSectionSpacing),
            _PriorityToggles(
              draftController: draftController,
              onImportantChanged: onImportantChanged,
              onUrgentChanged: onUrgentChanged,
            ),
            const SizedBox(height: calendarSidebarToggleSpacing),
            _AdvancedToggle(
              uiState: uiState,
              onPressed: onAdvancedToggle,
            ),
            AnimatedSwitcher(
              duration: calendarSidebarAdvancedAnimationDuration,
              transitionBuilder: (child, animation) {
                final fade = CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                );
                return FadeTransition(
                  opacity: fade,
                  child: SizeTransition(
                    sizeFactor: fade,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: uiState.showAdvancedOptions
                  ? _AdvancedOptions(
                      key: const ValueKey('advanced'),
                      locationHelper: locationHelper,
                      descriptionController: descriptionController,
                      locationController: locationController,
                      checklistController: checklistController,
                      draftController: draftController,
                      onDeadlineChanged: onDeadlineChanged,
                      onStartChanged: onStartChanged,
                      onEndChanged: onEndChanged,
                      onScheduleCleared: onScheduleCleared,
                      onRecurrenceChanged: onRecurrenceChanged,
                      titleController: titleController,
                      onAddToCriticalPath: onAddToCriticalPath,
                      onRemindersChanged: onRemindersChanged,
                      queuedPaths: queuedCriticalPaths,
                      onRemoveQueuedPath: onRemoveQueuedCriticalPath,
                    )
                  : const SizedBox.shrink(key: ValueKey('advanced-hidden')),
            ),
            const SizedBox(height: calendarSidebarSectionSpacing),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: titleController,
              builder: (context, value, _) {
                final bool canSubmit = quickTaskValidator(value.text) == null;
                return TaskFormActionsRow(
                  padding: EdgeInsets.zero,
                  gap: calendarGutterSm,
                  children: [
                    Expanded(
                      child: _AddTaskButton(
                        onPressed: addTask,
                        enabled: canSubmit,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

typedef _CalendarDragDetailsCallback = void Function(
  CalendarDropDetails details,
);

class _UnscheduledSidebarContent extends StatelessWidget {
  const _UnscheduledSidebarContent({
    required this.uiState,
    required this.locationHelper,
    required this.formActivityListenable,
    required this.hasSidebarFormValues,
    required this.onClearFieldsPressed,
    required this.titleController,
    required this.titleFocusNode,
    required this.addTaskFormKey,
    required this.quickTaskValidator,
    required this.quickTaskAutovalidateMode,
    required this.onQuickTaskChanged,
    required this.onQuickTaskSubmitted,
    required this.draftController,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.sidebarController,
    required this.onAdvancedToggle,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.onDeadlineChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onScheduleCleared,
    required this.onRecurrenceChanged,
    required this.onRemindersChanged,
    required this.onAddTask,
    required this.onAddToCriticalPath,
    required this.queuedCriticalPaths,
    required this.onRemoveQueuedCriticalPath,
    required this.onShowAddTaskSection,
    required this.showAddTaskSection,
    required this.unscheduledTasks,
    required this.reminderTasks,
    required this.hideCompletedUnscheduled,
    required this.hideCompletedReminders,
    required this.onToggleHideCompletedUnscheduled,
    required this.onToggleHideCompletedReminders,
    required this.sectionKeys,
    required this.onToggleSection,
    required this.onSectionDragEnter,
    required this.onTaskDropped,
    required this.onTaskListHover,
    required this.onTaskListLeave,
    required this.onTaskListDrop,
    required this.onUnscheduledReorder,
    required this.onReminderReorder,
    required this.requiresLongPressForReorder,
    required this.taskTileBuilder,
  });

  final CalendarSidebarState uiState;
  final LocationAutocompleteHelper locationHelper;
  final Listenable formActivityListenable;
  final ValueGetter<bool> hasSidebarFormValues;
  final VoidCallback onClearFieldsPressed;
  final TextEditingController titleController;
  final FocusNode titleFocusNode;
  final GlobalKey<FormState> addTaskFormKey;
  final FormFieldValidator<String> quickTaskValidator;
  final AutovalidateMode quickTaskAutovalidateMode;
  final ValueChanged<String> onQuickTaskChanged;
  final VoidCallback onQuickTaskSubmitted;
  final TaskDraftController draftController;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final CalendarSidebarController sidebarController;
  final VoidCallback onAdvancedToggle;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onScheduleCleared;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final VoidCallback onAddTask;
  final Future<void> Function() onAddToCriticalPath;
  final List<CalendarCriticalPath> queuedCriticalPaths;
  final ValueChanged<String> onRemoveQueuedCriticalPath;
  final VoidCallback onShowAddTaskSection;
  final bool showAddTaskSection;
  final List<CalendarTask> unscheduledTasks;
  final List<CalendarTask> reminderTasks;
  final bool hideCompletedUnscheduled;
  final bool hideCompletedReminders;
  final ValueChanged<bool> onToggleHideCompletedUnscheduled;
  final ValueChanged<bool> onToggleHideCompletedReminders;
  final Map<CalendarSidebarSection, GlobalKey> sectionKeys;
  final ValueChanged<CalendarSidebarSection> onToggleSection;
  final ValueChanged<CalendarSidebarSection> onSectionDragEnter;
  final ValueChanged<CalendarTask> onTaskDropped;
  final _CalendarDragDetailsCallback onTaskListHover;
  final VoidCallback onTaskListLeave;
  final _CalendarDragDetailsCallback onTaskListDrop;
  final void Function(int oldIndex, int newIndex) onUnscheduledReorder;
  final void Function(int oldIndex, int newIndex) onReminderReorder;
  final bool requiresLongPressForReorder;
  final Widget Function(
    CalendarTask task,
    Widget? trailing, {
    bool requiresLongPress,
  }) taskTileBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          crossFadeState: showAddTaskSection
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          sizeCurve: Curves.easeInOut,
          firstChild: _AddTaskSection(
            uiState: uiState,
            locationHelper: locationHelper,
            formActivityListenable: formActivityListenable,
            hasSidebarFormValues: hasSidebarFormValues,
            onClearFieldsPressed: onClearFieldsPressed,
            titleController: titleController,
            titleFocusNode: titleFocusNode,
            addTaskFormKey: addTaskFormKey,
            quickTaskValidator: quickTaskValidator,
            quickTaskAutovalidateMode: quickTaskAutovalidateMode,
            onQuickTaskChanged: onQuickTaskChanged,
            onQuickTaskSubmitted: onQuickTaskSubmitted,
            draftController: draftController,
            onImportantChanged: onImportantChanged,
            onUrgentChanged: onUrgentChanged,
            sidebarController: sidebarController,
            onAdvancedToggle: onAdvancedToggle,
            descriptionController: descriptionController,
            locationController: locationController,
            checklistController: checklistController,
            onDeadlineChanged: onDeadlineChanged,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
            onScheduleCleared: onScheduleCleared,
            onRecurrenceChanged: onRecurrenceChanged,
            addTask: onAddTask,
            onAddToCriticalPath: onAddToCriticalPath,
            onRemindersChanged: onRemindersChanged,
            queuedCriticalPaths: queuedCriticalPaths,
            onRemoveQueuedCriticalPath: onRemoveQueuedCriticalPath,
          ),
          secondChild: _CollapsedAddTaskSection(
            onExpand: onShowAddTaskSection,
          ),
        ),
        if (!showAddTaskSection) const SizedBox(height: calendarInsetMd),
        _TaskSectionsPanel(
          unscheduledTasks: unscheduledTasks,
          reminderTasks: reminderTasks,
          hideCompletedUnscheduled: hideCompletedUnscheduled,
          hideCompletedReminders: hideCompletedReminders,
          onToggleHideCompletedUnscheduled: onToggleHideCompletedUnscheduled,
          onToggleHideCompletedReminders: onToggleHideCompletedReminders,
          uiState: uiState,
          sectionKeys: sectionKeys,
          onToggleSection: onToggleSection,
          onSectionDragEnter: onSectionDragEnter,
          onTaskDropped: onTaskDropped,
          onTaskListHover: onTaskListHover,
          onTaskListLeave: onTaskListLeave,
          onTaskListDrop: onTaskListDrop,
          onUnscheduledReorder: onUnscheduledReorder,
          onReminderReorder: onReminderReorder,
          requiresLongPressForReorder: requiresLongPressForReorder,
          taskTileBuilder: taskTileBuilder,
        ),
      ],
    );
  }
}

class _CollapsedAddTaskSection extends StatelessWidget {
  const _CollapsedAddTaskSection({required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colorScheme;
    return InkWell(
      onTap: onExpand,
      borderRadius: BorderRadius.zero,
      child: Container(
        padding: calendarPaddingLg,
        decoration: BoxDecoration(
          color: colors.card,
          borderRadius: BorderRadius.zero,
          border: Border(
            bottom: BorderSide(color: colors.border),
          ),
        ),
        child: Row(
          children: [
            AnimatedRotation(
              turns: 0,
              duration: baseAnimationDuration,
              child: Icon(
                Icons.chevron_right,
                size: 18,
                color: colors.mutedForeground,
              ),
            ),
            const SizedBox(width: calendarInsetSm),
            Text(
              l10n.calendarAddTaskAction.toUpperCase(),
              style: _sidebarSectionHeaderStyle,
            ),
            const Spacer(),
          ],
        ),
      ),
    ).withTapBounce();
  }
}

class _TaskSectionsPanel extends StatelessWidget {
  const _TaskSectionsPanel({
    required this.unscheduledTasks,
    required this.reminderTasks,
    required this.hideCompletedUnscheduled,
    required this.hideCompletedReminders,
    required this.onToggleHideCompletedUnscheduled,
    required this.onToggleHideCompletedReminders,
    required this.uiState,
    required this.sectionKeys,
    required this.onToggleSection,
    required this.onSectionDragEnter,
    required this.onTaskDropped,
    required this.onTaskListHover,
    required this.onTaskListLeave,
    required this.onTaskListDrop,
    required this.onUnscheduledReorder,
    required this.onReminderReorder,
    required this.requiresLongPressForReorder,
    required this.taskTileBuilder,
  });

  final List<CalendarTask> unscheduledTasks;
  final List<CalendarTask> reminderTasks;
  final bool hideCompletedUnscheduled;
  final bool hideCompletedReminders;
  final ValueChanged<bool> onToggleHideCompletedUnscheduled;
  final ValueChanged<bool> onToggleHideCompletedReminders;
  final CalendarSidebarState uiState;
  final Map<CalendarSidebarSection, GlobalKey> sectionKeys;
  final ValueChanged<CalendarSidebarSection> onToggleSection;
  final ValueChanged<CalendarSidebarSection> onSectionDragEnter;
  final ValueChanged<CalendarTask> onTaskDropped;
  final _CalendarDragDetailsCallback onTaskListHover;
  final VoidCallback onTaskListLeave;
  final _CalendarDragDetailsCallback onTaskListDrop;
  final void Function(int oldIndex, int newIndex) onUnscheduledReorder;
  final void Function(int oldIndex, int newIndex) onReminderReorder;
  final bool requiresLongPressForReorder;
  final Widget Function(
    CalendarTask task,
    Widget? trailing, {
    bool requiresLongPress,
  }) taskTileBuilder;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SidebarAccordionSection(
          title: context.l10n.calendarUnscheduledTitle,
          section: CalendarSidebarSection.unscheduled,
          uiState: uiState,
          itemCount: unscheduledTasks.length,
          sectionKey: sectionKeys[CalendarSidebarSection.unscheduled],
          onToggleSection: onToggleSection,
          onSectionDragEnter: onSectionDragEnter,
          trailing: _HideCompletedToggle(
            value: hideCompletedUnscheduled,
            onChanged: onToggleHideCompletedUnscheduled,
          ),
          onTaskDropped: onTaskDropped,
          collapsedChild: _CollapsedTaskPreview(tasks: unscheduledTasks),
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterSm,
              vertical: calendarInsetMd,
            ),
            child: _SidebarTaskList(
              tasks: unscheduledTasks,
              emptyLabel: context.l10n.calendarUnscheduledEmptyLabel,
              emptyHint: context.l10n.calendarUnscheduledEmptyHint,
              onDragHover: onTaskListHover,
              onDragLeave: onTaskListLeave,
              onDrop: onTaskListDrop,
              reorderable: true,
              onReorder: onUnscheduledReorder,
              requiresLongPressForReorder: requiresLongPressForReorder,
              taskTileBuilder: taskTileBuilder,
            ),
          ),
        ),
        const SizedBox(height: calendarInsetMd),
        _SidebarAccordionSection(
          title: context.l10n.calendarRemindersTitle,
          section: CalendarSidebarSection.reminders,
          uiState: uiState,
          itemCount: reminderTasks.length,
          sectionKey: sectionKeys[CalendarSidebarSection.reminders],
          onToggleSection: onToggleSection,
          onSectionDragEnter: onSectionDragEnter,
          trailing: _HideCompletedToggle(
            value: hideCompletedReminders,
            onChanged: onToggleHideCompletedReminders,
          ),
          onTaskDropped: onTaskDropped,
          collapsedChild: _CollapsedTaskPreview(tasks: reminderTasks),
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterSm,
              vertical: calendarInsetMd,
            ),
            child: _SidebarTaskList(
              tasks: reminderTasks,
              emptyLabel: context.l10n.calendarRemindersEmptyLabel,
              emptyHint: context.l10n.calendarRemindersEmptyHint,
              onDragHover: onTaskListHover,
              onDragLeave: onTaskListLeave,
              onDrop: onTaskListDrop,
              reorderable: true,
              onReorder: onReminderReorder,
              requiresLongPressForReorder: requiresLongPressForReorder,
              taskTileBuilder: taskTileBuilder,
            ),
          ),
        ),
      ],
    );
  }
}

class _SidebarAccordionSection extends StatelessWidget {
  const _SidebarAccordionSection({
    required this.title,
    required this.section,
    required this.itemCount,
    required this.expandedChild,
    required this.collapsedChild,
    required this.uiState,
    required this.sectionKey,
    required this.onToggleSection,
    required this.onSectionDragEnter,
    required this.onTaskDropped,
    this.trailing,
  });

  final String title;
  final CalendarSidebarSection section;
  final int itemCount;
  final Widget expandedChild;
  final Widget collapsedChild;
  final CalendarSidebarState uiState;
  final GlobalKey? sectionKey;
  final ValueChanged<CalendarSidebarSection> onToggleSection;
  final ValueChanged<CalendarSidebarSection> onSectionDragEnter;
  final ValueChanged<CalendarTask> onTaskDropped;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool isExpanded = uiState.expandedSection == section;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: sidebarBackgroundColor,
            border: Border(
              bottom: section == CalendarSidebarSection.unscheduled
                  ? const BorderSide(
                      color: calendarBorderColor,
                      width: calendarBorderStroke,
                    )
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  onTap: () => onToggleSection(section),
                  child: Padding(
                    padding: calendarFieldPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title.toUpperCase(),
                            style: _sidebarSectionHeaderStyle,
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: calendarInsetSm),
                          trailing!,
                        ],
                        _SectionCountBadge(
                          count: itemCount,
                          isExpanded: isExpanded,
                        ),
                        const SizedBox(width: calendarGutterSm),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          size: 18,
                          color: calendarSubtitleColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    padding: calendarAccordionPadding,
                    child: expandedChild,
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  sizeCurve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 160),
                firstChild: Row(
                  children: [
                    Expanded(
                      child: CalendarDragTargetRegion(
                        onEnter: (_) => onSectionDragEnter(section),
                        onMove: (_) => onSectionDragEnter(section),
                        onDrop: (details) {
                          onSectionDragEnter(section);
                          onTaskDropped(details.payload.task);
                        },
                        builder: (context, isHovering, __) {
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onToggleSection(section),
                              child: AnimatedContainer(
                                key: ValueKey('${section.name}-collapsed'),
                                duration: const Duration(milliseconds: 120),
                                padding:
                                    const EdgeInsets.fromLTRB(14, 6, 14, 6),
                                constraints:
                                    const BoxConstraints(minHeight: 40),
                                decoration: BoxDecoration(
                                  color: isHovering
                                      ? calendarPrimaryColor.withValues(
                                          alpha: 0.12,
                                        )
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(
                                    calendarBorderRadius,
                                  ),
                                  border: isHovering
                                      ? Border.all(
                                          color: calendarPrimaryColor,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: collapsedChild,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ],
    );

    if (sectionKey == null) {
      return content;
    }
    return KeyedSubtree(key: sectionKey, child: content);
  }
}

class _HideCompletedToggle extends StatelessWidget {
  const _HideCompletedToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool hiding = value;
    final Color foreground = hiding ? colors.primary : colors.mutedForeground;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: calendarInsetMd),
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        onPressed: () => onChanged(!value),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hiding ? Icons.visibility_off : Icons.visibility,
              size: 16,
              color: foreground,
            ),
            const SizedBox(width: calendarInsetMd),
            Text(
              'Completed',
              style: context.textTheme.small.copyWith(
                color: foreground,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ).withTapBounce(),
    );
  }
}

class _CollapsedTaskPreview extends StatelessWidget {
  const _CollapsedTaskPreview({required this.tasks});

  final List<CalendarTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return Text(
        context.l10n.calendarNothingHere,
        style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: tasks
          .map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetSm),
              child: Text(
                '• ${task.title}',
                style: const TextStyle(
                  fontSize: 12,
                  color: calendarSubtitleColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _SidebarTaskList extends StatelessWidget {
  const _SidebarTaskList({
    required this.tasks,
    required this.emptyLabel,
    required this.emptyHint,
    required this.onDragHover,
    required this.onDragLeave,
    required this.onDrop,
    this.reorderable = false,
    this.onReorder,
    this.requiresLongPressForReorder = false,
    required this.taskTileBuilder,
  });

  final List<CalendarTask> tasks;
  final String emptyLabel;
  final String? emptyHint;
  final _CalendarDragDetailsCallback onDragHover;
  final VoidCallback onDragLeave;
  final _CalendarDragDetailsCallback onDrop;
  final bool reorderable;
  final void Function(int oldIndex, int newIndex)? onReorder;
  final bool requiresLongPressForReorder;
  final Widget Function(
    CalendarTask task,
    Widget? trailing, {
    bool requiresLongPress,
  }) taskTileBuilder;

  @override
  Widget build(BuildContext context) {
    return CalendarDragTargetRegion(
      onEnter: onDragHover,
      onMove: onDragHover,
      onLeave: (_) => onDragLeave(),
      onDrop: onDrop,
      builder: (context, isHovering, _) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovering
                ? calendarPrimaryColor.withValues(alpha: 0.08)
                : sidebarBackgroundColor,
            border: isHovering
                ? Border.all(color: calendarPrimaryColor, width: 2)
                : null,
          ),
          child: tasks.isEmpty
              ? _SidebarEmptyState(
                  label: emptyLabel,
                  hint: emptyHint,
                  isHovering: isHovering,
                )
              : reorderable && onReorder != null
                  ? ReorderableListView.builder(
                      shrinkWrap: true,
                      buildDefaultDragHandles: false,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: calendarInsetLg,
                        vertical: 2,
                      ),
                      itemCount: tasks.length,
                      onReorder: onReorder!,
                      proxyDecorator: (child, __, ___) {
                        return Material(
                          color: Colors.transparent,
                          child: child,
                        );
                      },
                      itemBuilder: (context, index) {
                        final CalendarTask task = tasks[index];
                        final Widget handle = _SidebarReorderHandle(
                          index: index,
                          requiresLongPress: requiresLongPressForReorder,
                        );
                        final Widget tile = taskTileBuilder(
                          task,
                          handle,
                          requiresLongPress: false,
                        );
                        return KeyedSubtree(
                          key: ValueKey(task.id),
                          child: tile,
                        );
                      },
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: calendarInsetLg,
                        vertical: 2,
                      ),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        return taskTileBuilder(
                          tasks[index],
                          null,
                          requiresLongPress: false,
                        );
                      },
                    ),
        );
      },
    );
  }
}

class _SidebarEmptyState extends StatelessWidget {
  const _SidebarEmptyState({
    required this.label,
    required this.hint,
    required this.isHovering,
  });

  final String label;
  final String? hint;
  final bool isHovering;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: calendarActionButtonPadding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHovering ? Icons.add_task : Icons.inbox_outlined,
              size: 48,
              color: isHovering ? calendarPrimaryColor : calendarTimeLabelColor,
            ),
            const SizedBox(height: calendarGutterMd),
            Text(
              label,
              style: TextStyle(
                color:
                    isHovering ? calendarPrimaryColor : calendarTimeLabelColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: calendarInsetSm),
              Text(
                hint!,
                style: const TextStyle(
                  color: calendarSubtitleColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SidebarReorderHandle extends StatelessWidget {
  const _SidebarReorderHandle({
    required this.index,
    required this.requiresLongPress,
  });

  final int index;
  final bool requiresLongPress;

  @override
  Widget build(BuildContext context) {
    final ShadColorScheme colors = context.colorScheme;
    final Widget icon = Container(
      padding: const EdgeInsets.all(calendarInsetMd),
      decoration: BoxDecoration(
        color: colors.muted.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.drag_indicator,
        size: 18,
        color: colors.mutedForeground,
      ),
    );

    final Widget handle = requiresLongPress
        ? ReorderableDelayedDragStartListener(index: index, child: icon)
        : ReorderableDragStartListener(index: index, child: icon);

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: handle,
    );
  }
}

class _SectionCountBadge extends StatelessWidget {
  const _SectionCountBadge({
    required this.count,
    required this.isExpanded,
  });

  final int count;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetMd,
      ),
      decoration: BoxDecoration(
        color: isExpanded
            ? calendarPrimaryColor
            : calendarPrimaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isExpanded ? Colors.white : calendarPrimaryColor,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 52),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: badge,
      ),
    );
  }
}

class _SidebarDraggableTaskTile<B extends BaseCalendarBloc>
    extends StatelessWidget {
  const _SidebarDraggableTaskTile({
    required this.host,
    required this.task,
    required this.uiState,
    this.trailing,
    this.requiresLongPress = false,
    this.enableInteraction = true,
    this.onTapOverride,
    this.allowContextMenu = true,
    this.onDragStart,
  });

  final TaskSidebarState<B> host;
  final CalendarTask task;
  final CalendarSidebarState uiState;
  final Widget? trailing;
  final bool requiresLongPress;
  final bool enableInteraction;
  final VoidCallback? onTapOverride;
  final bool allowContextMenu;
  final VoidCallback? onDragStart;

  @override
  Widget build(BuildContext context) {
    final Widget baseTile = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: _SidebarTaskTile<B>(
        host: host,
        task: task,
        uiState: uiState,
        trailing: trailing,
        enableInteraction: enableInteraction,
        onTapOverride: onTapOverride,
        allowContextMenu: allowContextMenu,
        onToggleCompletion: (completed) =>
            host._toggleSidebarTaskCompletion(task, completed),
      ),
    );
    final Widget fadedTile = Opacity(
      opacity: 0.3,
      child: _SidebarTaskTile<B>(
        host: host,
        task: task,
        uiState: uiState,
        trailing: trailing,
        enableInteraction: false,
        allowContextMenu: allowContextMenu,
        onToggleCompletion: (completed) =>
            host._toggleSidebarTaskCompletion(task, completed),
      ),
    );
    final Widget feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.8,
        child: SizedBox(
          width: uiState.width - 32,
          child: _SidebarTaskTile(
            host: host,
            task: task,
            uiState: uiState,
            trailing: trailing,
            enableInteraction: false,
            allowContextMenu: allowContextMenu,
            onToggleCompletion: (completed) =>
                host._toggleSidebarTaskCompletion(task, completed),
          ),
        ),
      ),
    );

    return CalendarSidebarDraggable(
      task: task,
      childWhenDragging: fadedTile,
      feedback: feedback,
      onDragSessionStarted: () {
        onDragStart?.call();
        host._handleSidebarDragSessionStarted();
      },
      onDragSessionEnded: host._handleSidebarDragSessionEnded,
      onDragGlobalPositionChanged: host._forwardSidebarGlobalPosition,
      requiresLongPress: requiresLongPress || host._isTouchOnlyInput,
      child: baseTile,
    );
  }
}

class _SidebarTaskTile<B extends BaseCalendarBloc> extends StatelessWidget {
  const _SidebarTaskTile({
    required this.host,
    required this.task,
    required this.uiState,
    this.enableInteraction = true,
    this.trailing,
    this.onToggleCompletion,
    this.onTapOverride,
    this.allowContextMenu = true,
  });

  final TaskSidebarState<B> host;
  final CalendarTask task;
  final CalendarSidebarState uiState;
  final bool enableInteraction;
  final Widget? trailing;
  final ValueChanged<bool>? onToggleCompletion;
  final VoidCallback? onTapOverride;
  final bool allowContextMenu;

  bool _hasRenderableLayout(RenderBox? box) {
    if (box == null || !box.attached || !box.hasSize) {
      return false;
    }

    RenderObject? current = box;
    bool foundSliverParent = false;
    while (current != null) {
      final ParentData? parentData = current.parentData;
      if (parentData is SliverMultiBoxAdaptorParentData) {
        foundSliverParent = true;
        return parentData.layoutOffset != null;
      }
      current = current.parent;
    }
    return !foundSliverParent;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = task.priorityColor;
    final bool isActive = uiState.activePopoverTaskId == task.id;

    Widget tile = Container(
      margin: const EdgeInsets.only(bottom: calendarGutterSm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Container(
          decoration: BoxDecoration(
            color: isActive ? calendarSidebarBackgroundColor : Colors.white,
            border: Border(
              left: BorderSide(color: borderColor, width: 3),
              top: const BorderSide(color: calendarBorderColor),
              right: const BorderSide(color: calendarBorderColor),
              bottom: const BorderSide(color: calendarBorderColor),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(calendarBorderRadius),
            child: enableInteraction
                ? Builder(
                    builder: (tileContext) {
                      final VoidCallback? customTap = onTapOverride;
                      if (customTap != null) {
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(calendarBorderRadius),
                            hoverColor: calendarSidebarBackgroundColor
                                .withValues(alpha: 0.5),
                            onTap: customTap,
                            child: _SidebarTaskTileBody(
                              task: task,
                              trailing: trailing,
                              onToggleCompletion: onToggleCompletion,
                            ),
                          ),
                        );
                      }

                      if (host._shouldUseSheetMenus(tileContext)) {
                        return MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(calendarBorderRadius),
                            hoverColor: calendarSidebarBackgroundColor
                                .withValues(alpha: 0.5),
                            onTap: () =>
                                host._showTaskEditSheet(tileContext, task),
                            child: _SidebarTaskTileBody(
                              task: task,
                              trailing: trailing,
                              onToggleCompletion: onToggleCompletion,
                            ),
                          ),
                        );
                      }

                      final controller = host._popoverControllerFor(task.id);
                      final renderBox =
                          tileContext.findRenderObject() as RenderBox?;
                      final bool hasLayout = _hasRenderableLayout(renderBox);
                      final tileSize = hasLayout ? renderBox!.size : Size.zero;
                      Offset tileOrigin = Offset.zero;
                      if (hasLayout) {
                        try {
                          tileOrigin = renderBox!.localToGlobal(Offset.zero);
                        } catch (_) {
                          tileOrigin = Offset.zero;
                        }
                      }
                      final screenSize = MediaQuery.of(tileContext).size;

                      const double margin = calendarPopoverScreenMargin;
                      const double dropdownMaxHeight =
                          calendarSidebarPopoverMaxHeight;
                      const double dropdownWidth = calendarTaskPopoverWidth;
                      const double preferredVerticalGap =
                          calendarPopoverPreferredVerticalGap;
                      const double preferredHorizontalGap =
                          calendarPopoverPreferredHorizontalGap;

                      final availableBelow = screenSize.height -
                          (tileOrigin.dy + tileSize.height) -
                          margin;
                      final availableAbove = tileOrigin.dy - margin;
                      final availableRight = screenSize.width -
                          (tileOrigin.dx + tileSize.width) -
                          margin;
                      final availableLeft = tileOrigin.dx - margin;

                      final normalizedAbove = math.max(0.0, availableAbove);
                      final normalizedBelow = math.max(0.0, availableBelow);

                      final heightIfAbove =
                          math.min(dropdownMaxHeight, normalizedAbove);
                      final heightIfBelow =
                          math.min(dropdownMaxHeight, normalizedBelow);

                      bool showAbove;
                      if (heightIfAbove <= 0 && heightIfBelow <= 0) {
                        showAbove = false;
                      } else if (heightIfBelow <= 0) {
                        showAbove = true;
                      } else if (heightIfAbove <= 0) {
                        showAbove = false;
                      } else if ((heightIfBelow - heightIfAbove).abs() <= 4) {
                        showAbove = normalizedAbove > normalizedBelow;
                      } else {
                        showAbove = heightIfAbove > heightIfBelow;
                      }

                      final availableSpace =
                          showAbove ? normalizedAbove : normalizedBelow;

                      double effectiveMaxHeight = availableSpace > 0
                          ? math.min(dropdownMaxHeight, availableSpace)
                          : dropdownMaxHeight;
                      if (effectiveMaxHeight <= 0) {
                        effectiveMaxHeight = dropdownMaxHeight;
                      }

                      bool openToLeft =
                          availableRight < dropdownWidth && availableLeft > 0;
                      if (openToLeft && availableLeft < dropdownWidth) {
                        openToLeft = availableLeft >= availableRight;
                      }

                      final extraAbove =
                          math.max(0.0, normalizedAbove - effectiveMaxHeight);
                      final extraBelow =
                          math.max(0.0, normalizedBelow - effectiveMaxHeight);
                      final extraVerticalSpace =
                          showAbove ? extraAbove : extraBelow;
                      final appliedVerticalGap =
                          math.min(preferredVerticalGap, extraVerticalSpace);

                      final triggerLeft = tileOrigin.dx;
                      final triggerRight = tileOrigin.dx + tileSize.width;

                      double desiredLeft;
                      if (openToLeft) {
                        desiredLeft = triggerRight -
                            dropdownWidth -
                            preferredHorizontalGap;
                      } else {
                        desiredLeft = triggerLeft + preferredHorizontalGap;
                      }

                      const double minLeft = margin;
                      final maxLeft = screenSize.width - margin - dropdownWidth;
                      final overlayLeft = desiredLeft.clamp(minLeft, maxLeft);
                      final horizontalOffset = overlayLeft - triggerLeft;

                      final verticalOffset =
                          showAbove ? -appliedVerticalGap : appliedVerticalGap;

                      final targetAnchor =
                          showAbove ? Alignment.topLeft : Alignment.bottomLeft;
                      final childAnchor =
                          showAbove ? Alignment.bottomLeft : Alignment.topLeft;

                      final anchor = ShadAnchor(
                        overlayAlignment: targetAnchor,
                        childAlignment: childAnchor,
                        offset: Offset(
                          horizontalOffset,
                          verticalOffset,
                        ),
                      );

                      final scaffoldMessenger =
                          ScaffoldMessenger.maybeOf(tileContext);

                      return ShadPopover(
                        controller: controller,
                        closeOnTapOutside: true,
                        anchor: anchor,
                        padding: EdgeInsets.zero,
                        popover: (context) {
                          return BlocBuilder<B, CalendarState>(
                            builder: (context, state) {
                              final baseId = task.baseId;
                              final latestTask =
                                  state.model.tasks[baseId] ?? task;
                              final CalendarTask? storedTask =
                                  state.model.tasks[task.id];
                              final CalendarTask? occurrenceTask =
                                  storedTask == null && task.isOccurrence
                                      ? latestTask.occurrenceForId(task.id)
                                      : null;
                              final CalendarTask displayTask =
                                  storedTask ?? occurrenceTask ?? latestTask;
                              final bool shouldUpdateOccurrence =
                                  storedTask == null && occurrenceTask != null;

                              return EditTaskDropdown<B>(
                                task: displayTask,
                                maxHeight: effectiveMaxHeight,
                                onClose: () => host._closeTaskPopover(task.id),
                                scaffoldMessenger: scaffoldMessenger,
                                locationHelper:
                                    LocationAutocompleteHelper.fromState(state),
                                onTaskUpdated: (updatedTask) {
                                  context.read<B>().add(
                                        CalendarEvent.taskUpdated(
                                          task: updatedTask,
                                        ),
                                      );
                                },
                                onOccurrenceUpdated: shouldUpdateOccurrence
                                    ? (updatedTask) {
                                        context.read<B>().add(
                                              CalendarEvent
                                                  .taskOccurrenceUpdated(
                                                taskId: baseId,
                                                occurrenceId: task.id,
                                                scheduledTime:
                                                    updatedTask.scheduledTime,
                                                duration: updatedTask.duration,
                                                endDate: updatedTask.endDate,
                                                checklist:
                                                    updatedTask.checklist,
                                              ),
                                            );

                                        final CalendarTask seriesUpdate =
                                            latestTask.copyWith(
                                          title: updatedTask.title,
                                          description: updatedTask.description,
                                          location: updatedTask.location,
                                          deadline: updatedTask.deadline,
                                          priority: updatedTask.priority,
                                          isCompleted: updatedTask.isCompleted,
                                          checklist: updatedTask.checklist,
                                          modifiedAt: DateTime.now(),
                                        );

                                        if (seriesUpdate != latestTask) {
                                          context.read<B>().add(
                                                CalendarEvent.taskUpdated(
                                                  task: seriesUpdate,
                                                ),
                                              );
                                        }
                                      }
                                    : null,
                                onTaskDeleted: (taskId) {
                                  context.read<B>().add(
                                        CalendarEvent.taskDeleted(
                                          taskId: taskId,
                                        ),
                                      );
                                  host._taskPopoverControllers
                                      .remove(task.id)
                                      ?.dispose();
                                  host._sidebarController
                                      .setActivePopoverTaskId(null);
                                  TaskEditSessionTracker.instance
                                      .end(task.id, host);
                                },
                              );
                            },
                          );
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: InkWell(
                            borderRadius:
                                BorderRadius.circular(calendarBorderRadius),
                            hoverColor: calendarSidebarBackgroundColor
                                .withValues(alpha: 0.5),
                            onTap: () => host._toggleTaskPopover(task.id),
                            child: _SidebarTaskTileBody(
                              task: task,
                              trailing: trailing,
                              onToggleCompletion: onToggleCompletion,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : _SidebarTaskTileBody(
                    task: task,
                    trailing: trailing,
                    onToggleCompletion: onToggleCompletion,
                  ),
          ),
        ),
      ),
    );

    if (enableInteraction && allowContextMenu && host._hasPrecisePointerInput) {
      tile = host._wrapWithSidebarContextMenu(task: task, child: tile);
    }

    return CalendarTaskTitleTooltip(
      title: task.title,
      enabled: enableInteraction && !isActive,
      child: tile,
    );
  }
}

class _SidebarResizeHandle extends StatelessWidget {
  const _SidebarResizeHandle({
    required this.uiState,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
  });

  final CalendarSidebarState uiState;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Listener(
          key: const ValueKey('calendar.sidebar.resizeHandle'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: onPointerDown,
          onPointerMove: onPointerMove,
          onPointerUp: onPointerUp,
          onPointerCancel: onPointerCancel,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 12,
            color: uiState.isResizing
                ? calendarPrimaryColor.withValues(alpha: 0.2)
                : Colors.transparent,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: uiState.isResizing ? 3 : 2,
                height: uiState.isResizing ? 60 : 50,
                decoration: BoxDecoration(
                  color: uiState.isResizing
                      ? calendarPrimaryColor
                      : calendarBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTaskInput extends StatelessWidget {
  const _QuickTaskInput({
    required this.controller,
    required this.focusNode,
    required this.helper,
    required this.onChanged,
    required this.onSubmitted,
    required this.validator,
    required this.autovalidateMode,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final LocationAutocompleteHelper helper;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmitted;
  final FormFieldValidator<String> validator;
  final AutovalidateMode autovalidateMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    const padding = EdgeInsets.symmetric(
      horizontal: calendarGutterLg,
      vertical: 14,
    );
    final field = TaskTextFormField(
      controller: controller,
      focusNode: focusNode,
      hintText: l10n.calendarQuickTaskHint,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: onChanged,
      onFieldSubmitted: (_) => onSubmitted(),
      contentPadding: padding,
      validator: validator,
      autovalidateMode: autovalidateMode,
    );

    final suggestionField = LocationInlineSuggestion(
      controller: controller,
      helper: helper,
      contentPadding: padding,
      textStyle: const TextStyle(
        fontSize: 14,
        color: calendarTitleColor,
      ),
      suggestionColor: calendarSubtitleColor,
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

class _PriorityToggles extends StatelessWidget {
  const _PriorityToggles({
    required this.draftController,
    required this.onImportantChanged,
    required this.onUrgentChanged,
  });

  final TaskDraftController draftController;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: draftController,
      builder: (context, _) {
        return TaskPriorityToggles(
          isImportant: draftController.isImportant,
          isUrgent: draftController.isUrgent,
          onImportantChanged: onImportantChanged,
          onUrgentChanged: onUrgentChanged,
        );
      },
    );
  }
}

class _AdvancedToggle extends StatelessWidget {
  const _AdvancedToggle({
    required this.uiState,
    required this.onPressed,
  });

  final CalendarSidebarState uiState;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        foregroundColor: calendarPrimaryColor,
        hoverForegroundColor: calendarPrimaryHoverColor,
        hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        onPressed: onPressed,
        leading: Icon(
          uiState.showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: calendarPrimaryColor,
        ),
        child: Text(
          uiState.showAdvancedOptions
              ? l10n.calendarAdvancedHide
              : l10n.calendarAdvancedShow,
        ),
      ),
    );
  }
}

class _AdvancedOptions extends StatelessWidget {
  const _AdvancedOptions({
    super.key,
    required this.locationHelper,
    required this.descriptionController,
    required this.locationController,
    required this.checklistController,
    required this.draftController,
    required this.onDeadlineChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onScheduleCleared,
    required this.onRecurrenceChanged,
    required this.titleController,
    required this.onAddToCriticalPath,
    required this.onRemindersChanged,
    required this.queuedPaths,
    required this.onRemoveQueuedPath,
  });

  final LocationAutocompleteHelper locationHelper;
  final TextEditingController descriptionController;
  final TextEditingController locationController;
  final TaskChecklistController checklistController;
  final TaskDraftController draftController;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onScheduleCleared;
  final ValueChanged<RecurrenceFormValue> onRecurrenceChanged;
  final TextEditingController titleController;
  final Future<void> Function() onAddToCriticalPath;
  final ValueChanged<ReminderPreferences> onRemindersChanged;
  final List<CalendarCriticalPath> queuedPaths;
  final ValueChanged<String> onRemoveQueuedPath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: calendarGutterMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskDescriptionField(
            controller: descriptionController,
            hintText: l10n.calendarDescriptionHint,
            minLines: 2,
            maxLines: 4,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterLg,
              vertical: calendarGutterMd,
            ),
          ),
          const SizedBox(height: calendarInsetMd),
          TaskChecklist(controller: checklistController),
          const SizedBox(height: calendarFormGap),
          TaskLocationField(
            controller: locationController,
            hintText: l10n.calendarLocationHint,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterLg,
              vertical: calendarGutterMd,
            ),
            autocomplete: locationHelper,
          ),
          const SizedBox(height: calendarGutterMd),
          _AdvancedScheduleSection(
            draftController: draftController,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
            onClear: onScheduleCleared,
          ),
          const TaskSectionDivider(),
          TaskSectionHeader(title: l10n.calendarDeadlineLabel),
          const SizedBox(height: calendarInsetLg),
          AnimatedBuilder(
            animation: draftController,
            builder: (context, _) {
              return DeadlinePickerField(
                value: draftController.deadline,
                onChanged: onDeadlineChanged,
              );
            },
          ),
          const TaskSectionDivider(),
          AnimatedBuilder(
            animation: draftController,
            builder: (context, _) {
              return ReminderPreferencesField(
                value: draftController.reminders,
                onChanged: onRemindersChanged,
                anchor: draftController.deadline == null
                    ? ReminderAnchor.start
                    : ReminderAnchor.deadline,
              );
            },
          ),
          const TaskSectionDivider(),
          _AdvancedRecurrenceSection(
            draftController: draftController,
            onChanged: onRecurrenceChanged,
          ),
          const TaskSectionDivider(
            verticalPadding: calendarGutterLg,
          ),
          SizedBox(
            width: double.infinity,
            child: TaskSecondaryButton(
              label: 'Add to critical path',
              icon: Icons.route,
              onPressed: onAddToCriticalPath,
            ).withTapBounce(),
          ),
          const SizedBox(height: calendarInsetSm),
          CriticalPathMembershipList(
            paths: queuedPaths,
            onRemovePath: onRemoveQueuedPath,
          ),
        ],
      ),
    );
  }
}

class _AdvancedScheduleSection extends StatelessWidget {
  const _AdvancedScheduleSection({
    required this.draftController,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onClear,
  });

  final TaskDraftController draftController;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: draftController,
      builder: (context, _) {
        return TaskScheduleSection(
          spacing: calendarInsetLg,
          start: draftController.startTime,
          end: draftController.endTime,
          onStartChanged: onStartChanged,
          onEndChanged: onEndChanged,
          onClear: onClear,
        );
      },
    );
  }
}

class _AdvancedRecurrenceSection extends StatelessWidget {
  const _AdvancedRecurrenceSection({
    required this.draftController,
    required this.onChanged,
  });

  final TaskDraftController draftController;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: draftController,
      builder: (context, _) {
        final referenceStart = draftController.startTime;
        final fallbackWeekday =
            referenceStart?.weekday ?? DateTime.now().weekday;

        return TaskRecurrenceSection(
          spacing: calendarInsetLg,
          value: draftController.recurrence,
          fallbackWeekday: fallbackWeekday,
          spacingConfig: const RecurrenceEditorSpacing(
            chipSpacing: 8,
            chipRunSpacing: 8,
            weekdaySpacing: 12,
            advancedSectionSpacing: 12,
            endSpacing: 14,
            fieldGap: 12,
          ),
          intervalSelectWidth: 118,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({
    required this.onPressed,
    required this.enabled,
  });

  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TaskPrimaryButton(
        label: context.l10n.calendarAddTaskAction,
        onPressed: enabled ? onPressed : null,
      ),
    );
  }
}
