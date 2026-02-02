// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/view/calendar_tile.dart';
import 'package:axichat/src/chats/view/widgets/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({
    super.key,
    this.showCalendarShortcut = true,
    this.calendarAvailable = false,
  });

  final bool showCalendarShortcut;
  final bool calendarAvailable;

  @override
  Widget build(BuildContext context) {
    final bool isDesktopPlatform =
        EnvScope.maybeOf(context)?.isDesktopPlatform ?? false;
    return BlocBuilder<HomeSearchCubit, HomeSearchState>(
      builder: (context, searchState) {
        return BlocBuilder<RosterCubit, RosterState>(
          builder: (context, rosterState) {
            final rosterItems = rosterState.items ?? const <RosterItem>[];
            return _ChatsListSync(
              searchState: searchState,
              rosterItems: rosterItems,
              showCalendarShortcut: showCalendarShortcut,
              calendarAvailable: calendarAvailable,
              isDesktopPlatform: isDesktopPlatform,
            );
          },
        );
      },
    );
  }
}

class _ChatsListSync extends StatefulWidget {
  const _ChatsListSync({
    required this.searchState,
    required this.rosterItems,
    required this.showCalendarShortcut,
    required this.calendarAvailable,
    required this.isDesktopPlatform,
  });

  final HomeSearchState searchState;
  final List<RosterItem> rosterItems;
  final bool showCalendarShortcut;
  final bool calendarAvailable;
  final bool isDesktopPlatform;

  @override
  State<_ChatsListSync> createState() => _ChatsListSyncState();
}

class _ChatsListSyncState extends State<_ChatsListSync> {
  @override
  void initState() {
    super.initState();
    _syncSearch();
    _syncRoster();
  }

  @override
  void didUpdateWidget(covariant _ChatsListSync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchState != widget.searchState) {
      _syncSearch();
    }
    if (!listEquals(oldWidget.rosterItems, widget.rosterItems)) {
      _syncRoster();
    }
  }

  void _syncSearch() {
    final tabState = widget.searchState.stateFor(HomeTab.chats);
    final query = widget.searchState.active ? tabState.query : '';
    context.read<ChatsCubit>().updateSearchSnapshot(
          active: widget.searchState.active,
          query: query,
          filterId: tabState.filterId,
          sortOrder: tabState.sort,
        );
  }

  void _syncRoster() {
    final rosterContacts = widget.rosterItems.map((item) => item.jid).toSet();
    context.read<ChatsCubit>().updateRosterContacts(rosterContacts);
  }

  @override
  Widget build(BuildContext context) {
    return _ChatsListBody(
      showCalendarShortcut: widget.showCalendarShortcut,
      calendarAvailable: widget.calendarAvailable,
      isDesktopPlatform: widget.isDesktopPlatform,
    );
  }
}

class _ChatsListBody extends StatelessWidget {
  const _ChatsListBody({
    required this.showCalendarShortcut,
    required this.calendarAvailable,
    required this.isDesktopPlatform,
  });

