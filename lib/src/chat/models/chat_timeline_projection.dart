// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/email/models/fan_out_models.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;

({String? subject, String body}) displaySubjectAndBody(
  Message message, {
  required bool isEmailMessage,
}) {
  if (isEmailMessage) {
    return ChatSubjectCodec.splitEmailBody(
      body: message.body,
      subject: message.subject,
    );
  }
  return ChatSubjectCodec.splitDisplayBody(
    body: message.body,
    subject: message.subject,
  );
}

String? previewTextForMessage(Message message) {
  if (message.isEmailBacked) {
    return ChatSubjectCodec.previewEmailText(
      body: message.body,
      subject: message.subject,
    );
  }
  return ChatSubjectCodec.previewText(
    body: message.body,
    subject: message.subject,
  );
}

bool isMucSelfMessage({
  required String senderJid,
  required RoomState? roomState,
  required String? fallbackSelfNick,
}) {
  if (roomState != null) {
    return roomState.isSelfSenderJid(
      senderJid,
      fallbackSelfNick: fallbackSelfNick,
    );
  }
  final trimmedSelfNick = fallbackSelfNick?.trim();
  if (trimmedSelfNick == null || trimmedSelfNick.isEmpty) {
    return false;
  }
  final senderNick = addressResourcePart(senderJid)?.trim();
  if (senderNick == null || senderNick.isEmpty) {
    return false;
  }
  return senderNick == trimmedSelfNick;
}

bool isEmailMessageForBubble({
  required Message? message,
  required bool isEmailChat,
  bool hasEmailMessageFlag = false,
}) {
  if (isEmailChat || hasEmailMessageFlag) {
    return true;
  }
  if (message == null) {
    return false;
  }
  return message.isEmailBacked;
}

bool looksForwardedMessage({
  required Message message,
  required String bodyText,
  String? subjectLabel,
}) {
  if (message.isForwarded) {
    return true;
  }
  final normalizedSubject = subjectLabel?.trim().toLowerCase() ?? '';
  if (normalizedSubject.startsWith('fwd:') ||
      normalizedSubject.startsWith('fw:')) {
    return true;
  }
  final normalizedBody = bodyText.trimLeft().toLowerCase();
  return normalizedBody.startsWith('fwd:') ||
      normalizedBody.startsWith('fw:') ||
      normalizedBody.startsWith('-------- forwarded message --------');
}

Occupant? resolveRoomMessageOccupant({
  required Message message,
  required RoomState roomState,
}) => roomState.occupantForSenderJid(message.senderJid, preferRealJid: true);

RoomMemberEntry? resolveRoomMemberEntryForMessage({
  required Message message,
  required List<RoomMemberSection> sections,
}) {
  final senderJid = message.senderJid.trim();
  final senderNick = addressResourcePart(senderJid)?.trim();
  RoomMemberEntry? fallback;
  for (final section in sections) {
    for (final member in section.members) {
      if (member.occupant.occupantId == senderJid ||
          sameFullAddress(member.occupant.occupantId, senderJid)) {
        return member;
      }
      if (fallback == null &&
          senderNick != null &&
          senderNick.isNotEmpty &&
          _sameOccupantNick(member.occupant.nick, senderNick)) {
        fallback = member;
      }
    }
  }
  return fallback;
}

