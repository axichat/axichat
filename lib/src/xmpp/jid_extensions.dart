// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

extension JidParsing on String {
  String? toBareJidOrNull({required int maxBytes}) {
    final trimmed = trim();
    if (trimmed.isEmpty) return null;
    if (!isWithinUtf8ByteLimit(trimmed, maxBytes: maxBytes)) {
      return null;
    }
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }
}
