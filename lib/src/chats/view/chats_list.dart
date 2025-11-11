import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/chats/view/calendar_tile.dart';
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
            itemCount: items.length + 1,
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
                        builder: (context, state) => CalendarTile(
                          onTap: () =>
                              context.read<ChatsCubit>().toggleCalendar(),
                          nextTask: state.nextTask,
                          dueReminderCount: state.dueReminders?.length ?? 0,
                        ),
                      );
                return ListItemPadding(child: tile);
              }

              final item = items[index - 1];
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

    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final tileBackgroundColor = item.open
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;
    T locate<T>() => context.read<T>();
    final menuItems = [
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
    ];
    final tile = AxiListTile(
      key: Key(item.jid),
      onTap: () => context.read<ChatsCubit?>()?.toggleChat(jid: item.jid),
      leadingConstraints: const BoxConstraints(
        maxWidth: 72,
        maxHeight: 80,
      ),
      menuItems: menuItems,
      selected: item.open,
      paintSurface: false,
      contentPadding: const EdgeInsets.only(left: 16.0, right: 40.0),
      tapBounce: false,
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

    final tileSurface = CutoutSurface(
      backgroundColor: tileBackgroundColor,
      borderColor: colors.border,
      cutouts: cutouts,
      shape: SquircleBorder(
        cornerRadius: 18,
        side: BorderSide(color: colors.border),
      ),
      child: tile,
    );

    return tileSurface.withTapBounce();
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
