import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/time_formatter.dart';
import 'edit_task_dropdown.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/calendar_completion_checkbox.dart';
import 'priority_checkbox_tile.dart';
import 'widgets/schedule_range_fields.dart';

enum _SidebarSection { unscheduled, reminders }

class TaskSidebar extends StatefulWidget {
  const TaskSidebar({super.key});

  @override
  State<TaskSidebar> createState() => _TaskSidebarState();
}

class _SelectionCompletionTile extends StatelessWidget {
  const _SelectionCompletionTile({
    required this.enabled,
    required this.value,
    required this.isIndeterminate,
    required this.onChanged,
  });

  final bool enabled;
  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool> onChanged;

  bool get _isActive => value || isIndeterminate;

  void _handleTap() {
    if (!enabled) {
      return;
    }
    onChanged(!value);
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor =
        _isActive ? calendarPrimaryColor : calendarBorderColor;
    final Color backgroundColor =
        _isActive ? calendarPrimaryColor.withValues(alpha: 0.08) : Colors.white;
    final double borderWidth = isIndeterminate || value ? 2.0 : 1.0;
    final Color textColor = !enabled
        ? calendarSubtitleColor
        : _isActive
            ? calendarPrimaryColor
            : calendarTitleColor;

    return InkWell(
      onTap: enabled ? _handleTap : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: enabled ? borderColor : calendarBorderColor,
            width: borderWidth,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CalendarCompletionCheckbox(
              value: value,
              isIndeterminate: isIndeterminate,
              onChanged: enabled ? onChanged : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Mark as completed',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isActive ? FontWeight.w600 : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSidebarState extends State<TaskSidebar>
    with TickerProviderStateMixin {
  late double _width;
  bool _widthInitialized = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DateTime? _selectedDeadline;
  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isResizing = false;

  _SidebarSection? _expandedSection = _SidebarSection.unscheduled;
  bool _showAdvancedOptions = false;
  DateTime? _advancedStartTime;
  DateTime? _advancedEndTime;
  RecurrenceFrequency _advancedRecurrenceFrequency = RecurrenceFrequency.none;
  int _advancedRecurrenceInterval = 1;
  DateTime? _advancedRecurrenceUntil;
  int? _advancedRecurrenceCount;
  final TextEditingController _advancedRecurrenceCountController =
      TextEditingController();
  late Set<int> _advancedSelectedWeekdays;

  String _selectionRecurrenceSignature = '';
  RecurrenceFrequency _selectionRecurrenceFrequency = RecurrenceFrequency.none;
  int _selectionRecurrenceInterval = 1;
  DateTime? _selectionRecurrenceUntil;
  int? _selectionRecurrenceCount;
  final TextEditingController _selectionRecurrenceCountController =
      TextEditingController();
  Set<int> _selectionSelectedWeekdays = {DateTime.monday};
  bool _selectionRecurrenceMixed = false;

  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  String? _activePopoverTaskId;

  @override
  void initState() {
    super.initState();
    _advancedSelectedWeekdays = {DateTime.now().weekday};
    _selectionSelectedWeekdays = {DateTime.now().weekday};
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _advancedRecurrenceCountController.dispose();
    _selectionRecurrenceCountController.dispose();
    _scrollController.dispose();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final minWidth = (screenWidth * 0.25).clamp(220.0, screenWidth);
    final maxWidth = (screenWidth * 0.5).clamp(minWidth, screenWidth);
    final defaultWidth = (screenWidth * 0.33).clamp(minWidth, maxWidth);

    if (!_widthInitialized) {
      _width = defaultWidth.toDouble();
      _widthInitialized = true;
    }
    _width = _width.clamp(minWidth, maxWidth).toDouble();

    return Container(
      width: _width,
      decoration: const BoxDecoration(
        color: sidebarBackgroundColor,
        border: Border(
          right: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: BlocBuilder<BaseCalendarBloc, CalendarState>(
              builder: (context, state) {
                final content = state.isSelectionMode
                    ? _buildSelectionPanel(state)
                    : _buildUnscheduledContent(state);

                return Scrollbar(
                  controller: _scrollController,
                  radius: const Radius.circular(8),
                  thickness: 6,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    physics: const ClampingScrollPhysics(),
                    child: content,
                  ),
                );
              },
            ),
          ),
          _buildResizeHandle(
            minWidth: minWidth.toDouble(),
            maxWidth: maxWidth.toDouble(),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: calendarTimeLabelColor,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: calendarBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: calendarBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff0969DA), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildAddTaskSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
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
          const SizedBox(height: 16),
          _buildQuickTaskInput(),
          const SizedBox(height: 16),
          _buildPriorityToggles(),
          const SizedBox(height: 12),
          _buildAdvancedToggle(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
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
            child: _showAdvancedOptions
                ? _buildAdvancedOptions(key: const ValueKey('advanced'))
                : const SizedBox.shrink(key: ValueKey('advanced-hidden')),
          ),
          const SizedBox(height: 16),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildUnscheduledContent(CalendarState state) {
    final unscheduledTasks = _sortTasksByDeadline(
      state.unscheduledTasks.where((task) => task.deadline == null).toList(),
    );
    final reminderTasks = _sortTasksByDeadline(
      state.unscheduledTasks.where((task) => task.deadline != null).toList(),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAddTaskSection(),
        _buildTaskSections(
          unscheduledTasks,
          reminderTasks,
        ),
      ],
    );
  }

  Widget _buildSelectionPanel(CalendarState state) {
    final tasks = _selectedTasks(state);
    _syncSelectionRecurrenceState(tasks);
    final total = tasks.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: calendarBorderColor, width: 1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'SELECTION MODE',
                      style: calendarHeaderTextStyle.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: calendarTimeLabelColor,
                      ),
                    ),
                  ),
                  ShadButton.outline(
                    size: ShadButtonSize.sm,
                    onPressed: () => context
                        .read<BaseCalendarBloc>()
                        .add(const CalendarEvent.selectionCleared()),
                    child: const Text('Exit'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '$total task${total == 1 ? '' : 's'} selected',
                style: calendarSubtitleTextStyle,
              ),
              const SizedBox(height: 16),
              _buildSelectionActions(tasks),
              const SizedBox(height: 16),
              Text(
                'Set Priority',
                style: calendarHeaderTextStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              _buildPriorityControls(tasks),
              const SizedBox(height: 16),
              Text(
                'Repeat',
                style: calendarHeaderTextStyle.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 8),
              _buildSelectionRecurrenceSection(tasks),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSelectedTaskList(tasks),
        ),
      ],
    );
  }

  Widget _buildSelectionActions(List<CalendarTask> tasks) {
    final bloc = context.read<BaseCalendarBloc>();
    final hasTasks = tasks.isNotEmpty;
    final bool allCompleted =
        hasTasks && tasks.every((task) => task.isCompleted);
    final bool anyCompleted = tasks.any((task) => task.isCompleted);
    final bool isIndeterminate = hasTasks && anyCompleted && !allCompleted;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _SelectionCompletionTile(
            enabled: hasTasks,
            value: allCompleted,
            isIndeterminate: isIndeterminate,
            onChanged: (completed) => bloc.add(
              CalendarEvent.selectionCompletedToggled(completed: completed),
            ),
          ),
        ),
        _selectionActionButton(
          icon: Icons.clear_all,
          label: 'Clear Selection',
          onPressed: () => bloc.add(
            const CalendarEvent.selectionCleared(),
          ),
        ),
        _selectionActionButton(
          icon: Icons.delete_outline,
          label: 'Delete Selected',
          onPressed: hasTasks
              ? () => bloc.add(const CalendarEvent.selectionDeleted())
              : null,
          backgroundColor: calendarDangerColor,
          hoverBackgroundColor: calendarDangerColor.withValues(alpha: 0.85),
          foregroundColor: Colors.white,
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

    return Row(
      children: [
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Important',
            value: allImportant,
            isIndeterminate: anyImportant && !allImportant,
            color: calendarSuccessColor,
            onChanged: hasTasks
                ? (selected) => updatePriority(
                      important: selected,
                      urgent: allUrgent,
                    )
                : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Urgent',
            value: allUrgent,
            isIndeterminate: anyUrgent && !allUrgent,
            color: calendarWarningColor,
            onChanged: hasTasks
                ? (selected) => updatePriority(
                      important: allImportant,
                      urgent: selected,
                    )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSelectionRecurrenceSection(List<CalendarTask> tasks) {
    final bool hasTasks = tasks.isNotEmpty;
    final frequency = _selectionRecurrenceFrequency;
    final bool showWeekdaySelector = frequency == RecurrenceFrequency.weekly ||
        frequency == RecurrenceFrequency.weekdays;
    final bool showAdvanced = frequency != RecurrenceFrequency.none;

    final content = <Widget>[
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: RecurrenceFrequency.values
            .map(
              (frequency) => _buildSelectionRecurrenceFrequencyButton(
                frequency,
                hasTasks,
                tasks,
              ),
            )
            .toList(),
      ),
    ];

    if (_selectionRecurrenceMixed) {
      content.insert(
        0,
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: calendarWarningColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: calendarWarningColor.withValues(alpha: 0.4)),
          ),
          child: const Text(
            'Tasks have different recurrence settings. Updates will apply to all selected tasks.',
            style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
          ),
        ),
      );
    }

    if (showWeekdaySelector) {
      content.add(const SizedBox(height: 12));
      content.add(_buildSelectionWeekdaySelector(hasTasks));
    }

    if (showAdvanced) {
      content
        ..add(const SizedBox(height: 12))
        ..add(_buildSelectionRecurrenceInterval(hasTasks))
        ..add(const SizedBox(height: 14))
        ..add(_buildSelectionRecurrenceEndControls(hasTasks));
    }

    if (content.length == 1 && !hasTasks) {
      return const Text(
        'No tasks selected.',
        style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: content,
    );
  }

  Widget _buildSelectionRecurrenceFrequencyButton(
    RecurrenceFrequency frequency,
    bool hasTasks,
    List<CalendarTask> tasks,
  ) {
    final isSelected = _selectionRecurrenceFrequency == frequency;

    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: 0.08),
      foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
      hoverForegroundColor:
          isSelected ? Colors.white : calendarPrimaryHoverColor,
      onPressed: hasTasks
          ? () {
              setState(() {
                _selectionRecurrenceFrequency = frequency;
                _selectionRecurrenceInterval = 1;
                _selectionRecurrenceUntil = null;
                _selectionRecurrenceCount = null;
                _selectionRecurrenceCountController.clear();
                _selectionRecurrenceMixed = false;
                if (frequency == RecurrenceFrequency.weekdays) {
                  _selectionSelectedWeekdays = const {
                    DateTime.monday,
                    DateTime.tuesday,
                    DateTime.wednesday,
                    DateTime.thursday,
                    DateTime.friday,
                  };
                } else if (frequency == RecurrenceFrequency.weekly) {
                  if (_selectionSelectedWeekdays.isEmpty) {
                    _selectionSelectedWeekdays = {
                      _defaultSelectionWeekday(tasks),
                    };
                  }
                }
              });
              _dispatchSelectionRecurrence();
            }
          : null,
      child: Text(
        _recurrenceLabel(frequency),
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSelectionWeekdaySelector(bool hasTasks) {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const values = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    final chips = <Widget>[];
    for (var index = 0; index < values.length; index++) {
      final value = values[index];
      final isSelected = _selectionSelectedWeekdays.contains(value);
      chips.add(
        ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
          hoverBackgroundColor: isSelected
              ? calendarPrimaryHoverColor
              : calendarPrimaryColor.withValues(alpha: 0.08),
          foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
          hoverForegroundColor:
              isSelected ? Colors.white : calendarPrimaryHoverColor,
          onPressed: hasTasks ? () => _toggleSelectionWeekday(value) : null,
          child: Text(
            labels[index],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: chips,
    );
  }

  Widget _buildSelectionRecurrenceInterval(bool hasTasks) {
    final options = List.generate(12, (index) => index + 1)
        .map(
          (value) => ShadOption<int>(
            value: value,
            child: Text('$value'),
          ),
        )
        .toList();

    return Row(
      children: [
        const Text(
          'Repeat every',
          style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 118,
          child: ShadSelect<int>(
            enabled: hasTasks,
            initialValue: _selectionRecurrenceInterval,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _selectionRecurrenceInterval = value);
              _dispatchSelectionRecurrence();
            },
            options: options,
            selectedOptionBuilder: (context, value) => Text('$value'),
            decoration: ShadDecoration(
              color: Colors.white,
              border: ShadBorder.all(
                color: calendarBorderColor,
                width: 1,
                radius: BorderRadius.circular(10),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            trailing: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _recurrenceIntervalUnit(_selectionRecurrenceFrequency),
          style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
    );
  }

  Widget _buildSelectionRecurrenceEndControls(bool hasTasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'END DATE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        DeadlinePickerField(
          value: _selectionRecurrenceUntil,
          placeholder: 'End',
          showStatusColors: false,
          showTimeSelectors: false,
          onChanged: (value) {
            setState(() {
              _selectionRecurrenceUntil = value == null
                  ? null
                  : DateTime(value.year, value.month, value.day);
              if (_selectionRecurrenceUntil != null) {
                _selectionRecurrenceCount = null;
                _selectionRecurrenceCountController.clear();
              }
            });
            _dispatchSelectionRecurrence();
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'COUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _selectionRecurrenceCountController,
          enabled: hasTasks,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Repeat times',
            hintStyle: TextStyle(
              color: calendarSubtitleColor.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: calendarPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            final parsed = int.tryParse(value);
            setState(() {
              if (parsed == null || parsed <= 0) {
                _selectionRecurrenceCount = null;
              } else {
                _selectionRecurrenceCount = parsed;
                _selectionRecurrenceUntil = null;
              }
            });
            _dispatchSelectionRecurrence();
          },
        ),
      ],
    );
  }

  void _toggleSelectionWeekday(int weekday) {
    setState(() {
      if (_selectionSelectedWeekdays.contains(weekday)) {
        final updated = {..._selectionSelectedWeekdays}..remove(weekday);
        if (updated.isEmpty) {
          return;
        }
        _selectionSelectedWeekdays = updated;
      } else {
        _selectionSelectedWeekdays = {
          ..._selectionSelectedWeekdays,
          weekday,
        };
      }
    });
    _dispatchSelectionRecurrence();
  }

  void _dispatchSelectionRecurrence() {
    final bloc = context.read<BaseCalendarBloc>();
    if (bloc.state.selectedTaskIds.isEmpty) {
      return;
    }

    RecurrenceRule? recurrence;
    final normalizedFrequency = _selectionRecurrenceFrequency;

    if (normalizedFrequency == RecurrenceFrequency.none) {
      recurrence = null;
    } else if (normalizedFrequency == RecurrenceFrequency.weekdays) {
      recurrence = RecurrenceRule(
        frequency: RecurrenceFrequency.weekdays,
        interval: _selectionRecurrenceInterval,
        byWeekdays: const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ],
        until: _selectionRecurrenceUntil,
        count: _selectionRecurrenceCount,
      );
    } else {
      var weekdays = _selectionSelectedWeekdays;
      if (normalizedFrequency == RecurrenceFrequency.weekly) {
        if (weekdays.isEmpty) {
          weekdays = {DateTime.monday};
        }
      } else {
        weekdays = <int>{};
      }
      recurrence = RecurrenceRule(
        frequency: normalizedFrequency,
        interval: _selectionRecurrenceInterval,
        byWeekdays: weekdays.isEmpty ? null : (weekdays.toList()..sort()),
        until: _selectionRecurrenceUntil,
        count: _selectionRecurrenceCount,
      );
    }

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
      _selectionRecurrenceFrequency = RecurrenceFrequency.none;
      _selectionRecurrenceInterval = 1;
      _selectionRecurrenceUntil = null;
      _selectionRecurrenceCount = null;
      _selectionRecurrenceCountController.clear();
      _selectionSelectedWeekdays = {DateTime.monday};
      _selectionRecurrenceMixed = false;
      return;
    }

    final firstRule = tasks.first.recurrence ?? RecurrenceRule.none;
    final bool allSame = tasks.every((task) {
      final rule = task.recurrence ?? RecurrenceRule.none;
      return _recurrenceEquals(firstRule, rule);
    });

    _selectionRecurrenceMixed = !allSame;

    final effectiveRule = allSame ? firstRule : RecurrenceRule.none;
    _selectionRecurrenceFrequency = effectiveRule.frequency;
    _selectionRecurrenceInterval = effectiveRule.interval;
    _selectionRecurrenceUntil = effectiveRule.until;
    _selectionRecurrenceCount = effectiveRule.count;
    _selectionRecurrenceCountController.text =
        _selectionRecurrenceCount?.toString() ?? '';

    if (effectiveRule.frequency == RecurrenceFrequency.weekdays) {
      _selectionSelectedWeekdays = const {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      };
    } else if (effectiveRule.frequency == RecurrenceFrequency.weekly) {
      final weekdays = effectiveRule.byWeekdays;
      if (weekdays != null && weekdays.isNotEmpty) {
        _selectionSelectedWeekdays = weekdays.toSet();
      } else {
        _selectionSelectedWeekdays = {
          _defaultSelectionWeekday(tasks),
        };
      }
    } else {
      _selectionSelectedWeekdays = {
        _defaultSelectionWeekday(tasks),
      };
    }
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

  Widget _buildSelectedTaskList(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
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

    final children = <Widget>[];
    for (var index = 0; index < tasks.length; index += 1) {
      if (index > 0) {
        children.add(const SizedBox(height: 12));
      }
      children.add(_buildSelectedTaskTile(tasks[index]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildSelectedTaskTile(CalendarTask task) {
    final scheduled = task.scheduledTime;
    final scheduleText = scheduled == null
        ? 'Unscheduled'
        : TimeFormatter.formatFriendlyDateTime(scheduled);
    final priority = task.priority ?? TaskPriority.none;
    final Color indicatorColor = priority == TaskPriority.none
        ? calendarBorderColor
        : task.priorityColor;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: calendarBorderColor),
        boxShadow: calendarLightShadow,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: indicatorColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: calendarTitleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  scheduleText,
                  style: const TextStyle(
                    fontSize: 12,
                    color: calendarSubtitleColor,
                  ),
                ),
              ],
            ),
          ),
          if (priority != TaskPriority.none)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 2),
              child: Text(
                _priorityLabel(priority),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: calendarSubtitleColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<CalendarTask> _selectedTasks(CalendarState state) {
    final tasks = state.selectedTaskIds
        .map((id) => state.model.tasks[id])
        .whereType<CalendarTask>()
        .toList();
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

  String _priorityLabel(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.none:
        return 'None';
      case TaskPriority.important:
        return 'Important';
      case TaskPriority.urgent:
        return 'Urgent';
      case TaskPriority.critical:
        return 'Critical';
    }
  }

  Widget _selectionActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    ShadButtonVariant variant = ShadButtonVariant.outline,
    Color? backgroundColor,
    Color? hoverBackgroundColor,
    Color? foregroundColor,
  }) {
    final defaultForeground = variant == ShadButtonVariant.primary
        ? Colors.white
        : calendarTitleColor;
    final effectiveForeground = foregroundColor ??
        (onPressed != null ? defaultForeground : calendarSubtitleColor);
    final effectiveHoverForeground = foregroundColor ?? defaultForeground;
    final effectiveHoverBackground =
        hoverBackgroundColor ?? backgroundColor?.withValues(alpha: 0.9);

    return ShadButton.raw(
      variant: variant,
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      enabled: onPressed != null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: backgroundColor,
      hoverBackgroundColor: effectiveHoverBackground,
      foregroundColor: effectiveForeground,
      hoverForegroundColor: foregroundColor ?? effectiveHoverForeground,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: effectiveForeground,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: effectiveForeground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickTaskInput() {
    return TextField(
      controller: _titleController,
      decoration:
          _fieldDecoration('Quick task (e.g., "Meeting at 2pm in Room 101")'),
      style: const TextStyle(
        fontSize: 14,
        color: calendarTitleColor,
      ),
      onSubmitted: (_) => _addTask(),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPriorityToggles() {
    return Row(
      children: [
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Important',
            value: _isImportant,
            color: calendarSuccessColor,
            onChanged: (value) => setState(() => _isImportant = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Urgent',
            value: _isUrgent,
            color: calendarWarningColor,
            onChanged: (value) => setState(() => _isUrgent = value),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvancedToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        foregroundColor: calendarPrimaryColor,
        hoverForegroundColor: calendarPrimaryHoverColor,
        hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        onPressed: () => setState(() {
          _showAdvancedOptions = !_showAdvancedOptions;
        }),
        leading: Icon(
          _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: calendarPrimaryColor,
        ),
        child: Text(
          _showAdvancedOptions
              ? 'Hide advanced options'
              : 'Show advanced options',
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions({Key? key}) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLinedTextField(
            controller: _descriptionController,
            hint: 'Description (optional)',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          _buildLinedTextField(
            controller: _locationController,
            hint: 'Location (optional)',
          ),
          const SizedBox(height: 12),
          const Text(
            'Deadline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: calendarSubtitleColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          DeadlinePickerField(
            value: _selectedDeadline,
            onChanged: (value) => setState(() => _selectedDeadline = value),
          ),
          _advancedDivider(),
          const Text(
            'Schedule',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: calendarSubtitleColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          _buildAdvancedScheduleFields(),
          _advancedDivider(),
          _buildAdvancedRecurrenceSection(),
        ],
      ),
    );
  }

  Widget _buildLinedTextField({
    required TextEditingController controller,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: _fieldDecoration(hint),
      textInputAction:
          maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
    );
  }

  Widget _advancedDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: calendarBorderColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildAdvancedScheduleFields() {
    return ScheduleRangeFields(
      start: _advancedStartTime,
      end: _advancedEndTime,
      onStartChanged: (value) {
        setState(() {
          _advancedStartTime = value;
          if (value == null) {
            _advancedEndTime = null;
            return;
          }
          if (_advancedEndTime == null || _advancedEndTime!.isBefore(value)) {
            _advancedEndTime = value.add(const Duration(hours: 1));
          }
        });
      },
      onEndChanged: (value) {
        setState(() {
          _advancedEndTime = value;
          if (value == null) {
            return;
          }
          if (_advancedStartTime != null &&
              value.isBefore(_advancedStartTime!)) {
            _advancedEndTime =
                _advancedStartTime!.add(const Duration(minutes: 15));
          }
        });
      },
    );
  }

  Widget _buildAdvancedRecurrenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RecurrenceFrequency.values
              .map(_buildRecurrenceFrequencyButton)
              .toList(),
        ),
        if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekly ||
            _advancedRecurrenceFrequency == RecurrenceFrequency.weekdays) ...[
          const SizedBox(height: 12),
          _buildAdvancedWeekdaySelector(),
        ],
        if (_advancedRecurrenceFrequency != RecurrenceFrequency.none) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAdvancedRecurrenceInterval(),
          ),
          const SizedBox(height: 14),
          _buildAdvancedRecurrenceEndControls(),
        ],
      ],
    );
  }

  Widget _buildRecurrenceFrequencyButton(RecurrenceFrequency frequency) {
    final isSelected = _advancedRecurrenceFrequency == frequency;

    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: 0.08),
      foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
      hoverForegroundColor:
          isSelected ? Colors.white : calendarPrimaryHoverColor,
      onPressed: () {
        setState(() {
          _advancedRecurrenceFrequency = frequency;
          _advancedRecurrenceInterval = 1;
          if (frequency == RecurrenceFrequency.none) {
            _advancedRecurrenceUntil = null;
            _advancedRecurrenceCount = null;
            _advancedRecurrenceCountController.clear();
          }
          if (frequency == RecurrenceFrequency.weekdays) {
            _advancedSelectedWeekdays = {
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            };
          } else if (frequency == RecurrenceFrequency.weekly &&
              _advancedSelectedWeekdays.isEmpty) {
            final defaultDay =
                _advancedStartTime?.weekday ?? DateTime.now().weekday;
            _advancedSelectedWeekdays = {defaultDay};
          }
        });
      },
      child: Text(
        _recurrenceLabel(frequency),
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAdvancedRecurrenceInterval() {
    final options = List.generate(12, (index) => index + 1)
        .map(
          (value) => ShadOption<int>(
            value: value,
            child: Text('$value'),
          ),
        )
        .toList();

    return Row(
      children: [
        const Text(
          'Repeat every',
          style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 118,
          child: ShadSelect<int>(
            initialValue: _advancedRecurrenceInterval,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _advancedRecurrenceInterval = value);
            },
            options: options,
            selectedOptionBuilder: (context, value) => Text('$value'),
            decoration: ShadDecoration(
              color: Colors.white,
              border: ShadBorder.all(
                color: calendarBorderColor,
                width: 1,
                radius: BorderRadius.circular(10),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            trailing: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _recurrenceIntervalUnit(_advancedRecurrenceFrequency),
          style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
    );
  }

  Widget _buildAdvancedRecurrenceEndControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'END DATE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        DeadlinePickerField(
          value: _advancedRecurrenceUntil,
          placeholder: 'End',
          showStatusColors: false,
          showTimeSelectors: false,
          onChanged: (value) {
            setState(() {
              _advancedRecurrenceUntil = value == null
                  ? null
                  : DateTime(value.year, value.month, value.day);
              if (_advancedRecurrenceUntil != null) {
                _advancedRecurrenceCount = null;
                _advancedRecurrenceCountController.clear();
              }
            });
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'COUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _advancedRecurrenceCountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Repeat times',
            hintStyle: TextStyle(
              color: calendarSubtitleColor.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide:
                  const BorderSide(color: calendarPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            final parsed = int.tryParse(value);
            setState(() {
              if (parsed == null || parsed <= 0) {
                _advancedRecurrenceCount = null;
              } else {
                _advancedRecurrenceCount = parsed;
                _advancedRecurrenceUntil = null;
              }
            });
          },
        ),
      ],
    );
  }

  String _recurrenceLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return 'Never';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekdays:
        return 'Weekdays';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
    }
  }

  String _recurrenceIntervalUnit(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return 'month(s)';
      case RecurrenceFrequency.weekly:
      case RecurrenceFrequency.weekdays:
        return 'week(s)';
      case RecurrenceFrequency.daily:
        return 'day(s)';
      case RecurrenceFrequency.none:
        return 'time(s)';
    }
  }

  Widget _buildAdvancedWeekdaySelector() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const values = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(values.length, (index) {
        final value = values[index];
        final isSelected = _advancedSelectedWeekdays.contains(value);

        return ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
          hoverBackgroundColor: isSelected
              ? calendarPrimaryHoverColor
              : calendarPrimaryColor.withValues(alpha: 0.08),
          foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
          hoverForegroundColor:
              isSelected ? Colors.white : calendarPrimaryHoverColor,
          onPressed: () {
            setState(() {
              if (isSelected) {
                final updated = {..._advancedSelectedWeekdays}..remove(value);
                _advancedSelectedWeekdays = updated.isEmpty ? {value} : updated;
              } else {
                _advancedSelectedWeekdays = {
                  ..._advancedSelectedWeekdays,
                  value,
                };
              }
            });
          },
          child: Text(
            labels[index],
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAddButton() {
    final isDisabled = _titleController.text.trim().isEmpty;
    return SizedBox(
      width: double.infinity,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: isDisabled ? null : _addTask,
        backgroundColor: isDisabled
            ? calendarPrimaryColor.withValues(alpha: 0.5)
            : calendarPrimaryColor,
        hoverBackgroundColor: calendarPrimaryHoverColor,
        foregroundColor: Colors.white,
        child: const Text('Add Task'),
      ),
    );
  }

  Widget _buildTaskSections(
    List<CalendarTask> unscheduledTasks,
    List<CalendarTask> reminderTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccordionSection(
          title: 'UNSCHEDULED TASKS',
          section: _SidebarSection.unscheduled,
          itemCount: unscheduledTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildTaskList(
              unscheduledTasks,
              emptyLabel: 'No unscheduled tasks',
              emptyHint: 'Tasks you add will appear here',
            ),
          ),
          collapsedChild: _buildCollapsedPreview(unscheduledTasks),
        ),
        const SizedBox(height: 4),
        _buildAccordionSection(
          title: 'REMINDERS',
          section: _SidebarSection.reminders,
          itemCount: reminderTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildReminderList(reminderTasks),
          ),
          collapsedChild: _buildCollapsedPreview(reminderTasks),
        ),
      ],
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required _SidebarSection section,
    required int itemCount,
    required Widget expandedChild,
    required Widget collapsedChild,
  }) {
    final isExpanded = _expandedSection == section;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: sidebarBackgroundColor,
            border: Border(
              bottom: section == _SidebarSection.unscheduled
                  ? const BorderSide(color: calendarBorderColor, width: 1)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedSection = section == _SidebarSection.unscheduled
                        ? _SidebarSection.reminders
                        : _SidebarSection.unscheduled;
                  } else {
                    _expandedSection = section;
                  }
                }),
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

    final previewTitles = tasks.take(2).map((task) => task.title).toList();
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
  }) {
    return DragTarget<CalendarTask>(
      onAcceptWithDetails: (details) {
        context.read<BaseCalendarBloc>().add(
              CalendarEvent.taskUpdated(
                task: details.data.copyWith(scheduledTime: null),
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
                    return _buildDraggableTaskTile(task);
                  },
                ),
        );
      },
    );
  }

  Widget _buildReminderList(List<CalendarTask> tasks) {
    return _buildTaskList(
      tasks,
      emptyLabel: 'No reminders yet',
      emptyHint: 'Add a deadline to create a reminder',
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

  Widget _buildDraggableTaskTile(CalendarTask task) {
    return Draggable<CalendarTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: SizedBox(
            width: _width - 32,
            child: _buildTaskTile(
              task,
              enableInteraction: false,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskTile(
          task,
          enableInteraction: false,
        ),
      ),
      child: _buildTaskTile(task),
    );
  }

  Widget _buildTaskTile(
    CalendarTask task, {
    bool enableInteraction = true,
  }) {
    final borderColor = task.priorityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: borderColor, width: 3),
              top: const BorderSide(color: calendarBorderColor),
              right: const BorderSide(color: calendarBorderColor),
              bottom: const BorderSide(color: calendarBorderColor),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
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

                      const double margin = 16.0;
                      const double dropdownMaxHeight =
                          644.0; // Increased by 40% from 460
                      const double dropdownWidth = 360.0;
                      const double preferredVerticalGap = 8.0;
                      const double preferredHorizontalGap = 12.0;

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

                              return EditTaskDropdown(
                                task: latestTask,
                                maxHeight: effectiveMaxHeight,
                                onClose: () => _closeTaskPopover(task.id),
                                onTaskUpdated: (updatedTask) {
                                  context.read<BaseCalendarBloc>().add(
                                        CalendarEvent.taskUpdated(
                                          task: updatedTask,
                                        ),
                                      );
                                },
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
                          borderRadius: BorderRadius.circular(6),
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

  Widget _buildTaskTileBody(CalendarTask task) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(fontSize: 13, color: calendarTitleColor),
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

  Widget _buildResizeHandle(
      {required double minWidth, required double maxWidth}) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() {}),
        onExit: (_) => setState(() {}),
        child: GestureDetector(
          onPanStart: (details) => setState(() => _isResizing = true),
          onPanUpdate: (details) {
            setState(() {
              final newWidth = _width + details.delta.dx;
              _width = newWidth.clamp(minWidth, maxWidth);
            });
          },
          onPanEnd: (details) => setState(() => _isResizing = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 8,
            color: _isResizing
                ? calendarPrimaryColor.withValues(alpha: 0.2)
                : Colors.transparent,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isResizing ? 3 : 2,
                height: _isResizing ? 60 : 50,
                decoration: BoxDecoration(
                  color:
                      _isResizing ? calendarPrimaryColor : calendarBorderColor,
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

  TaskPriority _getPriority() {
    if (_isImportant && _isUrgent) {
      return TaskPriority.critical;
    } else if (_isImportant) {
      return TaskPriority.important;
    } else if (_isUrgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  void _addTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final priority = _getPriority();
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSchedule = _advancedStartTime != null && _advancedEndTime != null;
    final hasRecurrence =
        _advancedRecurrenceFrequency != RecurrenceFrequency.none;

    if (!hasLocation && !hasSchedule && !hasRecurrence) {
      context.read<BaseCalendarBloc>().add(
            CalendarEvent.quickTaskAdded(
              text: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              deadline: _selectedDeadline,
              priority: priority,
            ),
          );
    } else {
      Duration? duration;
      DateTime? scheduledTime;
      if (hasSchedule) {
        duration = _advancedEndTime!.difference(_advancedStartTime!);
        if (duration.inMinutes < 15) {
          duration = const Duration(minutes: 15);
          _advancedEndTime = _advancedStartTime!.add(duration);
        }
        scheduledTime = _advancedStartTime;
      }

      RecurrenceRule? recurrence;
      if (hasRecurrence) {
        List<int>? weekdays;
        if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekdays) {
          weekdays = const [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ];
        } else if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekly) {
          weekdays = _advancedSelectedWeekdays.toList()..sort();
        }

        recurrence = RecurrenceRule(
          frequency: _advancedRecurrenceFrequency,
          interval: _advancedRecurrenceInterval,
          byWeekdays: weekdays,
          until: _advancedRecurrenceCount != null
              ? null
              : _advancedRecurrenceUntil,
          count: _advancedRecurrenceCount,
        );
      }

      context.read<BaseCalendarBloc>().add(
            CalendarEvent.taskAdded(
              title: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              scheduledTime: scheduledTime,
              duration: duration,
              deadline: _selectedDeadline,
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
    setState(() {
      _selectedDeadline = null;
      _isImportant = false;
      _isUrgent = false;
      _showAdvancedOptions = false;
      _advancedStartTime = null;
      _advancedEndTime = null;
      _advancedRecurrenceFrequency = RecurrenceFrequency.none;
      _advancedRecurrenceInterval = 1;
      _advancedRecurrenceUntil = null;
      _advancedRecurrenceCount = null;
      _advancedRecurrenceCountController.clear();
      final fallbackDay = DateTime.now().weekday;
      _advancedSelectedWeekdays = {fallbackDay};
    });
  }

  ShadPopoverController _popoverControllerFor(String taskId) {
    if (_taskPopoverControllers.containsKey(taskId)) {
      return _taskPopoverControllers[taskId]!;
    }
    final controller = ShadPopoverController();
    controller.addListener(() {
      if (!mounted) return;
      if (!controller.isOpen && _activePopoverTaskId == taskId) {
        setState(() => _activePopoverTaskId = null);
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
    if (_activePopoverTaskId != null && _activePopoverTaskId != taskId) {
      final activeController = _taskPopoverControllers[_activePopoverTaskId!];
      activeController?.hide();
    }
    controller.show();
    if (_activePopoverTaskId != taskId) {
      setState(() => _activePopoverTaskId = taskId);
    }
  }

  void _closeTaskPopover([String? taskId]) {
    final id = taskId ?? _activePopoverTaskId;
    if (id == null) {
      return;
    }
    final controller = _taskPopoverControllers[id];
    controller?.hide();
    if (_activePopoverTaskId == id && mounted) {
      setState(() => _activePopoverTaskId = null);
    }
  }
}
