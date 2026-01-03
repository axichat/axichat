// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

class ChatCalendarSyncEnvelope {
  const ChatCalendarSyncEnvelope({
    required this.chatJid,
    required this.chatType,
    required this.senderJid,
    required this.inbound,
  });

  final String chatJid;
  final ChatType chatType;
  final String senderJid;
  final CalendarSyncInbound inbound;
}

typedef ChatCalendarSyncHandler = Future<void> Function(
  ChatCalendarSyncEnvelope envelope,
);
