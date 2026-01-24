// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/bloc/chat_calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_availability_share_coordinator.dart';
import 'package:axichat/src/calendar/utils/calendar_acl_utils.dart';
import 'package:axichat/src/calendar/view/calendar_availability_share_sheet.dart';
import 'package:axichat/src/calendar/view/calendar_experience_state.dart';
import 'package:axichat/src/calendar/view/calendar_navigation.dart';
import 'package:axichat/src/calendar/view/calendar_task_search.dart';
import 'package:axichat/src/calendar/view/calendar_widget.dart';
import 'package:axichat/src/calendar/view/feedback_system.dart';
import 'package:axichat/src/calendar/view/task_sidebar.dart';
import 'package:axichat/src/calendar/view/sync_controls.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_hover_title_scope.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_mobile_tab_shell.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';

const double _chatCalendarToolbarHeight = 64.0;
const double _chatCalendarShareActionSpacing = 8.0;
const bool _chatCalendarAvailabilityShareVisible = false;
const bool _chatCalendarActionShowTransferMenu = false;
const bool _chatCalendarActionMenuGhost = true;
const bool _chatCalendarActionUsePrimary = true;
const bool _chatCalendarSurfacePopEnabledDefault = true;
const String _chatCalendarHeaderAssertMessage =
    'ChatCalendarWidget requires onBackPressed when showHeader and showBackButton are true.';

bool _resolveChatCalendarSurfacePopEnabled(BuildContext context) {
  try {
    return context.watch<ChatsCubit?>()?.state.openChatCalendar ??
        _chatCalendarSurfacePopEnabledDefault;
  } on FlutterError {
    return _chatCalendarSurfacePopEnabledDefault;
  }
}

CalendarAvailabilityShareCoordinator? _maybeReadAvailabilityShareCoordinator(
  BuildContext context,
) {
  try {
    return context.read<CalendarAvailabilityShareCoordinator>();
  } on FlutterError {
    return null;
  }
}

class ChatCalendarWidget extends StatefulWidget {
  const ChatCalendarWidget({
    super.key,
    required this.chat,
    this.onBackPressed,
    this.showHeader = true,
    this.showBackButton = true,
  });

  final VoidCallback? onBackPressed;
  final Chat chat;
  final bool showHeader;
  final bool showBackButton;

  @override
  State<ChatCalendarWidget> createState() => _ChatCalendarWidgetState();
}

class _ChatCalendarWidgetState
    extends CalendarExperienceState<ChatCalendarWidget, ChatCalendarBloc> {
  bool _mobileInitialScrollSynced = false;
  bool _desktopInitialViewSynced = false;
  late final CalendarHoverTitleController _hoverTitleController =
      CalendarHoverTitleController();
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
    final availabilityCoordinator = _maybeReadAvailabilityShareCoordinator(
      context,
    );
    assert(
      !widget.showHeader ||
          !widget.showBackButton ||
          widget.onBackPressed != null,
      _chatCalendarHeaderAssertMessage,
    );
    final Widget calendarBody = CalendarHoverTitleScope(
      controller: _hoverTitleController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.showHeader)
            _ChatCalendarAppBar(
              onBackPressed: widget.onBackPressed,
              showBackButton: widget.showBackButton,
              state: state,
              tabController: mobileTabController,
              onShareAvailability: availabilityCoordinator == null
                  ? null
                  : () => _openAvailabilityShareSheet(
                        state,
                      ),
            ),
          Expanded(child: tintedLayout),
        ],
      ),
    );
    return CalendarSurfaceNavigator(
      navigatorKey: _calendarNavigatorKey,
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
  ) async {
    final l10n = context.l10n;
    final xmpp = context.read<XmppService>();
    final String? ownerJid = xmpp.myJid?.trim();
    if (ownerJid == null || ownerJid.isEmpty) {
      FeedbackSystem.showError(
        context,
        l10n.calendarShareUnavailable,
      );
      return;
    }
    await showCalendarAvailabilityShareSheet(
      context: context,
      source: CalendarAvailabilityShareSource.chat(chatJid: widget.chat.jid),
      model: state.model,
      ownerJid: ownerJid,
      lockToChat: true,
      initialChat: widget.chat,
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

class _ChatCalendarAppBar extends StatelessWidget {
  const _ChatCalendarAppBar({
    required this.state,
    required this.tabController,
    this.onShareAvailability,
    this.onBackPressed,
    this.showBackButton = true,
  });

  final CalendarState state;
  final TabController tabController;
  final VoidCallback? onShareAvailability;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final Color background = CalendarNavSurface.backgroundColor(context);
    final Color border = context.colorScheme.border;
    final EdgeInsets toolbarPadding = calendarMarginLarge.copyWith(
      top: 0,
      bottom: 0,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: SizedBox(
        height: _chatCalendarToolbarHeight,
        child: Padding(
          padding: toolbarPadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (showBackButton)
                AxiIconButton.ghost(
                  iconData: LucideIcons.arrowLeft,
                  tooltip: context.l10n.chatBack,
                  onPressed: onBackPressed,
                ),
              const Spacer(),
              _ChatCalendarActionRow(
                state: state,
                tabController: tabController,
                onShareAvailability: onShareAvailability,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatCalendarActionRow extends StatelessWidget {
  const _ChatCalendarActionRow({
    required this.state,
    required this.tabController,
    this.onShareAvailability,
  });

  final CalendarState state;
  final TabController tabController;
  final VoidCallback? onShareAvailability;

  @override
  Widget build(BuildContext context) {
    final bool showPaneToggle = !ResponsiveHelper.isCompact(context);
    return Wrap(
      spacing: _chatCalendarShareActionSpacing,
      runSpacing: _chatCalendarShareActionSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (showPaneToggle)
          CalendarPaneToggle(
            controller: tabController,
          ),
        SyncControls(
          state: state,
          compact: true,
          showTransferMenu: _chatCalendarActionShowTransferMenu,
        ),
        if (onShareAvailability != null &&
            _chatCalendarAvailabilityShareVisible)
          AxiIconButton.ghost(
            iconData: LucideIcons.send,
            tooltip: context.l10n.calendarShareAvailability,
            onPressed: onShareAvailability,
            usePrimary: _chatCalendarActionUsePrimary,
          ),
        CalendarTransferMenu(
          state: state,
          ghost: _chatCalendarActionMenuGhost,
          usePrimary: _chatCalendarActionUsePrimary,
        ),
      ],
    );
  }
}