  final bool showCalendarShortcut;
  final bool calendarAvailable;
  final bool isDesktopPlatform;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid =
        resolvedProfileJid.isNotEmpty ? resolvedProfileJid : null;
    final selfIdentity = SelfIdentitySnapshot(
      selfJid: selfJid,
      avatarPath: context.watch<ProfileCubit>().state.avatarPath,
    );
    final refreshSpinnerExtent = sizing.buttonHeightLg + spacing.s;
    final refreshSpinnerDimension = sizing.progressIndicatorSize + spacing.xs;
    final refreshOffsetToArmed = spacing.xl + spacing.l;
    final refreshRevealThreshold = context.motion.tapHoverAlpha;
    final refreshIndicatorPadding = spacing.m;
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) =>
          previous.creationStatus != current.creationStatus ||
          previous.refreshStatus != current.refreshStatus,
      listener: (context, state) {
        if (state.creationStatus.isSuccess) {
          showToast?.call(
            FeedbackToast.success(message: l10n.chatsCreateGroupSuccess),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        } else if (state.creationStatus.isFailure) {
          showToast?.call(
            FeedbackToast.error(message: l10n.chatsCreateGroupFailure),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        }
        if (state.refreshStatus.isSuccess) {
          context.read<ChatsCubit>().clearRefreshStatus();
        } else if (state.refreshStatus.isFailure) {
          showToast?.call(
            FeedbackToast.error(message: l10n.chatsRefreshFailed),
          );
          context.read<ChatsCubit>().clearRefreshStatus();
        }
      },
      child: BlocBuilder<ChatsCubit, ChatsState>(
        builder: (context, state) {
          final items = state.items;
          Widget child;
          if (items == null) {
            child = KeyedSubtree(
              key: const ValueKey('chats-loading'),
              child: Center(
                child: AxiProgressIndicator(
                  color: context.colorScheme.foreground,
                ),
              ),
            );
          } else {
            final includeCalendarShortcut =
                showCalendarShortcut && calendarAvailable && !isDesktopPlatform;
            final visibleItems = state.visibleItems;
            Widget body;
            if (visibleItems.isEmpty) {
              body = Column(
                children: [
                  if (includeCalendarShortcut)
                    ListItemPadding(
                      child: BlocBuilder<CalendarBloc, CalendarState>(
                        builder: (context, state) {
                          final currentTask = state.currentTaskAt(
                            DateTime.now(),
                          );
                          return CalendarTile(
                            onTap: () =>
                                context.read<ChatsCubit>().toggleCalendar(),
                            currentTask: currentTask,
                            nextTask: state.nextTask,
                            dueReminderCount: state.dueReminders?.length ?? 0,
                          );
                        },
                      ),
                    ),
                  Center(
                    child: Text(
                      l10n.chatsEmptyList,
                      style: context.textTheme.muted,
                    ),
                  ),
                ],
              );
            } else {
              final scrollPhysics = AlwaysScrollableScrollPhysics(
                parent: ScrollConfiguration.of(
                  context,
                ).getScrollPhysics(context),
              );
              body = ColoredBox(
                color: context.colorScheme.background,
                child: AxiNowTicker(
                  now: kEnableDemoChats ? demoNow : DateTime.now,
                  builder: (context, nowListenable) => AnimatedChatsListView(
                    items: visibleItems,
                    includeCalendarShortcut: includeCalendarShortcut,
                    animationDuration:
                        context.watch<SettingsCubit>().animationDuration,
                    scrollPhysics: scrollPhysics,
                    selectedJids: state.selectedJids,
                    openJid: state.openJid,
                    timestampNowListenable: nowListenable,
                    selfIdentity: selfIdentity,
                    calendarShortcut: includeCalendarShortcut
                        ? ListItemPadding(
                            child: BlocBuilder<CalendarBloc, CalendarState>(
                              builder: (context, state) {
                                final currentTask = state.currentTaskAt(
                                  DateTime.now(),
                                );
                                return CalendarTile(
                                  onTap: () => context
                                      .read<ChatsCubit>()
                                      .toggleCalendar(),
                                  currentTask: currentTask,
                                  nextTask: state.nextTask,
                                  dueReminderCount:
                                      state.dueReminders?.length ?? 0,
                                );
                              },
                            ),
                          )
                        : null,
                  ),
                ),
              );
            }

            child = KeyedSubtree(
              key: const ValueKey('chats-loaded'),
              child: visibleItems.isEmpty
                  ? ColoredBox(
                      color: context.colorScheme.background,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final scrollPhysics = AlwaysScrollableScrollPhysics(
                            parent: ScrollConfiguration.of(
                              context,
                            ).getScrollPhysics(context),
                          );
                          return ListView(
                            physics: scrollPhysics,
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: body,
                              ),
                            ],
                          );
                        },
                      ),
                    )
                  : body,
            );
          }

          final animated = child;
          final env = EnvScope.of(context);
          final enableRefresh = env.navPlacement == NavPlacement.bottom;
          if (!enableRefresh) return animated;

          return CustomRefreshIndicator(
            onRefresh: () => context.read<ChatsCubit>().refreshHomeSync(),
            offsetToArmed: refreshOffsetToArmed,
            triggerMode: IndicatorTriggerMode.anywhere,
            leadingScrollIndicatorVisible: true,
            builder: (context, child, controller) {
              final clamped = controller.value.clamp(0.0, 1.0).toDouble();
              final isLeadingPull =
                  controller.hasEdge && controller.edge!.isLeading;
              final isActive = controller.isLoading ||
                  (isLeadingPull && !controller.state.isIdle);
              final isRevealed =
                  isActive && (controller.isLoading || clamped > 0.0);
              final revealFactor =
                  isRevealed ? (controller.isLoading ? 1.0 : clamped) : 0.0;

              final revealedExtent = refreshSpinnerExtent * revealFactor;
              final isArmed = controller.state.isArmed;
              final showIndicator = isLeadingPull &&
                  (controller.isLoading || clamped > refreshRevealThreshold);
              final indicatorContent = !showIndicator
                  ? const SizedBox.shrink()
                  : controller.isLoading
                      ? AxiProgressIndicator(
                          color: context.colorScheme.primary,
                        )
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
                                border: Border(
                                  bottom: context.borderSide,
                                ),
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
            child: animated,
          );
        },
      ),
    );
  }
}

class _AnimatedChatTile extends StatelessWidget {
  const _AnimatedChatTile({
    required this.chat,
    required this.animation,
    required this.entering,
    required this.fromTop,
    required this.archivedContext,
    required this.onArchivedTap,
    required this.selectionActive,
    required this.isSelected,
    required this.isOpen,
    required this.timestampNowListenable,
    required this.selfIdentity,
  });

  final Chat chat;
  final Animation<double> animation;
  final bool entering;
  final bool fromTop;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final ValueListenable<DateTime> timestampNowListenable;
  final SelfIdentitySnapshot selfIdentity;

  @override
  Widget build(BuildContext context) {
    final distance = context.spacing.s / context.sizing.listButtonHeight;
    final offset = fromTop ? Offset(0, -distance) : Offset(0, distance);
    final slideAnimation = CurvedAnimation(
      parent: entering ? animation : ReverseAnimation(animation),
      curve: Curves.easeOutCubic,
    );
    final tween = entering
        ? Tween<Offset>(begin: offset, end: Offset.zero)
        : Tween<Offset>(begin: Offset.zero, end: offset);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: tween.animate(slideAnimation),
        child: _ChatTileSlot(
          chat: chat,
          archivedContext: archivedContext,
          onArchivedTap: onArchivedTap,
          selectionActive: selectionActive,
          isSelected: isSelected,
          isOpen: isOpen,
          timestampNowListenable: timestampNowListenable,
          selfIdentity: selfIdentity,
        ),
      ),
    );
  }
}

