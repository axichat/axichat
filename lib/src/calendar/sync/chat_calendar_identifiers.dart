import 'dart:convert';

import 'package:crypto/crypto.dart';

const String _chatCalendarStorageIdPrefix = 'chat_calendar_';
const String _chatCalendarSyncStatePrefix = 'chat_calendar_sync_v1_';

String chatCalendarStorageId(String chatJid) {
  return '$_chatCalendarStorageIdPrefix${_hashJid(chatJid)}';
}

String chatCalendarSyncStateKey(String chatJid) {
  return '$_chatCalendarSyncStatePrefix${_hashJid(chatJid)}';
}

String _hashJid(String jid) {
  final normalized = jid.trim().toLowerCase();
  final bytes = utf8.encode(normalized);
  return sha256.convert(bytes).toString();
}
