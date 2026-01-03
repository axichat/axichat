// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:crypto/crypto.dart';

const String _notificationPayloadPrefix = 'axichat-chat-v1:';
const int _notificationPayloadMaxLength = 256;

class NotificationPayloadCodec {
  const NotificationPayloadCodec();

  String? encodeChatJid(String chatJid) {
    final normalized = chatJid.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return '$_notificationPayloadPrefix${_hashChatJid(normalized)}';
  }

  bool isEncodedPayload(String payload) =>
      payload.trim().startsWith(_notificationPayloadPrefix);

  String? resolveChatJid({
    required String payload,
    required Iterable<String> chatJids,
  }) {
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      return null;
    }
    if (normalized.length > _notificationPayloadMaxLength) {
      return null;
    }
    if (!normalized.startsWith(_notificationPayloadPrefix)) {
      return _matchChatJid(normalized, chatJids);
    }
    final token = normalized.substring(_notificationPayloadPrefix.length);
    if (token.isEmpty) {
      return null;
    }
    for (final chatJid in chatJids) {
      final candidate = chatJid.trim();
      if (candidate.isEmpty) {
        continue;
      }
      if (_hashChatJid(candidate) == token) {
        return candidate;
      }
    }
    return null;
  }

  String? _matchChatJid(String payload, Iterable<String> chatJids) {
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final normalizedLower = normalized.toLowerCase();
    for (final chatJid in chatJids) {
      final candidate = chatJid.trim();
      if (candidate.isEmpty) {
        continue;
      }
      if (candidate == normalized) {
        return candidate;
      }
      if (candidate.toLowerCase() == normalizedLower) {
        return candidate;
      }
    }
    return null;
  }

  String _hashChatJid(String chatJid) {
    final digest = sha256.convert(utf8.encode(chatJid));
    return base64Url.encode(digest.bytes);
  }
}