class _ChatTileSlot extends StatelessWidget {
  const _ChatTileSlot({
    required this.chat,
    required this.archivedContext,
    required this.onArchivedTap,
    required this.selectionActive,
    required this.isSelected,
    required this.isOpen,
    required this.timestampNowListenable,
    required this.selfIdentity,
  });

  final Chat chat;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final ValueListenable<DateTime> timestampNowListenable;
  final SelfIdentitySnapshot selfIdentity;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: timestampNowListenable,
      builder: (context, timestampNow, _) {
        return ListItemPadding(
          child: ChatListTile(
            item: chat,
            archivedContext: archivedContext,
            onArchivedTap: onArchivedTap,
            selectionActive: selectionActive,
            isSelected: isSelected,
            isOpen: isOpen,
            timestampNow: timestampNow,
            selfIdentity: selfIdentity,
          ),
        );
      },
    );
  }
}

class ChatListTile extends StatefulWidget {
  const ChatListTile({
    super.key,
    required this.item,
    required this.selectionActive,
    required this.isSelected,
    required this.isOpen,
    required this.timestampNow,
    required this.selfIdentity,
    this.archivedContext = false,
    this.onArchivedTap,
  });

  final Chat item;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final DateTime timestampNow;
  final SelfIdentitySnapshot selfIdentity;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class AnimatedChatsListView extends StatefulWidget {
  const AnimatedChatsListView({
    super.key,
    required this.items,
    required this.animationDuration,
    required this.scrollPhysics,
    required this.selectedJids,
    required this.openJid,
    required this.timestampNowListenable,
    required this.selfIdentity,
    this.includeCalendarShortcut = false,
    this.calendarShortcut,
  });

  final List<Chat> items;
  final Duration animationDuration;
  final ScrollPhysics scrollPhysics;
  final Set<String> selectedJids;
  final String? openJid;
  final ValueListenable<DateTime> timestampNowListenable;
  final SelfIdentitySnapshot selfIdentity;
  final bool includeCalendarShortcut;
  final Widget? calendarShortcut;

  @override
  State<AnimatedChatsListView> createState() => _AnimatedChatsListViewState();
}

class _AnimatedChatsListViewState extends State<AnimatedChatsListView> {
  final GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  late List<Chat> _displayedItems;

  @override
  void initState() {
    super.initState();
    _displayedItems = List<Chat>.from(widget.items);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedChatsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDisplayedItems(widget.items);
  }

  void _updateDisplayedItems(List<Chat> newItems) {
    final listState = _listKey.currentState;
    if (listState == null) {
      setState(() {
        _displayedItems = List<Chat>.from(newItems);
      });
      return;
    }
    var mutated = false;
    final newJids = newItems.map((chat) => chat.jid).toSet();
    for (int i = _displayedItems.length - 1; i >= 0; i--) {
      final chat = _displayedItems[i];
      if (!newJids.contains(chat.jid)) {
        final removedChat = _displayedItems.removeAt(i);
        listState.removeItem(
          i,
          (context, animation) => _AnimatedChatTile(
            chat: removedChat,
            animation: animation,
            entering: false,
            fromTop: i == 0,
            archivedContext: false,
            onArchivedTap: null,
            selectionActive: widget.selectedJids.isNotEmpty,
            isSelected: widget.selectedJids.contains(removedChat.jid),
            isOpen: widget.openJid == removedChat.jid,
            timestampNowListenable: widget.timestampNowListenable,
            selfIdentity: widget.selfIdentity,
          ),
          duration: widget.animationDuration,
        );
        mutated = true;
      }
    }

    final existingJids = _displayedItems.map((chat) => chat.jid).toSet();
    for (int targetIndex = 0; targetIndex < newItems.length; targetIndex++) {
      final chat = newItems[targetIndex];
      if (existingJids.contains(chat.jid)) {
        continue;
      }
      _displayedItems.insert(targetIndex, chat);
      existingJids.add(chat.jid);
      listState.insertItem(
        targetIndex,
        duration: widget.animationDuration,
      );
      mutated = true;
    }

    if (!_hasSameJidOrder(newItems)) {
      setState(() {
        _displayedItems = List<Chat>.from(newItems);
      });
      return;
    }

    for (var i = 0; i < _displayedItems.length; i++) {
      _displayedItems[i] = newItems[i];
    }
    if (mutated) {
      setState(() {});
    }
  }

