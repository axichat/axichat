// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/home_screen.dart';

enum _HomeDemoPhase { idle, triggered }

class Nexus extends StatefulWidget {
  const Nexus({
    super.key,
    required this.tabs,
    required this.navPlacement,
    this.showNavigationRail = true,
    this.navRailCollapsed = false,
    this.onToggleNavRail,
  });

  final List<HomeTabEntry> tabs;
  final NavPlacement navPlacement;
  final bool showNavigationRail;
  final bool navRailCollapsed;
  final VoidCallback? onToggleNavRail;

  @override
  State<Nexus> createState() => _NexusState();
}

class _NexusState extends State<Nexus> {
  TabController? _tabController;
  _HomeDemoPhase _demoPhase = _HomeDemoPhase.idle;
  Stream<void>? _demoResetStream;
  StreamSubscription<void>? _demoResetSubscription;

  void _triggerDemoInteractivePhase() {
    if (_demoPhase != _HomeDemoPhase.idle) return;
    setState(() => _demoPhase = _HomeDemoPhase.triggered);
    context.read<ChatsCubit>().startDemoInteractivePhase();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller != _tabController) {
      _tabController?.removeListener(_handleTabChanged);
      _tabController = controller;
      _tabController?.addListener(_handleTabChanged);
      _notifyTabIndex(controller.index);
    }
    if (!kEnableDemoChats) {
      _teardownDemoResetSubscription();
      return;
    }
    final demoResetStream = context.read<ChatsCubit>().demoResetStream;
    if (demoResetStream == _demoResetStream) {
      return;
    }
    _teardownDemoResetSubscription();
    _demoResetStream = demoResetStream;
    _demoResetSubscription = demoResetStream.listen((_) {
      if (!mounted) return;
      setState(() => _demoPhase = _HomeDemoPhase.idle);
    });
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    _notifyTabIndex(controller.index);
  }

  void _notifyTabIndex(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    context.read<HomeSearchCubit>().setActiveTab(widget.tabs[index].id);
    HomeShellScope.maybeOf(context)?.homeTabIndex.value = index;
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChanged);
    _teardownDemoResetSubscription();
    super.dispose();
  }

  void _teardownDemoResetSubscription() {
    _demoResetSubscription?.cancel();
    _demoResetSubscription = null;
    _demoResetStream = null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeSearchCubit, HomeSearchState>(
      builder: (context, searchState) {
        return BlocBuilder<ChatsCubit, ChatsState>(
          builder: (context, chatsState) {
            return _NexusScaffold(
              tabs: widget.tabs,
              navPlacement: widget.navPlacement,
              showNavigationRail: widget.showNavigationRail,
              navRailCollapsed: widget.navRailCollapsed,
              onToggleNavRail: widget.onToggleNavRail,
              selectedIndex: _tabController?.index ?? 0,
              onDestinationSelected: _handleRailSelection,
              searchState: searchState,
              chatsState: chatsState,
              demoPhase: _demoPhase,
              onTriggerDemoInteractivePhase: _triggerDemoInteractivePhase,
            );
          },
        );
      },
    );
  }

  void _handleRailSelection(int index) {
    final controller = _tabController;
    if (controller == null || index == controller.index) return;
    if (index < 0 || index >= widget.tabs.length) return;
    controller.animateTo(index);
  }
}

class _NexusScaffold extends StatelessWidget {
  const _NexusScaffold({
    required this.tabs,
    required this.navPlacement,
    required this.showNavigationRail,
    required this.navRailCollapsed,
    required this.onToggleNavRail,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.searchState,
    required this.chatsState,
    required this.demoPhase,
    required this.onTriggerDemoInteractivePhase,
  });

