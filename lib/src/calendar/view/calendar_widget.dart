import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import 'calendar_grid.dart';
import 'calendar_navigation.dart';
import 'error_display.dart';
import 'feedback_system.dart';
import 'loading_indicator.dart';
import 'quick_add_modal.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_keyboard_scope.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late final ValueNotifier<bool> _sidebarVisible;

  @override
  void initState() {
    super.initState();
    _sidebarVisible = ValueNotifier<bool>(true);
  }

  @override
  void dispose() {
    _sidebarVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return CalendarKeyboardScope(
          autofocus: true,
          canUndo: state.canUndo,
          canRedo: state.canRedo,
          onUndo: () {
            context
                .read<CalendarBloc>()
                .add(const CalendarEvent.undoRequested());
          },
          onRedo: () {
            context
                .read<CalendarBloc>()
                .add(const CalendarEvent.redoRequested());
          },
          child: ValueListenableBuilder<bool>(
            valueListenable: _sidebarVisible,
            builder: (context, sidebarVisible, _) {
              return Scaffold(
                backgroundColor: calendarBackgroundColor,
                body: Stack(
                  children: [
                    ResponsiveHelper.layoutBuilder(
                      context,
                      mobile: _buildMobileLayout(state, sidebarVisible),
                      tablet: _buildTabletLayout(state),
                      desktop: _buildDesktopLayout(state),
                    ),
                    if (state.isLoading) _buildLoadingOverlay(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleStateChanges(BuildContext context, CalendarState state) {
    // Handle errors
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FeedbackSystem.showError(context, state.error!);
        }
      });
    }

    // Handle sync success
    if (state.lastSyncTime != null &&
        DateTime.now().difference(state.lastSyncTime!).inSeconds < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FeedbackSystem.showSuccess(context, 'Calendar synced successfully!');
        }
      });
    }
  }

  Widget _buildErrorBanner(CalendarState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ErrorDisplay(
        error: state.error!,
        onRetry: () => context.read<CalendarBloc>().add(
              const CalendarEvent.errorCleared(),
            ),
        onDismiss: () => context.read<CalendarBloc>().add(
              const CalendarEvent.errorCleared(),
            ),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.3),
      child: const Center(
        child: CalendarLoadingIndicator(),
      ),
    );
  }

  Widget _buildMobileLayout(CalendarState state, bool sidebarVisible) {
    return Column(
      children: [
        // Navigation bar at the top
        CalendarNavigation(
          state: state,
          onDateSelected: (date) => context.read<CalendarBloc>().add(
                CalendarEvent.dateSelected(date: date),
              ),
          onViewChanged: (view) => context.read<CalendarBloc>().add(
                CalendarEvent.viewChanged(view: view),
              ),
          onErrorCleared: () => context.read<CalendarBloc>().add(
                const CalendarEvent.errorCleared(),
              ),
          onUndo: () => context
              .read<CalendarBloc>()
              .add(const CalendarEvent.undoRequested()),
          onRedo: () => context
              .read<CalendarBloc>()
              .add(const CalendarEvent.redoRequested()),
          canUndo: state.canUndo,
          canRedo: state.canRedo,
        ),

        // Error display
        if (state.error != null) _buildErrorBanner(state),

        // Collapsible sidebar drawer or overlay
        if (sidebarVisible)
          _buildSidebarWithProvider(height: calendarMobileSidebarHeight),

        // Toggle button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _sidebarVisible.value = !sidebarVisible,
                icon: Icon(
                    sidebarVisible ? Icons.expand_less : Icons.expand_more),
                style: IconButton.styleFrom(
                  backgroundColor: calendarContainerColor,
                  foregroundColor: calendarTitleColor,
                ),
              ),
              Text(
                sidebarVisible ? 'Hide Tasks' : 'Show Tasks',
                style: const TextStyle(
                  fontSize: 14,
                  color: calendarSubtitleColor,
                ),
              ),
            ],
          ),
        ),

        // Calendar grid
        Expanded(
          child: _buildCalendarGridWithHandlers(state),
        ),
      ],
    );
  }

  Widget _buildTabletLayout(CalendarState state) {
    return Row(
      children: [
        // Resizable sidebar - extends full height
        _buildSidebarWithProvider(),

        // Main content area with navigation and calendar
        Expanded(
          child: Column(
            children: [
              // Navigation bar - only spans over calendar area
              CalendarNavigation(
                state: state,
                sidebarVisible: true, // Tablet layout has sidebar alongside
                onDateSelected: (date) => context.read<CalendarBloc>().add(
                      CalendarEvent.dateSelected(date: date),
                    ),
                onViewChanged: (view) => context.read<CalendarBloc>().add(
                      CalendarEvent.viewChanged(view: view),
                    ),
                onErrorCleared: () => context.read<CalendarBloc>().add(
                      const CalendarEvent.errorCleared(),
                    ),
                onUndo: () => context
                    .read<CalendarBloc>()
                    .add(const CalendarEvent.undoRequested()),
                onRedo: () => context
                    .read<CalendarBloc>()
                    .add(const CalendarEvent.redoRequested()),
                canUndo: state.canUndo,
                canRedo: state.canRedo,
              ),

              // Error display
              if (state.error != null) _buildErrorBanner(state),

              // Calendar grid with horizontal scroll
              Expanded(
                child: _buildCalendarGridWithHandlers(state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout(CalendarState state) {
    return Row(
      children: [
        // Full sidebar always visible - extends full height
        _buildSidebarWithProvider(),

        // Main content area with navigation and calendar
        Expanded(
          child: Column(
            children: [
              // Navigation bar - only spans over calendar area
              CalendarNavigation(
                state: state,
                sidebarVisible: true, // Desktop layout has sidebar alongside
                onDateSelected: (date) => context.read<CalendarBloc>().add(
                      CalendarEvent.dateSelected(date: date),
                    ),
                onViewChanged: (view) => context.read<CalendarBloc>().add(
                      CalendarEvent.viewChanged(view: view),
                    ),
                onErrorCleared: () => context.read<CalendarBloc>().add(
                      const CalendarEvent.errorCleared(),
                    ),
                onUndo: () => context
                    .read<CalendarBloc>()
                    .add(const CalendarEvent.undoRequested()),
                onRedo: () => context
                    .read<CalendarBloc>()
                    .add(const CalendarEvent.redoRequested()),
                canUndo: state.canUndo,
                canRedo: state.canRedo,
              ),

              // Error display
              if (state.error != null) _buildErrorBanner(state),

              // Calendar grid
              Expanded(
                child: _buildCalendarGridWithHandlers(state),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSidebarWithProvider({double? height}) {
    final sidebar = BlocProvider<BaseCalendarBloc>.value(
      value: context.read<CalendarBloc>(),
      child: const TaskSidebar(),
    );

    if (height != null) {
      return SizedBox(height: height, child: sidebar);
    }

    return sidebar;
  }

  Widget _buildCalendarGridWithHandlers(CalendarState state) {
    return CalendarGrid<CalendarBloc>(
      state: state,
      onEmptySlotTapped: _onEmptySlotTapped,
      onTaskDragEnd: _onTaskDragEnd,
      onDateSelected: (date) => context.read<CalendarBloc>().add(
            CalendarEvent.dateSelected(date: date),
          ),
      onViewChanged: (view) => context.read<CalendarBloc>().add(
            CalendarEvent.viewChanged(view: view),
          ),
      focusRequest: state.pendingFocus,
    );
  }

  void _onEmptySlotTapped(DateTime time, Offset position) {
    _showQuickAddModal(position, prefilledTime: time);
  }

  void _onTaskDragEnd(CalendarTask task, DateTime newTime) {
    final bloc = context.read<CalendarBloc>();
    final currentState = bloc.state;
    final CalendarTask? directTask = currentState.model.tasks[task.id];
    if (directTask != null) {
      final DateTime plannedStart = newTime;
      final DateTime? taskEnd = task.effectiveEndDate;
      final Duration? taskDuration = task.duration ??
          (taskEnd != null && task.scheduledTime != null
              ? taskEnd.difference(task.scheduledTime!)
              : null);

      final Duration duration = taskDuration ??
          directTask.duration ??
          (directTask.effectiveEndDate != null &&
                  directTask.scheduledTime != null
              ? directTask.effectiveEndDate!
                  .difference(directTask.scheduledTime!)
              : const Duration(hours: 1));
      final DateTime? plannedEnd = taskEnd ?? plannedStart.add(duration);

      final DateTime? originalEnd = directTask.effectiveEndDate;
      final Duration? originalDuration = directTask.duration ??
          (originalEnd != null && directTask.scheduledTime != null
              ? originalEnd.difference(directTask.scheduledTime!)
              : null);

      if (directTask.scheduledTime != plannedStart ||
          originalDuration != duration ||
          originalEnd != plannedEnd) {
        bloc.add(
          CalendarEvent.taskResized(
            taskId: directTask.id,
            scheduledTime: plannedStart,
            duration: duration,
            endDate: plannedEnd,
          ),
        );
      } else {
        bloc.add(
          CalendarEvent.taskDropped(
            taskId: directTask.id,
            time: plannedStart,
          ),
        );
      }
      return;
    }

    final baseId = task.baseId;
    final originalTask = currentState.model.tasks[baseId];
    final plannedStart = (task.scheduledTime != null &&
            originalTask?.scheduledTime != task.scheduledTime)
        ? task.scheduledTime!
        : newTime;
    final DateTime? taskEnd = task.effectiveEndDate;
    final Duration? taskDuration = task.duration ??
        (taskEnd != null && task.scheduledTime != null
            ? taskEnd.difference(task.scheduledTime!)
            : null);

    final Duration duration = taskDuration ??
        originalTask?.duration ??
        (originalTask?.effectiveEndDate != null &&
                originalTask?.scheduledTime != null
            ? originalTask!.effectiveEndDate!
                .difference(originalTask.scheduledTime!)
            : const Duration(hours: 1));
    final DateTime? plannedEnd = taskEnd ?? plannedStart.add(duration);

    if (task.isOccurrence) {
      bloc.add(
        CalendarEvent.taskOccurrenceUpdated(
          taskId: baseId,
          occurrenceId: task.id,
          scheduledTime: newTime,
          duration: duration,
          endDate: plannedEnd,
        ),
      );
      return;
    }

    if (originalTask != null &&
        (originalTask.duration != task.duration ||
            originalTask.scheduledTime != task.scheduledTime ||
            originalTask.endDate != plannedEnd)) {
      bloc.add(
        CalendarEvent.taskResized(
          taskId: baseId,
          scheduledTime: plannedStart,
          duration: duration,
          endDate: plannedEnd,
        ),
      );
    } else {
      bloc.add(
        CalendarEvent.taskDropped(
          taskId: baseId,
          time: plannedStart,
        ),
      );
    }
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    showDialog(
      context: context,
      builder: (context) => QuickAddModal(
        prefilledDateTime: prefilledTime,
        onTaskAdded: (task) => context.read<CalendarBloc>().add(
              CalendarEvent.taskAdded(
                title: task.title,
                scheduledTime: task.scheduledTime,
                description: task.description,
                duration: task.duration,
                priority: task.priority ?? TaskPriority.none,
                recurrence: task.recurrence,
                startHour: task.startHour,
              ),
            ),
      ),
    );
  }
}