({
  String authorId,
  String authorDisplayName,
  String authorAvatarKey,
  String? authorAvatarPath,
  bool isSelf,
})
resolveMainChatTimelineMessageAuthor({
  required Message message,
  required bool isGroupChat,
  required String? profileJid,
  required String? resolvedEmailSelfJid,
  required String selfUserId,
  required String selfDisplayName,
  required String? selfAvatarPath,
  required String? selfNick,
  required RoomState? roomState,
  required List<RoomMemberSection> roomMemberSections,
  required chat_models.Chat? chat,
  required String unknownLabel,
  required String? Function(String jid) avatarPathForBareJid,
}) {
  final senderBare = bareAddress(message.senderJid);
  final normalizedSenderBare = normalizedAddressKey(message.senderJid);
  final isSelfXmpp =
      senderBare != null && senderBare == bareAddress(profileJid);
  final isSelfEmail =
      senderBare != null &&
      resolvedEmailSelfJid != null &&
      senderBare == bareAddress(resolvedEmailSelfJid);
  final isDeltaPlaceholderSender =
      normalizedSenderBare != null &&
      normalizedSenderBare.isDeltaPlaceholderJid;
  final isMucSelf =
      isGroupChat &&
      isMucSelfMessage(
        senderJid: message.senderJid,
        roomState: roomState,
        fallbackSelfNick: selfNick,
      );
  final isSelf =
      isSelfXmpp || isSelfEmail || isMucSelf || isDeltaPlaceholderSender;
  final occupant = !isGroupChat || roomState == null
      ? null
      : resolveRoomMessageOccupant(message: message, roomState: roomState);
  final fallbackNick = isGroupChat
      ? roomState?.senderNick(message.senderJid) ?? chat?.title ?? ''
      : chat?.title ?? '';
  final authorDisplayName = isSelf
      ? selfDisplayName
      : (occupant?.nick ?? fallbackNick);
  final authorId = isSelf ? selfUserId : message.senderJid;
  if (!isGroupChat) {
    return (
      authorId: authorId,
      authorDisplayName: authorDisplayName,
      authorAvatarKey: authorId,
      authorAvatarPath: null,
      isSelf: isSelf,
    );
  }
  final messageMemberEntry = resolveRoomMemberEntryForMessage(
    message: message,
    sections: roomMemberSections,
  );
  final avatarOccupant = messageMemberEntry?.occupant ?? occupant;
  String? authorAvatarPath;
  if (isSelf) {
    final trimmedSelfAvatarPath = selfAvatarPath?.trim();
    if (trimmedSelfAvatarPath != null && trimmedSelfAvatarPath.isNotEmpty) {
      authorAvatarPath = trimmedSelfAvatarPath;
    }
  } else {
    final memberAvatarPath = messageMemberEntry?.avatarPath?.trim();
    if (memberAvatarPath != null && memberAvatarPath.isNotEmpty) {
      authorAvatarPath = memberAvatarPath;
    } else {
      final occupantRealJid = avatarOccupant?.realJid?.trim();
      if (occupantRealJid != null && occupantRealJid.isNotEmpty) {
        final bareRealJid = bareAddress(occupantRealJid) ?? occupantRealJid;
        final resolvedAvatarPath = avatarPathForBareJid(bareRealJid)?.trim();
        if (resolvedAvatarPath != null && resolvedAvatarPath.isNotEmpty) {
          authorAvatarPath = resolvedAvatarPath;
        }
      }
    }
  }
  final authorAvatarKey = authorAvatarPath != null && avatarOccupant != null
      ? avatarOccupant.avatarKey
      : _resolveTimelineMessageAvatarKey(
          message: message,
          occupant: avatarOccupant,
          unknownLabel: unknownLabel,
        );
  return (
    authorId: authorId,
    authorDisplayName: authorDisplayName,
    authorAvatarKey: authorAvatarKey,
    authorAvatarPath: authorAvatarPath,
    isSelf: isSelf,
  );
}

