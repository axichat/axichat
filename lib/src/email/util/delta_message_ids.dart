// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const String _deltaMessageStanzaPrefix = 'dc-msg';
const String _deltaScopedMessageStoragePrefix = 'dc-local-msg';
const String _deltaPendingOutgoingStanzaPrefix = 'dc-pending';
const String _deltaMessageStanzaSeparator = '-';

String deltaMessageStanzaId(int msgId) =>
    '$_deltaMessageStanzaPrefix$_deltaMessageStanzaSeparator$msgId';

String deltaScopedMessageStorageStanzaId({
  required int accountId,
  required int chatId,
  required int msgId,
}) {
  return '$_deltaScopedMessageStoragePrefix'
      '$_deltaMessageStanzaSeparator$accountId'
      '$_deltaMessageStanzaSeparator$chatId'
      '$_deltaMessageStanzaSeparator$msgId';
}

String deltaPendingOutgoingStanzaId(String uniqueId) {
  final trimmed = uniqueId.trim();
  if (trimmed.isEmpty) {
    throw const FormatException(
      'Pending Delta stanza id suffix cannot be empty.',
    );
  }
  return '$_deltaPendingOutgoingStanzaPrefix'
      '$_deltaMessageStanzaSeparator$trimmed';
}

bool isPendingOutgoingDeltaStanzaId(String stanzaId) {
  final pendingPrefix =
      '$_deltaPendingOutgoingStanzaPrefix$_deltaMessageStanzaSeparator';
  return stanzaId.startsWith(pendingPrefix) &&
      stanzaId.length > pendingPrefix.length;
}

String deltaPendingOutgoingStanzaLikePattern() =>
    '$_deltaPendingOutgoingStanzaPrefix$_deltaMessageStanzaSeparator%';
