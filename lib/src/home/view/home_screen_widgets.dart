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

  void _triggerDemoInteractivePhase() {
    if (_demoPhase != _HomeDemoPhase.idle) return;
    setState(() => _demoPhase = _HomeDemoPhase.triggered);
    final locate = context.read;
    locate<ChatsCubit>().startDemoInteractivePhase();
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
  }

  void _handleTabChanged() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    _notifyTabIndex(controller.index);
  }

  void _notifyTabIndex(int index) {
    if (index < 0 || index >= widget.tabs.length) return;
    final locate = context.read;
    locate<HomeSearchCubit>().setActiveTab(widget.tabs[index].id);
    HomeShellScope.maybeOf(context)?.homeTabIndex.value = index;
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChanged);
    super.dispose();
  }

  void _handleDemoResetRevisionChanged() {
    if (!kEnableDemoChats || _demoPhase == _HomeDemoPhase.idle) return;
    setState(() => _demoPhase = _HomeDemoPhase.idle);
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) =>
          previous.demoResetRevision != current.demoResetRevision,
      listener: (_, _) => _handleDemoResetRevisionChanged(),
      child: BlocBuilder<HomeSearchCubit, HomeSearchState>(
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
      ),
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
    final locate = context.read;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final selectedChats = chatsState.selectedJids.isEmpty
        ? const <m.Chat>[]
        : chatItems
              .where((chat) => chatsState.selectedJids.contains(chat.jid))
              .toList();
    final badgeCounts = <HomeTab, int>{
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam && !chat.hidden)
          .fold<int>(
            0,
            (sum, chat) => sum + (chat.unreadCount > 0 ? chat.unreadCount : 0),
          ),
      HomeTab.drafts: context.watch<DraftCubit>().state.items?.length ?? 0,
      HomeTab.spam: chatItems
          .where((chat) => chat.spam && !chat.archived)
          .length,
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
          onPressed: () => locate<AccessibilityActionBloc>().add(
            const AccessibilityMenuOpened(),
          ),
        ),
      if (EnvScope.of(context).isDesktopPlatform)
        AppBarActionItem(
          label: l10n.homeSyncTooltip,
          iconData: LucideIcons.refreshCw,
          inline: const _DesktopHomeRefreshButton(),
          onPressed: () => locate<ChatsCubit>().refreshHomeSync(),
        ),
      AppBarActionItem(
        label: searchState.active ? l10n.chatSearchClose : l10n.commonSearch,
        iconData: LucideIcons.search,
        inline: _SearchToggleButton(
          active: searchState.active,
          onPressed: () => locate<HomeSearchCubit>().toggleSearch(),
        ),
        onPressed: () => locate<HomeSearchCubit>().toggleSearch(),
      ),
    ];
    final header = _NexusHeader(tabs: tabs, headerActions: headerActions);
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
    final topTabs = _NexusTopTabs(
      navPlacement: navPlacement,
      tabs: tabs,
      selectedChats: selectedChats,
      badgeCounts: badgeCounts,
    );
    final bottomArea = _NexusBottomArea(selectedChats: selectedChats);
    final HomeTab? activeTab;
    if (tabs.isEmpty) {
      activeTab = null;
    } else {
      final safeSelectedIndex = selectedIndex.clamp(0, tabs.length - 1).toInt();
      activeTab = tabs[safeSelectedIndex].id;
    }
    final tabContent = _NexusPullToRefresh(
      navPlacement: navPlacement,
      activeTab: activeTab,
      child: Column(
        children: [
          topTabs,
          Expanded(child: tabViews),
        ],
      ),
    );
    final column = Column(
      children: [
        header,
        Expanded(child: tabContent),
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
            profileActive: false,
            onCalendarSelected: () {},
            badgeCounts: badgeCounts,
            onCollapsedChanged: onToggleNavRail == null
                ? null
                : (_) => onToggleNavRail!(),
          ),
          Expanded(child: column),
        ],
      );
    }

    return column;
  }
}

class _NexusHeader extends StatelessWidget {
  const _NexusHeader({required this.tabs, required this.headerActions});

  final List<HomeTabEntry> tabs;
  final List<AppBarActionItem> headerActions;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiAppBar(
          showTitle: false,
          leading: const _TransportStatusChips(),
          trailing: AppBarActions(
            actions: headerActions,
            spacing: spacing.s,
            forceCollapsed: false,
          ),
        ),
        _HomeSearchPanel(tabs: tabs),
      ],
    );
  }
}

class _TransportStatusChips extends StatelessWidget {
  const _TransportStatusChips();

