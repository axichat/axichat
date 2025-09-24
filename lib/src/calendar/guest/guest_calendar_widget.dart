import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/responsive_helper.dart';
import '../view/calendar_grid.dart';
import '../view/calendar_navigation.dart';
import '../view/error_display.dart';
import '../view/feedback_system.dart';
import '../view/loading_indicator.dart';
import '../view/quick_add_modal.dart';
import '../view/task_sidebar.dart';
import 'guest_calendar_bloc.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key});

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState extends State<GuestCalendarWidget> {
  bool _sidebarVisible = true;
  late final KeyEventCallback _hardwareShortcutHandler;

  @override
  void initState() {
    super.initState();
    _hardwareShortcutHandler = _handleHardwareShortcut;
    HardwareKeyboard.instance.addHandler(_hardwareShortcutHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_hardwareShortcutHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuestCalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: calendarBackgroundColor,
          body: Stack(
            children: [
              Column(
                children: [
                  // Guest banner at very top
                  _buildGuestBanner(),

                  // New structure: Row with sidebar OUTSIDE of navigation column
                  Expanded(
                    child: ResponsiveHelper.layoutBuilder(
                      context,
                      mobile: _buildMobileLayout(state),
                      tablet: _buildTabletLayout(state),
                      desktop: _buildDesktopLayout(state),
                    ),
                  ),
                ],
              ),

              // Loading overlay
              if (state.isLoading) _buildLoadingOverlay(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuestBanner() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Colors.blue.shade600,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Guest Mode - Tasks saved locally on this device only',
              style: calendarBodyTextStyle.copyWith(
                color: calendarSubtitleColor,
                fontSize: 14,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: axiGreen,
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Text(
              'Sign Up to Sync',
              style: calendarBodyTextStyle.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleStateChanges(BuildContext context, CalendarState state) {
    // Handle errors (no sync errors in guest mode)
    if (state.error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          FeedbackSystem.showError(context, state.error!);
        }
      });
    }
  }

  Widget _buildErrorBanner(CalendarState state) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ErrorDisplay(
        error: state.error!,
        onRetry: () => context.read<GuestCalendarBloc>().add(
              const CalendarEvent.errorCleared(),
            ),
        onDismiss: () => context.read<GuestCalendarBloc>().add(
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
          onDateSelected: (date) => context.read<GuestCalendarBloc>().add(
                CalendarEvent.dateSelected(date: date),
              ),
          onViewChanged: (view) => context.read<GuestCalendarBloc>().add(
                CalendarEvent.viewChanged(view: view),
              ),
          onErrorCleared: () => context.read<GuestCalendarBloc>().add(
                const CalendarEvent.errorCleared(),
              ),
          onUndo: () => context
              .read<GuestCalendarBloc>()
              .add(const CalendarEvent.undoRequested()),
          onRedo: () => context
              .read<GuestCalendarBloc>()
              .add(const CalendarEvent.redoRequested()),
          canUndo: state.canUndo,
          canRedo: state.canRedo,
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
                style: calendarBodyTextStyle.copyWith(
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
                onDateSelected: (date) => context.read<GuestCalendarBloc>().add(
                      CalendarEvent.dateSelected(date: date),
                    ),
                onViewChanged: (view) => context.read<GuestCalendarBloc>().add(
                      CalendarEvent.viewChanged(view: view),
                    ),
                onErrorCleared: () => context.read<GuestCalendarBloc>().add(
                      const CalendarEvent.errorCleared(),
                    ),
                onUndo: () => context
                    .read<GuestCalendarBloc>()
                    .add(const CalendarEvent.undoRequested()),
                onRedo: () => context
                    .read<GuestCalendarBloc>()
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
                onDateSelected: (date) => context.read<GuestCalendarBloc>().add(
                      CalendarEvent.dateSelected(date: date),
                    ),
                onViewChanged: (view) => context.read<GuestCalendarBloc>().add(
                      CalendarEvent.viewChanged(view: view),
                    ),
                onErrorCleared: () => context.read<GuestCalendarBloc>().add(
                      const CalendarEvent.errorCleared(),
                    ),
                onUndo: () => context
                    .read<GuestCalendarBloc>()
                    .add(const CalendarEvent.undoRequested()),
                onRedo: () => context
                    .read<GuestCalendarBloc>()
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
      value: context.read<GuestCalendarBloc>(),
      child: const TaskSidebar(),
    );

    if (height != null) {
      return SizedBox(height: height, child: sidebar);
    }

    return sidebar;
  }

  Widget _buildCalendarGridWithHandlers(CalendarState state) {
    return CalendarGrid<GuestCalendarBloc>(
      state: state,
      onEmptySlotTapped: _onEmptySlotTapped,
      onTaskDragEnd: _onTaskDragEnd,
      onDateSelected: (date) => context.read<GuestCalendarBloc>().add(
            CalendarEvent.dateSelected(date: date),
          ),
      onViewChanged: (view) => context.read<GuestCalendarBloc>().add(
            CalendarEvent.viewChanged(view: view),
          ),
    );
  }

  void _onEmptySlotTapped(DateTime time, Offset position) {
    _showQuickAddModal(position, prefilledTime: time);
  }

  void _onTaskDragEnd(
    CalendarTask task,
    DateTime newTime,
    CalendarTask? collision,
  ) {
    final bloc = context.read<GuestCalendarBloc>();
    final baseId = task.baseId;
    final originalTask = bloc.state.model.tasks[baseId];
    final plannedStart = (task.scheduledTime != null &&
            originalTask?.scheduledTime != task.scheduledTime)
        ? task.scheduledTime!
        : newTime;
    final scheduled = plannedStart;
    final duration =
        task.duration ?? originalTask?.duration ?? const Duration(hours: 1);

    if (collision != null &&
        collision.id != task.id &&
        collision.scheduledTime != null) {
      final collisionStart = collision.scheduledTime!;
      final sameStart = collisionStart.isAtSameMomentAs(scheduled);
      final sameDuration =
          (collision.duration ?? const Duration(hours: 1)) == duration;
      if (!sameStart || !sameDuration) {
        bloc.add(
          CalendarEvent.taskResized(
            taskId: collision.baseId,
            startHour: collisionStart.hour + (collisionStart.minute / 60.0),
            duration:
                (collision.duration ?? const Duration(hours: 1)).inMinutes /
                    60.0,
            daySpan: collision.effectiveDaySpan,
          ),
        );
      }
    }

    if (task.isOccurrence) {
      final scheduled = newTime;
      bloc.add(
        CalendarEvent.taskOccurrenceUpdated(
          taskId: baseId,
          occurrenceId: task.id,
          scheduledTime: scheduled,
          duration: task.duration,
          endDate: task.endDate,
          daySpan: task.daySpan,
        ),
      );
      return;
    }

    if (originalTask != null &&
        (originalTask.duration != task.duration ||
            originalTask.scheduledTime != task.scheduledTime)) {
      // This handles both resize and time change
      final startHour = scheduled.hour + (scheduled.minute / 60.0);
      final durationHours = duration.inMinutes / 60.0;

      bloc.add(
        CalendarEvent.taskResized(
          taskId: baseId,
          startHour: startHour,
          duration: durationHours,
          daySpan: task.effectiveDaySpan,
        ),
      );
    } else {
      // Simple time change only
      bloc.add(
        CalendarEvent.taskDropped(
          taskId: baseId,
          time: scheduled,
        ),
      );
    }
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    showDialog(
      context: context,
      builder: (context) => QuickAddModal(
        prefilledDateTime: prefilledTime,
        onTaskAdded: (task) => context.read<GuestCalendarBloc>().add(
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

  bool _handleHardwareShortcut(KeyEvent event) {
    if (!mounted || event is! KeyDownEvent || event is KeyRepeatEvent) {
      return false;
    }

    final focusedWidget = FocusManager.instance.primaryFocus?.context?.widget;
    if (focusedWidget is EditableText) {
      return false;
    }

    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    final bool metaPressed = pressed.contains(LogicalKeyboardKey.metaLeft) ||
        pressed.contains(LogicalKeyboardKey.metaRight);
    final bool controlPressed =
        pressed.contains(LogicalKeyboardKey.controlLeft) ||
            pressed.contains(LogicalKeyboardKey.controlRight);
    final bool shiftPressed = pressed.contains(LogicalKeyboardKey.shiftLeft) ||
        pressed.contains(LogicalKeyboardKey.shiftRight);

    final bool modifierPressed = metaPressed || controlPressed;
    final key = event.logicalKey;

    final bool isUndoCombination =
        key == LogicalKeyboardKey.keyZ && modifierPressed && !shiftPressed;
    final bool isRedoCombination =
        (key == LogicalKeyboardKey.keyZ && modifierPressed && shiftPressed) ||
            (key == LogicalKeyboardKey.keyY && modifierPressed);

    final bloc = context.read<GuestCalendarBloc>();
    final state = bloc.state;

    if (isUndoCombination && state.canUndo) {
      bloc.add(const CalendarEvent.undoRequested());
      return true;
    }

    if (isRedoCombination && state.canRedo) {
      bloc.add(const CalendarEvent.redoRequested());
      return true;
    }

    return false;
  }
}
