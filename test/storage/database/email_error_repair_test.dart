// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late XmppDrift database;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Message row({
    required String stanzaId,
    required MessageError error,
    int? deltaMsgId,
    int? deltaChatId,
  }) {
    return Message(
      stanzaID: stanzaId,
      senderJid: 'me@example.com',
      chatJid: 'alice@example.com',
      body: 'Body of $stanzaId',
      timestamp: DateTime.utc(2026, 1, 1),
      error: error,
      deltaChatId: deltaChatId,
      deltaMsgId: deltaMsgId,
    );
  }

  test('clears XMPP-class errors from email-backed rows only', () async {
    await database.saveMessage(
      row(
        stanzaId: 'poisoned-email',
        error: MessageError.serviceUnavailable,
        deltaMsgId: 42,
        deltaChatId: 7,
      ),
    );
    await database.saveMessage(
      row(
        stanzaId: 'poisoned-email-unknown',
        error: MessageError.unknown,
        deltaMsgId: 43,
        deltaChatId: 7,
      ),
    );
    await database.saveMessage(
      row(
        stanzaId: 'failed-email-timeout',
        error: MessageError.serverTimeout,
        deltaMsgId: 44,
        deltaChatId: 7,
      ),
    );
    await database.saveMessage(
      row(
        stanzaId: 'failed-email-dns',
        error: MessageError.serverNotFound,
        deltaMsgId: 45,
        deltaChatId: 7,
      ),
    );
    await database.saveMessage(
      row(stanzaId: 'failed-xmpp', error: MessageError.serviceUnavailable),
    );
    await database.saveMessage(
      row(
        stanzaId: 'failed-email-send',
        error: MessageError.emailSendFailure,
        deltaMsgId: 46,
        deltaChatId: 7,
      ),
    );

    final cleared = await database.clearXmppErrorsFromEmailMessages();

    expect(cleared, 2);
    expect(
      (await database.getMessageByStanzaID('poisoned-email'))!.error,
      MessageError.none,
    );
    expect(
      (await database.getMessageByStanzaID('poisoned-email-unknown'))!.error,
      MessageError.none,
    );
    expect(
      (await database.getMessageByStanzaID('failed-email-timeout'))!.error,
      MessageError.serverTimeout,
    );
    expect(
      (await database.getMessageByStanzaID('failed-email-dns'))!.error,
      MessageError.serverNotFound,
    );
    expect(
      (await database.getMessageByStanzaID('failed-xmpp'))!.error,
      MessageError.serviceUnavailable,
    );
    expect(
      (await database.getMessageByStanzaID('failed-email-send'))!.error,
      MessageError.emailSendFailure,
    );
  });
}
