import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'calendar_task_search.dart';
import 'calendar_experience_state.dart';
import 'feedback_system.dart';
import 'sync_controls.dart';
import 'task_sidebar.dart';
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

class _CalendarWidgetState
    extends CalendarExperienceState<CalendarWidget, CalendarBloc> {
  bool _mobileInitialScrollSynced = false;

  @override
  void handleStateChanges(BuildContext context, CalendarState state) {
    if (state.error != null && mounted) {
      FeedbackSystem.showError(context, state.error!);
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
      calendarBloc?.add(
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
    return _CalendarSurfaceTint(
      child: CalendarNavSurface(
        child: navigation,
      ),
    );
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
  }

  @override
  Widget buildScaffoldBody(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
    Widget layout,
  ) {
    final colors = context.colorScheme;
    final Widget tintedLayout = _CalendarSurfaceTint(child: layout);
    return Column(
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
    );
  }

  @override
  VoidCallback? buildNavigationSearchAction(
    BuildContext context,
    CalendarState state,
    bool usesDesktopLayout,
  ) {
    final CalendarBloc? bloc = calendarBloc;
    if (bloc == null) {
      return null;
    }
    return () => _openTaskSearch(bloc);
  }

  Future<void> _openTaskSearch(CalendarBloc bloc) async {
    final TaskSidebarState? sidebarState = sidebarKey.currentState;
    await showCalendarTaskSearch(
      context: context,
      bloc: bloc,
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AxiIconButton(
                iconData: LucideIcons.arrowLeft,
                tooltip: 'Back to chats',
                color: colors.foreground,
                borderColor: colors.border,
                onPressed: onBackPressed,
              ),
              const Spacer(),
              SyncControls(state: state),
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
