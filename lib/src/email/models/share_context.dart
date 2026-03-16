// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

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