List<ChatTimelineItem> buildMainChatTimelineItems({
  required List<Message> messages,
  required bool loadingMessages,
  required String? unreadBoundaryStanzaId,
  required DateTime emptyStateCreatedAt,
  required String unreadDividerItemId,
  required String unreadDividerLabel,
  required String emptyStateItemId,
  required String emptyStateLabel,
  required bool isGroupChat,
  required bool isEmailChat,
  required String? profileJid,
  required String? resolvedEmailSelfJid,
  required String? currentUserId,
  required String selfUserId,
  required String selfDisplayName,
  required String? selfAvatarPath,
  required String? myOccupantJid,
  required String? selfNick,
  required RoomState? roomState,
  required List<RoomMemberSection> roomMemberSections,
  required chat_models.Chat? chat,
  required Map<String, Message> messageById,
  required Map<String, ShareContext> shareContexts,
  required Map<String, List<chat_models.Chat>> shareReplies,
  required Map<int, String> emailFullHtmlByDeltaId,
  required Set<String> revokedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String unknownAuthorLabel,
  required String Function(String roomDisplayName) inviteActionLabel,
  required bool supportsMarkers,
  required bool supportsReceipts,
  required List<String> Function(Message message) attachmentsForMessage,
  required List<ReactionPreview> Function(Message message)
  reactionPreviewsForMessage,
  required List<chat_models.Chat> Function(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  )
  participantsForBanner,
  required String? Function(String jid) avatarPathForBareJid,
  required String? Function(String shareId) ownerJidForShare,
  required String Function(MessageError error) errorLabel,
  required String Function(MessageError error, String body) errorLabelWithBody,
}) {
  final timelineItems = <ChatTimelineItem>[];
  final shownSubjectShares = <String>{};
  var unreadDividerInserted = false;
  for (final message in messages) {
    final timelineItem = buildMainChatTimelineMessageItem(
      message: message,
      shownSubjectShares: shownSubjectShares,
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
      inviteRoomFallbackLabel: inviteRoomFallbackLabel,
      inviteBodyLabel: inviteBodyLabel,
      inviteRevokedBodyLabel: inviteRevokedBodyLabel,
      unknownAuthorLabel: unknownAuthorLabel,
      inviteActionLabel: inviteActionLabel,
      supportsMarkers: supportsMarkers,
      supportsReceipts: supportsReceipts,
      attachmentsForMessage: attachmentsForMessage,
      reactionPreviewsForMessage: reactionPreviewsForMessage,
      participantsForBanner: participantsForBanner,
      avatarPathForBareJid: avatarPathForBareJid,
      ownerJidForShare: ownerJidForShare,
      errorLabel: errorLabel,
      errorLabelWithBody: errorLabelWithBody,
    );
    if (timelineItem == null) {
      continue;
    }
    timelineItems.add(timelineItem);
    if (!unreadDividerInserted &&
        unreadBoundaryStanzaId != null &&
        message.stanzaID == unreadBoundaryStanzaId) {
      unreadDividerInserted = true;
      timelineItems.add(
        ChatTimelineUnreadDividerItem(
          id: unreadDividerItemId,
          createdAt: timelineItem.createdAt,
          label: unreadDividerLabel,
        ),
      );
    }
  }
  if (!loadingMessages && messages.isEmpty) {
    timelineItems.add(
      ChatTimelineEmptyStateItem(
        id: emptyStateItemId,
        createdAt: emptyStateCreatedAt,
        label: emptyStateLabel,
      ),
    );
  }
  return List<ChatTimelineItem>.unmodifiable(timelineItems);
}

