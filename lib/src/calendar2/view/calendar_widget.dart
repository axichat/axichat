import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_model.dart';
import '../models/calendar_task.dart';

class CalendarWidget extends StatelessWidget {
  const CalendarWidget({super.key});

  @override
  Widget build(BuildContext context) =>
      const CalendarScaffold(title: 'Calendar');
}

class _TaskDragData {
  const _TaskDragData({required this.taskId});

  final String taskId;
}

class CalendarScaffold extends StatefulWidget {
  const CalendarScaffold({super.key, required this.title});

  final String title;

  @override
  State<CalendarScaffold> createState() => _CalendarScaffoldState();
}

class _CalendarScaffoldState extends State<CalendarScaffold> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _titleFocusNode = FocusNode();
  DateTime? _deadline;
  bool _important = false;
  bool _urgent = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CalendarBloc, CalendarState>(
      builder: (context, state) {
        final bloc = context.read<CalendarBloc>();
        final sizing = MediaQuery.of(context);
        final isCompact = sizing.size.width < 900;

        final appBar = isCompact
            ? AppBar(
                elevation: 0,
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                title: Text(
                  widget.title,
                  style: _CalendarTypography.appBar,
                ),
                leading: IconButton(
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
              )
            : null;

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: _CalendarColors.canvas,
          appBar: appBar,
          drawer: isCompact
              ? Drawer(
                  child: SafeArea(
                    child: _Sidebar(
                      titleFocusNode: _titleFocusNode,
                      titleController: _titleController,
                      descriptionController: _descriptionController,
                      deadline: _deadline,
                      important: _important,
                      urgent: _urgent,
                      onDeadlineChanged: (value) =>
                          setState(() => _deadline = value),
                      onImportantChanged: (value) =>
                          setState(() => _important = value ?? false),
                      onUrgentChanged: (value) =>
                          setState(() => _urgent = value ?? false),
                      onSubmit: () => _handleQuickAdd(context),
                    ),
                  ),
                )
              : null,
          body: SafeArea(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isCompact)
                  SizedBox(
                    width: 296,
                    child: _Sidebar(
                      titleFocusNode: _titleFocusNode,
                      titleController: _titleController,
                      descriptionController: _descriptionController,
                      deadline: _deadline,
                      important: _important,
                      urgent: _urgent,
                      onDeadlineChanged: (value) =>
                          setState(() => _deadline = value),
                      onImportantChanged: (value) =>
                          setState(() => _important = value ?? false),
                      onUrgentChanged: (value) =>
                          setState(() => _urgent = value ?? false),
                      onSubmit: () => _handleQuickAdd(context),
                    ),
                  ),
                Expanded(
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (state.error != null)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                            child: _InlineMessage(
                              message: state.error!,
                              onClose: () => bloc.add(
                                const CalendarEvent.errorCleared(),
                              ),
                            ),
                          ),
                        _CalendarToolbar(
                          state: state,
                          onToday: () => bloc.add(
                            CalendarEvent.dateSelected(date: DateTime.now()),
                          ),
                          onPrevious: () => bloc.add(
                            CalendarEvent.dateSelected(
                              date: _previousDate(state),
                            ),
                          ),
                          onNext: () => bloc.add(
                            CalendarEvent.dateSelected(
                              date: _nextDate(state),
                            ),
                          ),
                          onViewChanged: (view) =>
                              bloc.add(CalendarEvent.viewChanged(view: view)),
                          onTitlePressed: () =>
                              _handleTitlePressed(context, bloc, state),
                        ),
                        const Divider(
                            height: 1, color: _CalendarColors.divider),
                        Expanded(
                          child: _CalendarSurface(
                            state: state,
                            onCreateTask: (start) =>
                                _showCreateTaskDialog(context, start),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: isCompact
              ? FloatingActionButton.extended(
                  backgroundColor: _CalendarColors.primary,
                  foregroundColor: Colors.white,
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Task'),
                )
              : null,
        );
      },
    );
  }

  Future<void> _showCreateTaskDialog(BuildContext context, DateTime start) {
    final bloc = context.read<CalendarBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: _TaskCreateDialog(initialStart: start),
      ),
    );
  }

  DateTime _previousDate(CalendarState state) {
    return switch (state.viewMode) {
      CalendarView.day => state.selectedDate.subtract(const Duration(days: 1)),
      CalendarView.week => state.selectedDate.subtract(const Duration(days: 7)),
      CalendarView.month =>
        DateTime(state.selectedDate.year, state.selectedDate.month - 1, 1),
    };
  }

  DateTime _nextDate(CalendarState state) {
    return switch (state.viewMode) {
      CalendarView.day => state.selectedDate.add(const Duration(days: 1)),
      CalendarView.week => state.selectedDate.add(const Duration(days: 7)),
      CalendarView.month =>
        DateTime(state.selectedDate.year, state.selectedDate.month + 1, 1),
    };
  }

  Future<void> _handleTitlePressed(
    BuildContext context,
    CalendarBloc bloc,
    CalendarState state,
  ) async {
    final initialDate = state.selectedDate;
    final firstDate = DateTime(initialDate.year - 5);
    final lastDate = DateTime(initialDate.year + 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (!mounted) {
      return;
    }
    if (picked != null) {
      bloc.add(CalendarEvent.dateSelected(date: picked));
    }
  }

  void _handleQuickAdd(BuildContext context) {
    final bloc = context.read<CalendarBloc>();
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      return;
    }

    bloc.add(
      CalendarEvent.quickTaskAdded(
        text: title,
        description: description.isEmpty ? null : description,
        deadline: _deadline,
        important: _important,
        urgent: _urgent,
      ),
    );

    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _deadline = null;
      _important = false;
      _urgent = false;
    });
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.titleFocusNode,
    required this.titleController,
    required this.descriptionController,
    required this.deadline,
    required this.important,
    required this.urgent,
    required this.onDeadlineChanged,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    required this.onSubmit,
  });

  final FocusNode titleFocusNode;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final DateTime? deadline;
  final bool important;
  final bool urgent;
  final ValueChanged<DateTime?> onDeadlineChanged;
  final ValueChanged<bool?> onImportantChanged;
  final ValueChanged<bool?> onUrgentChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final bloc = context.watch<CalendarBloc>();
    final state = bloc.state;
    final unscheduled = state.unscheduledTasks;
    final upcoming = _upcomingTasks(state);

    return Container(
      decoration: const BoxDecoration(
        color: _CalendarColors.panel,
        border: Border(right: BorderSide(color: _CalendarColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: _CalendarColors.divider),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Task',
                  style: _CalendarTypography.caption
                      .copyWith(color: _CalendarColors.textSecondary),
                ),
                const SizedBox(height: 12),
                _InputField(
                  focusNode: titleFocusNode,
                  controller: titleController,
                  hintText: 'e.g., Meeting at 2pm, Doctor at 3pm on Main St',
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: descriptionController,
                  hintText: 'Description (optional)',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _DatePickerField(
                  value: deadline,
                  label: 'Deadline (optional)',
                  onChanged: onDeadlineChanged,
                ),
                const SizedBox(height: 12),
                _ToggleGroup(
                  important: important,
                  urgent: urgent,
                  onImportantChanged: onImportantChanged,
                  onUrgentChanged: onUrgentChanged,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: onSubmit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _CalendarColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: _CalendarTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    child: const Text('Add Task'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (upcoming.isNotEmpty)
                      _SidebarSection(
                        title: 'Upcoming',
                        child: Column(
                          children: upcoming
                              .map((task) => _SidebarTaskTile(
                                    task: task,
                                    subtitle: _formatSchedule(task, l10n),
                                  ))
                              .toList(),
                        ),
                      ),
                    if (unscheduled.isNotEmpty)
                      _SidebarSection(
                        title: 'Unscheduled Tasks',
                        child: DragTarget<_TaskDragData>(
                          onWillAcceptWithDetails: (_) => true,
                          onAcceptWithDetails: (details) {
                            final task =
                                bloc.state.model.tasks[details.data.taskId];
                            if (task == null) {
                              return;
                            }
                            bloc.add(
                              CalendarEvent.taskUpdated(
                                task: task.updatedCopy(
                                  scheduledStart: null,
                                  duration: null,
                                  endDate: null,
                                  timestamp: DateTime.now(),
                                ),
                              ),
                            );
                          },
                          builder: (context, candidateData, rejectedData) {
                            final highlight = candidateData.isNotEmpty;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: highlight
                                      ? _CalendarColors.primary
                                      : Colors.transparent,
                                  width: highlight ? 1.2 : 0,
                                ),
                                color: highlight
                                    ? _CalendarColors.pointerHighlight
                                    : Colors.transparent,
                              ),
                              child: Column(
                                children: unscheduled
                                    .map(
                                      (task) => _SidebarTaskTile(
                                        task: task,
                                        subtitle: task.description,
                                      ),
                                    )
                                    .toList(),
                              ),
                            );
                          },
                        ),
                      ),
                    if (unscheduled.isEmpty && upcoming.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'Everything is organized. Add your next priority.',
                          style: _CalendarTypography.bodyMuted,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<CalendarTask> _upcomingTasks(CalendarState state) {
    final now = DateTime.now();
    final horizon = now.add(const Duration(days: 7));
    return state.scheduledTasks
        .where((task) {
          final start = task.effectiveStart;
          if (start == null) {
            return false;
          }
          return start.isAfter(now.subtract(const Duration(hours: 1))) &&
              start.isBefore(horizon);
        })
        .take(5)
        .toList(growable: false);
  }

  String? _formatSchedule(CalendarTask task, MaterialLocalizations l10n) {
    final start = task.effectiveStart;
    if (start == null) {
      return null;
    }
    final date = l10n.formatMediumDate(start);
    final time = l10n.formatTimeOfDay(
      TimeOfDay.fromDateTime(start),
      alwaysUse24HourFormat: false,
    );
    return '$date | $time';
  }
}

class _ToggleGroup extends StatelessWidget {
  const _ToggleGroup({
    required this.important,
    required this.urgent,
    required this.onImportantChanged,
    required this.onUrgentChanged,
  });

  final bool important;
  final bool urgent;
  final ValueChanged<bool?> onImportantChanged;
  final ValueChanged<bool?> onUrgentChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToggleRow(
          label: 'Important',
          value: important,
          activeColor: _CalendarColors.important,
          onChanged: onImportantChanged,
        ),
        const SizedBox(height: 12),
        _ToggleRow(
          label: 'Urgent',
          value: urgent,
          activeColor: _CalendarColors.urgent,
          onChanged: onUrgentChanged,
        ),
      ],
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: _CalendarTypography.body.copyWith(fontSize: 13),
            ),
          ),
          _SidebarToggle(
            value: value,
            activeColor: activeColor,
            onChanged: (v) => onChanged(v),
          ),
        ],
      ),
    );
  }
}

