// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/routes.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart' as m;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_sync_warning.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/calendar_navigation.dart';
import 'calendar_task_search.dart';
import 'calendar_experience_state.dart';
import 'feedback_system.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_hover_title_scope.dart';
import 'widgets/calendar_mobile_tab_shell.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({
    super.key,
    this.pendingMobileTabIndex,
  });

  final ValueNotifier<int?>? pendingMobileTabIndex;

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class CalendarNavSurface extends StatelessWidget {
  const CalendarNavSurface({super.key, required this.child});

  final Widget child;

  static Color backgroundColor(BuildContext context) {
    final scheme = context.colorScheme;
    return ShadTheme.of(context).brightness == Brightness.dark
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
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _consumePendingMobileTabIndex(animate: false);
  }

  @override
  void didUpdateWidget(covariant CalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _consumePendingMobileTabIndex(animate: true);
  }

  @override
  void dispose() {
    _hoverTitleController.dispose();
    super.dispose();
  }

  void _consumePendingMobileTabIndex({required bool animate}) {
    final notifier = widget.pendingMobileTabIndex;
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
  void onLayoutModeResolved(CalendarState state, bool usesDesktopLayout) {
    if (usesDesktopLayout && _mobileInitialScrollSynced) {
      _mobileInitialScrollSynced = false;
    }
    if (!usesDesktopLayout) {
      _maybeSyncMobileInitialScroll();
    }
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
      return CalendarMobileTabShell(
        tabBar: _CalendarMobileNavRow(
          tabSwitcher: tabSwitcher,
          onHomePressed: () => context.read<ChatsCubit>().toggleCalendar(),
        ),
        cancelBucket: cancelBucket,
        backgroundColor: context.colorScheme.background,
        borderColor: context.colorScheme.border,
        dividerColor: context.colorScheme.border,
        showTopBorder: true,
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
  Widget? buildNavigationLeadingActions(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    return CalendarNavigationLeadingActions(
      state: state,
      backTooltip: context.l10n.calendarBackToChats,
      onBackPressed: _handleCalendarBackPressed,
    );
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

  void _handleCalendarBackPressed() {
    final NavigatorState? calendarNavigator =
        _calendarNavigatorKey.currentState;
    if (calendarNavigator != null && calendarNavigator.canPop()) {
      calendarNavigator.pop();
      return;
    }
    if (context.read<ChatsCubit>().state.openCalendar) {
      context.read<ChatsCubit>().toggleCalendar();
      return;
    }

    final router = GoRouter.maybeOf(context);
    if (router == null) {
      return;
    }
    if (router.canPop()) {
      router.pop();
      return;
    }
    router.go('/');
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

class _CalendarMobileNavRow extends StatelessWidget {
  const _CalendarMobileNavRow({
    required this.tabSwitcher,
    required this.onHomePressed,
  });

  final Widget tabSwitcher;
  final VoidCallback onHomePressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: spacing.s,
        vertical: spacing.xs,
      ),
      child: Row(
        children: [
          _CalendarBottomNavItem(
            label: Text(l10n.homeTabChats),
            icon: Icon(
              LucideIcons.messagesSquare,
              size: sizing.menuItemIconSize,
            ),
            onPressed: onHomePressed,
          ),
          Expanded(child: tabSwitcher),
          _CalendarSettingsBottomNavItem(
            label: l10n.settingsButtonLabel,
          ),
        ],
      ),
    );
  }
}

class _CalendarBottomNavItem extends StatelessWidget {
  const _CalendarBottomNavItem({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final Widget label;
  final Widget icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final textStyle = context.textTheme.small;
    return AxiButton.ghost(
      size: AxiButtonSize.sm,
      onPressed: onPressed,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          SizedBox(height: spacing.xxs),
          DefaultTextStyle.merge(
            style: textStyle,
            textAlign: TextAlign.center,
            child: label,
          ),
        ],
      ),
    );
  }
}

class _CalendarSettingsBottomNavItem extends StatelessWidget {
  const _CalendarSettingsBottomNavItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final sizing = context.sizing;
        return _CalendarBottomNavItem(
          label: Text(label),
          icon: AxiAvatar(
            jid: state.jid,
            subscription: m.Subscription.both,
            avatarPath: state.avatarPath,
            presence: null,
            status: null,
            active: false,
            size: sizing.iconButtonIconSize,
          ),
          onPressed: () =>
              context.push(const ProfileRoute().location, extra: context.read),
        );
      },
    );
  }
}