  @override
  Widget build(BuildContext context) {
    final demoOffline =
        kEnableDemoChats &&
        context.select<ProfileCubit, String>(
              (stateOwner) => stateOwner.state.jid,
            ) ==
            kDemoSelfJid;
    return BlocBuilder<ConnectivityCubit, ConnectivityState>(
      builder: (context, connectivityState) {
        final connectionState = _xmppStateForHome(
          connectivityState,
          demoOffline: demoOffline,
        );
        final sessionEmailState = demoOffline
            ? const EmailSyncState.ready()
            : connectivityState.emailState;
        final emailEnabled = demoOffline
            ? true
            : connectivityState.emailEnabled;
        final indicator = Align(
          alignment: Alignment.centerLeft,
          child: SessionCapabilityIndicators(
            xmppState: connectionState,
            emailState: sessionEmailState,
            emailEnabled: emailEnabled,
            compact: true,
          ),
        );
        return indicator;
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
      child: TabBarView(
        physics: tabViewPhysics,
        children: tabs.map((tab) {
          final floatingActionButton = selectedChats.isNotEmpty
              ? null
              : tab.fab;
          return Scaffold(
            resizeToAvoidBottomInset: false,
            extendBodyBehindAppBar: true,
            body: tab.body,
            floatingActionButtonAnimator: const _ScaleOnlyFabAnimator(),
            floatingActionButton: floatingActionButton == null
                ? null
                : Padding(
                    padding: EdgeInsets.only(bottom: context.spacing.xs),
                    child: floatingActionButton,
                  ),
          );
        }).toList(),
      ),
    );
  }
}

class _NexusTopTabs extends StatelessWidget {
  const _NexusTopTabs({
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
    if (navPlacement == NavPlacement.bottom && selectedChats.isEmpty) {
      final controller = DefaultTabController.maybeOf(context);
      if (controller == null) {
        return const SizedBox.shrink();
      }
      return Padding(
        padding: EdgeInsets.only(top: context.spacing.s),
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return _HomeBottomTabBar(
              tabs: tabs,
              badgeCounts: badgeCounts,
              selectedIndex: controller.index,
              onTabSelected: (index) {
                if (index == controller.index || controller.indexIsChanging) {
                  return;
                }
                controller.animateTo(index);
              },
            );
          },
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _NexusBottomArea extends StatelessWidget {
  const _NexusBottomArea({required this.selectedChats});

  final List<m.Chat> selectedChats;

  @override
  Widget build(BuildContext context) {
    if (selectedChats.isEmpty) {
      return const SizedBox.shrink();
    }
    return ChatSelectionActionBar(selectedChats: selectedChats);
  }
}

class _NexusPullToRefresh extends StatelessWidget {
  const _NexusPullToRefresh({
    required this.navPlacement,
    required this.activeTab,
    required this.child,
  });

  final NavPlacement navPlacement;
  final HomeTab? activeTab;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (navPlacement != NavPlacement.bottom || activeTab != HomeTab.chats) {
      return child;
    }
    final spacing = context.spacing;
    final sizing = context.sizing;
    final refreshSpinnerExtent = sizing.buttonHeightLg + spacing.s;
    final refreshSpinnerDimension = sizing.progressIndicatorSize + spacing.xs;
    final refreshOffsetToArmed = spacing.xxl;
    final refreshRevealThreshold = context.motion.tapHoverAlpha;
    final refreshIndicatorPadding = spacing.m;
    return CustomRefreshIndicator(
      onRefresh: () => context.read<ChatsCubit>().refreshHomeSync(),
      offsetToArmed: refreshOffsetToArmed,
      triggerMode: IndicatorTriggerMode.anywhere,
      notificationPredicate: (notification) =>
          notification.metrics.axis == Axis.vertical,
      leadingScrollIndicatorVisible: true,
      builder: (context, child, controller) {
        final clamped = controller.value.clamp(0.0, 1.0).toDouble();
        final isLeadingPull = controller.hasEdge && controller.edge!.isLeading;
        final isActive =
            controller.isLoading || (isLeadingPull && !controller.state.isIdle);
        final isRevealed = isActive && (controller.isLoading || clamped > 0.0);
        final revealFactor = isRevealed
            ? (controller.isLoading ? 1.0 : clamped)
            : 0.0;

        final revealedExtent = refreshSpinnerExtent * revealFactor;
        final isArmed = controller.state.isArmed;
        final showIndicator =
            isLeadingPull &&
            (controller.isLoading || clamped > refreshRevealThreshold);
        final indicatorContent = !showIndicator
            ? const SizedBox.shrink()
            : controller.isLoading
            ? AxiProgressIndicator(color: context.colorScheme.primary)
            : AnimatedRotation(
                turns: isArmed ? 0.5 : 0.0,
                duration: baseAnimationDuration,
                curve: Curves.easeOutCubic,
                child: Icon(
                  LucideIcons.arrowDown,
                  size: refreshSpinnerDimension,
                  color: context.colorScheme.primary,
                ),
              );

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: revealFactor,
                    child: SizedBox(
                      height: refreshSpinnerExtent,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colorScheme.card,
                          border: Border(bottom: context.borderSide),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: refreshIndicatorPadding,
                            ),
                            child: indicatorContent,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, revealedExtent),
              child: child,
            ),
          ],
        );
      },
      child: child,
    );
  }
}

