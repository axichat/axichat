import 'dart:io';

import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(fallbackChat);
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(MessageTimelineFilter.directOnly);
    registerFallbackValue(
      const FileMetadataData(id: 'fallback-file', filename: 'fallback.txt'),
    );
  });

  late MockXmppDatabase database;
  late MockDeltaContextHandle context;
  late DeltaEventConsumer consumer;

  setUp(() {
    database = MockXmppDatabase();
    context = MockDeltaContextHandle();
    consumer = DeltaEventConsumer(
      databaseBuilder: () async => database,
      context: context,
      selfJidProvider: () => 'me@example.com',
    );
    when(
      () => database.getChatByDeltaChatId(
        any(),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        any(),
        deltaAccountId: any(named: 'deltaAccountId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(any(), chatJid: any(named: 'chatJid')),
    ).thenAnswer((_) async => null);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getMessageByOriginID(any()),
    ).thenAnswer((_) async => null);
    when(() => database.getChat(any())).thenAnswer((_) async => null);
    when(
      () => database.repairChatSummaryPreservingTimestamp(any()),
    ).thenAnswer((_) async {});
    when(
      () => database.ensureEmailEncryptionStatusMarkerForChat(any()),
    ).thenAnswer((_) async {});
    when(
      () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
    ).thenAnswer((_) async {});
    when(
      () => database.deleteMessage(
        any(),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.isEmailAddressBlocked(any()),
    ).thenAnswer((_) async => false);
    when(
      () => database.getEmailBlocklistEntry(any()),
    ).thenAnswer((_) async => null);
    when(
      () => database.isEmailAddressSpam(any()),
    ).thenAnswer((_) async => false);
    when(
      () => database.getChatMessages(
        any(),
        start: any(named: 'start'),
        end: any(named: 'end'),
        filter: any(named: 'filter'),
      ),
    ).thenAnswer((_) async => const <Message>[]);
    when(
      () => database.countUnreadMessagesForChat(
        any(),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => database.repairUnreadCountForChat(
        any(),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => database.getPendingOutgoingDeltaMessages(
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async => const <Message>[]);
    when(() => context.getChat(any())).thenAnswer(
      (invocation) async => DeltaChat(
        id: invocation.positionalArguments.first as int,
        name: 'Alice',
        contactAddress: 'alice@example.com',
      ),
    );
    when(
      () => context.getMessageMimeHeaders(any()),
    ).thenAnswer((_) async => 'Message-ID: <test@example.com>');
    when(() => context.chatSendCapabilities(any())).thenAnswer(
      (_) async => const DeltaChatSendCapabilities(
        exists: true,
        canSend: true,
        isEncrypted: true,
      ),
    );
  });

  test('persists incoming timestamps from Delta core', () async {
    const chatId = 7;
    const msgId = 24;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: timestamp,
    );
    const deltaChat = DeltaChat(
      id: chatId,
      name: 'Alice',
      contactAddress: 'alice@example.com',
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
    when(
      () => database.getMessageByStanzaID(any()),
    ).thenAnswer((_) async => null);
    when(() => database.getChat(any())).thenAnswer((_) async => null);
    when(() => database.createChat(any())).thenAnswer((_) async {});
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final persistedMessage =
        verify(
              () => database.saveMessage(
                captureAny(),
                selfJid: any(named: 'selfJid'),
              ),
            ).captured.first
            as Message;
    expect(persistedMessage.timestamp, timestamp);
  });

  test(
    'ensures the email encryption marker after storing OpenPGP mail',
    () async {
      const chatId = 7;
      const msgId = 26;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Encrypted hello',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
        showPadlock: true,
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Alice',
        contactAddress: 'alice@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persistedMessage =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.first
              as Message;
      expect(persistedMessage.encryptionProtocol, EncryptionProtocol.openPgp);
      verify(
        () => database.ensureEmailEncryptionStatusMarkerForChat(
          'alice@example.com',
        ),
      ).called(1);
    },
  );

  test('ingests newer inbound mixed email after older XMPP messages', () async {
    const chatId = 37;
    const msgId = 137;
    final tempDir = await Directory.systemTemp.createTemp(
      'delta_mixed_order_test',
    );
    final realDb = XmppDrift(
      file: File('${tempDir.path}/db.sqlite'),
      passphrase: 'passphrase',
      executor: NativeDatabase.memory(),
    );
    try {
      final chat = Chat(
        jid: 'mixed-order@axi.im',
        title: 'Mixed Order',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'mixed-order@example.com',
        emailFromAddress: 'me@example.com',
      );
      await realDb.createChat(chat);
      await realDb.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      );

      final emailTimestamp = DateTime.utc(2024, 1, 2, 12, 10);
      final xmppMessages = [
        for (final age in [
          const Duration(seconds: 10),
          const Duration(minutes: 1),
          const Duration(minutes: 2),
          const Duration(minutes: 5),
          const Duration(minutes: 10),
        ])
          Message(
            stanzaID: 'mixed-xmpp-${age.inSeconds}',
            senderJid: chat.jid,
            chatJid: chat.jid,
            timestamp: emailTimestamp.subtract(age),
            body: 'older xmpp ${age.inSeconds}',
            encryptionProtocol: EncryptionProtocol.none,
          ),
      ];
      for (final message in xmppMessages.reversed) {
        await realDb.saveMessage(message, selfJid: 'me@axi.im');
      }

      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'newer email',
        timestamp: emailTimestamp,
      );
      final realConsumer = DeltaEventConsumer(
        databaseBuilder: () async => realDb,
        context: context,
        selfJidProvider: () => 'me@example.com',
        xmppSelfJidProvider: () => 'me@axi.im',
      );
      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => 'Message-ID: <mixed-newer@example.com>');

      await realConsumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final messages = await realDb.getChatMessages(
        chat.jid,
        start: 0,
        end: 10,
      );
      expect(messages.map((message) => message.stanzaID), [
        'dc-msg-$msgId',
        ...xmppMessages.map((message) => message.stanzaID),
      ]);
      expect(messages.first.timestamp, emailTimestamp);
      expect(messages.first.deltaMsgId, msgId);
      final updatedChat = await realDb.getChat(chat.jid);
      expect(updatedChat?.lastMessage, 'newer email');
      expect(updatedChat?.lastChangeTimestamp, emailTimestamp);

      await realConsumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final rehydratedMessages = await realDb.getChatMessages(
        chat.jid,
        start: 0,
        end: 10,
      );
      expect(rehydratedMessages.map((message) => message.stanzaID), [
        'dc-msg-$msgId',
        ...xmppMessages.map((message) => message.stanzaID),
      ]);
      expect(
        rehydratedMessages.where((message) => message.deltaMsgId == msgId),
        hasLength(1),
      );
    } finally {
      await realDb.close();
      await tempDir.delete(recursive: true);
    }
  });

  test(
    'uses Delta encryption info messages as email status marker triggers',
    () async {
      const chatId = 7;
      const msgId = 25;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Messages are end-to-end encrypted.',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
        infoType: DeltaMessageInfo.chatE2ee,
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Alice',
        contactAddress: 'alice@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verify(
        () => database.ensureEmailEncryptionStatusMarkerForChat(
          'alice@example.com',
        ),
      ).called(1);
      verifyNever(
        () =>
            database.saveMessage(captureAny(), selfJid: any(named: 'selfJid')),
      );
    },
  );

  test(
    'learns incoming Autocrypt keys when email encryption beta is enabled',
    () async {
      const chatId = 7;
      const msgId = 124;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Autocrypt hello',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Alice',
        contactAddress: 'alice@example.com',
      );
      consumer = DeltaEventConsumer(
        databaseBuilder: () async => database,
        context: context,
        selfJidProvider: () => 'me@example.com',
        emailEncryptionBetaEnabledForAddress: (_, address) =>
            address == 'me@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(() => context.getMessageMimeHeaders(msgId)).thenAnswer(
        (_) async =>
            'Message-ID: <autocrypt@example.com>\n'
            'Autocrypt: addr=alice@example.com; prefer-encrypt=mutual; '
            'keydata=AQID',
      );
      when(
        () => context.importContactPublicKey(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          armoredPublicKey: any(named: 'armoredPublicKey'),
        ),
      ).thenAnswer(
        (_) async => const DeltaContactPublicKeyImport(
          metadata: DeltaOpenPgpKeyMetadata(
            kind: DeltaOpenPgpKeyKind.public,
            fingerprint: 'ABC123',
            userIds: <String>['Alice <alice@example.com>'],
            hasExpectedAddress: true,
            hasEncryptionCapability: true,
          ),
          contactId: 42,
          chatId: 99,
        ),
      );
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final capturedKey =
          verify(
                () => context.importContactPublicKey(
                  address: 'alice@example.com',
                  displayName: 'Alice',
                  armoredPublicKey: captureAny(named: 'armoredPublicKey'),
                ),
              ).captured.single
              as String;
      expect(capturedKey, contains('-----BEGIN PGP PUBLIC KEY BLOCK-----'));
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: 'alice@example.com',
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: 99,
        ),
      ).called(1);
    },
  );

  test('learns changed incoming Autocrypt keys for the same sender', () async {
    const chatId = 7;
    const firstMsgId = 124;
    const secondMsgId = 125;
    const deltaChat = DeltaChat(
      id: chatId,
      name: 'Alice',
      contactAddress: 'alice@example.com',
    );
    consumer = DeltaEventConsumer(
      databaseBuilder: () async => database,
      context: context,
      selfJidProvider: () => 'me@example.com',
      emailEncryptionBetaEnabledForAddress: (_, address) =>
          address == 'me@example.com',
    );
    when(() => context.getMessage(any())).thenAnswer((invocation) async {
      final msgId = invocation.positionalArguments.first as int;
      return DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Autocrypt hello',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
    });
    when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
    when(() => context.getMessageMimeHeaders(any())).thenAnswer((invocation) {
      final msgId = invocation.positionalArguments.first as int;
      final keyData = msgId == firstMsgId ? 'AQID' : 'BAUG';
      return Future.value(
        'Message-ID: <autocrypt-$msgId@example.com>\n'
        'Autocrypt: addr=alice@example.com; prefer-encrypt=mutual; '
        'keydata=$keyData',
      );
    });
    var importCount = 0;
    when(
      () => context.importContactPublicKey(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        armoredPublicKey: any(named: 'armoredPublicKey'),
      ),
    ).thenAnswer((_) async {
      importCount += 1;
      return DeltaContactPublicKeyImport(
        metadata: DeltaOpenPgpKeyMetadata(
          kind: DeltaOpenPgpKeyKind.public,
          fingerprint: 'ABC$importCount',
          userIds: const <String>['Alice <alice@example.com>'],
          hasExpectedAddress: true,
          hasEncryptionCapability: true,
        ),
        contactId: 42,
        chatId: 98 + importCount,
      );
    });
    when(
      () => database.getMessageByStanzaID(any()),
    ).thenAnswer((_) async => null);
    when(() => database.createChat(any())).thenAnswer((_) async {});
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.incomingMsg.code,
        data1: chatId,
        data2: firstMsgId,
      ),
    );
    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.incomingMsg.code,
        data1: chatId,
        data2: secondMsgId,
      ),
    );

    final capturedKeys = verify(
      () => context.importContactPublicKey(
        address: 'alice@example.com',
        displayName: 'Alice',
        armoredPublicKey: captureAny(named: 'armoredPublicKey'),
      ),
    ).captured.cast<String>().toList();
    expect(capturedKeys, hasLength(2));
    expect(capturedKeys.first, isNot(capturedKeys.last));
    verify(
      () => database.upsertEmailChatAccount(
        chatJid: 'alice@example.com',
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: 100,
      ),
    ).called(1);
  });

  test(
    'persists original sender metadata for incoming forwarded emails',
    () async {
      const chatId = 7;
      const msgId = 25;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text:
            '---------- Forwarded message ---------\n'
            'From: Original Person <original@example.com>\n'
            'Subject: Quarterly plan\n'
            '\n'
            'Forwarded body',
        subject: 'Fwd: Quarterly plan',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Forwarder',
        contactAddress: 'forwarder@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persistedMessage =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.last
              as Message;
      expect(persistedMessage.isForwarded, isTrue);
      expect(persistedMessage.forwardedFromJid, 'forwarder@example.com');
      expect(
        persistedMessage.forwardedOriginalSenderLabel,
        'original@example.com',
      );
    },
  );

  test(
    'persists original sender metadata for quoted-printable forwarded emails',
    () async {
      const chatId = 7;
      const msgId = 26;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text:
            '---------- Forwarded message ---------\n'
            'From: Original=20Person=20=3Coriginal@=\n'
            'example.com=3E\n'
            'Subject: Quarterly plan\n'
            '\n'
            'Forwarded body',
        subject: 'Fwd: Quarterly plan',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Forwarder',
        contactAddress: 'forwarder@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persistedMessage =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.last
              as Message;
      expect(persistedMessage.isForwarded, isTrue);
      expect(
        persistedMessage.forwardedOriginalSenderLabel,
        'original@example.com',
      );
    },
  );

  test(
    'persists original sender metadata for top-level forwarded header blocks',
    () async {
      const chatId = 7;
      const msgId = 27;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text:
            'From: Original=20Person=20=3Coriginal@example.com=3E\n'
            'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
            'Subject: Quarterly plan\n'
            'To: Forwarder <forwarder@example.com>\n'
            '\n'
            'Forwarded body',
        subject: 'Fwd: Quarterly plan',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Forwarder',
        contactAddress: 'forwarder@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persistedMessage =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.last
              as Message;
      expect(persistedMessage.isForwarded, isTrue);
      expect(
        persistedMessage.forwardedOriginalSenderLabel,
        'original@example.com',
      );
    },
  );

  test(
    'persists original sender metadata when MIME preambles precede forwarded headers',
    () async {
      const chatId = 7;
      const msgId = 28;
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text:
            'Content-Type: text/plain; charset="utf-8"\n'
            'Content-Transfer-Encoding: quoted-printable\n'
            '\n'
            'From: Original=20Person=20=3Coriginal@example.com=3E\n'
            'Date: Tue, 19 Mar 2026 10:00:00 +0000\n'
            'Subject: Quarterly plan\n'
            'To: Forwarder <forwarder@example.com>\n'
            '\n'
            'Forwarded body',
        subject: 'Fwd: Quarterly plan',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Forwarder',
        contactAddress: 'forwarder@example.com',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(any())).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persistedMessage =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.last
              as Message;
      expect(persistedMessage.isForwarded, isTrue);
      expect(
        persistedMessage.forwardedOriginalSenderLabel,
        'original@example.com',
      );
    },
  );

  test('chatModified updates stored metadata', () async {
    const chatId = 11;
    final existingChat = Chat(
      jid: 'dc-$chatId@delta.chat',
      title: 'Old title',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024),
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => existingChat);
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => context.getChat(chatId)).thenAnswer(
      (_) async => const DeltaChat(
        id: chatId,
        name: 'Group Alpha',
        contactAddress: 'alpha@example.com',
        contactName: 'Coordinator',
        type: DeltaChatType.group,
      ),
    );

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.chatModified.code,
        data1: chatId,
        data2: 0,
      ),
    );

    final updatedChat =
        verify(() => database.updateChat(captureAny())).captured.single as Chat;
    expect(updatedChat.title, 'Group Alpha');
    expect(updatedChat.contactDisplayName, 'Coordinator');
    expect(updatedChat.emailAddress, 'alpha@example.com');
    expect(updatedChat.type, ChatType.groupChat);
  });

  test(
    'chatDeleted detaches Delta metadata without removing mixed XMPP chats',
    () async {
      const chatId = 40;
      final chat = Chat(
        jid: 'alice@axi.im',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        emailAddress: 'alice@example.com',
      );
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.countEmailChatAccounts(chat.jid),
      ).thenAnswer((_) async => 0);

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.chatDeleted.code,
          data1: chatId,
          data2: 0,
        ),
      );

      verify(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verifyNever(() => database.removeChat(chat.jid));
    },
  );

  test(
    'chatDeleted removes native email chats after the last Delta account detaches',
    () async {
      const chatId = 41;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
      );
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.countEmailChatAccounts(chat.jid),
      ).thenAnswer((_) async => 0);
      when(() => database.removeChat(chat.jid)).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.chatDeleted.code,
          data1: chatId,
          data2: 0,
        ),
      );

      verify(() => database.removeChat(chat.jid)).called(1);
    },
  );

  test(
    'merging Delta metadata preserves an existing XMPP chat transport',
    () async {
      const chatId = 31;
      const msgId = 91;
      final existingChat = Chat(
        jid: 'alice@axi.im',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        contactJid: 'alice@axi.im',
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Email copy',
        timestamp: DateTime.utc(2024, 1, 2, 3),
      );
      const deltaChat = DeltaChat(
        id: chatId,
        name: 'Alice Mail',
        contactName: 'Alice Mail',
        contactAddress: 'alice@axi.im',
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getChat(chatId)).thenAnswer((_) async => deltaChat);
      when(
        () => database.getMessageByStanzaID('dc-msg-91'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getChat(existingChat.jid),
      ).thenAnswer((_) async => existingChat);
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final updatedChat =
          verify(() => database.updateChat(captureAny())).captured.single
              as Chat;
      expect(updatedChat.transport, MessageTransport.xmpp);
      expect(updatedChat.deltaChatId, chatId);
      expect(updatedChat.emailAddress, 'alice@axi.im');
      expect(updatedChat.contactJid, 'alice@axi.im');
      verify(
        () =>
            database.saveMessage(captureAny(), selfJid: any(named: 'selfJid')),
      ).called(1);
    },
  );

  test('updates existing message timestamp from Delta core', () async {
    const chatId = 7;
    const msgId = 24;
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: chat.jid,
      timestamp: DateTime.utc(2024, 1, 1, 8),
      originID: 'existing-origin',
      body: 'Hello',
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    final deltaTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: deltaTimestamp,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final updated =
        verify(() => database.updateMessage(captureAny())).captured.single
            as Message;
    expect(updated.stanzaID, existing.stanzaID);
    expect(updated.timestamp, deltaTimestamp);
  });

  test('accepts newer Delta timestamps for pending outgoing email', () async {
    const chatId = 33;
    const msgId = 93;
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    final deltaTimestamp = DateTime.utc(2024, 1, 1, 12, 10);
    final existing = Message(
      stanzaID: 'dc-pending-local-newer',
      senderJid: 'me@example.com',
      chatJid: chat.jid,
      timestamp: DateTime.utc(2024, 1, 1, 12),
      originID: 'existing-origin',
      body: 'Hello',
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: deltaTimestamp,
      isOutgoing: true,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.getMessageByStanzaID('dc-msg-93'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final updated =
        verify(() => database.updateMessage(captureAny())).captured.single
            as Message;
    expect(updated.timestamp, deltaTimestamp);
  });

  test('treats incoming noticed messages as displayed', () async {
    const chatId = 7;
    const msgId = 24;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: chat.jid,
      timestamp: timestamp,
      originID: 'existing-origin',
      body: 'Hello',
      received: true,
      displayed: false,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: timestamp,
      state: DeltaMessageState.inNoticed,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final updated =
        verify(() => database.updateMessage(captureAny())).captured.single
            as Message;
    expect(updated.stanzaID, existing.stanzaID);
    expect(updated.received, isTrue);
    expect(updated.displayed, isTrue);
  });

  test('repairs mixed unread counts with both transport identities', () async {
    const chatId = 7;
    const msgId = 124;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final mixedConsumer = DeltaEventConsumer(
      databaseBuilder: () async => database,
      context: context,
      selfJidProvider: () => 'me@example.com',
      xmppSelfJidProvider: () => 'me@axi.im',
    );
    final chat = Chat(
      jid: 'alice@axi.im',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.xmpp,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
      emailAddress: 'alice@example.com',
      emailFromAddress: 'me@example.com',
    );
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: chat.jid,
      timestamp: timestamp,
      originID: 'existing-origin',
      body: 'Hello',
      received: true,
      displayed: false,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      text: 'Hello',
      timestamp: timestamp,
      state: DeltaMessageState.inNoticed,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

    await mixedConsumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    verify(
      () => database.repairUnreadCountForChat(
        chat.jid,
        selfJid: 'me@axi.im',
        emailSelfJid: 'me@example.com',
      ),
    ).called(1);
  });

  test(
    'does not regress locally displayed incoming messages to fresh',
    () async {
      const chatId = 7;
      const msgId = 25;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final existing = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'alice@example.com',
        chatJid: chat.jid,
        timestamp: timestamp,
        originID: 'existing-origin',
        body: 'Hello',
        received: true,
        displayed: true,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Hello',
        timestamp: timestamp,
        state: DeltaMessageState.inFresh,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.upsertEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => existing);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verifyNever(() => database.updateMessage(any()));
    },
  );

  test(
    'refreshChatlistSnapshot detaches missing Delta chats without removing mixed XMPP chats',
    () async {
      const chatId = 16;
      final chat = Chat(
        jid: 'alice@axi.im',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
      );
      when(() => context.getChatlist()).thenAnswer(
        (_) async => const [
          DeltaChatlistEntry(chatId: 99, msgId: DeltaMessageId.dayMarker),
        ],
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(() => context.getChat(99)).thenAnswer(
        (_) async => const DeltaChat(
          id: 99,
          name: 'System',
          contactAddress: 'chat-99@delta.chat',
        ),
      );
      when(
        () => database.getDeltaChats(accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer((_) async => [chat]);
      when(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.countEmailChatAccounts(chat.jid),
      ).thenAnswer((_) async => 0);

      await consumer.refreshChatlistSnapshot();

      verify(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verifyNever(() => database.removeChat(chat.jid));
    },
  );

  test(
    'refreshChatlistSnapshot hydrates fresh unread messages when chatlist points to a marker',
    () async {
      const chatId = 17;
      const msgId = 101;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Fresh offline email',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
      );

      when(() => context.getChatlist()).thenAnswer(
        (_) async => const [
          DeltaChatlistEntry(chatId: chatId, msgId: DeltaMessageId.dayMarker),
        ],
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(
        () => database.getDeltaChats(accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer((_) async => [chat]);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(() => context.getFreshMessageCountSafe(chatId)).thenAnswer(
        (_) async => const DeltaFreshMessageCount(count: 1, supported: true),
      );
      when(
        () => context.getChatMessageIds(chatId: chatId),
      ).thenAnswer((_) async => [msgId]);
      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getMessageDeltaSnapshot(
          chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getChatMessages(
          chat.jid,
          start: 0,
          end: 1,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer(
        (_) async => [
          Message(
            stanzaID: 'dc-msg-$msgId',
            senderJid: chat.jid,
            chatJid: chat.jid,
            body: 'Fresh offline email',
            timestamp: deltaMessage.timestamp,
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
            deltaMsgId: msgId,
          ),
        ],
      );
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.refreshChatlistSnapshot();

      final persisted =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.first
              as Message;
      expect(persisted.deltaMsgId, msgId);
      expect(persisted.body, 'Fresh offline email');
      expect(
        verify(() => database.updateChat(captureAny())).captured.any(
          (value) =>
              value is Chat &&
              value.jid == chat.jid &&
              value.lastMessage == 'Fresh offline email',
        ),
        isTrue,
      );
    },
  );

  test(
    'refreshChatlistSnapshot keeps unread cleared while the chat is open',
    () async {
      const chatId = 18;
      const msgId = 102;
      final chat = Chat(
        jid: 'alice-open@example.com',
        title: 'Alice Open',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        open: true,
        unreadCount: 0,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Fresh unread email',
        timestamp: DateTime.utc(2024, 1, 2, 4, 5, 6),
      );

      when(() => context.getChatlist()).thenAnswer(
        (_) async => const [
          DeltaChatlistEntry(chatId: chatId, msgId: DeltaMessageId.dayMarker),
        ],
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(
        () => database.getDeltaChats(accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer((_) async => [chat]);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(() => context.getFreshMessageCountSafe(chatId)).thenAnswer(
        (_) async => const DeltaFreshMessageCount(count: 16, supported: true),
      );
      when(
        () => context.getChatMessageIds(chatId: chatId),
      ).thenAnswer((_) async => [msgId]);
      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getMessageDeltaSnapshot(
          chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => []);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getChatMessages(
          chat.jid,
          start: 0,
          end: 1,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer(
        (_) async => [
          Message(
            stanzaID: 'dc-msg-$msgId',
            senderJid: chat.jid,
            chatJid: chat.jid,
            body: 'Fresh unread email',
            timestamp: deltaMessage.timestamp,
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
            deltaMsgId: msgId,
          ),
        ],
      );
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.refreshChatlistSnapshot();

      final updatedChats = verify(
        () => database.updateChat(captureAny()),
      ).captured.whereType<Chat>().where((updated) => updated.jid == chat.jid);

      expect(updatedChats, isNotEmpty);
      expect(updatedChats.every((updated) => updated.unreadCount == 0), isTrue);
    },
  );

  test(
    'msgsChanged keeps local Delta messages when core returns a partial snapshot',
    () async {
      const chatId = 20;
      const visibleMsgId = 202;
      final chat = Chat(
        jid: 'mixed@axi.im',
        title: 'Mixed',
        type: ChatType.chat,
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: chatId,
        emailAddress: 'mixed@example.com',
      );

      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => context.getChatMessageIds(chatId: chatId),
      ).thenAnswer((_) async => const [visibleMsgId]);
      when(
        () => database.getMessageDeltaSnapshot(
          chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const [
          MessageDeltaSnapshot(
            stanzaId: 'dc-msg-101',
            deltaMsgId: 101,
            displayed: true,
          ),
        ],
      );
      when(
        () => context.getMessage(visibleMsgId),
      ).thenAnswer((_) async => null);
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Mixed',
          contactAddress: 'mixed@example.com',
        ),
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(
        () => database.deleteMessagesByStanzaIds(any()),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: any(named: 'jid'),
          maxMessages: any(named: 'maxMessages'),
          deltaAccountId: any(named: 'deltaAccountId'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: 0,
        ),
      );

      verifyNever(() => database.deleteMessagesByStanzaIds(any()));
      verifyNever(
        () => database.trimChatMessages(
          jid: any(named: 'jid'),
          maxMessages: any(named: 'maxMessages'),
          deltaAccountId: any(named: 'deltaAccountId'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      );
    },
  );

  test(
    'msgsChanged does not trim local history on an empty core snapshot',
    () async {
      const chatId = 21;
      final chat = Chat(
        jid: 'empty-snapshot@axi.im',
        title: 'Empty Snapshot',
        type: ChatType.chat,
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        deltaChatId: chatId,
        emailAddress: 'empty-snapshot@example.com',
      );

      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => context.getChatMessageIds(chatId: chatId),
      ).thenAnswer((_) async => const <int>[]);
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Empty Snapshot',
          contactAddress: 'empty-snapshot@example.com',
        ),
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(
        () => database.trimChatMessages(
          jid: any(named: 'jid'),
          maxMessages: any(named: 'maxMessages'),
          deltaAccountId: any(named: 'deltaAccountId'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: 0,
        ),
      );

      verifyNever(
        () => database.trimChatMessages(
          jid: any(named: 'jid'),
          maxMessages: any(named: 'maxMessages'),
          deltaAccountId: any(named: 'deltaAccountId'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      );
    },
  );

  test(
    'bootstrapFromCore keeps unread cleared while the chat is open',
    () async {
      const chatId = 19;
      const msgId = 103;
      final chat = Chat(
        jid: 'bootstrap-open@example.com',
        title: 'Bootstrap Open',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        open: true,
        unreadCount: 0,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Offline unread email',
        timestamp: DateTime.utc(2024, 1, 2, 6, 7, 8),
      );

      when(() => context.getChatlist()).thenAnswer(
        (_) async => const [DeltaChatlistEntry(chatId: chatId, msgId: msgId)],
      );
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(() => context.getFreshMessageCountSafe(chatId)).thenAnswer(
        (_) async => const DeltaFreshMessageCount(count: 8, supported: true),
      );
      when(
        () => context.getChatMessageIds(chatId: chatId),
      ).thenAnswer((_) async => [msgId]);
      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.bootstrapFromCore();

      final updatedChats = verify(
        () => database.updateChat(captureAny()),
      ).captured.whereType<Chat>().where((updated) => updated.jid == chat.jid);

      expect(updatedChats, isNotEmpty);
      expect(updatedChats.every((updated) => updated.unreadCount == 0), isTrue);
      verify(
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      ).called(1);
    },
  );

  test('does not match a stale pending outgoing email hours later', () async {
    const chatId = 9;
    const msgId = 41;
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    final stalePending = Message(
      stanzaID: 'pending-1',
      senderJid: 'me@example.com',
      chatJid: chat.jid,
      timestamp: DateTime.utc(2024, 1, 1, 9),
      subject: 'Status',
      body: 'ok',
      originID: 'pending-origin',
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
    );
    final deltaTimestamp = DateTime.utc(2024, 1, 1, 15);
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      subject: 'Status',
      text: 'ok',
      timestamp: deltaTimestamp,
      isOutgoing: true,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: chat.jid,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(msgId, chatJid: chat.jid),
    ).thenAnswer((_) async => null);
    when(
      () => database.getPendingOutgoingDeltaMessages(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async => [stalePending]);
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final persisted =
        verify(
              () => database.saveMessage(
                captureAny(),
                selfJid: any(named: 'selfJid'),
              ),
            ).captured.first
            as Message;
    expect(persisted.stanzaID, 'dc-msg-$msgId');
    expect(persisted.timestamp, deltaTimestamp);
    verifyNever(() => database.updateMessage(any()));
  });

  test(
    'matches a pending outgoing email when Delta uses the empty-subject sentinel',
    () async {
      const chatId = 12;
      const msgId = 52;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final pending = Message(
        stanzaID: 'pending-nosubject',
        senderJid: 'me@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 9),
        body: 'Body without subject',
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: '\u2060',
        text: 'Body without subject',
        timestamp: DateTime.utc(2024, 1, 1, 9, 0, 30),
        isOutgoing: true,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.upsertEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(msgId, chatJid: chat.jid),
      ).thenAnswer((_) async => null);
      when(
        () => database.getPendingOutgoingDeltaMessages(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => [pending]);
      when(() => database.updateMessage(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verifyNever(
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      );
      expect(
        verify(() => database.updateMessage(captureAny())).captured.any(
          (value) =>
              value is Message &&
              value.stanzaID == pending.stanzaID &&
              value.deltaMsgId == msgId &&
              value.subject == null,
        ),
        isTrue,
      );
    },
  );

  test(
    'ingests peer emails that match the sync placeholder copy outside the self chat',
    () async {
      const chatId = 21;
      const msgId = 77;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'Multi Device Synchronization',
        text:
            'This message is used to synchronize data between your devices. '
            'Please ignore it.',
        timestamp: DateTime.utc(2024, 1, 2, 3, 4, 5),
        isOutgoing: false,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.upsertEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final persisted =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.single
              as Message;
      expect(persisted.stanzaID, equals('dc-msg-$msgId'));
      expect(persisted.subject, equals(deltaMessage.subject));
      expect(persisted.body, contains('synchronize data between your devices'));
    },
  );

  test(
    'summary repair preserves the existing timestamp when no visible message remains',
    () async {
      const chatId = 22;
      const msgId = 78;
      final chat = Chat(
        jid: 'me@example.com',
        title: 'Saved Messages',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 5, 9),
        lastMessage: 'Old preview',
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Visible text',
        timestamp: DateTime.utc(2024, 1, 6, 10),
        isOutgoing: true,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.upsertEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => database.getChatMessages(
          chat.jid,
          start: 0,
          end: 1,
          filter: MessageTimelineFilter.allWithContact,
        ),
      ).thenAnswer((_) async => const <Message>[]);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      final updatedChat =
          verify(() => database.updateChat(captureAny())).captured.last as Chat;
      expect(updatedChat.lastChangeTimestamp, chat.lastChangeTimestamp);
    },
  );
}
