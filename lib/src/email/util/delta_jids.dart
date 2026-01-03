// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

const String deltaDomain = 'delta.chat';
const String deltaUserDomain = 'user.delta.chat';
const String deltaSelfLocalPart = 'dc-self';
const String deltaAnonLocalPart = 'dc-anon';

const String deltaSelfJid = '$deltaSelfLocalPart@$deltaDomain';
const String deltaSelfUserJid = '$deltaSelfLocalPart@$deltaUserDomain';
const String deltaAnonJid = '$deltaAnonLocalPart@$deltaDomain';
const String deltaAnonUserJid = '$deltaAnonLocalPart@$deltaUserDomain';

const List<String> deltaPlaceholderJids = <String>[
  deltaSelfJid,
  deltaSelfUserJid,
  deltaAnonJid,
  deltaAnonUserJid,
];

extension DeltaJidExtensions on String {
  String get normalizedDeltaJid => trim().toLowerCase();

  bool get isDeltaPlaceholderJid =>
      deltaPlaceholderJids.contains(normalizedDeltaJid);
}

extension DeltaJidNullableExtensions on String? {
  String? resolveDeltaPlaceholderJid([String? fallback]) {
    final trimmed = this?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (!trimmed.isDeltaPlaceholderJid) {
      return trimmed;
    }
    final fallbackTrimmed = fallback?.trim();
    if (fallbackTrimmed == null || fallbackTrimmed.isEmpty) {
      return null;
    }
    return fallbackTrimmed.isDeltaPlaceholderJid ? null : fallbackTrimmed;
  }
}