  final List<HomeTabEntry> tabs;
  final NavPlacement navPlacement;
  final bool showNavigationRail;
  final bool navRailCollapsed;
  final VoidCallback? onToggleNavRail;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final HomeSearchState searchState;
  final ChatsState chatsState;
  final _HomeDemoPhase demoPhase;
  final VoidCallback onTriggerDemoInteractivePhase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final selectedChats = chatsState.selectedJids.isEmpty
        ? const <m.Chat>[]
        : chatItems
            .where((chat) => chatsState.selectedJids.contains(chat.jid))
            .toList();
    final badgeCounts = <HomeTab, int>{
      HomeTab.invites: context.watch<RosterCubit>().inviteCount,
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit>().state.items?.length ?? 0,
      HomeTab.spam:
          chatItems.where((chat) => chat.spam && !chat.archived).length,
    };
    final headerActions = <AppBarActionItem>[
      if (kEnableDemoChats && demoPhase == _HomeDemoPhase.idle)
        AppBarActionItem(
          label: l10n.commonStart,
          iconData: LucideIcons.play,
          onPressed: onTriggerDemoInteractivePhase,
        ),
      if (navPlacement != NavPlacement.rail)
        AppBarActionItem(
          label: l10n.accessibilityActionsLabel,
          iconData: LucideIcons.lifeBuoy,
          inline: const _FindActionIconButton(),
          onPressed: () => context.read<AccessibilityActionBloc>().add(
                const AccessibilityMenuOpened(),
              ),
        ),
      if (EnvScope.of(context).isDesktopPlatform)
        AppBarActionItem(
          label: l10n.homeSyncTooltip,
          iconData: LucideIcons.refreshCw,
          inline: const _DesktopHomeRefreshButton(),
          onPressed: () => context.read<ChatsCubit>().refreshHomeSync(),
        ),
      AppBarActionItem(
        label: searchState.active ? l10n.chatSearchClose : l10n.commonSearch,
        iconData: LucideIcons.search,
        inline: _SearchToggleButton(
          active: searchState.active,
          onPressed: () => context.read<HomeSearchCubit>().toggleSearch(),
        ),
        onPressed: () => context.read<HomeSearchCubit>().toggleSearch(),
      ),
    ];
    final header = _NexusHeader(
      tabs: tabs,
      headerActions: headerActions,
      navRailVisible: navPlacement == NavPlacement.rail && showNavigationRail,
    );
    final tabViews = _NexusTabViews(
      tabs: tabs,
      tabViewPhysics: navPlacement == NavPlacement.bottom
          ? const NeverScrollableScrollPhysics()
          : defaultTargetPlatform.isMobile
              ? null
              : const NeverScrollableScrollPhysics(),
      selectedChats: selectedChats,
      showToast: showToast,
    );
    final bottomArea = _NexusBottomArea(
      navPlacement: navPlacement,
      tabs: tabs,
      selectedChats: selectedChats,
      badgeCounts: badgeCounts,
    );
    final column = Column(
      children: [
        header,
        Expanded(child: tabViews),
        bottomArea,
      ],
    );

    if (navPlacement == NavPlacement.rail && showNavigationRail) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HomeNavigationRail(
            tabs: tabs,
            selectedIndex: selectedIndex,
            collapsed: navRailCollapsed,
            onDestinationSelected: onDestinationSelected,
            calendarAvailable: false,
            calendarActive: false,
            onCalendarSelected: () {},
            badgeCounts: badgeCounts,
            onCollapsedChanged:
                onToggleNavRail == null ? null : (_) => onToggleNavRail!(),
          ),
          Expanded(child: column),
        ],
      );
    }

    return column;
  }
}

class _NexusHeader extends StatelessWidget {
  const _NexusHeader({
    required this.tabs,
    required this.headerActions,
    required this.navRailVisible,
  });

  final List<HomeTabEntry> tabs;
  final List<AppBarActionItem> headerActions;
  final bool navRailVisible;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiAppBar(
          showTitle: false,
          leading: _TransportStatusChips(
            maxWidth: navRailVisible ? null : context.sizing.menuMaxWidth,
          ),
          trailing: AppBarActions(
            actions: headerActions,
            spacing: spacing.s,
            overflowBreakpoint: 0,
            forceCollapsed: false,
            availableWidth: double.infinity,
          ),
        ),
        _HomeSearchPanel(tabs: tabs),
      ],
    );
  }
}

class _TransportStatusChips extends StatelessWidget {
  const _TransportStatusChips({this.maxWidth});

  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final demoOffline = context.watch<XmppService>().demoOfflineMode;
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final connectionState = _xmppStateForHome(
          connectivityState,
          demoOffline: demoOffline,
        );
        final sessionEmailState = demoOffline
            ? const EmailSyncState.ready()
            : connectivityState.emailState;
        final emailEnabled =
            demoOffline ? true : connectivityState.emailEnabled;
        final indicator = Align(
          alignment: Alignment.centerLeft,
          child: SessionCapabilityIndicators(
            xmppState: connectionState,
            emailState: sessionEmailState,
            emailEnabled: emailEnabled,
            compact: true,
          ),
        );
        if (maxWidth == null) return indicator;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth!),
          child: indicator,
        );
      },
    );
  }
}

