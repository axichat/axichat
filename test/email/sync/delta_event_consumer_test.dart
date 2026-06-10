import 'dart:io';

import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
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
      core: DeltaContextEventCore(context),
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
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByStanzaID(any()),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(any(), chatJid: any(named: 'chatJid')),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        any(),
        deltaAccountId: any(named: 'deltaAccountId'),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getEmailChatAccountsForAccount(any()),
    ).thenAnswer((_) async => const <EmailChatAccountData>[]);
    when(
      () => database.getDeltaChatIdsForAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
      ),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () => database.getMessageByOriginID(any()),
    ).thenAnswer((_) async => null);
    when(
      () =>
          database.getMessagesByOriginID(any(), chatJid: any(named: 'chatJid')),
    ).thenAnswer((_) async => const <Message>[]);
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
      () => database.updateMessageAttachment(
        stanzaID: any(named: 'stanzaID'),
        metadata: any(named: 'metadata'),
      ),
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
    when(
      () => context.getMessageRfc724Mid(any()),
    ).thenAnswer((_) async => null);
    when(() => context.supportsMessageRfc724Mid).thenReturn(true);
    when(() => context.supportsMessageInfo).thenReturn(true);
    when(() => context.getMessageInfo(any())).thenAnswer((_) async => null);
    when(
      () => context.getMessageIdsByRfc724Mid(any()),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () => context.getMessageRfc822Body(any()),
    ).thenAnswer((_) async => null);
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
    expect(persistedMessage.originID, 'test@example.com');
  });

  test(
    'stores RFC822 body content when native sibling lookup is empty',
    () async {
      const chatId = 7;
      const msgId = 26;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'FWD: Photos',
        text:
            'Date: Jan 1, 2024\n'
            'From: Alice <alice@example.com>\n'
            'To: Me <me@example.com>\n'
            'Subject: Photos',
        timestamp: timestamp,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageIdsByRfc724Mid(msgId),
      ).thenAnswer((_) async => const <int>[]);
      when(() => context.getMessageRfc822Body(msgId)).thenAnswer(
        (_) async => const DeltaMessageRfc822Body(
          plainText: 'Real email body',
          htmlBody: '<p>Real email body</p>',
        ),
      );
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
      expect(persistedMessage.body, 'Real email body');
      expect(persistedMessage.htmlBody, '<p>Real email body</p>');
      expect(persistedMessage.hasRfc822BodyContent, isTrue);
    },
  );

  test(
    'keeps Delta html when RFC822 body reread returns css-only text',
    () async {
      const chatId = 7;
      const msgId = 29;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'Your ride',
        html:
            '<html><body>'
            '<p>Ride complete.</p>'
            '<p>Thanks for riding.</p>'
            '</body></html>',
        timestamp: timestamp,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageIdsByRfc724Mid(msgId),
      ).thenAnswer((_) async => const <int>[]);
      when(() => context.getMessageRfc822Body(msgId)).thenAnswer(
        (_) async => const DeltaMessageRfc822Body(
          plainText:
              'body { margin: 0; padding: 0; } '
              '.button { color: #111111; display: block; }',
        ),
      );
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
      expect(persistedMessage.body, contains('Ride complete.'));
      expect(persistedMessage.body, isNot(contains('margin: 0')));
      expect(persistedMessage.htmlBody, deltaMessage.html);
      expect(persistedMessage.hasRfc822BodyContent, isFalse);
    },
  );

  test('keeps valid RFC822 plain text when Delta also has html', () async {
    const chatId = 7;
    const msgId = 30;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      subject: 'Receipt',
      html: '<html><body><p>Generated Delta body</p></body></html>',
      timestamp: timestamp,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => context.getMessageIdsByRfc724Mid(msgId),
    ).thenAnswer((_) async => const <int>[]);
    when(() => context.getMessageRfc822Body(msgId)).thenAnswer(
      (_) async =>
          const DeltaMessageRfc822Body(plainText: 'Real RFC822 plain body'),
    );
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
    expect(persistedMessage.body, 'Real RFC822 plain body');
    expect(persistedMessage.htmlBody, isNull);
    expect(persistedMessage.hasRfc822BodyContent, isTrue);
  });

  test(
    'preserves existing RFC822 body when split row body cannot be reread',
    () async {
      const chatId = 7;
      const msgId = 27;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        deltaChatId: chatId,
      );
      final existing = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: chat.jid,
        chatJid: chat.jid,
        body: 'Real email body',
        htmlBody: '<p>Real email body</p>',
        pseudoMessageData: const {'emailRfc822Body': true},
        originID: 'test@example.com',
        timestamp: timestamp,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'FWD: Photos',
        text:
            'Date: Jan 1, 2024\n'
            'From: Alice <alice@example.com>\n'
            'To: Me <me@example.com>\n'
            'Subject: Photos',
        timestamp: timestamp,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => '<test@example.com>');
      when(
        () => context.getMessageIdsByRfc724Mid(msgId),
      ).thenAnswer((_) async => const <int>[msgId, msgId + 1]);
      when(
        () => context.getMessageRfc822Body(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => existing);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
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
      expect(updated.body, 'Real email body');
      expect(updated.htmlBody, '<p>Real email body</p>');
      expect(updated.hasRfc822BodyContent, isTrue);
    },
  );

  test('falls back to MIME headers when native RFC724 lookup fails', () async {
    const chatId = 7;
    const msgId = 25;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);

    when(() => context.getMessage(msgId)).thenAnswer(
      (_) async => DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Hello',
        timestamp: timestamp,
      ),
    );
    when(
      () => context.getMessageRfc724Mid(msgId),
    ).thenThrow(const DeltaOperationException('RFC724 lookup unavailable'));
    when(
      () => context.getMessageMimeHeaders(msgId),
    ).thenAnswer((_) async => 'Message-ID: <fallback@example.com>');
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(() => database.createChat(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.incomingMsg.code,
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
    expect(persistedMessage.originID, 'fallback@example.com');
  });

  test(
    'FINER email diagnostics avoid native debug and MIME header fetches',
    () async {
      const chatId = 7;
      const msgId = 126;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final previousHierarchicalLoggingEnabled = hierarchicalLoggingEnabled;
      final previousRootLevel = Logger.root.level;
      hierarchicalLoggingEnabled = true;
      addTearDown(() {
        Logger.root.level = previousRootLevel;
        hierarchicalLoggingEnabled = previousHierarchicalLoggingEnabled;
      });
      final diagnosticLogger = Logger('DeltaEventConsumer.diagnosticsTest')
        ..level = Level.FINER;
      consumer = DeltaEventConsumer(
        databaseBuilder: () async => database,
        core: DeltaContextEventCore(context),
        selfJidProvider: () => 'me@example.com',
        logger: diagnosticLogger,
      );

      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: 'Hello',
          timestamp: timestamp,
        ),
      );
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => '<diagnostic@example.com>');
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
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

      verifyNever(() => context.getMessageDebugInfo(msgId));
      verifyNever(() => context.getMessageMimeHeaders(msgId));
      verify(
        () => database.saveMessage(
          any(
            that: predicate<Message>(
              (message) => message.originID == 'diagnostic@example.com',
            ),
          ),
          selfJid: any(named: 'selfJid'),
        ),
      ).called(1);
    },
  );

  test(
    'downloads partial incoming email files without attachment settings',
    () async {
      const chatId = 7;
      const msgId = 26;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);

      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: 'Photo',
          filePath: '/delta/photo.jpg',
          fileName: 'photo.jpg',
          fileMime: 'image/jpeg',
          fileSize: 4096,
          timestamp: timestamp,
          downloadState: DeltaDownloadState.available,
        ),
      );
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
      when(
        () => context.downloadFullMessage(msgId),
      ).thenAnswer((_) async => true);

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      await untilCalled(() => context.downloadFullMessage(msgId));
      verify(() => context.downloadFullMessage(msgId)).called(1);
    },
  );

  test(
    'does not retry existing missing origins when native RFC724 is unavailable',
    () async {
      const chatId = 7;
      const msgId = 26;
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
        senderJid: chat.jid,
        chatJid: chat.jid,
        body: 'Hello',
        timestamp: timestamp,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );

      when(() => context.supportsMessageRfc724Mid).thenReturn(false);
      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: existing.body,
          timestamp: timestamp,
        ),
      );
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => existing);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verifyNever(() => context.getMessageRfc724Mid(msgId));
      verifyNever(() => context.getMessageInfo(msgId));
      verifyNever(() => context.getMessageMimeHeaders(msgId));
    },
  );

  test(
    'falls back to Delta message info when split part has no MIME headers',
    () async {
      const chatId = 7;
      const msgId = 26;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);

      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          filePath: '/tmp/photo.jpg',
          fileName: 'photo.jpg',
          fileMime: 'image/jpeg',
          fileSize: 123,
          timestamp: timestamp,
        ),
      );
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => null);
      when(() => context.getMessageInfo(msgId)).thenAnswer(
        (_) async =>
            'Sent: 2024-01-02\n'
            'Message-ID: <split@example.com>\n\n'
            'Message-ID: <hop-info@example.com>',
      );
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
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
      expect(persistedMessage.originID, 'split@example.com');
      verifyNever(() => context.getMessageMimeHeaders(msgId));
    },
  );

  test(
    'ignores Message-ID lines from Delta hop info when resolving origin',
    () async {
      const chatId = 7;
      const msgId = 27;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);

      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: 'Hello',
          timestamp: timestamp,
        ),
      );
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => null);
      when(() => context.getMessageInfo(msgId)).thenAnswer(
        (_) async => 'Sent: 2024-01-02\n\nMessage-ID: <hop@example.com>',
      );
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => 'Message-ID: <headers@example.com>');
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
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
      expect(persistedMessage.originID, 'headers@example.com');
    },
  );

  test(
    'does not synthesize native RFC sibling parts from one Delta event',
    () async {
      const chatId = 7;
      const siblingChatId = 8;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final deltaMessages = <int, DeltaMessage>{
        100: DeltaMessage(
          id: 100,
          chatId: chatId,
          text: 'Reply text',
          subject: 'Fwd: Photos',
          timestamp: timestamp,
        ),
        101: DeltaMessage(
          id: 101,
          chatId: chatId,
          filePath: '/tmp/one.jpg',
          fileName: 'one.jpg',
          fileMime: 'image/jpeg',
          fileSize: 123,
          timestamp: timestamp,
        ),
        102: DeltaMessage(
          id: 102,
          chatId: siblingChatId,
          text: 'Forwarded body',
          subject: 'Fwd: Photos',
          timestamp: timestamp,
        ),
        103: DeltaMessage(
          id: 103,
          chatId: siblingChatId,
          filePath: '/tmp/two.jpg',
          fileName: 'two.jpg',
          fileMime: 'image/jpeg',
          fileSize: 456,
          timestamp: timestamp,
        ),
      };
      final savedMessages = <Message>[];

      when(() => context.getMessage(any())).thenAnswer(
        (invocation) async =>
            deltaMessages[invocation.positionalArguments.first as int],
      );
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Alice',
          contactAddress: 'alice@example.com',
        ),
      );
      when(() => context.getMessageMimeHeaders(any())).thenAnswer((
        invocation,
      ) async {
        final msgId = invocation.positionalArguments.first as int;
        return msgId == 100 || msgId == 102
            ? 'Message-ID: <split@example.com>'
            : null;
      });
      when(() => context.getMessageRfc724Mid(any())).thenAnswer((
        invocation,
      ) async {
        final msgId = invocation.positionalArguments.first as int;
        return msgId == 100 || msgId == 102 ? '<split@example.com>' : null;
      });
      when(
        () => context.getMessageIdsByRfc724Mid(any()),
      ).thenAnswer((_) async => const <int>[100, 101, 102, 103]);
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          any(),
          deltaAccountId: any(named: 'deltaAccountId'),
        ),
      ).thenAnswer((invocation) async {
        final deltaMsgId = invocation.positionalArguments.first as int;
        return savedMessages
            .where((message) => message.deltaMsgId == deltaMsgId)
            .firstOrNull;
      });
      when(() => database.createChat(any())).thenAnswer((_) async {});
      when(() => database.updateMessage(any())).thenAnswer((invocation) async {
        final message = invocation.positionalArguments.first as Message;
        final index = savedMessages.indexWhere(
          (saved) => saved.stanzaID == message.stanzaID,
        );
        if (index == -1) {
          savedMessages.add(message);
        } else {
          savedMessages[index] = message;
        }
      });
      when(
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      ).thenAnswer((invocation) async {
        final message = invocation.positionalArguments.first as Message;
        savedMessages.add(message);
      });
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: 100,
        ),
      );

      expect(savedMessages, hasLength(1));
      expect(
        {
          for (final message in savedMessages)
            message.deltaMsgId: message.originID,
        },
        {100: 'split@example.com'},
      );
      expect(
        {
          for (final message in savedMessages)
            message.deltaMsgId: message.deltaChatId,
        },
        {100: chatId},
      );
      verifyNever(() => context.getMessage(101));
      verifyNever(() => context.getMessage(102));
      verifyNever(() => context.getMessage(103));
    },
  );

  test('existing origin updates do not hydrate sibling content', () async {
    const chatId = 7;
    const sourceMsgId = 110;
    const siblingMsgId = 111;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      deltaChatId: chatId,
    );
    final source = Message(
      stanzaID: 'dc-msg-$sourceMsgId',
      senderJid: chat.jid,
      chatJid: chat.jid,
      body: 'Source body',
      originID: 'split@example.com',
      timestamp: timestamp,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: sourceMsgId,
    );
    final sibling = Message(
      stanzaID: 'dc-msg-$siblingMsgId',
      senderJid: chat.jid,
      chatJid: chat.jid,
      body: 'Stable sibling body',
      originID: 'split@example.com',
      timestamp: timestamp,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: siblingMsgId,
    );

    when(() => context.getMessage(sourceMsgId)).thenAnswer(
      (_) async => DeltaMessage(
        id: sourceMsgId,
        chatId: chatId,
        text: 'Source body',
        timestamp: timestamp,
      ),
    );
    when(() => context.getMessage(siblingMsgId)).thenAnswer(
      (_) async => DeltaMessage(
        id: siblingMsgId,
        chatId: chatId,
        text: 'Changed sibling body from core',
        timestamp: timestamp,
      ),
    );
    when(
      () => context.getMessageRfc724Mid(any()),
    ).thenAnswer((_) async => '<split@example.com>');
    when(
      () => context.getMessageIdsByRfc724Mid(sourceMsgId),
    ).thenAnswer((_) async => const <int>[sourceMsgId, siblingMsgId]);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
    when(
      () => database.getMessageByStanzaID('dc-msg-$sourceMsgId'),
    ).thenAnswer((_) async => source);
    when(
      () => database.getMessageByDeltaId(
        any(),
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((invocation) async {
      final deltaMsgId = invocation.positionalArguments.first as int;
      return switch (deltaMsgId) {
        sourceMsgId => source,
        siblingMsgId => sibling,
        _ => null,
      };
    });
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: sourceMsgId,
      ),
    );

    verifyNever(() => context.getMessage(siblingMsgId));
    verifyNever(
      () => database.updateMessage(
        any(
          that: predicate<Message>(
            (message) => message.deltaMsgId == siblingMsgId,
          ),
        ),
      ),
    );
  });

  test(
    'does not match Delta rows by chat JID without the Delta account',
    () async {
      const chatId = 7;
      const msgId = 120;
      final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        deltaChatId: chatId,
      );

      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: 'Fresh body',
          timestamp: timestamp,
        ),
      );
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Alice',
          contactAddress: 'alice@example.com',
        ),
      );
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => '<fresh@example.com>');
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => null);
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

      verifyNever(
        () =>
            database.getMessageByDeltaId(msgId, chatJid: any(named: 'chatJid')),
      );
      verify(
        () => database.saveMessage(
          any(
            that: predicate<Message>(
              (message) =>
                  message.deltaMsgId == msgId &&
                  message.originID == 'fresh@example.com',
            ),
          ),
          selfJid: any(named: 'selfJid'),
        ),
      ).called(1);
    },
  );

  test('origin hydration updates only the matching Delta row', () async {
    const chatId = 7;
    const msgId = 104;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: 'alice@example.com',
      body: 'Hello',
      timestamp: timestamp,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );

    when(() => context.getMessage(msgId)).thenAnswer(
      (_) async => DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Hello',
        timestamp: timestamp,
      ),
    );
    when(
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => '<origin@example.com>');
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => Chat(
        jid: existing.chatJid,
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1),
        transport: MessageTransport.email,
        deltaChatId: chatId,
      ),
    );
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final updated = verify(
      () => database.updateMessage(captureAny()),
    ).captured.whereType<Message>().last;
    expect(updated.stanzaID, existing.stanzaID);
    expect(updated.originID, 'origin@example.com');
    verifyNever(
      () => database.deleteMessage(
        any(),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    );
  });

  test('origin hydration preserves unverifiable stored origins', () async {
    const chatId = 7;
    const msgId = 105;
    final timestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: 'alice@example.com',
      body: '\u{1F4CE} photo.png',
      originID: 'wrong@example.com',
      timestamp: timestamp,
      fileMetadataID: 'photo-metadata',
      pseudoMessageData: const {'emailAttachmentCaption': true},
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );

    when(() => context.getMessage(msgId)).thenAnswer(
      (_) async => DeltaMessage(
        id: msgId,
        chatId: chatId,
        fileName: 'photo.png',
        filePath: '/tmp/photo.png',
        timestamp: timestamp,
      ),
    );
    when(
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => null);
    when(
      () => context.getMessageMimeHeaders(msgId),
    ).thenAnswer((_) async => null);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => Chat(
        jid: existing.chatJid,
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1),
        transport: MessageTransport.email,
        deltaChatId: chatId,
      ),
    );
    when(
      () => database.getMessageByStanzaID('dc-msg-$msgId'),
    ).thenAnswer((_) async => null);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async => existing);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    final updated = verify(
      () => database.updateMessage(captureAny()),
    ).captured.whereType<Message>().last;
    expect(updated.stanzaID, existing.stanzaID);
    expect(updated.originID, existing.originID);
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
        core: DeltaContextEventCore(context),
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
      expect(messages.first.deltaMsgId, msgId);
      expect(
        messages.skip(1).map((message) => message.stanzaID),
        xmppMessages.map((message) => message.stanzaID),
      );
      expect(messages.first.timestamp, emailTimestamp);
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
      expect(rehydratedMessages.first.deltaMsgId, msgId);
      expect(
        rehydratedMessages.skip(1).map((message) => message.stanzaID),
        xmppMessages.map((message) => message.stanzaID),
      );
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
        core: DeltaContextEventCore(context),
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
      core: DeltaContextEventCore(context),
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
    'chatModified maps existing address without stealing active Delta chat',
    () async {
      const chatId = 12;
      const activeChatId = 7;
      final existingChat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: activeChatId,
      );
      when(
        () => database.getChat(existingChat.jid),
      ).thenAnswer((_) async => existingChat);
      when(() => database.updateChat(any())).thenAnswer((_) async {});
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Alice Mail',
          contactAddress: 'alice@example.com',
          contactName: 'Alice Email',
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
          verify(() => database.updateChat(captureAny())).captured.single
              as Chat;
      expect(updatedChat.deltaChatId, activeChatId);
      expect(updatedChat.emailAddress, 'alice@example.com');
      expect(updatedChat.contactDisplayName, 'Alice Email');
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: existingChat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).called(1);
    },
  );

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
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
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
          deltaChatId: chatId,
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
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => database.getDeltaChatIdsForAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.updateChat(any())).thenAnswer((_) async {});
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

  test(
    'outgoing Delta copy does not reclassify an existing XMPP attachment row',
    () async {
      const chatId = 32;
      const msgId = 92;
      final mixedChat = Chat(
        jid: 'alice@axi.im',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        contactJid: 'alice@axi.im',
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
      );
      final xmppMetadata = FileMetadataData(
        id: 'xmpp-photo',
        filename: 'photo.jpg',
        path: '/local/photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 1234,
      );
      final existingXmppAttachment = Message(
        stanzaID: 'xmpp-photo-message',
        senderJid: 'me@example.com',
        chatJid: mixedChat.jid,
        timestamp: DateTime.utc(2024, 1, 2, 9),
        id: 'xmpp-photo-row',
        fileMetadataID: xmppMetadata.id,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        filePath: '/delta/copied/photo',
        fileMime: 'image/jpeg',
        fileSize: 1234,
        timestamp: DateTime.utc(2024, 1, 2, 9, 0, 30),
        isOutgoing: true,
        state: DeltaMessageState.outDelivered,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => mixedChat);
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => null);
      when(
        () => database.getFileMetadata(xmppMetadata.id),
      ).thenAnswer((_) async => xmppMetadata);
      when(
        () => database.getFileMetadata(deltaFileMetadataId(msgId)),
      ).thenAnswer((_) async => null);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
      when(
        () => database.replaceMessageAttachments(
          messageId: existingXmppAttachment.id!,
          fileMetadataIds: any<List<String>>(named: 'fileMetadataIds'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.deleteFileMetadata(xmppMetadata.id),
      ).thenAnswer((_) async {});
      when(() => database.updateMessage(any())).thenAnswer((_) async {});
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verify(
        () => database.saveMessage(
          any(
            that: predicate<Message>(
              (message) =>
                  message.stanzaID != existingXmppAttachment.stanzaID &&
                  message.deltaMsgId == msgId &&
                  message.chatJid == mixedChat.jid,
            ),
          ),
          selfJid: any(named: 'selfJid'),
        ),
      ).called(1);
      verifyNever(
        () => database.updateMessage(
          any(
            that: predicate<Message>(
              (message) =>
                  message.stanzaID == existingXmppAttachment.stanzaID &&
                  message.deltaMsgId == msgId,
            ),
          ),
        ),
      );
    },
  );

  test(
    'incompatible dc-msg stanza collision stores a separate local row',
    () async {
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
      const collision = Message(
        stanzaID: 'dc-msg-93',
        senderJid: 'bob@example.com',
        chatJid: 'bob@example.com',
        body: 'Other account message',
        deltaAccountId: 99,
        deltaChatId: 99,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Actual message',
        timestamp: DateTime.utc(2024, 1, 2, 9),
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
      ).thenAnswer((_) async => collision);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => null);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.handle(
        DeltaCoreEvent(
          type: DeltaEventType.msgsChanged.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      verifyNever(() => database.updateMessage(collision));
      final saved =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.single
              as Message;
      expect(saved.stanzaID, isNot(collision.stanzaID));
      expect(saved.deltaMsgId, msgId);
      expect(saved.deltaChatId, chatId);
      expect(saved.body, 'Actual message');
    },
  );

  test(
    'chatlist snapshot collision does not suppress current Delta message',
    () async {
      const chatId = 34;
      const msgId = 94;
      final chat = Chat(
        jid: 'snapshot-alice@example.com',
        title: 'Snapshot Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      const collision = Message(
        stanzaID: 'dc-msg-94',
        senderJid: 'bob@example.com',
        chatJid: 'bob@example.com',
        body: 'Other snapshot message',
        deltaAccountId: 99,
        deltaChatId: 99,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Current snapshot message',
        timestamp: DateTime.utc(2024, 1, 2, 10),
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
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => collision);
      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(() => context.getFreshMessageCountSafe(chatId)).thenAnswer(
        (_) async => const DeltaFreshMessageCount(count: 0, supported: false),
      );
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.refreshChatlistSnapshot();

      verifyNever(() => database.updateMessage(collision));
      final saved =
          verify(
                () => database.saveMessage(
                  captureAny(),
                  selfJid: any(named: 'selfJid'),
                ),
              ).captured.single
              as Message;
      expect(saved.stanzaID, isNot(collision.stanzaID));
      expect(saved.deltaMsgId, msgId);
      expect(saved.deltaChatId, chatId);
      expect(saved.chatJid, chat.jid);
      expect(saved.body, 'Current snapshot message');
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
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => 'existing-origin');
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
        deltaChatId: chatId,
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

  test(
    'does not preserve stale inbound attachment body when Delta reports subject-only text',
    () async {
      const chatId = 7;
      const msgId = 25;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final metadata = FileMetadataData(
        id: deltaFileMetadataId(msgId),
        filename: 'photo.jpg',
        path: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 123,
      );
      final existing = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'alice@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 8),
        originID: 'existing-origin',
        subject: 'Photos',
        body: 'Actual email body',
        fileMetadataID: metadata.id,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'Photos',
        text: 'Photos',
        filePath: metadata.path,
        fileName: metadata.filename,
        fileMime: metadata.mimeType,
        fileSize: metadata.sizeBytes,
        timestamp: existing.timestamp,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => 'existing-origin');
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => existing);
      when(
        () => database.getFileMetadata(metadata.id),
      ).thenAnswer((_) async => metadata);
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
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
      expect(updated.body, isNull);
    },
  );

  test(
    'allows inbound attachment body to upgrade from subject-only text',
    () async {
      const chatId = 7;
      const msgId = 26;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
      );
      final metadata = FileMetadataData(
        id: deltaFileMetadataId(msgId),
        filename: 'photo.jpg',
        path: '/tmp/photo.jpg',
        mimeType: 'image/jpeg',
        sizeBytes: 123,
      );
      final existing = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'alice@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 8),
        originID: 'existing-origin',
        subject: 'Photos',
        body: 'Photos',
        fileMetadataID: metadata.id,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        subject: 'Photos',
        text: 'Actual email body',
        filePath: metadata.path,
        fileName: metadata.filename,
        fileMime: metadata.mimeType,
        fileSize: metadata.sizeBytes,
        timestamp: existing.timestamp,
      );

      when(
        () => context.getMessage(msgId),
      ).thenAnswer((_) async => deltaMessage);
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => 'existing-origin');
      when(
        () => database.getChatByDeltaChatId(
          chatId,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => chat);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => existing);
      when(
        () => database.getFileMetadata(metadata.id),
      ).thenAnswer((_) async => metadata);
      when(() => database.updateMessage(any())).thenAnswer((_) async {});
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

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
      expect(updated.body, 'Actual email body');
    },
  );

  test('allows inbound attachment body to upgrade to richer text', () async {
    const chatId = 7;
    const msgId = 27;
    final chat = Chat(
      jid: 'alice@example.com',
      title: 'Alice',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2024, 1, 1),
      transport: MessageTransport.email,
      encryptionProtocol: EncryptionProtocol.none,
      deltaChatId: chatId,
    );
    final metadata = FileMetadataData(
      id: deltaFileMetadataId(msgId),
      filename: 'photo.jpg',
      path: '/tmp/photo.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: 123,
    );
    final existing = Message(
      stanzaID: 'dc-msg-$msgId',
      senderJid: 'alice@example.com',
      chatJid: chat.jid,
      timestamp: DateTime.utc(2024, 1, 1, 8),
      originID: 'existing-origin',
      subject: 'Photos',
      body: 'Short preview',
      fileMetadataID: metadata.id,
      deltaAccountId: DeltaAccountDefaults.legacyId,
      deltaChatId: chatId,
      deltaMsgId: msgId,
    );
    final deltaMessage = DeltaMessage(
      id: msgId,
      chatId: chatId,
      subject: 'Photos',
      text: 'A much longer actual email body',
      filePath: metadata.path,
      fileName: metadata.filename,
      fileMime: metadata.mimeType,
      fileSize: metadata.sizeBytes,
      timestamp: existing.timestamp,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => 'existing-origin');
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(
      () => database.getMessageByDeltaId(
        msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
      ),
    ).thenAnswer((_) async => existing);
    when(
      () => database.getFileMetadata(metadata.id),
    ).thenAnswer((_) async => metadata);
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
    when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});

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
    expect(updated.body, 'A much longer actual email body');
  });

  test(
    'preserves outgoing local body and HTML when Delta content is empty',
    () async {
      const chatId = 34;
      const msgId = 94;
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
        senderJid: 'me@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 12),
        body: 'Local body',
        htmlBody: '<p>Local body</p>',
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        timestamp: DateTime.utc(2024, 1, 1, 12, 10),
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
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
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

      final updated = verify(() => database.updateMessage(captureAny()))
          .captured
          .whereType<Message>()
          .lastWhere(
            (message) =>
                message.stanzaID == existing.stanzaID &&
                message.timestamp == deltaMessage.timestamp,
          );
      expect(updated.body, 'Local body');
      expect(updated.htmlBody, '<p>Local body</p>');
    },
  );

  test(
    'uses non-empty Delta body instead of preserved outgoing body',
    () async {
      const chatId = 35;
      const msgId = 95;
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
        senderJid: 'me@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 12),
        body: 'Local body',
        htmlBody: '<p>Local body</p>',
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        text: 'Delta body',
        timestamp: DateTime.utc(2024, 1, 1, 12, 10),
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
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
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

      final updated = verify(() => database.updateMessage(captureAny()))
          .captured
          .whereType<Message>()
          .lastWhere(
            (message) =>
                message.stanzaID == existing.stanzaID &&
                message.timestamp == deltaMessage.timestamp,
          );
      expect(updated.body, 'Delta body');
      expect(updated.htmlBody, isNull);
    },
  );

  test(
    'does not preserve incoming content when Delta content is empty',
    () async {
      const chatId = 36;
      const msgId = 96;
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
        timestamp: DateTime.utc(2024, 1, 1, 12),
        body: 'Existing incoming body',
        htmlBody: '<p>Existing incoming body</p>',
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        timestamp: DateTime.utc(2024, 1, 1, 12, 10),
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
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
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

      final updated = verify(() => database.updateMessage(captureAny()))
          .captured
          .whereType<Message>()
          .lastWhere(
            (message) =>
                message.stanzaID == existing.stanzaID &&
                message.timestamp == deltaMessage.timestamp,
          );
      expect(updated.body, isNull);
      expect(updated.htmlBody, isNull);
    },
  );

  test(
    'does not preserve outgoing local body when Delta supplies HTML content',
    () async {
      const chatId = 37;
      const msgId = 97;
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
        senderJid: 'me@example.com',
        chatJid: chat.jid,
        timestamp: DateTime.utc(2024, 1, 1, 12),
        body: 'Local body',
        htmlBody: '<p>Local body</p>',
        deltaAccountId: DeltaAccountDefaults.legacyId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final deltaMessage = DeltaMessage(
        id: msgId,
        chatId: chatId,
        html: '<img src="cid:empty-text" />',
        timestamp: DateTime.utc(2024, 1, 1, 12, 10),
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
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
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

      final updated = verify(() => database.updateMessage(captureAny()))
          .captured
          .whereType<Message>()
          .lastWhere(
            (message) =>
                message.stanzaID == existing.stanzaID &&
                message.timestamp == deltaMessage.timestamp,
          );
      expect(updated.body, isNull);
      expect(updated.htmlBody, '<img src="cid:empty-text" />');
    },
  );

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
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => 'existing-origin');
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
        deltaChatId: chatId,
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
      core: DeltaContextEventCore(context),
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
      () => context.getMessageRfc724Mid(msgId),
    ).thenAnswer((_) async => 'existing-origin');
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
        deltaChatId: chatId,
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
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => 'existing-origin');
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
      when(() => context.getChat(chatId)).thenAnswer((_) async => null);
      when(
        () => database.getEmailChatAccountsForAccount(
          DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const [
          EmailChatAccountData(
            chatJid: 'alice@axi.im',
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
          ),
        ],
      );
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.trimChatMessages(
          jid: chat.jid,
          maxMessages: 0,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.countEmailChatAccounts(chat.jid),
      ).thenAnswer((_) async => 0);
      when(
        () => database.getDeltaChatIdsForAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.refreshChatlistSnapshot();

      verify(
        () => database.deleteEmailChatAccount(
          chatJid: chat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: chatId,
        ),
      ).called(1);
      verifyNever(() => database.removeChat(chat.jid));
    },
  );

  test(
    'refreshChatlistSnapshot keeps chats transiently missing from the chatlist',
    () async {
      const chatId = 18;
      final chat = Chat(
        jid: 'transient@axi.im',
        title: 'Transient',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.xmpp,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'transient@example.com',
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
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Transient',
          contactAddress: 'transient@example.com',
        ),
      );
      when(
        () => database.getEmailChatAccountsForAccount(
          DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const [
          EmailChatAccountData(
            chatJid: 'transient@axi.im',
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
          ),
        ],
      );
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);
      when(() => database.updateChat(any())).thenAnswer((_) async {});

      await consumer.refreshChatlistSnapshot();

      verifyNever(
        () => database.deleteEmailChatAccount(
          chatJid: any(named: 'chatJid'),
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );
      verifyNever(
        () => database.trimChatMessages(
          jid: any(named: 'jid'),
          maxMessages: any(named: 'maxMessages'),
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      );
      verifyNever(() => database.removeChat(any()));
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
        () => database.getEmailChatAccountsForAccount(
          DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const [
          EmailChatAccountData(
            chatJid: 'alice@example.com',
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
          ),
        ],
      );
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
      verify(
        () => database.repairChatSummaryPreservingTimestamp(chat.jid),
      ).called(greaterThanOrEqualTo(1));
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
        () => database.getEmailChatAccountsForAccount(
          DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const [
          EmailChatAccountData(
            chatJid: 'large-unread@example.com',
            deltaAccountId: DeltaAccountDefaults.legacyId,
            deltaChatId: chatId,
          ),
        ],
      );
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

      verify(
        () => database.repairChatSummaryPreservingTimestamp(chat.jid),
      ).called(greaterThanOrEqualTo(1));
      verifyNever(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) =>
                  updated.jid == chat.jid && updated.unreadCount != 0,
            ),
          ),
        ),
      );
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
      expect(persisted.stanzaID, isNotEmpty);
      expect(persisted.deltaMsgId, msgId);
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

      verify(
        () => database.repairChatSummaryPreservingTimestamp(chat.jid),
      ).called(1);
      verifyNever(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) =>
                  updated.jid == chat.jid &&
                  updated.lastChangeTimestamp.isBefore(
                    chat.lastChangeTimestamp,
                  ),
            ),
          ),
        ),
      );
    },
  );

  test('outgoing echo without a bound row stores a separate row', () async {
    const chatId = 44;
    const msgId = 144;
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
      text: 'Echo body',
      timestamp: DateTime.utc(2024, 1, 2, 9),
      isOutgoing: true,
    );

    when(() => context.getMessage(msgId)).thenAnswer((_) async => deltaMessage);
    when(
      () => database.getChatByDeltaChatId(
        chatId,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => chat);
    when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
    when(() => database.updateChat(any())).thenAnswer((_) async {});

    await consumer.handle(
      DeltaCoreEvent(
        type: DeltaEventType.msgsChanged.code,
        data1: chatId,
        data2: msgId,
      ),
    );

    verifyNever(
      () => database.getPendingOutgoingDeltaMessages(
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    );
    verifyNever(() => database.updateMessage(any()));
    final saved =
        verify(
              () => database.saveMessage(
                captureAny(),
                selfJid: any(named: 'selfJid'),
              ),
            ).captured.single
            as Message;
    expect(saved.deltaMsgId, msgId);
    expect(saved.deltaChatId, chatId);
    expect(saved.body, 'Echo body');
  });
}
