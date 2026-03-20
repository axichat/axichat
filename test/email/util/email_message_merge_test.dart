// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/email/util/email_message_merge.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mergeOriginMessages preserves forwarded original sender metadata', () {
    final primary = Message(
      stanzaID: 'primary',
      senderJid: 'forwarder@example.com',
      chatJid: 'forwarder@example.com',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageData: const {
        'forwarded': true,
        'forwardedFromJid': 'forwarder@example.com',
      },
    );
    final duplicate = Message(
      stanzaID: 'duplicate',
      senderJid: 'forwarder@example.com',
      chatJid: 'forwarder@example.com',
      timestamp: DateTime.utc(2024, 1, 1, 10),
      pseudoMessageData: const {
        'forwarded': true,
        'forwardedFromJid': 'forwarder@example.com',
        'forwardedOriginalSenderLabel': 'original@example.com',
      },
    );

    final merged = mergeOriginMessages(
      primary: primary,
      duplicate: duplicate,
      originId: '<origin@example.com>',
    );

    expect(merged.forwardedFromJid, 'forwarder@example.com');
    expect(merged.forwardedOriginalSenderLabel, 'original@example.com');
  });
}
