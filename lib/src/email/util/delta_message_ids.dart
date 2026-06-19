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

int? deltaMsgIdFromDeviceLocalStanzaId(String stanzaId) {
  final normalized = stanzaId.trim().toLowerCase();
  const separator = _deltaMessageStanzaSeparator;
  final messagePrefix = '$_deltaMessageStanzaPrefix$separator';
  if (normalized.startsWith(messagePrefix)) {
    return _positiveIntOrNull(normalized.substring(messagePrefix.length));
  }
  final scopedPrefix = '$_deltaScopedMessageStoragePrefix$separator';
  if (!normalized.startsWith(scopedPrefix)) {
    return null;
  }
  final parts = normalized.substring(scopedPrefix.length).split(separator);
  if (parts.length != 3) {
    return null;
  }
  if (int.tryParse(parts[0]) == null || int.tryParse(parts[1]) == null) {
    return null;
  }
  return _positiveIntOrNull(parts[2]);
}

int? _positiveIntOrNull(String value) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    return null;
  }
  return parsed;
}
