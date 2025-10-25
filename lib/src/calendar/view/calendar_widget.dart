import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/common/ui/ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
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

class _CalendarWidgetState extends State<CalendarWidget>
    with TickerProviderStateMixin {
  late final TabController _mobileTabController;
  late final AnimationController _tasksTabPulseController;
  late final Animation<double> _tasksTabPulse;
  DateTime? _lastDragTabSwitch;
  DateTime? _lastSyncToastTime;

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
  }

  @override
  void dispose() {
    _mobileTabController.dispose();
    _tasksTabPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        final spec = ResponsiveHelper.spec(context);
        final bool usesMobileLayout =
            spec.sizeClass != CalendarSizeClass.expanded;
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
                .read<CalendarBloc>()
                .add(const CalendarEvent.undoRequested());
          },
          onRedo: () {
            context
                .read<CalendarBloc>()
                .add(const CalendarEvent.redoRequested());
          },
          child: Scaffold(
            backgroundColor: calendarBackgroundColor,
            body: Stack(
              children: [
                ResponsiveHelper.layoutBuilder(
                  context,
                  mobile: _buildMobileLayout(state, highlightTasksTab),
                  tablet: _buildTabletLayout(state, highlightTasksTab),
                  desktop: _buildDesktopLayout(state),
                ),
                if (state.isLoading) _buildLoadingOverlay(),
              ],
            ),
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
        state.lastSyncTime != _lastSyncToastTime &&
        DateTime.now().difference(state.lastSyncTime!).inSeconds < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lastSyncToastTime = state.lastSyncTime;
          FeedbackSystem.showSuccess(context, 'Calendar synced successfully!');
        }
      });
    }
  }

  Widget _buildErrorBanner(CalendarState state) {
    return Container(
      margin: calendarPaddingXl,
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

  Widget _buildMobileLayout(CalendarState state, bool highlightTasksTab) {
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
                    CalendarNavigation(
                      state: state,
                      onDateSelected: (date) => context
                          .read<CalendarBloc>()
                          .add(CalendarEvent.dateSelected(date: date)),
                      onViewChanged: (view) => context
                          .read<CalendarBloc>()
                          .add(CalendarEvent.viewChanged(view: view)),
                      onErrorCleared: () => context
                          .read<CalendarBloc>()
                          .add(const CalendarEvent.errorCleared()),
                      onUndo: () => context
                          .read<CalendarBloc>()
                          .add(const CalendarEvent.undoRequested()),
                      onRedo: () => context
                          .read<CalendarBloc>()
                          .add(const CalendarEvent.redoRequested()),
                      canUndo: state.canUndo,
                      canRedo: state.canRedo,
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
                _buildEdgeDragTargets(),
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

  Widget _buildMobileTabBar(
    BuildContext context, {
    required bool highlightTasksTab,
  }) {
    final bottomInset = MediaQuery.of(context).padding.bottom;
    return LayoutBuilder(
      builder: (context, constraints) {
        final tabBar = TabBar(
          controller: _mobileTabController,
          dividerHeight: 0,
          isScrollable: constraints.maxWidth < 200,
          tabAlignment: constraints.maxWidth < 200
              ? TabAlignment.center
              : TabAlignment.fill,
          tabs: [
            const Tab(text: 'Schedule'),
            Tab(child: _buildTasksTabLabel(highlightTasksTab)),
          ],
        );
        return Material(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Stack(
              children: [
                tabBar,
                Positioned.fill(
                  child: Row(
                    children: [
                      Expanded(child: _buildTabDragTarget(0)),
                      Expanded(child: _buildTabDragTarget(1)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabDragTarget(int index) {
    return DragTarget<CalendarTask>(
      hitTestBehavior: HitTestBehavior.translucent,
      onWillAcceptWithDetails: (_) {
        _switchMobileTab(index, fromDrag: true);
        return false;
      },
      builder: (context, candidateData, rejectedData) =>
          const SizedBox.expand(),
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

  Widget _buildEdgeDragTargets() {
    const double zoneWidth = 32;
    return Positioned.fill(
      child: Row(
        children: [
          SizedBox(
            width: zoneWidth,
            child: DragTarget<CalendarTask>(
              hitTestBehavior: HitTestBehavior.translucent,
              onWillAcceptWithDetails: (_) {
                _switchMobileTab(0, fromDrag: true);
                return false;
              },
              builder: (context, candidateData, rejectedData) =>
                  const SizedBox.expand(),
            ),
          ),
          const Expanded(child: SizedBox.shrink()),
          SizedBox(
            width: zoneWidth,
            child: DragTarget<CalendarTask>(
              hitTestBehavior: HitTestBehavior.translucent,
              onWillAcceptWithDetails: (_) {
                _switchMobileTab(1, fromDrag: true);
                return false;
              },
              builder: (context, candidateData, rejectedData) =>
                  const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }

  void _switchMobileTab(int index, {bool fromDrag = false}) {
    if (_mobileTabController.index == index) {
      return;
    }
    if (fromDrag) {
      final DateTime now = DateTime.now();
      if (_lastDragTabSwitch != null &&
          now.difference(_lastDragTabSwitch!) <
              const Duration(milliseconds: 400)) {
        return;
      }
      _lastDragTabSwitch = now;
    }
    _mobileTabController.animateTo(index);
  }

  Widget _buildTabletLayout(CalendarState state, bool highlightTasksTab) {
    return _buildMobileLayout(state, highlightTasksTab);
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
    final CalendarTask normalized = task.normalizedForInteraction(newTime);
    bloc.commitTaskInteraction(normalized);
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    showQuickAddModal(
      context: context,
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
    );
  }
}
