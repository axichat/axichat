part of '../chat.dart';

const _messageArrivalDuration = Duration(milliseconds: 420);
const _messageArrivalCurve = Curves.easeOutCubic;
const _reactionQuickChoices = ['👍', '❤️', '😂', '😮', '😢', '🙏', '🔥', '👏'];
const _typingIndicatorMaxAvatars = 7;

class _SizeReportingWidget extends SingleChildRenderObjectWidget {
  const _SizeReportingWidget({
    required this.onSizeChange,
    required super.child,
  });

  final ValueChanged<Size> onSizeChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _SizeReportingRenderObject(onSizeChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _SizeReportingRenderObject renderObject,
  ) {
    renderObject.onSizeChange = onSizeChange;
  }
}

class _SizeReportingRenderObject extends RenderProxyBox {
  _SizeReportingRenderObject(this.onSizeChange);

  ValueChanged<Size> onSizeChange;
  Size? _lastSize;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_lastSize == newSize) {
      return;
    }
    _lastSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onSizeChange(newSize);
    });
  }
}

class _InviteAttachmentText extends StatelessWidget {
  const _InviteAttachmentText({
    required this.text,
    required this.style,
    required this.maxLines,
    required this.overflow,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) {
    final sanitized = sanitizeUnicodeControls(text);
    final candidate = sanitized.value.trim();
    final resolved = candidate.isNotEmpty ? candidate : text;
    return Text(resolved, maxLines: maxLines, overflow: overflow, style: style);
  }
}

class _InviteAttachmentCard extends StatelessWidget {
  const _InviteAttachmentCard({
    required this.shape,
    required this.enabled,
    required this.label,
    required this.detailLabel,
    required this.actionLabel,
    required this.onPressed,
  });

