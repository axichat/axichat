// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/calendar/view/calendar_availability_share_sheet.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'calendar_task_search.dart';
import 'calendar_experience_state.dart';
import 'feedback_system.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
import 'widgets/calendar_hover_title_scope.dart';
import 'widgets/calendar_mobile_tab_shell.dart';

class CalendarWidget extends StatefulWidget {
  const CalendarWidget({super.key});

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

const double _calendarShareActionSpacing = 8.0;
const String _calendarAvailabilityShareTooltip = 'Share availability';
const String _calendarAvailabilityShareMissingJidMessage =
    'Calendar sharing is unavailable.';
const bool _calendarActionShowTransferMenu = false;
const bool _calendarActionMenuGhost = true;
const bool _calendarActionUsePrimary = true;
const String _calendarSurfacePageId = 'calendar-surface';
const ValueKey<String> _calendarSurfacePageKey =
    ValueKey<String>(_calendarSurfacePageId);
const bool _calendarSurfacePopEnabledDefault = true;

CalendarAvailabilityShareCoordinator? _maybeReadAvailabilityShareCoordinator(
  BuildContext context,
) {
  try {
    return RepositoryProvider.of<CalendarAvailabilityShareCoordinator>(
      context,
      listen: false,
    );
  } on FlutterError {
    return null;
  }
}

bool _resolveCalendarSurfacePopEnabled(BuildContext context) {
  try {
    return context.watch<ChatsCubit?>()?.state.openCalendar ??
        _calendarSurfacePopEnabledDefault;
  } on FlutterError {
    return _calendarSurfacePopEnabledDefault;
  }
}

class _CalendarWidgetState
    extends CalendarExperienceState<CalendarWidget, CalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void dispose() {
    _hoverTitleController.dispose();
    super.dispose();
  }

  @override
  void handleStateChanges(BuildContext context, CalendarState state) {
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
    }
    final warning = state.syncWarning;
    if (warning != null && mounted) {
      FeedbackSystem.showWarning(
        context,
        warning.message,
        title: warning.title,
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
      calendarBloc.add(
        CalendarEvent.dateSelected(
          date: DateTime.now(),
        ),
      );
    });
  }

  @override
  CalendarMobileTabShell buildMobileTabShell(
    BuildContext context,
    Widget tabSwitcher,
    Widget cancelBucket,
  ) {
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
          children: [
            navigation,
            if (errorBanner != null) errorBanner,
          ],
        ),
      );
      headerChildren.add(
        navContent,
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
  }

  @override
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  ) {
    final Widget tintedLayout = CalendarNavSurface(child: layout);
    final availabilityCoordinator = _maybeReadAvailabilityShareCoordinator(
      context,
    );
    final Widget calendarBody = CalendarHoverTitleScope(
      controller: _hoverTitleController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CalendarAppBar(
            state: state,
            onBackPressed: _handleCalendarBackPressed,
            onShareAvailability: availabilityCoordinator == null
                ? null
                : () => _openAvailabilityShareSheet(
                      state,
                      availabilityCoordinator,
                    ),
          ),
          Expanded(child: tintedLayout),
        ],
      ),
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

  Future<void> _openAvailabilityShareSheet(
    CalendarState state,
    CalendarAvailabilityShareCoordinator coordinator,
  ) async {
    final xmpp = context.read<XmppService>();
    final ownerJid = xmpp.myJid?.trim();
    if (ownerJid == null || ownerJid.isEmpty) {
      FeedbackSystem.showError(
        context,
        _calendarAvailabilityShareMissingJidMessage,
      );
      return;
    }
    await showCalendarAvailabilityShareSheet(
      context: context,
      coordinator: coordinator,
      source: const CalendarAvailabilityShareSource.personal(),
      model: state.model,
      ownerJid: ownerJid,
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
    if (context.read<ChatsCubit?>()?.state.openCalendar == true) {
      context.read<ChatsCubit?>()?.toggleCalendar();
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
}

class _CalendarAppBar extends StatelessWidget {
  const _CalendarAppBar({
    required this.state,
    required this.onBackPressed,
    this.onShareAvailability,
  });

  final CalendarState state;
  final VoidCallback onBackPressed;
  final VoidCallback? onShareAvailability;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final Color background = CalendarNavSurface.backgroundColor(context);
    final EdgeInsets toolbarPadding =
        calendarMarginLarge.copyWith(top: 0, bottom: 0);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(
          bottom: BorderSide(color: colors.border),
        ),
      ),
      child: SizedBox(
        height: kToolbarHeight,
        child: Padding(
          padding: toolbarPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AxiIconButton.ghost(
                iconData: LucideIcons.arrowLeft,
                tooltip: context.l10n.calendarBackToChats,
                onPressed: onBackPressed,
              ),
              const Spacer(),
              _CalendarActionRow(
                state: state,
                onShareAvailability: onShareAvailability,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarActionRow extends StatelessWidget {
  const _CalendarActionRow({
    required this.state,
    this.onShareAvailability,
  });

  final CalendarState state;
  final VoidCallback? onShareAvailability;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: _calendarShareActionSpacing,
      runSpacing: _calendarShareActionSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SyncControls(
          state: state,
          showTransferMenu: _calendarActionShowTransferMenu,
        ),
        if (onShareAvailability != null)
          AxiIconButton.ghost(
            iconData: LucideIcons.send,
            tooltip: _calendarAvailabilityShareTooltip,
            onPressed: onShareAvailability,
            usePrimary: _calendarActionUsePrimary,
          ),
        CalendarTransferMenu(
          state: state,
          ghost: _calendarActionMenuGhost,
          usePrimary: _calendarActionUsePrimary,
        ),
      ],
    );
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
    return NavigatorPopHandler<void>(
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
          MaterialPage<void>(
            key: _calendarSurfacePageKey,
            child: child,
          ),
        ],
      ),
    );
  }
}
