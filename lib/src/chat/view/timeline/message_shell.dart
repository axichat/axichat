part of '../chat.dart';

({Widget actionBar, Widget? reactionManager, VoidCallback? onBubbleTap})
_resolveTimelineMessageChromeActions({
  required BuildContext context,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required chat_models.Chat? chatEntity,
  required RoomState? roomState,
  required RequestStatus shareRequestStatus,
  required bool readOnly,
  required bool self,
  required bool multiSelectActive,
  required bool canTogglePins,
  required bool canReact,
  required bool requiresMucReference,
  required bool loadingMucReference,
  required bool isSingleSelection,
  required bool isInviteMessage,
  required bool isInviteRevocationMessage,
  required bool inviteRevoked,
  required bool isPinned,
  required bool isImportant,
  required MessageStatus messageStatus,
  required String detailId,
  required List<ReactionPreview> reactions,
  required void Function(Message message) onReplyRequested,
  required Future<void> Function(Message message) onForwardRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested,
  required Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested,
  required void Function(String detailId) onDetailsRequested,
  required void Function(Message message) onStartMultiSelectRequested,
  required void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested,
  required Future<void> Function(Message message) onEditRequested,
  required void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested,
  required void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested,
  required void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested,
  required void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required Future<void> Function(Message message) onReactionSelectionRequested,
}) {
  final l10n = context.l10n;
  final callbacks = _resolveTimelineMessageActionCallbacks(
    timelineMessageItem: timelineMessageItem,
    messageModel: messageModel,
    chatEntity: chatEntity,
    roomState: roomState,
    readOnly: readOnly,
    self: self,
    multiSelectActive: multiSelectActive,
    canTogglePins: canTogglePins,
    canReact: canReact,
    requiresMucReference: requiresMucReference,
    loadingMucReference: loadingMucReference,
    isSingleSelection: isSingleSelection,
    isInviteMessage: isInviteMessage,
    isInviteRevocationMessage: isInviteRevocationMessage,
    inviteRevoked: inviteRevoked,
    isPinned: isPinned,
    isImportant: isImportant,
    messageStatus: messageStatus,
    detailId: detailId,
    onReplyRequested: onReplyRequested,
    onForwardRequested: onForwardRequested,
    onCopyRequested: onCopyRequested,
    onShareRequested: onShareRequested,
    onAddToCalendarRequested: onAddToCalendarRequested,
    onDetailsRequested: onDetailsRequested,
    onStartMultiSelectRequested: onStartMultiSelectRequested,
    onResendRequested: onResendRequested,
    onEditRequested: onEditRequested,
    onImportantToggleRequested: onImportantToggleRequested,
    onPinToggleRequested: onPinToggleRequested,
    onRevokeInviteRequested: onRevokeInviteRequested,
    onBubbleTapRequested: onBubbleTapRequested,
    onToggleQuickReactionRequested: onToggleQuickReactionRequested,
    onReactionSelectionRequested: onReactionSelectionRequested,
  );
  final actionBar = _MessageActionBar(
    onReply: callbacks.onReply,
    onForward: callbacks.onForward,
    onCopy: callbacks.onCopy,
    onShare: callbacks.onShare,
    shareStatus: shareRequestStatus,
    onAddToCalendar: callbacks.onAddToCalendar,
    onDetails: callbacks.onDetails,
    replyLoading: callbacks.replyLoading,
    onSelect: callbacks.onSelect,
    onResend: callbacks.onResend,
    onEdit: callbacks.onEdit,
    importantDisabled: callbacks.importantDisabled,
    onImportantToggle: callbacks.onImportantToggle,
    isImportant: isImportant,
    pinDisabled: callbacks.pinDisabled,
    pinLoading: callbacks.pinLoading,
    onPinToggle: callbacks.onPinToggle,
    isPinned: isPinned,
    onRevokeInvite: callbacks.onRevokeInvite,
  );
  final reactionManager = callbacks.canShowReactionManager
      ? _ReactionManager(
          reactions: reactions,
          disabled: callbacks.reactionManagerDisabled,
          disabledLoading: loadingMucReference,
          onToggle: callbacks.onToggleReaction,
          onAddCustom: callbacks.onAddReaction,
          disabledMessage: loadingMucReference
              ? l10n.chatMucReferencePending
              : l10n.chatMucReferenceUnavailable,
        )
      : null;
  return (
    actionBar: actionBar,
    reactionManager: reactionManager,
    onBubbleTap: callbacks.onBubbleTap,
  );
}

