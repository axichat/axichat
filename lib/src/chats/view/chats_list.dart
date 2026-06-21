// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/avatar/avatar_presentation.dart';
import 'package:axichat/src/avatar/view/app_icon_avatar.dart';
import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/storage/calendar_storage_manager.dart';
import 'package:axichat/src/calendar/storage/chat_calendar_storage.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/view/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/contact_rename_dialog.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/contacts/bloc/contacts_cubit.dart';
import 'package:axichat/src/contacts/view/contacts_list.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/home/bloc/home_bloc.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/profile/bloc/profile_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, searchState) {
        return BlocBuilder<RosterCubit, RosterState>(
          builder: (context, rosterState) {
            final rosterItems =
                rosterState.items ??
                (context.watch<RosterCubit>()[RosterCubit.itemsCacheKey]
                    as List<RosterItem>?) ??
                const <RosterItem>[];
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

  final HomeState searchState;
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
    final profileJid = context.watch<ProfileCubit>().state.jid;
    final calendarStorage = calendarAvailable
        ? context.watch<CalendarStorageManager>().authStorage
        : null;
    final resolvedProfileJid = profileJid.trim();
    final String? selfJid = resolvedProfileJid.isNotEmpty
        ? resolvedProfileJid
        : null;
    final selfIdentity = SelfAvatar(
      jid: selfJid,
      avatar: Avatar.tryParseOrNull(
        path: context.watch<ProfileCubit>().state.avatarPath,
        hash: null,
      ),
      hydrating: context.watch<ProfileCubit>().state.avatarHydrating,
    );
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) =>
          previous.creationStatus != current.creationStatus,
      listener: (context, state) {
        if (state.creationStatus.isSuccess) {
          showToast?.call(
            FeedbackToast.success(message: l10n.chatsCreateGroupSuccess),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        } else if (state.creationStatus.isFailure) {
          showToast?.call(
            FeedbackToast.error(
              message:
                  state.creationFailure?.resolve(l10n) ??
                  l10n.chatsCreateGroupFailure,
            ),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        }
      },
      child: BlocBuilder<ContactsCubit, ContactsState>(
        buildWhen: (previous, current) => previous.items != current.items,
        builder: (context, contactsState) {
          final contactsByAddressKey = _contactsByAddressKey(
            contactsState.items,
          );
          return BlocBuilder<ChatsCubit, ChatsState>(
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
                final visibleItems = state.visibleItems;
                Widget body;
                if (visibleItems.isEmpty) {
                  body = Center(
                    child: Text(
                      l10n.chatsEmptyList,
                      style: context.textTheme.muted,
                    ),
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
                      builder: (context, nowListenable) =>
                          AnimatedChatsListView(
                            items: visibleItems,
                            contactsByAddressKey: contactsByAddressKey,
                            animationDuration: context
                                .watch<SettingsCubit>()
                                .animationDuration,
                            scrollPhysics: scrollPhysics,
                            selectedJids: state.selectedJids,
                            openJid: state.openJid,
                            timestampNowListenable: nowListenable,
                            calendarStorage: calendarStorage,
                            selfIdentity: selfIdentity,
                            onNearEnd: () => unawaited(
                              context.read<ChatsCubit>().loadMoreChats(),
                            ),
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
                              final scrollPhysics =
                                  AlwaysScrollableScrollPhysics(
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

              return child;
            },
          );
        },
      ),
    );
  }
}

class _AnimatedChatTile extends StatelessWidget {
  const _AnimatedChatTile({
    super.key,
    required this.chat,
    required this.contactsByAddressKey,
    required this.animation,
    required this.showContent,
    required this.archivedContext,
    required this.onArchivedTap,
    required this.selectionActive,
    required this.isSelected,
    required this.isOpen,
    required this.timestampNowListenable,
    required this.calendarStorage,
    required this.selfIdentity,
  });

  final Chat chat;
  final Map<String, ContactDirectoryEntry> contactsByAddressKey;
  final Animation<double> animation;
  final bool showContent;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final ValueListenable<DateTime> timestampNowListenable;
  final Storage? calendarStorage;
  final SelfAvatar selfIdentity;

  @override
  Widget build(BuildContext context) {
    Widget child = _ChatTileSlot(
      chat: chat,
      contactsByAddressKey: contactsByAddressKey,
      archivedContext: archivedContext,
      onArchivedTap: onArchivedTap,
      selectionActive: selectionActive,
      isSelected: isSelected,
      isOpen: isOpen,
      timestampNowListenable: timestampNowListenable,
      calendarStorage: calendarStorage,
      selfIdentity: selfIdentity,
    );
    if (showContent) {
      child = FadeTransition(opacity: animation, child: child);
    } else {
      child = Visibility(
        visible: false,
        maintainAnimation: true,
        maintainSize: true,
        maintainState: true,
        child: child,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final transitionChild = constraints.hasBoundedWidth
            ? SizedBox(width: constraints.maxWidth, child: child)
            : child;
        return SizeTransition(
          sizeFactor: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          axisAlignment: -1,
          child: transitionChild,
        );
      },
    );
  }
}

class _ChatTileSlot extends StatelessWidget {
  const _ChatTileSlot({
    required this.chat,
    required this.contactsByAddressKey,
    required this.archivedContext,
    required this.onArchivedTap,
    required this.selectionActive,
    required this.isSelected,
    required this.isOpen,
    required this.timestampNowListenable,
    required this.calendarStorage,
    required this.selfIdentity,
  });

  final Chat chat;
  final Map<String, ContactDirectoryEntry> contactsByAddressKey;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final ValueListenable<DateTime> timestampNowListenable;
  final Storage? calendarStorage;
  final SelfAvatar selfIdentity;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<DateTime>(
      valueListenable: timestampNowListenable,
      builder: (context, timestampNow, _) {
        return ListItemPadding(
          child: ChatListTile(
            item: chat,
            contactsByAddressKey: contactsByAddressKey,
            archivedContext: archivedContext,
            onArchivedTap: onArchivedTap,
            selectionActive: selectionActive,
            isSelected: isSelected,
            isOpen: isOpen,
            timestampNow: timestampNow,
            calendarStorage: calendarStorage,
            selfIdentity: selfIdentity,
          ),
        );
      },
    );
  }
}

@immutable
class _CalendarRoomTileSummary {
  const _CalendarRoomTileSummary({required this.subtitle, this.startTime});

  final String subtitle;
  final DateTime? startTime;
}

_CalendarRoomTileSummary _calendarRoomTileSummary({
  required BuildContext context,
  required Chat chat,
  required Storage? storage,
  required DateTime now,
}) {
  final l10n = context.l10n;
  if (!chat.isCalendarFirstRoom || storage == null) {
    return _CalendarRoomTileSummary(subtitle: l10n.calendarTileNone);
  }
  final calendarState =
      ChatCalendarStorage(storage: storage).readState(chat.jid) ??
      CalendarState.initial();
  final currentTask = calendarState.currentTaskAt(now);
  final nextTask = _nextCalendarRoomTask(calendarState, now);
  final displayTask = currentTask ?? nextTask;
  final subtitle = switch ((currentTask, nextTask)) {
    (final CalendarTask task?, _) => l10n.calendarTileNow(task.title),
    (_, final CalendarTask task?) => l10n.calendarTileNext(task.title),
    _ => l10n.calendarTileNone,
  };
  return _CalendarRoomTileSummary(
    subtitle: subtitle,
    startTime: displayTask?.scheduledTime,
  );
}

CalendarTask? _nextCalendarRoomTask(CalendarState state, DateTime now) {
  final upcomingTasks =
      state.model.tasks.values
          .where(
            (task) =>
                !task.isCompleted &&
                task.scheduledTime != null &&
                task.scheduledTime!.isAfter(now),
          )
          .toList(growable: false)
        ..sort((a, b) => a.scheduledTime!.compareTo(b.scheduledTime!));
  return upcomingTasks.isEmpty ? null : upcomingTasks.first;
}

class _CalendarRoomTitle extends StatelessWidget {
  const _CalendarRoomTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Row(
      children: [
        Icon(
          LucideIcons.calendarClock,
          size: sizing.menuItemIconSize,
          color: colors.primary,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupChatTitle extends StatelessWidget {
  const _GroupChatTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Row(
      children: [
        Icon(
          LucideIcons.users,
          size: sizing.menuItemIconSize,
          color: colors.mutedForeground,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _VerifiedChatTitle extends StatelessWidget {
  const _VerifiedChatTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.copyWith(
              color: colors.foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: spacing.xs),
        AxiTooltip(
          builder: (context) =>
              Text(context.l10n.chatVerifiedServerAnnouncementTooltip),
          child: Icon(
            LucideIcons.shieldCheck,
            size: sizing.menuItemIconSize,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

class _ChatAvatar extends StatelessWidget {
  const _ChatAvatar({
    required this.chat,
    required this.selfIdentity,
    required this.size,
  });

  final Chat chat;
  final SelfAvatar selfIdentity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final avatarData = chat.avatarPresentation(selfAvatar: selfIdentity);
    if (avatarData.isAppIcon) {
      return AxichatAppIconAvatar(size: size);
    }
    return HydratedAxiAvatar(avatar: avatarData, size: size);
  }
}

class _EmailChatTitle extends StatelessWidget {
  const _EmailChatTitle({
    required this.chat,
    required this.selfIdentity,
    required this.title,
  });

  final Chat chat;
  final SelfAvatar selfIdentity;
  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    return Row(
      children: [
        _ChatAvatar(
          chat: chat,
          selfIdentity: selfIdentity,
          size: context.sizing.iconButtonIconSize,
        ),
        SizedBox(width: spacing.xs),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textTheme.small.strong.copyWith(
              color: colors.foreground,
            ),
          ),
        ),
      ],
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
    this.contactsByAddressKey = const <String, ContactDirectoryEntry>{},
    this.calendarStorage,
    this.archivedContext = false,
    this.spamContext = false,
    this.spamUpdating = false,
    this.onArchivedTap,
    this.onMoveToInbox,
  });

  final Chat item;
  final Map<String, ContactDirectoryEntry> contactsByAddressKey;
  final bool selectionActive;
  final bool isSelected;
  final bool isOpen;
  final DateTime timestampNow;
  final Storage? calendarStorage;
  final SelfAvatar selfIdentity;
  final bool archivedContext;
  final bool spamContext;
  final bool spamUpdating;
  final Future<void> Function(Chat chat)? onArchivedTap;
  final Future<void> Function()? onMoveToInbox;

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class AnimatedChatsListView extends StatefulWidget {
  const AnimatedChatsListView({
    super.key,
    required this.items,
    required this.contactsByAddressKey,
    required this.animationDuration,
    required this.scrollPhysics,
    required this.selectedJids,
    required this.openJid,
    required this.timestampNowListenable,
    required this.calendarStorage,
    required this.selfIdentity,
    this.onNearEnd,
  });

  final List<Chat> items;
  final Map<String, ContactDirectoryEntry> contactsByAddressKey;
  final Duration animationDuration;
  final ScrollPhysics scrollPhysics;
  final Set<String> selectedJids;
  final String? openJid;
  final ValueListenable<DateTime> timestampNowListenable;
  final Storage? calendarStorage;
  final SelfAvatar selfIdentity;
  final VoidCallback? onNearEnd;

  @override
  State<AnimatedChatsListView> createState() => _AnimatedChatsListViewState();
}

class _AnimatedChatsListViewState extends State<AnimatedChatsListView> {
  GlobalKey<SliverAnimatedListState> _listKey =
      GlobalKey<SliverAnimatedListState>();
  final ScrollController _scrollController = ScrollController();
  late List<Chat> _displayedItems;

  @override
  void initState() {
    super.initState();
    _displayedItems = List<Chat>.from(widget.items);
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant AnimatedChatsListView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateDisplayedItems(widget.items);
  }

  void _updateDisplayedItems(List<Chat> newItems) {
    final SliverAnimatedListState? listState = _listKey.currentState;
    if (listState == null) {
      setState(() {
        _displayedItems = List<Chat>.from(newItems);
      });
      return;
    }

    Widget removedBuilder(
      Chat removedChat,
      Animation<double> animation,
      bool showContent,
    ) {
      return _AnimatedChatTile(
        key: ValueKey<String>(
          showContent
              ? 'chat-list-removed-${removedChat.jid}'
              : 'chat-list-moved-${removedChat.jid}',
        ),
        chat: removedChat,
        contactsByAddressKey: widget.contactsByAddressKey,
        animation: animation,
        showContent: showContent,
        archivedContext: false,
        onArchivedTap: null,
        selectionActive: widget.selectedJids.isNotEmpty,
        isSelected: widget.selectedJids.contains(removedChat.jid),
        isOpen: widget.openJid == removedChat.jid,
        timestampNowListenable: widget.timestampNowListenable,
        calendarStorage: widget.calendarStorage,
        selfIdentity: widget.selfIdentity,
      );
    }

    bool mutated = false;
    bool metadataChanged = false;
    const largeAnimatedDeltaItemCount = 20;
    if (listEquals(_displayedItems, newItems)) {
      return;
    }
    if (widget.animationDuration == Duration.zero) {
      _resetDisplayedItems(newItems);
      return;
    }
    final currentJids = _displayedItems.map((chat) => chat.jid).toSet();
    final Set<String> newJids = newItems.map((chat) => chat.jid).toSet();
    var retainedCount = 0;
    for (final chat in _displayedItems) {
      if (newJids.contains(chat.jid)) {
        retainedCount += 1;
      }
    }
    final removedCount = _displayedItems.length - retainedCount;
    final insertedCount = newItems
        .where((chat) => !currentJids.contains(chat.jid))
        .length;
    final stableRetainedJids = _stableRetainedJids(newItems);
    final movedCount = retainedCount - stableRetainedJids.length;
    if (removedCount + insertedCount + movedCount >
        largeAnimatedDeltaItemCount) {
      _resetDisplayedItems(newItems);
      return;
    }

    for (int i = _displayedItems.length - 1; i >= 0; i--) {
      final Chat chat = _displayedItems[i];
      if (newJids.contains(chat.jid)) {
        continue;
      }
      final Chat removedChat = _displayedItems.removeAt(i);
      listState.removeItem(
        i,
        (context, animation) => removedBuilder(removedChat, animation, true),
        duration: widget.animationDuration,
      );
      mutated = true;
    }

    for (int i = _displayedItems.length - 1; i >= 0; i--) {
      final Chat chat = _displayedItems[i];
      if (stableRetainedJids.contains(chat.jid)) {
        continue;
      }
      final Chat movedChat = _displayedItems.removeAt(i);
      listState.removeItem(
        i,
        (context, animation) => removedBuilder(movedChat, animation, false),
        duration: widget.animationDuration,
      );
      mutated = true;
    }

    for (int targetIndex = 0; targetIndex < newItems.length; targetIndex++) {
      final Chat nextChat = newItems[targetIndex];
      if (targetIndex >= _displayedItems.length ||
          _displayedItems[targetIndex].jid != nextChat.jid) {
        final existingIndex = _displayedItems.indexWhere(
          (chat) => chat.jid == nextChat.jid,
          targetIndex + 1,
        );
        if (existingIndex != -1) {
          _resetDisplayedItems(newItems);
          return;
        }
        _displayedItems.insert(targetIndex, nextChat);
        listState.insertItem(targetIndex, duration: widget.animationDuration);
        mutated = true;
        continue;
      }

      if (_displayedItems[targetIndex] != nextChat) {
        _displayedItems[targetIndex] = nextChat;
        metadataChanged = true;
      }
    }

    if (_displayedItems.length != newItems.length) {
      _resetDisplayedItems(newItems);
      return;
    }
    if (mutated || metadataChanged) {
      setState(() {});
    }
  }

  Set<String> _stableRetainedJids(List<Chat> newItems) {
    final oldIndexByJid = <String, int>{};
    for (var index = 0; index < _displayedItems.length; index++) {
      oldIndexByJid[_displayedItems[index].jid] = index;
    }
    final retainedJids = <String>[];
    final retainedOldIndexes = <int>[];
    for (final chat in newItems) {
      final oldIndex = oldIndexByJid[chat.jid];
      if (oldIndex == null) {
        continue;
      }
      retainedJids.add(chat.jid);
      retainedOldIndexes.add(oldIndex);
    }
    final stablePositions = _longestIncreasingSubsequencePositions(
      retainedOldIndexes,
    );
    return {for (final position in stablePositions) retainedJids[position]};
  }

  List<int> _longestIncreasingSubsequencePositions(List<int> values) {
    if (values.isEmpty) {
      return const <int>[];
    }
    final previousIndexes = List<int>.filled(values.length, -1);
    final tailPositions = <int>[];
    for (var index = 0; index < values.length; index++) {
      var low = 0;
      var high = tailPositions.length;
      while (low < high) {
        final mid = (low + high) >> 1;
        if (values[tailPositions[mid]] < values[index]) {
          low = mid + 1;
        } else {
          high = mid;
        }
      }
      if (low > 0) {
        previousIndexes[index] = tailPositions[low - 1];
      }
      if (low == tailPositions.length) {
        tailPositions.add(index);
      } else {
        tailPositions[low] = index;
      }
    }

    final positions = <int>[];
    var index = tailPositions.last;
    while (index != -1) {
      positions.add(index);
      index = previousIndexes[index];
    }
    return positions.reversed.toList(growable: false);
  }

  void _resetDisplayedItems(List<Chat> newItems) {
    setState(() {
      _listKey = GlobalKey<SliverAnimatedListState>();
      _displayedItems = List<Chat>.from(newItems);
    });
  }

  void _handleScroll() {
    final onNearEnd = widget.onNearEnd;
    if (onNearEnd == null || !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions) {
      return;
    }
    final nearEndExtent = context.sizing.chatTileMinHeight * 4;
    if (position.extentAfter <= nearEndExtent) {
      onNearEnd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final topSpacer = spacing.m;
    final bottomSentinelInset = spacing.xxl;
    final scrollbarInset = spacing.xxs;
    final scrollbarThickness = spacing.xs;
    final slivers = <Widget>[
      SliverToBoxAdapter(child: SizedBox(height: topSpacer)),
      SliverAnimatedList(
        key: _listKey,
        initialItemCount: _displayedItems.length,
        itemBuilder: (context, index, animation) {
          final chat = _displayedItems[index];
          return _AnimatedChatTile(
            key: ValueKey<String>('chat-list-row-${chat.jid}'),
            chat: chat,
            contactsByAddressKey: widget.contactsByAddressKey,
            animation: animation,
            showContent: true,
            archivedContext: false,
            onArchivedTap: null,
            selectionActive: widget.selectedJids.isNotEmpty,
            isSelected: widget.selectedJids.contains(chat.jid),
            isOpen: widget.openJid == chat.jid,
            timestampNowListenable: widget.timestampNowListenable,
            calendarStorage: widget.calendarStorage,
            selfIdentity: widget.selfIdentity,
          );
        },
      ),
      SliverToBoxAdapter(child: SizedBox(height: bottomSentinelInset)),
    ];
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
  Size? _cachedTimestampSize;
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
    if (oldWidget.item.lastMessage != widget.item.lastMessage ||
        oldWidget.item.primaryView != widget.item.primaryView) {
      _cachedTimestampLabel = null;
      _cachedTimestampSize = null;
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
      final scaledValue = textScaler.scale(value);
      if (!scaledValue.isFinite || scaledValue <= 0) {
        return value;
      }
      return scaledValue;
    }

    final scaleFactor = textScaler.scale(1);
    if (_textScaleFactor != scaleFactor) {
      _textScaleFactor = scaleFactor;
      _cachedTimestampLabel = null;
      _cachedTimestampSize = null;
    }

    final displayName = item.displayName;
    final calendarSummary = _calendarRoomTileSummary(
      context: context,
      chat: item,
      storage: widget.calendarStorage,
      now: widget.timestampNow,
    );
    final isCalendarFirstRoom = item.isCalendarFirstRoom;
    final isEmailChatRow =
        item.defaultTransport.isEmail && !isCalendarFirstRoom;
    final editContact = widget.archivedContext || widget.spamContext
        ? null
        : _editableContactForChat(
            contactsByAddressKey: widget.contactsByAddressKey,
            chat: item,
          );
    final int unreadCount = math.max(0, item.unreadCount);
    final bool showUnreadBadge = unreadCount > 0;
    final double unreadDiameter = showUnreadBadge
        ? _resolveUnreadDiameter(context)
        : 0.0;
    final unreadCutoutVerticalClearance = spacing.xs;
    final unreadMinDepth = spacing.m;
    final double unreadDepth = showUnreadBadge
        ? math.max(
            unreadMinDepth,
            (unreadDiameter / 2) + unreadCutoutVerticalClearance,
          )
        : 0.0;
    final subtitleText = isCalendarFirstRoom
        ? calendarSummary.subtitle
        : _subtitlePreview(item.lastMessage);
    final trailingTimestampLabel = isCalendarFirstRoom
        ? _calendarRoomTimestampLabel(calendarSummary.startTime)
        : null;
    final timestampLabel = isCalendarFirstRoom
        ? null
        : item.lastMessage == null
        ? null
        : formatTimeSinceLabel(
            l10n,
            widget.timestampNow,
            item.lastChangeTimestamp,
          );
    final timestampCutoutSideGap = spacing.xs;
    final timestampOffset = spacing.xxs;
    final timestampSize = timestampLabel == null
        ? null
        : _resolveTimestampSize(context, timestampLabel);
    final timestampCutoutDepth = timestampSize == null
        ? 0.0
        : timestampSize.height / 2;
    final timestampThickness = timestampSize == null
        ? 0.0
        : timestampSize.width + scaled(timestampCutoutSideGap * 2);
    final selectionActive = widget.selectionActive;
    final isSelected = widget.isSelected;
    final isOpen = widget.isOpen;

    final brightness = context.brightness;
    final overlayAlpha = brightness == Brightness.dark
        ? motion.tapHoverAlpha
        : motion.tapSplashAlpha;
    final selectionOverlay = colors.primary.withValues(alpha: overlayAlpha);
    final tileBackgroundColor = isOpen
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;
    late final VoidCallback tileOnTap;
    if (selectionActive) {
      tileOnTap = () =>
          context.read<ChatsCubit>().toggleChatSelection(item.jid);
    } else {
      tileOnTap = () async {
        await _handleTap(item);
      };
    }
    final leadingAvatarSize = sizing.iconButtonSize;
    final cutoutGap = spacing.xxs;
    final iconButtonSize = sizing.iconButtonSize;
    final iconCutoutDepth = (iconButtonSize / 2) + cutoutGap;
    final tilePadding = EdgeInsetsDirectional.only(
      start: scaled(spacing.s),
      end: scaled((showUnreadBadge ? spacing.m : spacing.s) + iconCutoutDepth),
      top: scaled(isEmailChatRow ? spacing.xxs : spacing.xs),
      bottom: scaled(isEmailChatRow ? spacing.xxs : spacing.xs),
    );
    final tileActions = trailingTimestampLabel == null
        ? null
        : <Widget>[
            Text(
              trailingTimestampLabel,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ];
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
        maxWidth: scaled(sizing.iconButtonTapTarget),
        maxHeight: scaled(sizing.iconButtonTapTarget),
      ),
      selected: isOpen || isSelected,
      paintSurface: false,
      contentPadding: tilePadding,
      minTileHeight: scaled(sizing.chatTileMinHeight),
      horizontalTitleGap: isEmailChatRow ? null : scaled(spacing.s),
      tapBounce: false,
      leading: isEmailChatRow
          ? null
          : _ChatAvatar(
              chat: item,
              selfIdentity: widget.selfIdentity,
              size: leadingAvatarSize,
            ),
      title:
          isCalendarFirstRoom ||
              isEmailChatRow ||
              item.type == ChatType.groupChat ||
              item.isAxiImServerAnnouncementThread
          ? null
          : displayName,
      titleWidget: isCalendarFirstRoom
          ? _CalendarRoomTitle(title: displayName)
          : isEmailChatRow
          ? _EmailChatTitle(
              chat: item,
              selfIdentity: widget.selfIdentity,
              title: displayName,
            )
          : item.type == ChatType.groupChat
          ? _GroupChatTitle(title: displayName)
          : item.isAxiImServerAnnouncementThread
          ? _VerifiedChatTitle(title: displayName)
          : null,
      subtitle: subtitleText,
      subtitlePlaceholder: isCalendarFirstRoom
          ? l10n.calendarTileNone
          : l10n.chatEmptyMessages,
      actions: tileActions,
    );

    final iconCutoutThickness = iconButtonSize + (cutoutGap * 2);
    final iconCutoutRadius = context.radii.squircle;
    final cutouts = <CutoutSpec>[
      if (showUnreadBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.84, -1),
          depth: unreadDepth + spacing.xxs,
          thickness: unreadDiameter + (spacing.xxs * 2),
          cornerRadius: context.radii.squircle,
          child: _UnreadBadge(
            count: unreadCount,
            highlight: showUnreadBadge,
            diameter: unreadDiameter,
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
          depth: timestampCutoutDepth,
          thickness: timestampThickness,
          cornerRadius: context.radii.container,
          child: Transform.translate(
            offset: Offset(0, -scaled(timestampOffset)),
            child: Text(timestampLabel, style: context.textTheme.muted),
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
                      scaled(spacing.m),
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: scaled(spacing.m),
                      ),
                      child: _ChatActionPanel(
                        chat: item,
                        editContact: editContact,
                        archivedContext: widget.archivedContext,
                        spamContext: widget.spamContext,
                        spamUpdating: widget.spamUpdating,
                        onMoveToInbox: widget.onMoveToInbox,
                        onEditContact: _editContact,
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
    Widget tileContent = tileSurface.withTapBounce();
    if (isDesktop) {
      tileContent = AxiContextMenuRegion(
        longPressEnabled: false,
        items: [AxiMenu(actions: _chatContextMenuActions(item, editContact))],
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

  Size _resolveTimestampSize(BuildContext context, String label) {
    final cachedTimestampSize = _cachedTimestampSize;
    if (_cachedTimestampLabel == label && cachedTimestampSize != null) {
      return cachedTimestampSize;
    }
    final painter = TextPainter(
      text: TextSpan(text: label, style: context.textTheme.muted),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.of(context).textScaler,
    )..layout();
    _cachedTimestampLabel = label;
    _cachedTimestampSize = painter.size;
    return painter.size;
  }

  double _resolveUnreadDiameter(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final baseDiameter = context.sizing.iconButtonIconSize;
    final scaledDiameter = textScaler.scale(baseDiameter);
    if (!scaledDiameter.isFinite || scaledDiameter <= 0) {
      return baseDiameter;
    }
    return scaledDiameter;
  }

  String? _calendarRoomTimestampLabel(DateTime? startTime) {
    if (startTime == null) {
      return null;
    }
    return TimeOfDay.fromDateTime(startTime).format(context);
  }

  String? _subtitlePreview(String? rawMessage) {
    final String? trimmed = rawMessage?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (CalendarSyncMessage.looksLikeEnvelope(trimmed)) {
      return null;
    }
    if (ChatSubjectCodec.containsInviteEnvelope(trimmed)) {
      return context.l10n.chatInviteBodyLabel;
    }
    if (ChatSubjectCodec.containsInviteRevocationEnvelope(trimmed)) {
      return context.l10n.chatInviteRevokedLabel;
    }
    final split = ChatSubjectCodec.splitXmppBody(trimmed);
    final subject = _collapsePreviewText(split.subject);
    final body = _collapsePreviewText(
      ChatSubjectCodec.previewBodyText(split.body),
    );
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
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceFirst(RegExp(r'\s+[—–]$'), '')
        .trim();
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

  Future<void> _editContact(ContactDirectoryEntry contact) async {
    _hideActions();
    await showContactDetailsSheet(context: context, contact: contact);
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
            return AxiDialog(
              constraints: BoxConstraints(
                maxWidth: context.sizing.dialogMaxWidth,
              ),
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
    final scheduleExportCleanup = context
        .read<ChatsCubit>()
        .scheduleExportCleanup;
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
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(exportFile.path)],
          text: l10n.chatsExportShareText,
          subject: l10n.chatsExportShareSubject(chat.displayName),
        ),
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

  List<AxiMenuAction> _chatContextMenuActions(
    Chat chat,
    ContactDirectoryEntry? editContact,
  ) {
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
      if (editContact != null)
        AxiMenuAction(
          icon: LucideIcons.userRound,
          label: l10n.chatContactEditAction,
          onPressed: () async {
            await _editContact(editContact);
          },
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
      if (widget.spamContext)
        AxiMenuAction(
          icon: LucideIcons.inbox,
          label: l10n.spamMoveToInbox,
          enabled: !widget.spamUpdating,
          onPressed: () async {
            final moveToInbox = widget.onMoveToInbox;
            if (moveToInbox == null) {
              return;
            }
            await moveToInbox();
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
        icon: LucideIcons.settings,
        label: l10n.chatSettings,
        onPressed: () async {
          await context.read<ChatsCubit>().openChat(
            jid: chat.jid,
            route: ChatRouteIndex.settings,
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
    required this.editContact,
    required this.archivedContext,
    required this.spamContext,
    required this.spamUpdating,
    required this.onMoveToInbox,
    required this.onEditContact,
    required this.onClose,
    required this.onDelete,
  });

  final Chat chat;
  final ContactDirectoryEntry? editContact;
  final bool archivedContext;
  final bool spamContext;
  final bool spamUpdating;
  final Future<void> Function()? onMoveToInbox;
  final Future<void> Function(ContactDirectoryEntry contact) onEditContact;
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
    final addressLabel = widget.chat.isAxichatWelcomeThread
        ? ''
        : widget.chat.jid.trim();
    final actionWrap = Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        ContextActionButton(
          icon: Icon(LucideIcons.squareCheck, size: iconSize),
          label: l10n.commonSelect,
          onPressed: () {
            context.read<ChatsCubit>().ensureChatSelected(widget.chat.jid);
            widget.onClose();
          },
        ),
        if (widget.chat.type == ChatType.chat &&
            !widget.chat.isAxichatWelcomeThread &&
            !widget.chat.isAxiImServerAnnouncementThread)
          ContextActionButton(
            icon: Icon(LucideIcons.pencilLine, size: iconSize),
            label: l10n.chatContactRenameAction,
            onPressed: _renameContact,
          ),
        if (widget.editContact != null)
          ContextActionButton(
            icon: Icon(LucideIcons.userRound, size: iconSize),
            label: l10n.chatContactEditAction,
            onPressed: _editContact,
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
          label: widget.chat.archived
              ? l10n.commonUnarchive
              : l10n.commonArchive,
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
        if (widget.spamContext)
          ContextActionButton(
            icon: Icon(LucideIcons.inbox, size: iconSize),
            label: l10n.spamMoveToInbox,
            onPressed: widget.spamUpdating ? null : _moveToInbox,
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
          icon: Icon(LucideIcons.settings, size: iconSize),
          label: l10n.chatSettings,
          onPressed: () async {
            await context.read<ChatsCubit>().openChat(
              jid: widget.chat.jid,
              route: ChatRouteIndex.settings,
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
    final paddedActionWrap = Padding(
      padding: EdgeInsetsDirectional.only(bottom: scaled(context.spacing.xs)),
      child: actionWrap,
    );
    if (addressLabel.isEmpty) {
      return paddedActionWrap;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: SelectableText(
            addressLabel,
            maxLines: 1,
            textAlign: TextAlign.center,
            textWidthBasis: TextWidthBasis.parent,
            style: context.textTheme.muted,
          ),
        ),
        SizedBox(height: spacing),
        paddedActionWrap,
      ],
    );
  }

  Future<void> _moveToInbox() async {
    final moveToInbox = widget.onMoveToInbox;
    if (moveToInbox == null) {
      return;
    }
    await moveToInbox();
    if (!mounted) return;
    widget.onClose();
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

  Future<void> _editContact() async {
    final contact = widget.editContact;
    if (contact == null) {
      return;
    }
    await widget.onEditContact(contact);
  }

  Future<void> _exportChat() async {
    final l10n = context.l10n;
    final scheduleExportCleanup = context
        .read<ChatsCubit>()
        .scheduleExportCleanup;
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
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(exportFile.path)],
          text: l10n.chatsExportShareText,
          subject: l10n.chatsExportShareSubject(widget.chat.displayName),
        ),
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

ContactDirectoryEntry? _editableContactForChat({
  required Map<String, ContactDirectoryEntry> contactsByAddressKey,
  required Chat chat,
}) {
  if (chat.type != ChatType.chat ||
      chat.isAxichatWelcomeThread ||
      chat.isAxiImServerAnnouncementThread) {
    return null;
  }
  for (final candidate in chat.identityAddresses) {
    final contact = contactsByAddressKey[contactDirectoryAddressKey(candidate)];
    if (contact != null) {
      return contact;
    }
  }
  return null;
}

Map<String, ContactDirectoryEntry> _contactsByAddressKey(
  List<ContactDirectoryEntry>? contacts,
) {
  if (contacts == null || contacts.isEmpty) {
    return const <String, ContactDirectoryEntry>{};
  }
  final contactsByAddressKey = <String, ContactDirectoryEntry>{};
  for (final contact in contacts) {
    final key = contactDirectoryAddressKey(contact.address);
    if (key.isNotEmpty) {
      contactsByAddressKey[key] = contact;
    }
  }
  return Map.unmodifiable(contactsByAddressKey);
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.highlight,
    required this.diameter,
  });

  final int count;
  final bool highlight;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;

    final Color background = highlight
        ? colors.destructive
        : colors.destructive.withValues(alpha: context.motion.tapSplashAlpha);
    final Color borderColor = highlight ? colors.background : colors.border;
    final Color textColor = colors.destructiveForeground;
    return Semantics(
      container: true,
      label: context.l10n.chatsUnreadLabel(count),
      child: AxiCountBadge(
        count: count,
        diameter: diameter,
        backgroundColor: background,
        borderColor: borderColor,
        textColor: textColor,
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