class _HomeBottomTabBar extends StatelessWidget {
  const _HomeBottomTabBar({
    required this.tabs,
    required this.badgeCounts,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<HomeTabEntry> tabs;
  final Map<HomeTab, int> badgeCounts;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    if (tabs.isEmpty) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    final sizing = context.sizing;
    final colors = context.colorScheme;
    final motion = context.motion;
    final shadTheme = ShadTheme.of(context);
    const tabDecoration = ShadDecoration(
      color: Colors.transparent,
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );
    final animationDuration = context.watch<SettingsCubit>().animationDuration;
    final int safeSelectedIndex = selectedIndex
        .clamp(0, tabs.length - 1)
        .toInt();
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(spacing.m, 0, spacing.m, 0),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border.all(
            color: colors.border,
            width: context.borderSide.width,
          ),
          borderRadius: BorderRadius.circular(context.radii.container),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(context.radii.container),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = tabs.isEmpty
                  ? 0.0
                  : constraints.maxWidth / tabs.length;
              final horizontalIndicatorInset = spacing.xs;
              final verticalIndicatorInset = spacing.xs;
              final indicatorWidth = math.max(
                0.0,
                tabWidth - (horizontalIndicatorInset * 2),
              );
              return Stack(
                children: [
                  AnimatedPositionedDirectional(
                    duration: animationDuration,
                    curve: Curves.easeInOutCubic,
                    start:
                        (tabWidth * safeSelectedIndex) +
                        horizontalIndicatorInset,
                    top: verticalIndicatorInset,
                    bottom: verticalIndicatorInset,
                    width: indicatorWidth,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(
                          alpha: motion.tapSplashAlpha,
                        ),
                        borderRadius: BorderRadius.circular(
                          context.radii.container,
                        ),
                      ),
                    ),
                  ),
                  ShadTheme(
                    data: shadTheme.copyWith(
                      tabsTheme: shadTheme.tabsTheme.copyWith(
                        tabDecoration: tabDecoration,
                        tabSelectedDecoration: tabDecoration,
                        tabBackgroundColor: Colors.transparent,
                        tabSelectedBackgroundColor: Colors.transparent,
                        tabHoverBackgroundColor: Colors.transparent,
                        tabSelectedHoverBackgroundColor: Colors.transparent,
                        tabShadows: const <BoxShadow>[],
                        tabSelectedShadows: const <BoxShadow>[],
                      ),
                    ),
                    child: ShadTabs<int>(
                      value: safeSelectedIndex,
                      scrollable: false,
                      tabsGap: 0,
                      gap: 0,
                      padding: EdgeInsets.zero,
                      decoration: const ShadDecoration(
                        color: Colors.transparent,
                        border: ShadBorder.none,
                        secondaryBorder: ShadBorder.none,
                        secondaryFocusedBorder: ShadBorder.none,
                        focusedBorder: ShadBorder.none,
                        errorBorder: ShadBorder.none,
                        secondaryErrorBorder: ShadBorder.none,
                        disableSecondaryBorder: true,
                      ),
                      onChanged: (value) {
                        if (value != safeSelectedIndex) {
                          onTabSelected(value);
                        }
                      },
                      tabs: List<ShadTab<int>>.generate(tabs.length, (index) {
                        final tab = tabs[index];
                        return ShadTab<int>(
                          value: index,
                          height: sizing.iconButtonSize,
                          decoration: tabDecoration,
                          backgroundColor: Colors.transparent,
                          selectedBackgroundColor: Colors.transparent,
                          hoverBackgroundColor: Colors.transparent,
                          selectedHoverBackgroundColor: Colors.transparent,
                          pressedBackgroundColor: Colors.transparent,
                          shadows: const <BoxShadow>[],
                          selectedShadows: const <BoxShadow>[],
                          foregroundColor: colors.foreground,
                          selectedForegroundColor: colors.foreground,
                          child: _HomeBottomTabItem(
                            label: tab.label,
                            badgeCount: badgeCounts[tab.id] ?? 0,
                            selected: index == safeSelectedIndex,
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeBottomTabItem extends StatelessWidget {
  const _HomeBottomTabItem({
    required this.label,
    required this.badgeCount,
    required this.selected,
  });

  final String label;
  final int badgeCount;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final Duration animationDuration = context
        .watch<SettingsCubit>()
        .animationDuration;
    final badgeDiameter = sizing.iconButtonIconSize;
    final endPadding = badgeCount > 0 ? spacing.s : spacing.xs;
    return SizedBox(
      height: sizing.iconButtonSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Center(
            child: AnimatedScale(
              duration: animationDuration,
              curve: Curves.easeInOutCubic,
              scale: selected ? 1.04 : 1,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: spacing.xs,
                  end: endPadding,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: context.textTheme.small.strongIf(selected),
                ),
              ),
            ),
          ),
          if (badgeCount > 0)
            PositionedDirectional(
              top: -spacing.xs,
              end: -spacing.xs,
              child: AxiCountBadge(count: badgeCount, diameter: badgeDiameter),
            ),
        ],
      ),
    );
  }
}

class _HomeShellBottomBar extends StatelessWidget {
  const _HomeShellBottomBar({
    required this.calendarBottomDragSession,
    required this.selectedBottomIndex,
    required this.onBottomNavSelected,
    required this.calendarAvailable,
  });

  final ValueNotifier<CalendarBottomDragSession?> calendarBottomDragSession;
  final int selectedBottomIndex;
  final ValueChanged<int> onBottomNavSelected;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    return _HomeShellDefaultBar(
      calendarAvailable: calendarAvailable,
      calendarBottomDragSession: calendarBottomDragSession,
      selectedBottomIndex: selectedBottomIndex,
      onBottomNavSelected: onBottomNavSelected,
    );
  }
}

class _HomeShellDefaultBar extends StatefulWidget {
  const _HomeShellDefaultBar({
    required this.calendarAvailable,
    required this.calendarBottomDragSession,
    required this.selectedBottomIndex,
    required this.onBottomNavSelected,
  });

  final bool calendarAvailable;
  final ValueNotifier<CalendarBottomDragSession?> calendarBottomDragSession;
  final int selectedBottomIndex;
  final ValueChanged<int> onBottomNavSelected;

  @override
  State<_HomeShellDefaultBar> createState() => _HomeShellDefaultBarState();
}

class _HomeShellDefaultBarState extends State<_HomeShellDefaultBar> {
  final GlobalKey _bottomNavBarKey = GlobalKey(
    debugLabel: 'home-bottom-nav-bar',
  );
  Timer? _calendarDragSwitchTimer;
  int? _hoveredCalendarTargetTab;

  @override
  void initState() {
    super.initState();
    widget.calendarBottomDragSession.addListener(_handleCalendarDragSignal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _handleCalendarDragSignal();
  }

  @override
  void didUpdateWidget(covariant _HomeShellDefaultBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.calendarBottomDragSession !=
        widget.calendarBottomDragSession) {
      oldWidget.calendarBottomDragSession.removeListener(
        _handleCalendarDragSignal,
      );
      widget.calendarBottomDragSession.addListener(_handleCalendarDragSignal);
    }
    _handleCalendarDragSignal();
  }

  @override
  void dispose() {
    widget.calendarBottomDragSession.removeListener(_handleCalendarDragSignal);
    _cancelCalendarDragSwitchTimer();
    super.dispose();
  }

  int _clampBottomNavIndex(int index) => index.clamp(0, 3).toInt();

  int _calendarTargetToBottomNavIndex(int calendarTabIndex) =>
      calendarTabIndex == 0 ? 1 : 2;

  void _setBottomNavIndex(int index) {
    assert(index >= 0 && index <= 3, 'bottom nav index must be 0..3');
    if (index < 0 || index > 3) {
      return;
    }
    widget.onBottomNavSelected(index);
    if (index != 0) {
      return;
    }
    final scope = HomeShellScope.maybeOf(context);
    if (scope?.bottomNavIndex.value == 0) {
      scope?.homeTabIndex.value = 0;
    }
  }

  int? _normalizeCalendarTabIndex(int? value) {
    if (value == null) {
      return null;
    }
    if (value == 0 || value == 1) {
      return value;
    }
    return null;
  }

  Rect? _calendarTabRectForIndex(int index) {
    const int bottomNavTabCount = 4;
    final BuildContext? navContext = _bottomNavBarKey.currentContext;
    final RenderBox? box = navContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    final Size size = box.size;
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      return null;
    }
    final Offset origin = box.localToGlobal(Offset.zero);
    final double tabWidth = size.width / bottomNavTabCount;
    final int bottomNavIndex = _calendarTargetToBottomNavIndex(
      index,
    ).clamp(0, bottomNavTabCount - 1).toInt();
    return Rect.fromLTWH(
      origin.dx + (tabWidth * bottomNavIndex),
      origin.dy,
      tabWidth,
      size.height,
    );
  }

  void _cancelCalendarDragSwitchTimer() {
    _calendarDragSwitchTimer?.cancel();
    _calendarDragSwitchTimer = null;
  }

  void _setHoveredCalendarTargetTab(int? targetTab) {
    if (_hoveredCalendarTargetTab == targetTab) {
      return;
    }
    _cancelCalendarDragSwitchTimer();
    if (!mounted) {
      _hoveredCalendarTargetTab = targetTab;
      return;
    }
    setState(() {
      _hoveredCalendarTargetTab = targetTab;
    });
  }

  void _setCalendarDragCleared() {
    if (_hoveredCalendarTargetTab == null) {
      return;
    }
    _cancelCalendarDragSwitchTimer();
    if (!mounted) {
      _hoveredCalendarTargetTab = null;
      return;
    }
    setState(() {
      _hoveredCalendarTargetTab = null;
    });
  }

  void _scheduleCalendarDragSwitch(int targetTab) {
    if (_hoveredCalendarTargetTab != targetTab) {
      return;
    }
    if (_calendarDragSwitchTimer?.isActive == true) {
      return;
    }
    final locate = context.read;
    final duration = locate<SettingsCubit>().animationDuration;
    _calendarDragSwitchTimer = Timer(duration, () {
      if (!mounted) {
        return;
      }
      if (_hoveredCalendarTargetTab != targetTab) {
        return;
      }
      if (widget.calendarBottomDragSession.value == null) {
        return;
      }
      final selectedIndex = _clampBottomNavIndex(widget.selectedBottomIndex);
      final openCalendar = selectedIndex == 1 || selectedIndex == 2;
      final chatsState = locate<ChatsCubit>().state;
      final chatCalendarActive =
          chatsState.openJid != null && chatsState.openChatRoute.isCalendar;
      if (!widget.calendarAvailable || (!openCalendar && !chatCalendarActive)) {
        return;
      }
      _setBottomNavIndex(_calendarTargetToBottomNavIndex(targetTab));
      setState(() {
        _hoveredCalendarTargetTab = null;
      });
      _cancelCalendarDragSwitchTimer();
    });
  }

  void _handleCalendarDragSignal() {
    if (!mounted) {
      return;
    }
    final CalendarBottomDragSession? dragSession =
        widget.calendarBottomDragSession.value;
    final int selectedIndex = _clampBottomNavIndex(widget.selectedBottomIndex);
    final int? sourceTab = dragSession == null
        ? null
        : _normalizeCalendarTabIndex(dragSession.sourceTab) ??
              _normalizeCalendarTabIndex(
                selectedIndex == 2 ? 1 : selectedIndex,
              );
    if (sourceTab == null) {
      _setCalendarDragCleared();
      return;
    }
    final bool openCalendar = selectedIndex == 1 || selectedIndex == 2;
    final locate = context.read;
    final chatsState = locate<ChatsCubit>().state;
    final chatCalendarActive =
        chatsState.openJid != null && chatsState.openChatRoute.isCalendar;
    if (!widget.calendarAvailable || (!openCalendar && !chatCalendarActive)) {
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final Offset? pointer = dragSession?.pointer;
    if (pointer == null) {
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final int targetTab = sourceTab == 0 ? 1 : 0;
    final Rect? targetRect = _calendarTabRectForIndex(targetTab);
    if (targetRect == null) {
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final Rect hitRect = targetRect.inflate(context.spacing.s);
    if (!hitRect.contains(pointer)) {
      _setHoveredCalendarTargetTab(null);
      return;
    }
    _setHoveredCalendarTargetTab(targetTab);
    _scheduleCalendarDragSwitch(targetTab);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final sizing = context.sizing;
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final chatsState = context.watch<ChatsCubit>().state;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final unreadChatsCount = chatItems
        .where((chat) => !chat.archived && !chat.spam && !chat.hidden)
        .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount));
    final draftsCount = context.watch<DraftCubit>().state.items?.length ?? 0;
    final spamCount = chatItems
        .where((chat) => chat.spam && !chat.archived)
        .length;
    final chatsBadgeCount = unreadChatsCount + draftsCount + spamCount;
    int scheduledAlertsCount = 0;
    int unscheduledAlertsCount = 0;
    if (widget.calendarAvailable) {
      final tasks = context.watch<CalendarBloc>().state.model.tasks.values;
      for (final task in tasks) {
        if (task.isCompleted) {
          continue;
        }
        final hasReminderOffsets = task.effectiveReminders.isEnabled;
        final hasIcsAlarm = task.icsMeta?.alarms.isNotEmpty ?? false;
        if (!hasReminderOffsets && !hasIcsAlarm) {
          continue;
        }
        if (task.isScheduled) {
          scheduledAlertsCount += 1;
        } else {
          unscheduledAlertsCount += 1;
        }
      }
    }
    final profile = context.watch<ProfileCubit>().state;
    final bool lowMotion = context.watch<SettingsCubit>().state.lowMotion;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: context.borderSide),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.xs,
            end: spacing.xs,
            top: spacing.s,
            bottom: spacing.s,
          ),
          child: ValueListenableBuilder<CalendarBottomDragSession?>(
            valueListenable: widget.calendarBottomDragSession,
            builder: (context, dragSession, _) {
              final int safeSelectedIndex = _clampBottomNavIndex(
                widget.selectedBottomIndex,
              );
              final bool openCalendar =
                  safeSelectedIndex == 1 || safeSelectedIndex == 2;
              final bool chatCalendarActive =
                  chatsState.openJid != null &&
                  chatsState.openChatRoute.isCalendar;
              final int safeCalendarTab = safeSelectedIndex == 2
                  ? 1
                  : safeSelectedIndex == 1
                  ? 0
                  : 0;
              final bool calendarDisabled = !widget.calendarAvailable;
              final Color disabledColor = colors.mutedForeground.withValues(
                alpha: 0.45,
              );
              final homeColor = safeSelectedIndex == 0
                  ? colors.foreground
                  : colors.mutedForeground;
              final scheduleColor = calendarDisabled
                  ? disabledColor
                  : safeSelectedIndex == 1
                  ? colors.foreground
                  : colors.mutedForeground;
              final tasksColor = calendarDisabled
                  ? disabledColor
                  : safeSelectedIndex == 2
                  ? colors.foreground
                  : colors.mutedForeground;
              final int? dragSourceTab = dragSession == null
                  ? null
                  : _normalizeCalendarTabIndex(dragSession.sourceTab) ??
                        safeCalendarTab;
              final bool dragHintActive =
                  !lowMotion &&
                  widget.calendarAvailable &&
                  (openCalendar || chatCalendarActive) &&
                  dragSourceTab != null;
              final bool shakeSchedule = dragHintActive;
              final bool shakeTasks = dragHintActive;
              final avatar = AxiAvatar(
                jid: profile.jid,
                subscription: m.Subscription.both,
                avatarPath: profile.avatarPath,
                loading: profile.avatarHydrating,
                presence: null,
                status: null,
                active: false,
                size: sizing.iconButtonIconSize + spacing.xxs,
              );
              return GNav(
                key: _bottomNavBarKey,
                selectedIndex: safeSelectedIndex,
                duration: context.watch<SettingsCubit>().animationDuration,
                haptic: true,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                tabMargin: EdgeInsets.symmetric(horizontal: spacing.xxs),
                tabBorderRadius: context.radii.squircle,
                curve: Curves.easeInOutCubic,
                gap: spacing.s,
                iconSize: sizing.iconButtonIconSize + spacing.xxs,
                color: colors.mutedForeground,
                activeColor: colors.foreground,
                textStyle: context.textTheme.small.strong,
                tabBackgroundColor: colors.secondary.withValues(
                  alpha: context.motion.tapHoverAlpha,
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.s,
                  vertical: spacing.s,
                ),
                onTabChange: (index) {
                  assert(index >= 0 && index <= 3);
                  if (index == safeSelectedIndex) {
                    return;
                  }
                  if (!widget.calendarAvailable && (index == 1 || index == 2)) {
                    return;
                  }
                  _setBottomNavIndex(index);
                },
                tabs: [
                  GButton(
                    icon: LucideIcons.house,
                    text: l10n.homeBottomNavHome,
                    leading: _HomeBottomNavBadgeIcon(
                      iconData: LucideIcons.house,
                      badgeCount: chatsBadgeCount,
                      color: homeColor,
                      iconSize: sizing.iconButtonIconSize + spacing.xxs,
                    ),
                    iconColor: colors.mutedForeground,
                    iconActiveColor: colors.foreground,
                  ),
                  GButton(
                    icon: LucideIcons.calendarClock,
                    text: l10n.calendarScheduleLabel,
                    leading: _BottomNavShake(
                      enabled: shakeSchedule,
                      child: _HomeBottomNavBadgeIcon(
                        iconData: LucideIcons.calendarClock,
                        badgeCount: scheduledAlertsCount,
                        color: scheduleColor,
                        iconSize: sizing.iconButtonIconSize + spacing.xxs,
                      ),
                    ),
                    iconColor: calendarDisabled
                        ? disabledColor
                        : colors.mutedForeground,
                    iconActiveColor: calendarDisabled
                        ? disabledColor
                        : colors.foreground,
                  ),
                  GButton(
                    icon: LucideIcons.squareCheck,
                    text: l10n.calendarFragmentTaskLabel,
                    leading: _BottomNavShake(
                      enabled: shakeTasks,
                      child: _HomeBottomNavBadgeIcon(
                        iconData: LucideIcons.squareCheck,
                        badgeCount: unscheduledAlertsCount,
                        color: tasksColor,
                        iconSize: sizing.iconButtonIconSize + spacing.xxs,
                      ),
                    ),
                    iconColor: calendarDisabled
                        ? disabledColor
                        : colors.mutedForeground,
                    iconActiveColor: calendarDisabled
                        ? disabledColor
                        : colors.foreground,
                  ),
                  GButton(
                    icon: LucideIcons.user,
                    text: l10n.settingsButtonLabel,
                    leading: avatar,
                    iconColor: colors.mutedForeground,
                    iconActiveColor: colors.foreground,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BottomNavShake extends StatefulWidget {
  const _BottomNavShake({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_BottomNavShake> createState() => _BottomNavShakeState();
}

class _BottomNavShakeState extends State<_BottomNavShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: baseAnimationDuration,
    );
    if (widget.enabled) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant _BottomNavShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled == widget.enabled) {
      return;
    }
    if (widget.enabled) {
      _controller.repeat();
      return;
    }
    _controller.stop();
    _controller.value = 0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }
    final maxAngle =
        (context.spacing.xxs / context.sizing.iconButtonSize) * 2.0;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final phase = _controller.value * math.pi * 2;
        final angle = math.sin(phase) * maxAngle;
        return Transform.rotate(angle: angle, child: child);
      },
      child: widget.child,
    );
  }
}

class _HomeBottomNavBadgeIcon extends StatelessWidget {
  const _HomeBottomNavBadgeIcon({
    required this.iconData,
    required this.badgeCount,
    required this.color,
    required this.iconSize,
  });

  final IconData iconData;
  final int badgeCount;
  final Color color;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final badgeDiameter = context.sizing.iconButtonIconSize;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(iconData, color: color, size: iconSize),
        if (badgeCount > 0)
          PositionedDirectional(
            top: -spacing.s,
            end: -spacing.s,
            child: AxiCountBadge(count: badgeCount, diameter: badgeDiameter),
          ),
      ],
    );
  }
}

