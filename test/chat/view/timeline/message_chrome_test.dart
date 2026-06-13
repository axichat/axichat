// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/chat/view/chat.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allows email replies by delta id without an origin id', () {
    const message = Message(
      stanzaID: 'email-row',
      senderJid: 'alice@example.com',
      chatJid: 'alice@example.com',
      deltaMsgId: 42,
    );

    expect(message.replyReference(isGroupChat: false), isNull);
    expect(
      canReplyToTimelineMessage(
        message: message,
        isGroupChat: false,
        requiresMucReference: false,
      ),
      isTrue,
    );
  });

  test('does not allow email replies without a reference or delta id', () {
    const message = Message(
      stanzaID: 'email-row',
      senderJid: 'alice@example.com',
      chatJid: 'alice@example.com',
      deltaChatId: 7,
    );

    expect(
      canReplyToTimelineMessage(
        message: message,
        isGroupChat: false,
        requiresMucReference: false,
      ),
      isFalse,
    );
  });
}
