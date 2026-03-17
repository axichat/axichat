// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

part of 'package:axichat/src/home/view/home_screen.dart';

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
  final GlobalKey _cancelBucketKey = GlobalKey(
    debugLabel: 'home-bottom-nav-cancel-bucket',
  );
  Timer? _calendarDragSwitchTimer;
  int? _hoveredCalendarTargetTab;
  bool _cancelBucketHovering = false;
  final Object _bottomBarDragHoverToken = Object();
  CalendarTaskOffGridDragController? _offGridDragController;

  @override
  void initState() {
    super.initState();
    widget.calendarBottomDragSession.addListener(_handleCalendarDragSignal);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final CalendarTaskOffGridDragController offGridDragController = context
        .read<CalendarTaskOffGridDragController>();
    if (_offGridDragController != offGridDragController) {
      _offGridDragController?.setRegionActive(
        region: CalendarTaskOffGridDragRegion.compactBottomBar,
        token: _bottomBarDragHoverToken,
        isActive: false,
      );
      _offGridDragController = offGridDragController;
      if (_cancelBucketHovering) {
        _offGridDragController?.setRegionActive(
          region: CalendarTaskOffGridDragRegion.compactBottomBar,
          token: _bottomBarDragHoverToken,
          isActive: true,
        );
      }
    }
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
    _setBottomDragHovering(false);
    super.dispose();
  }

  void _setBottomDragHovering(bool isHovering) {
    _offGridDragController?.setRegionActive(
      region: CalendarTaskOffGridDragRegion.compactBottomBar,
      token: _bottomBarDragHoverToken,
      isActive: isHovering,
    );
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

  Rect? _bottomNavBarRect() {
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
    return origin & size;
  }

  Rect? _cancelBucketRect() {
    final BuildContext? bucketContext = _cancelBucketKey.currentContext;
    final RenderBox? box = bucketContext?.findRenderObject() as RenderBox?;
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
    return origin & size;
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
    if (dragSession == null) {
      _cancelBucketHovering = false;
      _setBottomDragHovering(false);
      _setCalendarDragCleared();
      return;
    }
    final int selectedIndex = _clampBottomNavIndex(widget.selectedBottomIndex);
    final int? sourceTab =
        _normalizeCalendarTabIndex(dragSession.sourceTab) ??
        _normalizeCalendarTabIndex(selectedIndex == 2 ? 1 : selectedIndex);
    if (sourceTab == null) {
      _cancelBucketHovering = false;
      _setBottomDragHovering(false);
      _setCalendarDragCleared();
      return;
    }
    final bool openCalendar = selectedIndex == 1 || selectedIndex == 2;
    final locate = context.read;
    final chatsState = locate<ChatsCubit>().state;
    final chatCalendarActive =
        chatsState.openJid != null && chatsState.openChatRoute.isCalendar;
    if (!widget.calendarAvailable || (!openCalendar && !chatCalendarActive)) {
      _cancelBucketHovering = false;
      _setBottomDragHovering(false);
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final Offset? pointer = dragSession.pointer;
    if (pointer == null) {
      _cancelBucketHovering = false;
      _setBottomDragHovering(false);
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final Rect? cancelBucketRect = _cancelBucketRect();
    final bool cancelBucketHovering =
        cancelBucketRect != null && cancelBucketRect.contains(pointer);
    if (_cancelBucketHovering != cancelBucketHovering) {
      setState(() {
        _cancelBucketHovering = cancelBucketHovering;
      });
    }
    final Rect? bottomNavBarRect = _bottomNavBarRect();
    final bool bottomNavHovering =
        bottomNavBarRect != null && bottomNavBarRect.contains(pointer);
    final int targetTab = sourceTab == 0 ? 1 : 0;
    final Rect? targetRect = _calendarTabRectForIndex(targetTab);
    if (targetRect == null) {
      _setBottomDragHovering(cancelBucketHovering || bottomNavHovering);
      _setHoveredCalendarTargetTab(null);
      return;
    }
    final Rect hitRect = targetRect.inflate(context.spacing.s);
    _setBottomDragHovering(cancelBucketHovering || bottomNavHovering);
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
          padding: EdgeInsetsDirectional.only(top: spacing.s),
          child: ValueListenableBuilder<CalendarBottomDragSession?>(
            valueListenable: widget.calendarBottomDragSession,
            builder: (context, dragSession, _) {
              final Duration animationDuration = context
                  .watch<SettingsCubit>()
                  .animationDuration;
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
              final bool scheduleSwitchHintActive =
                  dragHintActive && dragSourceTab == 1;
              final bool tasksSwitchHintActive =
                  dragHintActive && dragSourceTab == 0;
              final avatar = HydratedAxiAvatar(
                avatar: AvatarPresentation.avatar(
                  label: profile.jid,
                  colorSeed: profile.jid,
                  avatar: m.Avatar.tryParseOrNull(
                    path: profile.avatarPath,
                    hash: null,
                  ),
                  loading: profile.avatarHydrating,
                ),
                subscription: m.Subscription.both,
                presence: null,
                status: null,
                active: false,
                size: sizing.iconButtonIconSize + spacing.xxs,
              );
              final Widget navBar = GNav(
                key: _bottomNavBarKey,
                selectedIndex: safeSelectedIndex,
                duration: animationDuration,
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
                    text: context.l10n.homeBottomNavHome,
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
                    text: context.l10n.homeRailCalendar,
                    leading: AxiAttentionShake(
                      enabled: scheduleSwitchHintActive,
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
                    text: context.l10n.calendarFragmentTaskLabel,
                    leading: AxiAttentionShake(
                      enabled: tasksSwitchHintActive,
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
                    text: context.l10n.settingsButtonLabel,
                    leading: avatar,
                    iconColor: colors.mutedForeground,
                    iconActiveColor: colors.foreground,
                  ),
                ],
              );
              final bool showCancelBucket = dragSession != null;
              final Widget cancelBucket = CalendarDragCancelBucket(
                key: _cancelBucketKey,
                visible: showCancelBucket,
                bottomInset: 0,
                hovering: _cancelBucketHovering,
                onWillAcceptWithDetails: (details) {
                  _setBottomDragHovering(true);
                  if (!_cancelBucketHovering) {
                    setState(() {
                      _cancelBucketHovering = true;
                    });
                  }
                  return true;
                },
                onMove: (_) {
                  _setBottomDragHovering(true);
                  if (!_cancelBucketHovering) {
                    setState(() {
                      _cancelBucketHovering = true;
                    });
                  }
                },
                onLeave: (_) {
                  if (_cancelBucketHovering) {
                    setState(() {
                      _cancelBucketHovering = false;
                    });
                  }
                  _handleCalendarDragSignal();
                },
                onAcceptWithDetails: (details) {
                  final CalendarTask restored =
                      restoreCalendarTaskFromDragPayload(details.data);
                  context.read<CalendarBloc>().add(
                    CalendarEvent.taskUpdated(task: restored),
                  );
                  widget.calendarBottomDragSession.value = null;
                  _setBottomDragHovering(false);
                  setState(() {
                    _cancelBucketHovering = false;
                  });
                },
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.only(
                      start: spacing.xs,
                      end: spacing.xs,
                      bottom: showCancelBucket ? 0 : spacing.s,
                    ),
                    child: navBar,
                  ),
                  cancelBucket,
                ],
              );
            },
          ),
        ),
      ),
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