  final OutlinedBorder shape;
  final bool enabled;
  final String label;
  final String detailLabel;
  final String actionLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final padding = EdgeInsets.all(spacing.m);
    final contentSpacing = spacing.s;
    final headerSpacing = spacing.xs;
    final accentWidth = spacing.xxs;
    final leadingInset = sizing.menuItemIconSize + headerSpacing;
    final accentColor = enabled ? colors.primary : colors.muted;
    final labelColor = enabled ? colors.foreground : colors.mutedForeground;
    final iconColor = enabled ? colors.primary : colors.mutedForeground;
    final trimmedDetailLabel = detailLabel.trim();
    final showDetailLabel =
        trimmedDetailLabel.isNotEmpty && trimmedDetailLabel != label.trim();
    return ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: colors.card,
          shape: shape.copyWith(side: BorderSide(color: colors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: accentWidth,
              child: DecoratedBox(
                decoration: BoxDecoration(color: accentColor),
              ),
            ),
            Expanded(
              child: Padding(
                padding: padding,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: contentSpacing,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          LucideIcons.userPlus,
                          size: sizing.menuItemIconSize,
                          color: iconColor,
                        ),
                        SizedBox(width: headerSpacing),
                        Expanded(
                          child: _InviteAttachmentText(
                            text: label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: context.textTheme.small.copyWith(
                              fontWeight: FontWeight.w600,
                              color: labelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (showDetailLabel)
                      Padding(
                        padding: EdgeInsets.only(left: leadingInset),
                        child: _InviteAttachmentText(
                          text: trimmedDetailLabel,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.textTheme.small.copyWith(
                            color: colors.mutedForeground,
                          ),
                        ),
                      ),
                    if (enabled)
                      Padding(
                        padding: EdgeInsets.only(left: leadingInset),
                        child: SizedBox(
                          width: double.infinity,
                          child: AxiButton.outline(
                            onPressed: onPressed,
                            child: Text(
                              actionLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageExtraGap extends StatelessWidget {
  const _MessageExtraGap({super.key, required this.height});

  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

class _MessageExtraItem extends StatelessWidget {
  const _MessageExtraItem({
    super.key,
    required this.child,
    required this.shape,
    this.onLongPress,
    this.onSecondaryTapUp,
  });

  final Widget child;
  final ShapeBorder shape;
  final GestureLongPressCallback? onLongPress;
  final GestureTapUpCallback? onSecondaryTapUp;

  @override
  Widget build(BuildContext context) {
    final clippedChild = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    if (onLongPress == null && onSecondaryTapUp == null) {
      return clippedChild;
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onLongPress: onLongPress,
      onSecondaryTapUp: onSecondaryTapUp,
      child: clippedChild,
    );
  }
}

class _MessageExtraShadow extends StatelessWidget {
  const _MessageExtraShadow({
    super.key,
    required this.child,
    required this.shape,
    required this.shadows,
  });

  final Widget child;
  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: ShapeDecoration(shape: shape, shadows: shadows),
      child: child,
    );
  }
}

class _MessageExtrasColumn extends StatelessWidget {
  const _MessageExtrasColumn({
    required this.children,
    required this.shadowValue,
    required this.shadows,
    required this.crossAxisAlignment,
  });

  final List<Widget> children;
  final double shadowValue;
  final List<BoxShadow> shadows;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }
    final resolvedShadows = shadowValue > 0
        ? _scaleShadows(shadows, shadowValue)
        : const <BoxShadow>[];
    final decoratedChildren = children.map((child) {
      if (child is _MessageExtraGap) {
        return child;
      }
      if (child is _MessageExtraItem) {
        return _MessageExtraShadow(
          key: child.key,
          shape: child.shape,
          shadows: resolvedShadows,
          child: child,
        );
      }
      return child;
    }).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: decoratedChildren,
    );
  }
}

class _BubbleRegionRegistry {
  final regions = <String, RenderBox>{};

  Rect? rectFor(String messageId) {
    final renderBox = regions[messageId];
    if (renderBox == null || !renderBox.attached) {
      return null;
    }
    final origin = renderBox.localToGlobal(Offset.zero);
    return origin & renderBox.size;
  }

  void register(String messageId, RenderBox renderBox) {
    regions[messageId] = renderBox;
  }

  void unregister(String messageId, RenderBox renderBox) {
    final current = regions[messageId];
    if (identical(current, renderBox)) {
      regions.remove(messageId);
    }
  }

  void clear() {
    regions.clear();
  }
}

class _MessageBubbleRegion extends SingleChildRenderObjectWidget {
  const _MessageBubbleRegion({
    required this.messageId,
    required this.registry,
    required super.child,
  });

  final String messageId;
  final _BubbleRegionRegistry registry;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMessageBubbleRegion(messageId: messageId, registry: registry);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderMessageBubbleRegion renderObject,
  ) {
    renderObject
      ..messageId = messageId
      ..registry = registry;
  }
}

class _RenderMessageBubbleRegion extends RenderProxyBox {
  _RenderMessageBubbleRegion({
    required String messageId,
    required _BubbleRegionRegistry registry,
  }) : messageId0 = messageId,
       registry0 = registry;

  String messageId0;

  set messageId(String value) {
    if (value == messageId0) return;
    registry0.unregister(messageId0, this);
    messageId0 = value;
    registry0.register(messageId0, this);
  }

  _BubbleRegionRegistry registry0;

  set registry(_BubbleRegionRegistry value) {
    if (identical(value, registry0)) return;
    registry0.unregister(messageId0, this);
    registry0 = value;
    registry0.register(messageId0, this);
  }

  void register() {
    registry0.register(messageId0, this);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    register();
  }

  @override
  void detach() {
    registry0.unregister(messageId0, this);
    super.detach();
  }

  @override
  void performLayout() {
    super.performLayout();
    register();
  }
}

class _CutoutLayoutResult<T> {
  const _CutoutLayoutResult({
    required this.items,
    required this.overflowed,
    required this.totalWidth,
  });

  final List<T> items;
  final bool overflowed;
  final double totalWidth;
}

@visibleForTesting
({List<ReactionPreview> items, bool overflowed, double totalWidth})
layoutReactionStrip({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required double maxContentWidth,
}) {
  final layout = _layoutReactionStrip(
    context: context,
    reactions: reactions,
    maxContentWidth: maxContentWidth,
  );
  return (
    items: layout.items,
    overflowed: layout.overflowed,
    totalWidth: layout.totalWidth,
  );
}

@visibleForTesting
double minimumReactionStripContentWidth({
  required BuildContext context,
  required List<ReactionPreview> reactions,
}) {
  if (reactions.isEmpty) return 0.0;
  final textDirection = Directionality.of(context);
  final textScaler =
      MediaQuery.maybeOf(context)?.textScaler ?? TextScaler.noScaling;
  final measurementSlack = context.borderSide.width;
  final firstWidth = measureReactionChipWidth(
    context: context,
    reaction: reactions.first,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  if (reactions.length == 1) {
    return firstWidth + measurementSlack;
  }
  final glyphWidth = measureReactionOverflowGlyphWidth(
    context: context,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  return firstWidth + glyphWidth + measurementSlack;
}

@visibleForTesting
double minimumReactionCutoutBubbleWidth({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required EdgeInsets padding,
  required double minThickness,
  required double cornerClearance,
}) {
  if (reactions.isEmpty) return 0.0;
  final requiredContentWidth = minimumReactionStripContentWidth(
    context: context,
    reactions: reactions,
  );
  final requiredThickness = math.max(
    minThickness,
    requiredContentWidth + padding.horizontal,
  );
  return requiredThickness + (cornerClearance * 2);
}

_CutoutLayoutResult<ReactionPreview> _layoutReactionStrip({
  required BuildContext context,
  required List<ReactionPreview> reactions,
  required double maxContentWidth,
}) {
  final spacing = context.spacing;
  final reactionChipSpacing = 0.0;
  final reactionOverflowSpacing = spacing.xs;
  if (reactions.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <ReactionPreview>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final textDirection = Directionality.of(context);
  final mediaQuery = MediaQuery.maybeOf(context);
  final textScaler = mediaQuery == null
      ? TextScaler.noScaling
      : mediaQuery.textScaler;
  final measurementSlack = context.borderSide.width;
  final reactionOverflowGlyphWidth = measureReactionOverflowGlyphWidth(
    context: context,
    textDirection: textDirection,
    textScaler: textScaler,
  );
  final reactionWidths = [
    for (final reaction in reactions)
      measureReactionChipWidth(
        context: context,
        reaction: reaction,
        textDirection: textDirection,
        textScaler: textScaler,
      ),
  ];

  final visible = <ReactionPreview>[];
  double used = 0;

  final limit = maxContentWidth.isFinite
      ? math.max(0.0, maxContentWidth - measurementSlack)
      : maxContentWidth;

  for (var i = 0; i < reactions.length; i++) {
    final reaction = reactions[i];
    final reactionWidth = reactionWidths[i];
    final spacing = visible.isEmpty ? 0 : reactionChipSpacing;
    final addition = spacing + reactionWidth;
    final hasMoreAfter = i < reactions.length - 1;
    final overflowReservation = hasMoreAfter
        ? reactionOverflowGlyphWidth +
              ((visible.length + 1) > 1 ? reactionOverflowSpacing : 0.0)
        : 0.0;
    if (limit.isFinite && used + addition + overflowReservation > limit) {
      break;
    }
    visible.add(reaction);
    used += addition;
  }

  final truncated = visible.length < reactions.length;
  if (visible.isEmpty) {
    final firstWidth = reactionWidths.first;
    final canShowOverflow =
        reactions.length > 1 &&
        (!limit.isFinite || firstWidth + reactionOverflowGlyphWidth <= limit);
    final totalWidth = canShowOverflow
        ? firstWidth + reactionOverflowGlyphWidth
        : firstWidth;
    return _CutoutLayoutResult(
      items: <ReactionPreview>[reactions.first],
      overflowed: canShowOverflow,
      totalWidth: math.min(maxContentWidth, totalWidth),
    );
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: math.min(
      maxContentWidth,
      truncated
          ? used +
                (visible.length > 1 ? reactionOverflowSpacing : 0.0) +
                reactionOverflowGlyphWidth
          : used,
    ),
  );
}

double measureReactionChipWidth({
  required BuildContext context,
  required ReactionPreview reaction,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final spacing = context.spacing;
  final reactionChipPadding = EdgeInsets.symmetric(
    horizontal: 0.0,
    vertical: spacing.xxs,
  );
  final reactionSubscriptPadding = spacing.xs;
  final highlighted = reaction.reactedBySelf;
  final emojiPainter = TextPainter(
    text: TextSpan(
      text: reaction.emoji,
      style: reactionEmojiTextStyle(context, highlighted: highlighted),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();

  var width = emojiPainter.width + reactionChipPadding.horizontal;

  if (reaction.count > 1) {
    final countPainter = TextPainter(
      text: TextSpan(
        text: reaction.count.toString(),
        style: reactionCountTextStyle(context, highlighted: highlighted),
      ),
      maxLines: 1,
      textDirection: textDirection,
      textScaler: textScaler,
    )..layout();
    width =
        emojiPainter.width +
        reactionSubscriptPadding +
        countPainter.width +
        reactionChipPadding.horizontal;
  }

  return width;
}

double measureReactionOverflowGlyphWidth({
  required BuildContext context,
  required TextDirection textDirection,
  required TextScaler textScaler,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: context.l10n.commonEllipsis,
      style: reactionOverflowTextStyle(context),
    ),
    maxLines: 1,
    textDirection: textDirection,
    textScaler: textScaler,
  )..layout();
  return painter.width;
}

_CutoutLayoutResult<chat_models.Chat> _layoutRecipientStrip({
  required BuildContext context,
  required List<chat_models.Chat> recipients,
  required double maxContentWidth,
}) {
  if (recipients.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <chat_models.Chat>[],
      overflowed: false,
      totalWidth: 0,
    );
  }

  final spacing = context.spacing;
  final recipientAvatarSize = spacing.l;
  final recipientAvatarOverlap = spacing.s;
  final visible = <chat_models.Chat>[];
  final additions = <double>[];
  double used = 0;

  for (final recipient in recipients) {
    final addition = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    if (used + addition > maxContentWidth) {
      break;
    }
    visible.add(recipient);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < recipients.length;
  double totalWidth = used;

  if (truncated) {
    var ellipsisWidth = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? recipientAvatarSize
          : recipientAvatarSize - recipientAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

_CutoutLayoutResult<String> _layoutTypingStrip({
  required BuildContext context,
  required List<String> participants,
  required double maxContentWidth,
}) {
  if (participants.isEmpty || maxContentWidth <= 0) {
    return const _CutoutLayoutResult(
      items: <String>[],
      overflowed: false,
      totalWidth: 0,
    );
  }
  final spacing = context.spacing;
  final recipientAvatarSize = spacing.l;
  final recipientAvatarOverlap = spacing.s;
  final capped = participants
      .take(_typingIndicatorMaxAvatars + 1)
      .toList(growable: false);
  final visible = <String>[];
  final additions = <double>[];
  double used = 0;

  for (final participant in capped) {
    if (visible.length >= _typingIndicatorMaxAvatars) break;
    final addition = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    if (used + addition > maxContentWidth) {
      break;
    }
    visible.add(participant);
    additions.add(addition);
    used += addition;
  }

  final truncated = visible.length < participants.length;
  double totalWidth = used;

  if (truncated) {
    var ellipsisWidth = visible.isEmpty
        ? recipientAvatarSize
        : recipientAvatarSize - recipientAvatarOverlap;
    while (visible.isNotEmpty && totalWidth + ellipsisWidth > maxContentWidth) {
      totalWidth -= additions.removeLast();
      visible.removeLast();
      ellipsisWidth = visible.isEmpty
          ? recipientAvatarSize
          : recipientAvatarSize - recipientAvatarOverlap;
    }
    if (visible.isEmpty) {
      totalWidth = math.min(ellipsisWidth, maxContentWidth);
    } else {
      totalWidth = math.min(maxContentWidth, totalWidth + ellipsisWidth);
    }
  }

  return _CutoutLayoutResult(
    items: visible,
    overflowed: truncated,
    totalWidth: totalWidth,
  );
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({
    required this.jid,
    required this.size,
    this.avatarPath,
  });

  final String jid;
  final double size;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    return HydratedAxiAvatar(
      avatarData: AvatarData.avatar(
        identifier: jid,
        colorSeed: jid,
        avatarPath: avatarPath,
        loading: false,
      ),
      size: size,
    );
  }
}

class _ReactionStrip extends StatelessWidget {
  const _ReactionStrip({required this.reactions, this.onReactionTap});

  final List<ReactionPreview> reactions;
  final void Function(String emoji)? onReactionTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final chipSpacing = 0.0;
        final overflowSpacing = spacing.xs;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = layoutReactionStrip(
          context: context,
          reactions: reactions,
          maxContentWidth: maxWidth,
        );
        final items = layout.items;
        final children = <Widget>[];
        for (var i = 0; i < items.length; i++) {
          if (i != 0) {
            children.add(SizedBox(width: chipSpacing));
          }
          children.add(
            _ReactionChip(
              data: items[i],
              onTap: onReactionTap == null
                  ? null
                  : () => onReactionTap!(items[i].emoji),
            ),
          );
        }
        if (layout.overflowed) {
          if (children.isNotEmpty) {
            children.add(
              SizedBox(width: items.length > 1 ? overflowSpacing : 0.0),
            );
          }
          children.add(const _ReactionOverflowGlyph());
        }
        return Row(mainAxisSize: MainAxisSize.min, children: children);
      },
    );
  }
}

class _ReactionOverflowGlyph extends StatelessWidget {
  const _ReactionOverflowGlyph();

  @override
  Widget build(BuildContext context) {
    return Text(
      context.l10n.commonEllipsis,
      style: reactionOverflowTextStyle(context),
    );
  }
}

TextStyle reactionOverflowTextStyle(BuildContext context) {
  final colors = context.colorScheme;
  return context.textTheme.small
      .copyWith(
        fontWeight: FontWeight.w600,
        color: colors.mutedForeground,
        height: 1,
      )
      .apply(leadingDistribution: TextLeadingDistribution.even);
}

class _ReplyStrip extends StatelessWidget {
  const _ReplyStrip({required this.participants, this.onRecipientTap});

  final List<chat_models.Chat> participants;
  final ValueChanged<chat_models.Chat>? onRecipientTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(
          context: context,
          recipients: participants,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final chat = visible[i];
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: null,
                child: _RecipientAvatarBadge(chat: chat),
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _RecipientCutoutStrip extends StatelessWidget {
  const _RecipientCutoutStrip({required this.recipients});

  final List<chat_models.Chat> recipients;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutRecipientStrip(
          context: context,
          recipients: recipients,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _RecipientAvatarBadge(chat: visible[i]),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _RecipientAvatarBadge extends StatelessWidget {
  const _RecipientAvatarBadge({required this.chat});

  final chat_models.Chat chat;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final borderWidth = context.borderSide.width;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    final avatarPath = (chat.avatarPath ?? chat.contactAvatarPath)?.trim();
    final avatarImagePath = avatarPath?.isNotEmpty == true ? avatarPath : null;
    return SizedBox(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      child: DecoratedBox(
        decoration: ShapeDecoration(color: colors.card, shape: shape),
        child: Padding(
          padding: EdgeInsets.all(borderWidth),
          child: HydratedAxiAvatar(
            avatarData: AvatarData.avatar(
              identifier: chat.avatarIdentifier,
              colorSeed: chat.avatarColorSeed,
              avatarPath: avatarImagePath,
              loading: false,
            ),
            size: recipientAvatarSize - (borderWidth * 2),
          ),
        ),
      ),
    );
  }
}

class _RecipientOverflowAvatar extends StatelessWidget {
  const _RecipientOverflowAvatar();

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    return SizedBox(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      child: Center(
        child: Text(
          l10n.commonEllipsis,
          style: context.textTheme.small
              .copyWith(
                fontWeight: FontWeight.w700,
                color: colors.mutedForeground,
                height: 1,
              )
              .apply(leadingDistribution: TextLeadingDistribution.even),
        ),
      ),
    );
  }
}

class _TypingIndicatorPill extends StatelessWidget {
  const _TypingIndicatorPill({
    required this.participants,
    required this.avatarPaths,
  });

  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final avatarStrip = participants.isEmpty
            ? null
            : _TypingAvatarStrip(
                participants: participants,
                avatarPaths: avatarPaths,
              );
        final hasBoundedWidth =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final maxWidth = hasBoundedWidth ? constraints.maxWidth : null;
        return ConstrainedBox(
          constraints: maxWidth == null
              ? const BoxConstraints()
              : BoxConstraints(maxWidth: maxWidth),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (avatarStrip != null)
                Flexible(fit: FlexFit.loose, child: avatarStrip),
              if (avatarStrip != null) SizedBox(width: spacing.xs),
              const TypingIndicator(),
            ],
          ),
        );
      },
    );
  }
}

class _TypingAvatarStrip extends StatelessWidget {
  const _TypingAvatarStrip({
    required this.participants,
    required this.avatarPaths,
  });

  final List<String> participants;
  final Map<String, String> avatarPaths;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = context.spacing;
        final recipientAvatarSize = spacing.l;
        final recipientAvatarOverlap = spacing.s;
        final recipientOverflowGap = spacing.s;
        final maxWidth =
            constraints.hasBoundedWidth &&
                constraints.maxWidth.isFinite &&
                constraints.maxWidth > 0
            ? constraints.maxWidth
            : double.infinity;
        final layout = _layoutTypingStrip(
          context: context,
          participants: participants,
          maxContentWidth: maxWidth,
        );
        final visible = layout.items;
        final overflowed = layout.overflowed;
        final children = <Widget>[];
        for (var i = 0; i < visible.length; i++) {
          final offset = i * (recipientAvatarSize - recipientAvatarOverlap);
          children.add(
            Positioned(
              left: offset,
              child: _TypingAvatar(
                jid: visible[i],
                avatarPath: avatarPaths[visible[i]],
              ),
            ),
          );
        }
        if (overflowed) {
          final offset = visible.isEmpty
              ? 0.0
              : visible.length *
                        (recipientAvatarSize - recipientAvatarOverlap) +
                    recipientOverflowGap;
          children.add(
            Positioned(left: offset, child: const _RecipientOverflowAvatar()),
          );
        }
        final baseWidth = layout.totalWidth;
        final totalWidth = overflowed
            ? baseWidth + recipientOverflowGap + recipientAvatarSize
            : math.max(baseWidth, recipientAvatarSize);
        return SizedBox(
          width: totalWidth,
          height: recipientAvatarSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }
}

class _TypingAvatar extends StatelessWidget {
  const _TypingAvatar({required this.jid, this.avatarPath});

  final String jid;
  final String? avatarPath;

  @override
  Widget build(BuildContext context) {
    final borderColor = context.colorScheme.card;
    final borderWidth = context.borderSide.width;
    final spacing = context.spacing;
    final recipientAvatarSize = spacing.l;
    final shape = SquircleBorder(cornerRadius: context.radii.squircle);
    return Container(
      width: recipientAvatarSize,
      height: recipientAvatarSize,
      padding: EdgeInsets.all(borderWidth),
      decoration: ShapeDecoration(color: borderColor, shape: shape),
      child: HydratedAxiAvatar(
        avatarData: AvatarData.avatar(
          identifier: jid,
          colorSeed: jid,
          avatarPath: avatarPath,
          loading: false,
        ),
        size: recipientAvatarSize - (borderWidth * 2),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.data, this.onTap});

  final ReactionPreview data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final highlighted = data.reactedBySelf;
    final spacing = context.spacing;
    final chipPadding = EdgeInsets.symmetric(
      horizontal: 0.0,
      vertical: spacing.xxs,
    );
    final subscriptPadding = spacing.xs;
    final emojiStyle = reactionEmojiTextStyle(
      context,
      highlighted: highlighted,
    );
    final countStyle = reactionCountTextStyle(
      context,
      highlighted: highlighted,
    );
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      child: Padding(
        padding: chipPadding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.emoji, style: emojiStyle),
            if (data.count > 1)
              Padding(
                padding: EdgeInsets.only(
                  left: subscriptPadding,
                  top: spacing.xxs,
                ),
                child: Text(data.count.toString(), style: countStyle),
              ),
          ],
        ),
      ),
    );
  }
}

TextStyle reactionEmojiTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  return context.textTheme.large.copyWith(
    fontWeight: highlighted ? FontWeight.w700 : FontWeight.w500,
  );
}

TextStyle reactionCountTextStyle(
  BuildContext context, {
  required bool highlighted,
}) {
  final colors = context.colorScheme;
  return context.textTheme.small.copyWith(
    fontSize: (context.textTheme.small.fontSize ?? 10) * 0.9,
    color: highlighted ? colors.primary : colors.foreground,
    fontWeight: FontWeight.w600,
  );
}

class _ComposerOverlayHeadroomSpacer extends StatelessWidget {
  const _ComposerOverlayHeadroomSpacer({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: true,
      child: ExcludeSemantics(child: Opacity(opacity: 0, child: child)),
    );
  }
}

class _UnreadDivider extends StatelessWidget {
  const _UnreadDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final colors = context.colorScheme;
    final textTheme = context.textTheme;
    final borderSide = context.borderSide;
    final line = Expanded(
      child: Container(height: borderSide.width, color: colors.destructive),
    );
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.m, vertical: spacing.s),
      child: Row(
        children: [
          line,
          SizedBox(width: spacing.s),
          Text(
            label,
            style: textTheme.muted.copyWith(color: colors.destructive),
          ),
          SizedBox(width: spacing.s),
          line,
        ],
      ),
    );
  }
}

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({
    required this.onReply,
    this.onForward,
    required this.onCopy,
    required this.onShare,
    required this.shareStatus,
    required this.onAddToCalendar,
    required this.onDetails,
    this.replyLoading = false,
    this.onSelect,
    this.onResend,
    this.onEdit,
    this.importantDisabled = false,
    this.onImportantToggle,
    required this.isImportant,
    this.pinDisabled = false,
    this.pinLoading = false,
    this.onPinToggle,
    required this.isPinned,
    this.onRevokeInvite,
  });

  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final RequestStatus shareStatus;
  final VoidCallback onAddToCalendar;
  final VoidCallback onDetails;
  final bool replyLoading;
  final VoidCallback? onSelect;
  final VoidCallback? onResend;
  final VoidCallback? onEdit;
  final bool importantDisabled;
  final VoidCallback? onImportantToggle;
  final bool isImportant;
  final bool pinDisabled;
  final bool pinLoading;
  final VoidCallback? onPinToggle;
  final bool isPinned;
  final VoidCallback? onRevokeInvite;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.of(context).textScaler;
    final l10n = context.l10n;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final iconSize = sizing.menuItemIconSize;
    double scaled(double value) => textScaler.scale(value);
    final actions = <Widget>[
      ContextActionButton(
        icon: replyLoading
            ? AxiProgressIndicator(color: context.colorScheme.foreground)
            : Icon(LucideIcons.reply, size: iconSize),
        label: l10n.chatActionReply,
        onPressed: onReply,
      ),
      ContextActionButton(
        icon: Transform.scale(
          scaleX: -1,
          child: Icon(LucideIcons.reply, size: iconSize),
        ),
        label: l10n.chatActionForward,
        onPressed: onForward,
      ),
      if (onResend != null)
        ContextActionButton(
          icon: Icon(LucideIcons.repeat, size: iconSize),
          label: l10n.chatActionResend,
          onPressed: onResend,
        ),
      if (onEdit != null)
        ContextActionButton(
          icon: Icon(LucideIcons.pencilLine, size: iconSize),
          label: l10n.chatActionEdit,
          onPressed: onEdit,
        ),
      if (onRevokeInvite != null)
        ContextActionButton(
          icon: Icon(LucideIcons.ban, size: iconSize),
          label: l10n.chatActionRevoke,
          onPressed: onRevokeInvite,
        ),
      if (onImportantToggle != null || importantDisabled)
        ContextActionButton(
          icon: Icon(
            isImportant ? Icons.star_rounded : Icons.star_outline_rounded,
            size: iconSize,
          ),
          label: isImportant
              ? l10n.chatRemoveMessageImportant
              : l10n.chatMarkMessageImportant,
          onPressed: onImportantToggle,
        ),
      if (onPinToggle != null || pinLoading || pinDisabled)
        ContextActionButton(
          icon: pinLoading
              ? AxiProgressIndicator(color: context.colorScheme.foreground)
              : Icon(
                  isPinned ? LucideIcons.pinOff : LucideIcons.pin,
                  size: iconSize,
                ),
          label: isPinned ? l10n.chatUnpinMessage : l10n.chatPinMessage,
          onPressed: onPinToggle,
        ),
      ContextActionButton(
        icon: Icon(LucideIcons.copy, size: iconSize),
        label: l10n.chatActionCopy,
        onPressed: onCopy,
      ),
      ContextActionButton(
        icon: shareStatus.isLoading
            ? AxiProgressIndicator(color: context.colorScheme.foreground)
            : Icon(LucideIcons.share2, size: iconSize),
        label: l10n.chatActionShare,
        onPressed: shareStatus.isLoading ? null : onShare,
      ),
      ContextActionButton(
        icon: Icon(LucideIcons.calendarPlus, size: iconSize),
        label: l10n.chatActionAddToCalendar,
        onPressed: onAddToCalendar,
      ),
      ContextActionButton(
        icon: Icon(LucideIcons.info, size: iconSize),
        label: l10n.chatActionDetails,
        onPressed: onDetails,
      ),
      if (onSelect != null)
        ContextActionButton(
          icon: Icon(LucideIcons.squareCheck, size: iconSize),
          label: l10n.chatActionSelect,
          onPressed: onSelect,
        ),
    ];
    return Wrap(
      spacing: scaled(spacing.s),
      runSpacing: scaled(spacing.s),
      alignment: WrapAlignment.center,
      children: actions,
    );
  }
}

