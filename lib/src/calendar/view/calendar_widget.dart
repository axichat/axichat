import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/responsive_helper.dart';
import 'calendar_navigation.dart';
import 'feedback_system.dart';
import 'models/calendar_drag_payload.dart';
import 'quick_add_modal.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_drag_tab_mixin.dart';
import 'widgets/calendar_error_banner.dart';
import 'widgets/calendar_grid_host.dart';
import 'widgets/calendar_keyboard_scope.dart';
import 'widgets/calendar_loading_overlay.dart';
import 'widgets/calendar_mobile_tab_shell.dart';
import 'widgets/calendar_scaffolds.dart';
import 'widgets/calendar_sidebar_host.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class CalendarNavSurface extends StatelessWidget {
  const CalendarNavSurface({super.key, required this.child});

  final Widget child;

  static Color backgroundColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.surface
        : calendarSidebarBackgroundColor;
  }

  @override
  Widget build(BuildContext context) {
    final Color color = backgroundColor(context);
    return ColoredBox(
      color: color,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}

class _CalendarWidgetState extends State<CalendarWidget>
    with TickerProviderStateMixin, CalendarDragTabMixin {
  late final TabController _mobileTabController;
  late final AnimationController _tasksTabPulseController;
  late final Animation<double> _tasksTabPulse;
  bool _usesMobileLayout = false;
  bool _mobileInitialScrollSynced = false;
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
        final Color calendarBackground =
            CalendarNavSurface.backgroundColor(context);
        final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
        final CalendarBloc? bloc = _calendarBloc;
        final bool usesDesktopLayout = _shouldUseDesktopLayout(spec);
        _usesMobileLayout = !usesDesktopLayout;
        if (usesDesktopLayout && _mobileInitialScrollSynced) {
          _mobileInitialScrollSynced = false;
        }
        _maybeSyncMobileInitialScroll(state);
        final bool highlightTasksTab = !usesDesktopLayout &&
            state.isSelectionMode &&
            _mobileTabController.index != 1;
        final Widget sidebar = CalendarSidebarHost<CalendarBloc>(
          bloc: bloc,
          sidebarKey: _sidebarKey,
          onDragSessionStarted: handleGridDragSessionStarted,
          onDragSessionEnded: handleGridDragSessionEnded,
          onDragGlobalPositionChanged: handleGridDragPositionChanged,
        );
        final Widget calendarGrid = CalendarGridHost<CalendarBloc>(
          bloc: bloc,
          state: state,
          onEmptySlotTapped: _onEmptySlotTapped,
          onTaskDragEnd: _onTaskDragEnd,
          onDragSessionStarted: _handleCalendarGridDragSessionStarted,
          onDragSessionEnded: _handleCalendarGridDragSessionEnded,
          onDragGlobalPositionChanged: _handleCalendarGridDragPositionChanged,
          cancelBucketHoverNotifier: _cancelBucketHoverNotifier,
        );
        final MediaQueryData mediaQuery = MediaQuery.of(context);
        final double keyboardInset = mediaQuery.viewInsets.bottom;
        final double bottomInset =
            keyboardInset > 0 ? 0 : mediaQuery.viewPadding.bottom;
        final Widget tabBar = buildDragAwareTabBar(
          context: context,
          bottomInset: bottomInset,
          scheduleTabLabel: const Text('Schedule'),
          tasksTabLabel: TasksTabLabel(
            highlight: highlightTasksTab,
            animation: _tasksTabPulse,
          ),
        );
        final Widget cancelBucket = buildDragCancelBucket(
          context: context,
          bottomInset: bottomInset,
        );
        final Widget mobileTabBar = CalendarMobileTabShell(
          tabBar: tabBar,
          cancelBucket: cancelBucket,
          backgroundColor: colors.background,
          borderColor: colors.border,
          dividerColor: colors.border,
          showTopBorder: false,
          showDivider: true,
        );
        final Widget dragEdgeTargets = buildDragEdgeTargets();
        final Widget? errorBanner = state.error == null
            ? null
            : CalendarErrorBanner(
                error: state.error!,
                onRetry: () => bloc?.add(const CalendarEvent.errorCleared()),
                onDismiss: () => bloc?.add(const CalendarEvent.errorCleared()),
              );
        final Widget navigation = CalendarNavigation(
          state: state,
          sidebarVisible: usesDesktopLayout,
          onDateSelected: (date) => bloc?.add(
            CalendarEvent.dateSelected(date: date),
          ),
          onViewChanged: (view) => bloc?.add(
            CalendarEvent.viewChanged(view: view),
          ),
          onErrorCleared: () => bloc?.add(const CalendarEvent.errorCleared()),
          onUndo: () => bloc?.add(const CalendarEvent.undoRequested()),
          onRedo: () => bloc?.add(const CalendarEvent.redoRequested()),
          canUndo: state.canUndo,
          canRedo: state.canRedo,
        );
        final Widget layout = usesDesktopLayout
            ? CalendarDesktopSplitScaffold(
                topHeader: _CalendarSurfaceTint(
                  child: CalendarNavSurface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        navigation,
                        const SizedBox(height: calendarGutterSm),
                      ],
                    ),
                  ),
                ),
                bodyHeader: errorBanner,
                sidebar: sidebar,
                content: calendarGrid,
              )
            : CalendarMobileSplitScaffold(
                tabController: _mobileTabController,
                primaryPane: calendarGrid,
                secondaryPane: sidebar,
                dragOverlay: dragEdgeTargets,
                tabBar: mobileTabBar,
                safeAreaTop: false,
                safeAreaBottom: false,
                headerBuilder: (context, showingPrimary) {
                  final headerChildren = <Widget>[];
                  if (showingPrimary) {
                    Widget navContent = navigation;
                    navContent = CalendarNavSurface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          navContent,
                          if (errorBanner != null) errorBanner,
                        ],
                      ),
                    );
                    headerChildren.add(
                      _CalendarSurfaceTint(child: navContent),
                    );
                  } else if (errorBanner != null) {
                    headerChildren.add(errorBanner);
                  }
                  if (headerChildren.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: headerChildren,
                  );
                },
              );
        final Widget tintedLayout = _CalendarSurfaceTint(child: layout);
        _updateTasksTabPulse(highlightTasksTab);
        final bool shouldResizeForKeyboard = usesDesktopLayout;

        return SizedBox.expand(
          child: ColoredBox(
            color: calendarBackground,
            child: CalendarKeyboardScope(
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
                backgroundColor: calendarBackground,
                resizeToAvoidBottomInset: shouldResizeForKeyboard,
                body: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CalendarAppBar(
                          state: state,
                          onBackPressed: _handleCalendarBackPressed,
                        ),
                        Divider(
                          height: 1,
                          color: colors.border,
                        ),
                        Expanded(child: tintedLayout),
                      ],
                    ),
                    if (state.isLoading) const CalendarLoadingOverlay(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _maybeSyncMobileInitialScroll(CalendarState state) {
    if (!_usesMobileLayout || _mobileInitialScrollSynced) {
      return;
    }
    _mobileInitialScrollSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calendarBloc?.add(
        CalendarEvent.dateSelected(
          date: DateTime.now(),
        ),
      );
    });
  }

  void _handleStateChanges(BuildContext context, CalendarState state) {
    // Handle errors
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
  }

  void _handleCalendarBackPressed() {
    final chatsCubit = context.read<ChatsCubit?>();
    if (chatsCubit != null && chatsCubit.state.openCalendar) {
      chatsCubit.toggleCalendar();
      return;
    }

    final router = GoRouter.maybeOf(context);
    if (router != null) {
      if (router.canPop()) {
        router.pop();
      } else {
        router.go('/');
      }
      return;
    }

    final navigator = Navigator.maybeOf(context);
    if (navigator?.canPop() ?? false) {
      navigator?.pop();
    }
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

  bool _shouldUseDesktopLayout(CalendarResponsiveSpec spec) {
    if (!_isDesktopPlatform) {
      return false;
    }
    return spec.sizeClass == CalendarSizeClass.expanded;
  }

  bool get _isDesktopPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return false;
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

class _CalendarAppBar extends StatelessWidget {
  const _CalendarAppBar({
    required this.state,
    required this.onBackPressed,
  });

  final CalendarState state;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color background = CalendarNavSurface.backgroundColor(context);
    return Material(
      color: background,
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
                onPressed: onBackPressed,
              ),
              const SizedBox(width: calendarGutterMd),
              Expanded(
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
}

class _CalendarSurfaceTint extends StatelessWidget {
  const _CalendarSurfaceTint({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final color = CalendarNavSurface.backgroundColor(context);
    return ColoredBox(
      color: color,
      child: SizedBox(width: double.infinity, child: child),
    );
  }
}
