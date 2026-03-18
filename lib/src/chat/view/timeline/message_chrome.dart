part of '../chat.dart';

extension on MessageStatus {
  IconData get icon => switch (this) {
    MessageStatus.read => LucideIcons.checkCheck,
    MessageStatus.received || MessageStatus.sent => LucideIcons.check,
    MessageStatus.failed => LucideIcons.x,
    _ => LucideIcons.dot,
  };
}

BorderRadius _bubbleBaseRadius(BuildContext context) =>
    BorderRadius.circular(context.radii.squircle);

EdgeInsets _bubblePadding(BuildContext context) => EdgeInsets.symmetric(
  horizontal: context.spacing.s,
  vertical: context.spacing.s,
);

OutlinedBorder _attachmentSurfaceShape({
  required BuildContext context,
  required bool isSelf,
  required bool chainedPrevious,
  required bool chainedNext,
}) {
  final spacing = context.spacing;
  final radius = Radius.circular(spacing.m);
  if (!chainedPrevious && !chainedNext) {
    return ContinuousRectangleBorder(borderRadius: BorderRadius.all(radius));
  }
  var topLeading = radius;
  var topTrailing = radius;
  var bottomLeading = radius;
  var bottomTrailing = radius;
  if (isSelf) {
    if (chainedPrevious) topTrailing = Radius.zero;
    if (chainedNext) bottomTrailing = Radius.zero;
  } else {
    if (chainedPrevious) topLeading = Radius.zero;
    if (chainedNext) bottomLeading = Radius.zero;
  }
  return ContinuousRectangleBorder(
    borderRadius: BorderRadius.only(
      topLeft: topLeading,
      topRight: topTrailing,
      bottomLeft: bottomLeading,
      bottomRight: bottomTrailing,
    ),
  );
}

bool _chatTimelineItemsShouldChain(
  ChatTimelineItem current,
  ChatTimelineItem? neighbor,
) {
  if (current is! ChatTimelineMessageItem ||
      neighbor is! ChatTimelineMessageItem) {
    return false;
  }
  if (neighbor.authorId != current.authorId) {
    return false;
  }
  final neighborDate = DateTime(
    neighbor.createdAt.year,
    neighbor.createdAt.month,
    neighbor.createdAt.day,
  );
  final currentDate = DateTime(
    current.createdAt.year,
    current.createdAt.month,
    current.createdAt.day,
  );
  return neighborDate == currentDate;
}

Widget? _senderLabelForTimelineMessage({
  required BuildContext context,
  required bool shouldShow,
  required bool isSelfBubble,
  required bool hasAvatarSlot,
  required double avatarContentInset,
  required ChatUser user,
  required String selfLabel,
}) {
  if (!shouldShow) {
    return null;
  }
  final spacing = context.spacing;
  final leftInset = !isSelfBubble && hasAvatarSlot
      ? avatarContentInset + _bubblePadding(context).left + spacing.xxs
      : 0.0;
  return _MessageSenderLabel(
    user: user,
    isSelf: isSelfBubble,
    selfLabel: selfLabel,
    leftInset: leftInset,
  );
}

bool _timelineQuotedMessageIsSelf({
  required Message quotedMessage,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? fallbackSelfNick,
  required String? currentUserId,
}) {
  if (isGroupChat) {
    return isMucSelfMessage(
      senderJid: quotedMessage.senderJid,
      roomState: roomState,
      fallbackSelfNick: fallbackSelfNick,
    );
  }
  return quotedMessage.isFromAuthorizedJid(currentUserId);
}

String _timelineForwardedSenderLabel({
  required String? forwardedFromJid,
  required String fallbackSenderJid,
  required bool fallbackIsSelf,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? currentUserId,
  required AppLocalizations l10n,
}) {
  final source = forwardedFromJid?.trim();
  if (source == null || source.isEmpty) {
    if (fallbackIsSelf) {
      return l10n.chatSenderYou;
    }
    final fallbackNick = roomState?.senderNick(fallbackSenderJid);
    if (fallbackNick != null && fallbackNick.isNotEmpty) {
      return fallbackNick;
    }
    final fallbackResolved = fallbackSenderJid.trim();
    return fallbackResolved.isNotEmpty
        ? fallbackResolved
        : l10n.commonUnknownLabel;
  }
  if (bareAddress(source) == bareAddress(currentUserId)) {
    return l10n.chatSenderYou;
  }
  if (isGroupChat) {
    final nick = roomState?.senderNick(source);
    if (nick != null && nick.isNotEmpty) {
      return nick;
    }
  }
  return source;
}

String _timelineQuotedSenderLabel({
  required Message quotedMessage,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? chatDisplayName,
  required AppLocalizations l10n,
}) {
  if (isGroupChat) {
    final nick = roomState?.senderNick(quotedMessage.senderJid);
    final normalizedNick = nick?.trim() ?? _emptyText;
    if (normalizedNick.isNotEmpty) {
      return normalizedNick;
    }
  } else {
    final displayName = chatDisplayName?.trim() ?? _emptyText;
    if (displayName.isNotEmpty) {
      return displayName;
    }
  }
  final senderFallback = quotedMessage.senderJid.trim();
  if (senderFallback.isNotEmpty) {
    return senderFallback;
  }
  return l10n.commonUnknownLabel;
}

Widget? _timelineQuotedPreview({
  required Message? quotedMessage,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? fallbackSelfNick,
  required String? currentUserId,
  required String? chatDisplayName,
  required AppLocalizations l10n,
  required bool isSelfBubble,
}) {
  if (quotedMessage == null) {
    return null;
  }
  final quotedIsSelf = _timelineQuotedMessageIsSelf(
    quotedMessage: quotedMessage,
    isGroupChat: isGroupChat,
    roomState: roomState,
    fallbackSelfNick: fallbackSelfNick,
    currentUserId: currentUserId,
  );
  return _QuotedMessagePreview(
    message: quotedMessage,
    senderLabel: quotedIsSelf
        ? l10n.chatSenderYou
        : _timelineQuotedSenderLabel(
            quotedMessage: quotedMessage,
            isGroupChat: isGroupChat,
            roomState: roomState,
            chatDisplayName: chatDisplayName,
            l10n: l10n,
          ),
    isSelf: isSelfBubble,
  );
}

Widget? _timelineForwardedPreview({
  required bool isForwarded,
  required String? forwardedFromJid,
  required String? forwardedSubjectSenderLabel,
  required String fallbackSenderJid,
  required bool fallbackIsSelf,
  required bool isGroupChat,
  required RoomState? roomState,
  required String? currentUserId,
  required AppLocalizations l10n,
  required bool isSelfBubble,
}) {
  if (!isForwarded) {
    return null;
  }
  final resolvedForwardedSenderLabel = _timelineForwardedSenderLabel(
    forwardedFromJid: forwardedFromJid,
    fallbackSenderJid: fallbackSenderJid,
    fallbackIsSelf: fallbackIsSelf,
    isGroupChat: isGroupChat,
    roomState: roomState,
    currentUserId: currentUserId,
    l10n: l10n,
  );
  return _ForwardedPreviewText(
    senderLabel: forwardedFromJid?.trim().isNotEmpty == true
        ? resolvedForwardedSenderLabel
        : (forwardedSubjectSenderLabel ?? resolvedForwardedSenderLabel),
    isSelf: isSelfBubble,
  );
}