class _ReactionManager extends StatefulWidget {
  const _ReactionManager({
    required this.reactions,
    required this.onToggle,
    required this.onAddCustom,
    this.disabled = false,
    this.disabledLoading = false,
    this.disabledMessage,
  });

  final List<ReactionPreview> reactions;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddCustom;
  final bool disabled;
  final bool disabledLoading;
  final String? disabledMessage;

  @override
  State<_ReactionManager> createState() => _ReactionManagerState();
}

class _ReactionManagerState extends State<_ReactionManager> {
  late List<ReactionPreview> _sorted;
  int _signature = 0;

  @override
  void initState() {
    super.initState();
    _refreshSorted();
  }

  @override
  void didUpdateWidget(covariant _ReactionManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSignature = _reactionsSignature(widget.reactions);
    if (_signature != nextSignature) {
      _refreshSorted(signature: nextSignature);
    }
  }

  void _refreshSorted({int? signature}) {
    final nextSignature = signature ?? _reactionsSignature(widget.reactions);
    _signature = nextSignature;
    _sorted = widget.reactions.toList()
      ..sort((a, b) => b.count.compareTo(a.count));
  }

  int _reactionsSignature(List<ReactionPreview> reactions) {
    var hash = reactions.length;
    for (final reaction in reactions) {
      hash = Object.hash(
        hash,
        reaction.emoji,
        reaction.count,
        reaction.reactedBySelf,
      );
    }
    return hash;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final textTheme = context.textTheme;
    final sorted = _sorted;
    final hasReactions = sorted.isNotEmpty;
    return AxiModalSurface(
      padding: EdgeInsets.all(spacing.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: spacing.s,
        children: [
          if (widget.disabled)
            Row(
              children: [
                if (widget.disabledLoading) ...[
                  AxiProgressIndicator(color: colors.mutedForeground),
                  SizedBox(width: spacing.s),
                ],
                Expanded(
                  child: Text(
                    widget.disabledMessage ??
                        (widget.disabledLoading
                            ? context.l10n.chatMucReferencePending
                            : context.l10n.chatMucReferenceUnavailable),
                    style: textTheme.muted,
                  ),
                ),
              ],
            ),
          if (hasReactions)
            Wrap(
              spacing: spacing.s,
              runSpacing: spacing.s,
              children: [
                for (final reaction in sorted)
                  _ReactionManagerChip(
                    key: ValueKey(reaction.emoji),
                    data: reaction,
                    onToggle: widget.disabled
                        ? null
                        : () => widget.onToggle(reaction.emoji),
                  ),
              ],
            )
          else
            Text(
              context.l10n.chatReactionsNone,
              style: textTheme.small.copyWith(color: colors.mutedForeground),
            ),
          if (!widget.disabled)
            Text(
              hasReactions
                  ? context.l10n.chatReactionsPrompt
                  : context.l10n.chatReactionsPick,
              style: textTheme.muted,
            ),
          Wrap(
            spacing: spacing.s,
            runSpacing: spacing.s,
            children: [
              for (final emoji in _reactionQuickChoices)
                _ReactionQuickButton(
                  emoji: emoji,
                  onPressed: widget.disabled
                      ? null
                      : () => widget.onToggle(emoji),
                ),
              _ReactionAddButton(
                onPressed: widget.disabled ? null : widget.onAddCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReactionManagerChip extends StatelessWidget {
  const _ReactionManagerChip({
    super.key,
    required this.data,
    required this.onToggle,
  });

  final ReactionPreview data;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final highlighted = data.reactedBySelf;
    final background = highlighted
        ? colors.primary.withValues(alpha: 0.14)
        : colors.secondary.withValues(alpha: 0.05);
    final borderColor = highlighted
        ? colors.primary
        : colors.border.withValues(alpha: 0.9);
    final countStyle = context.textTheme.small.copyWith(
      fontWeight: FontWeight.w600,
      color: highlighted ? colors.primary : colors.mutedForeground,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onToggle,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: borderColor),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(data.emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 6),
              Text(data.count.toString(), style: countStyle),
              if (data.reactedBySelf) ...[
                const SizedBox(width: 6),
                Icon(LucideIcons.minus, size: 16, color: colors.primary),
              ],
            ],
          ),
        ),
      ),
    ).withTapBounce();
  }
}

class _ReactionQuickButton extends StatelessWidget {
  const _ReactionQuickButton({required this.emoji, required this.onPressed});

  final String emoji;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.secondary(onPressed: onPressed, child: Text(emoji));
  }
}

class _ReactionAddButton extends StatelessWidget {
  const _ReactionAddButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiButton.outline(
      onPressed: onPressed,
      leading: Icon(LucideIcons.plus, size: context.sizing.menuItemIconSize),
      child: Text(context.l10n.chatReactionMore),
    );
  }
}