class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final bool value;
  final Color activeColor;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Semantics(
        button: true,
        checked: value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40,
          height: 22,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: value ? activeColor : _CalendarColors.switchTrack,
            borderRadius: BorderRadius.circular(22),
          ),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.selected,
    required this.onChanged,
  });

  final CalendarView selected;
  final ValueChanged<CalendarView> onChanged;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (final view in CalendarView.values) {
      if (children.isNotEmpty) {
        children.add(const SizedBox(width: 4));
      }
      children.add(
        _ViewSwitcherChip(
          label: view.name,
          isSelected: view == selected,
          onTap: () => onChanged(view),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: _CalendarColors.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _CalendarColors.inputBorder),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _ViewSwitcherChip extends StatelessWidget {
  const _ViewSwitcherChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _CalendarColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label.toUpperCase(),
          style: _CalendarTypography.body.copyWith(
            color: isSelected ? Colors.white : _CalendarColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CalendarSurface extends StatelessWidget {
  const _CalendarSurface({required this.state, required this.onCreateTask});

  final CalendarState state;
  final ValueChanged<DateTime> onCreateTask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _CalendarColors.gridBackground,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          border: Border(
            top: BorderSide(color: _CalendarColors.divider),
            right: BorderSide(color: _CalendarColors.divider),
            left: BorderSide(color: _CalendarColors.divider),
            bottom: BorderSide(color: _CalendarColors.divider),
          ),
        ),
        child: switch (state.viewMode) {
          CalendarView.day =>
            _DayTimeline(state: state, onCreateTask: onCreateTask),
          CalendarView.week =>
            _WeekTimeline(state: state, onCreateTask: onCreateTask),
          CalendarView.month => _MonthGrid(state: state),
        },
      ),
    );
  }
}

class _CalendarToolbar extends StatelessWidget {
  const _CalendarToolbar({
    required this.state,
    required this.onPrevious,
    required this.onToday,
    required this.onNext,
    required this.onViewChanged,
    required this.onTitlePressed,
  });