class _NexusTabViews extends StatelessWidget {
  const _NexusTabViews({
    required this.tabs,
    required this.tabViewPhysics,
    required this.selectedChats,
    required this.showToast,
  });

  final List<HomeTabEntry> tabs;
  final ScrollPhysics? tabViewPhysics;
  final List<m.Chat> selectedChats;
  final void Function(ShadToast)? showToast;

  @override
  Widget build(BuildContext context) {
    final toast = showToast;
    return MultiBlocListener(
      listeners: [
        BlocListener<RosterCubit, RosterState>(
          listenWhen: (previous, current) =>
              previous.actionState != current.actionState,
          listener: (context, state) {
            if (toast == null) return;
            final actionState = state.actionState;
            if (actionState is RosterActionFailure) {
              toast(
                FeedbackToast.error(
                  message: _rosterFailureToastMessage(context, actionState),
                ),
              );
            } else if (actionState is RosterActionSuccess) {
              toast(
                FeedbackToast.success(
                  message: _rosterSuccessToastMessage(context, actionState),
                ),
              );
            }
          },
        ),
        BlocListener<BlocklistCubit, BlocklistState>(
          listener: (context, state) {
            if (toast == null) return;
            if (state is BlocklistFailure) {
              toast(
                FeedbackToast.error(
                  message: state.notice.resolve(context.l10n),
                ),
              );
            } else if (state is BlocklistSuccess) {
              toast(
                FeedbackToast.success(
                  message: state.notice.resolve(context.l10n),
                ),
              );
            }
          },
        ),
      ],
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: context.borderSide),
        ),
        child: TabBarView(
          physics: tabViewPhysics,
          children: tabs.map((tab) {
            return Scaffold(
              resizeToAvoidBottomInset: false,
              extendBodyBehindAppBar: true,
              body: tab.body,
              floatingActionButtonAnimator: const _ScaleOnlyFabAnimator(),
              floatingActionButton: selectedChats.isNotEmpty ? null : tab.fab,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _NexusBottomArea extends StatelessWidget {
  const _NexusBottomArea({
    required this.navPlacement,
    required this.tabs,
    required this.selectedChats,
    required this.badgeCounts,
  });

  final NavPlacement navPlacement;
  final List<HomeTabEntry> tabs;
  final List<m.Chat> selectedChats;
  final Map<HomeTab, int> badgeCounts;

  @override
  Widget build(BuildContext context) {
    if (selectedChats.isNotEmpty) {
      return ChatSelectionActionBar(selectedChats: selectedChats);
    }
    if (navPlacement == NavPlacement.bottom) {
      final badgeOffset = Offset(0, -context.spacing.s);
      final tabBar = Container(
        decoration: BoxDecoration(
          border: Border(bottom: context.borderSide),
        ),
        child: AxiTabBar(
          backgroundColor: context.colorScheme.background,
          badges: tabs.map((tab) => badgeCounts[tab.id] ?? 0).toList(),
          badgeOffset: badgeOffset,
          tabs: tabs.map((tab) {
            return Tab(child: Text(tab.label));
          }).toList(),
        ),
      );
      return tabBar;
    }
    return const SizedBox.shrink();
  }
}

class _HomeShellBottomBar extends StatelessWidget {
  const _HomeShellBottomBar({
    required this.pendingCalendarTabIndex,
    required this.calendarTabHost,
    required this.calendarAvailable,
  });

  final ValueNotifier<int?> pendingCalendarTabIndex;
  final CalendarMobileTabHostController calendarTabHost;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, bool>(
      selector: (state) => state.openCalendar,
      builder: (context, openCalendar) {
        return AnimatedBuilder(
          animation: calendarTabHost,
          builder: (context, _) {
            final hostData = calendarTabHost.data;
            if (openCalendar && hostData != null) {
              return _HomeShellCalendarBar(
                tabSwitcher: hostData.tabSwitcher,
                cancelBucket: hostData.cancelBucket,
                onHomePressed: () =>
                    context.read<ChatsCubit>().toggleCalendar(),
              );
            }
            return _HomeShellDefaultBar(
              calendarAvailable: calendarAvailable,
              pendingCalendarTabIndex: pendingCalendarTabIndex,
            );
          },
        );
      },
    );
  }
}

class _HomeShellCalendarBar extends StatelessWidget {
  const _HomeShellCalendarBar({
    required this.tabSwitcher,
    required this.cancelBucket,
    required this.onHomePressed,
  });

  final Widget tabSwitcher;
  final Widget cancelBucket;
  final VoidCallback onHomePressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return CalendarMobileTabShell(
      tabBar: _HomeShellCalendarNavRow(
        tabSwitcher: tabSwitcher,
        onHomePressed: onHomePressed,
      ),
      cancelBucket: cancelBucket,
      backgroundColor: colors.background,
      borderColor: colors.border,
      dividerColor: colors.border,
      showTopBorder: true,
      showDivider: false,
    );
  }
}

class _HomeShellCalendarNavRow extends StatelessWidget {
  const _HomeShellCalendarNavRow({
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
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.s,
          vertical: spacing.xs,
        ),
        child: Row(
          children: [
            _BottomNavItem(
              label: Text(l10n.homeTabChats),
              icon: Icon(
                LucideIcons.messagesSquare,
                size: sizing.menuItemIconSize,
              ),
              onPressed: onHomePressed,
            ),
            Expanded(child: tabSwitcher),
            _SettingsBottomNavItem(
              label: l10n.settingsButtonLabel,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeShellDefaultBar extends StatelessWidget {
  const _HomeShellDefaultBar({
    required this.calendarAvailable,
    required this.pendingCalendarTabIndex,
  });

  final bool calendarAvailable;
  final ValueNotifier<int?> pendingCalendarTabIndex;

  void _openHome(BuildContext context) {
    const HomeRoute().go(context);
    context.read<ChatsCubit>().closeAllChats();
  }

  void _requestCalendarTab(BuildContext context, int index) {
    pendingCalendarTabIndex.value = index;
    const HomeRoute().go(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: context.borderSide),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: spacing.s,
            vertical: spacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: Text(l10n.homeTabChats),
                  icon: Icon(
                    LucideIcons.messagesSquare,
                    size: sizing.menuItemIconSize,
                  ),
                  onPressed: () => _openHome(context),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: Text(l10n.calendarScheduleLabel),
                  icon: Icon(
                    LucideIcons.calendarClock,
                    size: sizing.menuItemIconSize,
                  ),
                  onPressed: calendarAvailable
                      ? () => _requestCalendarTab(context, 0)
                      : null,
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: const TasksTabLabel(),
                  icon: Icon(
                    LucideIcons.squareCheck,
                    size: sizing.menuItemIconSize,
                  ),
                  onPressed: calendarAvailable
                      ? () => _requestCalendarTab(context, 1)
                      : null,
                ),
              ),
              Expanded(
                child: _SettingsBottomNavItem(
                  label: l10n.settingsButtonLabel,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeShellRailLayout extends StatelessWidget {
  const _HomeShellRailLayout({
    required this.tabs,
    required this.homeTabIndex,
    required this.calendarAvailable,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.badgeCounts,
    required this.child,
  });

  final List<HomeTabEntry> tabs;
  final ValueListenable<int> homeTabIndex;
  final bool calendarAvailable;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final Map<HomeTab, int> badgeCounts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, bool>(
      selector: (state) => state.openCalendar,
      builder: (context, calendarActive) {
        return ValueListenableBuilder<int>(
          valueListenable: homeTabIndex,
          builder: (context, selectedIndex, _) {
            if (tabs.isEmpty) {
              return child;
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HomeShellNavigationRail(
                  tabs: tabs,
                  selectedIndex: selectedIndex,
                  collapsed: collapsed,
                  calendarAvailable: calendarAvailable,
                  calendarActive: calendarActive,
                  onCollapsedChanged: onCollapsedChanged,
                  badgeCounts: badgeCounts,
                ),
                Expanded(child: child),
              ],
            );
          },
        );
      },
    );
  }
}

class _HomeShellNavigationRail extends StatelessWidget {
  const _HomeShellNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.collapsed,
    required this.calendarAvailable,
    required this.calendarActive,
    required this.onCollapsedChanged,
    required this.badgeCounts,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final bool collapsed;
  final bool calendarAvailable;
  final bool calendarActive;
  final ValueChanged<bool> onCollapsedChanged;
  final Map<HomeTab, int> badgeCounts;

  void _openCalendar(BuildContext context) {
    const HomeRoute().go(context);
    final chatsCubit = context.read<ChatsCubit>();
    if (!chatsCubit.state.openCalendar) {
      chatsCubit.toggleCalendar();
    }
  }

  void _selectHomeTab(BuildContext context, int index) {
    HomeShellScope.maybeOf(context)?.homeTabIndex.value = index;
    const HomeRoute().go(context);
    if (context.read<ChatsCubit>().state.openCalendar) {
      context.read<ChatsCubit>().toggleCalendar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _HomeNavigationRail(
      tabs: tabs,
      selectedIndex: selectedIndex,
      collapsed: collapsed,
      onDestinationSelected: (index) => _selectHomeTab(context, index),
      calendarAvailable: calendarAvailable,
      calendarActive: calendarActive,
      onCalendarSelected: () => _openCalendar(context),
      onCollapsedChanged: onCollapsedChanged,
      badgeCounts: badgeCounts,
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
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
      widthBehavior: AxiButtonWidth.expand,
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

class _SettingsBottomNavItem extends StatelessWidget {
  const _SettingsBottomNavItem({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final sizing = context.sizing;
        return _BottomNavItem(
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
              context.go(const ProfileRoute().location, extra: context.read),
        );
      },
    );
  }
}

class _TabActionGroup extends StatelessWidget {
  const _TabActionGroup({
    this.includePrimaryActions = false,
    this.extraActions = const <Widget>[],
  });

  final bool includePrimaryActions;
  final List<Widget> extraActions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final locate = context.read;
    final actions = <Widget>[];
    if (includePrimaryActions) {
      actions.addAll([
        ChatsFilterButton(locate: locate),
        const DraftButton(),
        const ChatsAddButton(),
      ]);
    }
    actions.addAll(extraActions);
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: spacing.s, runSpacing: spacing.s, children: actions);
  }
}

class _AccessibilityFindActionRailItem extends StatelessWidget {
  const _AccessibilityFindActionRailItem({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    if (collapsed) {
      return AxiIconButton.ghost(
        iconData: LucideIcons.lifeBuoy,
        tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
        onPressed: () => context.read<AccessibilityActionBloc>().add(
              const AccessibilityMenuOpened(),
            ),
      );
    }
    final label = l10n.accessibilityActionsLabel;
    return AxiListButton(
      collapsed: collapsed,
      collapsedIconData: LucideIcons.lifeBuoy,
      collapsedTooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
      collapsedSemanticLabel: label,
      leading: const Icon(LucideIcons.lifeBuoy),
      child: Text(label, overflow: TextOverflow.ellipsis),
      onPressed: () => context.read<AccessibilityActionBloc>().add(
            const AccessibilityMenuOpened(),
          ),
    );
  }
}

class _HomeNavigationRailFooter extends StatelessWidget {
  const _HomeNavigationRailFooter({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    items.add(_AccessibilityFindActionRailItem(collapsed: collapsed));
    if (items.isNotEmpty) {
      items.add(SizedBox(height: context.spacing.m));
    }
    items.add(_ProfileRailItem(collapsed: collapsed));
    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _ProfileRailItem extends StatelessWidget {
  const _ProfileRailItem({required this.collapsed});

  final bool collapsed;

  void _openSettings(BuildContext context) {
    context.push(const ProfileRoute().location, extra: context.read);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.settingsButtonLabel;
    final sizing = context.sizing;
    final textTheme = context.textTheme;
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final avatar = AxiAvatar(
          jid: state.jid,
          subscription: m.Subscription.both,
          avatarPath: state.avatarPath,
          presence: null,
          status: null,
          active: false,
          size: sizing.iconButtonSize,
        );
        if (collapsed) {
          return AxiIconButton.ghost(
            iconData: LucideIcons.user,
            icon: avatar,
            tooltip: label,
            semanticLabel: label,
            onPressed: () => _openSettings(context),
          );
        }
        return AxiListButton(
          collapsed: collapsed,
          collapsedIconData: LucideIcons.user,
          collapsedTooltip: label,
          collapsedSemanticLabel: label,
          semanticLabel: label,
          leading: avatar,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                state.username,
                style: textTheme.small.strong,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              Text(
                state.jid,
                style: textTheme.muted,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
          onPressed: () => _openSettings(context),
        );
      },
    );
  }
}

class _FindActionIconButton extends StatelessWidget {
  const _FindActionIconButton();

  @override
  Widget build(BuildContext context) {
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    return AxiIconButton.outline(
      iconData: LucideIcons.lifeBuoy,
      tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
      onPressed: () => context.read<AccessibilityActionBloc>().add(
            const AccessibilityMenuOpened(),
          ),
    );
  }
}

class _SearchToggleButton extends StatelessWidget {
  const _SearchToggleButton({required this.active, this.onPressed});

  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AxiIconButton.outline(
      iconData: LucideIcons.search,
      tooltip: active ? l10n.chatSearchClose : l10n.commonSearch,
      onPressed: onPressed,
    );
  }
}

class _DesktopHomeRefreshButton extends StatelessWidget {
  const _DesktopHomeRefreshButton();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, RequestStatus>(
      selector: (state) => state.refreshStatus,
      builder: (context, status) {
        final isLoading = status.isLoading;
        final l10n = context.l10n;
        return AxiIconButton.ghost(
          iconData: LucideIcons.refreshCw,
          tooltip: l10n.homeSyncTooltip,
          loading: isLoading,
          onPressed: isLoading
              ? null
              : () => context.read<ChatsCubit>().refreshHomeSync(),
        );
      },
    );
  }
}

class _ScaleOnlyFabAnimator extends FloatingActionButtonAnimator {
  const _ScaleOnlyFabAnimator();

  static const Curve _moveCurve = Curves.easeInOutCubic;

  @override
  Offset getOffset({
    required Offset begin,
    required Offset end,
    required double progress,
  }) {
    final t = _moveCurve.transform(progress);
    return Offset.lerp(begin, end, t)!;
  }

  @override
  Animation<double> getScaleAnimation({required Animation<double> parent}) {
    const curveOut = Interval(0.0, 0.5, curve: Curves.easeIn);
    const curveIn = Interval(0.5, 1.0, curve: Curves.easeOut);
    return TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: curveOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.0,
        ).chain(CurveTween(curve: curveIn)),
        weight: 50,
      ),
    ]).animate(parent);
  }

  @override
  Animation<double> getRotationAnimation({required Animation<double> parent}) =>
      const AlwaysStoppedAnimation<double>(0.0);

  @override
  double getAnimationRestart(double previousValue) =>
      FloatingActionButtonAnimator.scaling.getAnimationRestart(previousValue);
}

class _HomeNavigationRail extends StatefulWidget {
  const _HomeNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.collapsed,
    required this.onDestinationSelected,
    required this.calendarAvailable,
    required this.calendarActive,
    required this.onCalendarSelected,
    required this.badgeCounts,
    this.onCollapsedChanged,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onDestinationSelected;
  final bool calendarAvailable;
  final bool calendarActive;
  final VoidCallback onCalendarSelected;
  final Map<HomeTab, int> badgeCounts;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<_HomeNavigationRail> createState() => _HomeNavigationRailState();
}

class _HomeNavigationRailState extends State<_HomeNavigationRail> {
  int _controllerIndex = 0;

  @override
  void initState() {
    super.initState();
    _controllerIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant _HomeNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != _controllerIndex) {
      _controllerIndex = widget.selectedIndex;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selectedIndex = _controllerIndex;
    if (widget.tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final calendarDestinationIndex = _calendarDestinationIndex();
    final destinations = <AxiRailDestination>[];
    for (final tab in widget.tabs) {
      destinations.add(
        AxiRailDestination(
          icon: _tabIcon(tab.id),
          label: tab.label,
          badgeCount: widget.badgeCounts[tab.id] ?? 0,
        ),
      );
      if (calendarDestinationIndex != null &&
          destinations.length == calendarDestinationIndex) {
        destinations.add(
          AxiRailDestination(
            icon: LucideIcons.calendarClock,
            label: l10n.homeRailCalendar,
          ),
        );
      }
    }
    final safeTabIndex = selectedIndex.clamp(0, widget.tabs.length - 1).toInt();
    final selectedRailIndex =
        widget.calendarActive && calendarDestinationIndex != null
            ? calendarDestinationIndex
            : _destinationIndexForTab(safeTabIndex, calendarDestinationIndex);
    final effectiveSelectedIndex =
        selectedRailIndex.clamp(0, destinations.length - 1).toInt();
    return SafeArea(
      left: false,
      right: false,
      child: AxiNavigationRail(
        destinations: destinations,
        selectedIndex: effectiveSelectedIndex,
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onCollapsedChanged == null
            ? null
            : () => widget.onCollapsedChanged!(!widget.collapsed),
        toggleExpandedTooltip: l10n.homeRailHideMenu,
        toggleCollapsedTooltip: l10n.homeRailShowMenu,
        backgroundColor: context.colorScheme.background,
        footer: _HomeNavigationRailFooter(collapsed: widget.collapsed),
        onDestinationSelected: (index) {
          final calendarIndex = _calendarDestinationIndex();
          if (calendarIndex != null && index == calendarIndex) {
            widget.onCalendarSelected();
            return;
          }
          final tabIndex = _tabIndexForDestination(index, calendarIndex);
          if (tabIndex == null) return;
          if (widget.calendarActive) {
            widget.onCalendarSelected();
          }
          setState(() => _controllerIndex = tabIndex);
          widget.onDestinationSelected(tabIndex);
        },
      ),
    );
  }

  int? _calendarDestinationIndex() {
    if (!widget.calendarAvailable) return null;
    final chatIndex = widget.tabs.indexWhere(
      (entry) => entry.id == HomeTab.chats,
    );
    if (chatIndex == -1) {
      return widget.tabs.length;
    }
    return chatIndex + 1;
  }

  int _destinationIndexForTab(int tabIndex, int? calendarDestinationIndex) {
    if (calendarDestinationIndex == null) return tabIndex;
    return tabIndex >= calendarDestinationIndex ? tabIndex + 1 : tabIndex;
  }

  int? _tabIndexForDestination(
    int destinationIndex,
    int? calendarDestinationIndex,
  ) {
    if (calendarDestinationIndex == null) return destinationIndex;
    if (destinationIndex == calendarDestinationIndex) {
      return null;
    }
    if (destinationIndex > calendarDestinationIndex) {
      return destinationIndex - 1;
    }
    return destinationIndex;
  }
}

IconData _tabIcon(HomeTab tab) {
  switch (tab) {
    case HomeTab.chats:
      return LucideIcons.messagesSquare;
    case HomeTab.contacts:
      return LucideIcons.users;
    case HomeTab.invites:
      return LucideIcons.userPlus;
    case HomeTab.blocked:
      return LucideIcons.userX;
    case HomeTab.spam:
      return LucideIcons.shieldAlert;
    case HomeTab.drafts:
      return LucideIcons.fileText;
  }
}

ConnectionState _xmppStateForHome(
  ConnectivityState state, {
  required bool demoOffline,
}) {
  if (demoOffline) return ConnectionState.connected;
  return switch (state) {
    ConnectivityConnected() => ConnectionState.connected,
    ConnectivityConnecting() => ConnectionState.connecting,
    ConnectivityError() => ConnectionState.error,
    ConnectivityNotConnected() => ConnectionState.notConnected,
  };
}

String _rosterFailureToastMessage(
  BuildContext context,
  RosterActionFailure failure,
) {
  final l10n = context.l10n;
  return switch (failure.reason) {
    RosterFailureReason.invalidJid => l10n.jidInputInvalid,
    RosterFailureReason.addFailed ||
    RosterFailureReason.removeFailed ||
    RosterFailureReason.rejectFailed =>
      l10n.authGenericError,
  };
}

String _rosterSuccessToastMessage(
  BuildContext context,
  RosterActionSuccess success,
) {
  final l10n = context.l10n;
  return l10n.commonDone;
}

class _HomeSearchPanel extends StatefulWidget {
  const _HomeSearchPanel({required this.tabs});

  final List<HomeTabEntry> tabs;

  @override
  State<_HomeSearchPanel> createState() => _HomeSearchPanelState();
}

class _HomeSearchPanelState extends State<_HomeSearchPanel> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  var _programmaticChange = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChanged() {
    if (_programmaticChange) return;
    context.read<HomeSearchCubit>().updateQuery(_controller.text);
    setState(() {});
  }

  void _syncController(String text) {
    if (_controller.text == text) return;
    _programmaticChange = true;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _programmaticChange = false;
    setState(() {});
  }

  String _filterLabel(List<HomeSearchFilter> filters, SearchFilterId? id) {
    for (final filter in filters) {
      if (filter.id == id) return filter.label;
    }
    return filters.isNotEmpty ? filters.first.label : '';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeSearchCubit, HomeSearchState>(
      listener: (context, state) {
        final query = state.currentTabState?.query ?? '';
        _syncController(query);
        if (state.active) {
          if (!mounted || _focusNode.hasFocus) return;
          _focusNode.requestFocus();
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
        final spacing = context.spacing;
        final active = state.active;
        final tab = state.activeTab;
        final entry = tab == null
            ? (widget.tabs.isEmpty ? null : widget.tabs.first)
            : widget.tabs.firstWhere(
                (candidate) => candidate.id == tab,
                orElse: () => widget.tabs.first,
              );
        final filters = entry?.searchFilters ?? const <HomeSearchFilter>[];
        final currentTabState = tab == null ? null : state.stateFor(tab);
        final sortValue = currentTabState?.sort ?? SearchSortOrder.newestFirst;
        final selectedFilterId = currentTabState?.filterId;
        final effectiveFilterId =
            filters.isEmpty ? null : (selectedFilterId ?? filters.first.id);
        final placeholder = entry == null
            ? l10n.homeSearchPlaceholderTabs
            : l10n.homeSearchPlaceholderForTab(entry.label);
        final filterLabel =
            filters.isEmpty ? null : _filterLabel(filters, effectiveFilterId);
        return AnimatedCrossFade(
          crossFadeState:
              active ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: context.watch<SettingsCubit>().animationDuration,
          reverseDuration: context.watch<SettingsCubit>().animationDuration,
          sizeCurve: Curves.easeInOutCubic,
          firstChild: const SizedBox.shrink(),
          secondChild: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: spacing.m,
              vertical: spacing.s,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.card,
              border: Border(
                bottom: context.borderSide,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: SearchInputField(
                        controller: _controller,
                        focusNode: _focusNode,
                        placeholder: Text(placeholder),
                        clearTooltip: l10n.commonClear,
                        onClear: () =>
                            context.read<HomeSearchCubit>().clearQuery(
                                  tab: tab,
                                ),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    AxiButton.ghost(
                      size: AxiButtonSize.sm,
                      onPressed: () => context
                          .read<HomeSearchCubit>()
                          .setSearchActive(false),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
                SizedBox(height: spacing.s),
                Row(
                  children: [
                    Expanded(
                      child: AxiSelect<SearchSortOrder>(
                        initialValue: sortValue,
                        onChanged: (value) {
                          if (value == null) return;
                          context.read<HomeSearchCubit>().updateSort(
                                value,
                                tab: tab,
                              );
                        },
                        options: SearchSortOrder.values
                            .map(
                              (order) => ShadOption<SearchSortOrder>(
                                value: order,
                                child: Text(order.label(l10n)),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, value) =>
                            Text(value.label(l10n)),
                      ),
                    ),
                    if (filters.length > 1 && effectiveFilterId != null) ...[
                      SizedBox(width: spacing.s),
                      Expanded(
                        child: AxiSelect<SearchFilterId>(
                          initialValue: effectiveFilterId,
                          onChanged: (value) {
                            context.read<HomeSearchCubit>().updateFilter(
                                  value,
                                  tab: tab,
                                );
                          },
                          options: filters
                              .map(
                                (filter) => ShadOption<SearchFilterId>(
                                  value: filter.id,
                                  child: Text(filter.label),
                                ),
                              )
                              .toList(),
                          selectedOptionBuilder: (_, value) =>
                              Text(_filterLabel(filters, value)),
                        ),
                      ),
                    ],
                  ],
                ),
                if (filterLabel != null && filters.length > 1)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: EdgeInsets.only(top: spacing.s),
                      child: Text(
                        l10n.homeSearchFilterLabel(filterLabel),
                        style: context.textTheme.muted,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