class _HomeShellRailLayout extends StatelessWidget {
  const _HomeShellRailLayout({
    required this.tabs,
    required this.homeTabIndex,
    required this.bottomNavIndex,
    required this.selectedBottomIndex,
    required this.calendarAvailable,
    required this.collapsed,
    required this.onCollapsedChanged,
    required this.onBottomNavSelected,
    required this.badgeCounts,
    required this.child,
  });

  final List<HomeTabEntry> tabs;
  final ValueNotifier<int> homeTabIndex;
  final ValueNotifier<int> bottomNavIndex;
  final int selectedBottomIndex;
  final bool calendarAvailable;
  final bool collapsed;
  final ValueChanged<bool> onCollapsedChanged;
  final ValueChanged<int> onBottomNavSelected;
  final Map<HomeTab, int> badgeCounts;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: homeTabIndex,
      builder: (context, selectedIndex, _) {
        if (tabs.isEmpty) {
          return child;
        }
        assert(
          selectedBottomIndex >= 0 && selectedBottomIndex <= 3,
          'bottom nav index must be 0..3',
        );
        final bool profileActive = selectedBottomIndex == 3;
        final bool calendarActive =
            selectedBottomIndex == 1 || selectedBottomIndex == 2;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HomeShellNavigationRail(
              tabs: tabs,
              selectedIndex: selectedIndex,
              homeTabIndex: homeTabIndex,
              bottomNavIndex: bottomNavIndex,
              collapsed: collapsed,
              calendarAvailable: calendarAvailable,
              calendarActive: calendarActive,
              profileActive: profileActive,
              onBottomNavSelected: onBottomNavSelected,
              onCollapsedChanged: onCollapsedChanged,
              badgeCounts: badgeCounts,
            ),
            Expanded(child: child),
          ],
        );
      },
    );
  }
}