  bool _hasSameJidOrder(List<Chat> newItems) {
    if (_displayedItems.length != newItems.length) return false;
    for (var i = 0; i < newItems.length; i++) {
      if (_displayedItems[i].jid != newItems[i].jid) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final topSpacer = context.spacing.m;
    final scrollbarInset = context.spacing.xxs;
    final scrollbarThickness = context.spacing.xs;
    final slivers = <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: topSpacer)),
      SliverAnimatedList(
        key: _listKey,
        initialItemCount: _displayedItems.length,
        itemBuilder: (context, index, animation) {
          final chat = _displayedItems[index];
          return _AnimatedChatTile(
            chat: chat,
            animation: animation,
            entering: true,
            fromTop: index == 0,
            archivedContext: false,
            onArchivedTap: null,
            selectionActive: widget.selectedJids.isNotEmpty,
            isSelected: widget.selectedJids.contains(chat.jid),
            isOpen: widget.openJid == chat.jid,
            timestampNowListenable: widget.timestampNowListenable,
            selfIdentity: widget.selfIdentity,
          );
        },
      ),
    ];
    if (widget.includeCalendarShortcut && widget.calendarShortcut != null) {
      slivers.insert(
        0,
        SliverToBoxAdapter(child: widget.calendarShortcut),
      );
    }
    return RawScrollbar(
      interactive: true,
      controller: _scrollController,
      thumbVisibility: true,
      crossAxisMargin: scrollbarInset,
      thickness: scrollbarThickness,
      radius: Radius.circular(context.radii.squircle),
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
        child: CustomScrollView(
          controller: _scrollController,
          physics: widget.scrollPhysics,
          slivers: slivers,
        ),
      ),
    );
  }
}

