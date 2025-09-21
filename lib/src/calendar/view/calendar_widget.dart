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

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  bool _sidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: calendarBackgroundColor,
          body: Stack(
            children: [
              // New structure: Row with sidebar OUTSIDE of navigation column
              ResponsiveHelper.layoutBuilder(
                context,
                mobile: _buildMobileLayout(state),
                tablet: _buildTabletLayout(state),
                desktop: _buildDesktopLayout(state),
              ),

              // Loading overlay
              if (state.isLoading) _buildLoadingOverlay(),
            ],
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

  Widget _buildMobileLayout(CalendarState state) {
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
        ),

        // Error display
        if (state.error != null) _buildErrorBanner(state),

        // Collapsible sidebar drawer or overlay
        if (_sidebarVisible) _buildSidebarWithProvider(height: 200),

        // Toggle button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              IconButton(
                onPressed: () =>
                    setState(() => _sidebarVisible = !_sidebarVisible),
                icon: Icon(
                    _sidebarVisible ? Icons.expand_less : Icons.expand_more),
                style: IconButton.styleFrom(
                  backgroundColor: calendarContainerColor,
                  foregroundColor: calendarTitleColor,
                ),
              ),
              Text(
                _sidebarVisible ? 'Hide Tasks' : 'Show Tasks',
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
    final calendarBloc = context.watch<CalendarBloc>();
    return CalendarGrid(
      state: state,
      bloc: calendarBloc,
      onEmptySlotTapped: _onEmptySlotTapped,
      onTaskDragEnd: _onTaskDragEnd,
      onDateSelected: (date) => context.read<CalendarBloc>().add(
            CalendarEvent.dateSelected(date: date),
          ),
      onViewChanged: (view) => context.read<CalendarBloc>().add(
            CalendarEvent.viewChanged(view: view),
          ),
    );
  }

  void _onEmptySlotTapped(DateTime time, Offset position) {
    _showQuickAddModal(position, prefilledTime: time);
  }

  void _onTaskDragEnd(CalendarTask task, DateTime newTime) {
    final baseId = task.baseId;
    final originalTask =
        context.read<CalendarBloc>().state.model.tasks[baseId];
    if (originalTask != null &&
        (originalTask.duration != task.duration ||
            originalTask.scheduledTime != task.scheduledTime)) {
      // This handles both resize and time change
      final startHour =
          task.scheduledTime!.hour + (task.scheduledTime!.minute / 60.0);
      final durationHours =
          (task.duration ?? const Duration(hours: 1)).inMinutes / 60.0;

      context.read<CalendarBloc>().add(
            CalendarEvent.taskResized(
              taskId: baseId,
              startHour: startHour,
              duration: durationHours,
              daySpan: task.effectiveDaySpan,
            ),
          );
    } else {
      // Simple time change only
      context.read<CalendarBloc>().add(
            CalendarEvent.taskDropped(
              taskId: baseId,
              time: newTime,
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
              ),
            ),
      ),
    );
  }
}
