// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

String normalizeEmailAddress(String value) {
  final trimmed = value.trim();
  return trimmed.toLowerCase();
}

const String _emailPattern =
    r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+";
final RegExp _emailRegex = RegExp(_emailPattern);

extension EmailAddressValidation on String {
  bool get isValidEmailAddress => _emailRegex.hasMatch(trim());
}

String fallbackEmailAddressForChat(int chatId) => 'chat-$chatId@delta.chat';
