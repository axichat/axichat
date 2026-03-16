// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/shell/calendar_task_search.dart';
import 'calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/shell/feedback_system.dart';
import 'sync_controls.dart';
import 'package:axichat/src/calendar/view/sidebar/task_sidebar.dart';
import 'package:axichat/src/calendar/view/grid/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/shell/calendar_mobile_tab_shell.dart';

@immutable
class CalendarBottomDragSession {
  const CalendarBottomDragSession({this.pointer, this.sourceTab});

  final Offset? pointer;
  final int? sourceTab;
}

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({
    super.key,
    this.mobileTabIndex,
    this.surfacePopEnabled = true,
    this.onMobileTabIndexChanged,
    this.bottomDragSession,
  });

  final int? mobileTabIndex;
  final bool surfacePopEnabled;
  final ValueChanged<int>? onMobileTabIndexChanged;
  final ValueNotifier<CalendarBottomDragSession?>? bottomDragSession;

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class CalendarNavSurface extends StatelessWidget {
  const CalendarNavSurface({super.key, required this.child});

  final Widget child;

  static Color backgroundColor(BuildContext context) {
    final scheme = context.colorScheme;
    return context.brightness == Brightness.dark
        ? scheme.card
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

const String _calendarSurfacePageId = 'calendar-surface';
const ValueKey<String> _calendarSurfacePageKey = ValueKey<String>(
  _calendarSurfacePageId,
);
const bool _calendarSurfacePopEnabledDefault = true;

class _CalendarWidgetState
    extends CalendarExperienceState<CalendarWidget, CalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey _calendarModalAnchorKey = GlobalKey(
    debugLabel: 'calendar-modal-anchor',
  );
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    mobileTabController.addListener(_handleMobileTabIndexChanged);
    _syncMobileTabController(animate: false);
  }

  @override
  void didUpdateWidget(covariant CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMobileTabController(animate: true);
  }

  @override
  void dispose() {
    _clearHomeBottomDragState();
    mobileTabController.removeListener(_handleMobileTabIndexChanged);
    _hoverTitleController.dispose();
    super.dispose();
  }

  void _clearHomeBottomDragState() {
    final notifier = widget.bottomDragSession;
    if (notifier?.value != null) {
      notifier!.value = null;
    }
  }

  void _handleMobileTabIndexChanged() {
    if (mobileTabController.indexIsChanging) {
      return;
    }
    widget.onMobileTabIndexChanged?.call(mobileTabController.index);
  }

  void _syncMobileTabController({required bool animate}) {
    final targetIndex = widget.mobileTabIndex;
    if (targetIndex == null) {
      return;
    }
    final int resolved = targetIndex.clamp(0, mobileTabController.length - 1);
    if (mobileTabController.index == resolved) {
      return;
    }
    if (animate) {
      mobileTabController.animateTo(resolved);
      return;
    }
    mobileTabController.index = resolved;
  }

  @override
  void handleStateChanges(BuildContext context, CalendarState state) {
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
    final warning = state.syncWarning;
    if (warning != null && mounted) {
      final l10n = context.l10n;
      final (String title, String message) = switch (warning.type) {
        CalendarSyncWarningType.snapshotUnavailable => (
          l10n.calendarSyncWarningSnapshotTitle,
          l10n.calendarSyncWarningSnapshotMessage,
        ),
      };
      FeedbackSystem.showWarning(context, message, title: title);
      calendarBloc.add(const CalendarEvent.syncWarningCleared());
    }
  }

  @override
  void onCalendarDragSessionStarted() {
    final notifier = widget.bottomDragSession;
    if (notifier != null) {
      notifier.value = CalendarBottomDragSession(
        sourceTab: _resolvedBottomDragSourceTab(),
      );
    }
  }

  @override
  void onCalendarDragPositionChanged(Offset globalPosition) {
    final notifier = widget.bottomDragSession;
    if (notifier != null) {
      notifier.value = CalendarBottomDragSession(
        pointer: globalPosition,
        sourceTab: _resolvedBottomDragSourceTab(),
      );
    }
  }

  @override
  void onCalendarDragSessionEnded() {
    _clearHomeBottomDragState();
  }

  int _resolvedBottomDragSourceTab() {
    return mobileTabController.index.clamp(0, 1);
  }

  @override
  BuildContext get calendarModalContext {
    return _calendarModalAnchorKey.currentContext ??
        _calendarNavigatorKey.currentState?.overlay?.context ??
        _calendarNavigatorKey.currentContext ??
        context;
  }

  @override
  void onLayoutModeResolved(CalendarState state, bool usesDesktopLayout) {
    if (usesDesktopLayout && _mobileInitialScrollSynced) {
      _mobileInitialScrollSynced = false;
    }
    if (!usesDesktopLayout) {
      _maybeSyncMobileInitialScroll();
    }
  }

  @override
  double resolveTabSwitcherBottomInset(
    BuildContext context,
    MediaQueryData mediaQuery,
    bool usesDesktopLayout,
  ) {
    final env = EnvScope.of(context);
    if (!usesDesktopLayout && env.navPlacement == NavPlacement.bottom) {
      return 0;
    }
    return super.resolveTabSwitcherBottomInset(
      context,
      mediaQuery,
      usesDesktopLayout,
    );
  }

  void _maybeSyncMobileInitialScroll() {
    if (_mobileInitialScrollSynced) {
      return;
    }
    _mobileInitialScrollSynced = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      calendarBloc.add(CalendarEvent.dateSelected(date: DateTime.now()));
    });
  }

  @override
  CalendarMobileTabShell buildMobileTabShell(
    BuildContext context,
    Widget tabSwitcher,
    Widget cancelBucket,
  ) {
    final env = EnvScope.of(context);
    if (env.navPlacement == NavPlacement.bottom) {
      return const CalendarMobileTabShell(
        tabBar: SizedBox.shrink(),
        cancelBucket: SizedBox.shrink(),
        showTopBorder: false,
        showDivider: false,
      );
    }
    final colors = context.colorScheme;
    return CalendarMobileTabShell(
      tabBar: tabSwitcher,
      cancelBucket: cancelBucket,
      backgroundColor: colors.background,
      borderColor: colors.border,
    );
  }

  @override
  Widget? buildDesktopTopHeader(Widget navigation, Widget? errorBanner) {
    return CalendarNavSurface(child: navigation);
  }

  @override
  Widget? buildDesktopBodyHeader(Widget navigation, Widget? errorBanner) {
    return errorBanner;
  }

  @override
  Widget buildMobileHeader(
    BuildContext context,
    bool showingPrimary,
    Widget navigation,
    Widget? errorBanner,
  ) {
    final headerChildren = <Widget>[];
    if (showingPrimary) {
      Widget navContent = CalendarNavSurface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [navigation, ?errorBanner],
        ),
      );
      headerChildren.add(navContent);
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
  }

  @override
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  ) {
    final Widget tintedLayout = CalendarNavSurface(child: layout);
    final Widget calendarBody = CalendarHoverTitleScope(
      controller: _hoverTitleController,
      child: tintedLayout,
    );
    return CalendarSurfaceNavigator(
      navigatorKey: _calendarNavigatorKey,
      modalAnchorKey: _calendarModalAnchorKey,
      enablePop: widget.surfacePopEnabled,
      child: calendarBody,
    );
  }

  @override
  VoidCallback? buildNavigationSearchAction(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    final locate = context.read;
    return () => _openTaskSearch(locate<CalendarBloc>(), locate: locate);
  }

  @override
  Widget? buildNavigationTrailingActions(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    return CalendarTransferMenu(
      state: state,
      ghost: true,
      additionalActions: [
        AxiMenuAction(
          icon: context.watch<SettingsCubit>().state.hideCompletedScheduled
              ? Icons.visibility
              : Icons.visibility_off,
          label: context.watch<SettingsCubit>().state.hideCompletedScheduled
              ? context.l10n.calendarShowCompleted
              : context.l10n.calendarHideCompleted,
          onPressed: () =>
              context.read<SettingsCubit>().toggleHideCompletedScheduled(
                !context.read<SettingsCubit>().state.hideCompletedScheduled,
              ),
        ),
      ],
    );
  }

  Future<void> _openTaskSearch(
    CalendarBloc bloc, {
    T Function<T>()? locate,
  }) async {
    final TaskSidebarState<CalendarBloc>? sidebarState =
        sidebarKey.currentState;
    await showCalendarTaskSearch(
      context: calendarModalContext,
      bloc: bloc,
      locate: locate,
      requiresLongPressForDrag: sidebarState?.requiresLongPressForDrag ?? false,
      taskTileBuilder: sidebarState == null
          ? null
          : (
              CalendarTask task, {
              Widget? trailing,
              bool requiresLongPress = false,
              VoidCallback? onTap,
              VoidCallback? onDragStart,
              bool allowContextMenu = false,
            }) => sidebarState.buildSearchTaskTile(
              task,
              trailing: trailing,
              requiresLongPress: requiresLongPress,
              onTap: onTap,
              onDragStart: onDragStart,
              allowContextMenu: allowContextMenu,
            ),
    );
  }

  @override
  Color resolveSurfaceColor(BuildContext context) =>
      CalendarNavSurface.backgroundColor(context);

  @override
  String get dragLogTag => 'calendar';

  @override
  bool shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  ) {
    return sizeClass == CalendarSizeClass.expanded;
  }
}