class _HomeShellNavigationRail extends StatelessWidget {
  const _HomeShellNavigationRail({
    required this.tabs,
    required this.selectedIndex,
    required this.homeTabIndex,
    required this.bottomNavIndex,
    required this.collapsed,
    required this.calendarAvailable,
    required this.calendarActive,
    required this.profileActive,
    required this.onBottomNavSelected,
    required this.onCollapsedChanged,
    required this.badgeCounts,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final ValueNotifier<int> homeTabIndex;
  final ValueNotifier<int> bottomNavIndex;
  final bool collapsed;
  final bool calendarAvailable;
  final bool calendarActive;
  final bool profileActive;
  final ValueChanged<int> onBottomNavSelected;
  final ValueChanged<bool> onCollapsedChanged;
  final Map<HomeTab, int> badgeCounts;

  void _openCalendar(BuildContext context) {
    assert(
      bottomNavIndex.value >= 0 && bottomNavIndex.value <= 2,
      'bottom nav index must be 0..2',
    );
    final currentIndex = bottomNavIndex.value;
    onBottomNavSelected(currentIndex == 2 ? 2 : 1);
  }

  void _selectHomeTab(BuildContext context, int index) {
    onBottomNavSelected(0);
    homeTabIndex.value = index;
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
      profileActive: profileActive,
      onBottomNavSelected: onBottomNavSelected,
      onCalendarSelected: () => _openCalendar(context),
      onCollapsedChanged: onCollapsedChanged,
      badgeCounts: badgeCounts,
    );
  }
}

class _TabActionGroup extends StatelessWidget {
  const _TabActionGroup({this.includePrimaryActions = false});