ChatTimelineMessageItem? buildMainChatTimelineMessageItem({
  required Message message,
  required Set<String> shownSubjectShares,
  required bool isGroupChat,
  required bool isEmailChat,
  required String? profileJid,
  required String? resolvedEmailSelfJid,
  required String? currentUserId,
  required String selfUserId,
  required String selfDisplayName,
  required String? selfAvatarPath,
  required String? myOccupantJid,
  required String? selfNick,
  required RoomState? roomState,
  required List<RoomMemberSection> roomMemberSections,
  required chat_models.Chat? chat,
  required Map<String, Message> messageById,
  required Map<String, ShareContext> shareContexts,
  required Map<String, List<chat_models.Chat>> shareReplies,
  required Map<int, String> emailFullHtmlByDeltaId,
  required Set<String> revokedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String unknownAuthorLabel,
  required String Function(String roomDisplayName) inviteActionLabel,
  required bool supportsMarkers,
  required bool supportsReceipts,
  required List<String> Function(Message message) attachmentsForMessage,
  required List<ReactionPreview> Function(Message message)
  reactionPreviewsForMessage,
  required List<chat_models.Chat> Function(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  )
  participantsForBanner,
  required String? Function(String jid) avatarPathForBareJid,
  required String? Function(String shareId) ownerJidForShare,
  required String Function(MessageError error) errorLabel,
  required String Function(MessageError error, String body) errorLabelWithBody,
}) {
  final timestamp = message.timestamp;
  if (timestamp == null) {
    return null;
  }
  final author = resolveMainChatTimelineMessageAuthor(
    message: message,
    isGroupChat: isGroupChat,
    profileJid: profileJid,
    resolvedEmailSelfJid: resolvedEmailSelfJid,
    selfUserId: selfUserId,
    selfDisplayName: selfDisplayName,
    selfAvatarPath: selfAvatarPath,
    selfNick: selfNick,
    roomState: roomState,
    roomMemberSections: roomMemberSections,
    chat: chat,
    unknownLabel: unknownAuthorLabel,
    avatarPathForBareJid: avatarPathForBareJid,
  );
  final isSelf = author.isSelf;
  final isEmailMessage = isEmailMessageForBubble(
    message: message,
    isEmailChat: isEmailChat,
  );
  final unreadSelfJid = isEmailMessage ? resolvedEmailSelfJid : currentUserId;
  final showUnreadIndicator =
      isEmailMessage &&
      !message.displayed &&
      message.countsTowardUnread(
        selfJid: unreadSelfJid,
        isGroupChat: isGroupChat,
        myOccupantJid: myOccupantJid,
      );
  final quotedMessage = message.quoting == null
      ? null
      : messageById[message.quoting!];
  final shareContext = shareContexts[message.stanzaID];
  final bannerParticipants = List<chat_models.Chat>.of(
    participantsForBanner(shareContext, chat?.jid, currentUserId),
  );
  bool showSubjectHeader = false;
  String? subjectLabel;
  String bodyText = message.body ?? '';
  final inviteToken = message.pseudoMessageData?['token'] as String?;
  final inviteRoom = message.pseudoMessageData?['roomJid'] as String?;
  final inviteRoomName = (message.pseudoMessageData?['roomName'] as String?)
      ?.trim();
  final isInvite = message.pseudoMessageType == PseudoMessageType.mucInvite;
  final isInviteRevocation =
      message.pseudoMessageType == PseudoMessageType.mucInviteRevocation;
  final inviteRoomDisplayName = inviteRoomName?.isNotEmpty == true
      ? inviteRoomName!
      : inviteRoomFallbackLabel;
  final inviteLabel = isInvite ? inviteBodyLabel : inviteRevokedBodyLabel;
  final inviteAction = inviteActionLabel(inviteRoomDisplayName);
  final inviteRevoked =
      inviteToken != null && revokedInviteTokens.contains(inviteToken);
  if (shareContext?.subject?.trim().isNotEmpty == true) {
    subjectLabel = shareContext!.subject!.trim();
    if (shownSubjectShares.add(shareContext.shareId)) {
      showSubjectHeader = true;
    }
  } else {
    final split = displaySubjectAndBody(
      message,
      isEmailMessage: isEmailMessage,
    );
    subjectLabel = split.subject;
    bodyText = split.body;
  }
  final rawSubjectLabel = subjectLabel;
  final rawBodyText = bodyText;
  final deltaMessageId = message.deltaMsgId;
  final resolvedForwardHtml = deltaMessageId == null
      ? message.htmlBody
      : emailFullHtmlByDeltaId[deltaMessageId] ?? message.htmlBody;
  final forwardedSubjectSenderLabel = syntheticForwardDisplaySenderLabel(
    subjectLabel: rawSubjectLabel,
    emailMarkerPresent:
        isEmailMessage &&
        hasSyntheticForwardHtmlMarker(html: resolvedForwardHtml),
  );
  if (forwardedSubjectSenderLabel != null) {
    final forwardedContent = splitSyntheticForwardBody(bodyText);
    subjectLabel = forwardedContent.subject;
    bodyText = forwardedContent.body;
    showSubjectHeader = subjectLabel?.trim().isNotEmpty == true;
  }
  if (isEmailMessage) {
    final trimmedSubject = subjectLabel?.trim();
    if (trimmedSubject?.isNotEmpty == true) {
      bodyText = ChatSubjectCodec.stripRepeatedSubject(
        body: bodyText,
        subject: trimmedSubject!,
      );
    }
    bodyText = ChatSubjectCodec.previewBodyText(bodyText);
  }
  if (!showSubjectHeader &&
      shareContext == null &&
      subjectLabel?.isNotEmpty == true) {
    showSubjectHeader = true;
  }
  final subjectText = subjectLabel?.trim() ?? '';
  final bodyTextTrimmed = bodyText.trim();
  final isForwardedMessage =
      forwardedSubjectSenderLabel != null ||
      looksForwardedMessage(
        message: message,
        bodyText: rawBodyText,
        subjectLabel: rawSubjectLabel,
      );
  final isSubjectOnlyBody =
      showSubjectHeader &&
      subjectText.isNotEmpty &&
      bodyTextTrimmed == subjectText;
  final displayedBody = isSubjectOnlyBody ? '' : bodyText;
  final shouldReplaceInviteBody = isInvite || isInviteRevocation;
  final renderedText = shouldReplaceInviteBody
      ? inviteLabel
      : message.error.isNotNone
      ? bodyText.isNotEmpty
            ? errorLabelWithBody(message.error, bodyTextTrimmed)
            : errorLabel(message.error)
      : displayedBody;
  final attachmentIds = attachmentsForMessage(message);
  final hasAttachment = attachmentIds.isNotEmpty;
  final hasRenderableSubjectHeader =
      showSubjectHeader && subjectText.isNotEmpty;
  final shouldForceRowText =
      renderedText.trim().isEmpty &&
      (hasAttachment ||
          hasRenderableSubjectHeader ||
          message.retracted ||
          message.edited);
  final validatedAvailabilityMessage = message
      .validatedCalendarAvailabilityMessage(
        roomState: roomState,
        ownerJidForShare: ownerJidForShare,
      );
  return ChatTimelineMessageItem(
    id: message.stanzaID,
    createdAt: timestamp.toLocal(),
    messageModel: message,
    authorId: author.authorId,
    authorDisplayName: author.authorDisplayName,
    authorAvatarKey: author.authorAvatarKey,
    authorAvatarPath: author.authorAvatarPath,
    delivery: _messageDelivery(
      message,
      isEmailChat: isEmailChat,
      supportsMarkers: supportsMarkers,
      supportsReceipts: supportsReceipts,
    ),
    rowText: shouldForceRowText
        ? (hasRenderableSubjectHeader ? subjectText : ' ')
        : renderedText,
    isSelf: isSelf,
    isEmailMessage: isEmailMessage,
    showUnreadIndicator: showUnreadIndicator,
    error: message.error,
    trusted: message.trusted,
    renderedText: renderedText,
    attachmentIds: attachmentIds,
    edited: message.edited,
    retracted: message.retracted,
    calendarFragment: message.calendarFragment,
    calendarTaskIcs: message.calendarTaskIcs,
    calendarTaskIcsReadOnly: message.calendarTaskIcsReadOnly,
    availabilityMessage: validatedAvailabilityMessage,
    quotedMessage: quotedMessage,
    reactions: reactionPreviewsForMessage(message),
    shareParticipants: bannerParticipants,
    replyParticipants:
        shareReplies[message.stanzaID] ?? const <chat_models.Chat>[],
    showSubject: showSubjectHeader,
    subjectLabel: subjectLabel,
    isForwarded: isForwardedMessage,
    forwardedFromJid: message.forwardedFromJid,
    forwardedSubjectSenderLabel: forwardedSubjectSenderLabel,
    isInvite: isInvite,
    isInviteRevocation: isInviteRevocation,
    inviteRevoked: inviteRevoked,
    inviteLabel: inviteLabel,
    inviteActionLabel: inviteAction,
    inviteRoom: inviteRoom,
    inviteRoomName: inviteRoomName,
    resolvedHtmlBody: resolvedForwardHtml,
  );
}

