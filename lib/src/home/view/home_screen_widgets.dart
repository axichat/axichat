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
  XmppService? _demoResetService;
  StreamSubscription<void>? _demoResetSubscription;

  void _triggerDemoInteractivePhase() {
    if (_demoPhase != _HomeDemoPhase.idle) return;
    setState(() => _demoPhase = _HomeDemoPhase.triggered);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<XmppService?>()?.startDemoInteractivePhase();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (controller != _tabController) {
      _tabController?.removeListener(_handleTabChanged);
      _tabController = controller;
      _tabController?.addListener(_handleTabChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _notifyTabIndex(controller.index);
      });
    }
    if (!kEnableDemoChats) {
      _teardownDemoResetSubscription();
      return;
    }
    final xmppService = context.read<XmppService?>();
    if (xmppService == null || xmppService == _demoResetService) {
      return;
    }
    _teardownDemoResetSubscription();
    _demoResetService = xmppService;
    _demoResetSubscription = xmppService.demoResetStream.listen((_) {
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
    context.read<HomeSearchCubit?>()?.setActiveTab(widget.tabs[index].id);
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
    _demoResetService = null;
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
    final showToast = ShadToaster.maybeOf(context)?.show;
    final chatItems = chatsState.items ?? const <m.Chat>[];
    final selectedChats = chatsState.selectedJids.isEmpty
        ? const <m.Chat>[]
        : chatItems
            .where((chat) => chatsState.selectedJids.contains(chat.jid))
            .toList();
    final badgeCounts = <HomeTab, int>{
      HomeTab.invites: context.watch<RosterCubit?>()?.inviteCount ?? 0,
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: context.watch<DraftCubit?>()?.state.items?.length ?? 0,
      HomeTab.spam:
          chatItems.where((chat) => chat.spam && !chat.archived).length,
    };
    final headerActions = <AppBarActionItem>[
      if (kEnableDemoChats && demoPhase == _HomeDemoPhase.idle)
        AppBarActionItem(
          label: context.l10n.commonStart,
          iconData: LucideIcons.play,
          onPressed: onTriggerDemoInteractivePhase,
        ),
      if (navPlacement != NavPlacement.rail &&
          context.watch<AccessibilityActionBloc?>() != null)
        AppBarActionItem(
          label: context.l10n.accessibilityActionsLabel,
          iconData: LucideIcons.lifeBuoy,
          inline: const _FindActionIconButton(),
          onPressed: () => context.read<AccessibilityActionBloc?>()?.add(
                const AccessibilityMenuOpened(),
              ),
        ),
      if (EnvScope.of(context).isDesktopPlatform &&
          context.read<ChatsCubit?>() != null)
        AppBarActionItem(
          label: _homeSyncTooltip,
          iconData: LucideIcons.refreshCw,
          inline: const _DesktopHomeRefreshButton(),
          onPressed: () async {
            final chatsCubit = context.read<ChatsCubit>();
            await chatsCubit.refreshHomeSync();
          },
        ),
      AppBarActionItem(
        label: searchState.active
            ? context.l10n.chatSearchClose
            : context.l10n.commonSearch,
        iconData: LucideIcons.search,
        inline: _SearchToggleButton(
          active: searchState.active,
          onPressed: () => context.read<HomeSearchCubit>().toggleSearch(),
        ),
        onPressed: () => context.read<HomeSearchCubit>().toggleSearch(),
      ),
    ];
    final header = _NexusHeader(
      navPlacement: navPlacement,
      tabs: tabs,
      headerActions: headerActions,
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
    required this.navPlacement,
    required this.tabs,
    required this.headerActions,
  });

  final NavPlacement navPlacement;
  final List<HomeTabEntry> tabs;
  final List<AppBarActionItem> headerActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AxiAppBar(
          showTitle: navPlacement != NavPlacement.rail,
          trailing: AppBarActions(
            actions: headerActions,
            spacing: _homeHeaderActionSpacing,
            overflowBreakpoint: 0,
          ),
        ),
        _HomeSearchPanel(tabs: tabs),
      ],
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
        if (context.read<RosterCubit?>() != null)
          BlocListener<RosterCubit, RosterState>(
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
          border: Border(bottom: BorderSide(color: context.colorScheme.border)),
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
      final tabBar = Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.colorScheme.border)),
        ),
        child: AxiTabBar(
          backgroundColor: context.colorScheme.background,
          badges: tabs.map((tab) => badgeCounts[tab.id] ?? 0).toList(),
          badgeOffset: const Offset(0, -12),
          tabs: tabs.map((tab) {
            return Tab(child: Text(tab.label));
          }).toList(),
        ),
      );
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [tabBar, const ProfileTile()],
      );
    }
    return const ProfileTile();
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
    final actions = <Widget>[];
    if (includePrimaryActions) {
      actions.addAll(const [
        ChatsFilterButton(),
        DraftButton(),
        ChatsAddButton(),
      ]);
    }
    actions.addAll(extraActions);
    if (actions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(spacing: 8, runSpacing: 8, children: actions);
  }
}