class CalendarSurfaceNavigator extends StatefulWidget {
  const CalendarSurfaceNavigator({
    super.key,
    required this.navigatorKey,
    required this.modalAnchorKey,
    required this.child,
    this.enablePop = _calendarSurfacePopEnabledDefault,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final GlobalKey modalAnchorKey;
  final Widget child;
  final bool enablePop;

  @override
  State<CalendarSurfaceNavigator> createState() =>
      _CalendarSurfaceNavigatorState();
}

final class _CalendarSurfaceNavigatorState
    extends State<CalendarSurfaceNavigator> {
  late final AxiSurfaceController _surfaceController = AxiSurfaceController();
  late final FocusScopeNode _focusScopeNode = FocusScopeNode(
    debugLabel: 'CalendarSurfaceScope',
  );
  late final ValueNotifier<bool> _navigatorCanPop = ValueNotifier<bool>(false);
  late final NavigatorObserver _navigatorObserver = _CalendarSurfaceObserver(
    onStackChanged: _syncNavigatorCanPop,
  );

  @override
  void initState() {
    super.initState();
    _surfaceController.attachFocusScope(_focusScopeNode);
  }

  @override
  void dispose() {
    _surfaceController.detachFocusScope(_focusScopeNode);
    _focusScopeNode.dispose();
    _navigatorCanPop.dispose();
    _surfaceController.dispose();
    super.dispose();
  }

  void _syncNavigatorCanPop() {
    final bool canPop = widget.navigatorKey.currentState?.canPop() ?? false;
    if (_navigatorCanPop.value != canPop) {
      _navigatorCanPop.value = canPop;
    }
  }

  bool _shouldInterceptBack() {
    return _surfaceController.hasFocusedTextInput() ||
        _surfaceController.hasOpenSurface ||
        _navigatorCanPop.value;
  }

  void _handleBack() {
    if (_surfaceController.dismissActiveTextInput()) {
      return;
    }
    if (_surfaceController.dismissTopSurface()) {
      return;
    }
    final NavigatorState? navigator = widget.navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AxiSurfaceScope(
      controller: _surfaceController,
      child: CalendarModalScope(
        navigatorKey: widget.navigatorKey,
        modalAnchorKey: widget.modalAnchorKey,
        surfaceController: _surfaceController,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            _surfaceController,
            _navigatorCanPop,
            FocusManager.instance,
          ]),
          builder: (context, _) {
            final bool shouldInterceptBack = _shouldInterceptBack();
            return PopScope(
              canPop: widget.enablePop && !shouldInterceptBack,
              onPopInvokedWithResult: (didPop, _) {
                if (didPop) {
                  return;
                }
                _handleBack();
              },
              child: FocusScope(
                node: _focusScopeNode,
                child: Navigator(
                  key: widget.navigatorKey,
                  observers: <NavigatorObserver>[_navigatorObserver],
                  onDidRemovePage: (page) => _syncNavigatorCanPop(),
                  pages: [
                    MaterialPage<void>(
                      key: _calendarSurfacePageKey,
                      child: KeyedSubtree(
                        key: widget.modalAnchorKey,
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

final class _CalendarSurfaceObserver extends NavigatorObserver {
  _CalendarSurfaceObserver({required VoidCallback onStackChanged})
    : _onStackChanged = onStackChanged;

  final VoidCallback _onStackChanged;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onStackChanged();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onStackChanged();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _onStackChanged();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _onStackChanged();
  }
}