({Widget attachmentsAligned, Widget extrasAligned, Widget? senderLabel})
_resolveTimelineMessageRowDecorations({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatUser messageUser,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool canReact,
  required bool showRecipientCutout,
  required double availableWidth,
  required double selectionExtrasPreferredMaxWidth,
  required double messageRowMaxWidth,
  required double bubbleMaxWidthForLayout,
  required double? measuredBubbleWidth,
  required double bubbleBottomCutoutPadding,
  required Object bubbleContentKey,
  required List<Widget> bubbleExtraChildren,
  required BoxConstraints bubbleExtraConstraints,
  required List<BoxShadow> bubbleShadows,
  required bool hasAvatarSlot,
  required double avatarContentInset,
  required Widget actionBar,
  required Widget? reactionManager,
}) {
  final spacing = context.spacing;
  final recipientHeadroom = showRecipientCutout ? spacing.m : 0.0;
  final attachmentTopPadding =
      (isSingleSelection ? spacing.s : spacing.m) + recipientHeadroom;
  final attachmentBottomPadding =
      spacing.xl + ((canReact && isSingleSelection) ? spacing.m : 0);
  final attachmentPadding = EdgeInsets.only(
    top: attachmentTopPadding,
    bottom: attachmentBottomPadding,
    left: spacing.m,
    right: spacing.m,
  );
  final attachmentsAligned = _ChatTimelineMessageSelectionExtras(
    self: self,
    isSingleSelection: isSingleSelection,
    actionBar: actionBar,
    reactionManager: reactionManager,
    availableWidth: availableWidth,
    selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    messageRowMaxWidth: messageRowMaxWidth,
    measuredBubbleWidth: measuredBubbleWidth,
    attachmentPadding: attachmentPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
  );
  final extrasAligned = bubbleExtraChildren.isEmpty
      ? const SizedBox.shrink()
      : _ChatTimelineMessageExtrasView(
          self: self,
          isSelected: isSelected,
          bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
          bubbleContentKey: bubbleContentKey,
          bubbleExtraChildren: bubbleExtraChildren,
          bubbleExtraConstraints: bubbleExtraConstraints,
          extraShadows: bubbleShadows,
        );
  final senderLabel = _senderLabelForTimelineMessage(
    context: context,
    shouldShow: !_chatTimelineItemsShouldChain(currentItem, previous),
    isSelfBubble: self,
    hasAvatarSlot: hasAvatarSlot,
    avatarContentInset: avatarContentInset,
    user: messageUser,
    selfLabel: context.l10n.chatSenderYou,
  );
  return (
    attachmentsAligned: attachmentsAligned,
    extrasAligned: extrasAligned,
    senderLabel: senderLabel,
  );
}

