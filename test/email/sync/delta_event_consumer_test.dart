import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
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
      () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
    ).thenAnswer((_) async {});
    when(() => database.deleteMessage(any())).thenAnswer((_) async {});
    when(
      () => database.isEmailAddressBlocked(any()),
    ).thenAnswer((_) async => false);
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
        () => database.getMessageDeltaSnapshot(chat.jid),
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
        () => database.getMessageDeltaSnapshot(chat.jid),
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
}
