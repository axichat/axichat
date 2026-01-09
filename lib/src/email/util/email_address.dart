// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

String normalizeEmailAddress(String value) {
  final trimmed = value.trim();
  return trimmed.toLowerCase();
}

String fallbackEmailAddressForChat(int chatId) => 'chat-$chatId@delta.chat';
