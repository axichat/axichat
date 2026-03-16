part of '../chat.dart';

class _MessageSenderLabel extends StatelessWidget {
  const _MessageSenderLabel({
    required this.user,
    required this.isSelf,
    required this.selfLabel,
    required this.leftInset,
  });

  final ChatUser user;
  final bool isSelf;
  final String selfLabel;
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final String trimmedSelfLabel = selfLabel.trim();
    final UnicodeSanitizedText displayName = sanitizeUnicodeControls(
      user.getFullName().trim(),
    );
    final UnicodeSanitizedText address = sanitizeUnicodeControls(
      user.id.trim(),
    );
    final String safeDisplayName = displayName.value.trim();
    final String safeAddress = address.value.trim();
    if (isSelf) {
      if (trimmedSelfLabel.isEmpty) {
        return const SizedBox.shrink();
      }
      return _SenderLabelBlock(
        primaryLabel: trimmedSelfLabel,
        secondaryLabel: null,
        isSelf: isSelf,
        leftInset: leftInset,
      );
    }
    if (safeDisplayName.isEmpty && safeAddress.isEmpty) {
      return const SizedBox.shrink();
    }
    final String primaryLabel = safeDisplayName.isNotEmpty
        ? safeDisplayName
        : safeAddress;
    return _SenderLabelBlock(
      primaryLabel: primaryLabel,
      secondaryLabel: null,
      isSelf: isSelf,
      leftInset: leftInset,
    );
  }
}

class _SenderLabelBlock extends StatelessWidget {
  const _SenderLabelBlock({
    required this.primaryLabel,
    required this.secondaryLabel,
    required this.isSelf,
    required this.leftInset,
  });

  final String primaryLabel;
  final String? secondaryLabel;
  final bool isSelf;
  final double leftInset;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final textAlign = isSelf ? TextAlign.right : TextAlign.left;
    final crossAxis = isSelf
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final secondaryLabel = this.secondaryLabel?.trim();
    final trimmedPrimaryLabel = primaryLabel.trim();
    if (trimmedPrimaryLabel.isEmpty &&
        (secondaryLabel == null || secondaryLabel.isEmpty)) {
      return const SizedBox.shrink();
    }
    final primaryStyle = context.textTheme.small.copyWith(
      color: colors.mutedForeground,
      fontWeight: FontWeight.w600,
    );
    final secondaryStyle = context.textTheme.muted.copyWith(
      color: colors.mutedForeground,
    );
    final labelChildren = <Widget>[
      if (trimmedPrimaryLabel.isNotEmpty)
        Text(trimmedPrimaryLabel, style: primaryStyle, textAlign: textAlign),
      if (secondaryLabel != null && secondaryLabel.isNotEmpty)
        Text(secondaryLabel, style: secondaryStyle, textAlign: textAlign),
    ];
    return Padding(
      padding: EdgeInsets.only(bottom: spacing.s, left: leftInset),
      child: Column(
        spacing: spacing.xxs,
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxis,
        children: labelChildren,
      ),
    );
  }
}

class _UnreadBubbleSideIndicator extends StatelessWidget {
  const _UnreadBubbleSideIndicator({
    required this.visible,
    required this.isSelf,
  });

