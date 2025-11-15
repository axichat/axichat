import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/calendar_tile.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/context_action_button.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/home/home_search_cubit.dart';
import 'package:axichat/src/roster/bloc/roster_cubit.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
      selector: (state) {
        final items = state.items;
        if (items == null) return null;
        return items.where((chat) => !chat.archived && !chat.spam).toList();
      },
      builder: (context, items) {
        final duration = context.read<SettingsCubit>().animationDuration;
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
          final searchState = context.watch<HomeSearchCubit?>()?.state;
          final tabState = searchState?.stateFor(HomeTab.chats);
          final searchActive = searchState?.active ?? false;
          final query =
              searchActive ? (tabState?.query.trim().toLowerCase() ?? '') : '';
          final filterId = tabState?.filterId;
          final sortOrder = tabState?.sort ?? SearchSortOrder.newestFirst;
          final rosterContacts =
              context.watch<RosterCubit?>()?.contacts ?? const <String>{};

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
                ? b.lastChangeTimestamp.compareTo(a.lastChangeTimestamp)
                : a.lastChangeTimestamp.compareTo(b.lastChangeTimestamp),
          );

          Widget body;
          if (visibleItems.isEmpty) {
            body = Center(
              child: Text(
                'No chats yet',
                style: context.textTheme.muted,
              ),
            );
          } else {
            body = ColoredBox(
              color: context.colorScheme.background,
              child: ListView.builder(
                itemCount: visibleItems.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final calendarBloc = context.read<CalendarBloc?>();
                    final tile = calendarBloc == null
                        ? CalendarTile(
                            onTap: () =>
                                context.read<ChatsCubit>().toggleCalendar(),
                          )
                        : BlocBuilder<CalendarBloc, CalendarState>(
                            bloc: calendarBloc,
                            builder: (context, state) {
                              final currentTask =
                                  state.currentTaskAt(DateTime.now());
                              return CalendarTile(
                                onTap: () =>
                                    context.read<ChatsCubit>().toggleCalendar(),
                                currentTask: currentTask,
                                nextTask: state.nextTask,
                                dueReminderCount:
                                    state.dueReminders?.length ?? 0,
                              );
                            },
                          );
                    return ListItemPadding(child: tile);
                  }

                  final item = visibleItems[index - 1];
                  return ListItemPadding(
                    child: ChatListTile(item: item),
                  );
                },
              ),
            );
          }

          child = KeyedSubtree(
            key: const ValueKey('chats-loaded'),
            child: body,
          );
        }

        return AnimatedSwitcher(
          duration: duration,
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
      },
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
  return chat.title.toLowerCase().contains(lower) ||
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
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final colors = context.colorScheme;
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
    final timestampLabel = item.lastMessage == null
        ? null
        : formatTimeSinceLabel(DateTime.now(), item.lastChangeTimestamp);
    final timestampThickness = timestampLabel == null
        ? 0.0
        : math.max(
            32.0,
            _measureLabelWidth(
                  context,
                  timestampLabel,
                ) +
                16.0,
          );
    final chatsCubit = context.watch<ChatsCubit?>();
    final selectedJids = chatsCubit?.state.selectedJids ?? const <String>{};
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
    VoidCallback? tileOnTap;
    if (chatsCubit == null) {
      tileOnTap = () {
        unawaited(_handleTap(item));
      };
    } else if (selectionActive) {
      tileOnTap = () => chatsCubit.toggleChatSelection(item.jid);
    } else {
      tileOnTap = () {
        unawaited(_handleTap(item));
      };
    }
    final tileOnLongPress = chatsCubit == null
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
          };
    final tile = AxiListTile(
      key: Key(item.jid),
      onTap: tileOnTap,
      onLongPress: tileOnLongPress,
      leadingConstraints: const BoxConstraints(
        maxWidth: 72,
        maxHeight: 80,
      ),
      selected: item.open || isSelected,
      paintSurface: false,
      contentPadding: const EdgeInsets.only(left: 16.0, right: 40.0),
      tapBounce: false,
      leading: _TransportAwareAvatar(chat: item),
      title: item.title,
      subtitle: item.lastMessage,
      subtitlePlaceholder: 'No messages',
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
            offset: const Offset(0, _unreadBadgeCutoutChildVerticalOffset),
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
                onPressed: () => chatsCubit?.toggleChatSelection(item.jid),
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
            offset: const Offset(0, -3),
            child: DisplayTimeSince(
              timestamp: item.lastChangeTimestamp,
              style: context.textTheme.small.copyWith(
                color: colors.mutedForeground,
              ),
            ),
          ),
        ),
    ];

    final tileSurface = CutoutSurface(
      backgroundColor: tileBackgroundColor,
      borderColor: colors.border,
      cutouts: cutouts,
      shape: SquircleBorder(
        cornerRadius: 18,
        side: BorderSide(color: colors.border),
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
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: _buildActionButtons(context, item),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return tileSurface.withTapBounce();
  }

  void _toggleActions() {
    setState(() {
      _showActions = !_showActions;
    });
  }

  Future<void> _handleTap(Chat chat) async {
    final chatsCubit = context.read<ChatsCubit?>();
    if (chatsCubit == null) return;
    if (widget.archivedContext && chat.archived) {
      final handler = widget.onArchivedTap;
      if (handler != null) {
        await handler(chat);
        return;
      }
    }
    unawaited(chatsCubit.toggleChat(jid: chat.jid));
  }

  List<Widget> _buildActionButtons(BuildContext context, Chat chat) {
    final chatsCubit = context.read<ChatsCubit?>();
    return [
      ContextActionButton(
        icon: const Icon(LucideIcons.squareCheck, size: 16),
        label: 'Select',
        onPressed: chatsCubit == null
            ? null
            : () {
                chatsCubit.ensureChatSelected(chat.jid);
                if (!mounted) return;
                setState(() => _showActions = false);
              },
      ),
      ContextActionButton(
        icon: Icon(
          chat.favorited ? LucideIcons.starOff : LucideIcons.star,
          size: 16,
        ),
        label: chat.favorited ? 'Unfavorite' : 'Favorite',
        onPressed: chatsCubit == null
            ? null
            : () async {
                await chatsCubit.toggleFavorited(
                  jid: chat.jid,
                  favorited: !chat.favorited,
                );
                if (!mounted) return;
                setState(() => _showActions = false);
              },
      ),
      ContextActionButton(
        icon: _exporting
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(LucideIcons.share2, size: 16),
        label: _exporting ? 'Exporting...' : 'Export',
        onPressed: _exporting
            ? null
            : () async {
                await _exportChat(chat);
              },
      ),
      ContextActionButton(
        icon: Icon(
          chat.archived ? LucideIcons.undo2 : LucideIcons.archive,
          size: 16,
        ),
        label: chat.archived ? 'Unarchive' : 'Archive',
        onPressed: chatsCubit == null
            ? null
            : () async {
                await chatsCubit.toggleArchived(
                  jid: chat.jid,
                  archived: !chat.archived,
                );
                if (!mounted) return;
                _showMessage(
                  chat.archived
                      ? 'Chat restored'
                      : 'Chat archived (Profile → Archived chats)',
                );
                setState(() => _showActions = false);
              },
      ),
      if (!widget.archivedContext)
        ContextActionButton(
          icon: Icon(
            chat.hidden ? LucideIcons.eye : LucideIcons.eyeOff,
            size: 16,
          ),
          label: chat.hidden ? 'Show' : 'Hide',
          onPressed: chatsCubit == null
              ? null
              : () async {
                  await chatsCubit.toggleHidden(
                    jid: chat.jid,
                    hidden: !chat.hidden,
                  );
                  if (!mounted) return;
                  _showMessage(
                    chat.hidden
                        ? 'Chat is visible again'
                        : 'Chat hidden (use filter to reveal)',
                  );
                  setState(() => _showActions = false);
                },
        ),
      ContextActionButton(
        icon: const Icon(LucideIcons.trash2, size: 16),
        label: 'Delete',
        destructive: true,
        onPressed: () => _confirmDelete(chat),
      ),
    ];
  }

  Future<void> _exportChat(Chat chat) async {
    final chatsCubit = context.read<ChatsCubit?>();
    if (chatsCubit == null) return;
    setState(() {
      _exporting = true;
    });
    try {
      final history = await chatsCubit.loadChatHistory(chat.jid);
      if (!mounted) return;
      if (history.isEmpty) {
        _showMessage('No messages to export');
        return;
      }
      final buffer = StringBuffer();
      final formatter = intl.DateFormat('y-MM-dd HH:mm');
      for (final message in history) {
        final timestampValue =
            message.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timestamp = formatter.format(timestampValue);
        final author = message.senderJid;
        final content = message.body?.trim();
        if (content == null || content.isEmpty) continue;
        buffer.writeln('[$timestamp] $author: $content');
      }
      final exportText = buffer.toString().trim();
      if (exportText.isEmpty) {
        _showMessage('No text content to export');
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle =
          chat.title.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_').toLowerCase();
      final fileName =
          'chat-${sanitizedTitle.isEmpty ? 'thread' : sanitizedTitle}-${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(exportText);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Chat export from Axichat',
        subject: 'Chat with ${chat.title}',
      );
      if (!mounted) return;
      _showMessage('Chat exported');
      setState(() => _showActions = false);
    } catch (error) {
      if (!mounted) return;
      _showMessage('Unable to export chat');
    } finally {
      if (mounted) {
        setState(() => _exporting = false);
      }
    }
  }

  Future<void> _confirmDelete(Chat chat) async {
    final chatsCubit = context.read<ChatsCubit?>();
    if (chatsCubit == null) return;
    var deleteMessages = false;
    final confirmed = await showShadDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return ShadDialog(
              title: const Text('Confirm'),
              actions: [
                ShadButton.outline(
                  onPressed: () => dialogContext.pop(false),
                  child: const Text('Cancel'),
                ).withTapBounce(),
                ShadButton.destructive(
                  onPressed: () => dialogContext.pop(true),
                  child: const Text('Continue'),
                ).withTapBounce(),
              ],
              child: Material(
                type: MaterialType.transparency,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete chat: ${chat.title}',
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
                              'Permanently delete messages',
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
    if (confirmed != true) return;
    if (deleteMessages) {
      await chatsCubit.deleteChatMessages(jid: chat.jid);
    }
    await chatsCubit.deleteChat(jid: chat.jid);
    if (!mounted) return;
    _showMessage('Chat deleted');
    setState(() => _showActions = false);
  }

  void _showMessage(String message) {
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
  return math.max(
    _unreadBadgeMinWidth,
    textWidth +
        (_unreadBadgeHorizontalPadding * 2) +
        (_unreadBadgeBorderWidth * 2) +
        _unreadBadgeCutoutClearance,
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
      (_unreadBadgeVerticalPadding * 2) +
      (_unreadBadgeBorderWidth * 2);
}

class _TransportAwareAvatar extends StatelessWidget {
  const _TransportAwareAvatar({required this.chat});

  final Chat chat;

  @override
  Widget build(BuildContext context) {
    final jid = chat.jid;
    final supportsEmail = chat.transport.isEmail;
    final isAxiCompatible = chat.isAxiContact;
    Widget badge;
    if (supportsEmail && isAxiCompatible) {
      badge = const AxiCompatibilityBadge(compact: true);
    } else if (supportsEmail) {
      badge = const AxiTransportChip(
        transport: MessageTransport.email,
        compact: true,
      );
    } else {
      badge = const AxiTransportChip(
        transport: MessageTransport.xmpp,
        compact: true,
      );
    }
    const avatarSize = 46.0;
    return SizedBox(
      width: avatarSize + 6,
      height: avatarSize + 12,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: AxiAvatar(
              jid: jid,
              shape: AxiAvatarShape.circle,
              size: avatarSize,
            ),
          ),
          Positioned(
            right: -6,
            bottom: -4,
            child: badge,
          ),
        ],
      ),
    );
  }
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
    final Color background =
        highlight ? colors.primary : colors.secondary.withValues(alpha: 0.2);
    final Color borderColor =
        highlight ? colors.background : colors.border.withValues(alpha: 0.8);
    final Color textColor =
        highlight ? colors.primaryForeground : colors.mutedForeground;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: background,
        shape: SquircleBorder(
          cornerRadius: _unreadBadgeCornerRadius,
          side: BorderSide(
            color: borderColor,
            width: _unreadBadgeBorderWidth,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _unreadBadgeHorizontalPadding,
          vertical: _unreadBadgeVerticalPadding,
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: SquircleBorder(
          cornerRadius: 14,
          side: BorderSide(color: colors.border, width: 1.4),
        ),
      ),
      child: IconButton(
        iconSize: 20,
        splashRadius: 22,
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(
          minWidth: 40,
          minHeight: 40,
        ),
        icon: Icon(
          expanded ? LucideIcons.x : LucideIcons.ellipsisVertical,
          color: colors.mutedForeground,
        ),
        onPressed: onPressed,
      ).withTapBounce(),
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
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: backgroundColor,
        shape: SquircleBorder(
          cornerRadius: 14,
          side: BorderSide(color: colors.border, width: 1.4),
        ),
      ),
      child: SelectionIndicator(
        visible: true,
        selected: selected,
        onPressed: onPressed,
      ),
    );
  }
}