class _ChatTimelineMessageShellView extends StatelessWidget {
  const _ChatTimelineMessageShellView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.messageUser,
    required this.readOnly,
    required this.isGroupChat,
    required this.multiSelectActive,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.rowKey,
    required this.measuredBubbleWidth,
    required this.animate,
    required this.onTapOutside,
    required this.availableWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.viewData,
    required this.interactionData,
    required this.bubbleContentData,
    required this.quotedPreview,
    required this.forwardedPreview,
    required this.actionBar,
    required this.reactionManager,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onRecipientTap,
    required this.onBubbleTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final ChatUser messageUser;
  final bool readOnly;
  final bool isGroupChat;
  final bool multiSelectActive;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Key? rowKey;
  final double? measuredBubbleWidth;
  final bool animate;
  final TapRegionCallback? onTapOutside;
  final double availableWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final ({
    String detailId,
    bool self,
    double bubbleMaxWidth,
    Color bubbleColor,
    Color borderColor,
    bool isEmailMessage,
    bool isPinned,
    bool isImportant,
  })
  viewData;
  final ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
    bool showReplyStrip,
    bool canReact,
    bool requiresMucReference,
    bool loadingMucReference,
    bool isSingleSelection,
    bool isMultiSelection,
    bool isSelected,
    bool showCompactReactions,
    bool isInviteMessage,
    bool isInviteRevocationMessage,
    bool inviteRevoked,
    bool showRecipientCutout,
  })
  interactionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData;
  final Widget? quotedPreview;
  final Widget? forwardedPreview;
  final Widget actionBar;
  final Widget? reactionManager;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final VoidCallback? onBubbleTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final self = viewData.self;
    final shellData = _resolveTimelineMessageShellData(
      context: context,
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      viewData: viewData,
      interactionData: interactionData,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      bubbleContentData: bubbleContentData,
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onRecipientTap: onRecipientTap,
    );
    return _ChatTimelineMessageDecorationsView(
      currentItem: currentItem,
      previous: previous,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageUser: messageUser,
      readOnly: readOnly,
      self: self,
      isSelected: interactionData.isSelected,
      isSingleSelection: interactionData.isSingleSelection,
      isEmailMessage: viewData.isEmailMessage,
      canReact: interactionData.canReact,
      showRecipientCutout: interactionData.showRecipientCutout,
      messageRowMaxWidth: messageRowMaxWidth,
      availableWidth: availableWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      measuredBubbleWidth: measuredBubbleWidth,
      bubbleContentData: bubbleContentData,
      shellData: shellData,
      quotedPreview: quotedPreview,
      forwardedPreview: forwardedPreview,
      actionBar: actionBar,
      reactionManager: reactionManager,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      animate: animate,
      onBubbleTap: onBubbleTap,
      onTapOutside: onTapOutside,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

class _ChatTimelineMessageDecorationsView extends StatelessWidget {
  const _ChatTimelineMessageDecorationsView({
    required this.currentItem,
    required this.previous,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.messageUser,
    required this.readOnly,
    required this.self,
    required this.isSelected,
    required this.isSingleSelection,
    required this.isEmailMessage,
    required this.canReact,
    required this.showRecipientCutout,
    required this.messageRowMaxWidth,
    required this.availableWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.measuredBubbleWidth,
    required this.bubbleContentData,
    required this.shellData,
    required this.quotedPreview,
    required this.forwardedPreview,
    required this.actionBar,
    required this.reactionManager,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.rowKey,
    required this.animate,
    required this.onBubbleTap,
    required this.onTapOutside,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final ChatUser messageUser;
  final bool readOnly;
  final bool self;
  final bool isSelected;
  final bool isSingleSelection;
  final bool isEmailMessage;
  final bool canReact;
  final bool showRecipientCutout;
  final double messageRowMaxWidth;
  final double availableWidth;
  final double selectionExtrasPreferredMaxWidth;
  final double? measuredBubbleWidth;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData;
  final ({
    Widget bubble,
    EdgeInsets outerPadding,
    double bubbleMaxWidthForLayout,
    double bubbleBottomCutoutPadding,
    BoxConstraints bubbleExtraConstraints,
    List<BoxShadow> bubbleShadows,
    bool hasAvatarSlot,
    double avatarContentInset,
  })
  shellData;
  final Widget? quotedPreview;
  final Widget? forwardedPreview;
  final Widget actionBar;
  final Widget? reactionManager;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Key? rowKey;
  final bool animate;
  final VoidCallback? onBubbleTap;
  final TapRegionCallback? onTapOutside;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final (
      attachmentsAligned: attachments,
      extrasAligned: extrasAligned,
      senderLabel: senderLabel,
    ) = _resolveTimelineMessageRowDecorations(
      context: context,
      currentItem: currentItem,
      previous: previous,
      messageUser: messageUser,
      self: self,
      isSelected: isSelected,
      isSingleSelection: isSingleSelection,
      canReact: canReact,
      showRecipientCutout: showRecipientCutout,
      availableWidth: availableWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      bubbleMaxWidthForLayout: shellData.bubbleMaxWidthForLayout,
      measuredBubbleWidth: measuredBubbleWidth,
      bubbleBottomCutoutPadding: shellData.bubbleBottomCutoutPadding,
      bubbleContentKey: bubbleContentData.bubbleContentKey,
      bubbleExtraChildren: bubbleContentData.bubbleExtraChildren,
      bubbleExtraConstraints: shellData.bubbleExtraConstraints,
      bubbleShadows: shellData.bubbleShadows,
      hasAvatarSlot: shellData.hasAvatarSlot,
      avatarContentInset: shellData.avatarContentInset,
      actionBar: actionBar,
      reactionManager: reactionManager,
    );
    return _ChatTimelineMessageRowView(
      messageId: messageModel.stanzaID,
      rowKey: rowKey,
      readOnly: readOnly,
      self: self,
      isSingleSelection: isSingleSelection,
      isEmailMessage: isEmailMessage,
      showUnreadIndicator: timelineMessageItem.showUnreadIndicator,
      messageRowMaxWidth: messageRowMaxWidth,
      bubblePreviewWidth: shellData.bubbleMaxWidthForLayout,
      replyPreviewMaxWidth: messageRowMaxWidth,
      messageRowAlignment: self ? Alignment.centerRight : Alignment.centerLeft,
      outerPadding: shellData.outerPadding,
      bubble: shellData.bubble,
      senderLabel: senderLabel,
      forwardedPreview: forwardedPreview,
      quotedPreview: quotedPreview,
      attachmentsAligned: attachments,
      extrasAligned: extrasAligned,
      showExtras: bubbleContentData.bubbleExtraChildren.isNotEmpty,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      animate: animate,
      onBubbleTap: onBubbleTap,
      onBubbleSizeChanged: (size) =>
          onBubbleSizeChanged(messageModel.stanzaID, size),
      onTapOutside: onTapOutside,
    );
  }
}