class _QuotedMessagePreview extends StatelessWidget {
  const _QuotedMessagePreview({
    required this.message,
    required this.senderLabel,
    required this.isSelf,
  });

  final Message message;
  final String senderLabel;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final senderLabelTrimmed = senderLabel.trim();
    return Builder(
      builder: (context) {
        final previewText =
            previewTextForMessage(message) ?? context.l10n.chatQuotedNoContent;
        return ReplyingToPreviewText(
          senderLabel: senderLabelTrimmed,
          quoteText: previewText,
          isSelf: isSelf,
        );
      },
    );
  }
}

class _ForwardedPreviewText extends StatelessWidget {
  const _ForwardedPreviewText({
    required this.senderLabel,
    required this.isSelf,
  });

  final String senderLabel;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final textAlign = isSelf ? TextAlign.end : TextAlign.start;
    final colors = context.colorScheme;
    final baseStyle = context.textTheme.small;
    final prefixStyle = context.textTheme.sectionLabelM;
    final senderStyle = baseStyle.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.chatForwardPrefix, style: prefixStyle),
          const TextSpan(text: ' '),
          TextSpan(text: senderLabel, style: senderStyle),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
    );
  }
}

class _ReplyPreviewBubbleColumn extends MultiChildRenderObjectWidget {
  const _ReplyPreviewBubbleColumn({
    required this.forwardedPreview,
    required this.quotedPreview,
    required this.senderLabel,
    required this.bubble,
    required this.previewMaxWidth,
    required this.spacing,
    required this.previewSpacing,
    required this.alignEnd,
  });

