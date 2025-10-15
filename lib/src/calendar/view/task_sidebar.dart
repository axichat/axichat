import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'edit_task_dropdown.dart';
import 'layout/calendar_layout.dart';
import 'controllers/calendar_sidebar_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';

class TaskSidebar extends StatefulWidget {
  const TaskSidebar({super.key});

  @override
  State<TaskSidebar> createState() => _TaskSidebarState();
}

class _TaskSidebarState extends State<TaskSidebar>
    with TickerProviderStateMixin {
  static const CalendarLayoutTheme _layoutTheme = CalendarLayoutTheme.material;
  late final CalendarSidebarController _sidebarController;
  final _titleController = TextEditingController();
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
  late final ValueNotifier<RecurrenceFormValue> _advancedRecurrenceNotifier;

  String _selectionRecurrenceSignature = '';
  late final ValueNotifier<RecurrenceFormValue> _selectionRecurrenceNotifier;
  late final ValueNotifier<bool> _selectionRecurrenceMixedNotifier;

  RecurrenceFormValue get _advancedRecurrence =>
      _advancedRecurrenceNotifier.value;
  RecurrenceFormValue get _selectionRecurrence =>
      _selectionRecurrenceNotifier.value;
  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  bool _selectionTitleDirty = false;
  bool _selectionDescriptionDirty = false;
  bool _selectionLocationDirty = false;
  bool _isUpdatingSelectionTitle = false;
  bool _isUpdatingSelectionDescription = false;
  bool _isUpdatingSelectionLocation = false;

  bool get _hasPendingSelectionEdits =>
      _selectionTitleDirty ||
      _selectionDescriptionDirty ||
      _selectionLocationDirty;

  @override
  void initState() {
    super.initState();
    _sidebarController = CalendarSidebarController(
      width: _layoutTheme.sidebarMinWidth,
      minWidth: _layoutTheme.sidebarMinWidth,
      maxWidth: _layoutTheme.sidebarMinWidth,
    );
    _advancedRecurrenceNotifier =
        ValueNotifier<RecurrenceFormValue>(const RecurrenceFormValue());
    _selectionRecurrenceNotifier =
        ValueNotifier<RecurrenceFormValue>(const RecurrenceFormValue());
    _selectionRecurrenceMixedNotifier = ValueNotifier<bool>(false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _selectionTitleController.dispose();
    _selectionDescriptionController.dispose();
    _selectionLocationController.dispose();
    _scrollController.dispose();
    _advancedRecurrenceNotifier.dispose();
    _selectionRecurrenceNotifier.dispose();
    _selectionRecurrenceMixedNotifier.dispose();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    _sidebarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        final BaseCalendarBloc calendarBloc = context.read<BaseCalendarBloc>();
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
                    final content = state.isSelectionMode
                        ? _buildSelectionPanel(state, uiState)
                        : _buildUnscheduledContent(state, uiState);

                    return Scrollbar(
                      controller: _scrollController,
                      radius:
                          const Radius.circular(calendarSidebarScrollbarRadius),
                      thickness: _layoutTheme.sidebarScrollbarThickness,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: calendarSidebarScrollPadding,
                        physics: const ClampingScrollPhysics(),
                        child: content,
                      ),
                    );
                  },
                ),
              ),
              _buildResizeHandle(uiState),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAddTaskSection(CalendarSidebarState uiState) {
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
          _buildQuickTaskInput(),
          const SizedBox(height: calendarSidebarSectionSpacing),
          _buildPriorityToggles(uiState),
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
                    uiState,
                    key: const ValueKey('advanced'),
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
        _buildAddTaskSection(uiState),
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
  ) {
    final tasks = _selectedTasks(state);
    _syncSelectionRecurrenceState(tasks);
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
            horizontal: calendarSpacing16,
            vertical: calendarSpacing16,
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
                padding: const EdgeInsets.only(bottom: calendarSpacing8),
                trailing: ShadButton.outline(
                  size: ShadButtonSize.sm,
                  onPressed: () => context
                      .read<BaseCalendarBloc>()
                      .add(const CalendarEvent.selectionCleared()),
                  child: const Text('Exit'),
                ),
              ),
              Text(
                '$total task${total == 1 ? '' : 's'} selected',
                style: calendarSubtitleTextStyle,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarSpacing12,
              ),
              const TaskSectionHeader(title: 'Actions'),
              const SizedBox(height: calendarSpacing8),
              _buildSelectionActions(tasks, hasTasks),
              const TaskSectionDivider(
                verticalPadding: calendarSpacing12,
              ),
              _buildSelectionBatchEditSection(hasTasks),
              const TaskSectionDivider(
                verticalPadding: calendarSpacing12,
              ),
              const TaskSectionHeader(title: 'Set priority'),
              const SizedBox(height: calendarSpacing8),
              _buildPriorityControls(tasks),
              const SizedBox(height: calendarSpacing12),
              _buildSelectionCompletionToggle(
                hasTasks: hasTasks,
                allCompleted: allCompleted,
                isIndeterminate: completionIndeterminate,
              ),
              const TaskSectionDivider(
                verticalPadding: calendarSpacing12,
              ),
              _buildSelectionRecurrenceSection(tasks),
            ],
          ),
        ),
        const SizedBox(height: calendarSpacing16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarSpacing16),
          child: _buildSelectedTaskList(tasks, uiState),
        ),
      ],
    );
  }

  Widget _buildSelectionActions(List<CalendarTask> tasks, bool hasTasks) {
    final bloc = context.read<BaseCalendarBloc>();
    return TaskFormActionsRow(
      padding: EdgeInsets.zero,
      gap: calendarSpacing8,
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
    final bloc = context.read<BaseCalendarBloc>();
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
          ? (completed) => context.read<BaseCalendarBloc>().add(
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
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                spacingConfig: const RecurrenceEditorSpacing(
                  chipSpacing: 8,
                  chipRunSpacing: 8,
                  weekdaySpacing: 12,
                  advancedSectionSpacing: 12,
                  endSpacing: 14,
                  fieldGap: 12,
                ),
                intervalSelectWidth: 118,
                onChanged: (next) {
                  _selectionRecurrenceNotifier.value = next;
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
    final bloc = context.read<BaseCalendarBloc>();
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

    final currentValue = _selectionRecurrenceNotifier.value;
    if (!_formValuesEqual(currentValue, nextValue)) {
      _selectionRecurrenceNotifier.value = nextValue;
    }

    final shouldFlagMixed = !allSame;
    if (_selectionRecurrenceMixedNotifier.value != shouldFlagMixed) {
      _selectionRecurrenceMixedNotifier.value = shouldFlagMixed;
    }
  }

  Widget _buildSelectionBatchEditSection(bool hasTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Batch edit'),
        const SizedBox(height: calendarSpacing8),
        _buildSelectionTextField(
          label: 'Title',
          controller: _selectionTitleController,
          hint: 'Set title for selected tasks',
          enabled: hasTasks,
          onChanged: _handleSelectionTitleChanged,
        ),
        const SizedBox(height: calendarSpacing8),
        _buildSelectionTextField(
          label: 'Description',
          controller: _selectionDescriptionController,
          hint: 'Set description (leave blank to clear)',
          enabled: hasTasks,
          minLines: 2,
          maxLines: 3,
          onChanged: _handleSelectionDescriptionChanged,
        ),
        const SizedBox(height: calendarSpacing8),
        _buildSelectionTextField(
          label: 'Location',
          controller: _selectionLocationController,
          hint: 'Set location (leave blank to clear)',
          enabled: hasTasks,
          onChanged: _handleSelectionLocationChanged,
        ),
        const SizedBox(height: calendarSpacing12),
        const TaskSectionHeader(title: 'Adjust time'),
        const SizedBox(height: calendarSpacing8),
        _buildSelectionTimeAdjustRow(hasTasks),
        const SizedBox(height: calendarSpacing12),
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
        const SizedBox(height: calendarSpacing4),
        TaskTextField(
          controller: controller,
          hintText: hint,
          enabled: enabled,
          minLines: minLines,
          maxLines: maxLines ?? minLines,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: calendarSpacing12,
            vertical: calendarSpacing8,
          ),
          onChanged: onChanged,
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
      spacing: calendarSpacing8,
      runSpacing: calendarSpacing8,
      children: buttons,
    );
  }

  void _handleSelectionTitleChanged(String value) {
    if (_isUpdatingSelectionTitle) {
      _isUpdatingSelectionTitle = false;
      return;
    }
    setState(() {
      _selectionTitleDirty = value.trim().isNotEmpty;
    });
  }

  void _handleSelectionDescriptionChanged(String value) {
    if (_isUpdatingSelectionDescription) {
      _isUpdatingSelectionDescription = false;
      return;
    }
    setState(() {
      _selectionDescriptionDirty = true;
    });
  }

  void _handleSelectionLocationChanged(String value) {
    if (_isUpdatingSelectionLocation) {
      _isUpdatingSelectionLocation = false;
      return;
    }
    setState(() {
      _selectionLocationDirty = true;
    });
  }

  void _applySelectionBatchChanges() {
    final bloc = context.read<BaseCalendarBloc>();
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
    final bloc = context.read<BaseCalendarBloc>();
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
      _isUpdatingSelectionTitle = true;
      _selectionTitleController.clear();
      _selectionTitleDirty = false;
    });
    return true;
  }

  bool _applySelectionDescription() {
    final bloc = context.read<BaseCalendarBloc>();
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
      _isUpdatingSelectionDescription = true;
      _selectionDescriptionController.clear();
      _selectionDescriptionDirty = false;
    });
    return true;
  }

  bool _applySelectionLocation() {
    final bloc = context.read<BaseCalendarBloc>();
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
      _isUpdatingSelectionLocation = true;
      _selectionLocationController.clear();
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
    final bloc = context.read<BaseCalendarBloc>();
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
        padding: const EdgeInsets.all(calendarSpacing16),
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
    final bloc = context.read<BaseCalendarBloc>();
    final String scheduleLabel = _selectionScheduleLabel(task);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
    context.read<BaseCalendarBloc>().add(
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

  Widget _buildQuickTaskInput() {
    return TaskTextField(
      controller: _titleController,
      hintText: 'Quick task (e.g., "Meeting at 2pm in Room 101")',
      textCapitalization: TextCapitalization.sentences,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _addTask(),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPriorityToggles(CalendarSidebarState uiState) {
    return TaskPriorityToggles(
      isImportant: uiState.isImportant,
      isUrgent: uiState.isUrgent,
      onImportantChanged: _sidebarController.setImportant,
      onUrgentChanged: _sidebarController.setUrgent,
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

  Widget _buildAdvancedOptions(
    CalendarSidebarState uiState, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskDescriptionField(
            controller: _descriptionController,
            hintText: 'Description (optional)',
            minLines: 2,
            maxLines: 4,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarSpacing16,
              vertical: calendarSpacing12,
            ),
          ),
          const SizedBox(height: 10),
          TaskLocationField(
            controller: _locationController,
            hintText: 'Location (optional)',
            contentPadding: const EdgeInsets.symmetric(
              horizontal: calendarSpacing16,
              vertical: calendarSpacing12,
            ),
          ),
          const SizedBox(height: 12),
          const TaskSectionHeader(title: 'Deadline'),
          const SizedBox(height: 6),
          DeadlinePickerField(
            value: uiState.selectedDeadline,
            onChanged: _sidebarController.setSelectedDeadline,
          ),
          const TaskSectionDivider(),
          _buildAdvancedScheduleSection(uiState),
          const TaskSectionDivider(),
          _buildAdvancedRecurrenceSection(),
        ],
      ),
    );
  }

  Widget _buildAdvancedScheduleSection(CalendarSidebarState uiState) {
    return TaskScheduleSection(
      spacing: calendarSpacing6,
      start: uiState.advancedStartTime,
      end: uiState.advancedEndTime,
      onStartChanged: _sidebarController.setAdvancedStart,
      onEndChanged: _sidebarController.setAdvancedEnd,
      onClear: () => _sidebarController.setAdvancedStart(null),
    );
  }

  Widget _buildAdvancedRecurrenceSection() {
    final referenceStart = _sidebarController.state.advancedStartTime;
    final fallbackWeekday = referenceStart?.weekday ?? DateTime.now().weekday;

    return ValueListenableBuilder<RecurrenceFormValue>(
      valueListenable: _advancedRecurrenceNotifier,
      builder: (context, recurrence, _) {
        return TaskRecurrenceSection(
          spacing: calendarSpacing6,
          value: recurrence,
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
          onChanged: (next) {
            _advancedRecurrenceNotifier.value = next;
          },
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildTaskList(
              unscheduledTasks,
              emptyLabel: 'No unscheduled tasks',
              emptyHint: 'Tasks you add will appear here',
              uiState: uiState,
            ),
          ),
          collapsedChild: _buildCollapsedPreview(unscheduledTasks),
        ),
        const SizedBox(height: 4),
        _buildAccordionSection(
          title: 'REMINDERS',
          section: CalendarSidebarSection.reminders,
          uiState: uiState,
          itemCount: reminderTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final isExpanded = uiState.expandedSection == section;

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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      const SizedBox(width: 8),
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
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
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
                firstChild: Container(
                  key: ValueKey('${section.name}-collapsed'),
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  constraints: const BoxConstraints(minHeight: 40),
                  child: collapsedChild,
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
              padding: const EdgeInsets.only(bottom: 2),
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

  Widget _buildTaskList(
    List<CalendarTask> tasks, {
    required String emptyLabel,
    String? emptyHint,
    required CalendarSidebarState uiState,
  }) {
    return DragTarget<CalendarTask>(
      onAcceptWithDetails: (details) {
        final CalendarTask dropped = details.data;
        final CalendarTask unscheduled = dropped.copyWith(
          scheduledTime: null,
          duration: null,
          endDate: null,
          startHour: null,
          modifiedAt: DateTime.now(),
        );
        context.read<BaseCalendarBloc>().add(
              CalendarEvent.taskUpdated(
                task: unscheduled,
              ),
            );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
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
            const SizedBox(height: 12),
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
              const SizedBox(height: 4),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    return Draggable<CalendarTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: SizedBox(
            width: uiState.width - 32,
            child: _buildTaskTile(
              task,
              uiState: uiState,
              enableInteraction: false,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskTile(
          task,
          uiState: uiState,
          enableInteraction: false,
        ),
      ),
      child: _buildTaskTile(task, uiState: uiState),
    );
  }

  Widget _buildTaskTile(
    CalendarTask task, {
    required CalendarSidebarState uiState,
    bool enableInteraction = true,
  }) {
    final borderColor = task.priorityColor;
    final bool isActive = uiState.activePopoverTaskId == task.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
                          ScaffoldMessenger.maybeOf(this.context);

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
                                onTaskUpdated: (updatedTask) {
                                  context.read<BaseCalendarBloc>().add(
                                        CalendarEvent.taskUpdated(
                                          task: updatedTask,
                                        ),
                                      );
                                },
                                onOccurrenceUpdated: shouldUpdateOccurrence
                                    ? (updatedTask) {
                                        context.read<BaseCalendarBloc>().add(
                                              CalendarEvent
                                                  .taskOccurrenceUpdated(
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
                                          context.read<BaseCalendarBloc>().add(
                                                CalendarEvent.taskUpdated(
                                                  task: seriesUpdate,
                                                ),
                                              );
                                        }
                                      }
                                    : null,
                                onTaskDeleted: (taskId) {
                                  context.read<BaseCalendarBloc>().add(
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
                      const SizedBox(height: 2),
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
                const SizedBox(width: 4),
                trailing,
              ],
            ],
          ),
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
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
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  const SizedBox(width: 4),
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
            const SizedBox(height: 4),
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

  Widget _buildResizeHandle(CalendarSidebarState uiState) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: GestureDetector(
          onPanStart: (_) => _sidebarController.beginResize(),
          onPanUpdate: (details) =>
              _sidebarController.adjustWidth(details.delta.dx),
          onPanEnd: (_) => _sidebarController.endResize(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 8,
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
    final uiState = _sidebarController.state;
    if (uiState.isImportant && uiState.isUrgent) {
      return TaskPriority.critical;
    } else if (uiState.isImportant) {
      return TaskPriority.important;
    } else if (uiState.isUrgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  void _addTask() {
    final uiState = _sidebarController.state;
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final priority = _currentPriority();
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSchedule =
        uiState.advancedStartTime != null && uiState.advancedEndTime != null;
    final hasRecurrence = _advancedRecurrence.isActive;

    if (!hasLocation && !hasSchedule && !hasRecurrence) {
      context.read<BaseCalendarBloc>().add(
            CalendarEvent.quickTaskAdded(
              text: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              deadline: uiState.selectedDeadline,
              priority: priority,
            ),
          );
    } else {
      Duration? duration;
      DateTime? scheduledTime;
      if (hasSchedule) {
        final DateTime start = uiState.advancedStartTime!;
        DateTime end = uiState.advancedEndTime!;
        duration = end.difference(start);
        if (duration.inMinutes < 15) {
          end = start.add(const Duration(minutes: 15));
          duration = const Duration(minutes: 15);
        }
        scheduledTime = start;
      }

      RecurrenceRule? recurrence;
      if (hasRecurrence) {
        final reference = uiState.advancedStartTime ?? DateTime.now();
        recurrence = _advancedRecurrence.toRule(start: reference);
      }

      context.read<BaseCalendarBloc>().add(
            CalendarEvent.taskAdded(
              title: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              scheduledTime: scheduledTime,
              duration: duration,
              deadline: uiState.selectedDeadline,
              location: hasLocation ? _locationController.text.trim() : null,
              priority: priority,
              recurrence: recurrence,
            ),
          );
    }

    _resetForm();
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    _advancedRecurrenceNotifier.value = const RecurrenceFormValue();
    _sidebarController.resetForm();
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