class _ChatListTileState extends State<ChatListTile> {
  bool _showActions = false;
  bool _focused = false;
  late final FocusNode _focusNode;
  String? _cachedTimestampLabel;
  double _cachedTimestampWidth = 0;
  int? _cachedUnreadCount;
  double _cachedUnreadWidth = 0;
  double _cachedUnreadHeight = 0;
  double _textScaleFactor = 1;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'chat-tile-${widget.item.jid}');
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ChatListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectionActive && !oldWidget.selectionActive && _showActions) {
      setState(() {
        _showActions = false;
      });
    }
    if (oldWidget.item.unreadCount != widget.item.unreadCount) {
      _cachedUnreadCount = null;
      _cachedUnreadWidth = 0;
      _cachedUnreadHeight = 0;
    }
    if (oldWidget.item.lastMessage != widget.item.lastMessage) {
      _cachedTimestampLabel = null;
      _cachedTimestampWidth = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final colors = context.colorScheme;
    final textScaler = MediaQuery.of(context).textScaler;
    final isDesktop = EnvScope.maybeOf(context)?.isDesktopPlatform ?? false;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final motion = context.motion;
    double scaled(double value) {
      if (!value.isFinite) {
        return value;
      }
      try {
        final scaledValue = textScaler.scale(value);
        if (!scaledValue.isFinite || scaledValue <= 0) {
          return value;
        }
        return scaledValue;
      } on AssertionError {
        return value;
      }
    }

    final scaleFactor = textScaler.scale(1);
    if (_textScaleFactor != scaleFactor) {
      _textScaleFactor = scaleFactor;
      _cachedTimestampLabel = null;
      _cachedTimestampWidth = 0;
      _cachedUnreadCount = null;
      _cachedUnreadWidth = 0;
      _cachedUnreadHeight = 0;
    }

    final displayName = item.displayName;
    final int unreadCount = math.max(0, item.unreadCount);
    final bool showUnreadBadge = unreadCount > 0;
    final double unreadThickness =
        showUnreadBadge ? _resolveUnreadWidth(context, unreadCount) : 0.0;
    final double unreadHeight =
        showUnreadBadge ? _resolveUnreadHeight(context, unreadCount) : 0.0;
    final unreadCutoutVerticalClearance = spacing.xs;
    final unreadMinDepth = spacing.s + spacing.xs;
    final double unreadDepth = showUnreadBadge
        ? math.max(
            unreadMinDepth,
            (unreadHeight / 2) + unreadCutoutVerticalClearance,
          )
        : 0.0;
    final subtitleText = _subtitlePreview(item.lastMessage);
    final timestampLabel = item.lastMessage == null
        ? null
        : formatTimeSinceLabel(
            l10n, widget.timestampNow, item.lastChangeTimestamp);
    final timestampThickness = timestampLabel == null
        ? 0.0
        : math.max(
            scaled(sizing.menuItemHeight),
            _resolveTimestampWidth(context, timestampLabel) + scaled(spacing.m),
          );
    final selectionActive = widget.selectionActive;
    final isSelected = widget.isSelected;
    final isOpen = widget.isOpen;

    final brightness = context.brightness;
    final overlayAlpha = brightness == Brightness.dark
        ? motion.tapHoverAlpha
        : motion.tapSplashAlpha;
    final selectionOverlay = colors.primary.withValues(
      alpha: overlayAlpha,
    );
    final tileBackgroundColor =
        isOpen ? Color.alphaBlend(selectionOverlay, colors.card) : colors.card;
    late final VoidCallback tileOnTap;
    if (selectionActive) {
      tileOnTap =
          () => context.read<ChatsCubit>().toggleChatSelection(item.jid);
    } else {
      tileOnTap = () async {
        await _handleTap(item);
      };
    }
    final tilePadding = EdgeInsetsDirectional.only(
      start: scaled(spacing.m),
      end: scaled(showUnreadBadge ? spacing.l : spacing.m),
      top: scaled(spacing.xs),
      bottom: scaled(spacing.xs),
    );
    final tile = AxiListTile(
      key: Key(item.jid),
      onTap: tileOnTap,
      onLongPress: () {
        if (selectionActive) {
          context.read<ChatsCubit>().toggleChatSelection(item.jid);
        } else {
          context.read<ChatsCubit>().ensureChatSelected(item.jid);
        }
        if (_showActions) {
          setState(() => _showActions = false);
        }
      },
      leadingConstraints: BoxConstraints(
        maxWidth: scaled(sizing.iconButtonTapTarget + spacing.s),
        maxHeight: scaled(sizing.iconButtonTapTarget + spacing.s),
      ),
      selected: isOpen || isSelected,
      paintSurface: false,
      contentPadding: tilePadding,
      tapBounce: false,
      leading: TransportAwareAvatar(
        chat: item,
        selfIdentity: widget.selfIdentity,
      ),
      title: displayName,
      subtitle: subtitleText,
      subtitlePlaceholder: l10n.chatEmptyMessages,
    );

    final cutoutGap = spacing.xxs;
    final iconButtonSize = sizing.iconButtonSize;
    final iconCutoutThickness = iconButtonSize + (cutoutGap * 2);
    final iconCutoutDepth = (iconButtonSize / 2) + cutoutGap;
    final iconCutoutRadius = context.radii.squircle;
    final unreadChildOffset = -spacing.xs;
    final timestampOffset = (spacing.xs + spacing.xxs) / 2;
    final cutouts = <CutoutSpec>[
      if (showUnreadBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.84, -1),
          depth: unreadDepth,
          thickness: unreadThickness,
          cornerRadius: sizing.containerRadius,
          child: Transform.translate(
            offset: Offset(0, scaled(unreadChildOffset)),
            child: _UnreadBadge(count: unreadCount, highlight: showUnreadBadge),
          ),
        ),
      CutoutSpec(
        edge: CutoutEdge.right,
        alignment: const Alignment(1, 0),
        depth: iconCutoutDepth,
        thickness: iconCutoutThickness,
        cornerRadius: iconCutoutRadius,
        child: selectionActive
            ? _ChatSelectionCutoutButton(
                backgroundColor: tileBackgroundColor,
                selected: isSelected,
                onPressed: () =>
                    context.read<ChatsCubit>().toggleChatSelection(item.jid),
              )
            : _ChatActionsToggle(
                backgroundColor: tileBackgroundColor,
                expanded: _showActions,
                onPressed: _toggleActions,
              ),
      ),
      if (timestampLabel != null)
        CutoutSpec(
          edge: CutoutEdge.bottom,
          alignment: const Alignment(0.52, 1),
          depth: spacing.m,
          thickness: timestampThickness,
          cornerRadius: sizing.containerRadius,
          child: Transform.translate(
            offset: Offset(0, -scaled(timestampOffset)),
            child: Text(
              timestampLabel,
              style: context.textTheme.muted,
            ),
          ),
        ),
    ];

    final surfaceBorderColor = _focused ? colors.primary : colors.border;
    final tileSurface = CutoutSurface(
      backgroundColor: tileBackgroundColor,
      borderColor: surfaceBorderColor,
      cutouts: cutouts,
      shape: SquircleBorder(
        cornerRadius: context.radii.squircle,
        side: BorderSide(
          color: surfaceBorderColor,
          width: context.borderSide.width,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth;
          final inset = scaled(iconCutoutDepth);
          final bodyWidth = (maxWidth - inset).clamp(0.0, maxWidth);
          return SizedBox(
            width: bodyWidth,
            child: Column(
              children: [
                tile,
                AnimatedCrossFade(
                  duration: baseAnimationDuration,
                  sizeCurve: Curves.easeInOutCubic,
                  crossFadeState: _showActions
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                      scaled(spacing.m),
                      0,
                      scaled(spacing.m),
                      scaled(spacing.m + spacing.xs),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: scaled(spacing.m + spacing.xs),
                      ),
                      child: _ChatActionPanel(
                        chat: item,
                        archivedContext: widget.archivedContext,
                        onClose: _hideActions,
                        onDelete: () => _confirmDelete(item),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    final semanticsValue = l10n.chatsUnreadLabel(unreadCount);
    final semanticsHint = selectionActive
        ? (isSelected
            ? l10n.chatsSemanticsUnselectHint
            : l10n.chatsSemanticsSelectHint)
        : l10n.chatsSemanticsOpenHint;
    Widget tileContent = Padding(
      padding: EdgeInsetsDirectional.only(end: scaled(iconCutoutDepth)),
      child: tileSurface.withTapBounce(),
    );
    if (isDesktop) {
      tileContent = AxiContextMenuRegion(
        longPressEnabled: false,
        items: [
          AxiMenu(
            actions: _chatContextMenuActions(item),
          ),
        ],
        child: tileContent,
      );
    }
    return FocusableActionDetector(
      focusNode: _focusNode,
      onShowFocusHighlight: (value) {
        if (_focused != value) {
          setState(() => _focused = value);
        }
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            tileOnTap();
            return null;
          },
        ),
      },
      child: Semantics(
        container: true,
        button: true,
        selected: isSelected,
        label: displayName,
        value: semanticsValue,
        hint: semanticsHint,
        onTap: tileOnTap,
        child: tileContent,
      ),
    );
  }

  double _resolveTimestampWidth(BuildContext context, String label) {
    if (_cachedTimestampLabel == label && _cachedTimestampWidth > 0) {
      return _cachedTimestampWidth;
    }
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: context.textTheme.small,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.of(context).textScaler,
    )..layout();
    _cachedTimestampLabel = label;
    _cachedTimestampWidth = painter.width;
    return _cachedTimestampWidth;
  }

  double _resolveUnreadWidth(BuildContext context, int count) {
    if (_cachedUnreadCount == count && _cachedUnreadWidth > 0) {
      return _cachedUnreadWidth;
    }
    _cacheUnreadMetrics(context, count);
    return _cachedUnreadWidth;
  }

  double _resolveUnreadHeight(BuildContext context, int count) {
    if (_cachedUnreadCount == count && _cachedUnreadHeight > 0) {
      return _cachedUnreadHeight;
    }
    _cacheUnreadMetrics(context, count);
    return _cachedUnreadHeight;
  }

  void _cacheUnreadMetrics(BuildContext context, int count) {
    final spacing = context.spacing;
    final borderWidth = context.borderSide.width;
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: context.textTheme.small.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.of(context).textScaler,
    )..layout();
    final textWidth = textPainter.width;
    final textHeight = textPainter.height;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) {
      if (!value.isFinite) {
        return value;
      }
      final scaledValue = textScaler.scale(value);
      if (!scaledValue.isFinite || scaledValue <= 0) {
        return value;
      }
      return scaledValue;
    }

    final horizontalPadding = scaled(spacing.s);
    final verticalPadding = scaled(spacing.xs);
    final minWidth = scaled(spacing.l);
    final cutoutClearance = scaled(spacing.xs);
    final scaledBorderWidth = scaled(borderWidth);
    _cachedUnreadCount = count;
    _cachedUnreadWidth = math.max(
      minWidth,
      textWidth +
          (horizontalPadding * 2) +
          (scaledBorderWidth * 2) +
          cutoutClearance,
    );
    _cachedUnreadHeight =
        textHeight + (verticalPadding * 2) + (scaledBorderWidth * 2);
  }

  String? _subtitlePreview(String? rawMessage) {
    final String? trimmed = rawMessage?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (CalendarSyncMessage.looksLikeEnvelope(trimmed)) {
      return null;
    }
    final split = ChatSubjectCodec.splitXmppBody(trimmed);
    final subject = _collapsePreviewText(split.subject);
    final body = _collapsePreviewText(split.body);
    if (subject.isEmpty) {
      return body.isEmpty ? null : body;
    }
    if (body.isEmpty) {
      return subject;
    }
    return '$subject — $body';
  }

  String _collapsePreviewText(String? value) {
    if (value == null) {
      return '';
    }
    return value.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
    });
  }

  void _hideActions() {
    if (!_showActions || !mounted) {
      return;
    }
    setState(() {
      _showActions = false;
    });
  }

  Future<void> _handleTap(Chat chat) async {
    if (widget.archivedContext && chat.archived) {
      final handler = widget.onArchivedTap;
      if (handler != null) {
        await handler(chat);
        return;
      }
    }
    await context.read<ChatsCubit>().openChat(jid: chat.jid);
  }

  Future<void> _confirmDelete(Chat chat) async {
    final l10n = context.l10n;
    var deleteMessages = false;
    final spacing = context.spacing;
    final confirmed = await showFadeScaleDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ShadDialog(
              constraints:
                  BoxConstraints(maxWidth: context.sizing.dialogMaxWidth),
              title: Text(
                l10n.commonConfirm,
                style: context.modalHeaderTextStyle,
              ),
              actions: [
                AxiButton.outline(
                  onPressed: () => dialogContext.pop(false),
                  child: Text(l10n.commonCancel),
                ),
                AxiButton.destructive(
                  onPressed: () => dialogContext.pop(true),
                  child: Text(l10n.commonContinue),
                ),
              ],
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.chatsDeleteConfirmMessage(chat.displayName),
                      style: context.textTheme.small,
                    ),
                    SizedBox(height: spacing.s),
                    AxiCheckboxFormField(
                      initialValue: deleteMessages,
                      inputLabel: Text(l10n.chatsDeleteMessagesOption),
                      onChanged: (value) =>
                          setState(() => deleteMessages = value),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (!mounted) return;
    if (confirmed != true) return;
    if (deleteMessages) {
      await context.read<ChatsCubit>().deleteChatMessages(jid: chat.jid);
      if (!mounted) return;
    }
    await context.read<ChatsCubit>().deleteChat(jid: chat.jid);
    if (!mounted) return;
    _showMessage(l10n.chatsDeleteSuccess);
    setState(() => _showActions = false);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportChatFromContextMenu(Chat chat) async {
    final l10n = context.l10n;
    final scheduleExportCleanup =
        context.read<ChatsCubit>().scheduleExportCleanup;
    final confirmed = await _confirmChatExport(context);
    if (!mounted || !confirmed) return;
    File? exportFile;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: [chat],
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
        countHistory: context.read<ChatsCubit>().countChatHistoryMessages,
        loadHistoryPage: context.read<ChatsCubit>().loadChatHistoryPage,
      );
      exportFile = result.file;
      if (!mounted) return;
      if (exportFile == null) {
        _showMessage(l10n.chatsExportNoContent);
        return;
      }
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        text: l10n.chatsExportShareText,
        subject: l10n.chatsExportShareSubject(chat.displayName),
      );
      if (!mounted) return;
      _showMessage(l10n.chatsExportSuccess);
    } catch (_) {
      if (!mounted) return;
      _showMessage(l10n.chatsExportFailure);
    } finally {
      if (exportFile != null) {
        scheduleExportCleanup(exportFile);
      }
    }
  }

  List<AxiMenuAction> _chatContextMenuActions(Chat chat) {
    final l10n = context.l10n;
    return [
      AxiMenuAction(
        icon: LucideIcons.messagesSquare,
        label: l10n.commonOpen,
        onPressed: () async {
          await _handleTap(chat);
        },
      ),
      AxiMenuAction(
        icon: LucideIcons.squareCheck,
        label: l10n.commonSelect,
        onPressed: () =>
            context.read<ChatsCubit>().ensureChatSelected(chat.jid),
      ),
      AxiMenuAction(
        icon: LucideIcons.share2,
        label: l10n.commonExport,
        onPressed: () async {
          await _exportChatFromContextMenu(chat);
        },
      ),
      AxiMenuAction(
        icon: chat.favorited ? LucideIcons.starOff : LucideIcons.star,
        label: chat.favorited ? l10n.commonUnfavorite : l10n.commonFavorite,
        onPressed: () async {
          await context.read<ChatsCubit>().toggleFavorited(
                jid: chat.jid,
                favorited: !chat.favorited,
              );
        },
      ),
      AxiMenuAction(
        icon: chat.archived ? LucideIcons.undo2 : LucideIcons.archive,
        label: chat.archived ? l10n.commonUnarchive : l10n.commonArchive,
        onPressed: () async {
          await context.read<ChatsCubit>().toggleArchived(
                jid: chat.jid,
                archived: !chat.archived,
              );
        },
      ),
      if (!widget.archivedContext)
        AxiMenuAction(
          icon: chat.hidden ? LucideIcons.eye : LucideIcons.eyeOff,
          label: chat.hidden ? l10n.commonShow : l10n.commonHide,
          onPressed: () async {
            await context.read<ChatsCubit>().toggleHidden(
                  jid: chat.jid,
                  hidden: !chat.hidden,
                );
          },
        ),
      AxiMenuAction(
        icon: LucideIcons.trash2,
        label: l10n.commonDelete,
        destructive: true,
        onPressed: () => _confirmDelete(chat),
      ),
    ];
  }
}

