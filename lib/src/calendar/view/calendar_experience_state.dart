// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'calendar_navigation.dart';
import 'feedback_system.dart';
import 'models/calendar_drag_payload.dart';
import 'quick_add_modal.dart';
import 'widgets/calendar_drag_tab_mixin.dart';
import 'widgets/calendar_error_banner.dart';
import 'widgets/calendar_grid_host.dart';
import 'widgets/calendar_keyboard_scope.dart';
import 'widgets/calendar_loading_overlay.dart';
import 'widgets/calendar_mobile_tab_shell.dart';
import 'widgets/calendar_month_host.dart';
import 'widgets/calendar_scaffolds.dart';
import 'widgets/calendar_sidebar_host.dart';
import 'task_sidebar.dart';

/// Base [State] used by both the authenticated and guest calendar surfaces to
/// host the shared drag/tab interactions, sidebars, and layout switching.
abstract class CalendarExperienceState<W extends StatefulWidget,
        B extends BaseCalendarBloc> extends State<W>
    with TickerProviderStateMixin, CalendarDragTabMixin {
  late final TabController _mobileTabController;
  late final AnimationController _tasksTabPulseController;
  late final Animation<double> _tasksTabPulse;
  bool _usesMobileLayout = false;
  final GlobalKey<TaskSidebarState<B>> _sidebarKey =
      GlobalKey<TaskSidebarState<B>>();
  final ValueNotifier<bool> _cancelBucketHoverNotifier =
      ValueNotifier<bool>(false);

  bool get _hasMouseDevice =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  @protected
  B get calendarBloc => context.read<B>();

  @protected
  GlobalKey<TaskSidebarState<B>> get sidebarKey => _sidebarKey;

  @protected
  ValueNotifier<bool> get cancelBucketHoverNotifier =>
      _cancelBucketHoverNotifier;

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
  Widget build(BuildContext context) {
    return BlocConsumer<B, CalendarState>(
      listener: handleStateChanges,
      builder: (context, state) {
        final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final CalendarSizeClass sizeClass =
            resolveLayoutSizeClass(spec, mediaQuery);
        final bool usesDesktopLayout =
            shouldUseDesktopLayout(sizeClass, mediaQuery);
        _usesMobileLayout = !usesDesktopLayout;
        onLayoutModeResolved(state, usesDesktopLayout);

        final bool highlightTasksTab = !usesDesktopLayout &&
            state.isSelectionMode &&
            _mobileTabController.index != 1;

        final Widget navigation =
            buildNavigation(context, state, spec, usesDesktopLayout);
        final Widget? errorBanner =
            buildErrorBanner(context, state, spec, usesDesktopLayout);
        final Widget sidebar = CalendarSidebarHost<B>(
          sidebarKey: _sidebarKey,
          onDragSessionStarted: handleGridDragSessionStarted,
          onDragSessionEnded: handleGridDragSessionEnded,
          onDragGlobalPositionChanged: handleGridDragPositionChanged,
        );
        final bool isMonthView = state.viewMode == CalendarView.month;
        final Widget calendarSurface = isMonthView
            ? CalendarMonthHost<B>(
                state: state,
              )
            : CalendarGridHost<B>(
                state: state,
                onEmptySlotTapped: _onEmptySlotTapped,
                onTaskDragEnd: _onTaskDragEnd,
                onDragSessionStarted: _handleCalendarGridDragSessionStarted,
                onDragGlobalPositionChanged:
                    _handleCalendarGridDragPositionChanged,
                onDragSessionEnded: _handleCalendarGridDragSessionEnded,
                cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
              );
        final Widget dragTargets =
            isMonthView ? const SizedBox.shrink() : buildDragEdgeTargets();
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final double bottomInset =
            keyboardInset > 0 ? 0 : mediaQuery.viewPadding.bottom;
        final Widget tabSwitcher = buildDragAwareTabBar(
          context: context,
          bottomInset: bottomInset,
          scheduleTabLabel: buildScheduleTabLabel(context),
          tasksTabLabel: buildTasksTabLabel(
            context,
            highlightTasksTab,
            _tasksTabPulse,
          ),
        );
        final Widget cancelBucket = buildDragCancelBucket(
          context: context,
          bottomInset: bottomInset,
        );
        final Widget mobileTabShell = buildMobileTabShell(
          context,
          tabSwitcher,
          cancelBucket,
        );
        final Widget layout = _buildLayout(
          usesDesktopLayout: usesDesktopLayout,
          navigation: navigation,
          errorBanner: errorBanner,
          sidebar: sidebar,
          calendarGrid: calendarSurface,
          dragOverlay: dragTargets,
          mobileTabShell: mobileTabShell,
        );
        _updateTasksTabPulse(highlightTasksTab);
        final Color surfaceColor = resolveSurfaceColor(context);
        final bool resizeForKeyboard =
            shouldResizeForKeyboard(usesDesktopLayout);

        return SizedBox.expand(
          child: ColoredBox(
            color: surfaceColor,
            child: CalendarKeyboardScope(
              autofocus: true,
              canUndo: state.canUndo,
              canRedo: state.canRedo,
              onUndo: () =>
                  context.read<B>().add(const CalendarEvent.undoRequested()),
              onRedo: () =>
                  context.read<B>().add(const CalendarEvent.redoRequested()),
              onNavigatePrevious: () => _handleKeyboardNavigate(state, -1),
              onNavigateNext: () => _handleKeyboardNavigate(state, 1),
              onJumpToToday: () => _handleKeyboardJumpToToday(state),
              onCancelDrag: isAnyDragActive ? _handleKeyboardCancelDrag : null,
              child: wrapWithTaskFeedback(
                context,
                Scaffold(
                  backgroundColor: surfaceColor,
                  resizeToAvoidBottomInset: resizeForKeyboard,
                  body: Stack(
                    children: [
                      buildScaffoldBody(
                        context,
                        state,
                        usesDesktopLayout,
                        layout,
                      ),
                      if (shouldShowLoadingOverlay(state))
                        buildLoadingOverlay(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLayout({
    required bool usesDesktopLayout,
    required Widget navigation,
    required Widget? errorBanner,
    required Widget sidebar,
    required Widget calendarGrid,
    required Widget dragOverlay,
    required Widget mobileTabShell,
  }) {
    if (usesDesktopLayout) {
      return CalendarDesktopSplitScaffold(
        topHeader: buildDesktopTopHeader(navigation, errorBanner),
        bodyHeader: buildDesktopBodyHeader(navigation, errorBanner),
        sidebar: sidebar,
        content: calendarGrid,
      );
    }
    return CalendarMobileSplitScaffold(
      tabController: _mobileTabController,
      primaryPane: calendarGrid,
      secondaryPane: sidebar,
      dragOverlay: dragOverlay,
      tabBar: mobileTabShell,
      safeAreaTop: useMobileSafeAreaTop,
      safeAreaBottom: useMobileSafeAreaBottom,
      headerBuilder: (context, showingPrimary) => buildMobileHeader(
        context,
        showingPrimary,
        navigation,
        errorBanner,
      ),
    );
  }

  void _onEmptySlotTapped(DateTime time, Offset position) {
    _showQuickAddModal(position, prefilledTime: time);
  }

  void _onTaskDragEnd(CalendarTask task, DateTime newTime) {
    final CalendarTask normalized = task.normalizedForInteraction(newTime);
    calendarBloc.commitTaskInteraction(normalized);
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    final LocationAutocompleteHelper helper =
        LocationAutocompleteHelper.fromState(calendarBloc.state);
    final locate = context.read;
    showQuickAddModal(
      context: context,
      prefilledDateTime: prefilledTime,
      locationHelper: helper,
      calendarBloc: calendarBloc,
      locate: locate,
      onTaskAdded: (task) => calendarBloc.add(
        CalendarEvent.taskAdded(
          title: task.title,
          scheduledTime: task.scheduledTime,
          description: task.description,
          duration: task.duration,
          deadline: task.deadline,
          location: task.location,
          priority: task.priority ?? TaskPriority.none,
          recurrence: task.recurrence,
          checklist: task.checklist,
          endDate: task.endDate,
          reminders: task.reminders,
          icsMeta: task.icsMeta,
        ),
      ),
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

  void _handleKeyboardCancelDrag() {
    handleKeyboardCancelBucket();
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
    debugPrint(
      '[$dragLogTag] cancel drag task=${payload.task.id} '
      'pickup=${payload.pickupScheduledTime} '
      'snapshot=${payload.snapshot.scheduledTime} '
      'origin=${payload.originSlot}',
    );
    final CalendarTask restored = restoreTaskFromPayload(payload);
    calendarBloc.add(CalendarEvent.taskUpdated(task: restored));
    FeedbackSystem.showInfo(context, 'Drag canceled');
  }

  @override
  void onDragDayShiftRequested(int deltaDays) {
    final DateTime selected = calendarBloc.state.selectedDate;
    calendarBloc.add(
      CalendarEvent.dateSelected(
        date: selected.add(Duration(days: deltaDays)),
      ),
    );
  }

  /// Hook for subclasses to react to bloc state changes.
  void handleStateChanges(BuildContext context, CalendarState state);

  /// Allows subclasses to react whenever the responsive layout switches.
  void onLayoutModeResolved(CalendarState state, bool usesDesktopLayout) {}

  /// Builds the navigation header. Subclasses can wrap the base navigation in
  /// additional chrome (padding, background, etc.).
  @protected
  Widget buildNavigation(
    BuildContext context,
    CalendarState state,
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) {
    final VoidCallback? searchAction =
        buildNavigationSearchAction(context, state, usesDesktopLayout);
    final CalendarChatAcl? chatAcl = buildNavigationChatAcl(state);
    final String? chatTitle = buildNavigationChatTitle(state);
    final Widget base = CalendarNavigation(
      state: state,
      sidebarVisible: usesDesktopLayout,
      onDateSelected: (date) => calendarBloc.add(
        CalendarEvent.dateSelected(date: date),
      ),
      onViewChanged: (view) => calendarBloc.add(
        CalendarEvent.viewChanged(view: view),
      ),
      onErrorCleared: () =>
          calendarBloc.add(const CalendarEvent.errorCleared()),
      onUndo: () => calendarBloc.add(const CalendarEvent.undoRequested()),
      onRedo: () => calendarBloc.add(const CalendarEvent.redoRequested()),
      canUndo: state.canUndo,
      canRedo: state.canRedo,
      hideCompletedScheduled:
          context.watch<SettingsCubit>().state.hideCompletedScheduled,
      onToggleHideCompletedScheduled: (hide) =>
          context.read<SettingsCubit>().toggleHideCompletedScheduled(hide),
      onSearchRequested: searchAction,
      chatAcl: chatAcl,
      chatTitle: chatTitle,
    );
    final EdgeInsets? padding = navigationPadding(spec, usesDesktopLayout);
    if (padding == null) {
      return base;
    }
    return Padding(padding: padding, child: base);
  }

  /// Margins for the navigation wrapper, allowing guest mode to provide layout
  /// spacing.
  EdgeInsets? navigationPadding(
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) =>
      null;

  @protected
  CalendarChatAcl? buildNavigationChatAcl(CalendarState state) => null;

  @protected
  String? buildNavigationChatTitle(CalendarState state) => null;

  @protected
  VoidCallback? buildNavigationSearchAction(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) =>
      null;

  /// Builds the error banner shown above the content, if any.
  Widget? buildErrorBanner(
    BuildContext context,
    CalendarState state,
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) {
    if (state.error == null) {
      return null;
    }
    return CalendarErrorBanner(
      margin: errorBannerMargin(spec, usesDesktopLayout),
      error: state.error!,
      onRetry: () => calendarBloc.add(const CalendarEvent.errorCleared()),
      onDismiss: () => calendarBloc.add(const CalendarEvent.errorCleared()),
    );
  }

  EdgeInsets? errorBannerMargin(
    CalendarResponsiveSpec spec,
    bool usesDesktopLayout,
  ) =>
      null;

  /// Builds the tab label for the schedule pane. Subclasses can override to
  /// customize text/style.
  Widget buildScheduleTabLabel(BuildContext context) =>
      Text(context.l10n.calendarScheduleLabel);

  /// Builds the tasks tab label so guests can tint it differently.
  Widget buildTasksTabLabel(
    BuildContext context,
    bool highlight,
    Animation<double> animation,
  ) {
    return TasksTabLabel(
      highlight: highlight,
      animation: animation,
    );
  }

  /// Wraps the tab/cancel bucket chrome for mobile layouts.
  CalendarMobileTabShell buildMobileTabShell(
    BuildContext context,
    Widget tabSwitcher,
    Widget cancelBucket,
  );

  /// Optional top header displayed above the desktop layout.
  Widget? buildDesktopTopHeader(Widget navigation, Widget? errorBanner);

  /// Optional header inserted between the desktop chrome and the calendar grid.
  Widget? buildDesktopBodyHeader(Widget navigation, Widget? errorBanner);

  /// Header builder for the mobile split scaffold.
  Widget buildMobileHeader(
    BuildContext context,
    bool showingPrimary,
    Widget navigation,
    Widget? errorBanner,
  );

  /// Builds the body placed underneath the Stack inside the Scaffold.
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  );

  /// Allows subclasses to provide loading overlays with custom tinting.
  Widget buildLoadingOverlay(BuildContext context) =>
      const CalendarLoadingOverlay();

  /// Only show the blocking overlay when the calendar is empty and bootstrapping.
  bool shouldShowLoadingOverlay(CalendarState state) =>
      state.isLoading &&
      state.model.tasks.isEmpty &&
      state.model.dayEvents.isEmpty;

  /// Wraps the Scaffold with additional chrome (like task feedback observers).
  Widget wrapWithTaskFeedback(BuildContext context, Widget child) => child;

  /// Background color for the scaffold + keyboard scope.
  Color resolveSurfaceColor(BuildContext context);

  /// Whether the scaffold should resize when the keyboard is shown.
  bool shouldResizeForKeyboard(bool usesDesktopLayout) => usesDesktopLayout;

  /// Whether the mobile split scaffold should respect top safe area insets.
  bool get useMobileSafeAreaTop => false;

  /// Whether the mobile split scaffold should respect bottom safe area insets.
  bool get useMobileSafeAreaBottom => false;

  /// Used in drag cancel logging to distinguish surfaces.
  String get dragLogTag;

  /// Computes whether desktop layout should be used for the given size class.
  bool shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  );

  /// Allows guests to adapt the resolved size class for landscape phones.
  CalendarSizeClass resolveLayoutSizeClass(
    CalendarResponsiveSpec spec,
    MediaQueryData mediaQuery,
  ) =>
      _resolveSizeClass(spec, mediaQuery);

  CalendarSizeClass _resolveSizeClass(
    CalendarResponsiveSpec spec,
    MediaQueryData mediaQuery,
  ) {
    final CalendarSizeClass base = spec.sizeClass;
    final bool landscapeCompactDevice =
        mediaQuery.orientation == Orientation.landscape &&
            mediaQuery.size.shortestSide < compactDeviceBreakpoint;
    if (landscapeCompactDevice && base == CalendarSizeClass.expanded) {
      return CalendarSizeClass.medium;
    }
    return base;
  }

  void _handleKeyboardNavigate(CalendarState state, int steps) {
    final DateTime nextDate = _shiftedDate(state, steps);
    calendarBloc.add(CalendarEvent.dateSelected(date: nextDate));
  }

  void _handleKeyboardJumpToToday(CalendarState state) {
    calendarBloc.add(
      CalendarEvent.dateSelected(date: DateTime.now()),
    );
  }

  DateTime _shiftedDate(CalendarState state, int steps) {
    final DateTime base = state.selectedDate;
    switch (state.viewMode) {
      case CalendarView.day:
        return base.add(Duration(days: steps));
      case CalendarView.week:
        return base.add(Duration(days: 7 * steps));
      case CalendarView.month:
        final DateTime targetMonth = DateTime(base.year, base.month + steps, 1);
        final int maxDay =
            DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        final int clampedDay = base.day.clamp(1, maxDay).toInt();
        return DateTime(targetMonth.year, targetMonth.month, clampedDay);
    }
  }
}