class _AccessibilityFindActionRailItem extends StatelessWidget {
  const _AccessibilityFindActionRailItem({required this.collapsed});

  final bool collapsed;

  @override
  Widget build(BuildContext context) {
    if (context.read<AccessibilityActionBloc?>() == null) {
      return const SizedBox.shrink();
    }
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    if (collapsed) {
      return AxiIconButton.ghost(
        iconData: LucideIcons.lifeBuoy,
        tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
        onPressed: () => context.read<AccessibilityActionBloc?>()?.add(
              const AccessibilityMenuOpened(),
            ),
      );
    }
    final colors = context.colorScheme;
    final radius = context.radius;
    final label = l10n.accessibilityActionsLabel;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: colors.background,
        shape: SquircleBorder(
          cornerRadius: radius.topLeft.x,
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => context.read<AccessibilityActionBloc?>()?.add(
                const AccessibilityMenuOpened(),
              ),
          child: Padding(
            padding: _railFooterItemPadding,
            child: Row(
              children: [
                const Icon(LucideIcons.lifeBuoy, size: _railFooterIconSize),
                const SizedBox(width: _railFooterItemSpacing),
                Expanded(
                  child: Text(
                    label,
                    style: context.textTheme.small.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    if (context.read<AccessibilityActionBloc?>() != null) {
      items.add(_AccessibilityFindActionRailItem(collapsed: collapsed));
    }
    if (items.isNotEmpty) {
      items.add(const SizedBox(height: _railFooterSpacing));
    }
    items.add(_SettingsRailItem(collapsed: collapsed));
    return Column(mainAxisSize: MainAxisSize.min, children: items);
  }
}

class _SettingsRailItem extends StatelessWidget {
  const _SettingsRailItem({required this.collapsed});

  final bool collapsed;

  void _openSettings(BuildContext context) {
    context.push(const ProfileRoute().location, extra: context.read);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.settingsButtonLabel;
    if (collapsed) {
      return AxiIconButton.ghost(
        iconData: LucideIcons.settings,
        tooltip: label,
        onPressed: () => _openSettings(context),
      );
    }
    final colors = context.colorScheme;
    final radius = context.radius;
    return Semantics(
      label: label,
      button: true,
      child: Material(
        color: colors.background,
        shape: SquircleBorder(
          cornerRadius: radius.topLeft.x,
          side: BorderSide(color: colors.border),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: () => _openSettings(context),
          child: Padding(
            padding: _railFooterItemPadding,
            child: Row(
              children: [
                const Icon(LucideIcons.settings, size: _railFooterIconSize),
                const SizedBox(width: _railFooterItemSpacing),
                Expanded(
                  child: Text(
                    label,
                    style: context.textTheme.small.copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FindActionIconButton extends StatelessWidget {
  const _FindActionIconButton();

  @override
  Widget build(BuildContext context) {
    if (context.read<AccessibilityActionBloc?>() == null) {
      return const SizedBox.shrink();
    }
    final shortcut = findActionShortcut(Theme.of(context).platform);
    final shortcutText = shortcutLabel(context, shortcut);
    final l10n = context.l10n;
    return AxiIconButton.outline(
      iconData: LucideIcons.lifeBuoy,
      tooltip: l10n.accessibilityActionsShortcutTooltip(shortcutText),
      onPressed: () => context.read<AccessibilityActionBloc?>()?.add(
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

class _DesktopHomeRefreshButton extends StatefulWidget {
  const _DesktopHomeRefreshButton();

  @override
  State<_DesktopHomeRefreshButton> createState() =>
      _DesktopHomeRefreshButtonState();
}

class _DesktopHomeRefreshButtonState extends State<_DesktopHomeRefreshButton>
    with SingleTickerProviderStateMixin {
  static const _spinDuration = Duration(milliseconds: 900);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(vsync: this, duration: _spinDuration);
  }

  late final AnimationController _spinController;
  bool _spinning = false;

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  void _setSpinning(bool spinning) {
    if (_spinning == spinning) return;
    _spinning = spinning;
    if (spinning) {
      _spinController.repeat();
    } else {
      _spinController
        ..stop()
        ..value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) =>
          previous.refreshStatus != current.refreshStatus,
      listener: (context, state) => _setSpinning(state.refreshStatus.isLoading),
      child: BlocSelector<ChatsCubit, ChatsState, RequestStatus>(
        selector: (state) => state.refreshStatus,
        builder: (context, status) {
          final spinning = status.isLoading;
          return AxiIconButton.ghost(
            iconData: LucideIcons.refreshCw,
            tooltip: _homeSyncTooltip,
            onPressed: spinning
                ? null
                : () async {
                    final chatsCubit = context.read<ChatsCubit>();
                    await chatsCubit.refreshHomeSync();
                  },
            icon: RotationTransition(
              turns: _spinController,
              child: Icon(
                LucideIcons.refreshCw,
                color: context.colorScheme.primary,
              ),
            ),
          );
        },
      ),
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
    this.onCollapsedChanged,
  });

  final List<HomeTabEntry> tabs;
  final int selectedIndex;
  final bool collapsed;
  final ValueChanged<int> onDestinationSelected;
  final bool calendarAvailable;
  final bool calendarActive;
  final VoidCallback onCalendarSelected;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<_HomeNavigationRail> createState() => _HomeNavigationRailState();
}

class _HomeNavigationRailState extends State<_HomeNavigationRail> {
  TabController? _tabController;
  int _controllerIndex = 0;
  late final AppLocalizations l10n = context.l10n;

  @override
  void initState() {
    super.initState();
    _controllerIndex = widget.selectedIndex;
  }

  @override
  void didUpdateWidget(covariant _HomeNavigationRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_tabController == null && widget.selectedIndex != _controllerIndex) {
      _controllerIndex = widget.selectedIndex;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (_tabController == controller) return;
    _tabController?.removeListener(_handleTabChange);
    _tabController = controller;
    _controllerIndex = controller.index;
    _tabController?.addListener(_handleTabChange);
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabChange);
    super.dispose();
  }

  void _handleTabChange() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging) return;
    setState(() {
      _controllerIndex = controller.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatsCubit, ChatsState>(
      builder: (context, chatsState) {
        final selectedIndex = _tabController?.index ?? _controllerIndex;
        if (widget.tabs.isEmpty) {
          return const SizedBox.shrink();
        }
        final badgeCounts = _computeBadgeCounts(
          chatsState: chatsState,
          inviteCount: context.watch<RosterCubit?>()?.inviteCount ?? 0,
          draftCount: context.watch<DraftCubit?>()?.state.items?.length ?? 0,
        );
        final calendarDestinationIndex = _calendarDestinationIndex();
        final destinations = <AxiRailDestination>[];
        for (final tab in widget.tabs) {
          destinations.add(
            AxiRailDestination(
              icon: _tabIcon(tab.id),
              label: tab.label,
              badgeCount: badgeCounts[tab.id] ?? 0,
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
        final safeTabIndex =
            selectedIndex.clamp(0, widget.tabs.length - 1).toInt();
        final selectedRailIndex = widget.calendarActive &&
                calendarDestinationIndex != null
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
              setState(() {
                _controllerIndex = tabIndex;
              });
              widget.onDestinationSelected(tabIndex);
            },
          ),
        );
      },
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

  Map<HomeTab, int> _computeBadgeCounts({
    required ChatsState chatsState,
    required int inviteCount,
    required int draftCount,
  }) {
    final chatItems = chatsState.items ?? const <m.Chat>[];
    return <HomeTab, int>{
      HomeTab.invites: inviteCount,
      HomeTab.chats: chatItems
          .where((chat) => !chat.archived && !chat.spam)
          .fold<int>(0, (sum, chat) => sum + math.max(0, chat.unreadCount)),
      HomeTab.drafts: draftCount,
      HomeTab.spam:
          chatItems.where((chat) => chat.spam && !chat.archived).length,
    };
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
    context.read<HomeSearchCubit?>()?.updateQuery(_controller.text);
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

  String _filterLabel(List<HomeSearchFilter> filters, String? id) {
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _focusNode.hasFocus) return;
            _focusNode.requestFocus();
          });
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
      },
      builder: (context, state) {
        final l10n = context.l10n;
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colorScheme.card,
              border: Border(
                bottom: BorderSide(color: context.colorScheme.border),
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
                            context.read<HomeSearchCubit?>()?.clearQuery(
                                  tab: tab,
                                ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ShadButton.ghost(
                      size: ShadButtonSize.sm,
                      onPressed: () => context
                          .read<HomeSearchCubit?>()
                          ?.setSearchActive(false),
                      child: Text(l10n.commonCancel),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AxiSelect<SearchSortOrder>(
                        initialValue: sortValue,
                        onChanged: (value) {
                          if (value == null) return;
                          context.read<HomeSearchCubit?>()?.updateSort(
                                value,
                                tab: tab,
                              );
                        },
                        options: SearchSortOrder.values
                            .map(
                              (order) => ShadOption<SearchSortOrder>(
                                value: order,
                                child: Text(order.label),
                              ),
                            )
                            .toList(),
                        selectedOptionBuilder: (_, value) => Text(value.label),
                      ),
                    ),
                    if (filters.length > 1 && effectiveFilterId != null) ...[
                      const SizedBox(width: 12),
                      Expanded(
                        child: AxiSelect<String>(
                          initialValue: effectiveFilterId,
                          onChanged: (value) {
                            context.read<HomeSearchCubit?>()?.updateFilter(
                                  value,
                                  tab: tab,
                                );
                          },
                          options: filters
                              .map(
                                (filter) => ShadOption<String>(
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
                      padding: const EdgeInsets.only(top: 8),
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