ChatTimelineMessageItem? buildPreviewChatTimelineMessageItem({
  required Message message,
  required String? messageIdPrefix,
  required Set<String> shownSubjectShares,
  required bool isGroupChat,
  required bool isEmailChat,
  required String? profileJid,
  required String? resolvedEmailSelfJid,
  required String? currentUserId,
  required String selfUserId,
  required String selfDisplayName,
  required String? selfAvatarPath,
  required String? myOccupantJid,
  required String? selfNick,
  required RoomState? roomState,
  required List<RoomMemberSection> roomMemberSections,
  required chat_models.Chat? chat,
  required Map<String, Message> messageById,
  required Map<String, ShareContext> shareContexts,
  required Map<String, List<chat_models.Chat>> shareReplies,
  required Map<int, String> emailFullHtmlByDeltaId,
  required Set<String> revokedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String unknownAuthorLabel,
  required String Function(String roomDisplayName) inviteActionLabel,
  required bool supportsMarkers,
  required bool supportsReceipts,
  required List<String> Function(Message message) attachmentsForMessage,
  required List<ReactionPreview> Function(Message message)
  reactionPreviewsForMessage,
  required List<chat_models.Chat> Function(
    ShareContext? context,
    String? chatJid,
    String? selfJid,
  )
  participantsForBanner,
  required String? Function(String jid) avatarPathForBareJid,
  required String? Function(String shareId) ownerJidForShare,
  required String Function(MessageError error) errorLabel,
  required String Function(MessageError error, String body) errorLabelWithBody,
}) {
  final timelineItem = buildMainChatTimelineMessageItem(
    message: message,
    shownSubjectShares: shownSubjectShares,
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
    inviteRoomFallbackLabel: inviteRoomFallbackLabel,
    inviteBodyLabel: inviteBodyLabel,
    inviteRevokedBodyLabel: inviteRevokedBodyLabel,
    unknownAuthorLabel: unknownAuthorLabel,
    inviteActionLabel: inviteActionLabel,
    supportsMarkers: supportsMarkers,
    supportsReceipts: supportsReceipts,
    attachmentsForMessage: attachmentsForMessage,
    reactionPreviewsForMessage: reactionPreviewsForMessage,
    participantsForBanner: participantsForBanner,
    avatarPathForBareJid: avatarPathForBareJid,
    ownerJidForShare: ownerJidForShare,
    errorLabel: errorLabel,
    errorLabelWithBody: errorLabelWithBody,
  );
  if (timelineItem == null) {
    return null;
  }
  final idPrefix = messageIdPrefix?.trim() ?? '';
  if (idPrefix.isEmpty) {
    return timelineItem;
  }
  final previewId = '$idPrefix${message.stanzaID}';
  final previewDatabaseId = '$idPrefix${message.id ?? message.stanzaID}';
  return _copyChatTimelineMessageItem(
    timelineItem,
    id: previewId,
    messageModel: message.copyWith(stanzaID: previewId, id: previewDatabaseId),
    showUnreadIndicator: false,
  );
}

