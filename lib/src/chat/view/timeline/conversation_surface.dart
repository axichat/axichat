part of '../chat.dart';

class _ChatTimelineViewport extends StatelessWidget {
  const _ChatTimelineViewport({
    required this.loadingMessages,
    required this.messageListKey,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.messageList,
    required this.typingVisible,
    required this.typingAvatars,
    required this.typingAvatarPaths,
    required this.quotedMessage,
    required this.quotedSenderLabel,
    required this.quotedIsSelf,
    required this.onClearQuote,
    required this.overlayAnimationDuration,
    this.notices,
    this.banner,
  });

  final bool loadingMessages;
  final Key messageListKey;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final Widget messageList;
  final bool typingVisible;
  final List<String> typingAvatars;
  final Map<String, String> typingAvatarPaths;
  final Message? quotedMessage;
  final String? quotedSenderLabel;
  final bool quotedIsSelf;
  final VoidCallback onClearQuote;
  final Duration overlayAnimationDuration;
  final Widget? notices;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    if (loadingMessages) {
      return const Align(
        alignment: Alignment.center,
        child: AxiProgressIndicator(),
      );
    }
    final spacing = context.spacing;
    return KeyedSubtree(
      key: messageListKey,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        child: Stack(
          fit: StackFit.expand,
          children: [
            messageList,
            if (typingVisible)
              Positioned(
                left: 0,
                right: 0,
                bottom: spacing.s,
                child: IgnorePointer(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: spacing.s),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colorScheme.card,
                          borderRadius: BorderRadius.circular(
                            context.radii.pill,
                          ),
                          border: Border.all(color: context.colorScheme.border),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: spacing.m,
                            vertical: spacing.s,
                          ),
                          child: _TypingIndicatorPill(
                            participants: typingAvatars,
                            avatarPaths: typingAvatarPaths,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _ComposerBottomOverlay(
                quotedMessage: quotedMessage,
                quotedSenderLabel: quotedSenderLabel,
                quotedIsSelf: quotedIsSelf,
                onClearQuote: onClearQuote,
                notices: notices,
                banner: banner,
                animationDuration: overlayAnimationDuration,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatComposerBottomPane extends StatelessWidget {
  const _ChatComposerBottomPane({
    required this.maxHeight,
    required this.onSizeChange,
    required this.child,
  });

  final double maxHeight;
  final ValueChanged<Size> onSizeChange;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        primary: false,
        child: _SizeReportingWidget(onSizeChange: onSizeChange, child: child),
      ),
    );
  }
}

class _ChatMainConversationSection extends StatelessWidget {
  const _ChatMainConversationSection({
    required this.chatEntity,
    required this.state,
    required this.pinnedPanelVisible,
    required this.pinnedPanelMaxHeight,
    required this.accountJidForPins,
    required this.canTogglePins,
    required this.chatCalendarAvailable,
    required this.personalCalendarAvailable,
    required this.attachmentsBlockedForChat,
    required this.pinnedPreviewMessagePrefix,
    required this.isGroupChat,
    required this.isEmailChat,
    required this.currentUserId,
    required this.selfXmppJid,
    required this.selfUserId,
    required this.selfDisplayName,
    required this.selfAvatarPath,
    required this.myOccupantJid,
    required this.selfNick,
    required this.resolvedEmailSelfJid,
    required this.resolvedDirectChatDisplayName,
    required this.supportsMarkers,
    required this.supportsReceipts,
    required this.messageById,
    required this.shareContexts,
    required this.shareReplies,
    required this.revokedInviteTokens,
    required this.availabilityCoordinator,
    required this.availabilityShareOwnersById,
    required this.availabilityActorId,
    required this.availableWidth,
    required this.inboundMessageRowMaxWidth,
    required this.outboundMessageRowMaxWidth,
    required this.inboundClampedBubbleWidth,
    required this.outboundClampedBubbleWidth,
    required this.messageRowMaxWidth,
    required this.selectionExtrasPreferredMaxWidth,
    required this.readOnly,
    required this.isWelcomeChat,
    required this.multiSelectActive,
    required this.selectedMessageId,
    required this.normalizedXmppSelfJid,
    required this.normalizedEmailSelfJid,
    required this.messageFontSize,
    required this.loadingMessages,
    required this.mainTimelineItems,
    required this.messageListOptions,
    required this.typingVisible,
    required this.typingAvatars,
    required this.typingAvatarPaths,
    required this.overlayQuotedMessage,
    required this.overlayQuotedSenderLabel,
    required this.overlayQuotedIsSelf,
    required this.overlayNotices,
    required this.composerOverlayBanner,
    required this.overlayAnimationDuration,
    required this.bottomPaneMaxHeight,
    required this.onBottomPaneSizeChange,
    required this.bottomContent,
    required this.shareRequestStatus,
    required this.bubbleRegionRegistry,
    required this.selectionTapRegionGroup,
    required this.messageKeys,
    required this.bubbleWidthByMessageId,
    required this.shouldAnimateMessage,
    required this.isPinnedMessage,
    required this.isImportantMessage,
    required this.onClosePinnedMessages,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.attachmentsForMessage,
    required this.reactionPreviewsForMessage,
    required this.participantsForBanner,
    required this.avatarPathForBareJid,
    required this.onMessageLinkTap,
    required this.messageListKey,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onClearQuote,
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
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.profileJid,
  });

  final chat_models.Chat? chatEntity;
  final ChatState state;
  final bool pinnedPanelVisible;
  final double pinnedPanelMaxHeight;
  final String? accountJidForPins;
  final bool canTogglePins;
  final bool chatCalendarAvailable;
  final bool personalCalendarAvailable;
  final bool attachmentsBlockedForChat;
  final String pinnedPreviewMessagePrefix;
  final bool isGroupChat;
  final bool isEmailChat;
  final String? currentUserId;
  final String? selfXmppJid;
  final String selfUserId;
  final String selfDisplayName;
  final String? selfAvatarPath;
  final String? myOccupantJid;
  final String? selfNick;
  final String? resolvedEmailSelfJid;
  final String? resolvedDirectChatDisplayName;
  final bool supportsMarkers;
  final bool supportsReceipts;
  final Map<String, Message> messageById;
  final Map<String, ShareContext> shareContexts;
  final Map<String, List<chat_models.Chat>> shareReplies;
  final Set<String> revokedInviteTokens;
  final CalendarAvailabilityShareCoordinator? availabilityCoordinator;
  final Map<String, String> availabilityShareOwnersById;
  final String? availabilityActorId;
  final double availableWidth;
  final double inboundMessageRowMaxWidth;
  final double outboundMessageRowMaxWidth;
  final double inboundClampedBubbleWidth;
  final double outboundClampedBubbleWidth;
  final double messageRowMaxWidth;
  final double selectionExtrasPreferredMaxWidth;
  final bool readOnly;
  final bool isWelcomeChat;
  final bool multiSelectActive;
  final String? selectedMessageId;
  final String? normalizedXmppSelfJid;
  final String? normalizedEmailSelfJid;
  final double messageFontSize;
  final bool loadingMessages;
  final List<ChatTimelineItem> mainTimelineItems;
  final MessageListOptions messageListOptions;
  final bool typingVisible;
  final List<String> typingAvatars;
  final Map<String, String> typingAvatarPaths;
  final Message? overlayQuotedMessage;
  final String? overlayQuotedSenderLabel;
  final bool overlayQuotedIsSelf;
  final Widget? overlayNotices;
  final Widget? composerOverlayBanner;
  final Duration overlayAnimationDuration;
  final double bottomPaneMaxHeight;
  final ValueChanged<Size> onBottomPaneSizeChange;
  final Widget bottomContent;
  final RequestStatus shareRequestStatus;
  final _BubbleRegionRegistry bubbleRegionRegistry;
  final Object selectionTapRegionGroup;
  final Map<String, GlobalKey> messageKeys;
  final Map<String, double> bubbleWidthByMessageId;
  final bool Function(Message message) shouldAnimateMessage;
  final bool Function(Message message) isPinnedMessage;
  final bool Function(Message message) isImportantMessage;
  final VoidCallback onClosePinnedMessages;
  final FileMetadataData? Function(String metadataId) metadataFor;
  final bool Function(String metadataId) metadataPendingFor;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final List<String> Function(Message message) attachmentsForMessage;
  final List<ReactionPreview> Function(Message message)
  reactionPreviewsForMessage;
  final List<chat_models.Chat> Function(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  )
  participantsForBanner;
  final String? Function(String bareJid) avatarPathForBareJid;
  final ValueChanged<String> onMessageLinkTap;
  final Key messageListKey;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final VoidCallback onClearQuote;
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
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final String? profileJid;

  @override
  Widget build(BuildContext context) {
    return _ChatConversationPane(
      pinnedPanel: _ChatPinnedPanelSection(
        chatEntity: chatEntity,
        visible: pinnedPanelVisible,
        maxHeight: pinnedPanelMaxHeight,
        accountJid: accountJidForPins,
        pinnedMessages: state.pinnedMessages,
        pinnedMessagesLoaded: state.pinnedMessagesLoaded,
        pinnedMessagesHydrating: state.pinnedMessagesHydrating,
        onClose: onClosePinnedMessages,
        canTogglePins: canTogglePins,
        canShowCalendarTasks: chatCalendarAvailable,
        canAddToPersonalCalendar: personalCalendarAvailable,
        canAddToChatCalendar: chatCalendarAvailable,
        onCopyTaskToPersonalCalendar: onCopyTaskToPersonalCalendar,
        onCopyCriticalPathToPersonalCalendar:
            onCopyCriticalPathToPersonalCalendar,
        roomState: state.roomState,
        metadataFor: metadataFor,
        metadataPendingFor: metadataPendingFor,
        attachmentsBlocked: attachmentsBlockedForChat,
        isOneTimeAttachmentAllowed: isOneTimeAttachmentAllowed,
        shouldAllowAttachment: shouldAllowAttachment,
        onApproveAttachment: onApproveAttachment,
        previewMessageIdPrefix: pinnedPreviewMessagePrefix,
        isGroupChat: isGroupChat,
        isEmailChat: isEmailChat,
        resolvedEmailSelfJid: resolvedEmailSelfJid,
        currentUserId: currentUserId,
        selfUserId: selfUserId,
        selfDisplayName: selfDisplayName,
        selfAvatarPath: selfAvatarPath,
        myOccupantJid: myOccupantJid,
        selfNick: selfNick,
        roomMemberSections: state.roomMemberSections,
        chat: state.chat,
        messageById: messageById,
        shareContexts: shareContexts,
        shareReplies: shareReplies,
        emailFullHtmlByDeltaId: state.emailFullHtmlByDeltaId,
        emailQuotedTextByDeltaId: state.emailQuotedTextByDeltaId,
        revokedInviteTokens: revokedInviteTokens,
        supportsMarkers: supportsMarkers,
        supportsReceipts: supportsReceipts,
        attachmentsForMessage: attachmentsForMessage,
        reactionPreviewsForMessage: reactionPreviewsForMessage,
        participantsForBanner: participantsForBanner,
        avatarPathForBareJid: avatarPathForBareJid,
        ownerJidForShare: (shareId) =>
            availabilityShareOwnersById[shareId] ??
            availabilityCoordinator?.ownerJidForShare(shareId),
        profileJid: context.read<ProfileCubit>().state.jid,
        onMessageLinkTap: onMessageLinkTap,
      ),
      timelineViewport: _ChatTimelineViewport(
        loadingMessages: loadingMessages,
        messageListKey: messageListKey,
        onPointerMove: onPointerMove,
        onPointerUp: onPointerUp,
        onPointerCancel: onPointerCancel,
        messageList: _ChatMainTimelineList(
          items: mainTimelineItems,
          messageListOptions: messageListOptions,
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
        typingVisible: typingVisible,
        typingAvatars: typingAvatars,
        typingAvatarPaths: typingAvatarPaths,
        quotedMessage: overlayQuotedMessage,
        quotedSenderLabel: overlayQuotedSenderLabel,
        quotedIsSelf: overlayQuotedIsSelf,
        onClearQuote: onClearQuote,
        notices: overlayNotices,
        banner: composerOverlayBanner,
        overlayAnimationDuration: overlayAnimationDuration,
      ),
      bottomPane: _ChatComposerBottomPane(
        maxHeight: bottomPaneMaxHeight,
        onSizeChange: onBottomPaneSizeChange,
        child: bottomContent,
      ),
    );
  }
}

class _ChatPinnedPanelSection extends StatelessWidget {
  const _ChatPinnedPanelSection({
    required this.chatEntity,
    required this.visible,
    required this.maxHeight,
    required this.accountJid,
    required this.pinnedMessages,
    required this.pinnedMessagesLoaded,
    required this.pinnedMessagesHydrating,
    required this.onClose,
    required this.canTogglePins,
    required this.canShowCalendarTasks,
    required this.canAddToPersonalCalendar,
    required this.canAddToChatCalendar,
    required this.onCopyTaskToPersonalCalendar,
    required this.onCopyCriticalPathToPersonalCalendar,
    required this.roomState,
    required this.metadataFor,
    required this.metadataPendingFor,
    required this.attachmentsBlocked,
    required this.isOneTimeAttachmentAllowed,
    required this.shouldAllowAttachment,
    required this.onApproveAttachment,
    required this.previewMessageIdPrefix,
    required this.isGroupChat,
    required this.isEmailChat,
    required this.resolvedEmailSelfJid,
    required this.currentUserId,
    required this.selfUserId,
    required this.selfDisplayName,
    required this.selfAvatarPath,
    required this.myOccupantJid,
    required this.selfNick,
    required this.roomMemberSections,
    required this.chat,
    required this.messageById,
    required this.shareContexts,
    required this.shareReplies,
    required this.emailFullHtmlByDeltaId,
    required this.emailQuotedTextByDeltaId,
    required this.revokedInviteTokens,
    required this.supportsMarkers,
    required this.supportsReceipts,
    required this.attachmentsForMessage,
    required this.reactionPreviewsForMessage,
    required this.participantsForBanner,
    required this.avatarPathForBareJid,
    required this.ownerJidForShare,
    required this.profileJid,
    required this.onMessageLinkTap,
  });

  final chat_models.Chat? chatEntity;
  final bool visible;
  final double maxHeight;
  final String? accountJid;
  final List<PinnedMessageItem> pinnedMessages;
  final bool pinnedMessagesLoaded;
  final bool pinnedMessagesHydrating;
  final VoidCallback onClose;
  final bool canTogglePins;
  final bool canShowCalendarTasks;
  final bool canAddToPersonalCalendar;
  final bool canAddToChatCalendar;
  final Future<String?> Function(CalendarTask task)?
  onCopyTaskToPersonalCalendar;
  final Future<bool> Function(
    CalendarModel model,
    String pathId,
    Set<String> taskIds,
  )?
  onCopyCriticalPathToPersonalCalendar;
  final RoomState? roomState;
  final FileMetadataData? Function(String metadataId) metadataFor;
  final bool Function(String metadataId) metadataPendingFor;
  final bool attachmentsBlocked;
  final bool Function(String stanzaId) isOneTimeAttachmentAllowed;
  final bool Function({required bool isSelf, required chat_models.Chat? chat})
  shouldAllowAttachment;
  final Future<void> Function({
    required Message message,
    required String senderJid,
    required String stanzaId,
    required bool isSelf,
    required bool isEmailChat,
    String? senderEmail,
  })
  onApproveAttachment;
  final String previewMessageIdPrefix;
  final bool isGroupChat;
  final bool isEmailChat;
  final String? resolvedEmailSelfJid;
  final String? currentUserId;
  final String selfUserId;
  final String selfDisplayName;
  final String? selfAvatarPath;
  final String? myOccupantJid;
  final String? selfNick;
  final List<RoomMemberSection> roomMemberSections;
  final chat_models.Chat? chat;
  final Map<String, Message> messageById;
  final Map<String, ShareContext> shareContexts;
  final Map<String, List<chat_models.Chat>> shareReplies;
  final Map<int, String> emailFullHtmlByDeltaId;
  final Map<int, String> emailQuotedTextByDeltaId;
  final Set<String> revokedInviteTokens;
  final bool supportsMarkers;
  final bool supportsReceipts;
  final List<String> Function(Message message) attachmentsForMessage;
  final List<ReactionPreview> Function(Message message)
  reactionPreviewsForMessage;
  final List<chat_models.Chat> Function(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  )
  participantsForBanner;
  final String? Function(String bareJid) avatarPathForBareJid;
  final String? Function(String shareId) ownerJidForShare;
  final String? profileJid;
  final ValueChanged<String> onMessageLinkTap;

  @override
  Widget build(BuildContext context) {
    final locate = context.read;
    final l10n = context.l10n;
    return _ChatPinnedMessagesPanel(
      key: ValueKey(
        '$_chatPinnedPanelKeyPrefix${chatEntity?.jid ?? _chatPanelKeyFallback}',
      ),
      chat: chatEntity,
      visible: visible,
      maxHeight: maxHeight,
      accountJid: accountJid,
      pinnedMessages: pinnedMessages,
      pinnedMessagesLoaded: pinnedMessagesLoaded,
      pinnedMessagesHydrating: pinnedMessagesHydrating,
      onClose: onClose,
      canTogglePins: canTogglePins,
      canShowCalendarTasks: canShowCalendarTasks,
      canAddToPersonalCalendar: canAddToPersonalCalendar,
      canAddToChatCalendar: canAddToChatCalendar,
      onCopyTaskToPersonalCalendar: onCopyTaskToPersonalCalendar,
      onCopyCriticalPathToPersonalCalendar:
          onCopyCriticalPathToPersonalCalendar,
      locate: locate,
      roomState: roomState,
      metadataFor: metadataFor,
      metadataPendingFor: metadataPendingFor,
      attachmentsBlocked: attachmentsBlocked,
      isOneTimeAttachmentAllowed: isOneTimeAttachmentAllowed,
      shouldAllowAttachment: shouldAllowAttachment,
      onApproveAttachment: onApproveAttachment,
      previewTimelineItemForItem: (item) {
        final message = item.message;
        if (message == null) {
          return null;
        }
        return buildPreviewChatTimelineMessageItem(
          message: message,
          messageIdPrefix: previewMessageIdPrefix,
          shownSubjectShares: <String>{},
          isGroupChat: isGroupChat,
          isEmailChat: isEmailChat,
          profileJid: profileJid,
          resolvedEmailSelfJid: resolvedEmailSelfJid,
          currentUserId: currentUserId,
          selfUserId: selfUserId,
          selfDisplayName: selfDisplayName,
          selfAvatarPath: selfAvatarPath,
          myOccupantJid: myOccupantJid,
          selfNick: selfNick,
          roomState: roomState,
          roomMemberSections: roomMemberSections,
          chat: chat,
          messageById: messageById,
          shareContexts: shareContexts,
          shareReplies: shareReplies,
          emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
          revokedInviteTokens: revokedInviteTokens,
          inviteRoomFallbackLabel: l10n.chatInviteRoomFallbackLabel,
          inviteBodyLabel: l10n.chatInviteBodyLabel,
          inviteRevokedBodyLabel: l10n.chatInviteRevokedLabel,
          unknownAuthorLabel: l10n.commonUnknownLabel,
          inviteActionLabel: l10n.chatInviteActionLabel,
          supportsMarkers: supportsMarkers,
          supportsReceipts: supportsReceipts,
          attachmentsForMessage: attachmentsForMessage,
          reactionPreviewsForMessage: reactionPreviewsForMessage,
          participantsForBanner: participantsForBanner,
          avatarPathForBareJid: avatarPathForBareJid,
          ownerJidForShare: ownerJidForShare,
          errorLabel: (error) => error.label(l10n),
          errorLabelWithBody: (error, body) =>
              l10n.chatMessageErrorWithBody(error.label(l10n), body),
        );
      },
      resolvedHtmlBodyFor: (message) {
        final deltaMessageId = message.deltaMsgId;
        if (deltaMessageId == null) {
          return message.htmlBody;
        }
        return emailFullHtmlByDeltaId[deltaMessageId] ?? message.htmlBody;
      },
      resolvedQuotedTextFor: (message) {
        final deltaMessageId = message.deltaMsgId;
        if (deltaMessageId == null) {
          return null;
        }
        return emailQuotedTextByDeltaId[deltaMessageId];
      },
      onMessageLinkTap: onMessageLinkTap,
    );
  }
}
