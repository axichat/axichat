String normalizeEmailAddress(String value) {
  final trimmed = value.trim();
  return trimmed.toLowerCase();
}

String fallbackEmailAddressForChat(int chatId) => 'chat-$chatId@delta.chat';