  final bool visible;
  final bool isSelf;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final spacing = context.spacing;
    final sizing = context.sizing;
    final collapseAlignment = isSelf
        ? Alignment.centerRight
        : Alignment.centerLeft;
    final indicatorAlignment = isSelf
        ? Alignment.centerLeft
        : Alignment.centerRight;
    final dotSize = sizing.statusDotSize;
    final indicatorExtent = dotSize + spacing.xs;
    return AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: collapseAlignment,
      clipBehavior: Clip.none,
      child: SizedBox(
        width: visible ? indicatorExtent : 0,
        height: dotSize,
        child: Align(
          alignment: indicatorAlignment,
          child: AnimatedOpacity(
            duration: _bubbleFocusDuration,
            curve: _bubbleFocusCurve,
            opacity: visible ? 1 : 0,
            child: SizedBox(
              width: dotSize,
              height: dotSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.destructive,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatTimelineMessageRowView extends StatelessWidget {
  const _ChatTimelineMessageRowView({
    required this.messageId,
    required this.rowKey,
    required this.readOnly,
    required this.self,
    required this.isSingleSelection,
    required this.isEmailMessage,
    required this.showUnreadIndicator,
    required this.messageRowMaxWidth,
    required this.bubblePreviewWidth,
    required this.replyPreviewMaxWidth,
    required this.messageRowAlignment,
    required this.outerPadding,
    required this.bubble,
    required this.senderLabel,
    required this.forwardedPreview,
    required this.quotedPreview,
    required this.attachmentsAligned,
    required this.extrasAligned,
    required this.showExtras,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.animate,
    required this.onBubbleTap,
    required this.onBubbleSizeChanged,
    this.onTapOutside,
  });

  final String messageId;
  final Key? rowKey;
  final bool readOnly;
  final bool self;
  final bool isSingleSelection;
  final bool isEmailMessage;
  final bool showUnreadIndicator;
  final double messageRowMaxWidth;
  final double bubblePreviewWidth;
  final double replyPreviewMaxWidth;
  final AlignmentGeometry messageRowAlignment;
  final EdgeInsetsGeometry outerPadding;
  final Widget bubble;
  final Widget? senderLabel;
  final Widget? forwardedPreview;
  final Widget? quotedPreview;
  final Widget attachmentsAligned;
  final Widget extrasAligned;
  final bool showExtras;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final bool animate;
  final VoidCallback? onBubbleTap;
  final ValueChanged<Size> onBubbleSizeChanged;
  final TapRegionCallback? onTapOutside;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final messageColumnAlignment = self
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final selectableBubble = MouseRegion(
      cursor: readOnly ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onBubbleTap,
        onLongPress: null,
        onSecondaryTapUp: null,
        child: bubble,
      ),
    );
    final bubbleStack = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [selectableBubble],
    );
    final measuredBubbleStack = isSingleSelection
        ? _SizeReportingWidget(
            onSizeChange: onBubbleSizeChanged,
            child: bubbleStack,
          )
        : bubbleStack;
    final bubbleWithSlack = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: bubblePreviewWidth),
      child: measuredBubbleStack,
    );
    final bubbleWithIndicator = isEmailMessage
        ? Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (self)
                _UnreadBubbleSideIndicator(
                  visible: showUnreadIndicator,
                  isSelf: self,
                ),
              _MessageBubbleRegion(
                messageId: messageId,
                registry: bubbleRegionRegistry,
                child: bubbleWithSlack,
              ),
              if (!self)
                _UnreadBubbleSideIndicator(
                  visible: showUnreadIndicator,
                  isSelf: self,
                ),
            ],
          )
        : bubbleWithSlack;
    final bubbleStackWithReply = _ReplyPreviewBubbleColumn(
      forwardedPreview: forwardedPreview,
      quotedPreview: quotedPreview,
      senderLabel: senderLabel,
      bubble: bubbleWithIndicator,
      previewMaxWidth: replyPreviewMaxWidth,
      spacing: spacing.s,
      previewSpacing: spacing.xxs,
      alignEnd: self,
    );
    final animatedBubbleStackWithReply = AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: self ? Alignment.topRight : Alignment.topLeft,
      clipBehavior: Clip.none,
      child: bubbleStackWithReply,
    );
    final messageBody = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: messageColumnAlignment,
      children: [
        animatedBubbleStackWithReply,
        if (showExtras) extrasAligned,
        attachmentsAligned,
      ],
    );
    final messageArrival = _MessageArrivalAnimator(
      key: ValueKey<String>('arrival-$messageId'),
      animate: animate,
      isSelf: self,
      child: messageBody,
    );
    final selectionRegion = TapRegion(
      groupId: selectionTapRegionGroup,
      onTapOutside: onTapOutside,
      child: messageArrival,
    );
    final alignedMessage = SizedBox(
      width: messageRowMaxWidth,
      child: AnimatedAlign(
        duration: _bubbleFocusDuration,
        curve: _bubbleFocusCurve,
        alignment: messageRowAlignment,
        child: selectionRegion,
      ),
    );
    return KeyedSubtree(
      key: rowKey,
      child: Padding(padding: outerPadding, child: alignedMessage),
    );
  }
}

