// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/chat/models/rfc_email_group.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
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

String? previewTextForMessage(
  Message message, {
  String? attachmentPreviewFallback,
}) {
  if (message.isEmailBacked) {
    return ChatSubjectCodec.previewEmailText(
          body: message.body,
          subject: message.subject,
        ) ??
        _normalizedAttachmentPreviewFallback(attachmentPreviewFallback);
  }
  return ChatSubjectCodec.previewText(
        body: message.body,
        subject: message.subject,
      ) ??
      _normalizedAttachmentPreviewFallback(attachmentPreviewFallback);
}

String? _normalizedAttachmentPreviewFallback(String? fallback) {
  final normalized = fallback?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

bool isMucSelfMessage({
  required Message message,
  required RoomState? roomState,
  String? selfJid,
  String? fallbackSelfNick,
}) {
  final realJid = message.effectiveSenderRealJid;
  if (realJid != null) {
    return sameBareAddress(
      realJid,
      roomState?.resolvedSelfJid(fallbackJid: selfJid) ?? selfJid,
    );
  }
  if (roomState != null) {
    if (roomState.isSelfOccupantId(message.occupantID)) {
      return true;
    }
    return roomState.isSelfSenderJid(
      message.senderJid,
      selfJid: selfJid,
      fallbackSelfNick: fallbackSelfNick,
    );
  }
  return false;
}

bool canTogglePinForMessage({
  required chat_models.Chat chat,
  required Message message,
  required RoomState? roomState,
  String? selfJid,
}) {
  if (chat.defaultTransport.isEmail || message.isEmailBacked) {
    return false;
  }
  if (chat.type != ChatType.groupChat) {
    return true;
  }
  if (roomState == null ||
      roomState.myRole.isVisitor ||
      roomState.myRole.isNone) {
    return false;
  }
  if (roomState.myRole.canManagePins || roomState.myAffiliation.canManagePins) {
    return true;
  }
  return roomState.myRole.isParticipant || roomState.myAffiliation.isMember;
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
      hasForwardedBodyHeader(bodyText);
}

Occupant? resolveRoomMessageOccupant({
  required Message message,
  required RoomState roomState,
}) {
  final senderJid = message.senderJid.trim();
  final occupantId = message.occupantID?.trim();
  if (occupantId != null && occupantId.isNotEmpty) {
    final matchedByOccupantId = roomState.matchingOccupant(occupantId);
    if (matchedByOccupantId != null) {
      return matchedByOccupantId;
    }
  }
  final occupantFromSenderJid = roomState.occupantForSenderJid(
    senderJid,
    preferRealJid: true,
  );
  if (occupantFromSenderJid != null) {
    return occupantFromSenderJid;
  }
  return roomState.occupantForRealJid(senderJid);
}

RoomMemberEntry? resolveRoomMemberEntryForMessage({
  required Message message,
  required List<RoomMemberSection> sections,
}) {
  final senderJid = message.senderJid.trim();
  final senderNick = addressResourcePart(senderJid)?.trim();
  final occupantId = message.occupantID?.trim();
  RoomMemberEntry? directMatch;
  RoomMemberEntry? realJidMatch;
  RoomMemberEntry? exactNickMatch;
  RoomMemberEntry? aliasNickMatch;
  for (final section in sections) {
    for (final member in section.members) {
      final memberOccupant = member.occupant;
      final matchesDirectOccupantId =
          occupantId != null &&
          occupantId.isNotEmpty &&
          _sameOccupantId(memberOccupant.occupantId, occupantId);
      final matchesSenderOccupantId = _sameOccupantId(
        memberOccupant.occupantId,
        senderJid,
      );
      if (matchesDirectOccupantId || matchesSenderOccupantId) {
        directMatch = _betterRoomMemberEntry(directMatch, member);
        continue;
      }
      if (memberOccupant.matchesRealJid(senderJid)) {
        realJidMatch = _betterRoomMemberEntry(realJidMatch, member);
        continue;
      }
      if (senderNick != null && senderNick.isNotEmpty) {
        if (_matchesExactRoomMemberSenderNick(
          memberOccupant: memberOccupant,
          senderNick: senderNick,
        )) {
          exactNickMatch = _betterRoomMemberEntry(exactNickMatch, member);
          continue;
        }
        if (_matchesDerivedRoomMemberSenderAlias(
          memberOccupant: memberOccupant,
          senderNick: senderNick,
        )) {
          aliasNickMatch = _betterRoomMemberEntry(aliasNickMatch, member);
        }
      }
    }
  }
  var resolved = directMatch;
  resolved = _betterRoomMemberEntry(resolved, realJidMatch);
  resolved = _betterRoomMemberEntry(resolved, exactNickMatch);
  resolved = _betterRoomMemberEntry(resolved, aliasNickMatch);
  return resolved;
}

RoomMemberEntry? resolveRoomMemberEntryForOccupant({
  required Occupant occupant,
  required List<RoomMemberSection> sections,
}) {
  final occupantRealJid = occupant.realJid?.trim();
  final occupantNick = occupant.nick.trim();
  final occupantId = occupant.occupantId.trim();
  RoomMemberEntry? directMatch;
  RoomMemberEntry? realJidMatch;
  RoomMemberEntry? exactNickMatch;
  RoomMemberEntry? aliasNickMatch;
  for (final section in sections) {
    for (final member in section.members) {
      final memberOccupant = member.occupant;
      if (_sameOccupantId(memberOccupant.occupantId, occupantId)) {
        directMatch = _betterRoomMemberEntry(directMatch, member);
        continue;
      }
      if (occupantRealJid != null &&
          occupantRealJid.isNotEmpty &&
          memberOccupant.matchesRealJid(occupantRealJid)) {
        realJidMatch = _betterRoomMemberEntry(realJidMatch, member);
        continue;
      }
      if (_matchesExactRoomMemberSenderNick(
        memberOccupant: memberOccupant,
        senderNick: occupantNick,
      )) {
        exactNickMatch = _betterRoomMemberEntry(exactNickMatch, member);
        continue;
      }
      if (_matchesDerivedRoomMemberSenderAlias(
        memberOccupant: memberOccupant,
        senderNick: occupantNick,
      )) {
        aliasNickMatch = _betterRoomMemberEntry(aliasNickMatch, member);
      }
    }
  }
  var resolved = directMatch;
  resolved = _betterRoomMemberEntry(resolved, realJidMatch);
  resolved = _betterRoomMemberEntry(resolved, exactNickMatch);
  resolved = _betterRoomMemberEntry(resolved, aliasNickMatch);
  return resolved;
}

RoomMemberEntry? _betterRoomMemberEntry(
  RoomMemberEntry? current,
  RoomMemberEntry? candidate,
) {
  if (current == null) {
    return candidate;
  }
  if (candidate == null) {
    return current;
  }
  // Room state can hold both the live room/nick occupant and the
  // affiliation-backed member entry for the same person.
  final currentHasAvatar = _roomMemberEntryHasAvatar(current);
  final candidateHasAvatar = _roomMemberEntryHasAvatar(candidate);
  if (candidateHasAvatar != currentHasAvatar) {
    return candidateHasAvatar ? candidate : current;
  }
  final currentPresent = current.occupant.isPresent;
  final candidatePresent = candidate.occupant.isPresent;
  if (candidatePresent != currentPresent) {
    return candidatePresent ? candidate : current;
  }
  return current;
}

bool _roomMemberEntryHasAvatar(RoomMemberEntry entry) {
  return entry.avatarPath?.trim().isNotEmpty == true;
}

bool _sameOccupantId(String left, String right) {
  final trimmedLeft = left.trim();
  final trimmedRight = right.trim();
  if (trimmedLeft.isEmpty || trimmedRight.isEmpty) {
    return false;
  }
  final normalizedLeft = normalizedOccupantId(left);
  final normalizedRight = normalizedOccupantId(right);
  if (normalizedLeft != null &&
      normalizedRight != null &&
      normalizedLeft == normalizedRight) {
    return true;
  }
  return trimmedLeft.toLowerCase() == trimmedRight.toLowerCase();
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
  final normalizedSenderBare = normalizedAddressKey(message.senderJid);
  final isSelfXmpp = message.isFromAccount(profileJid);
  final isSelfEmail = message.isFromAccount(resolvedEmailSelfJid);
  final isDeltaPlaceholderSender =
      normalizedSenderBare != null &&
      normalizedSenderBare.isDeltaPlaceholderJid;
  final isMucSelf =
      isGroupChat &&
      isMucSelfMessage(
        message: message,
        roomState: roomState,
        selfJid: profileJid,
      );
  final isSelf =
      isSelfXmpp || isSelfEmail || isMucSelf || isDeltaPlaceholderSender;
  final occupant = !isGroupChat || roomState == null
      ? null
      : resolveRoomMessageOccupant(message: message, roomState: roomState);
  final senderNick = addressResourcePart(message.senderJid)?.trim();
  final senderBareAddress = bareAddress(message.senderJid)?.trim();
  final fallbackNick = isGroupChat
      ? roomState?.senderNick(message.senderJid) ??
            senderNick ??
            senderBareAddress ??
            ''
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
  final roomBareJid = chat == null ? null : normalizedAddressKey(chat.jid);
  final avatarMemberEntry =
      messageMemberEntry ??
      (occupant == null
          ? null
          : resolveRoomMemberEntryForOccupant(
              occupant: occupant,
              sections: roomMemberSections,
            ));
  final avatarOccupant = avatarMemberEntry?.occupant ?? occupant;
  String? authorAvatarPath;
  if (isSelf) {
    final trimmedSelfAvatarPath = selfAvatarPath?.trim();
    if (trimmedSelfAvatarPath != null && trimmedSelfAvatarPath.isNotEmpty) {
      authorAvatarPath = trimmedSelfAvatarPath;
    }
  } else {
    final memberAvatarPath = avatarMemberEntry?.avatarPath?.trim();
    if (memberAvatarPath != null && memberAvatarPath.isNotEmpty) {
      authorAvatarPath = memberAvatarPath;
    } else {
      final occupantRealJid = avatarOccupant?.realJid?.trim();
      if (occupantRealJid != null && occupantRealJid.isNotEmpty) {
        final bareRealJid = bareAddress(occupantRealJid) ?? occupantRealJid;
        final normalizedBareRealJid = normalizedAddressKey(bareRealJid);
        final isRoomBareJidMatch =
            roomBareJid != null &&
            normalizedBareRealJid != null &&
            normalizedBareRealJid == roomBareJid;
        if (normalizedBareRealJid != null &&
            normalizedBareRealJid.isNotEmpty &&
            !isRoomBareJidMatch) {
          final resolvedAvatarPath = avatarPathForBareJid(bareRealJid)?.trim();
          if (resolvedAvatarPath != null && resolvedAvatarPath.isNotEmpty) {
            authorAvatarPath = resolvedAvatarPath;
          }
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
  String? pendingEmailContentLabel,
  String? unavailableEmailContentLabel,
  required String emailEncryptionStatusLabel,
  required bool isGroupChat,
  required bool isEmailChat,
  DateTime? staleUnackedCutoff,
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
  required Set<int> emailFullHtmlUnavailable,
  required Set<String> revokedInviteTokens,
  required Set<String> acceptedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String inviteAcceptedBodyLabel,
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
  final loadedOpenPgpEmailStanzaIds = <String>{
    for (final message in messages)
      if (message.isEmailBackedOpenPgpContent) message.stanzaID,
  };
  final rfcEmailGroupsByStanzaId = buildRfcEmailGroupsByMessageStanzaId(
    messages: messages,
    attachmentsForMessage: attachmentsForMessage,
    bodyTextForMessage: (message) => rfcEmailBodyText(
      message: message,
      resolvedHtmlBody: _resolvedEmailHtmlBodyForProjection(
        message: message,
        emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
      ),
    ),
    isAuthoritativeBody: (message) => message.hasRfc822BodyContent,
    requireMeaningfulBody: false,
  );
  final visibleUnreadBoundary = _visibleUnreadBoundary(
    unreadBoundaryStanzaId: unreadBoundaryStanzaId,
    messages: messages,
    rfcEmailGroupsByStanzaId: rfcEmailGroupsByStanzaId,
  );
  var unreadDividerInserted = false;
  final renderedRfcEmailGroupKeys = <String>{};
  ChatTimelineMessageItem? projectMessage(
    Message message,
    RfcEmailGroup? rfcEmailGroup,
  ) {
    return buildMainChatTimelineMessageItem(
      message: message,
      rfcEmailGroup: rfcEmailGroup,
      includeRfcEmailBodyBlocks: rfcEmailGroup?.isLeader(message) == true,
      suppressRfcEmailBody:
          rfcEmailGroup?.shouldSuppressTimelineText(message) == true,
      shownSubjectShares: shownSubjectShares,
      isGroupChat: isGroupChat,
      isEmailChat: isEmailChat,
      staleUnackedCutoff: staleUnackedCutoff,
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
      emailFullHtmlUnavailable: emailFullHtmlUnavailable,
      revokedInviteTokens: revokedInviteTokens,
      acceptedInviteTokens: acceptedInviteTokens,
      inviteRoomFallbackLabel: inviteRoomFallbackLabel,
      inviteBodyLabel: inviteBodyLabel,
      inviteRevokedBodyLabel: inviteRevokedBodyLabel,
      inviteAcceptedBodyLabel: inviteAcceptedBodyLabel,
      pendingEmailContentLabel: pendingEmailContentLabel,
      unavailableEmailContentLabel: unavailableEmailContentLabel,
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
  }

  void appendMessageItem(ChatTimelineMessageItem timelineItem) {
    timelineItems.add(timelineItem);
    if (!unreadDividerInserted &&
        visibleUnreadBoundary.shouldInsert &&
        timelineItem.id == visibleUnreadBoundary.stanzaId) {
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

  Iterable<Message> orderedVisibleRfcEmailGroupMessages(RfcEmailGroup group) {
    final visibleRowsBelowLeader = group.messages
        .where((groupMessage) => groupMessage.stanzaID != group.leader.stanzaID)
        .where((groupMessage) => !group.shouldHideTimelineMessage(groupMessage))
        .toList(growable: false);
    // MessageList is reversed, so emit grouped rows bottom-up.
    return [
      ...visibleRowsBelowLeader.reversed,
      if (!group.shouldHideTimelineMessage(group.leader)) group.leader,
    ];
  }

  for (final message in messages) {
    if (message.pseudoMessageType?.isSystemStatus == true) {
      final systemStatusItem = buildSystemStatusTimelineItem(
        message,
        loadedOpenPgpEmailStanzaIds: loadedOpenPgpEmailStanzaIds,
        emailEncryptionStatusLabel: emailEncryptionStatusLabel,
      );
      if (systemStatusItem != null) {
        timelineItems.add(systemStatusItem);
      }
      continue;
    }
    final rfcEmailGroup = rfcEmailGroupsByStanzaId[message.stanzaID];
    final rfcEmailGroupKey = message.emailRfcGroupKey;
    if (rfcEmailGroup != null && rfcEmailGroupKey != null) {
      if (!renderedRfcEmailGroupKeys.add(rfcEmailGroupKey)) {
        continue;
      }
      for (final groupMessage in orderedVisibleRfcEmailGroupMessages(
        rfcEmailGroup,
      )) {
        final timelineItem = projectMessage(groupMessage, rfcEmailGroup);
        if (timelineItem != null) {
          appendMessageItem(timelineItem);
        }
      }
      continue;
    }
    final timelineItem = projectMessage(message, rfcEmailGroup);
    if (timelineItem == null) {
      continue;
    }
    appendMessageItem(timelineItem);
  }
  if (!loadingMessages && timelineItems.isEmpty) {
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

({String? stanzaId, bool shouldInsert}) _visibleUnreadBoundary({
  required String? unreadBoundaryStanzaId,
  required List<Message> messages,
  required Map<String, RfcEmailGroup> rfcEmailGroupsByStanzaId,
}) {
  if (unreadBoundaryStanzaId == null) {
    return (stanzaId: null, shouldInsert: false);
  }
  final boundaryMessage = messages
      .where((message) => message.stanzaID == unreadBoundaryStanzaId)
      .firstOrNull;
  if (boundaryMessage == null || boundaryMessage.displayed) {
    return (stanzaId: unreadBoundaryStanzaId, shouldInsert: false);
  }
  final group = rfcEmailGroupsByStanzaId[unreadBoundaryStanzaId];
  if (group == null) {
    return (stanzaId: unreadBoundaryStanzaId, shouldInsert: true);
  }
  if (!group.shouldHideTimelineMessage(boundaryMessage)) {
    return (stanzaId: unreadBoundaryStanzaId, shouldInsert: true);
  }
  return (stanzaId: group.leader.stanzaID, shouldInsert: true);
}

ChatTimelineSystemStatusItem? buildSystemStatusTimelineItem(
  Message message, {
  required Set<String> loadedOpenPgpEmailStanzaIds,
  String? emailEncryptionStatusLabel,
}) {
  if (!message.isRenderableEmailEncryptionStatusMarker(
    loadedOpenPgpEmailStanzaIds: loadedOpenPgpEmailStanzaIds,
  )) {
    return null;
  }
  final timestamp = message.timestamp;
  final label = emailEncryptionStatusLabel?.trim().isNotEmpty == true
      ? emailEncryptionStatusLabel!.trim()
      : previewTextForMessage(message)?.trim();
  if (timestamp == null || label == null || label.isEmpty) {
    return null;
  }
  return ChatTimelineSystemStatusItem(
    id: message.stanzaID,
    createdAt: timestamp.toLocal(),
    label: label,
  );
}

({Set<String> revokedInviteTokens, Set<String> acceptedInviteTokens})
resolveInviteLifecycleTokens(Iterable<Message> messages) {
  final lifecycleMessages =
      <Message>[
        for (final message in messages)
          if (message.pseudoMessageType ==
                  PseudoMessageType.mucInviteRevocation ||
              message.pseudoMessageType == PseudoMessageType.mucInviteAccepted)
            message,
      ]..sort((a, b) {
        final leftTimestamp = a.timestamp;
        final rightTimestamp = b.timestamp;
        if (leftTimestamp == null && rightTimestamp == null) return 0;
        if (leftTimestamp == null) return -1;
        if (rightTimestamp == null) return 1;
        return leftTimestamp.compareTo(rightTimestamp);
      });
  final revokedInviteTokens = <String>{};
  final acceptedInviteTokens = <String>{};
  for (final message in lifecycleMessages) {
    if (message.error.isNotNone) {
      continue;
    }
    final token = (message.pseudoMessageData?['token'] as String?)?.trim();
    if (token == null || token.isEmpty) {
      continue;
    }
    if (message.pseudoMessageType == PseudoMessageType.mucInviteRevocation) {
      revokedInviteTokens.add(token);
      acceptedInviteTokens.remove(token);
    } else if (message.pseudoMessageType ==
        PseudoMessageType.mucInviteAccepted) {
      acceptedInviteTokens.add(token);
      revokedInviteTokens.remove(token);
    }
  }
  return (
    revokedInviteTokens: Set<String>.unmodifiable(revokedInviteTokens),
    acceptedInviteTokens: Set<String>.unmodifiable(acceptedInviteTokens),
  );
}

({Set<String> revokedInviteTokens, Set<String> acceptedInviteTokens})
resolveActiveInviteLifecycleTokens({
  required Iterable<Message> messages,
  required Iterable<Message> searchResults,
  required bool searchFiltering,
}) {
  Iterable<Message> activeLifecycleMessages() sync* {
    yield* messages;
    if (searchFiltering) {
      yield* searchResults;
    }
  }

  return resolveInviteLifecycleTokens(activeLifecycleMessages());
}

ChatTimelineMessageItem? buildMainChatTimelineMessageItem({
  required Message message,
  RfcEmailGroup? rfcEmailGroup,
  bool includeRfcEmailBodyBlocks = false,
  bool suppressRfcEmailBody = false,
  required Set<String> shownSubjectShares,
  required bool isGroupChat,
  required bool isEmailChat,
  DateTime? staleUnackedCutoff,
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
  required Set<int> emailFullHtmlUnavailable,
  required Set<String> revokedInviteTokens,
  required Set<String> acceptedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String inviteAcceptedBodyLabel,
  String? pendingEmailContentLabel,
  String? unavailableEmailContentLabel,
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
  if (message.pseudoMessageType?.isHiddenInviteLifecycle == true) {
    return null;
  }
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
  final inviteAction = inviteActionLabel(inviteRoomDisplayName);
  final inviteAccepted =
      isInvite &&
      inviteToken != null &&
      acceptedInviteTokens.contains(inviteToken);
  final inviteRevoked =
      !inviteAccepted &&
      inviteToken != null &&
      revokedInviteTokens.contains(inviteToken);
  final inviteLabel = inviteAccepted
      ? inviteAcceptedBodyLabel
      : inviteRevoked
      ? inviteRevokedBodyLabel
      : isInvite
      ? inviteBodyLabel
      : inviteRevokedBodyLabel;
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
  final resolvedForwardHtml = _resolvedEmailHtmlBodyForProjection(
    message: message,
    emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
  );
  final hasResolvedForwardHtml = resolvedForwardHtml?.trim().isNotEmpty == true;
  final emailFullHtmlIsUnavailable =
      deltaMessageId != null &&
      emailFullHtmlUnavailable.contains(deltaMessageId);
  final forwardedHtmlText = resolvedForwardHtml == null
      ? null
      : HtmlContentCodec.toPlainText(resolvedForwardHtml);
  final forwardedSubjectSenderLabel =
      syntheticForwardDisplaySenderLabel(
        subjectLabel: rawSubjectLabel,
        emailMarkerPresent:
            isEmailMessage &&
            hasSyntheticForwardHtmlMarker(html: resolvedForwardHtml),
      ) ??
      forwardedBodySenderLabel(rawBodyText) ??
      forwardedBodySenderLabel(forwardedHtmlText);
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
    if (message.hasRfc822BodyContent &&
        HtmlContentCodec.looksLikeCssBodyText(bodyText)) {
      bodyText = rfcEmailBodyText(
        message: message,
        resolvedHtmlBody: resolvedForwardHtml,
      );
    }
  }
  if (suppressRfcEmailBody) {
    showSubjectHeader = false;
    subjectLabel = null;
    bodyText = '';
  }
  final attachmentIds = attachmentsForMessage(message);
  final hasAttachment = attachmentIds.isNotEmpty;
  if (isEmailMessage &&
      hasAttachment &&
      bodyText.trim().isNotEmpty &&
      rfcEmailBodyText(
        message: message,
        resolvedHtmlBody: resolvedForwardHtml,
      ).trim().isEmpty) {
    bodyText = '';
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
      hasForwardedBodyHeader(forwardedHtmlText) ||
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
  final normalizedPendingEmailContentLabel = pendingEmailContentLabel?.trim();
  final normalizedUnavailableEmailContentLabel = unavailableEmailContentLabel
      ?.trim();
  final hasRenderableEmailSourceContent =
      isEmailMessage &&
      _hasRenderableEmailSourceContent(
        message: message,
        resolvedHtmlBody: resolvedForwardHtml,
      );
  final shouldUseUnavailableEmailContentLabel =
      isEmailMessage &&
      message.error.isNone &&
      !message.retracted &&
      !hasAttachment &&
      deltaMessageId != null &&
      deltaMessageId > 0 &&
      !hasResolvedForwardHtml &&
      !hasRenderableEmailSourceContent &&
      emailFullHtmlIsUnavailable &&
      bodyTextTrimmed.isEmpty &&
      normalizedUnavailableEmailContentLabel != null &&
      normalizedUnavailableEmailContentLabel.isNotEmpty;
  final shouldUsePendingEmailContentLabel =
      isEmailMessage &&
      message.error.isNone &&
      !message.retracted &&
      !hasAttachment &&
      deltaMessageId != null &&
      deltaMessageId > 0 &&
      !hasResolvedForwardHtml &&
      !emailFullHtmlIsUnavailable &&
      bodyTextTrimmed.isEmpty &&
      normalizedPendingEmailContentLabel != null &&
      normalizedPendingEmailContentLabel.isNotEmpty;
  final renderedText = shouldReplaceInviteBody
      ? inviteLabel
      : shouldUseUnavailableEmailContentLabel
      ? normalizedUnavailableEmailContentLabel
      : shouldUsePendingEmailContentLabel
      ? normalizedPendingEmailContentLabel
      : message.error.isNotNone
      ? bodyText.isNotEmpty
            ? errorLabelWithBody(message.error, bodyTextTrimmed)
            : errorLabel(message.error)
      : displayedBody;
  final validatedAvailabilityMessage = message
      .validatedCalendarAvailabilityMessage(ownerJidForShare: ownerJidForShare);
  final emailBodyBlocks = !includeRfcEmailBodyBlocks || rfcEmailGroup == null
      ? const <ChatTimelineEmailBodyBlock>[]
      : _rfcEmailBodyBlocksForGroup(
          group: rfcEmailGroup,
          emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
        );
  final resolvedRenderedText = emailBodyBlocks.isEmpty
      ? renderedText
      : emailBodyBlocks
            .map((block) => block.plainText.trim())
            .where((text) => text.isNotEmpty)
            .join('\n\n');
  final emailVisualKind = _emailVisualKindForTimelineItem(
    isEmailMessage: isEmailMessage,
    hasAttachments: hasAttachment,
    resolvedHtmlBody: resolvedForwardHtml,
    rfcEmailGroup: rfcEmailGroup,
    emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
  );
  final hasRenderableSubjectHeader =
      showSubjectHeader && subjectText.isNotEmpty;
  final shouldForceRowText =
      resolvedRenderedText.trim().isEmpty &&
      (hasAttachment ||
          hasRenderableSubjectHeader ||
          message.retracted ||
          message.edited);
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
        : resolvedRenderedText,
    isSelf: isSelf,
    isEmailMessage: isEmailMessage,
    canSendAgain:
        staleUnackedCutoff != null &&
        message.isStaleUnackedXmppSendAgainCandidate(
          isSelf: isSelf,
          isEmailChat: isEmailChat,
          staleBefore: staleUnackedCutoff,
        ),
    showUnreadIndicator: showUnreadIndicator,
    error: message.error,
    trusted: message.trusted,
    renderedText: resolvedRenderedText,
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
    emailRfcGroupKey: rfcEmailGroup == null ? null : message.emailRfcGroupKey,
    isEmailRfcGroupLeader:
        rfcEmailGroup == null || rfcEmailGroup.isLeader(message),
    emailVisualKind: emailVisualKind,
    isForwarded:
        isForwardedMessage &&
        (rfcEmailGroup == null || rfcEmailGroup.isLeader(message)),
    forwardedFromJid: message.forwardedFromJid,
    forwardedOriginalSenderLabel: message.forwardedOriginalSenderLabel,
    forwardedSubjectSenderLabel: forwardedSubjectSenderLabel,
    isInvite: isInvite,
    isInviteRevocation: isInviteRevocation,
    inviteRevoked: inviteRevoked,
    inviteAccepted: inviteAccepted,
    inviteLabel: inviteLabel,
    inviteActionLabel: inviteAction,
    inviteRoom: inviteRoom,
    inviteRoomName: inviteRoomName,
    resolvedHtmlBody: suppressRfcEmailBody ? null : resolvedForwardHtml,
    emailBodyBlocks: emailBodyBlocks,
  );
}

ChatTimelineMessageItem? buildPreviewChatTimelineMessageItem({
  required Message message,
  required String? messageIdPrefix,
  required Set<String> shownSubjectShares,
  required bool isGroupChat,
  required bool isEmailChat,
  DateTime? staleUnackedCutoff,
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
  required Set<int> emailFullHtmlUnavailable,
  required Set<String> revokedInviteTokens,
  required Set<String> acceptedInviteTokens,
  required String inviteRoomFallbackLabel,
  required String inviteBodyLabel,
  required String inviteRevokedBodyLabel,
  required String inviteAcceptedBodyLabel,
  String? pendingEmailContentLabel,
  String? unavailableEmailContentLabel,
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
    staleUnackedCutoff: staleUnackedCutoff,
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
    emailFullHtmlUnavailable: emailFullHtmlUnavailable,
    revokedInviteTokens: revokedInviteTokens,
    acceptedInviteTokens: acceptedInviteTokens,
    inviteRoomFallbackLabel: inviteRoomFallbackLabel,
    inviteBodyLabel: inviteBodyLabel,
    inviteRevokedBodyLabel: inviteRevokedBodyLabel,
    inviteAcceptedBodyLabel: inviteAcceptedBodyLabel,
    pendingEmailContentLabel: pendingEmailContentLabel,
    unavailableEmailContentLabel: unavailableEmailContentLabel,
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
    canSendAgain: item.canSendAgain,
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
    emailRfcGroupKey: item.emailRfcGroupKey,
    isEmailRfcGroupLeader: item.isEmailRfcGroupLeader,
    emailVisualKind: item.emailVisualKind,
    isForwarded: item.isForwarded,
    forwardedFromJid: item.forwardedFromJid,
    forwardedOriginalSenderLabel: item.forwardedOriginalSenderLabel,
    forwardedSubjectSenderLabel: item.forwardedSubjectSenderLabel,
    isInvite: item.isInvite,
    isInviteRevocation: item.isInviteRevocation,
    inviteRevoked: item.inviteRevoked,
    inviteAccepted: item.inviteAccepted,
    inviteLabel: item.inviteLabel,
    inviteActionLabel: item.inviteActionLabel,
    inviteRoom: item.inviteRoom,
    inviteRoomName: item.inviteRoomName,
    resolvedHtmlBody: item.resolvedHtmlBody,
    emailBodyBlocks: item.emailBodyBlocks,
  );
}

ChatTimelineEmailVisualKind _emailVisualKindForTimelineItem({
  required bool isEmailMessage,
  required bool hasAttachments,
  required String? resolvedHtmlBody,
  required RfcEmailGroup? rfcEmailGroup,
  required Map<int, String> emailFullHtmlByDeltaId,
}) {
  if (!isEmailMessage) {
    return ChatTimelineEmailVisualKind.none;
  }
  if (hasAttachments || rfcEmailGroup?.hasAnyAttachments == true) {
    return ChatTimelineEmailVisualKind.attachment;
  }
  if (rfcEmailGroup != null &&
      _rfcEmailGroupHasHtml(
        group: rfcEmailGroup,
        emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
      )) {
    return ChatTimelineEmailVisualKind.html;
  }
  if (_emailBodyHasHtml(resolvedHtmlBody: resolvedHtmlBody)) {
    return ChatTimelineEmailVisualKind.html;
  }
  return ChatTimelineEmailVisualKind.plainText;
}

bool _rfcEmailGroupHasHtml({
  required RfcEmailGroup group,
  required Map<int, String> emailFullHtmlByDeltaId,
}) {
  for (final source in group.bodySources) {
    final resolvedHtmlBody = _resolvedEmailHtmlBodyForProjection(
      message: source,
      emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
    );
    if (_emailBodyHasHtml(resolvedHtmlBody: resolvedHtmlBody)) {
      return true;
    }
  }
  return false;
}

bool _emailBodyHasHtml({required String? resolvedHtmlBody}) {
  final normalizedHtmlBody = HtmlContentCodec.normalizeHtml(resolvedHtmlBody);
  return normalizedHtmlBody != null;
}

String? _resolvedEmailHtmlBodyForProjection({
  required Message message,
  required Map<int, String> emailFullHtmlByDeltaId,
}) => resolvedEmailHtmlBodyForMessage(
  message: message,
  emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
);

bool _hasRenderableEmailSourceContent({
  required Message message,
  required String? resolvedHtmlBody,
}) => rfcEmailBodyText(
  message: message,
  resolvedHtmlBody: resolvedHtmlBody,
).trim().isNotEmpty;

List<ChatTimelineEmailBodyBlock> _rfcEmailBodyBlocksForGroup({
  required RfcEmailGroup group,
  required Map<int, String> emailFullHtmlByDeltaId,
}) {
  final blocks = <ChatTimelineEmailBodyBlock>[];
  for (final source in group.bodySources) {
    final resolvedHtmlBody = _resolvedEmailHtmlBodyForProjection(
      message: source,
      emailFullHtmlByDeltaId: emailFullHtmlByDeltaId,
    );
    final plainText = rfcEmailBodyText(
      message: source,
      resolvedHtmlBody: resolvedHtmlBody,
    );
    if (plainText.trim().isEmpty &&
        HtmlContentCodec.normalizeHtml(resolvedHtmlBody) == null) {
      continue;
    }
    blocks.add(
      ChatTimelineEmailBodyBlock(
        sourceStanzaId: source.stanzaID,
        sourceMessageDatabaseId: source.id,
        sourceDeltaMsgId: source.deltaMsgId,
        plainText: plainText,
        resolvedHtmlBody: resolvedHtmlBody,
      ),
    );
  }
  return List<ChatTimelineEmailBodyBlock>.unmodifiable(blocks);
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
  if (message.displayed) {
    return ChatTimelineMessageDelivery.read;
  }
  if (message.received) {
    return ChatTimelineMessageDelivery.received;
  }
  if (message.acked) {
    return ChatTimelineMessageDelivery.sent;
  }
  return ChatTimelineMessageDelivery.pending;
}

bool _sameOccupantNick(String left, String right) {
  final normalizedLeft = _normalizeMemberNickname(left);
  final normalizedRight = _normalizeMemberNickname(right);
  if (normalizedLeft.isEmpty || normalizedRight.isEmpty) {
    return false;
  }
  return normalizedLeft == normalizedRight;
}

bool _matchesExactRoomMemberSenderNick({
  required Occupant memberOccupant,
  required String senderNick,
}) {
  final candidates = <String>[
    memberOccupant.nick,
    _resourcePart(memberOccupant.occupantId),
  ];
  for (final candidate in candidates) {
    if (_sameOccupantNick(candidate, senderNick)) {
      return true;
    }
  }
  return false;
}

bool _matchesDerivedRoomMemberSenderAlias({
  required Occupant memberOccupant,
  required String senderNick,
}) {
  final occupantNickLocalPart = addressLocalPart(memberOccupant.nick);
  if (occupantNickLocalPart != null &&
      _sameOccupantNick(occupantNickLocalPart, senderNick)) {
    return true;
  }
  final realJidLocalPart = addressLocalPart(memberOccupant.realJid);
  if (realJidLocalPart != null &&
      _sameOccupantNick(realJidLocalPart, senderNick)) {
    return true;
  }
  return false;
}

String _normalizeMemberNickname(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed
      .toLowerCase()
      .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _resourcePart(String? raw) {
  final trimmed = raw?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return '';
  }
  final parsed = parseJid(trimmed);
  if (parsed != null && parsed.resource.trim().isNotEmpty) {
    return parsed.resource.trim();
  }
  final slashIndex = trimmed.indexOf('/');
  if (slashIndex == -1 || slashIndex == trimmed.length - 1) {
    return '';
  }
  return trimmed.substring(slashIndex + 1).trim();
}
