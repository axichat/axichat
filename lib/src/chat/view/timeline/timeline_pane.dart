part of '../chat.dart';

class _ChatConversationPane extends StatelessWidget {
  const _ChatConversationPane({
    required this.pinnedPanel,
    required this.timelineViewport,
    required this.bottomPane,
  });

  final Widget pinnedPanel;
  final Widget timelineViewport;
  final Widget bottomPane;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        pinnedPanel,
        Expanded(child: timelineViewport),
        bottomPane,
      ],
    );
  }
}

class _ChatMainTimelineList extends StatelessWidget {
  const _ChatMainTimelineList({
    required this.items,
    required this.messageListOptions,
    required this.state,
    required this.chatEntity,
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
    required this.overlayQuotedMessage,
    required this.overlayQuotedSenderLabel,
    required this.overlayQuotedIsSelf,
    required this.overlayNotices,
    required this.composerOverlayBanner,
    required this.overlayAnimationDuration,
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

  final List<ChatTimelineItem> items;
  final MessageListOptions messageListOptions;
  final ChatState state;
  final chat_models.Chat? chatEntity;
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
  final Message? overlayQuotedMessage;
  final String? overlayQuotedSenderLabel;
  final bool overlayQuotedIsSelf;
  final Widget? overlayNotices;
  final Widget? composerOverlayBanner;
  final Duration overlayAnimationDuration;
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
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeRight: true,
      child: _ChatMessageList(
        items: items,
        scrollToBottomOptions: const ScrollToBottomOptions(),
        itemBuilder: (currentItem, previous, next) => _ChatTimelineItemView(
          currentItem: currentItem,
          previous: previous,
          next: next,
          state: state,
          chatEntity: chatEntity,
          currentUserId: currentUserId,
          selfNick: selfNick,
          selfXmppJid: selfXmppJid,
          myOccupantJid: myOccupantJid,
          resolvedDirectChatDisplayName: resolvedDirectChatDisplayName,
          readOnly: readOnly,
          isGroupChat: isGroupChat,
          isEmailChat: isEmailChat,
          isWelcomeChat: isWelcomeChat,
          attachmentsBlockedForChat: attachmentsBlockedForChat,
          multiSelectActive: multiSelectActive,
          selectedMessageId: selectedMessageId,
          canTogglePins: canTogglePins,
          availabilityActorId: availabilityActorId,
          availabilityShareOwnersById: availabilityShareOwnersById,
          availabilityCoordinator: availabilityCoordinator,
          normalizedXmppSelfJid: normalizedXmppSelfJid,
          normalizedEmailSelfJid: normalizedEmailSelfJid,
          personalCalendarAvailable: personalCalendarAvailable,
          chatCalendarAvailable: chatCalendarAvailable,
          messageFontSize: messageFontSize,
          availableWidth: availableWidth,
          inboundMessageRowMaxWidth: inboundMessageRowMaxWidth,
          outboundMessageRowMaxWidth: outboundMessageRowMaxWidth,
          inboundClampedBubbleWidth: inboundClampedBubbleWidth,
          outboundClampedBubbleWidth: outboundClampedBubbleWidth,
          messageRowMaxWidth: messageRowMaxWidth,
          selectionExtrasPreferredMaxWidth: selectionExtrasPreferredMaxWidth,
          overlayQuotedMessage: overlayQuotedMessage,
          overlayQuotedSenderLabel: overlayQuotedSenderLabel,
          overlayQuotedIsSelf: overlayQuotedIsSelf,
          overlayNotices: overlayNotices,
          composerOverlayBanner: composerOverlayBanner,
          overlayAnimationDuration: overlayAnimationDuration,
          shareRequestStatus: shareRequestStatus,
          bubbleRegionRegistry: bubbleRegionRegistry,
          selectionTapRegionGroup: selectionTapRegionGroup,
          messageKeys: messageKeys,
          bubbleWidthByMessageId: bubbleWidthByMessageId,
          shouldAnimateMessage: shouldAnimateMessage,
          isPinnedMessage: isPinnedMessage,
          isImportantMessage: isImportantMessage,
          onTapOutsideRequested: onTapOutsideRequested,
          resolveViewData: resolveViewData,
          resolveInteractionData: resolveInteractionData,
          composeBubbleContent: composeBubbleContent,
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
        ),
        messageListOptions: messageListOptions,
        readOnly: true,
      ),
    );
  }
}
