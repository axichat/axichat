// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/home/view/home_screen.dart';

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
    final shortcut = findActionShortcut(EnvScope.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final homeRefreshLoading = chatsState.refreshStatus.isLoading;
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
          tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
          onPressed: () => locate<AccessibilityActionBloc>().add(
            const AccessibilityMenuOpened(),
          ),
        ),
      if (EnvScope.of(context).isDesktopPlatform)
        AppBarActionItem(
          label: l10n.homeSyncTooltip,
          iconData: LucideIcons.refreshCw,
          loading: homeRefreshLoading,
          enabled: !homeRefreshLoading,
          onPressed: homeRefreshLoading
              ? null
              : () => locate<ChatsCubit>().refreshHomeSync(),
        ),
      AppBarActionItem(
        label: searchState.active ? l10n.chatSearchClose : l10n.commonSearch,
        iconData: LucideIcons.search,
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
        return Align(
          alignment: Alignment.centerLeft,
          child: ConnectionStatusIndicators(
            xmppState: connectionState,
            emailState: sessionEmailState,
            emailEnabled: emailEnabled,
            compact: true,
            collapseReadyStatus: true,
          ),
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