({
  Widget? avatarOverlay,
  CutoutStyle? avatarStyle,
  ChatBubbleCutoutAnchor avatarAnchor,
})
resolveTimelineMessageAvatarCutout({
  required BuildContext context,
  required bool requiresAvatarHeadroom,
  required ChatTimelineMessageItem timelineMessageItem,
  required double messageAvatarSize,
  required double avatarCutoutDepth,
  required double avatarCutoutRadius,
  required double avatarMinThickness,
  required double messageAvatarCornerClearance,
  required EdgeInsets messageAvatarCutoutPadding,
  required double avatarCutoutAlignment,
}) {
  if (!requiresAvatarHeadroom) {
    return (
      avatarOverlay: null,
      avatarStyle: null,
      avatarAnchor: ChatBubbleCutoutAnchor.left,
    );
  }
  final messageAvatarPath = timelineMessageItem.authorAvatarPath?.trim();
  return (
    avatarOverlay: _MessageAvatar(
      jid: timelineMessageItem.authorAvatarKey,
      size: messageAvatarSize,
      avatarPath: messageAvatarPath?.isNotEmpty == true
          ? messageAvatarPath
          : null,
    ),
    avatarStyle: CutoutStyle(
      depth: avatarCutoutDepth,
      cornerRadius: avatarCutoutRadius,
      shapeCornerRadius: context.radii.squircle,
      padding: messageAvatarCutoutPadding,
      offset: Offset.zero,
      minThickness: avatarMinThickness,
      cornerClearance: messageAvatarCornerClearance,
      alignment: avatarCutoutAlignment,
    ),
    avatarAnchor: ChatBubbleCutoutAnchor.left,
  );
}

String resolveMessageAvatarSeed({
  required Message message,
  required RoomState? roomState,
  required Occupant? occupant,
  required String fallbackLabel,
  required String unknownLabel,
}) {
  final resolvedOccupant =
      occupant ??
      roomState?.occupantForSenderJid(message.senderJid, preferRealJid: true);
  final occupantNick = resolvedOccupant?.nick.trim();
  if (occupantNick != null && occupantNick.isNotEmpty) {
    return occupantNick;
  }

  final trimmedFallback = fallbackLabel.trim();
  if (trimmedFallback.isEmpty) {
    return unknownLabel;
  }

  final senderBare = bareAddressValue(message.senderJid);
  final chatBare = bareAddressValue(message.chatJid);
  final fallbackBare = bareAddressValue(trimmedFallback);
  if (senderBare != null &&
      chatBare != null &&
      senderBare == chatBare &&
      fallbackBare == chatBare) {
    return unknownLabel;
  }
  return trimmedFallback;
}