  final Widget? forwardedPreview;
  final Widget? quotedPreview;
  final Widget? senderLabel;
  final Widget bubble;
  final double previewMaxWidth;
  final double spacing;
  final double previewSpacing;
  final bool alignEnd;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderReplyPreviewBubbleColumn(
        previewMaxWidth: previewMaxWidth,
        spacing: spacing,
        previewSpacing: previewSpacing,
        hasForwardedPreview: forwardedPreview != null,
        hasQuotedPreview: quotedPreview != null,
        hasSenderLabel: senderLabel != null,
        alignEnd: alignEnd,
      );

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderReplyPreviewBubbleColumn renderObject,
  ) {
    renderObject
      ..previewMaxWidth = previewMaxWidth
      ..spacing = spacing
      ..previewSpacing = previewSpacing
      ..hasForwardedPreview = forwardedPreview != null
      ..hasQuotedPreview = quotedPreview != null
      ..hasSenderLabel = senderLabel != null
      ..alignEnd = alignEnd;
  }

  @override
  List<Widget> get children => <Widget>[
    ?senderLabel,
    ?forwardedPreview,
    ?quotedPreview,
    bubble,
  ];
}

class _ReplyPreviewBubbleParentData extends ContainerBoxParentData<RenderBox> {
  double? quoteMaxWidth;
}

