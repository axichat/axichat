// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

enum FanOutRecipientState { queued, sending, sent, failed }

class FanOutRecipientStatus extends Equatable {
  const FanOutRecipientStatus({
    required this.chat,
    required this.state,
    this.deltaMsgId,
    this.error,
  });

  final Chat chat;
  final FanOutRecipientState state;
  final int? deltaMsgId;
  final Object? error;

  bool get isFailure => state == FanOutRecipientState.failed;

  @override
  List<Object?> get props => [chat, state, deltaMsgId, error];
}

class FanOutSendReport extends Equatable {
  const FanOutSendReport({
    required this.shareId,
    required this.statuses,
    this.subjectToken,
    this.subject,
    this.attachmentWarning = false,
  });

  final String shareId;
  final String? subjectToken;
  final String? subject;
  final bool attachmentWarning;
  final List<FanOutRecipientStatus> statuses;

  bool get hasFailures => statuses.any((status) => status.isFailure);

  @override
  List<Object?> get props => [
    shareId,
    subjectToken,
    subject,
    attachmentWarning,
    statuses,
  ];
}

class ShareContext extends Equatable {
  const ShareContext({
    required this.shareId,
    required this.participants,
    this.subject,
    this.originatorDeltaMsgId,
    this.participantCount,
  });

  final String shareId;
  final List<Chat> participants;
  final String? subject;
  final int? originatorDeltaMsgId;
  final int? participantCount;

  bool isOriginator(Message message) {
    final originatorId = originatorDeltaMsgId;
    final messageId = message.deltaMsgId;
    if (originatorId == null || messageId == null) {
      return false;
    }
    return originatorId == messageId;
  }

  @override
  List<Object?> get props => [
    shareId,
    participants,
    subject,
    originatorDeltaMsgId,
    participantCount,
  ];
}