class _ChatTimelineMessageInteractionView extends StatelessWidget {
  const _ChatTimelineMessageInteractionView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.state,
    required this.chatEntity,
    required this.roomState,
    required this.currentUserId,
    required this.selfNick,
    required this.selfXmppJid,
    required this.myOccupantJid,
    required this.resolvedDirectChatDisplayName,
    required this.readOnly,
    required this.isGroupChat,
    required this.isEmailChat,
    required this.isWelcomeChat,
    required this.attachmentsBlockedForChat,
    required this.multiSelectActive,
    required this.selectedMessageId,
    required this.canTogglePins,
    required this.availabilityActorId,
    required this.availabilityShareOwnersById,
    required this.availabilityCoordinator,
    required this.normalizedXmppSelfJid,
    required this.normalizedEmailSelfJid,
    required this.personalCalendarAvailable,
    required this.chatCalendarAvailable,
    required this.messageFontSize,
    required this.availableWidth,
    required this.inboundMessageRowMaxWidth,
    required this.outboundMessageRowMaxWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.shareRequestStatus,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.messageKeys,
    required this.bubbleWidthByMessageId,
    required this.shouldAnimateMessage,
    required this.isPinnedMessage,
    required this.isImportantMessage,
    required this.onTapOutsideRequested,
    required this.resolveViewData,
    required this.resolveInteractionData,
    required this.composeBubbleContent,
    required this.onReplyRequested,
    required this.onForwardRequested,
    required this.onCopyRequested,
    required this.onShareRequested,
    required this.onAddToCalendarRequested,
    required this.onDetailsRequested,
    required this.onStartMultiSelectRequested,
    required this.onResendRequested,
    required this.onEditRequested,
    required this.onImportantToggleRequested,
    required this.onPinToggleRequested,
    required this.onRevokeInviteRequested,
    required this.onBubbleTapRequested,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onReactionSelectionRequested,
    required this.onRecipientTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final ChatState state;
  final chat_models.Chat? chatEntity;
  final RoomState? roomState;
  final String? currentUserId;
  final String? selfNick;
  final String? selfXmppJid;
  final String? myOccupantJid;
  final String? resolvedDirectChatDisplayName;
  final bool readOnly;
  final bool isGroupChat;
  final bool isEmailChat;
  final bool isWelcomeChat;
  final bool attachmentsBlockedForChat;
  final bool multiSelectActive;
  final String? selectedMessageId;
  final bool canTogglePins;
  final String? availabilityActorId;
  final Map<String, String> availabilityShareOwnersById;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final String? normalizedXmppSelfJid;
  final String? normalizedEmailSelfJid;
  final bool personalCalendarAvailable;
  final bool chatCalendarAvailable;
  final double messageFontSize;
  final double availableWidth;
  final double inboundMessageRowMaxWidth;
  final double outboundMessageRowMaxWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final RequestStatus shareRequestStatus;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Map<String, GlobalKey> messageKeys;
  final Map<String, double> bubbleWidthByMessageId;
  final bool Function(Message message) shouldAnimateMessage;
  final bool Function(Message message) isPinnedMessage;
  final bool Function(Message message) isImportantMessage;
  final TapRegionCallback onTapOutsideRequested;
  final ({
    String detailId,
    TextStyle extraStyle,
    bool self,
    double bubbleMaxWidth,
    bool isError,
    Color bubbleColor,
    Color borderColor,
    Color textColor,
    TextStyle baseTextStyle,
    TextStyle linkStyle,
    bool isEmailMessage,
    String messageText,
    TextStyle surfaceDetailStyle,
    List<InlineSpan> messageDetails,
    Map<int, double> detailOpticalOffsetFactors,
    List<InlineSpan> surfaceDetails,
  })
  Function({
    required BuildContext context,
    required ChatTimelineMessageItem timelineMessageItem,
    required bool isPinned,
    required bool isImportant,
    required double inboundMessageRowMaxWidth,
    required double outboundMessageRowMaxWidth,
    required double messageFontSize,
  })
  resolveViewData;
  final ({
    List<ReactionPreview> reactions,
    List<chat_models.Chat> replyParticipants,
    List<chat_models.Chat> recipientCutoutParticipants,
    List<String> attachmentIds,
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
  Function({
    required ChatState state,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isGroupChat,
    required String? selfXmppJid,
    required String? myOccupantJid,
  })
  resolveInteractionData;
  final ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  Function({
    required BuildContext context,
    required ChatState state,
    required Object detailId,
    required ChatTimelineMessageItem timelineMessageItem,
    required Message messageModel,
    required String messageText,
    required bool self,
    required bool isError,
    required bool isInviteMessage,
    required bool isInviteRevocationMessage,
    required bool inviteRevoked,
    required bool isEmailMessage,
    required bool isEmailChat,
    required bool isSingleSelection,
    required bool isWelcomeChat,
    required bool attachmentsBlockedForChat,
    required bool showCompactReactions,
    required bool showReplyStrip,
    required bool showRecipientCutout,
    required String? availabilityActorId,
    required Map<String, String> availabilityShareOwnersById,
    required CalendarAvailabilityShareCoordinator? availabilityCoordinator,
    required String? normalizedXmppSelfJid,
    required String? normalizedEmailSelfJid,
    required bool personalCalendarAvailable,
    required bool chatCalendarAvailable,
    required String? selfXmppJid,
    required Color bubbleColor,
    required Color textColor,
    required TextStyle baseTextStyle,
    required TextStyle linkStyle,
    required TextStyle surfaceDetailStyle,
    required TextStyle extraStyle,
    required List<InlineSpan> messageDetails,
    required List<InlineSpan> surfaceDetails,
    required Map<int, double> detailOpticalOffsetFactors,
    required List<String> attachmentIds,
    required bool chainsIntoNextMessage,
  })
  composeBubbleContent;
  final void Function(Message message) onReplyRequested;
  final Future<void> Function(Message message) onForwardRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested;
  final void Function(String detailId) onDetailsRequested;
  final void Function(Message message) onStartMultiSelectRequested;
  final void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested;
  final Future<void> Function(Message message) onEditRequested;
  final void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested;
  final void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested;
  final void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested;
  final void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final Future<void> Function(Message message) onReactionSelectionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final messageModel = timelineMessageItem.messageModel;
    final isPinned = isPinnedMessage(messageModel);
    final isImportant = isImportantMessage(messageModel);
    final rowKey = messageKeys[messageModel.stanzaID];
    final measuredBubbleWidth = bubbleWidthByMessageId[messageModel.stanzaID];
    final animate = shouldAnimateMessage(messageModel);
    final onTapOutside =
        !multiSelectActive && selectedMessageId == messageModel.stanzaID
        ? onTapOutsideRequested
        : null;
    final (
      detailId: detailId,
      extraStyle: extraStyle,
      self: self,
      bubbleMaxWidth: bubbleMaxWidth,
      isError: isError,
      bubbleColor: bubbleColor,
      borderColor: borderColor,
      textColor: textColor,
      baseTextStyle: baseTextStyle,
      linkStyle: linkStyle,
      isEmailMessage: isEmailMessage,
      messageText: messageText,
      surfaceDetailStyle: surfaceDetailStyle,
      messageDetails: messageDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      surfaceDetails: surfaceDetails,
    ) = resolveViewData(
      context: context,
      timelineMessageItem: timelineMessageItem,
      isPinned: isPinned,
      isImportant: isImportant,
      inboundMessageRowMaxWidth: inboundMessageRowMaxWidth,
      outboundMessageRowMaxWidth: outboundMessageRowMaxWidth,
      messageFontSize: messageFontSize,
    );
    final (
      reactions: reactions,
      replyParticipants: replyParticipants,
      recipientCutoutParticipants: recipientCutoutParticipants,
      attachmentIds: attachmentIds,
      showReplyStrip: showReplyStrip,
      canReact: canReact,
      requiresMucReference: requiresMucReference,
      loadingMucReference: loadingMucReference,
      isSingleSelection: isSingleSelection,
      isMultiSelection: isMultiSelection,
      isSelected: isSelected,
      showCompactReactions: showCompactReactions,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      showRecipientCutout: showRecipientCutout,
    ) = resolveInteractionData(
      state: state,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      isEmailMessage: isEmailMessage,
      isEmailChat: isEmailChat,
      isGroupChat: isGroupChat,
      selfXmppJid: selfXmppJid,
      myOccupantJid: myOccupantJid,
    );
    final (
      bubbleContentKey: bubbleContentKey,
      bubbleTextChildren: bubbleTextChildren,
      bubbleExtraChildren: bubbleExtraChildren,
    ) = composeBubbleContent(
      context: context,
      state: state,
      detailId: detailId,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageText: messageText,
      self: self,
      isError: isError,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      isEmailMessage: isEmailMessage,
      isEmailChat: isEmailChat,
      isSingleSelection: isSingleSelection,
      isWelcomeChat: isWelcomeChat,
      attachmentsBlockedForChat: attachmentsBlockedForChat,
      showCompactReactions: showCompactReactions,
      showReplyStrip: showReplyStrip,
      showRecipientCutout: showRecipientCutout,
      availabilityActorId: availabilityActorId,
      availabilityShareOwnersById: availabilityShareOwnersById,
      availabilityCoordinator: availabilityCoordinator,
      normalizedXmppSelfJid: normalizedXmppSelfJid,
      normalizedEmailSelfJid: normalizedEmailSelfJid,
      personalCalendarAvailable: personalCalendarAvailable,
      chatCalendarAvailable: chatCalendarAvailable,
      selfXmppJid: selfXmppJid,
      bubbleColor: bubbleColor,
      textColor: textColor,
      baseTextStyle: baseTextStyle,
      linkStyle: linkStyle,
      surfaceDetailStyle: surfaceDetailStyle,
      extraStyle: extraStyle,
      messageDetails: messageDetails,
      surfaceDetails: surfaceDetails,
      detailOpticalOffsetFactors: detailOpticalOffsetFactors,
      attachmentIds: attachmentIds,
      chainsIntoNextMessage: _chatTimelineItemsShouldChain(currentItem, next),
    );
    return _ChatTimelineMessageChromeView(
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      chatEntity: chatEntity,
      roomState: roomState,
      currentUserId: currentUserId,
      selfNick: selfNick,
      resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
      readOnly: readOnly,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      canTogglePins: canTogglePins,
      shareRequestStatus: shareRequestStatus,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      measuredBubbleWidth: measuredBubbleWidth,
      animate: animate,
      onTapOutside: onTapOutside,
      availableWidth: availableWidth,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      viewData: (
        detailId: detailId,
        self: self,
        bubbleMaxWidth: bubbleMaxWidth,
        bubbleColor: bubbleColor,
        borderColor: borderColor,
        isEmailMessage: isEmailMessage,
        isPinned: isPinned,
        isImportant: isImportant,
      ),
      interactionData: (
        reactions: reactions,
        replyParticipants: replyParticipants,
        recipientCutoutParticipants: recipientCutoutParticipants,
        showReplyStrip: showReplyStrip,
        canReact: canReact,
        requiresMucReference: requiresMucReference,
        loadingMucReference: loadingMucReference,
        isSingleSelection: isSingleSelection,
        isMultiSelection: isMultiSelection,
        isSelected: isSelected,
        showCompactReactions: showCompactReactions,
        isInviteMessage: isInviteMessage,
        isInviteRevocationMessage: isInviteRevocationMessage,
        inviteRevoked: inviteRevoked,
        showRecipientCutout: showRecipientCutout,
      ),
      bubbleContentData: (
        bubbleContentKey: bubbleContentKey,
        bubbleTextChildren: bubbleTextChildren,
        bubbleExtraChildren: bubbleExtraChildren,
      ),
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
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onReactionSelectionRequested: onReactionSelectionRequested,
      onRecipientTap: onRecipientTap,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

class _ChatTimelineMessageChromeView extends StatelessWidget {
  const _ChatTimelineMessageChromeView({
    required this.currentItem,
    required this.previous,
    required this.next,
    required this.timelineMessageItem,
    required this.messageModel,
    required this.chatEntity,
    required this.roomState,
    required this.currentUserId,
    required this.selfNick,
    required this.resolvedDirectChatDisplayName,
    required this.readOnly,
    required this.isGroupChat,
    required this.multiSelectActive,
    required this.canTogglePins,
    required this.shareRequestStatus,
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
    required this.onReplyRequested,
    required this.onForwardRequested,
    required this.onCopyRequested,
    required this.onShareRequested,
    required this.onAddToCalendarRequested,
    required this.onDetailsRequested,
    required this.onStartMultiSelectRequested,
    required this.onResendRequested,
    required this.onEditRequested,
    required this.onImportantToggleRequested,
    required this.onPinToggleRequested,
    required this.onRevokeInviteRequested,
    required this.onBubbleTapRequested,
    required this.onToggleMultiSelectRequested,
    required this.onToggleQuickReactionRequested,
    required this.onReactionSelectionRequested,
    required this.onRecipientTap,
    required this.onBubbleSizeChanged,
  });

  final ChatTimelineItem currentItem;
  final ChatTimelineItem? previous;
  final ChatTimelineItem? next;
  final ChatTimelineMessageItem timelineMessageItem;
  final Message messageModel;
  final chat_models.Chat? chatEntity;
  final RoomState? roomState;
  final String? currentUserId;
  final String? selfNick;
  final String? resolvedDirectChatDisplayName;
  final bool readOnly;
  final bool isGroupChat;
  final bool multiSelectActive;
  final bool canTogglePins;
  final RequestStatus shareRequestStatus;
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
  final void Function(Message message) onReplyRequested;
  final Future<void> Function(Message message) onForwardRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onCopyRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onShareRequested;
  final Future<void> Function({
    required String fallbackText,
    required Message model,
  })
  onAddToCalendarRequested;
  final void Function(String detailId) onDetailsRequested;
  final void Function(Message message) onStartMultiSelectRequested;
  final void Function(Message message, {required chat_models.Chat? chat})
  onResendRequested;
  final Future<void> Function(Message message) onEditRequested;
  final void Function(
    Message message, {
    required bool important,
    required chat_models.Chat? chat,
  })
  onImportantToggleRequested;
  final void Function(
    Message message, {
    required bool pin,
    required chat_models.Chat? chat,
    required RoomState? roomState,
  })
  onPinToggleRequested;
  final void Function(Message message, {String? inviteeJidFallback})
  onRevokeInviteRequested;
  final void Function(Message message, {required bool showUnreadIndicator})
  onBubbleTapRequested;
  final void Function(Message message) onToggleMultiSelectRequested;
  final void Function(Message message, String emoji)
  onToggleQuickReactionRequested;
  final Future<void> Function(Message message) onReactionSelectionRequested;
  final void Function(chat_models.Chat chat) onRecipientTap;
  final void Function(String messageId, Size size) onBubbleSizeChanged;

  @override
  Widget build(BuildContext context) {
    final (
      :detailId,
      self: self,
      :bubbleMaxWidth,
      :bubbleColor,
      :borderColor,
      isEmailMessage: isEmailMessage,
      isPinned: isPinned,
      isImportant: isImportant,
    ) = viewData;
    final (
      :reactions,
      replyParticipants: replyParticipants,
      recipientCutoutParticipants: recipientCutoutParticipants,
      showReplyStrip: showReplyStrip,
      canReact: canReact,
      requiresMucReference: requiresMucReference,
      loadingMucReference: loadingMucReference,
      isSingleSelection: isSingleSelection,
      isMultiSelection: isMultiSelection,
      isSelected: isSelected,
      showCompactReactions: showCompactReactions,
      isInviteMessage: isInviteMessage,
      isInviteRevocationMessage: isInviteRevocationMessage,
      inviteRevoked: inviteRevoked,
      showRecipientCutout: showRecipientCutout,
    ) = interactionData;
    final messageUser = ChatUser(
      id: timelineMessageItem.authorId,
      firstName: timelineMessageItem.authorDisplayName,
      profileImage: timelineMessageItem.authorAvatarPath,
    );
    final messageStatus = switch (timelineMessageItem.delivery) {
      ChatTimelineMessageDelivery.none => MessageStatus.none,
      ChatTimelineMessageDelivery.pending => MessageStatus.pending,
      ChatTimelineMessageDelivery.sent => MessageStatus.sent,
      ChatTimelineMessageDelivery.received => MessageStatus.received,
      ChatTimelineMessageDelivery.read => MessageStatus.read,
      ChatTimelineMessageDelivery.failed => MessageStatus.failed,
    };
    final (
      quotedPreview: replyPreview,
      forwardedPreview: forwardedPreview,
    ) = _resolveTimelineMessagePreviews(
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      roomState: roomState,
      selfNick: selfNick,
      resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
      currentUserId: currentUserId,
      isGroupChat: isGroupChat,
      self: self,
      l10n: context.l10n,
    );
    final (
      actionBar: actionBar,
      reactionManager: reactionManager,
      onBubbleTap: onBubbleTap,
    ) = _resolveTimelineMessageChromeActions(
      context: context,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      chatEntity: chatEntity,
      roomState: roomState,
      shareRequestStatus: shareRequestStatus,
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
      reactions: reactions,
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
    return _ChatTimelineMessageShellView(
      currentItem: currentItem,
      previous: previous,
      next: next,
      timelineMessageItem: timelineMessageItem,
      messageModel: messageModel,
      messageUser: messageUser,
      readOnly: readOnly,
      isGroupChat: isGroupChat,
      multiSelectActive: multiSelectActive,
      bubbleRegionRegistry: bubbleRegionRegistry,
      selectionTapRegionGroup: selectionTapRegionGroup,
      rowKey: rowKey,
      measuredBubbleWidth: measuredBubbleWidth,
      animate: animate,
      onTapOutside: onTapOutside,
      availableWidth: availableWidth,
      inboundClampedBubbleWidth: inboundClampedBubbleWidth,
      outboundClampedBubbleWidth: outboundClampedBubbleWidth,
      messageRowMaxWidth: messageRowMaxWidth,
      selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
      viewData: viewData,
      interactionData: interactionData,
      bubbleContentData: bubbleContentData,
      quotedPreview: replyPreview,
      forwardedPreview: forwardedPreview,
      actionBar: actionBar,
      reactionManager: reactionManager,
      onToggleMultiSelectRequested: onToggleMultiSelectRequested,
      onToggleQuickReactionRequested: onToggleQuickReactionRequested,
      onRecipientTap: onRecipientTap,
      onBubbleTap: onBubbleTap,
      onBubbleSizeChanged: onBubbleSizeChanged,
    );
  }
}

({
  Widget? recipientOverlay,
  CutoutStyle? recipientStyle,
  ChatBubbleCutoutAnchor recipientAnchor,
  Widget? selectionOverlay,
  CutoutStyle? selectionStyle,
  Widget? reactionOverlay,
  CutoutStyle? reactionStyle,
  double reactionBubbleInset,
  double reactionCutoutDepth,
  double reactionCutoutMinThickness,
  EdgeInsets reactionCutoutPadding,
  double reactionCornerClearance,
  double recipientBubbleInset,
  double recipientCutoutDepth,
  double recipientCutoutMinThickness,
  bool selectionOverlayVisible,
  double selectionOuterInset,
  double selectionBubbleVerticalInset,
  double selectionBubbleInboundSpacing,
  double selectionBubbleOutboundSpacing,
  bool hasAvatarSlot,
  double avatarOuterInset,
  double avatarContentInset,
  Widget? avatarOverlay,
  CutoutStyle? avatarStyle,
  ChatBubbleCutoutAnchor avatarAnchor,
})
_resolveTimelineMessageCutoutData({
  required BuildContext context,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool isEmailMessage,
  required bool isGroupChat,
  required bool multiSelectActive,
  required bool canReact,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required List<ReactionPreview> reactions,
  required List<chat_models.Chat> replyParticipants,
  required List<chat_models.Chat> recipientCutoutParticipants,
  required void Function(Message message) onToggleMultiSelectRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required void Function(chat_models.Chat chat) onRecipientTap,
}) {
  final spacing = context.spacing;
  final messageAvatarSize = spacing.l;
  final avatarCutoutDepth = messageAvatarSize / 2;
  final avatarCutoutRadius = avatarCutoutDepth + spacing.xs;
  final avatarOuterInset = avatarCutoutDepth;
  final avatarContentInset = avatarCutoutDepth - spacing.xs;
  final avatarMinThickness = messageAvatarSize;
  final avatarCutoutAlignment = Alignment.centerLeft.x;
  final messageAvatarCornerClearance = 0.0;
  const messageAvatarCutoutPadding = EdgeInsets.zero;
  final reactionBubbleInset = spacing.m;
  final reactionCutoutDepth = spacing.m;
  final reactionCutoutRadius = spacing.m;
  final reactionCutoutMinThickness = spacing.l;
  final reactionStripOffset = Offset(0, -spacing.xxs);
  final reactionCutoutPadding = EdgeInsets.symmetric(
    horizontal: spacing.xs,
    vertical: spacing.xxs,
  );
  final reactionCornerClearance = spacing.s;
  final recipientCutoutDepth = spacing.m;
  final recipientCutoutRadius = spacing.m;
  final recipientCutoutPadding = EdgeInsets.fromLTRB(
    spacing.s,
    spacing.xs,
    spacing.s,
    spacing.s,
  );
  final recipientCutoutMinThickness = spacing.xl;
  final recipientBubbleInset = recipientCutoutDepth;
  final selectionCutoutDepth = spacing.m;
  final selectionCutoutRadius = spacing.m;
  final selectionCutoutPadding = EdgeInsets.fromLTRB(
    spacing.xs,
    spacing.s,
    spacing.xs,
    spacing.s,
  );
  final selectionCutoutOffset = Offset(-(spacing.xs), 0);
  final selectionCutoutThickness = SelectionIndicator.size + spacing.s;
  final selectionBubbleInteriorInset = selectionCutoutDepth + spacing.s;
  final selectionBubbleVerticalInset = spacing.xs;
  final selectionOuterInset =
      selectionCutoutDepth + (SelectionIndicator.size / 2);
  final selectionIndicatorInset = spacing.xxs;
  final selectionBubbleInboundExtraGap = spacing.xs;
  final selectionBubbleOutboundExtraGap = spacing.s;
  final selectionBubbleOutboundSpacingBoost = spacing.s;
  final selectionBubbleInboundSpacing =
      selectionBubbleInteriorInset + selectionBubbleInboundExtraGap;
  final selectionBubbleOutboundSpacing =
      selectionBubbleInteriorInset +
      selectionBubbleOutboundExtraGap +
      selectionBubbleOutboundSpacingBoost;
  final requiresAvatarHeadroom = isGroupChat && !isEmailMessage && !self;
  final hasAvatarSlot = requiresAvatarHeadroom;
  Widget? recipientOverlay;
  CutoutStyle? recipientStyle;
  var recipientAnchor = ChatBubbleCutoutAnchor.bottom;
  if (showRecipientCutout) {
    recipientOverlay = _RecipientCutoutStrip(
      recipients: recipientCutoutParticipants,
    );
    recipientStyle = CutoutStyle(
      depth: recipientCutoutDepth,
      cornerRadius: recipientCutoutRadius,
      padding: recipientCutoutPadding,
      offset: Offset.zero,
      minThickness: recipientCutoutMinThickness,
    );
  }
  Widget? selectionOverlay;
  CutoutStyle? selectionStyle;
  if (multiSelectActive) {
    selectionOverlay = Padding(
      padding: EdgeInsets.only(left: selectionIndicatorInset),
      child: SelectionIndicator(
        visible: true,
        selected: isSingleSelection,
        onPressed: () => onToggleMultiSelectRequested(messageModel),
      ),
    );
    selectionStyle = CutoutStyle(
      depth: selectionCutoutDepth,
      cornerRadius: selectionCutoutRadius,
      padding: selectionCutoutPadding,
      offset: selectionCutoutOffset,
      minThickness: selectionCutoutThickness,
      cornerClearance: 0.0,
    );
  }
  final reactionOverlay = showReplyStrip
      ? _ReplyStrip(
          participants: replyParticipants,
          onRecipientTap: onRecipientTap,
        )
      : showCompactReactions
      ? _ReactionStrip(
          reactions: reactions,
          onReactionTap: canReact
              ? (emoji) => onToggleQuickReactionRequested(messageModel, emoji)
              : null,
        )
      : null;
  final reactionStyle = showReplyStrip
      ? CutoutStyle(
          depth: recipientCutoutDepth,
          cornerRadius: recipientCutoutRadius,
          padding: recipientCutoutPadding,
          offset: Offset.zero,
          minThickness: recipientCutoutMinThickness,
        )
      : showCompactReactions
      ? CutoutStyle(
          depth: reactionCutoutDepth,
          cornerRadius: reactionCutoutRadius,
          shapeCornerRadius: context.radii.squircle,
          padding: reactionCutoutPadding,
          offset: reactionStripOffset,
          minThickness: reactionCutoutMinThickness,
        )
      : null;
  final (
    avatarOverlay: avatarOverlay,
    avatarStyle: avatarStyle,
    avatarAnchor: avatarAnchor,
  ) = resolveTimelineMessageAvatarCutout(
    context: context,
    requiresAvatarHeadroom: requiresAvatarHeadroom,
    timelineMessageItem: timelineMessageItem,
    messageAvatarSize: messageAvatarSize,
    avatarCutoutDepth: avatarCutoutDepth,
    avatarCutoutRadius: avatarCutoutRadius,
    avatarMinThickness: avatarMinThickness,
    messageAvatarCornerClearance: messageAvatarCornerClearance,
    messageAvatarCutoutPadding: messageAvatarCutoutPadding,
    avatarCutoutAlignment: avatarCutoutAlignment,
  );
  return (
    recipientOverlay: recipientOverlay,
    recipientStyle: recipientStyle,
    recipientAnchor: recipientAnchor,
    selectionOverlay: selectionOverlay,
    selectionStyle: selectionStyle,
    reactionOverlay: reactionOverlay,
    reactionStyle: reactionStyle,
    reactionBubbleInset: reactionBubbleInset,
    reactionCutoutDepth: reactionCutoutDepth,
    reactionCutoutMinThickness: reactionCutoutMinThickness,
    reactionCutoutPadding: reactionCutoutPadding,
    reactionCornerClearance: reactionCornerClearance,
    recipientBubbleInset: recipientBubbleInset,
    recipientCutoutDepth: recipientCutoutDepth,
    recipientCutoutMinThickness: recipientCutoutMinThickness,
    selectionOverlayVisible: selectionOverlay != null,
    selectionOuterInset: selectionOuterInset,
    selectionBubbleVerticalInset: selectionBubbleVerticalInset,
    selectionBubbleInboundSpacing: selectionBubbleInboundSpacing,
    selectionBubbleOutboundSpacing: selectionBubbleOutboundSpacing,
    hasAvatarSlot: hasAvatarSlot,
    avatarOuterInset: avatarOuterInset,
    avatarContentInset: avatarContentInset,
    avatarOverlay: avatarOverlay,
    avatarStyle: avatarStyle,
    avatarAnchor: avatarAnchor,
  );
}

({
  EdgeInsetsGeometry bubblePadding,
  BorderRadius bubbleBorderRadius,
  double bubbleMaxWidthForLayout,
  BoxConstraints bubbleTextConstraints,
  BoxConstraints bubbleExtraConstraints,
  EdgeInsets outerPadding,
  double bubbleBottomCutoutPadding,
  List<BoxShadow> bubbleShadows,
  double combinedReactionCornerClearance,
})
_resolveTimelineMessageBubbleLayout({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatTimelineItem? next,
  required bool self,
  required bool isSelected,
  required bool isSingleSelection,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required bool hasAvatarSlot,
  required double avatarOuterInset,
  required double avatarContentInset,
  required double bubbleMaxWidth,
  required double inboundClampedBubbleWidth,
  required double outboundClampedBubbleWidth,
  required double messageRowMaxWidth,
  required List<Widget> bubbleTextChildren,
  required List<Widget> bubbleExtraChildren,
  required List<ReactionPreview> reactions,
  required bool selectionOverlayVisible,
  required double selectionOuterInset,
  required double selectionBubbleVerticalInset,
  required double selectionBubbleInboundSpacing,
  required double selectionBubbleOutboundSpacing,
  required double reactionBubbleInset,
  required double reactionCutoutDepth,
  required double reactionCutoutMinThickness,
  required EdgeInsets reactionCutoutPadding,
  required double reactionCornerClearance,
  required double recipientBubbleInset,
  required double recipientCutoutDepth,
}) {
  final spacing = context.spacing;
  final bubbleBaseRadius = _bubbleBaseRadius(context);
  final bubbleCornerClearance = _bubbleCornerClearance(bubbleBaseRadius);
  EdgeInsetsGeometry bubblePadding = _bubblePadding(context);
  var bubbleBottomInset = 0.0;
  if (showCompactReactions) {
    bubbleBottomInset = reactionBubbleInset;
  }
  if (showReplyStrip || showRecipientCutout) {
    bubbleBottomInset = math.max(bubbleBottomInset, recipientBubbleInset);
  }
  if (bubbleBottomInset > 0) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(bottom: bubbleBottomInset),
    );
  }
  if (selectionOverlayVisible) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(
        left: self ? selectionBubbleOutboundSpacing : 0,
        right: self ? 0 : selectionBubbleInboundSpacing,
      ),
    );
    bubblePadding = bubblePadding.add(
      EdgeInsets.symmetric(vertical: selectionBubbleVerticalInset),
    );
  }
  final chainedPrevious = _chatTimelineItemsShouldChain(currentItem, previous);
  final showAvatarContentInset = hasAvatarSlot && !chainedPrevious;
  if (showAvatarContentInset) {
    bubblePadding = bubblePadding.add(
      EdgeInsets.only(left: avatarContentInset + spacing.xxs),
    );
  }
  final hasBubbleExtras = bubbleExtraChildren.any(
    (child) => child is _MessageExtraItem,
  );
  final chainedPrev = chainedPrevious;
  final chainedNext = _chatTimelineItemsShouldChain(currentItem, next);
  final bubbleBorderRadius = _bubbleBorderRadius(
    baseRadius: bubbleBaseRadius,
    isSelf: self,
    chainedPrevious: chainedPrev,
    chainedNext: chainedNext,
    isSelected: isSelected,
    flattenBottom: hasBubbleExtras,
  );
  final selectionAllowance = selectionOverlayVisible
      ? selectionOuterInset
      : 0.0;
  final cappedBubbleWidth = math.min(
    bubbleMaxWidth,
    (self ? outboundClampedBubbleWidth : inboundClampedBubbleWidth) +
        selectionAllowance,
  );
  final combinedReactionCornerClearance =
      bubbleCornerClearance + reactionCornerClearance;
  final nextIsTailSpacer = next is ChatTimelineTailSpacerItem;
  final isLatestBubble = next == null || nextIsTailSpacer;
  final rowTopGap = previous == null
      ? 0.0
      : chainedPrev
      ? spacing.s
      : spacing.m;
  var extraOuterBottom = 0.0;
  if (showCompactReactions) {
    extraOuterBottom = math.max(extraOuterBottom, spacing.s);
  }
  if (showReplyStrip || showRecipientCutout) {
    extraOuterBottom = math.max(extraOuterBottom, recipientCutoutDepth);
  }
  if (isLatestBubble) {
    extraOuterBottom = math.max(extraOuterBottom, spacing.m);
  }
  final extraOuterLeft = hasAvatarSlot ? avatarOuterInset : 0.0;
  final outerPadding = EdgeInsets.only(
    top: rowTopGap,
    bottom: extraOuterBottom,
    left: spacing.s + extraOuterLeft,
    right: spacing.s,
  );
  final fullWidthBubbleMax = math.max(
    0.0,
    messageRowMaxWidth - outerPadding.horizontal - selectionAllowance,
  );
  final bubbleMaxWidthForLayout = isSingleSelection
      ? math.max(cappedBubbleWidth, fullWidthBubbleMax)
      : cappedBubbleWidth;
  final compactReactionMinimumBubbleWidth = showCompactReactions
      ? math.min(
          bubbleMaxWidthForLayout,
          minimumReactionCutoutBubbleWidth(
            context: context,
            reactions: reactions,
            padding: reactionCutoutPadding,
            minThickness: reactionCutoutMinThickness,
            cornerClearance: combinedReactionCornerClearance,
          ),
        )
      : 0.0;
  final bubbleTextConstraints = BoxConstraints(
    minWidth: compactReactionMinimumBubbleWidth,
    maxWidth: bubbleMaxWidthForLayout,
  );
  final bubbleExtraConstraints = BoxConstraints(maxWidth: cappedBubbleWidth);
  final reactionBottomInset = showCompactReactions ? reactionCutoutDepth : 0.0;
  final recipientBottomInset = (showReplyStrip || showRecipientCutout)
      ? recipientCutoutDepth
      : 0.0;
  final bubbleBottomCutoutPadding = showCompactReactions && hasBubbleExtras
      ? spacing.s
      : math.max(reactionBottomInset, recipientBottomInset);
  final bubbleShadows = _selectedBubbleShadows(context.colorScheme.primary);
  return (
    bubblePadding: bubblePadding,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleTextConstraints: bubbleTextConstraints,
    bubbleExtraConstraints: bubbleExtraConstraints,
    outerPadding: outerPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleShadows: bubbleShadows,
    combinedReactionCornerClearance: combinedReactionCornerClearance,
  );
}

({
  Widget bubbleContent,
  bool showBubbleSurface,
  Color bubbleSurfaceColor,
  Color bubbleSurfaceBorder,
})
_resolveTimelineMessageBubbleContent({
  required BuildContext context,
  required List<Widget> bubbleTextChildren,
  required EdgeInsetsGeometry bubblePadding,
  required BoxConstraints bubbleTextConstraints,
  required bool showCompactReactions,
  required bool showReplyStrip,
  required bool showRecipientCutout,
  required double reactionCutoutDepth,
  required double recipientCutoutDepth,
  required Color bubbleColor,
  required Color borderColor,
}) {
  final spacing = context.spacing;
  final hasBubbleText = bubbleTextChildren.isNotEmpty;
  final hasBubbleCutout =
      showCompactReactions || showReplyStrip || showRecipientCutout;
  final bubbleAnchorHeight = hasBubbleText || !hasBubbleCutout
      ? 0.0
      : math.max(
          showCompactReactions ? reactionCutoutDepth : 0.0,
          (showReplyStrip || showRecipientCutout) ? recipientCutoutDepth : 0.0,
        );
  final showBubbleSurface = hasBubbleText;
  final bubbleSurfaceColor = showBubbleSurface
      ? bubbleColor
      : Colors.transparent;
  final bubbleSurfaceBorder = showBubbleSurface
      ? borderColor
      : Colors.transparent;
  final bubbleContent = hasBubbleText
      ? Padding(
          padding: bubblePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: spacing.xs,
            children: bubbleTextChildren,
          ),
        )
      : bubbleAnchorHeight > 0
      ? SizedBox(
          width: bubbleTextConstraints.maxWidth,
          height: bubbleAnchorHeight,
        )
      : const SizedBox.shrink();
  return (
    bubbleContent: bubbleContent,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
  );
}