class _RenderReplyPreviewBubbleColumn extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _ReplyPreviewBubbleParentData>,
        RenderBoxContainerDefaultsMixin<
          RenderBox,
          _ReplyPreviewBubbleParentData
        > {
  _RenderReplyPreviewBubbleColumn({
    required double previewMaxWidth,
    required double spacing,
    required double previewSpacing,
    required bool hasForwardedPreview,
    required bool hasQuotedPreview,
    required bool hasSenderLabel,
    required bool alignEnd,
  }) : _previewMaxWidth = previewMaxWidth,
       _spacing = spacing,
       _previewSpacing = previewSpacing,
       _hasForwardedPreview = hasForwardedPreview,
       _hasQuotedPreview = hasQuotedPreview,
       _hasSenderLabel = hasSenderLabel,
       _alignEnd = alignEnd;

  double _previewMaxWidth;
  double _spacing;
  double _previewSpacing;
  bool _hasForwardedPreview;
  bool _hasQuotedPreview;
  bool _hasSenderLabel;
  bool _alignEnd;

  double get previewMaxWidth => _previewMaxWidth;

  set previewMaxWidth(double value) {
    if (_previewMaxWidth == value) return;
    _previewMaxWidth = value;
    markNeedsLayout();
  }

  double get spacing => _spacing;

  set spacing(double value) {
    if (_spacing == value) return;
    _spacing = value;
    markNeedsLayout();
  }

  double get previewSpacing => _previewSpacing;

  set previewSpacing(double value) {
    if (_previewSpacing == value) return;
    _previewSpacing = value;
    markNeedsLayout();
  }

  bool get hasForwardedPreview => _hasForwardedPreview;

  set hasForwardedPreview(bool value) {
    if (_hasForwardedPreview == value) return;
    _hasForwardedPreview = value;
    markNeedsLayout();
  }

  bool get hasQuotedPreview => _hasQuotedPreview;

  set hasQuotedPreview(bool value) {
    if (_hasQuotedPreview == value) return;
    _hasQuotedPreview = value;
    markNeedsLayout();
  }

  bool get hasSenderLabel => _hasSenderLabel;

  set hasSenderLabel(bool value) {
    if (_hasSenderLabel == value) return;
    _hasSenderLabel = value;
    markNeedsLayout();
  }

  bool get alignEnd => _alignEnd;

  set alignEnd(bool value) {
    if (_alignEnd == value) return;
    _alignEnd = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ReplyPreviewBubbleParentData) {
      child.parentData = _ReplyPreviewBubbleParentData();
    }
  }

  @override
  void performLayout() {
    final RenderBox? senderLabelChild = hasSenderLabel ? firstChild : null;
    final RenderBox? forwardedPreviewChild = hasForwardedPreview
        ? (hasSenderLabel ? childAfter(senderLabelChild!) : firstChild)
        : null;
    final RenderBox? quotedPreviewChild = hasQuotedPreview
        ? (hasForwardedPreview
              ? childAfter(forwardedPreviewChild!)
              : (hasSenderLabel ? childAfter(senderLabelChild!) : firstChild))
        : null;
    final RenderBox? bubbleChild = lastChild;
    if (bubbleChild == null) {
      size = constraints.smallest;
      return;
    }
    bubbleChild.layout(constraints.loosen(), parentUsesSize: true);
    final bubbleSize = bubbleChild.size;
    final double bubbleWidth = bubbleSize.width;
    var forwardedPreviewHeight = 0.0;
    var forwardedPreviewWidth = 0.0;
    var quotedPreviewHeight = 0.0;
    var quotedPreviewWidth = 0.0;
    var senderLabelHeight = 0.0;
    var senderLabelWidth = 0.0;
    if (senderLabelChild != null) {
      senderLabelChild.layout(constraints.loosen(), parentUsesSize: true);
      senderLabelHeight = senderLabelChild.size.height;
      senderLabelWidth = senderLabelChild.size.width;
    }
    var layoutWidth = bubbleWidth;
    final effectivePreviewMaxWidth = constraints.hasBoundedWidth
        ? math.min(previewMaxWidth, constraints.maxWidth)
        : previewMaxWidth;
    if (forwardedPreviewChild != null) {
      forwardedPreviewChild.layout(
        BoxConstraints(maxWidth: effectivePreviewMaxWidth),
        parentUsesSize: true,
      );
      forwardedPreviewWidth = forwardedPreviewChild.size.width;
      forwardedPreviewHeight = forwardedPreviewChild.size.height;
      layoutWidth = math.max(layoutWidth, forwardedPreviewWidth);
    }
    if (quotedPreviewChild != null) {
      final quotedPreviewParentData =
          quotedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      quotedPreviewParentData.quoteMaxWidth = bubbleWidth;
      quotedPreviewChild.layout(
        BoxConstraints(maxWidth: effectivePreviewMaxWidth),
        parentUsesSize: true,
      );
      quotedPreviewWidth = quotedPreviewChild.size.width;
      quotedPreviewHeight = quotedPreviewChild.size.height;
      layoutWidth = math.max(layoutWidth, quotedPreviewWidth);
    }
    final bubbleOffsetX = alignEnd ? layoutWidth - bubbleWidth : 0.0;
    if (senderLabelChild != null) {
      final senderLabelParentData =
          senderLabelChild.parentData as _ReplyPreviewBubbleParentData;
      senderLabelParentData.offset = Offset(
        alignEnd ? bubbleOffsetX + bubbleWidth - senderLabelWidth : 0,
        0,
      );
    }
    var currentY = senderLabelHeight;
    if (forwardedPreviewChild != null) {
      final forwardedPreviewParentData =
          forwardedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      forwardedPreviewParentData.offset = Offset(
        alignEnd ? layoutWidth - forwardedPreviewWidth : 0,
        currentY,
      );
      currentY += forwardedPreviewHeight;
      currentY += quotedPreviewChild != null ? previewSpacing : spacing;
    }
    if (quotedPreviewChild != null) {
      final quotedPreviewParentData =
          quotedPreviewChild.parentData as _ReplyPreviewBubbleParentData;
      quotedPreviewParentData.offset = Offset(
        alignEnd ? layoutWidth - quotedPreviewWidth : 0,
        currentY,
      );
      currentY += quotedPreviewHeight + spacing;
    }
    final bubbleParentData =
        bubbleChild.parentData as _ReplyPreviewBubbleParentData;
    bubbleParentData.offset = Offset(bubbleOffsetX, currentY);
    size = constraints.constrain(
      Size(layoutWidth, bubbleSize.height + currentY),
    );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}

