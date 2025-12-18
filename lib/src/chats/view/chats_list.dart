import 'dart:async';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/utils/chat_history_exporter.dart';
import 'package:axichat/src/chats/view/calendar_tile.dart';
import 'package:axichat/src/chats/view/widgets/chat_export_action_button.dart';
import 'package:axichat/src/chats/view/widgets/contact_rename_dialog.dart';
import 'package:axichat/src/chats/view/widgets/transport_aware_avatar.dart';
import 'package:axichat/src/common/env.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/feedback_toast.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
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
    final l10n = context.l10n;
    final showToast = ShadToaster.maybeOf(context)?.show;
    const creationSuccessMessage = 'Group chat created.';
    const creationFailureMessage = 'Could not create group chat.';
    const refreshFailureMessage = 'Sync failed.';
    const refreshSpinnerExtent = 56.0;
    const refreshSpinnerDimension = 20.0;
    const refreshOffsetToArmed = 96.0;
    const refreshRevealThreshold = 0.02;
    const refreshIndicatorPadding = 16.0;
    return BlocListener<ChatsCubit, ChatsState>(
      listenWhen: (previous, current) =>
          previous.creationStatus != current.creationStatus ||
          previous.refreshStatus != current.refreshStatus,
      listener: (context, state) {
        if (state.creationStatus.isSuccess) {
          showToast?.call(
            FeedbackToast.success(message: creationSuccessMessage),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        } else if (state.creationStatus.isFailure) {
          showToast?.call(
            FeedbackToast.error(message: creationFailureMessage),
          );
          context.read<ChatsCubit>().clearCreationStatus();
        }
        if (state.refreshStatus.isSuccess) {
          context.read<ChatsCubit>().clearRefreshStatus();
        } else if (state.refreshStatus.isFailure) {
          showToast?.call(
            FeedbackToast.error(message: refreshFailureMessage),
          );
          context.read<ChatsCubit>().clearRefreshStatus();
        }
      },
      child: BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
        selector: (state) {
          final items = state.items;
          if (items == null) return null;
          return items.where((chat) => !chat.archived && !chat.spam).toList();
        },
        builder: (context, items) {
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
            child = BlocBuilder<HomeSearchCubit, HomeSearchState>(
              builder: (context, searchState) {
                final tabState = searchState.stateFor(HomeTab.chats);
                final query = searchState.active
                    ? tabState.query.trim().toLowerCase()
                    : '';
                final filterId = tabState.filterId;
                final sortOrder = tabState.sort;
                return BlocBuilder<RosterCubit, RosterState>(
                  builder: (context, rosterState) {
                    final rosterContacts = rosterState is RosterAvailable
                        ? (rosterState.items ?? const <RosterItem>[])
                            .map((item) => item.jid)
                            .toSet()
                        : const <String>{};
                    final includeCalendarShortcut =
                        showCalendarShortcut && calendarAvailable;

                    var visibleItems = items
                        .where(
                          (chat) => _chatMatchesFilter(
                            chat,
                            filterId,
                            rosterContacts,
                          ),
                        )
                        .toList();

                    if (query.isNotEmpty) {
                      visibleItems = visibleItems
                          .where((chat) => _chatMatchesQuery(chat, query))
                          .toList();
                    }

                    visibleItems.sort(
                      (a, b) => sortOrder.isNewestFirst
                          ? b.lastChangeTimestamp
                              .compareTo(a.lastChangeTimestamp)
                          : a.lastChangeTimestamp
                              .compareTo(b.lastChangeTimestamp),
                    );

                    Widget body;
                    if (visibleItems.isEmpty) {
                      body = Column(
                        children: [
                          ListItemPadding(
                            child: BlocBuilder<CalendarBloc, CalendarState>(
                              builder: (context, state) {
                                final currentTask =
                                    state.currentTaskAt(DateTime.now());
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
                        parent: ScrollConfiguration.of(context)
                            .getScrollPhysics(context),
                      );
                      body = ColoredBox(
                        color: context.colorScheme.background,
                        child: ListView.builder(
                          physics: scrollPhysics,
                          itemCount: visibleItems.length +
                              (includeCalendarShortcut ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (includeCalendarShortcut && index == 0) {
                              return ListItemPadding(
                                child: BlocBuilder<CalendarBloc, CalendarState>(
                                  builder: (context, state) {
                                    final currentTask =
                                        state.currentTaskAt(DateTime.now());
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
                              );
                            }

                            final offset = includeCalendarShortcut ? 1 : 0;
                            final item = visibleItems[index - offset];
                            return ListItemPadding(
                              child: ChatListTile(item: item),
                            );
                          },
                        ),
                      );
                    }

                    return KeyedSubtree(
                      key: const ValueKey('chats-loaded'),
                      child: visibleItems.isEmpty
                          ? ColoredBox(
                              color: context.colorScheme.background,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final scrollPhysics =
                                      AlwaysScrollableScrollPhysics(
                                    parent: ScrollConfiguration.of(context)
                                        .getScrollPhysics(context),
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
                  },
                );
              },
            );
          }

          final animated = AnimatedSwitcher(
            duration: context.watch<SettingsCubit>().animationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (widget, animation) {
              final offsetAnimation = Tween<Offset>(
                begin: const Offset(0, 0.08),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: offsetAnimation,
                  child: widget,
                ),
              );
            },
            child: child,
          );
          final env = EnvScope.of(context);
          final enableRefresh = env.navPlacement == NavPlacement.bottom;
          if (!enableRefresh) return animated;

          return CustomRefreshIndicator(
            onRefresh: context.read<ChatsCubit>().refreshHomeSync,
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
                          dimension: refreshSpinnerDimension,
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
                                  bottom: BorderSide(
                                    color: context.colorScheme.border,
                                  ),
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(
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

bool _chatMatchesFilter(
  Chat chat,
  String? filterId,
  Set<String> contacts,
) {
  final normalized = filterId ?? 'all';
  switch (normalized) {
    case 'contacts':
      return !chat.hidden && contacts.contains(chat.jid);
    case 'nonContacts':
      return !chat.hidden && !contacts.contains(chat.jid);
    case 'xmpp':
      return !chat.hidden && chat.transport.isXmpp;
    case 'email':
      return !chat.hidden && chat.transport.isEmail;
    case 'hidden':
      return chat.hidden;
    default:
      return !chat.hidden;
  }
}

bool _chatMatchesQuery(Chat chat, String query) {
  if (query.isEmpty) return true;
  final lower = query.toLowerCase();
  final alias = chat.contactDisplayName?.toLowerCase() ?? '';
  return chat.title.toLowerCase().contains(lower) ||
      alias.contains(lower) ||
      chat.jid.toLowerCase().contains(lower) ||
      (chat.lastMessage?.toLowerCase().contains(lower) ?? false) ||
      (chat.alert?.toLowerCase().contains(lower) ?? false);
}

class ChatListTile extends StatefulWidget {
  const ChatListTile({
    super.key,
    required this.item,
    this.archivedContext = false,
    this.onArchivedTap,
  });

  final Chat item;
  final bool archivedContext;
  final Future<void> Function(Chat chat)? onArchivedTap;

  @override
  State<ChatListTile> createState() => _ChatListTileState();
}

class _ChatListTileState extends State<ChatListTile> {
  bool _showActions = false;
  bool _focused = false;
  late final FocusNode _focusNode;
  late DateTime _timestampNow;
  Timer? _timestampTicker;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'chat-tile-${widget.item.jid}');
    _timestampNow = DateTime.now();
    _timestampTicker = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (!mounted) return;
        setState(() {
          _timestampNow = DateTime.now();
        });
      },
    );
  }

  @override
  void dispose() {
    _timestampTicker?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;
    final colors = context.colorScheme;
    final textScaler = MediaQuery.of(context).textScaler;
    final isDesktop = EnvScope.maybeOf(context)?.isDesktopPlatform ?? false;
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

    final displayName = item.displayName;
    final int unreadCount = math.max(0, item.unreadCount);
    final bool showUnreadBadge = unreadCount > 0;
    final double unreadThickness = showUnreadBadge
        ? _measureUnreadBadgeWidth(
            context,
            unreadCount,
          )
        : 0.0;
    final double unreadHeight = showUnreadBadge
        ? _measureUnreadBadgeHeight(
            context,
            unreadCount,
          )
        : 0.0;
    final double unreadDepth = showUnreadBadge
        ? math.max(
            _unreadBadgeMinDepth,
            (unreadHeight / 2) +
                _unreadBadgeCutoutVerticalClearance +
                _unreadBadgeCutoutDepthAdjustment,
          )
        : 0.0;
    final subtitleText = _subtitlePreview(item.lastMessage);
    final timestampLabel = item.lastMessage == null
        ? null
        : formatTimeSinceLabel(_timestampNow, item.lastChangeTimestamp);
    final timestampThickness = timestampLabel == null
        ? 0.0
        : math.max(
            scaled(32.0),
            _measureLabelWidth(
                  context,
                  timestampLabel,
                ) +
                scaled(16.0),
          );
    final ChatsCubit? chatsCubit = context.watch<ChatsCubit?>();
    final ChatsState? chatsState = chatsCubit?.state;
    final selectedJids = chatsState?.selectedJids ?? const <String>{};
    final selectionActive = selectedJids.isNotEmpty;
    final isSelected = selectedJids.contains(item.jid);
    if (selectionActive && _showActions) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _showActions = false;
        });
      });
    }

    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final tileBackgroundColor = item.open
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;
    late final VoidCallback tileOnTap;
    if (chatsState == null) {
      tileOnTap = () {
        unawaited(_handleTap(item));
      };
    } else if (selectionActive) {
      tileOnTap =
          () => context.read<ChatsCubit>().toggleChatSelection(item.jid);
    } else {
      tileOnTap = () {
        unawaited(_handleTap(item));
      };
    }
    final tilePadding = EdgeInsetsDirectional.only(
      start: scaled(16),
      end: scaled(showUnreadBadge ? 40 : 28),
      top: scaled(4),
      bottom: scaled(4),
    );
    final tile = AxiListTile(
      key: Key(item.jid),
      onTap: tileOnTap,
      onLongPress: chatsCubit == null
          ? null
          : () {
              if (selectionActive) {
                chatsCubit.toggleChatSelection(item.jid);
              } else {
                chatsCubit.ensureChatSelected(item.jid);
              }
              if (_showActions) {
                setState(() => _showActions = false);
              }
            },
      leadingConstraints: BoxConstraints(
        maxWidth: scaled(72),
        maxHeight: scaled(80),
      ),
      selected: item.open || isSelected,
      paintSurface: false,
      contentPadding: tilePadding,
      tapBounce: false,
      leading: TransportAwareAvatar(chat: item),
      title: displayName,
      subtitle: subtitleText,
      subtitlePlaceholder: l10n.chatEmptyMessages,
    );

    final cutouts = <CutoutSpec>[
      if (showUnreadBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.84, -1),
          depth: unreadDepth,
          thickness: unreadThickness,
          cornerRadius: _unreadBadgeCornerRadius,
          child: Transform.translate(
            offset: Offset(0, scaled(_unreadBadgeCutoutChildVerticalOffset)),
            child: _UnreadBadge(
              count: unreadCount,
              highlight: showUnreadBadge,
            ),
          ),
        ),
      CutoutSpec(
        edge: CutoutEdge.right,
        alignment: const Alignment(1.02, 0),
        depth: 32,
        thickness: 46,
        cornerRadius: 18,
        child: selectionActive
            ? _ChatSelectionCutoutButton(
                backgroundColor: tileBackgroundColor,
                selected: isSelected,
                onPressed: () =>
                    context.read<ChatsCubit?>()?.toggleChatSelection(item.jid),
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
          depth: 16,
          thickness: timestampThickness,
          cornerRadius: 18,
          child: Transform.translate(
            offset: Offset(0, -scaled(3)),
            child: Text(
              timestampLabel,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
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
        cornerRadius: scaled(18),
        side: BorderSide(color: surfaceBorderColor),
      ),
      child: Column(
        children: [
          tile,
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            sizeCurve: Curves.easeInOutCubic,
            crossFadeState: _showActions
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                scaled(16),
                0,
                scaled(16),
                scaled(20),
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: scaled(18)),
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
        items: _chatContextMenuItems(item, chatsState),
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

  String? _subtitlePreview(String? rawMessage) {
    final String? trimmed = rawMessage?.trim();
    if (trimmed == null || trimmed.isEmpty) {
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
    if (context.read<ChatsCubit?>() == null) return;
    if (widget.archivedContext && chat.archived) {
      final handler = widget.onArchivedTap;
      if (handler != null) {
        await handler(chat);
        return;
      }
    }
    unawaited(context.read<ChatsCubit>().openChat(jid: chat.jid));
  }

  Future<void> _confirmDelete(Chat chat) async {
    final l10n = context.l10n;
    if (context.read<ChatsCubit?>() == null) return;
    var deleteMessages = false;
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ShadDialog(
              title: Text(
                l10n.commonConfirm,
                style: context.modalHeaderTextStyle,
              ),
              actions: [
                ShadButton.outline(
                  onPressed: () => dialogContext.pop(false),
                  child: Text(l10n.commonCancel),
                ).withTapBounce(),
                ShadButton.destructive(
                  onPressed: () => dialogContext.pop(true),
                  child: Text(l10n.commonContinue),
                ).withTapBounce(),
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
                    const SizedBox.square(dimension: 10.0),
                    ShadGestureDetector(
                      cursor: SystemMouseCursors.click,
                      hoverStrategies: mobileHoverStrategies,
                      onTap: () =>
                          setState(() => deleteMessages = !deleteMessages),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 44,
                            height: 44,
                            child: Center(
                              child: Checkbox(
                                value: deleteMessages,
                                activeColor: context.colorScheme.primary,
                                checkColor:
                                    context.colorScheme.primaryForeground,
                                side: BorderSide(
                                  color: context.colorScheme.border,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                onChanged: (value) => setState(
                                  () => deleteMessages = value ?? false,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l10n.chatsDeleteMessagesOption,
                              style: context.textTheme.muted,
                            ),
                          ),
                        ],
                      ),
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportChatFromContextMenu(Chat chat) async {
    final l10n = context.l10n;
    if (context.read<ChatsCubit?>() == null) return;
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: [chat],
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
      );
      if (!mounted) return;
      final file = result.file;
      if (file == null) {
        _showMessage(l10n.chatsExportNoContent);
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
        text: l10n.chatsExportShareText,
        subject: l10n.chatsExportShareSubject(chat.displayName),
      );
      if (!mounted) return;
      _showMessage(l10n.chatsExportSuccess);
    } catch (_) {
      if (!mounted) return;
      _showMessage(l10n.chatsExportFailure);
    }
  }

  List<Widget> _chatContextMenuItems(Chat chat, ChatsState? chatsState) {
    final l10n = context.l10n;
    final disabled = chatsState == null;
    return [
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.messagesSquare),
        onPressed: disabled ? null : () => unawaited(_handleTap(chat)),
        child: Text(l10n.commonOpen),
      ),
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.squareCheck),
        onPressed: disabled
            ? null
            : () => context.read<ChatsCubit>().ensureChatSelected(chat.jid),
        child: Text(l10n.commonSelect),
      ),
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.share2),
        onPressed:
            disabled ? null : () => unawaited(_exportChatFromContextMenu(chat)),
        child: Text(l10n.commonExport),
      ),
      ShadContextMenuItem(
        leading: Icon(
          chat.favorited ? LucideIcons.starOff : LucideIcons.star,
        ),
        onPressed: disabled
            ? null
            : () async {
                await context.read<ChatsCubit>().toggleFavorited(
                      jid: chat.jid,
                      favorited: !chat.favorited,
                    );
              },
        child: Text(
          chat.favorited ? l10n.commonUnfavorite : l10n.commonFavorite,
        ),
      ),
      ShadContextMenuItem(
        leading: Icon(
          chat.archived ? LucideIcons.undo2 : LucideIcons.archive,
        ),
        onPressed: disabled
            ? null
            : () async {
                await context.read<ChatsCubit>().toggleArchived(
                      jid: chat.jid,
                      archived: !chat.archived,
                    );
              },
        child: Text(
          chat.archived ? l10n.commonUnarchive : l10n.commonArchive,
        ),
      ),
      if (!widget.archivedContext)
        ShadContextMenuItem(
          leading: Icon(chat.hidden ? LucideIcons.eye : LucideIcons.eyeOff),
          onPressed: disabled
              ? null
              : () async {
                  await context.read<ChatsCubit>().toggleHidden(
                        jid: chat.jid,
                        hidden: !chat.hidden,
                      );
                },
          child: Text(chat.hidden ? l10n.commonShow : l10n.commonHide),
        ),
      ShadContextMenuItem(
        leading: const Icon(LucideIcons.trash2),
        onPressed: disabled ? null : () => _confirmDelete(chat),
        child: Text(l10n.commonDelete),
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
    final iconSize = scaled(16);
    final spacing = scaled(8);
    final l10n = context.l10n;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      alignment: WrapAlignment.center,
      children: [
        ContextActionButton(
          icon: Icon(LucideIcons.squareCheck, size: iconSize),
          label: l10n.commonSelect,
          onPressed: context.read<ChatsCubit?>() == null
              ? null
              : () {
                  context
                      .read<ChatsCubit>()
                      .ensureChatSelected(widget.chat.jid);
                  widget.onClose();
                },
        ),
        if (widget.chat.type == ChatType.chat)
          ContextActionButton(
            icon: Icon(LucideIcons.pencilLine, size: iconSize),
            label: l10n.chatContactRenameAction,
            onPressed: context.read<ChatsCubit?>() == null
                ? null
                : () => _renameContact(),
          ),
        ContextActionButton(
          icon: Icon(
            widget.chat.favorited ? LucideIcons.starOff : LucideIcons.star,
            size: iconSize,
          ),
          label: widget.chat.favorited
              ? l10n.commonUnfavorite
              : l10n.commonFavorite,
          onPressed: context.read<ChatsCubit?>() == null
              ? null
              : () async {
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
        ),
        ContextActionButton(
          icon: Icon(
            widget.chat.archived ? LucideIcons.undo2 : LucideIcons.archive,
            size: iconSize,
          ),
          label:
              widget.chat.archived ? l10n.commonUnarchive : l10n.commonArchive,
          onPressed: context.read<ChatsCubit?>() == null
              ? null
              : () async {
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
            onPressed: context.read<ChatsCubit?>() == null
                ? null
                : () async {
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
    if (context.read<ChatsCubit?>() == null) return;
    setState(() {
      _exporting = true;
    });
    try {
      final result = await ChatHistoryExporter.exportChats(
        chats: [widget.chat],
        loadHistory: context.read<ChatsCubit>().loadChatHistory,
      );
      if (!mounted) return;
      final file = result.file;
      if (file == null) {
        _showSnack(l10n.chatsExportNoContent);
        return;
      }
      await Share.shareXFiles(
        [XFile(file.path)],
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
      if (mounted) {
        setState(() {
          _exporting = false;
        });
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

double _measureLabelWidth(BuildContext context, String text) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: context.textTheme.small.copyWith(
        color: context.colorScheme.mutedForeground,
      ),
    ),
    textDirection: Directionality.of(context),
  )..layout();
  return painter.width;
}

double _measureUnreadBadgeWidth(BuildContext context, int count) {
  final textPainter = TextPainter(
    text: TextSpan(
      text: '$count',
      style: context.textTheme.small.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: Directionality.of(context),
  )..layout();
  final textWidth = textPainter.width;
  final textScaler = MediaQuery.of(context).textScaler;
  double scaled(double value) => textScaler.scale(value);
  return math.max(
    scaled(_unreadBadgeMinWidth),
    textWidth +
        (scaled(_unreadBadgeHorizontalPadding) * 2) +
        (scaled(_unreadBadgeBorderWidth) * 2) +
        scaled(_unreadBadgeCutoutClearance),
  );
}

const double _unreadBadgeHorizontalPadding = 10.0;
const double _unreadBadgeVerticalPadding = 4.0;
const double _unreadBadgeBorderWidth = 2.0;
const double _unreadBadgeMinWidth = 36.0;
const double _unreadBadgeCutoutClearance = 0.0;
const double _unreadBadgeCutoutVerticalClearance = 1.0;
const double _unreadBadgeMinDepth = 10.0;
const double _unreadBadgeCornerRadius = 12.0;
const double _unreadBadgeCutoutChildVerticalOffset = -2.0;
const double _unreadBadgeCutoutDepthAdjustment = -2.0;

double _measureUnreadBadgeHeight(BuildContext context, int count) {
  final textScaler = MediaQuery.of(context).textScaler;
  double scaled(double value) => textScaler.scale(value);
  final textPainter = TextPainter(
    text: TextSpan(
      text: '$count',
      style: context.textTheme.small.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: Directionality.of(context),
  )..layout();
  return textPainter.height +
      (scaled(_unreadBadgeVerticalPadding) * 2) +
      (scaled(_unreadBadgeBorderWidth) * 2);
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({
    required this.count,
    required this.highlight,
  });

  final int count;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final Color background =
        highlight ? colors.primary : colors.secondary.withValues(alpha: 0.2);
    final Color borderColor =
        highlight ? colors.background : colors.border.withValues(alpha: 0.8);
    final Color textColor =
        highlight ? colors.primaryForeground : colors.mutedForeground;
    final borderWidth = scaled(_unreadBadgeBorderWidth);
    final cornerRadius = scaled(_unreadBadgeCornerRadius);
    final horizontalPadding = scaled(_unreadBadgeHorizontalPadding);
    final verticalPadding = scaled(_unreadBadgeVerticalPadding);
    return Semantics(
      container: true,
      label: context.l10n.chatsUnreadLabel(count),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: background,
          shape: SquircleBorder(
            cornerRadius: cornerRadius,
            side: BorderSide(
              color: borderColor,
              width: borderWidth,
            ),
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
              letterSpacing: 0.2,
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
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final iconSize = scaled(18);
    final minButtonSize = scaled(36);
    final borderWidth = scaled(1.4);
    final icon = expanded ? LucideIcons.x : LucideIcons.ellipsisVertical;
    final tooltip = expanded
        ? context.l10n.chatsHideActions
        : context.l10n.chatsShowActions;
    final button = AxiIconButton(
      iconData: icon,
      tooltip: tooltip,
      semanticLabel: tooltip,
      onPressed: onPressed,
      color: colors.mutedForeground,
      backgroundColor: backgroundColor,
      borderColor: colors.border,
      borderWidth: borderWidth,
      cornerRadius: scaled(14),
      buttonSize: minButtonSize,
      tapTargetSize: minButtonSize,
      iconSize: iconSize,
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
    final textScaler = MediaQuery.of(context).textScaler;
    double scaled(double value) => textScaler.scale(value);
    final borderWidth = scaled(1.4);
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
            cornerRadius: scaled(14),
            side: BorderSide(color: colors.border, width: borderWidth),
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