({
  Widget bubble,
  EdgeInsets outerPadding,
  double bubbleMaxWidthForLayout,
  double bubbleBottomCutoutPadding,
  BoxConstraints bubbleExtraConstraints,
  List<BoxShadow> bubbleShadows,
  bool hasAvatarSlot,
  double avatarContentInset,
})
_resolveTimelineMessageShellData({
  required BuildContext context,
  required ChatTimelineItem currentItem,
  required ChatTimelineItem? previous,
  required ChatTimelineItem? next,
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required ({
    String detailId,
    bool self,
    double bubbleMaxWidth,
    Color bubbleColor,
    Color borderColor,
    bool isEmailMessage,
    bool isPinned,
    bool isImportant,
  })
  viewData,
  required ({
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
  interactionData,
  required bool isGroupChat,
  required bool multiSelectActive,
  required double inboundClampedBubbleWidth,
  required double outboundClampedBubbleWidth,
  required double messageRowMaxWidth,
  required ({
    Object bubbleContentKey,
    List<Widget> bubbleTextChildren,
    List<Widget> bubbleExtraChildren,
  })
  bubbleContentData,
  required void Function(Message message) onToggleMultiSelectRequested,
  required void Function(Message message, String emoji)
  onToggleQuickReactionRequested,
  required void Function(chat_models.Chat chat) onRecipientTap,
}) {
  final self = viewData.self;
  final chainedPrevious = _chatTimelineItemsShouldChain(currentItem, previous);
  final cutoutData = _resolveTimelineMessageCutoutData(
    context: context,
    timelineMessageItem: timelineMessageItem,
    messageModel: messageModel,
    self: self,
    isSelected: interactionData.isSelected,
    isSingleSelection: interactionData.isSingleSelection,
    isEmailMessage: viewData.isEmailMessage,
    isGroupChat: isGroupChat,
    multiSelectActive: multiSelectActive,
    canReact: interactionData.canReact,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    reactions: interactionData.reactions,
    replyParticipants: interactionData.replyParticipants,
    recipientCutoutParticipants: interactionData.recipientCutoutParticipants,
    onToggleMultiSelectRequested: onToggleMultiSelectRequested,
    onToggleQuickReactionRequested: onToggleQuickReactionRequested,
    onRecipientTap: onRecipientTap,
  );
  final hasAvatarSlot = cutoutData.hasAvatarSlot;
  final (
    bubblePadding: bubblePadding,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleTextConstraints: bubbleTextConstraints,
    bubbleExtraConstraints: bubbleExtraConstraints,
    outerPadding: outerPadding,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleShadows: bubbleShadows,
    combinedReactionCornerClearance: combinedReactionCornerClearance,
  ) = _resolveTimelineMessageBubbleLayout(
    context: context,
    currentItem: currentItem,
    previous: previous,
    next: next,
    self: self,
    isSelected: interactionData.isSelected,
    isSingleSelection: interactionData.isSingleSelection,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    hasAvatarSlot: hasAvatarSlot,
    avatarOuterInset: cutoutData.avatarOuterInset,
    avatarContentInset: cutoutData.avatarContentInset,
    bubbleMaxWidth: viewData.bubbleMaxWidth,
    inboundClampedBubbleWidth: inboundClampedBubbleWidth,
    outboundClampedBubbleWidth: outboundClampedBubbleWidth,
    messageRowMaxWidth: messageRowMaxWidth,
    bubbleTextChildren: bubbleContentData.bubbleTextChildren,
    bubbleExtraChildren: bubbleContentData.bubbleExtraChildren,
    reactions: interactionData.reactions,
    selectionOverlayVisible: cutoutData.selectionOverlayVisible,
    selectionOuterInset: cutoutData.selectionOuterInset,
    selectionBubbleVerticalInset: cutoutData.selectionBubbleVerticalInset,
    selectionBubbleInboundSpacing: cutoutData.selectionBubbleInboundSpacing,
    selectionBubbleOutboundSpacing: cutoutData.selectionBubbleOutboundSpacing,
    reactionBubbleInset: cutoutData.reactionBubbleInset,
    reactionCutoutDepth: cutoutData.reactionCutoutDepth,
    reactionCutoutMinThickness: cutoutData.reactionCutoutMinThickness,
    reactionCutoutPadding: cutoutData.reactionCutoutPadding,
    reactionCornerClearance: cutoutData.reactionCornerClearance,
    recipientBubbleInset: cutoutData.recipientBubbleInset,
    recipientCutoutDepth: cutoutData.recipientCutoutDepth,
  );
  final (
    bubbleContent: bubbleContent,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
  ) = _resolveTimelineMessageBubbleContent(
    context: context,
    bubbleTextChildren: bubbleContentData.bubbleTextChildren,
    bubblePadding: bubblePadding,
    bubbleTextConstraints: bubbleTextConstraints,
    showCompactReactions: interactionData.showCompactReactions,
    showReplyStrip: interactionData.showReplyStrip,
    showRecipientCutout: interactionData.showRecipientCutout,
    reactionCutoutDepth: cutoutData.reactionCutoutDepth,
    recipientCutoutDepth: cutoutData.recipientCutoutDepth,
    bubbleColor: viewData.bubbleColor,
    borderColor: viewData.borderColor,
  );
  final bubble = _ChatTimelineBubbleView(
    self: self,
    isSelected: interactionData.isSelected,
    showBubbleSurface: showBubbleSurface,
    bubbleSurfaceColor: bubbleSurfaceColor,
    bubbleSurfaceBorder: bubbleSurfaceBorder,
    bubbleBorderRadius: bubbleBorderRadius,
    bubbleShadows: bubbleShadows,
    cornerClearance: combinedReactionCornerClearance,
    body: bubbleContent,
    textConstraints: bubbleTextConstraints,
    reactionOverlay: cutoutData.reactionOverlay,
    reactionStyle: cutoutData.reactionStyle,
    recipientOverlay: cutoutData.recipientOverlay,
    recipientStyle: cutoutData.recipientStyle,
    recipientAnchor: cutoutData.recipientAnchor,
    avatarOverlay: chainedPrevious ? null : cutoutData.avatarOverlay,
    avatarStyle: chainedPrevious ? null : cutoutData.avatarStyle,
    avatarAnchor: cutoutData.avatarAnchor,
    selectionOverlay: cutoutData.selectionOverlay,
    selectionStyle: cutoutData.selectionStyle,
  );
  return (
    bubble: bubble,
    outerPadding: outerPadding,
    bubbleMaxWidthForLayout: bubbleMaxWidthForLayout,
    bubbleBottomCutoutPadding: bubbleBottomCutoutPadding,
    bubbleExtraConstraints: bubbleExtraConstraints,
    bubbleShadows: bubbleShadows,
    hasAvatarSlot: hasAvatarSlot,
    avatarContentInset: cutoutData.avatarContentInset,
  );
}

({Widget? quotedPreview, Widget? forwardedPreview})
_resolveTimelineMessagePreviews({
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required RoomState? roomState,
  required String? selfNick,
  required String? resolvedDirectChatDisplayName,
  required String? currentUserId,
  required bool isGroupChat,
  required bool self,
  required AppLocalizations l10n,
}) {
  final quotedPreview = _timelineQuotedPreview(
    quotedMessage: timelineMessageItem.quotedMessage,
    isGroupChat: isGroupChat,
    roomState: roomState,
    fallbackSelfNick: selfNick,
    currentUserId: currentUserId,
    chatDisplayName: resolvedDirectChatDisplayName,
    l10n: l10n,
    isSelfBubble: self,
  );
  final forwardedPreview = _timelineForwardedPreview(
    isForwarded: timelineMessageItem.isForwarded,
    forwardedFromJid: timelineMessageItem.forwardedFromJid,
    forwardedSubjectSenderLabel:
        timelineMessageItem.forwardedSubjectSenderLabel,
    fallbackSenderJid: messageModel.senderJid,
    fallbackIsSelf: self,
    isGroupChat: isGroupChat,
    roomState: roomState,
    currentUserId: currentUserId,
    l10n: l10n,
    isSelfBubble: self,
  );
  return (quotedPreview: quotedPreview, forwardedPreview: forwardedPreview);
}

({
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback onCopy,
  VoidCallback onShare,
  VoidCallback onAddToCalendar,
  VoidCallback onDetails,
  VoidCallback? onSelect,
  VoidCallback? onResend,
  VoidCallback? onEdit,
  VoidCallback? onPinToggle,
  VoidCallback? onImportantToggle,
  VoidCallback? onRevokeInvite,
  VoidCallback? onBubbleTap,
  VoidCallback onAddReaction,
  void Function(String emoji) onToggleReaction,
  bool canShowReactionManager,
  bool reactionManagerDisabled,
  bool importantDisabled,
  bool pinDisabled,
  bool pinLoading,
  bool replyLoading,
})
_resolveTimelineMessageActionCallbacks({
  required ChatTimelineMessageItem timelineMessageItem,
  required Message messageModel,
  required chat_models.Chat? chatEntity,
  required RoomState? roomState,
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
  final includeSelectAction = !multiSelectActive;
  final canRetry = messageStatus == MessageStatus.failed;
  final canShowReactionManager = canReact && isSingleSelection;
  final reactionManagerDisabled =
      canShowReactionManager && requiresMucReference;
  final pinDisabled = requiresMucReference && canTogglePins;
  final pinLoading = loadingMucReference && canTogglePins;
  final rowText = timelineMessageItem.rowText;

  VoidCallback? onReply;
  if (!requiresMucReference) {
    onReply = () => onReplyRequested(messageModel);
  }

  VoidCallback? onForward;
  if (!(isInviteMessage || inviteRevoked || isInviteRevocationMessage)) {
    onForward = () => unawaited(onForwardRequested(messageModel));
  }

  void onCopy() =>
      unawaited(onCopyRequested(fallbackText: rowText, model: messageModel));

  void onShare() =>
      unawaited(onShareRequested(fallbackText: rowText, model: messageModel));

  void onAddToCalendar() => unawaited(
    onAddToCalendarRequested(fallbackText: rowText, model: messageModel),
  );

  void onDetails() => onDetailsRequested(detailId);

  VoidCallback? onSelect;
  if (includeSelectAction) {
    onSelect = () => onStartMultiSelectRequested(messageModel);
  }

  VoidCallback? onResend;
  VoidCallback? onEdit;
  if (canRetry) {
    onResend = () => onResendRequested(messageModel, chat: chatEntity);
    onEdit = () => unawaited(onEditRequested(messageModel));
  }

  VoidCallback? onPinToggle;
  if (canTogglePins && !requiresMucReference) {
    onPinToggle = () => onPinToggleRequested(
      messageModel,
      pin: !isPinned,
      chat: chatEntity,
      roomState: roomState,
    );
  }

  VoidCallback? onImportantToggle;
  if (!requiresMucReference) {
    onImportantToggle = () => onImportantToggleRequested(
      messageModel,
      important: !isImportant,
      chat: chatEntity,
    );
  }

  VoidCallback? onRevokeInvite;
  if (isInviteMessage && self) {
    onRevokeInvite = () => onRevokeInviteRequested(
      messageModel,
      inviteeJidFallback: chatEntity?.jid,
    );
  }

  VoidCallback? onBubbleTap;
  if (!readOnly) {
    onBubbleTap = () => onBubbleTapRequested(
      messageModel,
      showUnreadIndicator: timelineMessageItem.showUnreadIndicator,
    );
  }

  void onAddReaction() => unawaited(onReactionSelectionRequested(messageModel));
  void onToggleReaction(String emoji) =>
      onToggleQuickReactionRequested(messageModel, emoji);

  return (
    onReply: onReply,
    onForward: onForward,
    onCopy: onCopy,
    onShare: onShare,
    onAddToCalendar: onAddToCalendar,
    onDetails: onDetails,
    onSelect: onSelect,
    onResend: onResend,
    onEdit: onEdit,
    onPinToggle: onPinToggle,
    onImportantToggle: onImportantToggle,
    onRevokeInvite: onRevokeInvite,
    onBubbleTap: onBubbleTap,
    onAddReaction: onAddReaction,
    onToggleReaction: onToggleReaction,
    canShowReactionManager: canShowReactionManager,
    reactionManagerDisabled: reactionManagerDisabled,
    importantDisabled: requiresMucReference,
    pinDisabled: pinDisabled,
    pinLoading: pinLoading,
    replyLoading: loadingMucReference,
  );
}
