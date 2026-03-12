// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:axichat/src/calendar/view/sync_controls.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/utils/calendar_acl_utils.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const bool _chatCalendarSurfacePopEnabledDefault = true;

bool _resolveChatCalendarSurfacePopEnabled(BuildContext context) {
  return context.watch<ChatsCubit>().state.openChatCalendar ||
      _chatCalendarSurfacePopEnabledDefault;
}

class ChatCalendarWidget extends StatefulWidget {
  const ChatCalendarWidget({
    super.key,
    required this.chat,
    this.showHeader = true,
  });

  final Chat chat;
  final bool showHeader;

  @override
  State<ChatCalendarWidget> createState() => _ChatCalendarWidgetState();
}

class _ChatCalendarWidgetState
    extends CalendarExperienceState<ChatCalendarWidget, ChatCalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  bool _desktopInitialViewSynced = false;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
  late final GlobalKey _calendarModalAnchorKey = GlobalKey(
    debugLabel: 'chat-calendar-modal-anchor',
  );
  late final GlobalKey<NavigatorState> _calendarNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  CalendarChatAcl? buildNavigationChatAcl(CalendarState state) =>
      widget.chat.type.calendarDefaultAcl;

  @override
  String? buildNavigationChatTitle(CalendarState state) => widget.chat.title;

  @override
  void dispose() {
    _hoverTitleController.dispose();
    super.dispose();
  }

  @override
  BuildContext get calendarModalContext {
    return _calendarModalAnchorKey.currentContext ??
        _calendarNavigatorKey.currentState?.overlay?.context ??
        _calendarNavigatorKey.currentContext ??
        context;
  }

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
    if (usesDesktopLayout) {
      _maybeSyncDesktopInitialView(state);
      return;
    }
    if (_desktopInitialViewSynced) {
      _desktopInitialViewSynced = false;
    }
    _maybeSyncMobileInitialScroll();
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

  void _maybeSyncDesktopInitialView(CalendarState state) {
    if (_desktopInitialViewSynced) {
      return;
    }
    _desktopInitialViewSynced = true;
    if (state.viewMode != CalendarView.day) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      calendarBloc.add(
        const CalendarEvent.viewChanged(view: CalendarView.week),
      );
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
      enablePop: _resolveChatCalendarSurfacePopEnabled(context),
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
    return () => _openTaskSearch(locate<ChatCalendarBloc>(), locate: locate);
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
    ChatCalendarBloc bloc, {
    T Function<T>()? locate,
  }) async {
    final TaskSidebarState<ChatCalendarBloc>? sidebarState =
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
  String get dragLogTag => 'chat-calendar';

  @override
  bool shouldUseDesktopLayout(
    CalendarSizeClass sizeClass,
    MediaQueryData mediaQuery,
  ) {
    return sizeClass == CalendarSizeClass.expanded;
  }
}
