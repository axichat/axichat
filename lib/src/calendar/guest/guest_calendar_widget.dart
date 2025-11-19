import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/responsive_helper.dart';
import '../view/calendar_navigation.dart';
import '../view/feedback_system.dart';
import '../view/quick_add_modal.dart';
import 'guest_calendar_bloc.dart';
import '../view/widgets/calendar_drag_tab_mixin.dart';
import '../view/widgets/calendar_grid_host.dart';
import '../view/widgets/calendar_error_banner.dart';
import '../view/widgets/calendar_keyboard_scope.dart';
import '../view/widgets/calendar_loading_overlay.dart';
import '../view/widgets/calendar_mobile_tab_shell.dart';
import '../view/widgets/calendar_scaffolds.dart';
import '../view/widgets/calendar_sidebar_host.dart';
import '../view/widgets/calendar_task_feedback_observer.dart';
import '../view/widgets/task_form_section.dart';
import '../view/models/calendar_drag_payload.dart';
import '../view/task_sidebar.dart';

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
  GuestCalendarBloc? _calendarBloc;
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
    _calendarBloc ??= context.read<GuestCalendarBloc>();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GuestCalendarBloc, CalendarState>(
      listener: _handleStateChanges,
      builder: (context, state) {
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
        final bool usesDesktopLayout =
            _shouldUseDesktopLayout(layoutClass, mediaQuery);
        _usesMobileLayout = !usesDesktopLayout;
        final bool highlightTasksTab = !usesDesktopLayout &&
            state.isSelectionMode &&
            _mobileTabController.index != 1;
        final EdgeInsets contentPadding = spec.contentPadding;
        final Widget navigation = Padding(
          padding: contentPadding,
          child: CalendarNavigation(
            state: state,
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
        );
        final Widget? errorBanner = state.error == null
            ? null
            : CalendarErrorBanner(
                margin: spec.modalMargin,
                error: state.error!,
                onRetry: () => _calendarBloc?.add(
                  const CalendarEvent.errorCleared(),
                ),
                onDismiss: () => _calendarBloc?.add(
                  const CalendarEvent.errorCleared(),
                ),
              );
        final Widget sidebar = CalendarSidebarHost<GuestCalendarBloc>(
          bloc: _calendarBloc,
          sidebarKey: _sidebarKey,
          onDragSessionStarted: handleGridDragSessionStarted,
          onDragSessionEnded: handleGridDragSessionEnded,
          onDragGlobalPositionChanged: handleGridDragPositionChanged,
        );
        final Widget calendarGrid = CalendarGridHost<GuestCalendarBloc>(
          bloc: _calendarBloc,
          state: state,
          onEmptySlotTapped: _onEmptySlotTapped,
          onTaskDragEnd: _onTaskDragEnd,
          onDragSessionStarted: _handleCalendarGridDragSessionStarted,
          onDragGlobalPositionChanged: _handleCalendarGridDragPositionChanged,
          onDragSessionEnded: _handleCalendarGridDragSessionEnded,
          cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
        );
        final Widget dragTargets = buildDragEdgeTargets();
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final double bottomInset =
            keyboardInset > 0 ? 0 : mediaQuery.viewPadding.bottom;
        final Widget tasksTabLabel = TasksTabLabel(
          highlight: highlightTasksTab,
          animation: _tasksTabPulse,
          baseColor: calendarPrimaryColor,
        );
        final Widget tabSwitcher = buildDragAwareTabBar(
          context: context,
          bottomInset: bottomInset,
          scheduleTabLabel: const Text('Schedule'),
          tasksTabLabel: tasksTabLabel,
        );
        final Widget cancelBucket = buildDragCancelBucket(
          context: context,
          bottomInset: bottomInset,
        );
        final ThemeData theme = Theme.of(context);
        final ColorScheme colors = theme.colorScheme;
        final Widget mobileTabBar = CalendarMobileTabShell(
          tabBar: tabSwitcher,
          cancelBucket: cancelBucket,
          backgroundColor: colors.surface,
          borderColor: theme.dividerColor,
        );
        final Widget activeLayout = usesDesktopLayout
            ? CalendarDesktopSplitScaffold(
                topHeader: null,
                bodyHeader: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    navigation,
                    if (errorBanner != null) errorBanner,
                  ],
                ),
                sidebar: sidebar,
                content: calendarGrid,
              )
            : CalendarMobileSplitScaffold(
                tabController: _mobileTabController,
                primaryPane: calendarGrid,
                secondaryPane: sidebar,
                dragOverlay: dragTargets,
                tabBar: mobileTabBar,
                headerBuilder: (context, showingPrimary) {
                  final children = <Widget>[];
                  if (showingPrimary) {
                    children.add(navigation);
                  }
                  if (errorBanner != null) {
                    children.add(errorBanner);
                  }
                  if (children.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  );
                },
              );
        _updateTasksTabPulse(highlightTasksTab);
        final Color surfaceColor = _calendarSurfaceColor(context);
        final bool shouldResizeForKeyboard = usesDesktopLayout;
        return SizedBox.expand(
          child: ColoredBox(
            color: surfaceColor,
            child: CalendarKeyboardScope(
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
              child: CalendarTaskFeedbackObserver<GuestCalendarBloc>(
                child: Scaffold(
                  backgroundColor: surfaceColor,
                  resizeToAvoidBottomInset: shouldResizeForKeyboard,
                  body: Stack(
                    children: [
                      SafeArea(
                        top: true,
                        bottom: false,
                        child: Column(
                          children: [
                            _GuestBanner(
                              onNavigateBack: _handleBannerBackNavigation,
                              onSignUp: () => context.go('/login'),
                            ),
                            Expanded(child: activeLayout),
                          ],
                        ),
                      ),
                      if (state.isLoading)
                        CalendarLoadingOverlay(
                          color: Colors.black.withValues(alpha: 0.3),
                        ),
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

  Color _calendarSurfaceColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : calendarSidebarBackgroundColor;
  }

  bool _shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  ) {
    final bool desktopPlatform = switch (defaultTargetPlatform) {
      TargetPlatform.macOS => true,
      TargetPlatform.windows => true,
      TargetPlatform.linux => true,
      TargetPlatform.fuchsia => true,
      TargetPlatform.android => false,
      TargetPlatform.iOS => false,
    };
    if (!desktopPlatform) {
      return false;
    }
    if (sizeClass != CalendarSizeClass.expanded) {
      return false;
    }
    return mediaQuery.size.width >= largeScreen;
  }

  void _handleStateChanges(BuildContext context, CalendarState state) {
    // Handle errors (no sync errors in guest mode)
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
  }

  Future<void> _handleBannerBackNavigation() async {
    final navigator =
        GoRouter.of(context).routerDelegate.navigatorKey.currentState;
    if (navigator != null && await navigator.maybePop()) {
      return;
    }
    if (!mounted) {
      return;
    }
    context.go('/login');
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
    final GuestCalendarBloc? bloc = _calendarBloc;
    if (bloc == null) {
      return;
    }
    final CalendarTask normalized = task.normalizedForInteraction(newTime);
    bloc.commitTaskInteraction(normalized);
  }

  void _showQuickAddModal(Offset position, {required DateTime prefilledTime}) {
    final GuestCalendarBloc? bloc = _calendarBloc;
    if (bloc == null) {
      return;
    }
    final LocationAutocompleteHelper helper =
        LocationAutocompleteHelper.fromState(bloc.state);
    showQuickAddModal(
      context: context,
      prefilledDateTime: prefilledTime,
      locationHelper: helper,
      onTaskAdded: (task) => bloc.add(
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

  @override
  void onCancelBucketHoverChanged(bool isHovering) {
    _cancelBucketHoverNotifier.value = isHovering;
  }

  @override
  void onDragCancelRequested(CalendarDragPayload payload) {
    final GuestCalendarBloc? bloc = _calendarBloc;
    debugPrint(
      '[guest-calendar] cancel drag task=${payload.task.id} '
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

class _GuestBanner extends StatelessWidget {
  const _GuestBanner({
    required this.onNavigateBack,
    required this.onSignUp,
  });

  final Future<void> Function() onNavigateBack;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final responsive = ResponsiveHelper.spec(context);
    final EdgeInsets basePadding = responsive.contentPadding;
    final EdgeInsets bannerPadding = EdgeInsets.fromLTRB(
      basePadding.left,
      calendarGutterMd,
      basePadding.right,
      calendarGutterMd,
    );
    final accent = calendarPrimaryColor;
    return Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.04),
        border: const Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      padding: bannerPadding,
      child: Row(
        children: [
          AxiIconButton(
            iconData: Icons.arrow_back,
            tooltip: 'Back to login',
            onPressed: () {
              onNavigateBack();
            },
          ),
          const SizedBox(width: calendarGutterMd),
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: accent,
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
            onPressed: onSignUp,
            icon: Icons.login,
          ),
        ],
      ),
    );
  }
}