class _ChatTimelineBubbleView extends StatelessWidget {
  const _ChatTimelineBubbleView({
    required this.self,
    required this.isSelected,
    required this.showBubbleSurface,
    required this.bubbleSurfaceColor,
    required this.bubbleSurfaceBorder,
    required this.bubbleBorderRadius,
    required this.bubbleShadows,
    required this.cornerClearance,
    required this.body,
    required this.textConstraints,
    this.reactionOverlay,
    this.reactionStyle,
    this.recipientOverlay,
    this.recipientStyle,
    this.recipientAnchor = ChatBubbleCutoutAnchor.bottom,
    this.avatarOverlay,
    this.avatarStyle,
    this.avatarAnchor = ChatBubbleCutoutAnchor.left,
    this.selectionOverlay,
    this.selectionStyle,
  });

  final bool self;
  final bool isSelected;
  final bool showBubbleSurface;
  final Color bubbleSurfaceColor;
  final Color bubbleSurfaceBorder;
  final BorderRadius bubbleBorderRadius;
  final List<BoxShadow> bubbleShadows;
  final double cornerClearance;
  final Widget body;
  final BoxConstraints textConstraints;
  final Widget? reactionOverlay;
  final CutoutStyle? reactionStyle;
  final Widget? recipientOverlay;
  final CutoutStyle? recipientStyle;
  final ChatBubbleCutoutAnchor recipientAnchor;
  final Widget? avatarOverlay;
  final CutoutStyle? avatarStyle;
  final ChatBubbleCutoutAnchor avatarAnchor;
  final Widget? selectionOverlay;
  final CutoutStyle? selectionStyle;

  @override
  Widget build(BuildContext context) {
    final bubbleHighlightColor = context.colorScheme.primary;
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      child: body,
      builder: (context, shadowValue, child) {
        return ConstrainedBox(
          constraints: textConstraints,
          child: ChatBubbleSurface(
            isSelf: self,
            backgroundColor: bubbleSurfaceColor,
            borderColor: bubbleSurfaceBorder,
            borderRadius: bubbleBorderRadius,
            shadowOpacity: showBubbleSurface ? shadowValue : 0.0,
            shadows: bubbleShadows.isNotEmpty
                ? bubbleShadows
                : _selectedBubbleShadows(bubbleHighlightColor),
            bubbleWidthFraction: 1.0,
            cornerClearance: cornerClearance,
            body: child!,
            reactionOverlay: reactionOverlay,
            reactionStyle: reactionStyle,
            recipientOverlay: recipientOverlay,
            recipientStyle: recipientStyle,
            recipientAnchor: recipientAnchor,
            avatarOverlay: avatarOverlay,
            avatarStyle: avatarStyle,
            avatarAnchor: avatarAnchor,
            selectionOverlay: selectionOverlay,
            selectionStyle: selectionStyle,
            selectionFollowsSelfEdge: false,
          ),
        );
      },
    );
  }
}

class _ChatTimelineMessageSelectionExtras extends StatelessWidget {
  const _ChatTimelineMessageSelectionExtras({
    required this.self,
    required this.isSingleSelection,
    required this.actionBar,
    required this.reactionManager,
    required this.availableWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.bubbleMaxWidthForLayout,
    required this.messageRowMaxWidth,
    required this.measuredBubbleWidth,
    required this.attachmentPadding,
    required this.bubbleBottomCutoutPadding,
  });