class _MessageArrivalAnimator extends StatefulWidget {
  const _MessageArrivalAnimator({
    super.key,
    required this.child,
    required this.animate,
    required this.isSelf,
  });

  final Widget child;
  final bool animate;
  final bool isSelf;

  @override
  State<_MessageArrivalAnimator> createState() =>
      _MessageArrivalAnimatorState();
}

class _MessageArrivalAnimatorState extends State<_MessageArrivalAnimator>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller0;
  late final Animation<double> opacity;
  late final Animation<Offset> slide;
  late bool completed;

  @override
  void initState() {
    super.initState();
    completed = !widget.animate;
    controller0 = AnimationController(
      vsync: this,
      duration: _messageArrivalDuration,
    );
    final curve = CurvedAnimation(
      parent: controller0,
      curve: _messageArrivalCurve,
    );
    opacity = curve;
    slide = Tween<Offset>(
      begin: Offset(widget.isSelf ? 0.22 : -0.22, 0.0),
      end: Offset.zero,
    ).animate(curve);
    controller0.addStatusListener(handleStatus);
    if (widget.animate) {
      controller0.forward();
    } else {
      controller0.value = 1;
    }
  }

  @override
  void didUpdateWidget(_MessageArrivalAnimator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !oldWidget.animate) {
      completed = false;
      controller0
        ..value = 0
        ..forward();
    }
  }

  @override
  void dispose() {
    controller0.removeStatusListener(handleStatus);
    controller0.dispose();
    super.dispose();
  }

  void handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && mounted) {
      setState(() {
        completed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (completed) {
      return widget.child;
    }
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