  final bool includePrimaryActions;

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
    final locate = context.read;
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    if (collapsed) {
      return AxiIconButton.ghost(
        iconData: LucideIcons.lifeBuoy,
        tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
        onPressed: () => locate<AccessibilityActionBloc>().add(
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
      onPressed: () => locate<AccessibilityActionBloc>().add(
        const AccessibilityMenuOpened(),
      ),
    );
  }
}

class _HomeNavigationRailFooter extends StatelessWidget {
  const _HomeNavigationRailFooter({
    required this.collapsed,
    required this.profileActive,
    required this.onBottomNavSelected,
  });

  final bool collapsed;
  final bool profileActive;
  final ValueChanged<int>? onBottomNavSelected;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    items.add(_AccessibilityFindActionRailItem(collapsed: collapsed));
    if (items.isNotEmpty) {
      items.add(SizedBox(height: context.spacing.m));
    }
    items.add(
      _ProfileRailItem(
        collapsed: collapsed,
        selected: profileActive,
        onBottomNavSelected: onBottomNavSelected,
      ),
    );
    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _ProfileRailItem extends StatelessWidget {
  const _ProfileRailItem({
    required this.collapsed,
    required this.selected,
    required this.onBottomNavSelected,
  });

  final bool collapsed;
  final bool selected;
  final ValueChanged<int>? onBottomNavSelected;

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
          loading: state.avatarHydrating,
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
            selected: selected,
            onPressed: onBottomNavSelected == null
                ? null
                : () => onBottomNavSelected!(3),
          );
        }
        return AxiListButton(
          selected: selected,
          collapsed: collapsed,
          collapsedIconData: LucideIcons.user,
          collapsedTooltip: label,
          collapsedSemanticLabel: label,
          semanticLabel: label,
          leading: avatar,
          onPressed: onBottomNavSelected == null
              ? null
              : () => onBottomNavSelected!(3),
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
        );
      },
    );
  }
}

