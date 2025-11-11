import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/responsive_helper.dart';
import 'calendar_grid.dart';
import 'calendar_navigation.dart';
import 'error_display.dart';
import 'feedback_system.dart';
import 'loading_indicator.dart';
import 'models/calendar_drag_payload.dart';
import 'quick_add_modal.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_drag_tab_mixin.dart';
import 'widgets/calendar_keyboard_scope.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget>
    with TickerProviderStateMixin, CalendarDragTabMixin {
  late final TabController _mobileTabController;
  late final AnimationController _tasksTabPulseController;
  late final Animation<double> _tasksTabPulse;
  DateTime? _lastSyncToastTime;
  bool _usesMobileLayout = false;
  CalendarBloc? _calendarBloc;
  final GlobalKey<TaskSidebarState> _sidebarKey = GlobalKey<TaskSidebarState>();
  final ValueNotifier<bool> _cancelBucketHoverNotifier =
      ValueNotifier<bool>(false);

  bool get _hasMouseDevice =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

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
    _cancelBucketHoverNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _calendarBloc ??= context.read<CalendarBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
        final colors = context.colorScheme;
        final spec = ResponsiveHelper.spec(context);
        final mediaQuery = MediaQuery.of(context);
        final bool isLandscapePhone =
            mediaQuery.orientation == Orientation.landscape &&
                mediaQuery.size.shortestSide < compactDeviceBreakpoint;
        final CalendarSizeClass baseSizeClass = spec.sizeClass;
        final CalendarSizeClass layoutClass =
            isLandscapePhone && baseSizeClass == CalendarSizeClass.expanded
                ? CalendarSizeClass.medium
                : baseSizeClass;
        final bool usesMobileLayout = layoutClass == CalendarSizeClass.compact;
        _usesMobileLayout = usesMobileLayout;
        final bool highlightTasksTab = usesMobileLayout &&
            state.isSelectionMode &&
            _mobileTabController.index != 1;
        final Widget activeLayout = switch (layoutClass) {
          CalendarSizeClass.compact =>
            _buildMobileLayout(state, highlightTasksTab),
          CalendarSizeClass.medium => _buildTabletLayout(state),
          CalendarSizeClass.expanded => _buildDesktopLayout(state),
        };
        _updateTasksTabPulse(highlightTasksTab);
        return CalendarKeyboardScope(
          autofocus: true,
          canUndo: state.canUndo,
          canRedo: state.canRedo,
          onUndo: () {
            _calendarBloc?.add(const CalendarEvent.undoRequested());
          },
          onRedo: () {
            _calendarBloc?.add(const CalendarEvent.redoRequested());
          },
          child: Scaffold(
            backgroundColor: colors.background,
            body: Stack(
              children: [
                Column(
                  children: [
                    _buildCalendarAppBar(state),
                    Divider(
                      height: 1,
                      color: colors.border,
                    ),
                    Expanded(child: activeLayout),
                  ],
                ),
                if (state.isLoading) _buildLoadingOverlay(context),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleStateChanges(BuildContext context, CalendarState state) {
    // Handle errors
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }

    // Handle sync success
    if (state.lastSyncTime != null &&
        state.lastSyncTime != _lastSyncToastTime &&
        DateTime.now().difference(state.lastSyncTime!).inSeconds < 3) {
      if (mounted) {
        _lastSyncToastTime = state.lastSyncTime;
        FeedbackSystem.showSuccess(context, 'Calendar synced successfully!');
      }
    }
  }

  Widget _buildCalendarAppBar(CalendarState state) {
    final colors = context.colorScheme;
    return Material(
      color: colors.card,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: calendarMarginLarge,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: 'Back to chats',
                color: colors.foreground,
                borderColor: colors.border,
                onPressed: _handleCalendarBackPressed,
              ),
              const SizedBox(width: calendarGutterMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Calendar',
                      style: context.textTheme.h3,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: calendarGutterMd),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SyncControls(
                    state: state,
                    compact: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCalendarBackPressed() {
    final chatsCubit = context.read<ChatsCubit?>();
    if (chatsCubit != null && chatsCubit.state.openCalendar) {
      chatsCubit.toggleCalendar();
      return;
    }

    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) {
      navigator?.pop();
    }
  }

  Widget _buildErrorBanner(CalendarState state) {
    return Container(
      margin: calendarPaddingXl,
      child: ErrorDisplay(
        error: state.error!,
        onRetry: () => _calendarBloc?.add(
          const CalendarEvent.errorCleared(),
        ),
        onDismiss: () => _calendarBloc?.add(
          const CalendarEvent.errorCleared(),
        ),
      ),
    );
  }

  Widget _buildLoadingOverlay(BuildContext context) {
    final colors = context.colorScheme;
    return Container(
      color: colors.background.withValues(alpha: 0.6),
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
    return SafeArea(
      top: false,
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
                buildDragEdgeTargets(),
              ],
            ),
          ),
          _buildMobileTabBar(
            context,
            highlightTasksTab: highlightTasksTab,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileTabBar(
    BuildContext context, {
    required bool highlightTasksTab,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double bottomInset =
        keyboardInset > 0 ? 0 : mediaQuery.viewPadding.bottom;
    final colors = context.colorScheme;
    final Widget tabBar = buildDragAwareTabBar(
      context: context,
      bottomInset: bottomInset,
      scheduleTabLabel: const Text('Schedule'),
      tasksTabLabel: _buildTasksTabLabel(highlightTasksTab),
    );
    final Widget cancelBucket = buildDragCancelBucket(
      context: context,
      bottomInset: bottomInset,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(
          top: BorderSide(color: colors.border),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          tabBar,
          cancelBucket,
        ],
      ),
    );
  }

  Widget _buildTasksTabLabel(bool highlight) {
    if (!highlight) {
      return const Text('Tasks');
    }
    return AnimatedBuilder(
      animation: _tasksTabPulse,
      builder: (context, _) {
        final colors = context.colorScheme;
        final double t = _tasksTabPulse.value;
        final double scale = 0.85 + (0.25 * t);
        final Color badgeColor = Color.lerp(
          colors.primary.withValues(alpha: 0.55),
          colors.primary,
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

  Widget _buildTabletLayout(CalendarState state) {
    final spec = ResponsiveHelper.spec(context);
    final EdgeInsets contentPadding = spec.contentPadding;
    final colors = context.colorScheme;
    final sidebarDimensions = ResponsiveHelper.sidebarDimensions(context);
    final double sidebarWidth = sidebarDimensions.defaultWidth;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            contentPadding.left,
            contentPadding.top,
            contentPadding.right,
            calendarGutterSm,
          ),
          child: CalendarNavigation(
            state: state,
            sidebarVisible: true,
            onDateSelected: (date) => _calendarBloc?.add(
              CalendarEvent.dateSelected(date: date),
            ),
            onViewChanged: (view) => _calendarBloc?.add(
              CalendarEvent.viewChanged(view: view),
            ),
            onErrorCleared: () => _calendarBloc?.add(
              const CalendarEvent.errorCleared(),
            ),
            onUndo: () => _calendarBloc?.add(
              const CalendarEvent.undoRequested(),
            ),
            onRedo: () => _calendarBloc?.add(
              const CalendarEvent.redoRequested(),
            ),
            canUndo: state.canUndo,
            canRedo: state.canRedo,
          ),
        ),
        if (state.error != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: contentPadding.left,
            ),
            child: _buildErrorBanner(state),
          ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              contentPadding.left,
              calendarGutterSm,
              contentPadding.right,
              contentPadding.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildCalendarGridWithHandlers(state),
                ),
                const SizedBox(width: calendarGutterLg),
                Container(
                  width: 1,
                  margin: const EdgeInsets.symmetric(
                    vertical: calendarGutterLg,
                  ),
                  color: colors.border,
                ),
                const SizedBox(width: calendarGutterLg),
                SizedBox(
                  width: sidebarWidth,
                  child: _buildSidebarWithProvider(),
                ),
              ],
            ),
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
                onDateSelected: (date) => _calendarBloc?.add(
                  CalendarEvent.dateSelected(date: date),
                ),
                onViewChanged: (view) => _calendarBloc?.add(
                  CalendarEvent.viewChanged(view: view),
                ),
                onErrorCleared: () =>
                    _calendarBloc?.add(const CalendarEvent.errorCleared()),
                onUndo: () =>
                    _calendarBloc?.add(const CalendarEvent.undoRequested()),
                onRedo: () =>
                    _calendarBloc?.add(const CalendarEvent.redoRequested()),
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
    final CalendarBloc? bloc = _calendarBloc;
    if (bloc == null) {
      return const SizedBox.shrink();
    }
    final sidebar = BlocProvider<BaseCalendarBloc>.value(
      value: bloc,
      child: TaskSidebar(
        key: _sidebarKey,
        onDragSessionStarted: handleGridDragSessionStarted,
        onDragSessionEnded: handleGridDragSessionEnded,
        onDragGlobalPositionChanged: handleGridDragPositionChanged,
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: sidebar);
    }

    return sidebar;
  }

  Widget _buildCalendarGridWithHandlers(CalendarState state) {
    final CalendarBloc? bloc = _calendarBloc;
    return CalendarGrid<CalendarBloc>(
      state: state,
      onEmptySlotTapped: _onEmptySlotTapped,
      onTaskDragEnd: _onTaskDragEnd,
      onDateSelected: (date) => bloc?.add(
        CalendarEvent.dateSelected(date: date),
      ),
      onViewChanged: (view) => bloc?.add(
        CalendarEvent.viewChanged(view: view),
      ),
      focusRequest: state.pendingFocus,
      onDragSessionStarted: _handleCalendarGridDragSessionStarted,
      onDragGlobalPositionChanged: _handleCalendarGridDragPositionChanged,
      onDragSessionEnded: _handleCalendarGridDragSessionEnded,
      cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
    );
  }

  void _handleCalendarGridDragSessionStarted() {
    handleGridDragSessionStarted();
    _sidebarKey.currentState?.handleExternalGridDragStarted(
      isTouchMode: !_hasMouseDevice,
    );
  }

  void _handleCalendarGridDragPositionChanged(Offset globalPosition) {
    handleGridDragPositionChanged(globalPosition);
    _sidebarKey.currentState?.handleExternalGridDragPosition(globalPosition);
  }

  void _handleCalendarGridDragSessionEnded() {
    handleGridDragSessionEnded();
    _sidebarKey.currentState?.handleExternalGridDragEnded();
  }

  void _onEmptySlotTapped(DateTime time, Offset position) {
    _showQuickAddModal(position, prefilledTime: time);
  }

  void _onTaskDragEnd(CalendarTask task, DateTime newTime) {
    final CalendarBloc? bloc = _calendarBloc;
    if (bloc == null) {
      return;
    }
    final CalendarTask normalized = task.normalizedForInteraction(newTime);
    bloc.commitTaskInteraction(normalized);
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    final LocationAutocompleteHelper helper = _calendarBloc != null
        ? LocationAutocompleteHelper.fromState(_calendarBloc!.state)
        : LocationAutocompleteHelper.fromSeeds(const <String>[]);
    showQuickAddModal(
      context: context,
      prefilledDateTime: prefilledTime,
      locationHelper: helper,
      onTaskAdded: (task) => _calendarBloc?.add(
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

  @override
  TabController get mobileTabController => _mobileTabController;

  @override
  bool get isDragSwitcherEnabled => _usesMobileLayout;

  @override
  void onCancelBucketHoverChanged(bool isHovering) {
    _cancelBucketHoverNotifier.value = isHovering;
  }

  @override
  void onDragCancelRequested(CalendarDragPayload payload) {
    final CalendarBloc? bloc = _calendarBloc;
    debugPrint(
      '[calendar] cancel drag task=${payload.task.id} '
      'pickup=${payload.pickupScheduledTime} '
      'snapshot=${payload.snapshot.scheduledTime} '
      'origin=${payload.originSlot}',
    );
    if (bloc != null) {
      final CalendarTask restored = restoreTaskFromPayload(payload);
      bloc.add(CalendarEvent.taskUpdated(task: restored));
      FeedbackSystem.showInfo(context, 'Drag canceled');
    }
  }
}
