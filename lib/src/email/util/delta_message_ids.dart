// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const String _deltaMessageStanzaPrefix = 'dc-msg';
const String _deltaScopedMessageStoragePrefix = 'dc-local-msg';
const String _deltaPendingOutgoingStanzaPrefix = 'dc-pending';
const String _deltaMessageStanzaSeparator = '-';

bool isDeviceLocalDeltaStanzaId(String stanzaId) {
  const separator = _deltaMessageStanzaSeparator;
  return stanzaId.startsWith('$_deltaMessageStanzaPrefix$separator') ||
      stanzaId.startsWith('$_deltaScopedMessageStoragePrefix$separator') ||
      stanzaId.startsWith('$_deltaPendingOutgoingStanzaPrefix$separator');
}
