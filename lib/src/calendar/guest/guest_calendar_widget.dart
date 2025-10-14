import 'package:flutter/material.dart';
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
import '../view/widgets/calendar_keyboard_scope.dart';
import '../view/widgets/task_form_section.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key});

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState extends State<GuestCalendarWidget> {
  bool _sidebarVisible = true;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuestCalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        return CalendarKeyboardScope(
          autofocus: true,
          canUndo: state.canUndo,
          canRedo: state.canRedo,
          onUndo: () {
            context
                .read<GuestCalendarBloc>()
                .add(const CalendarEvent.undoRequested());
          },
          onRedo: () {
            context
                .read<GuestCalendarBloc>()
                .add(const CalendarEvent.redoRequested());
          },
          child: Scaffold(
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
          ),
        );
      },
    );
  }

  Widget _buildGuestBanner() {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets basePadding = responsive.contentPadding;
    final EdgeInsets bannerPadding = EdgeInsets.fromLTRB(
      basePadding.left,
      calendarSpacing12,
      basePadding.right,
      calendarSpacing12,
    );
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: bannerPadding,
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
          TaskPrimaryButton(
            label: 'Sign Up to Sync',
            onPressed: () => context.go('/login'),
            icon: Icons.login,
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
    final responsive = ResponsiveHelper.spec(context);
    return Container(
      margin: responsive.modalMargin,
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
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = responsive.contentPadding;
    return Column(
      children: [
        // Navigation bar at the top
        Padding(
          padding: contentPadding,
          child: CalendarNavigation(
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
        ),

        // Error display
        if (state.error != null) _buildErrorBanner(state),

        // Collapsible sidebar drawer or overlay
        if (_sidebarVisible) _buildSidebarWithProvider(height: 200),

        // Toggle button
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: contentPadding.left,
            vertical: contentPadding.top / 1.5,
          ),
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
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = responsive.contentPadding;
    final double sidebarWidth =
        ResponsiveHelper.sidebarDimensions(context).defaultWidth;
    return Row(
      children: [
        // Resizable sidebar - extends full height
        _buildSidebarWithProvider(width: sidebarWidth),

        // Main content area with navigation and calendar
        Expanded(
          child: Column(
            children: [
              // Navigation bar - only spans over calendar area
              Padding(
                padding: contentPadding,
                child: CalendarNavigation(
                  state: state,
                  onDateSelected: (date) =>
                      context.read<GuestCalendarBloc>().add(
                            CalendarEvent.dateSelected(date: date),
                          ),
                  onViewChanged: (view) =>
                      context.read<GuestCalendarBloc>().add(
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
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = responsive.contentPadding;
    final double sidebarWidth =
        ResponsiveHelper.sidebarDimensions(context).defaultWidth;
    return Row(
      children: [
        // Full sidebar always visible - extends full height
        _buildSidebarWithProvider(width: sidebarWidth),

        // Main content area with navigation and calendar
        Expanded(
          child: Column(
            children: [
              // Navigation bar - only spans over calendar area
              Padding(
                padding: contentPadding,
                child: CalendarNavigation(
                  state: state,
                  onDateSelected: (date) =>
                      context.read<GuestCalendarBloc>().add(
                            CalendarEvent.dateSelected(date: date),
                          ),
                  onViewChanged: (view) =>
                      context.read<GuestCalendarBloc>().add(
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

  Widget _buildSidebarWithProvider({double? height, double? width}) {
    final sidebar = BlocProvider<BaseCalendarBloc>.value(
      value: context.read<GuestCalendarBloc>(),
      child: const TaskSidebar(),
    );

    if (height != null || width != null) {
      return SizedBox(
        height: height,
        width: width,
        child: sidebar,
      );
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

  void _onTaskDragEnd(CalendarTask task, DateTime newTime) {
    final bloc = context.read<GuestCalendarBloc>();
    final CalendarTask normalized = task.normalizedForInteraction(newTime);
    bloc.commitTaskInteraction(normalized);
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
}
