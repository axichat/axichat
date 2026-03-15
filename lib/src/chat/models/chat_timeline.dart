// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_fragment.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/models/chat_models.dart' as chat_models;

sealed class ChatTimelineItem {
  const ChatTimelineItem({required this.id, required this.createdAt});

  final String id;
  final DateTime createdAt;
}

sealed class ChatTimelineSpecialItem extends ChatTimelineItem {
  const ChatTimelineSpecialItem({required super.id, required super.createdAt});
}

sealed class ChatTimelineTailSpacerItem extends ChatTimelineSpecialItem {
  const ChatTimelineTailSpacerItem({
    required super.id,
    required super.createdAt,
  });
}

enum ChatTimelineMessageDelivery { none, pending, sent, received, read, failed }

final class ChatTimelineMessageItem extends ChatTimelineItem {
  const ChatTimelineMessageItem({
    required super.id,
    required super.createdAt,
    required this.messageModel,
    required this.authorId,
    required this.authorDisplayName,
    required this.authorAvatarKey,
    required this.authorAvatarPath,
    required this.delivery,
    required this.rowText,
    required this.isSelf,
    required this.isEmailMessage,
    required this.showUnreadIndicator,
    required this.error,
    required this.trusted,
    required this.renderedText,
    required this.attachmentIds,
    required this.edited,
    required this.retracted,
    required this.calendarFragment,
    required this.calendarTaskIcs,
    required this.calendarTaskIcsReadOnly,
    required this.availabilityMessage,
    required this.quotedMessage,
    required this.reactions,
    required this.shareParticipants,
    required this.replyParticipants,
    required this.showSubject,
    required this.subjectLabel,
    required this.isForwarded,
    required this.forwardedFromJid,
    required this.forwardedSubjectSenderLabel,
    required this.isInvite,
    required this.isInviteRevocation,
    required this.inviteRevoked,
    required this.inviteLabel,
    required this.inviteActionLabel,
    required this.inviteRoom,
    required this.inviteRoomName,
    required this.resolvedHtmlBody,
  });

  final Message messageModel;
  final String authorId;
  final String authorDisplayName;
  final String authorAvatarKey;
  final String? authorAvatarPath;
  final ChatTimelineMessageDelivery delivery;
  final String rowText;
  final bool isSelf;
  final bool isEmailMessage;
  final bool showUnreadIndicator;
  final MessageError error;
  final bool? trusted;
  final String renderedText;
  final List<String> attachmentIds;
  final bool edited;
  final bool retracted;
  final CalendarFragment? calendarFragment;
  final CalendarTask? calendarTaskIcs;
  final bool calendarTaskIcsReadOnly;
  final CalendarAvailabilityMessage? availabilityMessage;
  final Message? quotedMessage;
  final List<ReactionPreview> reactions;
  final List<chat_models.Chat> shareParticipants;
  final List<chat_models.Chat> replyParticipants;
  final bool showSubject;
  final String? subjectLabel;
  final bool isForwarded;
  final String? forwardedFromJid;
  final String? forwardedSubjectSenderLabel;
  final bool isInvite;
  final bool isInviteRevocation;
  final bool inviteRevoked;
  final String inviteLabel;
  final String inviteActionLabel;
  final String? inviteRoom;
  final String? inviteRoomName;
  final String? resolvedHtmlBody;
}

final class ChatTimelineComposerOverlaySpacerItem
    extends ChatTimelineTailSpacerItem {
  const ChatTimelineComposerOverlaySpacerItem({
    required super.id,
    required super.createdAt,
  });
}

final class ChatTimelineUnreadDividerItem extends ChatTimelineSpecialItem {
  const ChatTimelineUnreadDividerItem({
    required super.id,
    required super.createdAt,
    required this.label,
  });

  final String label;
}

final class ChatTimelineEmptyStateItem extends ChatTimelineSpecialItem {
  const ChatTimelineEmptyStateItem({
    required super.id,
    required super.createdAt,
    required this.label,
  });

  final String label;
}