class _FindActionIconButton extends StatelessWidget {
  const _FindActionIconButton();

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    return AxiIconButton.outline(
      iconData: LucideIcons.lifeBuoy,
      tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
      onPressed: () => locate<AccessibilityActionBloc>().add(
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
        final locate = context.read;
        final isLoading = status.isLoading;
        final l10n = context.l10n;
        return AxiIconButton.outline(
          iconData: LucideIcons.refreshCw,
          tooltip: l10n.homeSyncTooltip,
          loading: isLoading,
          onPressed: isLoading
              ? null
              : () => locate<ChatsCubit>().refreshHomeSync(),
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
    required this.profileActive,
    this.onBottomNavSelected,
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
  final bool profileActive;
  final ValueChanged<int>? onBottomNavSelected;
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
    assert(
      selectedIndex >= 0 && selectedIndex < widget.tabs.length,
      'selectedIndex must be within tab bounds',
    );
    final effectiveSelectedIndex =
        widget.calendarActive && calendarDestinationIndex != null
        ? calendarDestinationIndex
        : _destinationIndexForTab(selectedIndex, calendarDestinationIndex);
    assert(
      effectiveSelectedIndex >= 0 &&
          effectiveSelectedIndex < destinations.length,
      'effectiveSelectedIndex must be within destination bounds',
    );
    return SafeArea(
      left: false,
      right: false,
      child: AxiNavigationRail(
        destinations: destinations,
        selectedIndex: effectiveSelectedIndex,
        showSelection: !widget.profileActive,
        collapsed: widget.collapsed,
        onToggleCollapse: widget.onCollapsedChanged == null
            ? null
            : () => widget.onCollapsedChanged!(!widget.collapsed),
        toggleExpandedTooltip: l10n.homeRailHideMenu,
        toggleCollapsedTooltip: l10n.homeRailShowMenu,
        backgroundColor: context.colorScheme.background,
        footer: _HomeNavigationRailFooter(
          collapsed: widget.collapsed,
          profileActive: widget.profileActive,
          onBottomNavSelected: widget.onBottomNavSelected,
        ),
        onDestinationSelected: (index) {
          final calendarIndex = _calendarDestinationIndex();
          if (calendarIndex != null && index == calendarIndex) {
            widget.onCalendarSelected();
            return;
          }
          final tabIndex = _tabIndexForDestination(index, calendarIndex);
          if (tabIndex == null) return;
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
    case HomeTab.important:
      return Icons.star_rounded;
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
    RosterFailureReason.rejectFailed => l10n.authGenericError,
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
    final locate = context.read;
    locate<HomeSearchCubit>().updateQuery(_controller.text);
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
        final locate = context.read;
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
        final effectiveFilterId = filters.isEmpty
            ? null
            : (selectedFilterId ?? filters.first.id);
        final placeholder = entry == null
            ? l10n.homeSearchPlaceholderTabs
            : l10n.homeSearchPlaceholderForTab(entry.label);
        final filterLabel = filters.isEmpty
            ? null
            : _filterLabel(filters, effectiveFilterId);
        return AnimatedCrossFade(
          crossFadeState: active
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
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
              border: Border(bottom: context.borderSide),
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
                            locate<HomeSearchCubit>().clearQuery(tab: tab),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    AxiButton.ghost(
                      onPressed: () =>
                          locate<HomeSearchCubit>().setSearchActive(false),
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
                          locate<HomeSearchCubit>().updateSort(value, tab: tab);
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
                            locate<HomeSearchCubit>().updateFilter(
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
