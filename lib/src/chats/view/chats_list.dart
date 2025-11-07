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
                    ),
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
                    )
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

    final cutouts = <_CutoutSpec>[
      if (item.unreadCount > 0)
        _CutoutSpec(
          edge: _CutoutEdge.top,
          alignment: const Alignment(0.72, -1),
          depth: 18,
          thickness: 60,
          cornerRadius: 18,
          childInset: 0,
          childOffset: const Offset(0, -14),
          child: _UnreadBadge(count: item.unreadCount),
        ),
      _CutoutSpec(
        edge: _CutoutEdge.right,
        alignment: const Alignment(1.06, 0.1),
        depth: 32,
        thickness: 46,
        cornerRadius: 18,
        child: _FavoriteToggle(
          favorited: item.favorited,
          onPressed: () => context.read<ChatsCubit?>()?.toggleFavorited(
                jid: item.jid,
                favorited: !item.favorited,
              ),
        ),
      ),
      if (timestampLabel != null)
        _CutoutSpec(
          edge: _CutoutEdge.bottom,
          alignment: const Alignment(0.52, 1),
          depth: 14,
          thickness: timestampThickness,
          cornerRadius: 18,
          childInset: 0,
          child: DisplayTimeSince(
            timestamp: item.lastChangeTimestamp,
            style: context.textTheme.small.copyWith(
              color: colors.mutedForeground,
            ),
          ),
        ),
    ];

    return _CutoutTile(
      selected: item.open,
      cutouts: cutouts,
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
    required this.favorited,
    required this.onPressed,
  });

  final bool favorited;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: colors.card,
        shape: SquircleBorder(
          cornerRadius: 14,
          side: BorderSide(color: colors.background, width: 2),
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
      ),
    );
  }
}

class _CutoutTile extends StatelessWidget {
  const _CutoutTile({
    required this.child,
    required this.cutouts,
    required this.selected,
  });

  final Widget child;
  final List<_CutoutSpec> cutouts;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final brightness = Theme.of(context).brightness;
    final selectionOverlay = colors.primary.withValues(
      alpha: brightness == Brightness.dark ? 0.12 : 0.06,
    );
    final backgroundColor = selected
        ? Color.alphaBlend(selectionOverlay, colors.card)
        : colors.card;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: _CutoutPainter(
            borderRadius: 18,
            backgroundColor: backgroundColor,
            borderColor: colors.border,
            cutouts: cutouts,
          ),
          child: child,
        ),
        for (final spec in cutouts) _CutoutAttachment(spec: spec),
      ],
    );
  }
}

class _CutoutAttachment extends StatelessWidget {
  const _CutoutAttachment({required this.spec});

  final _CutoutSpec spec;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: CustomSingleChildLayout(
        delegate: _CutoutAttachmentDelegate(spec),
        child: spec.child,
      ),
    );
  }
}

class _CutoutSpec {
  const _CutoutSpec({
    required this.edge,
    required this.alignment,
    required this.depth,
    required this.thickness,
    required this.child,
    this.cornerRadius = 16,
    this.childInset,
    this.childOffset = Offset.zero,
  });

  final _CutoutEdge edge;
  final Alignment alignment;
  final double depth;
  final double thickness;
  final Widget child;
  final double cornerRadius;
  final double? childInset;
  final Offset childOffset;
}

enum _CutoutEdge { top, right, bottom, left }

class _CutoutPainter extends CustomPainter {
  const _CutoutPainter({
    required this.borderRadius,
    required this.backgroundColor,
    required this.borderColor,
    required this.cutouts,
  });

  final double borderRadius;
  final Color backgroundColor;
  final Color borderColor;
  final List<_CutoutSpec> cutouts;

  @override
  void paint(Canvas canvas, Size size) {
    var path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(borderRadius),
        ),
      );

    for (final spec in cutouts) {
      final rect = _cutoutRect(size, spec);
      final cutout =
          SquircleBorder(cornerRadius: spec.cornerRadius).getOuterPath(rect);
      path = Path.combine(PathOperation.difference, path, cutout);
    }

    final fillPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _CutoutPainter oldDelegate) => true;
}