ChatTimelineMessageItem _copyChatTimelineMessageItem(
  ChatTimelineMessageItem item, {
  required String id,
  required Message messageModel,
  required bool showUnreadIndicator,
}) {
  return ChatTimelineMessageItem(
    id: id,
    createdAt: item.createdAt,
    messageModel: messageModel,
    authorId: item.authorId,
    authorDisplayName: item.authorDisplayName,
    authorAvatarKey: item.authorAvatarKey,
    authorAvatarPath: item.authorAvatarPath,
    delivery: item.delivery,
    rowText: item.rowText,
    isSelf: item.isSelf,
    isEmailMessage: item.isEmailMessage,
    showUnreadIndicator: showUnreadIndicator,
    error: item.error,
    trusted: item.trusted,
    renderedText: item.renderedText,
    attachmentIds: item.attachmentIds,
    edited: item.edited,
    retracted: item.retracted,
    calendarFragment: item.calendarFragment,
    calendarTaskIcs: item.calendarTaskIcs,
    calendarTaskIcsReadOnly: item.calendarTaskIcsReadOnly,
    availabilityMessage: item.availabilityMessage,
    quotedMessage: item.quotedMessage,
    reactions: item.reactions,
    shareParticipants: item.shareParticipants,
    replyParticipants: item.replyParticipants,
    showSubject: item.showSubject,
    subjectLabel: item.subjectLabel,
    isForwarded: item.isForwarded,
    forwardedFromJid: item.forwardedFromJid,
    forwardedSubjectSenderLabel: item.forwardedSubjectSenderLabel,
    isInvite: item.isInvite,
    isInviteRevocation: item.isInviteRevocation,
    inviteRevoked: item.inviteRevoked,
    inviteLabel: item.inviteLabel,
    inviteActionLabel: item.inviteActionLabel,
    inviteRoom: item.inviteRoom,
    inviteRoomName: item.inviteRoomName,
    resolvedHtmlBody: item.resolvedHtmlBody,
  );
}

String _resolveTimelineMessageAvatarKey({
  required Message message,
  required Occupant? occupant,
  required String unknownLabel,
}) {
  final occupantNick = occupant?.nick.trim();
  if (occupantNick != null && occupantNick.isNotEmpty) {
    return occupantNick;
  }
  final senderNick = addressResourcePart(message.senderJid)?.trim();
  if (senderNick != null && senderNick.isNotEmpty) {
    return senderNick;
  }
  final unknown = unknownLabel.trim();
  if (unknown.isNotEmpty) {
    return unknown;
  }
  return '?';
}

ChatTimelineMessageDelivery _messageDelivery(
  Message message, {
  required bool isEmailChat,
  required bool supportsMarkers,
  required bool supportsReceipts,
}) {
  if (message.error.isNotNone) {
    return ChatTimelineMessageDelivery.failed;
  }
  if (isEmailChat) {
    if (message.received || message.displayed) {
      return ChatTimelineMessageDelivery.received;
    }
    if (message.acked) {
      return ChatTimelineMessageDelivery.sent;
    }
    return ChatTimelineMessageDelivery.pending;
  }
  if (message.displayed && supportsMarkers) {
    return ChatTimelineMessageDelivery.read;
  }
  if (message.received && (supportsMarkers || supportsReceipts)) {
    return ChatTimelineMessageDelivery.received;
  }
  if (message.acked) {
    return ChatTimelineMessageDelivery.sent;
  }
  return ChatTimelineMessageDelivery.pending;
}

bool _sameOccupantNick(String left, String right) {
  final normalizedLeft = left.trim().toLowerCase();
  final normalizedRight = right.trim().toLowerCase();
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }
  return normalizedLeft == normalizedRight;
}
