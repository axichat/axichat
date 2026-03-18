// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/models/chat_timeline.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/safe_logging.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/email/models/share_context.dart';
import 'package:axichat/src/email/util/delta_jids.dart';
import 'package:axichat/src/email/util/synthetic_forward_html.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/xmpp/muc/room_state.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;

const _mucAvatarTraceLogName = 'MucAvatarTrace';

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

String? _traceValue(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }
  return trimmed;
}

String _traceOccupant(Occupant? occupant) {
  if (occupant == null) {
    return '<none>';
  }
  return '${occupant.occupantId}|nick=${occupant.nick}|'
      'realJid=${occupant.realJid ?? '<null>'}|present=${occupant.isPresent}|'
      'avatarKey=${occupant.avatarKey}';
}

String _traceMemberEntry(RoomMemberEntry? entry) {
  if (entry == null) {
    return '<none>';
  }
  return '${entry.occupant.occupantId}|nick=${entry.occupant.nick}|'
      'avatar=${_traceValue(entry.avatarPath) ?? '<none>'}|'
      'direct=${_traceValue(entry.directChatJid) ?? '<none>'}|'
      'actions=${entry.actions.length}';
}

String _traceRoomMemberSections(List<RoomMemberSection> sections) {
  final entries = <String>[];
  for (final section in sections) {
    for (final member in section.members) {
      if (entries.length >= 12) {
        break;
      }
      final occupant = member.occupant;
      entries.add(
        '${section.kind.name}|'
        'id=${occupant.occupantId}|'
        'nick=${occupant.nick}|'
        'present=${occupant.isPresent}|'
        'real=${_traceValue(occupant.realJid) ?? '<none>'}|'
        'avatar=${_traceValue(member.avatarPath) ?? '<none>'}',
      );
    }
    if (entries.length >= 12) {
      break;
    }
  }
  if (entries.isEmpty) {
    return '<none>';
  }
  if (entries.length >= 12) {
    return '${entries.take(12).join('||')}|truncated';
  }
  return entries.join('||');
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
  final senderNick = addressResourcePart(message.senderJid)?.trim();
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
  final roomBareJid = chat == null ? null : normalizedAddressKey(chat.jid);
  String avatarSource = 'none';
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
  bool skippedRoomBareFallback = false;
  String? fallbackLookupJid;
  String nickMatchCandidateSummary = '<none>';
  if (!isSelf && senderNick != null && senderNick.isNotEmpty) {
    final matches = <String>[];
    for (final section in roomMemberSections) {
      for (final member in section.members) {
        if (!_matchesExactRoomMemberSenderNick(
          memberOccupant: member.occupant,
          senderNick: senderNick,
        )) {
          if (!_matchesDerivedRoomMemberSenderAlias(
            memberOccupant: member.occupant,
            senderNick: senderNick,
          )) {
            continue;
          }
        }
        if (matches.length >= 6) {
          continue;
        }
        final occupant = member.occupant;
        matches.add(
          '${section.kind.name}|'
          'id=${occupant.occupantId}|'
          'present=${occupant.isPresent}|'
          'real=${_traceValue(occupant.realJid) ?? '<none>'}|'
          'avatar=${_traceValue(member.avatarPath) ?? '<none>'}|'
          'aliases=${_traceMemberIdentityAliases(occupant)}',
        );
      }
    }
    if (matches.isNotEmpty) {
      nickMatchCandidateSummary = matches.join('||');
    }
  }
  if (isSelf) {
    final trimmedSelfAvatarPath = selfAvatarPath?.trim();
    if (trimmedSelfAvatarPath != null && trimmedSelfAvatarPath.isNotEmpty) {
      authorAvatarPath = trimmedSelfAvatarPath;
      avatarSource = 'self_avatar';
    }
  } else {
    final memberAvatarPath = avatarMemberEntry?.avatarPath?.trim();
    if (memberAvatarPath != null && memberAvatarPath.isNotEmpty) {
      authorAvatarPath = memberAvatarPath;
      avatarSource = messageMemberEntry != null
          ? 'message_entry'
          : 'occupant_entry';
    } else {
      final occupantRealJid = avatarOccupant?.realJid?.trim();
      if (occupantRealJid != null && occupantRealJid.isNotEmpty) {
        final bareRealJid = bareAddress(occupantRealJid) ?? occupantRealJid;
        final normalizedBareRealJid = normalizedAddressKey(bareRealJid);
        fallbackLookupJid = bareRealJid;
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
            avatarSource = 'bare_jid_fallback:$bareRealJid';
          }
        } else {
          skippedRoomBareFallback = isRoomBareJidMatch;
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
  SafeLogging.debugLog(
    'MUC_AVATAR_TRACE|resolve_message|'
    'chat=${chat?.jid ?? '<none>'}|stanza=${message.stanzaID}|'
    'senderJid=${message.senderJid}|occupantId=${_traceValue(message.occupantID) ?? '<none>'}|'
    'senderNick=${addressResourcePart(message.senderJid) ?? '<none>'}|'
    'isSelf=$isSelf|selfFlags='
    'xmpp=$isSelfXmpp,email=$isSelfEmail,'
    'mucSelf=$isMucSelf,placeholder=$isDeltaPlaceholderSender|'
    'sections=${roomMemberSections.map((section) => '${section.kind.name}=${section.members.length}').join('|')}|'
    'occupant=${_traceOccupant(occupant)}|'
    'messageEntry=${_traceMemberEntry(messageMemberEntry)}|'
    'avatarEntry=${_traceMemberEntry(avatarMemberEntry)}|'
    'avatarSource=$avatarSource|'
    'memberNick=${occupant?.nick}|avatarKey=$authorAvatarKey|'
    'avatarPath=${_traceValue(authorAvatarPath) ?? '<none>'}|'
    'lookupJid=${fallbackLookupJid ?? '<none>'}|'
    'nickMatches=$nickMatchCandidateSummary|'
    'sectionMembers=${_traceRoomMemberSections(roomMemberSections)}|'
    'skipRoomBare=$skippedRoomBareFallback',
    name: _mucAvatarTraceLogName,
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
  for (final candidate in _memberIdentityAliases(memberOccupant)) {
    if (_sameOccupantNick(candidate, senderNick)) {
      return true;
    }
  }
  return false;
}

Iterable<String> _memberIdentityAliases(Occupant occupant) sync* {
  final occupantNickLocalPart = addressLocalPart(occupant.nick);
  if (occupantNickLocalPart != null && occupantNickLocalPart.isNotEmpty) {
    yield occupantNickLocalPart;
  }
  final realJid = occupant.realJid?.trim();
  if (realJid == null || realJid.isEmpty) {
    return;
  }
  yield realJid;
  final bareRealJid = bareAddress(realJid);
  if (bareRealJid != null && bareRealJid.isNotEmpty) {
    yield bareRealJid;
  }
  final realJidLocalPart = addressLocalPart(realJid);
  if (realJidLocalPart != null && realJidLocalPart.isNotEmpty) {
    yield realJidLocalPart;
  }
}

String _traceMemberIdentityAliases(Occupant occupant) {
  final aliases = <String>{};
  for (final candidate in _memberIdentityAliases(occupant)) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    aliases.add(trimmed);
    if (aliases.length >= 6) {
      break;
    }
  }
  if (aliases.isEmpty) {
    return '<none>';
  }
  return aliases.join(',');
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