  final CalendarState state;
  final VoidCallback onPrevious;
  final VoidCallback onToday;
  final VoidCallback onNext;
  final ValueChanged<CalendarView> onViewChanged;
  final VoidCallback onTitlePressed;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final title = _dateRangeLabel(l10n, state);
    final isDay = state.viewMode == CalendarView.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      color: Colors.white,
      child: Row(
        children: [
          _ToolbarButton(
            label: '← Previous',
            onTap: onPrevious,
            variant: _ToolbarButtonVariant.secondary,
          ),
          const SizedBox(width: 12),
          _ToolbarButton(
            label: 'Today',
            onTap: onToday,
            variant: _ToolbarButtonVariant.primary,
          ),
          const SizedBox(width: 12),
          _ToolbarButton(
            label: 'Next →',
            onTap: onNext,
            variant: _ToolbarButtonVariant.secondary,
          ),
          if (isDay) ...[
            const SizedBox(width: 12),
            _ToolbarButton(
              label: 'Back to Week',
              onTap: () => onViewChanged(CalendarView.week),
              variant: _ToolbarButtonVariant.tertiary,
            ),
          ],
          const SizedBox(width: 24),
          Expanded(
            child: Center(
              child: TextButton(
                onPressed: onTitlePressed,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  foregroundColor: _CalendarColors.textPrimary,
                ),
                child: Text(
                  title,
                  style: _CalendarTypography.headline.copyWith(fontSize: 18),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),
          _ViewSwitcher(
            selected: state.viewMode,
            onChanged: onViewChanged,
          ),
        ],
      ),
    );
  }

  String _dateRangeLabel(MaterialLocalizations l10n, CalendarState state) {
    return switch (state.viewMode) {
      CalendarView.day => l10n.formatMediumDate(state.selectedDate),
      CalendarView.week =>
        '${l10n.formatMediumDate(state.weekStart)} - ${l10n.formatMediumDate(state.weekEnd)}',
      CalendarView.month => DateFormat.yMMMM().format(state.selectedDate),
    };
  }
}

enum _ToolbarButtonVariant { primary, secondary, tertiary }

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    required this.variant,
  });

  final String label;
  final VoidCallback onTap;
  final _ToolbarButtonVariant variant;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground, BorderSide border) =
        switch (variant) {
      _ToolbarButtonVariant.primary => (
          _CalendarColors.primary,
          Colors.white,
          const BorderSide(color: _CalendarColors.primary)
        ),
      _ToolbarButtonVariant.secondary => (
          Colors.white,
          _CalendarColors.textPrimary,
          const BorderSide(color: _CalendarColors.divider)
        ),
      _ToolbarButtonVariant.tertiary => (
          _CalendarColors.textSecondary,
          Colors.white,
          const BorderSide(color: Colors.transparent)
        ),
    };

    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        backgroundColor: background,
        foregroundColor: foreground,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: border,
        ),
        textStyle: _CalendarTypography.body.copyWith(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

class _DayTimeline extends StatelessWidget {
  const _DayTimeline({required this.state, required this.onCreateTask});

  final CalendarState state;
  final ValueChanged<DateTime> onCreateTask;

  @override
  Widget build(BuildContext context) {
    final tasks = state.tasksForSelectedDay;
    return _TimelineGrid(
      days: [state.selectedDate],
      tasks: tasks,
      highlightDate: state.selectedDate,
      onEmptySlotTapped: onCreateTask,
    );
  }
}

class _WeekTimeline extends StatelessWidget {
  const _WeekTimeline({required this.state, required this.onCreateTask});

  final CalendarState state;
  final ValueChanged<DateTime> onCreateTask;

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(
      7,
      (index) => state.weekStart.add(Duration(days: index)),
    );
    return _TimelineGrid(
      days: days,
      tasks: state.tasksForSelectedWeek,
      highlightDate: state.selectedDate,
      onEmptySlotTapped: onCreateTask,
    );
  }
}

class _TimelineGrid extends StatefulWidget {
  const _TimelineGrid({
    required this.days,
    required this.tasks,
    required this.highlightDate,
    required this.onEmptySlotTapped,
  });

  final List<DateTime> days;
  final List<CalendarTask> tasks;
  final DateTime highlightDate;
  final ValueChanged<DateTime> onEmptySlotTapped;

  @override
  State<_TimelineGrid> createState() => _TimelineGridState();
}

class _TimelineGridState extends State<_TimelineGrid> {
  static const int _startHour = 4;
  static const int _endHour = 22;
  static const double _headerHeight = 48;
  static const double _gridTopPadding = 8;
  static const double _timeColumnWidth = 90;

  final Map<int, double?> _dragHoverMinutesPerDay = {};
  final Map<int, double?> _pointerHoverMinutesPerDay = {};