class _ChatActionPanel extends StatefulWidget {
  const _ChatActionPanel({
    required this.chat,
    required this.archivedContext,
    required this.onClose,
    required this.onDelete,
  });

  final Chat chat;
  final bool archivedContext;
  final VoidCallback onClose;
  final VoidCallback onDelete;

  @override
  State<_ChatActionPanel> createState() => _ChatActionPanelState();
}

class _ChatActionPanelState extends State<_ChatActionPanel> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconSize = scaled(context.sizing.menuItemIconSize);
    final spacing = scaled(context.spacing.s);
    final l10n = context.l10n;
    final addressLabel = widget.chat.jid.trim();
    final actionWrap = Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        ContextActionButton(
          icon: Icon(LucideIcons.squareCheck, size: iconSize),
          label: l10n.commonSelect,
          onPressed: () {
            context.read<ChatsCubit>().ensureChatSelected(
                  widget.chat.jid,
                );
            widget.onClose();
          },
        ),
        if (widget.chat.type == ChatType.chat)
          ContextActionButton(
            icon: Icon(LucideIcons.pencilLine, size: iconSize),
            label: l10n.chatContactRenameAction,
            onPressed: _renameContact,
          ),
        ContextActionButton(
          icon: Icon(
            widget.chat.favorited ? LucideIcons.starOff : LucideIcons.star,
            size: iconSize,
          ),
          label: widget.chat.favorited
              ? l10n.commonUnfavorite
              : l10n.commonFavorite,
          onPressed: () async {
            await context.read<ChatsCubit>().toggleFavorited(
                  jid: widget.chat.jid,
                  favorited: !widget.chat.favorited,
                );
            if (!mounted) return;
            widget.onClose();
          },
        ),
        ChatExportActionButton(
          exporting: _exporting,
          onPressed: _exportChat,
          iconSize: iconSize,
          readyLabel: l10n.commonExport,
        ),
        ContextActionButton(
          icon: Icon(
            widget.chat.archived ? LucideIcons.undo2 : LucideIcons.archive,
            size: iconSize,
          ),
          label:
              widget.chat.archived ? l10n.commonUnarchive : l10n.commonArchive,
          onPressed: () async {
            await context.read<ChatsCubit>().toggleArchived(
                  jid: widget.chat.jid,
                  archived: !widget.chat.archived,
                );
            _showSnack(
              widget.chat.archived
                  ? l10n.chatsArchivedRestored
                  : l10n.chatsArchivedHint,
            );
            if (!mounted) return;
            widget.onClose();
          },
        ),
        if (!widget.archivedContext)
          ContextActionButton(
            icon: Icon(
              widget.chat.hidden ? LucideIcons.eye : LucideIcons.eyeOff,
              size: iconSize,
            ),
            label: widget.chat.hidden ? l10n.commonShow : l10n.commonHide,
            onPressed: () async {
              await context.read<ChatsCubit>().toggleHidden(
                    jid: widget.chat.jid,
                    hidden: !widget.chat.hidden,
                  );
              _showSnack(
                widget.chat.hidden
                    ? l10n.chatsVisibleNotice
                    : l10n.chatsHiddenNotice,
              );
              if (!mounted) return;
              widget.onClose();
            },
          ),
        ContextActionButton(
          icon: Icon(LucideIcons.trash2, size: iconSize),
          label: l10n.commonDelete,
          destructive: true,
          onPressed: widget.onDelete,
        ),
      ],
    );
    if (addressLabel.isEmpty) {
      return actionWrap;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SelectableText(
          addressLabel,
          maxLines: 1,
          textAlign: TextAlign.center,
          style: context.textTheme.muted,
        ),
        SizedBox(height: spacing),
        actionWrap,
      ],
    );
  }

  Future<void> _renameContact() async {
    final l10n = context.l10n;
    final result = await showContactRenameDialog(
      context: context,
      initialValue: widget.chat.displayName,
    );
    if (!mounted) return;
    if (result == null) return;
    try {
      await context.read<ChatsCubit>().renameContact(
            jid: widget.chat.jid,
            displayName: result,
          );
      if (!mounted) return;
      _showSnack(l10n.chatContactRenameSuccess);
      widget.onClose();
    } on Exception {
      if (!mounted) return;
      _showSnack(l10n.chatContactRenameFailure);
    }
  }

  Future<void> _exportChat() async {
    final l10n = context.l10n;
    final scheduleExportCleanup =
        context.read<ChatsCubit>().scheduleExportCleanup;
    final confirmed = await _confirmChatExport(context);
    if (!mounted || !confirmed) return;
    setState(() {
      _exporting = true;
    });
    File? exportFile;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: [widget.chat],
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
        countHistory: context.read<ChatsCubit>().countChatHistoryMessages,
        loadHistoryPage: context.read<ChatsCubit>().loadChatHistoryPage,
      );
      exportFile = result.file;
      if (!mounted) return;
      if (exportFile == null) {
        _showSnack(l10n.chatsExportNoContent);
        return;
      }
      await Share.shareXFiles(
        [XFile(exportFile.path)],
        text: l10n.chatsExportShareText,
        subject: l10n.chatsExportShareSubject(widget.chat.displayName),
      );
      if (!mounted) return;
      _showSnack(l10n.chatsExportSuccess);
      widget.onClose();
    } catch (_) {
      if (!mounted) return;
      _showSnack(l10n.chatsExportFailure);
    } finally {
      if (exportFile != null) {
        scheduleExportCleanup(exportFile);
      }
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<bool> _confirmChatExport(BuildContext context) async {
  final l10n = context.l10n;
  final confirmed = await confirm(
    context,
    title: l10n.chatExportWarningTitle,
    message: l10n.chatExportWarningMessage,
    confirmLabel: l10n.commonContinue,
    cancelLabel: l10n.commonCancel,
    destructiveConfirm: false,
  );
  return confirmed == true;
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.highlight});

  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final motion = context.motion;
    final spacing = context.spacing;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) {
      if (!value.isFinite) {
        return value;
      }
      final scaledValue = textScaler.scale(value);
      if (!scaledValue.isFinite || scaledValue <= 0) {
        return value;
      }
      return scaledValue;
    }

    final Color background = highlight
        ? colors.primary
        : colors.secondary.withValues(alpha: motion.tapSplashAlpha);
    final Color borderColor = highlight ? colors.background : colors.border;
    final Color textColor =
        highlight ? colors.primaryForeground : colors.mutedForeground;
    final borderWidth = scaled(context.borderSide.width);
    final cornerRadius = scaled(context.sizing.containerRadius);
    final horizontalPadding = scaled(spacing.s);
    final verticalPadding = scaled(spacing.xs);
    return Semantics(
      container: true,
      label: context.l10n.chatsUnreadLabel(count),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: SquircleBorder(
            cornerRadius: cornerRadius,
            side: BorderSide(color: borderColor, width: borderWidth),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Text(
            '$count',
            maxLines: 1,
            style: context.textTheme.small.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatActionsToggle extends StatelessWidget {
  const _ChatActionsToggle({
    required this.backgroundColor,
    required this.expanded,
    required this.onPressed,
  });

  final Color backgroundColor;
  final bool expanded;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final sizing = context.sizing;
    final icon = expanded ? LucideIcons.x : LucideIcons.ellipsisVertical;
    final tooltip = expanded
        ? context.l10n.chatsHideActions
        : context.l10n.chatsShowActions;
    final button = AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      iconSize: sizing.iconButtonIconSize,
      buttonSize: sizing.iconButtonSize,
      tapTargetSize: sizing.iconButtonSize,
      color: colors.mutedForeground,
      backgroundColor: backgroundColor,
      borderColor: colors.border,
      borderWidth: context.borderSide.width,
      cornerRadius: context.radii.squircle,
    );
    return Semantics(
      container: true,
      button: true,
      toggled: expanded,
      label: tooltip,
      onTap: onPressed,
      child: button,
    );
  }
}

class _ChatSelectionCutoutButton extends StatelessWidget {
  const _ChatSelectionCutoutButton({
    required this.backgroundColor,
    required this.selected,
    required this.onPressed,
  });

  final Color backgroundColor;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Semantics(
      container: true,
      button: true,
      toggled: selected,
      label: selected
          ? context.l10n.chatsSelectedLabel
          : context.l10n.chatsSelectLabel,
      onTap: onPressed,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: backgroundColor,
          shape: SquircleBorder(
            cornerRadius: context.radii.squircle,
            side: BorderSide(
              color: colors.border,
              width: context.borderSide.width,
            ),
          ),
        ),
        child: SelectionIndicator(
          visible: true,
          selected: selected,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
