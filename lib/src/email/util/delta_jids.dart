// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';

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
  String get normalizedDeltaJid => normalizedAddressValueOrEmpty(this);

  bool get isDeltaPlaceholderJid =>
      deltaPlaceholderJids.contains(normalizedDeltaJid);
}

extension DeltaJidNullableExtensions on String? {
  String? resolveDeltaPlaceholderJid([String? fallback]) {
    final normalized = normalizeAddress(this);
    if (normalized == null) {
      return null;
    }
    if (!normalized.isDeltaPlaceholderJid) {
      return normalized;
    }
    final fallbackNormalized = normalizeAddress(fallback);
    if (fallbackNormalized == null) {
      return null;
    }
    return fallbackNormalized.isDeltaPlaceholderJid ? null : fallbackNormalized;
  }
}
