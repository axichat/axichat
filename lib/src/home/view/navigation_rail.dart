// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/home/view/home_screen.dart';

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
        const DraftButton(compact: true),
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
        final avatar = SelfAxiAvatar(size: sizing.iconButtonSize);
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
      return Icons.star_outline_rounded;
    case HomeTab.blocked:
      return LucideIcons.userX;
    case HomeTab.spam:
      return LucideIcons.shieldAlert;
    case HomeTab.drafts:
      return LucideIcons.fileText;
  }
}
