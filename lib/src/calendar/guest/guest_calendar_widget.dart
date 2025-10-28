import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../view/calendar_grid.dart';
import '../view/calendar_navigation.dart';
import '../view/error_display.dart';
import '../view/feedback_system.dart';
import '../view/loading_indicator.dart';
import '../view/quick_add_modal.dart';
import '../view/task_sidebar.dart';
import 'guest_calendar_bloc.dart';
import '../view/widgets/calendar_drag_tab_mixin.dart';
import '../view/widgets/calendar_keyboard_scope.dart';
import '../view/widgets/task_form_section.dart';

class GuestCalendarWidget extends StatefulWidget {
  const GuestCalendarWidget({super.key});

  @override
  State<GuestCalendarWidget> createState() => _GuestCalendarWidgetState();
}

class _GuestCalendarWidgetState extends State<GuestCalendarWidget>
    with TickerProviderStateMixin, CalendarDragTabMixin {
  late final TabController _mobileTabController;
  late final AnimationController _tasksTabPulseController;
  late final Animation<double> _tasksTabPulse;
  bool _usesMobileLayout = false;

  @override
  void initState() {
    super.initState();
    _mobileTabController = TabController(length: 2, vsync: this);
    _tasksTabPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _tasksTabPulse = CurvedAnimation(
      parent: _tasksTabPulseController,
      curve: Curves.easeInOut,
    );
    initCalendarDragTabMixin();
  }

  @override
  void dispose() {
    disposeCalendarDragTabMixin();
    _mobileTabController.dispose();
    _tasksTabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuestCalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        final spec = ResponsiveHelper.spec(context);
        final bool usesMobileLayout =
            spec.sizeClass != CalendarSizeClass.expanded;
        _usesMobileLayout = usesMobileLayout;
        final bool highlightTasksTab = usesMobileLayout &&
            state.isSelectionMode &&
            _mobileTabController.index != 1;
        _updateTasksTabPulse(highlightTasksTab);
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
                        mobile: _buildMobileLayout(state, highlightTasksTab),
                        tablet: _buildTabletLayout(state, highlightTasksTab),
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
      calendarGutterMd,
      basePadding.right,
      calendarGutterMd,
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
          const SizedBox(width: calendarGutterMd),
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
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
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

  void _updateTasksTabPulse(bool shouldPulse) {
    if (shouldPulse) {
      if (!_tasksTabPulseController.isAnimating) {
        _tasksTabPulseController.repeat(reverse: true);
      }
    } else {
      if (_tasksTabPulseController.isAnimating ||
          _tasksTabPulseController.value != 0) {
        _tasksTabPulseController.stop();
        _tasksTabPulseController.reset();
      }
    }
  }

  Widget _buildMobileLayout(
    CalendarState state,
    bool highlightTasksTab,
  ) {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = responsive.contentPadding;
    return SafeArea(
      top: true,
      bottom: false,
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _mobileTabController,
            builder: (context, _) {
              final bool showNavigation = _mobileTabController.index == 0;
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showNavigation)
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
                        onErrorCleared: () =>
                            context.read<GuestCalendarBloc>().add(
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
                  if (state.error != null) _buildErrorBanner(state),
                ],
              );
            },
          ),
          Expanded(
            child: Stack(
              children: [
                TabBarView(
                  controller: _mobileTabController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildCalendarGridWithHandlers(state),
                    _buildSidebarWithProvider(),
                  ],
                ),
                buildDragEdgeTargets(),
              ],
            ),
          ),
          Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
            child: _buildMobileTabBar(
              context,
              highlightTasksTab: highlightTasksTab,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(CalendarState state, bool highlightTasksTab) {
    return _buildMobileLayout(state, highlightTasksTab);
  }

  Widget _buildDesktopLayout(CalendarState state) {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = responsive.contentPadding;
    return Row(
      children: [
        // Full sidebar always visible - extends full height
        _buildSidebarWithProvider(),

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

  Widget _buildSidebarWithProvider({double? height}) {
    final sidebar = BlocProvider<BaseCalendarBloc>.value(
      value: context.read<GuestCalendarBloc>(),
      child: const TaskSidebar(),
    );

    if (height != null) {
      return SizedBox(
        height: height,
        child: sidebar,
      );
    }

    return sidebar;
  }

  Widget _buildMobileTabBar(
    BuildContext context, {
    required bool highlightTasksTab,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        return buildDragAwareTabBar(
          context: context,
          constraints: constraints,
          bottomInset: bottomInset,
          scheduleTabLabel: const Text('Schedule'),
          tasksTabLabel: _buildTasksTabLabel(highlightTasksTab),
        );
      },
    );
  }

  Widget _buildTasksTabLabel(bool highlight) {
    if (!highlight) {
      return const Text('Tasks');
    }
    return AnimatedBuilder(
      animation: _tasksTabPulse,
      builder: (context, _) {
        final double t = _tasksTabPulse.value;
        final double scale = 0.85 + (0.25 * t);
        final Color badgeColor = Color.lerp(
          calendarPrimaryColor.withValues(alpha: 0.55),
          calendarPrimaryColor,
          t,
        )!;
        final bool isRtl = Directionality.of(context) == TextDirection.rtl;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                'Tasks',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Positioned(
              top: -6,
              right: isRtl ? null : -14,
              left: isRtl ? -14 : null,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        badgeColor.withValues(alpha: 0.9),
                        badgeColor,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: badgeColor.withValues(alpha: 0.45),
                        blurRadius: 8 + (4 * t),
                        spreadRadius: 1.5 + t,
                      ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.25 + (0.15 * t)),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
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
      onDragSessionStarted: handleGridDragSessionStarted,
      onDragGlobalPositionChanged: handleGridDragPositionChanged,
      onDragSessionEnded: handleGridDragSessionEnded,
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
    showQuickAddModal(
      context: context,
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
    );
  }

  @override
  TabController get mobileTabController => _mobileTabController;

  @override
  bool get isDragSwitcherEnabled => _usesMobileLayout;
}
