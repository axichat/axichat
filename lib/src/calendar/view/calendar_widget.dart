// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_sync_warning.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'calendar_task_search.dart';
import 'calendar_experience_state.dart';
import 'feedback_system.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_hover_title_scope.dart';
import 'widgets/calendar_mobile_tab_shell.dart';

@immutable
class CalendarBottomDragSession {
  const CalendarBottomDragSession({this.pointer});

  final Offset? pointer;
}

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({
    super.key,
    this.pendingMobileTabIndex,
    this.activeMobileTabIndex,
    this.bottomDragSession,
  });

  final ValueNotifier<int?>? pendingMobileTabIndex;
  final ValueNotifier<int>? activeMobileTabIndex;
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

bool _resolveCalendarSurfacePopEnabled(BuildContext context) {
  return context.watch<ChatsCubit>().state.openCalendar ||
      _calendarSurfacePopEnabledDefault;
}

class _CalendarWidgetState
    extends CalendarExperienceState<CalendarWidget, CalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  ValueNotifier<int?>? _pendingMobileTabNotifier;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _attachPendingMobileTabNotifier();
    mobileTabController.addListener(_handleMobileTabIndexChanged);
    _consumePendingMobileTabIndex(animate: false);
    _syncActiveMobileTabIndex();
  }

  @override
  void didUpdateWidget(covariant CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _attachPendingMobileTabNotifier();
    _consumePendingMobileTabIndex(animate: true);
    _syncActiveMobileTabIndex();
  }

  @override
  void dispose() {
    _clearHomeBottomDragState();
    _pendingMobileTabNotifier?.removeListener(_handlePendingMobileTabChange);
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

  void _attachPendingMobileTabNotifier() {
    final notifier = widget.pendingMobileTabIndex;
    if (notifier == _pendingMobileTabNotifier) {
      return;
    }
    _pendingMobileTabNotifier?.removeListener(_handlePendingMobileTabChange);
    _pendingMobileTabNotifier = notifier;
    _pendingMobileTabNotifier?.addListener(_handlePendingMobileTabChange);
  }

  void _handlePendingMobileTabChange() {
    _consumePendingMobileTabIndex(animate: true);
  }

  void _handleMobileTabIndexChanged() {
    if (mobileTabController.indexIsChanging) {
      return;
    }
    _syncActiveMobileTabIndex();
  }

  void _syncActiveMobileTabIndex() {
    final notifier = widget.activeMobileTabIndex;
    if (notifier == null) {
      return;
    }
    final int resolvedIndex = mobileTabController.index;
    if (notifier.value == resolvedIndex) {
      return;
    }
    notifier.value = resolvedIndex;
  }

  void _consumePendingMobileTabIndex({required bool animate}) {
    final notifier = _pendingMobileTabNotifier;
    if (notifier == null) return;
    final pending = notifier.value;
    if (pending == null) return;
    final resolved = pending.clamp(0, mobileTabController.length - 1);
    if (animate && mobileTabController.index != resolved) {
      mobileTabController.animateTo(resolved);
    } else {
      mobileTabController.index = resolved;
    }
    notifier.value = null;
    _syncActiveMobileTabIndex();
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
      FeedbackSystem.showWarning(
        context,
        message,
        title: title,
      );
      calendarBloc.add(const CalendarEvent.syncWarningCleared());
    }
  }

  @override
  void onCalendarDragSessionStarted() {
    final notifier = widget.bottomDragSession;
    if (notifier != null) {
      notifier.value = const CalendarBottomDragSession();
    }
  }

  @override
  void onCalendarDragPositionChanged(Offset globalPosition) {
    final notifier = widget.bottomDragSession;
    if (notifier != null) {
      notifier.value = CalendarBottomDragSession(pointer: globalPosition);
    }
  }

  @override
  void onCalendarDragSessionEnded() {
    _clearHomeBottomDragState();
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
      dividerColor: colors.border,
      showTopBorder: false,
      showDivider: true,
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
          children: [navigation, if (errorBanner != null) errorBanner],
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
      enablePop: _resolveCalendarSurfacePopEnabled(context),
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
      context: context,
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
            }) =>
              sidebarState.buildSearchTaskTile(
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

class CalendarSurfaceNavigator extends StatelessWidget {
  const CalendarSurfaceNavigator({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.enablePop = _calendarSurfacePopEnabledDefault,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final bool enablePop;

  @override
  Widget build(BuildContext context) {
    return CalendarModalScope(
      navigatorKey: navigatorKey,
      child: NavigatorPopHandler<void>(
        enabled: enablePop,
        onPopWithResult: (_) {
          final NavigatorState? navigator = navigatorKey.currentState;
          if (navigator == null || !navigator.canPop()) {
            return;
          }
          navigator.pop();
        },
        child: Navigator(
          key: navigatorKey,
          onDidRemovePage: (page) {},
          pages: [
            MaterialPage<void>(key: _calendarSurfacePageKey, child: child),
          ],
        ),
      ),
    );
  }
}
