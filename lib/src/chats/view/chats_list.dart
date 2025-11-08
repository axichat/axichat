import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class ChatsList extends StatelessWidget {
  const ChatsList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ChatsCubit, ChatsState, List<Chat>?>(
      selector: (state) => state.items?.where(state.filter).toList(),
      builder: (context, items) {
        if (items == null) {
          return Center(
            child: AxiProgressIndicator(
              color: context.colorScheme.foreground,
            ),
          );
        }

        if (items.isEmpty) {
          return Center(
            child: Text(
              'No chats yet',
              style: context.textTheme.muted,
            ),
          );
        }

        return ColoredBox(
          color: context.colorScheme.background,
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return ListItemPadding(
                child: _ChatListTile(item: item),
              );
            },
          ),
        );
      },
    );
  }
}

class _ChatListTile extends StatelessWidget {
  const _ChatListTile({required this.item});

  final Chat item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final transport = item.transport;
    final showUnreadBadge = item.unreadCount > 0;
    final unreadCount = item.unreadCount;
    final unreadThickness = showUnreadBadge
        ? _measureUnreadBadgeWidth(
            context,
            unreadCount,
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

    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final tileBackgroundColor = item.open
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;
    final locate = context.read;
    final tile = AxiListTile(
      key: Key(item.jid),
      onTap: () => context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
      leadingConstraints: const BoxConstraints(
        maxWidth: 72,
        maxHeight: 80,
      ),
      menuItems: [
        AxiDeleteMenuItem(
          onPressed: () => showShadDialog<bool>(
            context: context,
            builder: (context) {
              var deleteMessages = false;
              return StatefulBuilder(builder: (context, setState) {
                return ShadDialog(
                  title: const Text('Confirm'),
                  actions: [
                    ShadButton.outline(
                      onPressed: () => context.pop(),
                      child: const Text('Cancel'),
                    ).withTapBounce(),
                    ShadButton.destructive(
                      onPressed: () {
                        if (deleteMessages) {
                          locate<ChatsCubit?>()
                              ?.deleteChatMessages(jid: item.jid);
                        }
                        locate<ChatsCubit?>()?.deleteChat(jid: item.jid);
                        return context.pop();
                      },
                      child: const Text('Continue'),
                    ).withTapBounce(),
                  ],
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Delete chat: ${item.title}',
                        style: context.textTheme.small,
                      ),
                      const SizedBox.square(dimension: 10.0),
                      ShadCheckbox(
                        value: deleteMessages,
                        onChanged: (value) =>
                            setState(() => deleteMessages = value),
                        label: Text(
                          'Permanently delete messages',
                          style: context.textTheme.muted,
                        ),
                      ),
                    ],
                  ),
                );
              });
            },
          ),
        ),
      ],
      selected: item.open,
      paintSurface: false,
      contentPadding: const EdgeInsets.only(left: 16.0, right: 80.0),
      leading: _TransportAwareAvatar(
        jid: item.jid,
        transport: transport,
      ),
      title: item.title,
      subtitle: item.lastMessage,
      subtitlePlaceholder: 'No messages',
    );

    final cutouts = <CutoutSpec>[
      if (showUnreadBadge)
        CutoutSpec(
          edge: CutoutEdge.top,
          alignment: const Alignment(0.84, -1),
          depth: 14,
          thickness: unreadThickness,
          cornerRadius: 18,
          child: _UnreadBadge(count: unreadCount),
        ),
      CutoutSpec(
        edge: CutoutEdge.right,
        alignment: const Alignment(1.02, 0),
        depth: 32,
        thickness: 46,
        cornerRadius: 18,
        child: _FavoriteToggle(
          backgroundColor: tileBackgroundColor,
          favorited: item.favorited,
          onPressed: () => context.read<ChatsCubit?>()?.toggleFavorited(
                jid: item.jid,
                favorited: !item.favorited,
              ),
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

    return CutoutSurface(
      backgroundColor: tileBackgroundColor,
      borderColor: colors.border,
      cutouts: cutouts,
      shape: SquircleBorder(
        cornerRadius: 18,
        side: BorderSide(color: colors.border),
      ),
      child: tile,
    );
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
  final textWidth = _measureLabelWidth(context, '$count');
  const horizontalPadding = 20.0; // padding in _UnreadBadge
  const minWidth = 36.0;
  return math.max(minWidth, textWidth + horizontalPadding);
}

class _TransportAwareAvatar extends StatelessWidget {
  const _TransportAwareAvatar({
    required this.jid,
    required this.transport,
  });

  final String jid;
  final MessageTransport transport;

  @override
  Widget build(BuildContext context) {
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
            child: AxiTransportChip(
              transport: transport,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.primary,
        shape: SquircleBorder(
          cornerRadius: 12,
          side: BorderSide(color: colors.background, width: 2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          '$count',
          maxLines: 1,
          style: context.textTheme.small.copyWith(
            color: colors.primaryForeground,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _FavoriteToggle extends StatelessWidget {
  const _FavoriteToggle({
    required this.backgroundColor,
    required this.favorited,
    required this.onPressed,
  });

  final Color backgroundColor;
  final bool favorited;
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
          favorited ? Icons.star_rounded : Icons.star_border_rounded,
          color: favorited ? colors.primary : colors.mutedForeground,
        ),
        onPressed: onPressed,
      ).withTapBounce(enabled: onPressed != null),
    );
  }
}