  @override
  Widget build(BuildContext context) {
    final columnFraction = 1 / widget.days.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;
        const totalHours = _endHour - _startHour;
        final stepMinutes = widget.days.length == 1 ? 15 : 60;
        final gridHeight =
            math.max(0.0, totalHeight - _headerHeight - _gridTopPadding);
        final hourHeight = totalHours == 0 ? 0.0 : gridHeight / totalHours;
        final now = DateTime.now();

        return Container(
          decoration: BoxDecoration(
            color: _CalendarColors.gridBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _CalendarColors.divider),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Column(
                  children: List.generate(
                    totalHours + 1,
                    (index) {
                      final hour = _startHour + index;
                      final isMajor = hour % 2 == 0;
                      return Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                color: isMajor
                                    ? _CalendarColors.divider
                                    : _CalendarColors.gridLine,
                                width: isMajor ? 1.2 : 0.6,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  children: List.generate(widget.days.length, (index) {
                    final date = widget.days[index];
                    final isToday = _sameDay(date, now);
                    final isHighlighted = _sameDay(date, widget.highlightDate);
                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: _headerHeight,
                            decoration: BoxDecoration(
                              color: isHighlighted
                                  ? _CalendarColors.pointerHighlight
                                  : Colors.white,
                              border: Border(
                                top: const BorderSide(
                                  color: _CalendarColors.divider,
                                ),
                                right: const BorderSide(
                                  color: _CalendarColors.divider,
                                ),
                                bottom: const BorderSide(
                                  color: _CalendarColors.divider,
                                ),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  DateFormat.EEEE().format(date).toUpperCase(),
                                  style: _CalendarTypography.smallCaps,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '${date.day}',
                                  style: _CalendarTypography.dayNumber.copyWith(
                                    color: isToday
                                        ? _CalendarColors.primary
                                        : _CalendarColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Container(
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: _CalendarColors.divider,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
                Positioned.fill(
                  top: _headerHeight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      top: _gridTopPadding,
                      right: 8,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: _timeColumnWidth,
                          padding: const EdgeInsets.only(right: 12),
                          decoration: const BoxDecoration(
                            color: _CalendarColors.panel,
                            border: Border(
                              right: BorderSide(
                                color: _CalendarColors.divider,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: List.generate(
                              totalHours,
                              (index) {
                                final hour = _startHour + index;
                                final time =
                                    TimeOfDay(hour: hour % 24, minute: 0);
                                final label = MaterialLocalizations.of(context)
                                    .formatTimeOfDay(
                                  time,
                                  alwaysUse24HourFormat: false,
                                );
                                return SizedBox(
                                  height: hourHeight,
                                  child: Align(
                                    alignment: Alignment.topRight,
                                    child: Text(
                                      label,
                                      style: _CalendarTypography.timeLabel,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, taskConstraints) {
                              final dayWidth =
                                  taskConstraints.maxWidth * columnFraction;
                              final totalWidth = taskConstraints.maxWidth;

                              final dayTargets =
                                  List.generate(widget.days.length, (index) {
                                final dayLeft = dayWidth * index;
                                return Positioned(
                                  left: dayLeft,
                                  top: 0,
                                  width: dayWidth,
                                  height: gridHeight,
                                  child: DragTarget<_TaskDragData>(
                                    onWillAcceptWithDetails: (_) => true,
                                    onAcceptWithDetails: (details) =>
                                        _handleTaskDrop(
                                      context: context,
                                      index: index,
                                      details: details,
                                      gridHeight: gridHeight,
                                      hourHeight: hourHeight,
                                      totalHours: totalHours,
                                      stepMinutes: stepMinutes,
                                    ),
                                    onMove: (details) => _handleHover(
                                      context: context,
                                      index: index,
                                      details: details,
                                      gridHeight: gridHeight,
                                      hourHeight: hourHeight,
                                      totalHours: totalHours,
                                      stepMinutes: stepMinutes,
                                    ),
                                    builder:
                                        (targetContext, candidate, rejected) {
                                      final hasDragCandidate =
                                          candidate.isNotEmpty;
                                      final dragMinutes =
                                          _dragHoverMinutesPerDay[index];
                                      final pointerMinutes =
                                          _pointerHoverMinutesPerDay[index];
                                      final hoverMinutes =
                                          dragMinutes ?? pointerMinutes;
                                      final isDragHover = hasDragCandidate ||
                                          dragMinutes != null;
                                      final isPointerHover = !isDragHover &&
                                          pointerMinutes != null;
                                      return Stack(
                                        children: [
                                          AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 120),
                                            decoration: BoxDecoration(
                                              color: isDragHover
                                                  ? _CalendarColors
                                                      .dragHighlight
                                                  : isPointerHover
                                                      ? _CalendarColors
                                                          .pointerHighlight
                                                      : Colors.transparent,
                                            ),
                                          ),
                                          if (hoverMinutes != null)
                                            Positioned(
                                              top: () {
                                                final highlightExtent =
                                                    math.max(
                                                  hourHeight *
                                                      (stepMinutes / 60),
                                                  20,
                                                );
                                                final rawTop =
                                                    (hoverMinutes / 60) *
                                                        hourHeight;
                                                final maxTop = math.max(
                                                  0.0,
                                                  gridHeight - highlightExtent,
                                                );
                                                return rawTop
                                                    .clamp(0, maxTop)
                                                    .toDouble();
                                              }(),
                                              left: 6,
                                              right: 6,
                                              height: math.min(
                                                gridHeight,
                                                math.max(
                                                  hourHeight *
                                                      (stepMinutes / 60),
                                                  20,
                                                ),
                                              ),
                                              child: DecoratedBox(
                                                decoration: BoxDecoration(
                                                  color: isDragHover
                                                      ? _CalendarColors
                                                          .dragHighlight
                                                      : _CalendarColors
                                                          .pointerHighlight,
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                  border: isDragHover
                                                      ? Border.all(
                                                          color: _CalendarColors
                                                              .primary,
                                                          width: 1.5,
                                                        )
                                                      : null,
                                                ),
                                              ),
                                            ),
                                        ],
                                      );
                                    },
                                    onLeave: (_) => setState(() =>
                                        _dragHoverMinutesPerDay[index] = null),
                                  ),
                                );
                              });

                              return Stack(
                                children: [
                                  ...dayTargets,
                                  Positioned.fill(
                                    child: MouseRegion(
                                      onEnter: (event) => _handlePointerHover(
                                        position: event.localPosition,
                                        dayWidth: dayWidth,
                                        totalWidth: totalWidth,
                                        gridHeight: gridHeight,
                                        hourHeight: hourHeight,
                                        totalHours: totalHours,
                                        stepMinutes: stepMinutes,
                                      ),
                                      onHover: (event) => _handlePointerHover(
                                        position: event.localPosition,
                                        dayWidth: dayWidth,
                                        totalWidth: totalWidth,
                                        gridHeight: gridHeight,
                                        hourHeight: hourHeight,
                                        totalHours: totalHours,
                                        stepMinutes: stepMinutes,
                                      ),
                                      onExit: (_) => _clearPointerHover(),
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTapUp: (details) =>
                                            _handleTimelineTap(
                                          details: details,
                                          dayWidth: dayWidth,
                                          hourHeight: hourHeight,
                                          gridHeight: gridHeight,
                                        ),
                                      ),
                                    ),
                                  ),
                                  for (final task in widget.tasks)
                                    if (task.scheduledStart != null)
                                      _TaskCard(
                                        task: task,
                                        hoursRange: const (
                                          _startHour,
                                          _endHour,
                                        ),
                                        hourHeight: hourHeight,
                                        dayWidth: dayWidth,
                                        dayStart: widget.days.first,
                                        totalDays: widget.days.length,
                                      ),
                                  if (_sameDay(now, widget.highlightDate))
                                    _CurrentTimeIndicator(
                                      time: now,
                                      hoursRange: const (
                                        _startHour,
                                        _endHour,
                                      ),
                                      hourHeight: hourHeight,
                                      days: widget.days,
                                      width: totalWidth,
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleHover({
    required BuildContext context,
    required int index,
    required DragTargetDetails<_TaskDragData> details,
    required double gridHeight,
    required double hourHeight,
    required int totalHours,
    required int stepMinutes,
  }) {
    if (hourHeight <= 0) {
      return;
    }
    final local = _toLocalOffset(context, details.offset);
    if (local == null) {
      return;
    }
    final clampedY = local.dy.clamp(0, gridHeight);
    final minutesFromStart = (clampedY / hourHeight) * 60;
    final snapped = (minutesFromStart / stepMinutes).round() * stepMinutes;
    setState(() {
      _dragHoverMinutesPerDay[index] =
          snapped.clamp(0, totalHours * 60).toDouble();
    });
  }

  void _handlePointerHover({
    required Offset position,
    required double dayWidth,
    required double totalWidth,
    required double gridHeight,
    required double hourHeight,
    required int totalHours,
    required int stepMinutes,
  }) {
    if (hourHeight <= 0 || dayWidth <= 0) {
      return;
    }
    if (position.dx < 0 ||
        position.dx > totalWidth ||
        position.dy < 0 ||
        position.dy > gridHeight) {
      _clearPointerHover();
      return;
    }

    final column = (position.dx ~/ dayWidth).clamp(0, widget.days.length - 1);
    final clampedY = position.dy.clamp(0, gridHeight);
    final minutesFromStart = (clampedY / hourHeight) * 60;
    final snapped = (minutesFromStart / stepMinutes).round() * stepMinutes;
    final value = snapped.clamp(0, totalHours * 60).toDouble();

    var shouldSetState = false;
    for (var i = 0; i < widget.days.length; i++) {
      final newValue = i == column ? value : null;
      if (_pointerHoverMinutesPerDay[i] != newValue) {
        shouldSetState = true;
        break;
      }
    }

    if (!shouldSetState) {
      return;
    }

    setState(() {
      for (var i = 0; i < widget.days.length; i++) {
        _pointerHoverMinutesPerDay[i] = i == column ? value : null;
      }
    });
  }

  void _clearPointerHover() {
    var hasHover = false;
    for (var i = 0; i < widget.days.length; i++) {
      if (_pointerHoverMinutesPerDay[i] != null) {
        hasHover = true;
        break;
      }
    }
    if (!hasHover) {
      return;
    }
    setState(() {
      for (var i = 0; i < widget.days.length; i++) {
        _pointerHoverMinutesPerDay[i] = null;
      }
    });
  }

  void _handleTaskDrop({
    required BuildContext context,
    required int index,
    required DragTargetDetails<_TaskDragData> details,
    required double gridHeight,
    required double hourHeight,
    required int totalHours,
    required int stepMinutes,
  }) {
    if (hourHeight <= 0) {
      return;
    }
    final bloc = context.read<CalendarBloc>();
    final local = _toLocalOffset(context, details.offset);
    if (local == null) {
      return;
    }
    final clampedY = local.dy.clamp(0, gridHeight);
    final minutesFromStart = (clampedY / hourHeight) * 60;
    final snapped = (minutesFromStart / stepMinutes).round() * stepMinutes;
    final clampedMinutes = snapped.clamp(0, totalHours * 60).toInt();
    final day = widget.days[index];
    final startMinutes = _startHour * 60 + clampedMinutes;
    final newStart = DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: startMinutes));

    bloc.add(
      CalendarEvent.taskDropped(
        taskId: details.data.taskId,
        time: newStart,
      ),
    );
    setState(() => _dragHoverMinutesPerDay[index] = null);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Offset? _toLocalOffset(BuildContext context, Offset globalOffset) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) {
      return null;
    }
    return box.globalToLocal(globalOffset);
  }

  void _handleTimelineTap({
    required TapUpDetails details,
    required double dayWidth,
    required double hourHeight,
    required double gridHeight,
  }) {
    if (hourHeight <= 0) {
      return;
    }
    final position = details.localPosition;
    if (position.dy < 0 || position.dy > gridHeight + _gridTopPadding) {
      return;
    }

    final column = position.dx ~/ dayWidth;
    if (column < 0 || column >= widget.days.length) {
      return;
    }

    final clampedY = position.dy.clamp(0, gridHeight);
    final minutesFromStart = (clampedY / hourHeight) * 60;
    final snapped = (minutesFromStart / 15).round() * 15;
    final clampedMinutes = snapped.clamp(0, (_endHour - _startHour) * 60);
    final startMinutes = (_startHour * 60 + clampedMinutes).round();
    final day = widget.days[column];
    final start = DateTime(day.year, day.month, day.day)
        .add(Duration(minutes: startMinutes));

    widget.onEmptySlotTapped(start);
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.hoursRange,
    required this.hourHeight,
    required this.dayWidth,
    required this.dayStart,
    required this.totalDays,
  });

  final CalendarTask task;
  final (int, int) hoursRange;
  final double hourHeight;
  final double dayWidth;
  final DateTime dayStart;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    final start = task.scheduledStart!;
    final effectiveEnd =
        task.effectiveEnd ?? start.add(const Duration(hours: 1));
    final startHour = start.hour + start.minute / 60;
    final endHour = effectiveEnd.hour + effectiveEnd.minute / 60;
    final (rangeStart, rangeEnd) = hoursRange;
    final clampedStart = math.max(rangeStart.toDouble(), startHour);
    final clampedEnd = math.min(rangeEnd.toDouble(), endHour);
    final top = (clampedStart - rangeStart) * hourHeight;
    final height =
        math.max((clampedEnd - clampedStart) * hourHeight, 56).toDouble();
    final dayIndex = start.difference(dayStart).inDays.clamp(0, totalDays - 1);
    final spanDays = math.min(task.spanDaysCount, totalDays - dayIndex);
    final left = dayWidth * dayIndex + 4;
    final width = dayWidth * spanDays - 12;
    final eventColor = task.priorityColor;
    final useSolidFill = task.important || task.urgent;
    final backgroundColor =
        useSolidFill ? eventColor : eventColor.withValues(alpha: 0.12);
    final textColor = useSolidFill ? Colors.white : _CalendarColors.textPrimary;

    final content = _TaskCardContent(
      task: task,
      start: start,
      end: effectiveEnd,
      backgroundColor: backgroundColor,
      textColor: textColor,
      eventColor: eventColor,
      useSolidFill: useSolidFill,
      showCompleted: true,
    );

    return Positioned(
      top: top,
      left: left,
      width: width,
      height: height,
      child: Draggable<_TaskDragData>(
        data: _TaskDragData(taskId: task.id),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: width,
            height: height,
            child: _TaskCardContent(
              task: task,
              start: start,
              end: effectiveEnd,
              backgroundColor: backgroundColor,
              textColor: textColor,
              eventColor: eventColor,
              useSolidFill: useSolidFill,
              showCompleted: false,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: content,
        ),
        child: GestureDetector(
          onTap: () => _showTaskDialog(context, task),
          child: content,
        ),
      ),
    );
  }

  Future<void> _showTaskDialog(BuildContext context, CalendarTask task) {
    final bloc = context.read<CalendarBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: _TaskEditDialog(task: task),
      ),
    );
  }
}

class _TaskCardContent extends StatelessWidget {
  const _TaskCardContent({
    required this.task,
    required this.start,
    required this.end,
    required this.backgroundColor,
    required this.textColor,
    required this.eventColor,
    required this.useSolidFill,
    required this.showCompleted,
  });

  final CalendarTask task;
  final DateTime start;
  final DateTime end;
  final Color backgroundColor;
  final Color textColor;
  final Color eventColor;
  final bool useSolidFill;
  final bool showCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: useSolidFill ? null : Border.all(color: eventColor, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _CalendarTypography.taskTitle.copyWith(
                          color: textColor,
                        ),
                      ),
                    ),
                    if (showCompleted && task.completed)
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: _CalendarColors.completed,
                      ),
                  ],
                ),
                SizedBox(height: constraints.maxHeight > 48 ? 6 : 2),
                Text(
                  '${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(start))} -> ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(end))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _CalendarTypography.bodyMuted.copyWith(
                    color: textColor.withValues(alpha: 0.85),
                  ),
                ),
                if (task.location != null)
                  Padding(
                    padding: EdgeInsets.only(
                        top: constraints.maxHeight > 56 ? 4 : 2),
                    child: Text(
                      task.location!,
                      maxLines: constraints.maxHeight > 68 ? 2 : 1,
                      overflow: TextOverflow.ellipsis,
                      style: _CalendarTypography.caption.copyWith(
                        color: textColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({
    required this.time,
    required this.hoursRange,
    required this.hourHeight,
    required this.days,
    required this.width,
  });

  final DateTime time;
  final (int, int) hoursRange;
  final double hourHeight;
  final List<DateTime> days;
  final double width;

  @override
  Widget build(BuildContext context) {
    final (startHour, endHour) = hoursRange;
    if (time.hour < startHour || time.hour > endHour) {
      return const SizedBox.shrink();
    }
    final minutesFromStart =
        ((time.hour + time.minute / 60) - startHour) * hourHeight;
    final dayIndex =
        time.difference(days.first).inDays.clamp(0, days.length - 1);
    final columnWidth = width / days.length;
    final left = columnWidth * dayIndex;

    return Positioned(
      top: minutesFromStart,
      left: left,
      right: width - left - columnWidth,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: _CalendarColors.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 2,
              color: _CalendarColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskCreateDialog extends StatefulWidget {
  const _TaskCreateDialog({required this.initialStart});

  final DateTime initialStart;

  @override
  State<_TaskCreateDialog> createState() => _TaskCreateDialogState();
}

class _TaskCreateDialogState extends State<_TaskCreateDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  DateTime? _start;
  DateTime? _end;
  DateTime? _deadline;
  bool _important = false;
  bool _urgent = false;
  bool _allDay = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _start = widget.initialStart;
    _end = widget.initialStart.add(const Duration(hours: 1));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child:
                        Text('New Task', style: _CalendarTypography.headline),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Title',
                child: _InputField(
                  controller: _titleController,
                  hintText: 'Task title',
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Description',
                child: _InputField(
                  controller: _descriptionController,
                  hintText: 'Notes or agenda',
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Schedule',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            label: 'Start',
                            value: _start,
                            allDay: _allDay,
                            onPick: (value) => setState(() => _start = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            label: 'End',
                            value: _end,
                            allDay: _allDay,
                            onPick: (value) => setState(() => _end = value),
                            firstDate: _start,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _allDay,
                          onChanged: (value) => setState(() {
                            _allDay = value;
                            if (_allDay) {
                              _start = _stripToMidnight(_start);
                              _end = _stripToMidnight(_end);
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        const Text('All day'),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _start = null;
                            _end = null;
                            _allDay = false;
                          }),
                          child: const Text('Clear schedule'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Location',
                child: _InputField(
                  controller: _locationController,
                  hintText: 'Add a location',
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Deadline',
                child: _DateTile(
                  label: 'Due',
                  value: _deadline,
                  allDay: true,
                  allowTime: false,
                  onPick: (value) => setState(() => _deadline = value),
                  onClear: () => setState(() => _deadline = null),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TogglePill(
                    label: 'Important',
                    value: _important,
                    activeColor: _CalendarColors.important,
                    onChanged: (value) =>
                        setState(() => _important = value ?? _important),
                  ),
                  const SizedBox(width: 12),
                  _TogglePill(
                    label: 'Urgent',
                    value: _urgent,
                    activeColor: _CalendarColors.urgent,
                    onChanged: (value) =>
                        setState(() => _urgent = value ?? _urgent),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: _CalendarColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleSave() {
    final bloc = context.read<CalendarBloc>();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    DateTime? start = _start;
    DateTime? end = _end;

    if (start != null && end != null && end.isBefore(start)) {
      end = start.add(const Duration(hours: 1));
    }

    Duration? duration;
    DateTime? endDate;
    if (start != null && end != null) {
      if (_allDay || !_isSameDay(start, end)) {
        duration = null;
        endDate = end;
      } else {
        duration = end.difference(start);
        if (duration.inMinutes <= 0) {
          duration = const Duration(hours: 1);
          end = start.add(duration);
        }
      }
    }

    bloc.add(
      CalendarEvent.taskAdded(
        title: title,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        scheduledStart: start,
        duration: duration,
        endDate: endDate,
        deadline: _deadline,
        isAllDay: _allDay,
        important: _important,
        urgent: _urgent,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
      ),
    );

    Navigator.of(context).pop();
  }

  DateTime? _stripToMidnight(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _TaskEditDialog extends StatefulWidget {
  const _TaskEditDialog({required this.task});

  final CalendarTask task;

  @override
  State<_TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends State<_TaskEditDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  DateTime? _start;
  DateTime? _end;
  DateTime? _deadline;
  bool _important = false;
  bool _urgent = false;
  bool _completed = false;
  bool _allDay = false;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _descriptionController =
        TextEditingController(text: task.description ?? '');
    _locationController = TextEditingController(text: task.location ?? '');
    _start = task.scheduledStart;
    _end = task.effectiveEnd;
    _deadline = task.deadline;
    _important = task.important;
    _urgent = task.urgent;
    _completed = task.completed;
    _allDay = task.isAllDay;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Edit Task',
                      style: _CalendarTypography.headline,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Title',
                child: _InputField(
                  controller: _titleController,
                  hintText: 'Task title',
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Description',
                child: _InputField(
                  controller: _descriptionController,
                  hintText: 'Notes or agenda',
                  maxLines: 3,
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Schedule',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _DateTile(
                            label: 'Start',
                            value: _start,
                            allDay: _allDay,
                            onPick: (value) => setState(() => _start = value),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateTile(
                            label: 'End',
                            value: _end,
                            allDay: _allDay,
                            onPick: (value) => setState(() => _end = value),
                            firstDate: _start,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Switch(
                          value: _allDay,
                          onChanged: (value) => setState(() {
                            _allDay = value;
                            if (_allDay) {
                              _start = _stripToMidnight(_start);
                              _end = _stripToMidnight(_end);
                            }
                          }),
                        ),
                        const SizedBox(width: 8),
                        const Text('All day'),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setState(() {
                            _start = null;
                            _end = null;
                            _allDay = false;
                          }),
                          child: const Text('Clear schedule'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _LabeledField(
                label: 'Location',
                child: _InputField(
                  controller: _locationController,
                  hintText: 'Add a location',
                ),
              ),
              const SizedBox(height: 16),
              _LabeledField(
                label: 'Deadline',
                child: _DateTile(
                  label: 'Due',
                  value: _deadline,
                  allDay: true,
                  allowTime: false,
                  onPick: (value) => setState(() => _deadline = value),
                  onClear: () => setState(() => _deadline = null),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _TogglePill(
                    label: 'Important',
                    value: _important,
                    activeColor: _CalendarColors.important,
                    onChanged: (value) => setState(() {
                      _important = value ?? _important;
                    }),
                  ),
                  const SizedBox(width: 12),
                  _TogglePill(
                    label: 'Urgent',
                    value: _urgent,
                    activeColor: _CalendarColors.urgent,
                    onChanged: (value) => setState(() {
                      _urgent = value ?? _urgent;
                    }),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Switch(
                        value: _completed,
                        onChanged: (value) => setState(() {
                          _completed = value;
                        }),
                      ),
                      const SizedBox(width: 4),
                      const Text('Completed'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Row(
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFDC2626),
                      side: const BorderSide(color: Color(0xFFDC2626)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    onPressed: _handleDelete,
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: const Text('Delete'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _handleSave,
                    style: FilledButton.styleFrom(
                      backgroundColor: _CalendarColors.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 26,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<DateTime?> _pickDate({
    required BuildContext context,
    required DateTime initialDate,
    DateTime? firstDate,
  }) {
    return showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate ?? DateTime(2020),
      lastDate: DateTime(2100),
    );
  }

  Future<TimeOfDay?> _pickTime({
    required BuildContext context,
    required TimeOfDay initialTime,
  }) =>
      showTimePicker(
        context: context,
        initialTime: initialTime,
      );

  Future<DateTime?> _pickDateTime({
    required DateTime? current,
    DateTime? firstDate,
    bool allowTime = true,
  }) async {
    final now = DateTime.now();
    final initial = current ?? now;
    final pickedDate = await _pickDate(
      context: context,
      initialDate: firstDate != null && initial.isBefore(firstDate)
          ? firstDate
          : initial,
      firstDate: firstDate,
    );
    if (pickedDate == null) {
      return current;
    }
    if (!allowTime || _allDay) {
      return DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    }
    final pickedTime = await _pickTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) {
      return DateTime(pickedDate.year, pickedDate.month, pickedDate.day);
    }
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  void _handleSave() {
    final bloc = context.read<CalendarBloc>();
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    DateTime? start = _start;
    DateTime? end = _end;

    if (start != null && end != null && end.isBefore(start)) {
      end = start.add(const Duration(hours: 1));
    }

    Duration? duration;
    DateTime? endDate;
    if (start != null && end != null) {
      if (_allDay || !_isSameDay(start, end)) {
        duration = null;
        endDate = end;
      } else {
        duration = end.difference(start);
        if (duration.inMinutes <= 0) {
          duration = const Duration(hours: 1);
          end = start.add(duration);
        }
        endDate = null;
      }
    }

    final updated = widget.task.updatedCopy(
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      scheduledStart: start,
      duration: duration,
      endDate: endDate,
      deadline: _deadline,
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      isAllDay: _allDay,
      important: _important,
      urgent: _urgent,
      completed: _completed,
    );

    bloc.add(CalendarEvent.taskUpdated(task: updated));
    Navigator.of(context).pop();
  }

  void _handleDelete() {
    final bloc = context.read<CalendarBloc>();
    bloc.add(CalendarEvent.taskDeleted(taskId: widget.task.id));
    Navigator.of(context).pop();
  }

  DateTime? _stripToMidnight(DateTime? value) {
    if (value == null) {
      return null;
    }
    return DateTime(value.year, value.month, value.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _CalendarTypography.smallCaps,
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

typedef _DatePickCallback = void Function(DateTime? value);

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.value,
    required this.onPick,
    this.allDay = false,
    this.allowTime = true,
    this.onClear,
    this.firstDate,
  });

  final String label;
  final DateTime? value;
  final _DatePickCallback onPick;
  final bool allDay;
  final bool allowTime;
  final VoidCallback? onClear;
  final DateTime? firstDate;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final date = value;
    final text = date == null
        ? 'Not set'
        : allowTime && !allDay
            ? '${l10n.formatMediumDate(date)} • ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(date))}'
            : l10n.formatMediumDate(date);

    return GestureDetector(
      onTap: () async {
        final dialog = context.findAncestorStateOfType<_TaskEditDialogState>();
        if (dialog == null) {
          return;
        }
        final picked = await dialog._pickDateTime(
          current: date,
          firstDate: firstDate,
          allowTime: allowTime,
        );
        if (picked != null) {
          onPick(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _CalendarColors.inputBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _CalendarColors.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                color: _CalendarColors.textSecondary, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$label: $text',
                style: _CalendarTypography.body.copyWith(
                  color: date == null
                      ? _CalendarColors.textSecondary
                      : _CalendarColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (date != null)
              IconButton(
                tooltip: 'Clear',
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: onClear ?? () => onPick(null),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.state});

  final CalendarState state;

  @override
  Widget build(BuildContext context) {
    final firstDay =
        DateTime(state.selectedDate.year, state.selectedDate.month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(firstDay.year, firstDay.month);
    final firstWeekday = firstDay.weekday % 7; // 0 for Sunday
    final totalCells = firstWeekday + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final tasksByDay = <int, List<CalendarTask>>{};

    for (final task in state.scheduledTasks) {
      final start = task.effectiveStart;
      if (start != null &&
          start.month == firstDay.month &&
          start.year == firstDay.year) {
        tasksByDay.putIfAbsent(start.day, () => <CalendarTask>[]).add(task);
      }
    }

    return Column(
      children: [
        Row(
          children: List.generate(7, (index) {
            final date =
                firstDay.subtract(Duration(days: firstWeekday - index));
            return Expanded(
              child: Text(
                DateFormat.E().format(date),
                textAlign: TextAlign.center,
                style: _CalendarTypography.caption,
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: rows * 7,
            itemBuilder: (context, index) {
              final dayNumber = index - firstWeekday + 1;
              final isCurrentMonth = dayNumber >= 1 && dayNumber <= daysInMonth;
              final tasks = isCurrentMonth
                  ? tasksByDay[dayNumber] ?? const []
                  : const <CalendarTask>[];
              final isSelected =
                  isCurrentMonth && dayNumber == state.selectedDate.day;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected ? _CalendarColors.highlight : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? _CalendarColors.primary
                        : _CalendarColors.divider,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCurrentMonth ? '$dayNumber' : '',
                        style: _CalendarTypography.caption,
                      ),
                      const SizedBox(height: 4),
                      ...tasks.take(3).map(
                            (task) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: task.priorityColor
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _CalendarTypography.caption,
                                ),
                              ),
                            ),
                          ),
                      if (tasks.length > 3)
                        Text(
                          '+${tasks.length - 3} more',
                          style: _CalendarTypography.caption,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _CalendarColors.errorBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _CalendarColors.errorBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded,
                color: _CalendarColors.errorIcon),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: _CalendarTypography.body,
              ),
            ),
            IconButton(
              tooltip: 'Dismiss',
              icon: const Icon(Icons.close_rounded),
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    this.focusNode,
    this.textInputAction,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      textInputAction: textInputAction,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: _CalendarColors.inputBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _CalendarColors.inputBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _CalendarColors.inputBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _CalendarColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.value,
    required this.label,
    required this.onChanged,
  });

  final DateTime? value;
  final String label;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = MaterialLocalizations.of(context);
    final date = value;
    final labelText = date == null
        ? label
        : '${l10n.formatMediumDate(date)} at ${l10n.formatTimeOfDay(TimeOfDay.fromDateTime(date))}';

    return GestureDetector(
      onTap: () async {
        final initialDate = value ?? DateTime.now();
        final pickedDate = await showDatePicker(
          context: context,
          initialDate: initialDate,
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (!context.mounted) {
          return;
        }
        if (pickedDate == null) {
          return;
        }
        final pickedTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(initialDate),
        );
        if (pickedTime == null) {
          onChanged(
              DateTime(pickedDate.year, pickedDate.month, pickedDate.day));
          return;
        }
        onChanged(
          DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _CalendarColors.inputBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: date == null
                ? _CalendarColors.inputBorder
                : _CalendarColors.primary,
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.event, color: _CalendarColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                labelText,
                style: value == null
                    ? _CalendarTypography.bodyMuted
                    : _CalendarTypography.body,
              ),
            ),
            if (value != null)
              IconButton(
                tooltip: 'Clear deadline',
                icon: const Icon(Icons.close_rounded),
                onPressed: () => onChanged(null),
              ),
          ],
        ),
      ),
    );
  }
}

class _TogglePill extends StatelessWidget {
  const _TogglePill({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color activeColor;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: value,
      onSelected: (selected) => onChanged(selected),
      selectedColor: activeColor.withValues(alpha: 0.16),
      backgroundColor: _CalendarColors.inputBackground,
      labelStyle: TextStyle(
        color: value ? activeColor.darken(0.2) : _CalendarColors.textSecondary,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(color: value ? activeColor : Colors.transparent),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _SidebarSection extends StatelessWidget {
  const _SidebarSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(), style: _CalendarTypography.smallCaps),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _SidebarTaskTile extends StatelessWidget {
  const _SidebarTaskTile({required this.task, this.subtitle});

  final CalendarTask task;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<CalendarBloc>();
    final tile = Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _CalendarColors.divider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 40,
            decoration: BoxDecoration(
              color: task.priorityColor,
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
                  style: _CalendarTypography.body.copyWith(fontSize: 13),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      subtitle!,
                      style: _CalendarTypography.bodyMuted.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Checkbox(
            value: task.completed,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            onChanged: (value) => bloc.add(
              CalendarEvent.taskCompleted(
                taskId: task.id,
                completed: value ?? false,
              ),
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.grab,
      child: Draggable<_TaskDragData>(
        data: _TaskDragData(taskId: task.id),
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(width: 240, child: tile),
        ),
        childWhenDragging: Opacity(
          opacity: 0.25,
          child: tile,
        ),
        child: GestureDetector(
          onTap: () => _showTaskDialog(context, task),
          child: tile,
        ),
      ),
    );
  }

  Future<void> _showTaskDialog(BuildContext context, CalendarTask task) {
    final bloc = context.read<CalendarBloc>();
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: _TaskEditDialog(task: task),
      ),
    );
  }
}

class _CalendarColors {
  static const canvas = Color(0xFFFFFFFF);
  static const panel = Color(0xFFF7F8FA);
  static const primary = Color(0xFF0969DA);
  static const completed = Color(0xFF0969DA);
  static const important = Color(0xFF28A745);
  static const urgent = Color(0xFFFD7E14);
  static const divider = Color(0xFFE1E4E8);
  static const gridLine = Color(0xFFE1E4E8);
  static const gridBackground = Color(0xFFFFFFFF);
  static const highlight = Color(0x0F0969DA);
  static const pointerHighlight = Color(0x140969DA);
  static const dragHighlight = Color(0x260969DA);
  static const inputBackground = Colors.white;
  static const inputBorder = Color(0xFFD1D5DA);
  static const textPrimary = Color(0xFF24292E);
  static const textSecondary = Color(0xFF6A737D);
  static const errorBackground = Color(0xFFFFF3F0);
  static const errorBorder = Color(0xFFFFC7BC);
  static const errorIcon = Color(0xFFDE5C4A);
  static const switchTrack = Color(0xFFD1D5DA);
}

class _CalendarTypography {
  static const appBar = TextStyle(
    color: _CalendarColors.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );
  static const headline = TextStyle(
    color: _CalendarColors.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 24,
  );
  static const body = TextStyle(
    color: _CalendarColors.textPrimary,
    fontWeight: FontWeight.w500,
    fontSize: 15,
  );
  static final bodyMuted = body.copyWith(
    color: _CalendarColors.textSecondary,
    fontWeight: FontWeight.w400,
  );
  static const caption = TextStyle(
    color: _CalendarColors.textSecondary,
    fontWeight: FontWeight.w500,
    fontSize: 12,
    letterSpacing: 0.2,
  );
  static final smallCaps = caption.copyWith(
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
  static final timeLabel = caption.copyWith(fontSize: 11);
  static final taskTitle = body.copyWith(fontWeight: FontWeight.w600);
  static const dayNumber = TextStyle(
    color: _CalendarColors.textPrimary,
    fontWeight: FontWeight.w700,
    fontSize: 20,
  );
}

extension on Color {
  Color darken(double amount) {
    final factor = 1 - amount;
    return Color.fromARGB(
      alpha,
      math.max(0, math.min(255, (red * factor).round())),
      math.max(0, math.min(255, (green * factor).round())),
      math.max(0, math.min(255, (blue * factor).round())),
    );
  }
}