  final bool self;
  final bool isSingleSelection;
  final Widget actionBar;
  final Widget? reactionManager;
  final double availableWidth;
  final double selectionExtrasPreferredMaxWidth;
  final double bubbleMaxWidthForLayout;
  final double messageRowMaxWidth;
  final double? measuredBubbleWidth;
  final EdgeInsets attachmentPadding;
  final double bubbleBottomCutoutPadding;

  @override
  Widget build(BuildContext context) {
    final clampedMeasuredBubbleWidth = measuredBubbleWidth
        ?.clamp(0.0, bubbleMaxWidthForLayout)
        .toDouble();
    final bubbleIsVisuallyFullWidth =
        isSingleSelection &&
        clampedMeasuredBubbleWidth != null &&
        clampedMeasuredBubbleWidth >=
            bubbleMaxWidthForLayout - context.borderSide.width;
    final legacySelectionExtrasMaxWidth = math.min(
      availableWidth,
      selectionExtrasPreferredMaxWidth,
    );
    final selectionExtrasMaxWidth = math
        .max(
          legacySelectionExtrasMaxWidth,
          bubbleIsVisuallyFullWidth ? bubbleMaxWidthForLayout : 0.0,
        )
        .clamp(0.0, messageRowMaxWidth)
        .toDouble();
    final selectionExtrasChild = Align(
      alignment: self ? Alignment.centerRight : Alignment.centerLeft,
      child: SizedBox(
        width: selectionExtrasMaxWidth,
        child: Padding(
          padding: attachmentPadding.copyWith(
            top: attachmentPadding.top + bubbleBottomCutoutPadding,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              actionBar,
              if (reactionManager != null) const SizedBox(height: 20),
              ?reactionManager,
            ],
          ),
        ),
      ),
    );
    final selectionExtras = IgnorePointer(
      ignoring: !isSingleSelection,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: isSingleSelection ? 1.0 : 0.0),
        duration: _bubbleFocusDuration,
        curve: _bubbleFocusCurve,
        builder: (context, value, child) {
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: value,
              child: Opacity(opacity: value, child: child),
            ),
          );
        },
        child: selectionExtrasChild,
      ),
    );
    return AxiAnimatedSize(
      duration: _bubbleFocusDuration,
      reverseDuration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: selectionExtras,
    );
  }
}

class _ChatTimelineMessageExtrasView extends StatelessWidget {
  const _ChatTimelineMessageExtrasView({
    required this.self,
    required this.isSelected,
    required this.bubbleBottomCutoutPadding,
    required this.bubbleContentKey,
    required this.bubbleExtraChildren,
    required this.bubbleExtraConstraints,
    required this.extraShadows,
  });

  final bool self;
  final bool isSelected;
  final double bubbleBottomCutoutPadding;
  final Object bubbleContentKey;
  final List<Widget> bubbleExtraChildren;
  final BoxConstraints bubbleExtraConstraints;
  final List<BoxShadow> extraShadows;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: isSelected ? 1.0 : 0.0),
      duration: _bubbleFocusDuration,
      curve: _bubbleFocusCurve,
      builder: (context, shadowValue, child) {
        final extras = bubbleBottomCutoutPadding > 0
            ? <Widget>[
                _MessageExtraGap(
                  key: ValueKey<String>('$bubbleContentKey-extra-cutout-gap'),
                  height: bubbleBottomCutoutPadding,
                ),
                ...bubbleExtraChildren,
              ]
            : bubbleExtraChildren;
        return ConstrainedBox(
          constraints: bubbleExtraConstraints,
          child: _MessageExtrasColumn(
            shadowValue: shadowValue,
            shadows: extraShadows,
            crossAxisAlignment: self
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: extras,
          ),
        );
      },
    );
  }
}
