import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/rendering.dart' show RenderBox, RendererBinding;
import 'package:flutter/scheduler.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_model.dart';
import '../constants.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/recurrence_utils.dart';
import '../utils/task_title_validation.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import '../utils/nl_parser_service.dart';
import '../utils/nl_schedule_adapter.dart';
import 'edit_task_dropdown.dart';
import 'layout/calendar_layout.dart';
import 'controllers/calendar_sidebar_controller.dart';
import 'controllers/task_draft_controller.dart';
import 'models/task_context_action.dart';
import 'widgets/calendar_drag_target.dart';
import 'widgets/calendar_sidebar_draggable.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/recurrence_spacing_tokens.dart';
import 'widgets/location_inline_suggestion.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';
import 'widgets/task_field_character_hint.dart';
import 'feedback_system.dart';

class TaskSidebar extends StatefulWidget {
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
  State<TaskSidebar> createState() => TaskSidebarState();
}

class TaskSidebarState extends State<TaskSidebar>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  static const CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  late final CalendarSidebarController _sidebarController;
  late final TaskDraftController _draftController;
  final _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode(debugLabel: 'sidebarTitleInput');
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final TextEditingController _selectionTitleController =
      TextEditingController();
  final TextEditingController _selectionDescriptionController =
      TextEditingController();
  final TextEditingController _selectionLocationController =
      TextEditingController();
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
  BaseCalendarBloc? _calendarBloc;
  BaseCalendarBloc get _bloc {
    final BaseCalendarBloc? bloc = _calendarBloc;
    if (bloc == null) {
      throw StateError('TaskSidebar requires BaseCalendarBloc in the tree.');
    }
    return bloc;
  }

  String _selectionRecurrenceSignature = '';
  late final ValueNotifier<RecurrenceFormValue> _selectionRecurrenceNotifier;
  late final ValueNotifier<bool> _selectionRecurrenceMixedNotifier;

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
  String? _quickTaskError;

  RecurrenceFormValue get _advancedRecurrence => _draftController.recurrence;
  RecurrenceFormValue get _selectionRecurrence =>
      _selectionRecurrenceNotifier.value;
  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  bool _selectionTitleDirty = false;
  bool _selectionDescriptionDirty = false;
  bool _selectionLocationDirty = false;
  String _selectionFieldsSignature = '';
  String _selectionTitleInitialValue = '';
  String _selectionDescriptionInitialValue = '';
  String _selectionLocationInitialValue = '';
  bool _isUpdatingSelectionTitle = false;
  bool _isUpdatingSelectionDescription = false;
  bool _isUpdatingSelectionLocation = false;
  int? _activeResizePointerId;

  bool get _hasPendingSelectionEdits =>
      _selectionTitleDirty ||
      _selectionDescriptionDirty ||
      _selectionLocationDirty;

  bool _externalGridDragActive = false;

  bool get _hasPrecisePointerInput =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  bool get _isTouchOnlyInput => !_hasPrecisePointerInput;

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

  void _handleQuickTaskInputChanged(String value) {
    _ensureAdvancedOptionsVisible();
    final trimmed = value.trim();
    _updateQuickTaskValidation(value);
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

  void _updateQuickTaskValidation(String raw) {
    final bool tooLong = TaskTitleValidation.isTooLong(raw);
    final bool hasContent = raw.trim().isNotEmpty;
    String? nextError = _quickTaskError;

    if (tooLong) {
      nextError = calendarTaskTitleFriendlyError;
    } else {
      if (_quickTaskError == calendarTaskTitleFriendlyError) {
        nextError = null;
      }
      if (_quickTaskError == TaskTitleValidation.requiredMessage &&
          hasContent) {
        nextError = null;
      }
    }

    if (nextError != _quickTaskError) {
      setState(() {
        _quickTaskError = nextError;
      });
    }
  }

  void _ensureAdvancedOptionsVisible() {
    if (!_sidebarController.state.showAdvancedOptions) {
      _sidebarController.toggleAdvancedOptions();
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Parser unavailable (${error.runtimeType})')),
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

  void _resetParserLocks() {
    _locationLocked = false;
    _scheduleLocked = false;
    _deadlineLocked = false;
    _recurrenceLocked = false;
    _priorityLocked = false;
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
    _selectionRecurrenceNotifier =
        ValueNotifier<RecurrenceFormValue>(const RecurrenceFormValue());
    _selectionRecurrenceMixedNotifier = ValueNotifier<bool>(false);
    _nlParserService = NlScheduleParserService();
    _locationController.addListener(_handleLocationEdited);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calendarBloc ??= BlocProvider.of<BaseCalendarBloc>(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _descriptionController.dispose();
    _locationController.removeListener(_handleLocationEdited);
    _locationController.dispose();

    _selectionTitleController.dispose();
    _selectionDescriptionController.dispose();
    _selectionLocationController.dispose();
    _scrollController.dispose();
    _draftController.dispose();
    _selectionRecurrenceNotifier.dispose();
    _selectionRecurrenceMixedNotifier.dispose();
    _sidebarAutoScrollTicker?.dispose();
    _parserDebounce?.cancel();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    _sidebarController.dispose();
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
        final BaseCalendarBloc calendarBloc = _bloc;
        return Container(
          width: uiState.width,
          decoration: const BoxDecoration(
            color: sidebarBackgroundColor,
            border: Border(
              right: BorderSide(
                color: calendarBorderColor,
                width: calendarBorderStroke,
              ),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: BlocBuilder<BaseCalendarBloc, CalendarState>(
                  bloc: calendarBloc,
                  builder: (context, state) {
                    final locationHelper =
                        LocationAutocompleteHelper.fromState(state);
                    final content = state.isSelectionMode
                        ? _buildSelectionPanel(state, uiState, locationHelper)
                        : _buildUnscheduledContent(
                            state,
                            uiState,
                            locationHelper,
                          );

                    final Set<String> activeTaskIds = state.isSelectionMode
                        ? _selectedTasks(state).map((task) => task.id).toSet()
                        : state.unscheduledTasks.map((task) => task.id).toSet();
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
                _buildResizeHandle(uiState),
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

  Widget _buildAddTaskSection(
    CalendarSidebarState uiState,
    LocationAutocompleteHelper locationHelper,
  ) {
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD TASK',
            style: calendarHeaderTextStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: calendarTimeLabelColor,
            ),
          ),
          const SizedBox(height: calendarSidebarSectionSpacing),
          _buildQuickTaskInput(locationHelper),
          const SizedBox(height: calendarSidebarSectionSpacing),
          _buildPriorityToggles(),
          const SizedBox(height: calendarSidebarToggleSpacing),
          _buildAdvancedToggle(uiState),
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
                ? _buildAdvancedOptions(
                    key: const ValueKey('advanced'),
                    locationHelper: locationHelper,
                  )
                : const SizedBox.shrink(key: ValueKey('advanced-hidden')),
          ),
          const SizedBox(height: calendarSidebarSectionSpacing),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildUnscheduledContent(
    CalendarState state,
    CalendarSidebarState uiState,
    LocationAutocompleteHelper locationHelper,
  ) {
    final unscheduledTasks = _sortTasksByDeadline(
      state.unscheduledTasks.where((task) => task.deadline == null).toList(),
    );
    final reminderTasks = _sortTasksByDeadline(
      state.unscheduledTasks.where((task) => task.deadline != null).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddTaskSection(uiState, locationHelper),
        _buildTaskSections(
          unscheduledTasks,
          reminderTasks,
          uiState,
        ),
      ],
    );
  }

  Widget _buildSelectionPanel(
    CalendarState state,
    CalendarSidebarState uiState,
    LocationAutocompleteHelper locationHelper,
  ) {
    final tasks = _selectedTasks(state);
    _syncSelectionRecurrenceState(tasks);
    _syncSelectionFieldControllers(tasks);
    final total = tasks.length;
    final hasTasks = tasks.isNotEmpty;
    final bool allCompleted =
        hasTasks && tasks.every((task) => task.isCompleted);
    final bool anyCompleted = tasks.any((task) => task.isCompleted);
    final bool completionIndeterminate =
        hasTasks && anyCompleted && !allCompleted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                title: 'Selection mode',
                padding: const EdgeInsets.only(bottom: calendarGutterSm),
                trailing: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () =>
                      _bloc.add(const CalendarEvent.selectionCleared()),
                  child: const Text('Exit'),
                ),
              ),
              Text(
                '$total task${total == 1 ? '' : 's'} selected',
                style: calendarSubtitleTextStyle,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              const TaskSectionHeader(title: 'Actions'),
              const SizedBox(height: calendarGutterSm),
              _buildSelectionActions(tasks, hasTasks),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              _buildSelectionBatchEditSection(hasTasks, locationHelper),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              const TaskSectionHeader(title: 'Set priority'),
              const SizedBox(height: calendarGutterSm),
              _buildPriorityControls(tasks),
              const SizedBox(height: calendarGutterMd),
              _buildSelectionCompletionToggle(
                hasTasks: hasTasks,
                allCompleted: allCompleted,
                isIndeterminate: completionIndeterminate,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarGutterMd,
              ),
              _buildSelectionRecurrenceSection(tasks),
            ],
          ),
        ),
        const SizedBox(height: calendarGutterLg),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarGutterLg),
          child: _buildSelectedTaskList(tasks, uiState),
        ),
      ],
    );
  }

  Widget _buildSelectionActions(List<CalendarTask> tasks, bool hasTasks) {
    final bloc = _bloc;
    return TaskFormActionsRow(
      padding: EdgeInsets.zero,
      gap: calendarGutterSm,
      children: [
        TaskSecondaryButton(
          label: 'Clear Selection',
          onPressed: hasTasks
              ? () => bloc.add(const CalendarEvent.selectionCleared())
              : null,
        ),
        TaskDestructiveButton(
          label: 'Delete selected',
          onPressed: hasTasks
              ? () => bloc.add(const CalendarEvent.selectionDeleted())
              : null,
        ),
      ],
    );
  }

  Widget _buildPriorityControls(List<CalendarTask> tasks) {
    final bloc = _bloc;
    final bool hasTasks = tasks.isNotEmpty;

    final bool allImportant =
        hasTasks && tasks.every((task) => task.isImportant || task.isCritical);
    final bool anyImportant =
        tasks.any((task) => task.isImportant || task.isCritical);

    final bool allUrgent =
        hasTasks && tasks.every((task) => task.isUrgent || task.isCritical);
    final bool anyUrgent =
        tasks.any((task) => task.isUrgent || task.isCritical);

    void updatePriority({required bool important, required bool urgent}) {
      final TaskPriority target;
      if (important && urgent) {
        target = TaskPriority.critical;
      } else if (important) {
        target = TaskPriority.important;
      } else if (urgent) {
        target = TaskPriority.urgent;
      } else {
        target = TaskPriority.none;
      }
      bloc.add(
        CalendarEvent.selectionPriorityChanged(priority: target),
      );
    }

    return TaskPriorityToggles(
      isImportant: allImportant,
      isUrgent: allUrgent,
      isImportantIndeterminate: anyImportant && !allImportant,
      isUrgentIndeterminate: anyUrgent && !allUrgent,
      onImportantChanged: hasTasks
          ? (selected) => updatePriority(
                important: selected,
                urgent: allUrgent,
              )
          : null,
      onUrgentChanged: hasTasks
          ? (selected) => updatePriority(
                important: allImportant,
                urgent: selected,
              )
          : null,
    );
  }

  Widget _buildSelectionCompletionToggle({
    required bool hasTasks,
    required bool allCompleted,
    required bool isIndeterminate,
  }) {
    return TaskCompletionToggle(
      value: allCompleted,
      isIndeterminate: isIndeterminate,
      enabled: hasTasks,
      onChanged: hasTasks
          ? (completed) => _bloc.add(
                CalendarEvent.selectionCompletedToggled(
                  completed: completed,
                ),
              )
          : null,
    );
  }

  Widget _buildSelectionRecurrenceSection(List<CalendarTask> tasks) {
    final hasTasks = tasks.isNotEmpty;
    if (!hasTasks) {
      return const Text(
        'No tasks selected.',
        style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    final fallbackWeekday = _defaultSelectionWeekday(tasks);

    return ValueListenableBuilder<RecurrenceFormValue>(
      valueListenable: _selectionRecurrenceNotifier,
      builder: (context, recurrence, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: _selectionRecurrenceMixedNotifier,
          builder: (context, isMixed, __) {
            final children = <Widget>[];
            if (isMixed) {
              children.add(
                Container(
                  margin: const EdgeInsets.only(bottom: calendarGutterSm),
                  padding: const EdgeInsets.symmetric(
                      horizontal: calendarGutterMd, vertical: calendarGutterSm),
                  decoration: BoxDecoration(
                    color: calendarWarningColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: calendarWarningColor.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Text(
                    'Tasks have different recurrence settings. Updates will apply to all selected tasks.',
                    style:
                        TextStyle(fontSize: 12, color: calendarSubtitleColor),
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
                onChanged: (next) {
                  final normalized = _normalizeSelectionRecurrence(next);
                  _selectionRecurrenceNotifier.value = normalized;
                  if (_selectionRecurrenceMixedNotifier.value) {
                    _selectionRecurrenceMixedNotifier.value = false;
                  }
                  _dispatchSelectionRecurrence();
                },
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

  void _dispatchSelectionRecurrence() {
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      return;
    }

    final reference = bloc.state.selectedDate;
    final recurrence = _selectionRecurrence.isActive
        ? _selectionRecurrence.toRule(start: reference)
        : null;

    bloc.add(
      CalendarEvent.selectionRecurrenceChanged(
        recurrence: recurrence,
      ),
    );
  }

  RecurrenceFormValue _normalizeSelectionRecurrence(RecurrenceFormValue value) {
    final bloc = _bloc;
    final DateTime reference = bloc.state.selectedDate;
    return value.resolveLinkedLimits(reference);
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

  Widget _buildSelectionBatchEditSection(
    bool hasTasks,
    LocationAutocompleteHelper locationHelper,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Batch edit'),
        const SizedBox(height: calendarGutterSm),
        _buildSelectionTextField(
          label: 'Title',
          controller: _selectionTitleController,
          hint: 'Set title for selected tasks',
          enabled: hasTasks,
          onChanged: _handleSelectionTitleChanged,
        ),
        const SizedBox(height: calendarGutterSm),
        _buildSelectionTextField(
          label: 'Description',
          controller: _selectionDescriptionController,
          hint: 'Set description (leave blank to clear)',
          enabled: hasTasks,
          minLines: 2,
          maxLines: 3,
          onChanged: _handleSelectionDescriptionChanged,
        ),
        const SizedBox(height: calendarGutterSm),
        _buildSelectionLocationField(hasTasks, locationHelper),
        const SizedBox(height: calendarGutterMd),
        Align(
          alignment: Alignment.centerLeft,
          child: TaskPrimaryButton(
            label: 'Apply changes',
            size: ShadButtonSize.sm,
            onPressed: hasTasks && _hasPendingSelectionEdits
                ? _applySelectionBatchChanges
                : null,
          ),
        ),
        const SizedBox(height: calendarGutterMd),
        const TaskSectionDivider(
          verticalPadding: calendarGutterMd,
        ),
        const TaskSectionHeader(title: 'Adjust time'),
        const SizedBox(height: calendarGutterSm),
        _buildSelectionTimeAdjustRow(hasTasks),
      ],
    );
  }

  Widget _buildSelectionTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool enabled,
    int minLines = 1,
    int? maxLines,
    ValueChanged<String>? onChanged,
  }) {
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

  Widget _buildSelectionLocationField(
    bool enabled,
    LocationAutocompleteHelper helper,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOCATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: calendarInsetMd),
        TaskLocationField(
          controller: _selectionLocationController,
          hintText: 'Set location (leave blank to clear)',
          textCapitalization: TextCapitalization.words,
          enabled: enabled,
          onChanged: _handleSelectionLocationChanged,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd,
            vertical: calendarGutterSm,
          ),
          autocomplete: helper,
        ),
      ],
    );
  }

  Widget _buildSelectionTimeAdjustRow(bool enabled) {
    final buttons = [
      _SelectionAdjustButton(
        label: 'Start -15m',
        onPressed: enabled
            ? () => _shiftSelectionTime(
                  startDelta: -_selectionTimeStep,
                )
            : null,
      ),
      _SelectionAdjustButton(
        label: 'Start +15m',
        onPressed: enabled
            ? () => _shiftSelectionTime(
                  startDelta: _selectionTimeStep,
                )
            : null,
      ),
      _SelectionAdjustButton(
        label: 'End -15m',
        onPressed: enabled
            ? () => _shiftSelectionTime(
                  endDelta: -_selectionTimeStep,
                )
            : null,
      ),
      _SelectionAdjustButton(
        label: 'End +15m',
        onPressed: enabled
            ? () => _shiftSelectionTime(
                  endDelta: _selectionTimeStep,
                )
            : null,
      ),
    ];

    return Wrap(
      spacing: calendarGutterSm,
      runSpacing: calendarGutterSm,
      children: buttons,
    );
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

  void _applySelectionBatchChanges() {
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      _showSelectionMessage('Select tasks before applying changes.');
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

    if (applied && !hadError) {
      _showSelectionMessage('Changes applied to selected tasks.');
    } else if (!applied && !hadError) {
      _showSelectionMessage('No pending changes to apply.');
    }
  }

  bool _applySelectionTitle() {
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      _showSelectionMessage('Select tasks before applying changes.');
      return false;
    }
    final title = _selectionTitleController.text.trim();
    if (title.isEmpty) {
      _showSelectionMessage('Title cannot be blank.');
      return false;
    }
    bloc.add(CalendarEvent.selectionTitleChanged(title: title));
    setState(() {
      _selectionTitleDirty = false;
    });
    return true;
  }

  bool _applySelectionDescription() {
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      _showSelectionMessage('Select tasks before applying changes.');
      return false;
    }
    final raw = _selectionDescriptionController.text.trim();
    final description = raw.isEmpty ? null : raw;
    bloc.add(
      CalendarEvent.selectionDescriptionChanged(description: description),
    );
    setState(() {
      _selectionDescriptionDirty = false;
    });
    return true;
  }

  bool _applySelectionLocation() {
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      _showSelectionMessage('Select tasks before applying changes.');
      return false;
    }
    final raw = _selectionLocationController.text.trim();
    final location = raw.isEmpty ? null : raw;
    bloc.add(
      CalendarEvent.selectionLocationChanged(location: location),
    );
    setState(() {
      _selectionLocationDirty = false;
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
    final bloc = _bloc;
    if (bloc.state.selectedTaskIds.isEmpty) {
      _showSelectionMessage('Select tasks before adjusting time.');
      return;
    }
    bloc.add(
      CalendarEvent.selectionTimeShifted(
        startDelta: startDelta,
        endDelta: endDelta,
      ),
    );
  }

  void _showSelectionMessage(String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
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
      _selectionTitleInitialValue = sharedTitle ?? '';
      _selectionDescriptionInitialValue = sharedDescription ?? '';
      _selectionLocationInitialValue = sharedLocation ?? '';
      if (_selectionTitleDirty ||
          _selectionDescriptionDirty ||
          _selectionLocationDirty) {
        _selectionTitleDirty = false;
        _selectionDescriptionDirty = false;
        _selectionLocationDirty = false;
      }
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

  Widget _buildSelectedTaskList(
    List<CalendarTask> tasks,
    CalendarSidebarState uiState,
  ) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(calendarGutterLg),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(calendarBorderRadius + 2),
          border: Border.all(color: calendarBorderColor),
        ),
        child: const Text(
          'No tasks selected. Use the Select option in the calendar to pick tasks to edit.',
          style: TextStyle(
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
          _buildSelectionTaskTile(
            task,
            uiState: uiState,
          ),
      ],
    );
  }

  Widget _buildSelectionTaskTile(
    CalendarTask task, {
    required CalendarSidebarState uiState,
  }) {
    final borderColor = task.priorityColor;
    final bool isActive = uiState.activePopoverTaskId == task.id;
    final bloc = _bloc;
    final String scheduleLabel = _selectionScheduleLabel(task);

    return Container(
      margin: const EdgeInsets.only(bottom: calendarGutterSm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _focusTask(task),
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
              child: _buildTaskTileBody(
                task,
                scheduleLabel: scheduleLabel,
                trailing: Tooltip(
                  message: 'Remove from selection',
                  child: ShadIconButton.ghost(
                    onPressed: () => bloc.add(
                      CalendarEvent.selectionIdsRemoved(taskIds: {task.id}),
                    ),
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
    );
  }

  void _focusTask(CalendarTask task) {
    _bloc.add(
      CalendarEvent.taskFocusRequested(taskId: task.id),
    );
  }

  String _selectionScheduleLabel(CalendarTask task) {
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      return 'No scheduled time';
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

  Widget _buildQuickTaskInput(LocationAutocompleteHelper helper) {
    const padding = EdgeInsets.symmetric(
      horizontal: calendarGutterLg,
      vertical: 14,
    );
    final field = TaskTextField(
      controller: _titleController,
      focusNode: _titleFocusNode,
      hintText: 'Quick task (e.g., "Meeting at 2pm in Room 101")',
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onChanged: _handleQuickTaskInputChanged,
      onSubmitted: (_) => _addTask(),
      contentPadding: padding,
      errorText: _quickTaskError,
    );

    final suggestionField = LocationInlineSuggestion(
      controller: _titleController,
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
        TaskFieldCharacterHint(controller: _titleController),
      ],
    );
  }

  Widget _buildPriorityToggles() {
    return AnimatedBuilder(
      animation: _draftController,
      builder: (context, _) {
        return TaskPriorityToggles(
          isImportant: _draftController.isImportant,
          isUrgent: _draftController.isUrgent,
          onImportantChanged: _onUserImportantChanged,
          onUrgentChanged: _onUserUrgentChanged,
        );
      },
    );
  }

  Widget _buildAdvancedToggle(CalendarSidebarState uiState) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        foregroundColor: calendarPrimaryColor,
        hoverForegroundColor: calendarPrimaryHoverColor,
        hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        onPressed: _sidebarController.toggleAdvancedOptions,
        leading: Icon(
          uiState.showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: calendarPrimaryColor,
        ),
        child: Text(
          uiState.showAdvancedOptions
              ? 'Hide advanced options'
              : 'Show advanced options',
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions({
    Key? key,
    required LocationAutocompleteHelper locationHelper,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: calendarGutterMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskDescriptionField(
            controller: _descriptionController,
            hintText: 'Description (optional)',
            minLines: 2,
            maxLines: 4,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterLg,
              vertical: calendarGutterMd,
            ),
          ),
          const SizedBox(height: calendarFormGap),
          TaskLocationField(
            controller: _locationController,
            hintText: 'Location (optional)',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarGutterLg,
              vertical: calendarGutterMd,
            ),
            autocomplete: locationHelper,
          ),
          const SizedBox(height: calendarGutterMd),
          const TaskSectionHeader(title: 'Deadline'),
          const SizedBox(height: calendarInsetLg),
          AnimatedBuilder(
            animation: _draftController,
            builder: (context, _) {
              return DeadlinePickerField(
                value: _draftController.deadline,
                onChanged: _onUserDeadlineChanged,
              );
            },
          ),
          const TaskSectionDivider(),
          _buildAdvancedScheduleSection(),
          const TaskSectionDivider(),
          _buildAdvancedRecurrenceSection(),
        ],
      ),
    );
  }

  Widget _buildAdvancedScheduleSection() {
    return AnimatedBuilder(
      animation: _draftController,
      builder: (context, _) {
        return TaskScheduleSection(
          spacing: calendarInsetLg,
          start: _draftController.startTime,
          end: _draftController.endTime,
          onStartChanged: _onUserStartChanged,
          onEndChanged: _onUserEndChanged,
          onClear: _onUserScheduleCleared,
        );
      },
    );
  }

  Widget _buildAdvancedRecurrenceSection() {
    return AnimatedBuilder(
      animation: _draftController,
      builder: (context, _) {
        final referenceStart = _draftController.startTime;
        final fallbackWeekday =
            referenceStart?.weekday ?? DateTime.now().weekday;

        return TaskRecurrenceSection(
          spacing: calendarInsetLg,
          value: _draftController.recurrence,
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
          onChanged: _onUserRecurrenceChanged,
        );
      },
    );
  }

  Widget _buildAddButton() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _titleController,
      builder: (context, value, _) {
        final isDisabled = value.text.trim().isEmpty;
        return SizedBox(
          width: double.infinity,
          child: TaskPrimaryButton(
            label: 'Add Task',
            onPressed: isDisabled ? null : _addTask,
          ),
        );
      },
    );
  }

  Widget _buildTaskSections(
    List<CalendarTask> unscheduledTasks,
    List<CalendarTask> reminderTasks,
    CalendarSidebarState uiState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccordionSection(
          title: 'UNSCHEDULED TASKS',
          section: CalendarSidebarSection.unscheduled,
          uiState: uiState,
          itemCount: unscheduledTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterSm,
              vertical: calendarInsetMd,
            ),
            child: _buildTaskList(
              unscheduledTasks,
              emptyLabel: 'No unscheduled tasks',
              emptyHint: 'Tasks you add will appear here',
              uiState: uiState,
            ),
          ),
          collapsedChild: _buildCollapsedPreview(unscheduledTasks),
        ),
        const SizedBox(height: calendarInsetMd),
        _buildAccordionSection(
          title: 'REMINDERS',
          section: CalendarSidebarSection.reminders,
          uiState: uiState,
          itemCount: reminderTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: calendarGutterSm,
              vertical: calendarInsetMd,
            ),
            child: _buildReminderList(reminderTasks, uiState),
          ),
          collapsedChild: _buildCollapsedPreview(reminderTasks),
        ),
      ],
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required CalendarSidebarSection section,
    required int itemCount,
    required Widget expandedChild,
    required Widget collapsedChild,
    required CalendarSidebarState uiState,
  }) {
    final bool isExpanded = uiState.expandedSection == section;

    Widget buildContent() {
      return Column(
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
                InkWell(
                  onTap: () => _sidebarController.toggleSection(section),
                  child: Padding(
                    padding: calendarFieldPadding,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: calendarSubtitleColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        _buildCountBadge(itemCount, isExpanded),
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
                          onEnter: (_) =>
                              _handleSidebarSectionDragEnter(section),
                          onMove: (_) =>
                              _handleSidebarSectionDragEnter(section),
                          onDrop: (details) {
                            _handleSidebarSectionDragEnter(section);
                            _handleTaskDroppedIntoSidebar(
                              details.payload.task,
                            );
                          },
                          builder: (context, isHovering, __) {
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () =>
                                  _sidebarController.toggleSection(section),
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
                                          alpha: 0.12)
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
    }

    final content = buildContent();
    final GlobalKey? key = _sectionKeys[section];
    if (key == null) {
      return content;
    }
    return KeyedSubtree(key: key, child: content);
  }

  Widget _buildCollapsedPreview(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      return const Text(
        'Nothing here yet',
        style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    final previewTitles = tasks.map((task) => task.title).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: previewTitles
          .map(
            (title) => Padding(
              padding: const EdgeInsets.only(bottom: calendarInsetSm),
              child: Text(
                '• $title',
                style:
                    const TextStyle(fontSize: 12, color: calendarSubtitleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }

  void _handleSidebarSectionDragEnter(CalendarSidebarSection section) {
    _sidebarController.expandSection(section);
  }

  void _handleTaskDroppedIntoSidebar(CalendarTask dropped) {
    final bloc = _bloc;
    final model = bloc.state.model;
    CalendarTask? source =
        model.tasks[dropped.id] ?? model.tasks[dropped.baseId];
    source ??= model.resolveTaskInstance(dropped.id);
    if (source == null) {
      FeedbackSystem.showError(context, 'Task not found');
      return;
    }
    final CalendarTask unscheduled = source.copyWith(
      scheduledTime: null,
      duration: null,
      endDate: null,
      startHour: null,
      modifiedAt: DateTime.now(),
    );
    bloc.add(
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

  Widget _buildTaskList(
    List<CalendarTask> tasks, {
    required String emptyLabel,
    String? emptyHint,
    required CalendarSidebarState uiState,
  }) {
    return CalendarDragTargetRegion(
      onEnter: _handleSidebarDragTargetHover,
      onMove: _handleSidebarDragTargetHover,
      onLeave: (_) => _stopSidebarAutoScroll(),
      onDrop: (details) {
        _stopSidebarAutoScroll();
        _forwardSidebarGlobalPosition(
          details.globalPosition,
          notifyParent: false,
        );
        _handleTaskDroppedIntoSidebar(details.payload.task);
      },
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
              ? _buildEmptyState(
                  label: emptyLabel,
                  hint: emptyHint,
                  isHovering: isHovering,
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                      horizontal: calendarInsetLg, vertical: 2),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildDraggableTaskTile(task, uiState);
                  },
                ),
        );
      },
    );
  }

  Widget _buildReminderList(
    List<CalendarTask> tasks,
    CalendarSidebarState uiState,
  ) {
    return _buildTaskList(
      tasks,
      emptyLabel: 'No reminders yet',
      emptyHint: 'Add a deadline to create a reminder',
      uiState: uiState,
    );
  }

  Widget _buildEmptyState({
    required String label,
    String? hint,
    required bool isHovering,
  }) {
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
              const SizedBox(height: calendarInsetMd),
              Text(
                hint,
                style: const TextStyle(
                  color: calendarTimeLabelColor,
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

  Widget _buildCountBadge(int count, bool isExpanded) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterSm, vertical: calendarInsetMd),
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

  Widget _buildDraggableTaskTile(
    CalendarTask task,
    CalendarSidebarState uiState,
  ) {
    final Widget baseTile = _buildTaskTile(task, uiState: uiState);
    final Widget fadedTile = Opacity(
      opacity: 0.3,
      child: _buildTaskTile(
        task,
        uiState: uiState,
        enableInteraction: false,
      ),
    );
    final Widget feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.8,
        child: SizedBox(
          width: uiState.width - 32,
          child: _buildTaskTile(
            task,
            uiState: uiState,
            enableInteraction: false,
          ),
        ),
      ),
    );

    return CalendarSidebarDraggable(
      task: task,
      childWhenDragging: fadedTile,
      feedback: feedback,
      onDragSessionStarted: _handleSidebarDragSessionStarted,
      onDragSessionEnded: _handleSidebarDragSessionEnded,
      onDragGlobalPositionChanged: _forwardSidebarGlobalPosition,
      requiresLongPress: _isTouchOnlyInput,
      child: baseTile,
    );
  }

  Widget _buildTaskTile(
    CalendarTask task, {
    required CalendarSidebarState uiState,
    bool enableInteraction = true,
  }) {
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
                      if (_shouldUseSheetMenus(tileContext)) {
                        return InkWell(
                          borderRadius:
                              BorderRadius.circular(calendarBorderRadius),
                          hoverColor: calendarSidebarBackgroundColor.withValues(
                              alpha: 0.5),
                          onTap: () => _showTaskEditSheet(tileContext, task),
                          child: _buildTaskTileBody(task),
                        );
                      }

                      final controller = _popoverControllerFor(task.id);
                      final renderBox =
                          tileContext.findRenderObject() as RenderBox?;
                      final tileSize = renderBox?.size ?? Size.zero;
                      final tileOrigin =
                          renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                      final screenSize = MediaQuery.of(tileContext).size;

                      const double margin = calendarPopoverScreenMargin;
                      const double dropdownMaxHeight =
                          calendarSidebarPopoverMaxHeight; // Increased by 40% from 460
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
                          ScaffoldMessenger.maybeOf(context);

                      return ShadPopover(
                        controller: controller,
                        closeOnTapOutside: true,
                        anchor: anchor,
                        padding: EdgeInsets.zero,
                        popover: (context) {
                          return BlocBuilder<BaseCalendarBloc, CalendarState>(
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

                              return EditTaskDropdown(
                                task: displayTask,
                                maxHeight: effectiveMaxHeight,
                                onClose: () => _closeTaskPopover(task.id),
                                scaffoldMessenger: scaffoldMessenger,
                                locationHelper:
                                    LocationAutocompleteHelper.fromState(state),
                                onTaskUpdated: (updatedTask) {
                                  _bloc.add(
                                    CalendarEvent.taskUpdated(
                                      task: updatedTask,
                                    ),
                                  );
                                },
                                onOccurrenceUpdated: shouldUpdateOccurrence
                                    ? (updatedTask) {
                                        _bloc.add(
                                          CalendarEvent.taskOccurrenceUpdated(
                                            taskId: baseId,
                                            occurrenceId: task.id,
                                            scheduledTime:
                                                updatedTask.scheduledTime,
                                            duration: updatedTask.duration,
                                            endDate: updatedTask.endDate,
                                          ),
                                        );

                                        final seriesUpdate =
                                            latestTask.copyWith(
                                          title: updatedTask.title,
                                          description: updatedTask.description,
                                          location: updatedTask.location,
                                          deadline: updatedTask.deadline,
                                          priority: updatedTask.priority,
                                          isCompleted: updatedTask.isCompleted,
                                        );

                                        if (seriesUpdate != latestTask) {
                                          _bloc.add(
                                            CalendarEvent.taskUpdated(
                                              task: seriesUpdate,
                                            ),
                                          );
                                        }
                                      }
                                    : null,
                                onTaskDeleted: (taskId) {
                                  _bloc.add(
                                    CalendarEvent.taskDeleted(
                                      taskId: taskId,
                                    ),
                                  );
                                  _closeTaskPopover(task.id);
                                  _taskPopoverControllers
                                      .remove(task.id)
                                      ?.dispose();
                                },
                              );
                            },
                          );
                        },
                        child: InkWell(
                          borderRadius:
                              BorderRadius.circular(calendarBorderRadius),
                          hoverColor: calendarSidebarBackgroundColor.withValues(
                              alpha: 0.5),
                          onTap: () => _toggleTaskPopover(task.id),
                          child: _buildTaskTileBody(task),
                        ),
                      );
                    },
                  )
                : _buildTaskTileBody(task),
          ),
        ),
      ),
    );

    if (enableInteraction && _hasPrecisePointerInput) {
      tile = _wrapWithSidebarContextMenu(task: task, child: tile);
    }

    return tile;
  }

  Widget _wrapWithSidebarContextMenu({
    required CalendarTask task,
    required Widget child,
  }) {
    return ShadContextMenuRegion(
      items: _buildSidebarContextMenuItems(task),
      child: child,
    );
  }

  List<TaskContextAction> _buildSidebarInlineActions(CalendarTask task) {
    return [
      TaskContextAction(
        icon: Icons.copy_outlined,
        label: 'Copy',
        onSelected: () => _copyTaskDetails(task),
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
      buffer.writeln('Location: $location');
    }
    final deadline = task.deadline;
    if (deadline != null) {
      buffer.writeln(
        'Due: ${TimeFormatter.formatFriendlyDateTime(deadline)}',
      );
    }
    final payload = buffer.toString().trim().isEmpty
        ? task.title.trim()
        : buffer.toString().trim();
    Clipboard.setData(ClipboardData(text: payload));
    if (mounted) {
      FeedbackSystem.showSuccess(context, 'Task copied');
    }
  }

  void _deleteSidebarTask(CalendarTask task) {
    _bloc.add(CalendarEvent.taskDeleted(taskId: task.id));
    _closeTaskPopover(task.id);
    _taskPopoverControllers.remove(task.id)?.dispose();
  }

  List<Widget> _buildSidebarContextMenuItems(CalendarTask task) {
    return [
      ShadContextMenuItem(
        leading: const Icon(Icons.copy_outlined),
        onPressed: () => _copyTaskDetails(task),
        child: const Text('Copy Task'),
      ),
      ShadContextMenuItem(
        leading: const Icon(Icons.delete_outline),
        onPressed: () => _deleteSidebarTask(task),
        child: const Text('Delete Task'),
      ),
    ];
  }

  Widget _buildTaskTileBody(
    CalendarTask task, {
    Widget? trailing,
    String? scheduleLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        fontSize: 13,
                        color: calendarTitleColor,
                      ),
                    ),
                    if (scheduleLabel != null) ...[
                      const SizedBox(height: calendarInsetSm),
                      Text(
                        scheduleLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: calendarSubtitleColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: calendarInsetMd),
                trailing,
              ],
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
          if (task.deadline != null) ...[
            const SizedBox(height: calendarInsetLg),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: calendarGutterSm, vertical: calendarInsetMd),
              decoration: BoxDecoration(
                color: _getDeadlineBackgroundColor(task.deadline!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: _getDeadlineColor(task.deadline!),
                  ),
                  const SizedBox(width: calendarInsetMd),
                  Text(
                    _getFullDeadlineText(task.deadline!),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getDeadlineColor(task.deadline!),
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
    );
  }

  bool _shouldUseSheetMenus(BuildContext context) {
    final bool hasMouse =
        RendererBinding.instance.mouseTracker.mouseIsConnected;
    return ResponsiveHelper.isCompact(context) || !hasMouse;
  }

  Future<void> _showTaskEditSheet(
    BuildContext context,
    CalendarTask task,
  ) async {
    final bloc = _bloc;
    final state = bloc.state;
    final String baseId = task.baseId;
    final CalendarTask latestTask = state.model.tasks[baseId] ?? task;
    final CalendarTask? storedTask = state.model.tasks[task.id];
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

    await showModalBottomSheet<void>(
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
          Navigator.of(sheetContext).pop();
        }

        return AnimatedPadding(
          padding: EdgeInsets.only(
            top: safeTopInset,
            bottom: bottomInset,
            left: hostMediaQuery.padding.left,
            right: hostMediaQuery.padding.right,
          ),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: EditTaskDropdown(
            task: displayTask,
            maxHeight: maxHeight,
            isSheet: true,
            inlineActionsBloc: bloc,
            inlineActionsBuilder: (_) =>
                _buildSidebarInlineActions(displayTask),
            onClose: closeSheet,
            scaffoldMessenger: scaffoldMessenger,
            locationHelper: LocationAutocompleteHelper.fromState(state),
            onTaskUpdated: (updatedTask) {
              bloc.add(
                CalendarEvent.taskUpdated(
                  task: updatedTask,
                ),
              );
            },
            onOccurrenceUpdated: shouldUpdateOccurrence
                ? (updatedTask) {
                    bloc.add(
                      CalendarEvent.taskOccurrenceUpdated(
                        taskId: baseId,
                        occurrenceId: task.id,
                        scheduledTime: updatedTask.scheduledTime,
                        duration: updatedTask.duration,
                        endDate: updatedTask.endDate,
                      ),
                    );

                    final CalendarTask seriesUpdate = latestTask.copyWith(
                      title: updatedTask.title,
                      description: updatedTask.description,
                      location: updatedTask.location,
                      deadline: updatedTask.deadline,
                      priority: updatedTask.priority,
                      isCompleted: updatedTask.isCompleted,
                    );

                    if (seriesUpdate != latestTask) {
                      bloc.add(
                        CalendarEvent.taskUpdated(
                          task: seriesUpdate,
                        ),
                      );
                    }
                  }
                : null,
            onTaskDeleted: (taskId) {
              bloc.add(
                CalendarEvent.taskDeleted(
                  taskId: taskId,
                ),
              );
              _taskPopoverControllers.remove(task.id)?.dispose();
              _sidebarController.setActivePopoverTaskId(null);
              Navigator.of(sheetContext).pop();
            },
          ),
        );
      },
    );
  }

  Widget _buildResizeHandle(CalendarSidebarState uiState) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Listener(
          key: const ValueKey('calendar.sidebar.resizeHandle'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            if (_activeResizePointerId != null) {
              return;
            }
            _activeResizePointerId = event.pointer;
            _sidebarController.beginResize();
          },
          onPointerMove: (event) {
            if (_activeResizePointerId != event.pointer) {
              return;
            }
            final double deltaX = event.delta.dx;
            if (deltaX == 0) {
              return;
            }
            _sidebarController.adjustWidth(deltaX);
          },
          onPointerUp: (event) {
            if (_activeResizePointerId != event.pointer) {
              return;
            }
            _activeResizePointerId = null;
            _sidebarController.endResize();
          },
          onPointerCancel: (event) {
            if (_activeResizePointerId != event.pointer) {
              return;
            }
            _activeResizePointerId = null;
            _sidebarController.endResize();
          },
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

  String _getFullDeadlineText(DateTime deadline) {
    return TimeFormatter.formatFriendlyDateTime(deadline);
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return calendarDangerColor;
    } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
      return calendarWarningColor;
    }
    return calendarPrimaryColor;
  }

  Color _getDeadlineBackgroundColor(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return calendarDangerColor.withValues(alpha: 0.1);
    } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
      return calendarWarningColor.withValues(alpha: 0.1);
    }
    return calendarPrimaryColor.withValues(alpha: 0.08);
  }

  TaskPriority _currentPriority() {
    return _draftController.selectedPriority;
  }

  void _addTask() {
    final validationError = TaskTitleValidation.validate(_titleController.text);
    if (validationError != null) {
      setState(() {
        _quickTaskError = validationError;
      });
      FeedbackSystem.showWarning(context, validationError);
      return;
    }

    final rawTitle = _titleController.text.trim();
    if (rawTitle.isEmpty) return;
    final title = _effectiveParserTitle(rawTitle);

    final priority = _currentPriority();
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSchedule =
        _draftController.startTime != null && _draftController.endTime != null;
    final hasRecurrence = _advancedRecurrence.isActive;

    if (!hasLocation && !hasSchedule && !hasRecurrence) {
      _bloc.add(
        CalendarEvent.quickTaskAdded(
          text: title,
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          deadline: _draftController.deadline,
          priority: priority,
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

      _bloc.add(
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
        ),
      );
    }

    _resetForm();
  }

  void _resetForm() {
    _clearParserState(clearFields: true);
    _resetParserLocks();
    if (_quickTaskError != null) {
      setState(() {
        _quickTaskError = null;
      });
    }
    if (_titleController.text.isNotEmpty) {
      _titleController.clear();
    }
    if (_descriptionController.text.isNotEmpty) {
      _descriptionController.clear();
    }
    if (_locationController.text.isNotEmpty) {
      _locationController.clear();
    }
    if (mounted) {
      FocusScope.of(context).requestFocus(_titleFocusNode);
    }
  }

  ShadPopoverController _popoverControllerFor(String taskId) {
    if (_taskPopoverControllers.containsKey(taskId)) {
      return _taskPopoverControllers[taskId]!;
    }
    final controller = ShadPopoverController();
    controller.addListener(() {
      if (!mounted) return;
      if (!controller.isOpen &&
          _sidebarController.state.activePopoverTaskId == taskId) {
        _sidebarController.setActivePopoverTaskId(null);
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
