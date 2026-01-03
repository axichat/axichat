// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/storage/models.dart';
import 'package:equatable/equatable.dart';

class PinnedMessageItem extends Equatable {
  const PinnedMessageItem({
    required this.messageStanzaId,
    required this.chatJid,
    required this.pinnedAt,
    required this.message,
    required this.attachmentMetadataIds,
  });

  final String messageStanzaId;
  final String chatJid;
  final DateTime pinnedAt;
  final Message? message;
  final List<String> attachmentMetadataIds;

  bool get hasMessage => message != null;

  bool get hasAttachments => attachmentMetadataIds.isNotEmpty;

  @override
  List<Object?> get props => [
        messageStanzaId,
        chatJid,
        pinnedAt,
        message,
        attachmentMetadataIds,
      ];
}