Offset _edgeAnchor(Size size, _CutoutSpec spec) {
  final fx = ((spec.alignment.x + 1) / 2) * size.width;
  final fy = ((spec.alignment.y + 1) / 2) * size.height;
  switch (spec.edge) {
    case _CutoutEdge.right:
      return Offset(size.width, fy);
    case _CutoutEdge.left:
      return Offset(0, fy);
    case _CutoutEdge.top:
      return Offset(fx, 0);
    case _CutoutEdge.bottom:
      return Offset(fx, size.height);
  }
}

Offset _insideNormal(_CutoutEdge edge) {
  switch (edge) {
    case _CutoutEdge.right:
      return const Offset(-1, 0);
    case _CutoutEdge.left:
      return const Offset(1, 0);
    case _CutoutEdge.top:
      return const Offset(0, 1);
    case _CutoutEdge.bottom:
      return const Offset(0, -1);
  }
}

Rect _cutoutRect(Size size, _CutoutSpec spec) {
  final anchor = _edgeAnchor(size, spec);
  final halfThickness = spec.thickness / 2;
  switch (spec.edge) {
    case _CutoutEdge.right:
      return Rect.fromLTRB(
        size.width - spec.depth,
        anchor.dy - halfThickness,
        size.width + spec.depth,
        anchor.dy + halfThickness,
      );
    case _CutoutEdge.left:
      return Rect.fromLTRB(
        -spec.depth,
        anchor.dy - halfThickness,
        spec.depth,
        anchor.dy + halfThickness,
      );
    case _CutoutEdge.top:
      return Rect.fromLTRB(
        anchor.dx - halfThickness,
        -spec.depth,
        anchor.dx + halfThickness,
        spec.depth,
      );
    case _CutoutEdge.bottom:
      return Rect.fromLTRB(
        anchor.dx - halfThickness,
        size.height - spec.depth,
        anchor.dx + halfThickness,
        size.height + spec.depth,
      );
  }
}

class _CutoutAttachmentDelegate extends SingleChildLayoutDelegate {
  const _CutoutAttachmentDelegate(this.spec);

  final _CutoutSpec spec;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    return BoxConstraints.loose(Size(
      constraints.maxWidth,
      constraints.maxHeight,
    ));
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final rect = _cutoutRect(size, spec);
    final direction = _insideNormal(spec.edge);
    final inset = _resolvedInset(childSize);
    final target = rect.center + direction * inset;
    final topLeft = target -
        Offset(
          childSize.width / 2,
          childSize.height / 2,
        ) +
        spec.childOffset;
    return topLeft;
  }

  double _resolvedInset(Size childSize) {
    final raw = spec.childInset ?? _autoInset(childSize);
    return raw.clamp(-spec.depth, spec.depth);
  }

  double _autoInset(Size childSize) {
    final normalExtent = _extentAlongNormal(childSize);
    final perpendicularExtent = _extentPerpendicular(childSize);
    final targetClearance =
        math.max(0.0, (spec.thickness - perpendicularExtent) / 2);
    final inset = spec.depth - normalExtent / 2 - targetClearance;
    if (inset <= 0) {
      return 0;
    }
    return math.min(inset, spec.depth);
  }

  double _extentAlongNormal(Size childSize) {
    switch (spec.edge) {
      case _CutoutEdge.right:
      case _CutoutEdge.left:
        return childSize.width;
      case _CutoutEdge.top:
      case _CutoutEdge.bottom:
        return childSize.height;
    }
  }

  double _extentPerpendicular(Size childSize) {
    switch (spec.edge) {
      case _CutoutEdge.right:
      case _CutoutEdge.left:
        return childSize.height;
      case _CutoutEdge.top:
      case _CutoutEdge.bottom:
        return childSize.width;
    }
  }

  @override
  bool shouldRelayout(covariant _CutoutAttachmentDelegate oldDelegate) =>
      oldDelegate.spec != spec;
}
