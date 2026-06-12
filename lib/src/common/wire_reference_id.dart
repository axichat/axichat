// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';

const int wireReferenceIdMaxBytes = 1024;

extension type const WireReferenceId._(String value) {
  static WireReferenceId? tryFrom(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (!isWithinUtf8ByteLimit(trimmed, maxBytes: wireReferenceIdMaxBytes)) {
      return null;
    }
    final normalized = trimmed.toLowerCase();
    if (isDeviceLocalDeltaStanzaId(normalized) ||
        isDeltaGeneratedMessageId(normalized) ||
        isDerivedEmailMessageKey(normalized)) {
      return null;
    }
    return WireReferenceId._(trimmed);
  }
}
