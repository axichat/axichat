import 'dart:io';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tempDir;
  late File databaseFile;
  late XmppDrift database;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'message_manual_send_again_test',
    );
    databaseFile = File('${tempDir.path}/db.sqlite');
    database = XmppDrift(
      file: databaseFile,
      passphrase: 'passphrase',
      executor: NativeDatabase(databaseFile),
    );
  });

  tearDown(() async {
    await database.close();
    await tempDir.delete(recursive: true);
  });

  test('manual send-again marker is stored on the original message', () async {
    await database.saveMessage(
      Message(
        stanzaID: 'original-message',
        senderJid: 'self@example.com',
        chatJid: 'peer@example.com',
        body: 'Original',
        timestamp: DateTime.utc(2024, 1, 1),
      ),
      selfJid: 'self@example.com',
    );

    await database.markMessageManualSendAgain(
      stanzaID: 'original-message',
      sendAgainStanzaID: 'copy-message',
    );

    var original = await database.getMessageByStanzaID('original-message');
    expect(original?.manualSendAgainStanzaID, 'copy-message');

    await database.close();
    database = XmppDrift(
      file: databaseFile,
      passphrase: 'passphrase',
      executor: NativeDatabase(databaseFile),
    );

    original = await database.getMessageByStanzaID('original-message');
    expect(original?.manualSendAgainStanzaID, 'copy-message');
  });
}
