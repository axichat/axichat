import 'dart:async';

import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/email_sync_state.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/chat/util/chat_subject_codec.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

class MockEmailDeltaTransport extends Mock implements EmailDeltaTransport {}

class FakeForegroundBridge implements ForegroundTaskBridge {
  final Map<String, ForegroundTaskMessageHandler> _listeners = {};
  final Set<String> _acquiredClients = <String>{};
  final List<List<Object>> sent = [];

  bool isClientAcquired(String clientId) => _acquiredClients.contains(clientId);

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {
    _acquiredClients.add(clientId);
  }

  @override
  Future<void> release(String clientId) async {
    _acquiredClients.remove(clientId);
  }

  @override
  Future<void> send(List<Object> parts) async {
    sent.add(parts);
  }

  @override
  void registerListener(String clientId, ForegroundTaskMessageHandler handler) {
    _listeners[clientId] = handler;
  }

  @override
  void unregisterListener(String clientId) {
    _listeners.remove(clientId);
  }

  void emit(String data) {
    for (final handler in List.of(_listeners.values)) {
      final result = handler(data);
      if (result is Future) {
        fireAndForget(() => result);
      }
    }
  }
}

void main() {
  late MockCredentialStore credentialStore;
  late MockXmppDatabase database;
  late MockNotificationService notificationService;
  late MockEmailDeltaTransport transport;
  late FakeForegroundBridge foregroundBridge;

  late void Function(DeltaCoreEvent) listener;

  setUpAll(() {
    registerFallbackValue(MessageTransport.xmpp);
    registerFallbackValue(MessageNotificationChannel.chat);
    registerFallbackValue(<FutureOr<bool>>[]);
    registerFallbackValue(MessageTimelineFilter.directOnly);
    registerFallbackValue(<String, String>{});
    registerFallbackValue(Duration.zero);
    registerFallbackValue(
      const EmailAttachment(path: '', fileName: '', sizeBytes: 0),
    );
    registerFallbackValue(
      Chat(
        jid: 'fallback@axi.im',
        title: 'Fallback',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(
      MessageShareData(
        shareId: 'fallback',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        participantCount: 0,
      ),
    );
  });

  setUp(() {
    credentialStore = MockCredentialStore();
    database = MockXmppDatabase();
    notificationService = MockNotificationService();
    transport = MockEmailDeltaTransport();
    foregroundBridge = FakeForegroundBridge();
    when(
      () => notificationService.notificationPreviewsEnabled,
    ).thenReturn(true);

    when(() => transport.addEventListener(any())).thenAnswer((invocation) {
      listener =
          invocation.positionalArguments.first as void Function(DeltaCoreEvent);
    });
    when(() => transport.removeEventListener(any())).thenAnswer((_) {});
    when(
      () => transport.events,
    ).thenAnswer((_) => const Stream<DeltaCoreEvent>.empty());
    when(() => transport.selfJid).thenReturn('dc-self@user.delta.chat');
    when(() => transport.accountsSupported).thenReturn(true);
    when(() => transport.accountsActive).thenReturn(false);
    when(
      () => transport.activeAccountId,
    ).thenReturn(DeltaAccountDefaults.legacyId);
    when(
      () => transport.createAccount(),
    ).thenAnswer((_) async => DeltaAccountDefaults.legacyId);
    when(() => transport.accountIds()).thenAnswer((_) async => const <int>[]);
    when(() => transport.ensureAccountSession(any())).thenAnswer((_) async {});
    when(
      () => transport.isConfigured(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => false);
    when(() => transport.isIoRunning).thenReturn(false);
    when(() => transport.start()).thenAnswer((_) async {});
    when(() => transport.stop()).thenAnswer((_) async {});
    when(() => transport.dispose()).thenAnswer((_) async {});
    when(
      () => transport.deconfigureAccount(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async {});
    when(() => transport.deleteStorageArtifacts()).thenAnswer((_) async {});
    when(
      () => transport.deleteStorageArtifacts(
        databasePrefix: any(named: 'databasePrefix'),
      ),
    ).thenAnswer((_) async {});
    when(() => transport.notifyNetworkAvailable()).thenAnswer((_) async {});
    when(() => transport.notifyNetworkLost()).thenAnswer((_) async {});
    when(() => transport.connectivity()).thenAnswer((_) async => 4000);
    when(
      () =>
          transport.refreshChatlistSnapshot(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async {});
    when(
      () => transport.performBackgroundFetch(any()),
    ).thenAnswer((_) async => true);
    when(() => transport.bootstrapFromCore()).thenAnswer((_) async => true);
    when(() => transport.registerPushToken(any())).thenAnswer((_) async {});
    when(
      () => transport.getCoreConfig(any(), accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => null);
    when(() => transport.getCoreConfig(any())).thenAnswer((_) async => null);
    when(
      () => transport.setCoreConfig(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => transport.purgeStockMessages(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async {});
    when(
      () => transport.sendText(
        chatId: any(named: 'chatId'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
        htmlBody: any(named: 'htmlBody'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => transport.sendAttachment(
        chatId: any(named: 'chatId'),
        attachment: any(named: 'attachment'),
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
        htmlCaption: any(named: 'htmlCaption'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => transport.ensureInitialized(
        databasePrefix: any(named: 'databasePrefix'),
        databasePassphrase: any(named: 'databasePassphrase'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => transport.configureAccount(
        address: any(named: 'address'),
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        additional: any(named: 'additional'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => credentialStore.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => credentialStore.delete(key: any(named: 'key')),
    ).thenAnswer((_) async => true);
    when(
      () => credentialStore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => database.getMessageShareById(any()),
    ).thenAnswer((_) async => null);
    when(
      () => database.getParticipantsForShare(any()),
    ).thenAnswer((_) async => const <MessageParticipantData>[]);
    when(
      () => database.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: any(named: 'deltaAccountId'),
        resolvedAddress: any(named: 'resolvedAddress'),
        placeholderJids: any(named: 'placeholderJids'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.removeDeltaPlaceholderDuplicates(
        deltaAccountId: any(named: 'deltaAccountId'),
        placeholderJids: any(named: 'placeholderJids'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getDeltaChatIdForAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.upsertEmailChatAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async {});
    when(() => database.updateChat(any())).thenAnswer((_) async {});
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
    when(() => database.getChat(any())).thenAnswer((_) async => null);
    when(
      () => notificationService.sendNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => notificationService.sendMessageNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
        senderName: any(named: 'senderName'),
        senderKey: any(named: 'senderKey'),
        conversationTitle: any(named: 'conversationTitle'),
        sentAt: any(named: 'sentAt'),
        isGroupConversation: any(named: 'isGroupConversation'),
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: any(named: 'payload'),
        threadKey: any(named: 'threadKey'),
        showPreviewOverride: any(named: 'showPreviewOverride'),
        channel: any(named: 'channel'),
      ),
    ).thenAnswer((_) async {});
  });

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'marks chats as email and raises notifications on incoming events',
    () async {
      const chatId = 7;
      const msgId = 42;
      final message = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        timestamp: DateTime.now(),
        body: 'Hello from email',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final chat = Chat(
        jid: 'dc-$chatId@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: chatId,
        emailAddress: 'peer@example.com',
      );

      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => message);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);

      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      await pumpMicrotasks();
      verifyNever(
        () => notificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        ),
      );

      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsgBunch.code,
          data1: 0,
          data2: 0,
        ),
      );

      await pumpMicrotasks();

      verify(
        () => notificationService.sendMessageNotification(
          title: chat.displayName,
          body: message.body,
          senderName: chat.displayName,
          senderKey: message.senderJid,
          conversationTitle: chat.displayName,
          sentAt: message.timestamp,
          isGroupConversation: false,
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
          threadKey: any(named: 'threadKey'),
          showPreviewOverride: true,
          channel: MessageNotificationChannel.email,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'flushes pending notifications after debounce when no bunch arrives',
    () async {
      const chatId = 9;
      const msgId = 77;
      final message = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        timestamp: DateTime.now(),
        body: 'Queued hello',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final chat = Chat(
        jid: 'dc-$chatId@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: chatId,
        emailAddress: 'peer@example.com',
      );
      when(
        () => database.getMessageByStanzaID('dc-msg-$msgId'),
      ).thenAnswer((_) async => message);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);

      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      addTearDown(service.shutdown);

      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: msgId,
        ),
      );

      await pumpMicrotasks();
      verifyNever(
        () => notificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 600));
      await pumpMicrotasks();

      verify(
        () => notificationService.sendMessageNotification(
          title: chat.displayName,
          body: message.body,
          senderName: chat.displayName,
          senderKey: message.senderJid,
          conversationTitle: chat.displayName,
          sentAt: message.timestamp,
          isGroupConversation: false,
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
          threadKey: any(named: 'threadKey'),
          showPreviewOverride: true,
          channel: MessageNotificationChannel.email,
        ),
      ).called(1);
    },
  );

  test('registerPushToken defers until provisioning completes', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.registerPushToken('token-123');
    verifyNever(() => transport.registerPushToken(any()));

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    verify(() => transport.registerPushToken('token-123')).called(1);
    addTearDown(service.shutdown);
  });

  test('ensureProvisioned configures transport with TLS endpoints', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@axi.im',
      passwordOverride: 'password',
    );

    final capturedAdditional =
        verify(
              () => transport.configureAccount(
                address: any(named: 'address'),
                password: any(named: 'password'),
                displayName: any(named: 'displayName'),
                additional: captureAny(named: 'additional'),
                accountId: any(named: 'accountId'),
              ),
            ).captured.single
            as Map<String, String>;
    expect(
      capturedAdditional,
      equals({
        'show_emails': '2',
        'mdns_enabled': '1',
        'mail_server': 'axi.im',
        'mail_port': '993',
        'mail_security': 'ssl',
        'mail_user': 'alice',
        'send_server': 'axi.im',
        'send_port': '465',
        'send_security': 'ssl',
        'send_user': 'alice',
      }),
    );
    addTearDown(service.shutdown);
  });

  test('handleNetworkAvailable/lost call transport when provisioned', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.handleNetworkAvailable();
    await service.handleNetworkLost();
    verifyNever(() => transport.notifyNetworkAvailable());
    verifyNever(() => transport.notifyNetworkLost());

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    await service.handleNetworkAvailable();
    await service.handleNetworkLost();

    verify(() => transport.notifyNetworkAvailable()).called(1);
    verify(() => transport.notifyNetworkLost()).called(1);

    addTearDown(service.shutdown);
  });

  test('performBackgroundFetch delegates to transport when ready', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    expect(await service.performBackgroundFetch(), isFalse);

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    expect(
      await service.performBackgroundFetch(timeout: const Duration(seconds: 5)),
      isTrue,
    );

    verify(
      () => transport.performBackgroundFetch(const Duration(seconds: 5)),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('foreground keepalive ignored before provisioning', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.setForegroundKeepalive(true);
    await pumpMicrotasks();
    verifyNever(() => transport.start());
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isFalse,
    );
    expect(foregroundBridge.sent, isEmpty);
    addTearDown(service.shutdown);
  });

  test('foreground keepalive performs periodic fetches', () async {
    var fetchCalls = 0;
    var refreshCalls = 0;
    when(() => transport.performBackgroundFetch(any())).thenAnswer((
      invocation,
    ) async {
      fetchCalls++;
      return true;
    });
    when(
      () =>
          transport.refreshChatlistSnapshot(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async {
      refreshCalls++;
    });

    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    await service.setForegroundKeepalive(true);
    await pumpMicrotasks();
    expect(fetchCalls, 1);
    expect(refreshCalls, 1);
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isTrue,
    );

    foregroundBridge.emit(
      '$emailKeepaliveTickPrefix$join${DateTime.now().millisecondsSinceEpoch}',
    );
    await pumpMicrotasks();
    expect(fetchCalls, 2);
    expect(refreshCalls, 2);

    await service.setForegroundKeepalive(false);
    await service.shutdown();
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isFalse,
    );

    foregroundBridge.emit(
      '$emailKeepaliveTickPrefix$join${DateTime.now().millisecondsSinceEpoch}',
    );
    await pumpMicrotasks();
    expect(fetchCalls, 2);
    expect(refreshCalls, 2);
  });

  test('sendAttachment delegates to transport after provisioning', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    final chat = Chat(
      jid: 'dc-5@delta.chat',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 5,
    );
    const attachment = EmailAttachment(
      path: '/tmp/file.txt',
      fileName: 'file.txt',
      sizeBytes: 12,
      mimeType: 'text/plain',
    );

    when(
      () => transport.sendAttachment(
        chatId: chat.deltaChatId!,
        attachment: attachment,
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
        htmlCaption: any(named: 'htmlCaption'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => 77);

    final msgId = await service.sendAttachment(
      chat: chat,
      attachment: attachment,
    );

    expect(msgId, 77);
    verify(
      () => transport.sendAttachment(
        chatId: chat.deltaChatId!,
        attachment: attachment,
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
        htmlCaption: any(named: 'htmlCaption'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test(
    'fanOutSend delivers to multiple recipients and records share metadata',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      final chatA = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Bob',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 1,
        emailAddress: 'bob@example.com',
      );
      final chatB = Chat(
        jid: 'dc-2@delta.chat',
        title: 'Carol',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 2,
        emailAddress: 'carol@example.com',
      );

      when(
        () => database.createMessageShare(
          share: any(named: 'share'),
          participants: any(named: 'participants'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.insertMessageCopy(
          shareId: any(named: 'shareId'),
          dcMsgId: any(named: 'dcMsgId'),
          dcChatId: any(named: 'dcChatId'),
          dcAccountId: any(named: 'dcAccountId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.assignShareOriginator(
          shareId: any(named: 'shareId'),
          originatorDcMsgId: any(named: 'originatorDcMsgId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.getParticipantsForShare(any()),
      ).thenAnswer((_) async => const <MessageParticipantData>[]);
      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => transport.ensureChatForAddress(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((invocation) async {
        final address = invocation.namedArguments[#address] as String;
        return switch (address) {
          'bob@example.com' => chatA.deltaChatId!,
          'carol@example.com' => chatB.deltaChatId!,
          _ => throw StateError('Unexpected address: $address'),
        };
      });
      when(
        () => transport.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer(
        (invocation) async => (invocation.namedArguments[#chatId] as int) + 100,
      );

      final report = await service.fanOutSend(
        targets: [
          FanOutTarget.chat(chat: chatA, shareSignatureEnabled: true),
          FanOutTarget.chat(chat: chatB, shareSignatureEnabled: true),
        ],
        body: 'Hello everyone',
        quotedStanzaId: 'quoted-stanza',
      );

      expect(report.statuses, hasLength(2));
      expect(
        report.statuses.every(
          (status) => status.state == FanOutRecipientState.sent,
        ),
        isTrue,
      );
      final participantsCapture =
          verify(
                () => database.createMessageShare(
                  share: any(named: 'share'),
                  participants: captureAny(named: 'participants'),
                ),
              ).captured.single
              as List<MessageParticipantData>;
      expect(participantsCapture, hasLength(3));
      verify(
        () => transport.sendText(
          chatId: chatA.deltaChatId!,
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: report.shareId,
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: 'quoted-stanza',
          accountId: any(named: 'accountId'),
        ),
      ).called(1);
      verify(
        () => transport.sendText(
          chatId: chatB.deltaChatId!,
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: report.shareId,
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: 'quoted-stanza',
          accountId: any(named: 'accountId'),
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test('ensureProvisioned uses the provided JID for account address', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@axi.im',
      passwordOverride: 'password',
    );

    verify(
      () => credentialStore.write(
        key: any(named: 'key'),
        value: 'alice@axi.im',
      ),
    ).called(1);

    verify(
      () => transport.configureAccount(
        address: 'alice@axi.im',
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        additional: any(named: 'additional'),
        accountId: any(named: 'accountId'),
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test(
    'updatePassword pauses keepalive and reports reconnect pending on configure timeout',
    () async {
      final storedCredentials = <String, String>{};
      when(() => credentialStore.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        return storedCredentials[key.value];
      });
      when(
        () => credentialStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        final value = invocation.namedArguments[#value] as String;
        storedCredentials[key.value] = value;
        return true;
      });
      when(() => credentialStore.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        storedCredentials.remove(key.value);
        return true;
      });

      final capturedConfigurePayloads = <Map<String, String>>[];
      when(
        () => transport.configureAccount(
          address: any(named: 'address'),
          password: any(named: 'password'),
          displayName: any(named: 'displayName'),
          additional: any(named: 'additional'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((invocation) async {
        final password = invocation.namedArguments[#password] as String;
        final additional =
            invocation.namedArguments[#additional] as Map<String, String>;
        capturedConfigurePayloads.add(Map<String, String>.of(additional));
        if (password == 'new-password') {
          throw const DeltaSafeException('Email configuration timed out');
        }
      });

      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@axi.im',
        passwordOverride: 'old-password',
      );
      await service.setForegroundKeepalive(true);
      foregroundBridge.sent.clear();

      final result = await service.updatePassword(
        jid: 'alice@axi.im',
        displayName: 'Alice',
        password: 'new-password',
      );

      final currentAccount = await service.currentAccount('alice@axi.im');
      expect(result, EmailPasswordRefreshResult.reconnectPending);
      expect(service.activeAccount, isNotNull);
      expect(service.activeAccount!.password, 'new-password');
      expect(currentAccount, isNotNull);
      expect(currentAccount!.password, 'new-password');
      expect(service.syncState.status, EmailSyncStatus.recovering);
      expect(capturedConfigurePayloads, hasLength(2));
      expect(capturedConfigurePayloads.last['send_pw'], 'new-password');
      expect(
        foregroundBridge.sent,
        containsAllInOrder([
          [emailKeepalivePrefix, emailKeepaliveStopCommand],
          predicate<List<Object>>(
            (message) =>
                message.length == 3 &&
                message[0] == emailKeepalivePrefix &&
                message[1] == emailKeepaliveStartCommand,
          ),
        ]),
      );

      verifyInOrder([
        () => transport.stop(),
        () => transport.configureAccount(
          address: 'alice@axi.im',
          password: 'new-password',
          displayName: 'Alice',
          additional: any(named: 'additional'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
        () => transport.start(),
      ]);

      addTearDown(service.shutdown);
    },
  );

  test('shutdown only clears scoped credentials when requested', () async {
    final deletedKeys = <String>[];
    when(() => credentialStore.delete(key: any(named: 'key'))).thenAnswer((
      invocation,
    ) async {
      final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
      deletedKeys.add(key.value);
      return true;
    });

    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );

    expect(service.hasActiveSession, isTrue);
    expect(service.hasInMemoryReconnectContext, isTrue);
    expect(service.activeAccount, isNotNull);

    await service.shutdown(jid: 'bob@axi.im');
    expect(service.hasActiveSession, isFalse);
    expect(service.hasInMemoryReconnectContext, isFalse);
    expect(service.activeAccount, isNull);
    expect(service.sessionCredentials, isNull);
    expect(deletedKeys, isEmpty);

    await service.shutdown(jid: 'bob@axi.im', clearCredentials: true);

    expect(deletedKeys.length, greaterThanOrEqualTo(2));
    expect(deletedKeys.every((key) => key.contains('bob@axi.im')), isTrue);
  });

  test(
    'shutdown detaches the Delta listener before stopping transport',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      await service.shutdown(jid: 'bob@axi.im');

      verifyInOrder([
        () => transport.removeEventListener(any()),
        () => transport.stop(),
        () => transport.dispose(),
      ]);
    },
  );

  test('queued Delta connectivity work is dropped once stop begins', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );

    listener(
      DeltaCoreEvent(
        type: DeltaEventType.connectivityChanged.code,
        data1: 0,
        data2: 0,
      ),
    );

    clearInteractions(transport);
    await service.stop();
    await pumpMicrotasks();

    verifyNever(() => transport.connectivity());
    await service.shutdown(jid: 'bob@axi.im');
  });

  test('handleNetworkAvailable wakes a provisioned stopped service', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );

    await service.stop();
    clearInteractions(transport);
    await service.handleNetworkAvailable();

    verifyInOrder([
      () => transport.addEventListener(any()),
      () => transport.start(),
      () => transport.notifyNetworkAvailable(),
    ]);
    await service.shutdown(jid: 'bob@axi.im');
  });

  test(
    'working connectivity does not downgrade a ready sync state after grace',
    () async {
      when(() => credentialStore.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        if (key.value.contains('email_bootstrap_v1')) {
          return 'true';
        }
        return null;
      });

      var connectivityCalls = 0;
      when(() => transport.connectivity()).thenAnswer((_) async {
        connectivityCalls++;
        if (connectivityCalls == 1) {
          return 1000;
        }
        return 3000;
      });

      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      try {
        await service.ensureProvisioned(
          displayName: 'Bob',
          databasePrefix: 'bob',
          databasePassphrase: 'secret',
          jid: 'bob@axi.im',
          passwordOverride: 'password',
        );
        expect(service.syncState.status, EmailSyncStatus.ready);

        listener(
          DeltaCoreEvent(
            type: DeltaEventType.connectivityChanged.code,
            data1: 0,
            data2: 0,
          ),
        );
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.ready);

        await Future<void>.delayed(const Duration(milliseconds: 2300));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.ready);
        expect(connectivityCalls, greaterThanOrEqualTo(2));
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'reconnect restart reattaches listener and reruns recovery after offline restart',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      await service.handleNetworkAvailable();
      clearInteractions(transport);
      when(() => transport.connectivity()).thenAnswer((_) async => 1000);

      await service.handleNetworkAvailable();
      await Future<void>.delayed(const Duration(milliseconds: 2200));
      await pumpMicrotasks();

      verify(() => transport.removeEventListener(any())).called(1);
      verify(() => transport.stop()).called(1);
      verify(() => transport.addEventListener(any())).called(1);
      verify(() => transport.start()).called(1);
      verify(() => transport.notifyNetworkAvailable()).called(2);

      await service.shutdown(jid: 'bob@axi.im');
    },
  );

  test(
    'handleNetworkLost notifies transport while provisioned but stopped',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      await service.stop();
      clearInteractions(transport);
      await service.handleNetworkLost();

      verify(() => transport.notifyNetworkLost()).called(1);
      verifyNever(() => transport.start());
      await service.shutdown(jid: 'bob@axi.im');
    },
  );

  test('shutdown blocks re-entry while dispose is in flight', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );
    await service.ensureEventChannelActive();

    clearInteractions(transport);
    final disposeCompleter = Completer<void>();
    when(() => transport.dispose()).thenAnswer((_) => disposeCompleter.future);

    final shutdownFuture = service.shutdown(jid: 'bob@axi.im');
    await untilCalled(() => transport.dispose());

    await service.ensureEventChannelActive();
    await service.handleNetworkAvailable();

    verifyNever(() => transport.addEventListener(any()));
    verifyNever(() => transport.start());
    verifyNever(() => transport.notifyNetworkAvailable());

    disposeCompleter.complete();
    await shutdownFuture;
  });

  test('burn blocks re-entry while dispose is in flight', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );
    await service.ensureEventChannelActive();

    clearInteractions(transport);
    final disposeCompleter = Completer<void>();
    when(() => transport.dispose()).thenAnswer((_) => disposeCompleter.future);

    final burnFuture = service.burn(jid: 'bob@axi.im');
    await untilCalled(() => transport.dispose());

    await service.ensureEventChannelActive();
    await service.handleNetworkAvailable();

    verifyNever(() => transport.addEventListener(any()));
    verifyNever(() => transport.start());
    verifyNever(() => transport.notifyNetworkAvailable());

    disposeCompleter.complete();
    await burnFuture;
  });

  test('burn clears in-memory session credentials', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );
    service.cacheSessionCredentials(
      address: 'bob@axi.im',
      password: 'password',
    );

    await service.burn(jid: 'bob@axi.im');

    expect(service.hasActiveSession, isFalse);
    expect(service.activeAccount, isNull);
    expect(service.sessionCredentials, isNull);
  });

  test(
    'burn deletes storage artifacts for an explicit database prefix',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.burn(jid: 'bob@axi.im', databasePrefix: 'bob');

      verify(
        () => transport.deleteStorageArtifacts(databasePrefix: 'bob'),
      ).called(1);
    },
  );

  test(
    'fanOutSend preserves participant count when retrying a subset',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      const shareId = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
      final createdAt = DateTime.utc(2024, 5, 4);
      final existingShare = MessageShareData(
        shareId: shareId,
        originatorDcMsgId: 41,
        subjectToken: '01HX5R8W7YAYR5K1R7Q7MB5G4W',
        createdAt: createdAt,
        participantCount: 3,
      );
      when(
        () => database.getMessageShareById(shareId),
      ).thenAnswer((_) async => existingShare);

      final chatAlice = Chat(
        jid: 'dc-1@delta.chat',
        title: 'Bob',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 1,
        emailAddress: 'bob@example.com',
      );
      final chatBob = Chat(
        jid: 'dc-2@delta.chat',
        title: 'Carol',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 2,
        emailAddress: 'carol@example.com',
      );

      final existingParticipants = [
        const MessageParticipantData(
          shareId: shareId,
          contactJid: 'dc-self@user.delta.chat',
          role: MessageParticipantRole.sender,
        ),
        MessageParticipantData(
          shareId: shareId,
          contactJid: chatAlice.jid,
          role: MessageParticipantRole.recipient,
        ),
        MessageParticipantData(
          shareId: shareId,
          contactJid: chatBob.jid,
          role: MessageParticipantRole.recipient,
        ),
      ];

      when(
        () => database.getParticipantsForShare(shareId),
      ).thenAnswer((_) async => existingParticipants);
      final capturedShares = <MessageShareData>[];
      final capturedParticipants = <List<MessageParticipantData>>[];
      when(
        () => database.createMessageShare(
          share: captureAny(named: 'share'),
          participants: captureAny(named: 'participants'),
        ),
      ).thenAnswer((invocation) async {
        capturedShares.add(
          invocation.namedArguments[#share] as MessageShareData,
        );
        capturedParticipants.add(
          List<MessageParticipantData>.from(
            invocation.namedArguments[#participants] as List,
          ),
        );
      });

      when(
        () => transport.sendText(
          chatId: chatBob.deltaChatId!,
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 202);

      await service.fanOutSend(
        targets: [
          FanOutTarget.chat(chat: chatBob, shareSignatureEnabled: true),
        ],
        body: 'Retrying Carol only',
        shareId: shareId,
      );

      expect(capturedShares.single.shareId, shareId);
      expect(capturedShares.single.participantCount, 3);
      expect(capturedParticipants.single.map((p) => p.contactJid).toSet(), {
        'dc-self@user.delta.chat',
        chatAlice.jid,
        chatBob.jid,
      });

      addTearDown(service.shutdown);
    },
  );

  test(
    'shareContextForMessage returns null when message lacks delta id',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      final message = Message(
        stanzaID: 'dc-msg-15',
        senderJid: 'dc-self@delta.chat',
        chatJid: 'dc-1@delta.chat',
        timestamp: DateTime.now(),
        body: 'Fan-out body',
        encryptionProtocol: EncryptionProtocol.none,
      );

      final result = await service.shareContextForMessage(message);

      expect(result, isNull);
      verifyNever(() => database.getShareIdForDeltaMessage(any()));

      addTearDown(service.shutdown);
    },
  );

  test('sendMessage resolves direct chats by recipient address', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    when(
      () => transport.isConfigured(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => true);
    when(
      () => transport.ensureChatForAddress(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => 91);

    final chat = Chat(
      jid: 'peer@axi.im',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      deltaChatId: 88,
      emailAddress: 'peer@example.com',
      emailFromAddress: 'alice@example.org',
    );

    await service.sendMessage(chat: chat, body: 'First send');

    verify(
      () => transport.ensureChatForAddress(
        address: 'peer@example.com',
        displayName: 'Peer',
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).called(1);
    verify(
      () => transport.sendText(
        chatId: 91,
        body: 'First send',
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
        htmlBody: any(named: 'htmlBody'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test(
    'sendMessage normalizes direct recipient addresses to bare JIDs',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => transport.ensureChatForAddress(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 91);

      final chat = Chat(
        jid: 'peer@axi.im/resource',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        contactJid: 'peer@example.com/resource',
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'First send');

      verify(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'sendReply synthesizes a visible reply for non-delta quoted messages',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => transport.ensureChatForAddress(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 88);
      when(
        () => database.createMessageShare(
          share: any(named: 'share'),
          participants: any(named: 'participants'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.assignShareOriginator(
          shareId: any(named: 'shareId'),
          originatorDcMsgId: any(named: 'originatorDcMsgId'),
        ),
      ).thenAnswer((_) async {});

      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final quotedMessage = Message(
        stanzaID: 'quoted-xmpp-stanza',
        senderJid: 'peer@axi.im',
        chatJid: chat.jid,
        body: ChatSubjectCodec.composeXmppBody(
          body: 'Original body',
          subject: 'Original subject',
        ),
        timestamp: DateTime.now(),
      );
      final syntheticReply = syntheticReplyEnvelope(
        body: 'Reply body',
        subject: null,
        quotedSubject: 'Original subject',
        quotedBody: 'Original body',
        quotedSenderLabel: 'peer@axi.im',
      );

      await service.sendReply(
        chat: chat,
        body: 'Reply body',
        quotedMessage: quotedMessage,
      );

      verify(
        () => transport.sendText(
          chatId: 88,
          body: syntheticReply.body,
          subject: syntheticReply.subject,
          shareId: any(named: 'shareId'),
          localBodyOverride: syntheticReply.body,
          htmlBody: HtmlContentCodec.fromPlainText(syntheticReply.body),
          quotingStanzaId: 'quoted-xmpp-stanza',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'sendReply strips the legacy synthetic forward subject marker',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => transport.ensureChatForAddress(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 88);
      when(
        () => transport.sendTextWithQuote(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          quotedMessageId: any(named: 'quotedMessageId'),
          quotedStanzaId: any(named: 'quotedStanzaId'),
          subject: any(named: 'subject'),
          htmlBody: any(named: 'htmlBody'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 1);

      final chat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final quotedMessage = Message(
        stanzaID: 'quoted-stanza',
        senderJid: 'peer@axi.im',
        chatJid: chat.jid,
        body: 'Forwarded content',
        timestamp: DateTime.now(),
        deltaMsgId: 77,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        subject: markSyntheticForwardSubject('FWD: peer@axi.im'),
      );

      await service.sendReply(
        chat: chat,
        body: 'Reply body',
        quotedMessage: quotedMessage,
      );

      verify(
        () => transport.sendTextWithQuote(
          chatId: 88,
          body: 'Reply body',
          quotedMessageId: 77,
          quotedStanzaId: 'quoted-stanza',
          subject: 'Re: FWD: peer@axi.im',
          htmlBody: any(named: 'htmlBody'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'sendMessage rehydrates stale delta chats before resolving by address',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => database.getChatByDeltaChatId(
          88,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => Chat(
          jid: 'peer@example.com',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          deltaChatId: 88,
          emailAddress: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 99);

      final chat = Chat(
        jid: 'dc-88@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'First send');

      verify(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verify(
        () => transport.sendText(
          chatId: 99,
          body: 'First send',
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verify(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) =>
                  updated.jid == 'peer@example.com' &&
                  updated.deltaChatId == 99,
            ),
          ),
        ),
      ).called(1);
      verifyNever(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) => updated.jid == 'dc-88@delta.chat',
            ),
          ),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'sendMessage repairs synthetic stored email addresses after resolution',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(() => database.getChat('peer@example.com')).thenAnswer(
        (_) async => Chat(
          jid: 'peer@example.com',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          deltaChatId: 88,
          contactJid: 'peer@example.com',
          emailAddress: 'chat-88@delta.chat',
          emailFromAddress: 'alice@example.org',
        ),
      );
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 91);

      final chat = Chat(
        jid: 'dc-88@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        contactJid: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'First send');

      verify(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) =>
                  updated.jid == 'peer@example.com' &&
                  updated.emailAddress == 'peer@example.com' &&
                  updated.deltaChatId == 91,
            ),
          ),
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'getFreshMessageCount rehydrates direct chats by recipient address',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(() => database.getChat('peer@example.com')).thenAnswer(
        (_) async => Chat(
          jid: 'peer@example.com',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          transport: MessageTransport.email,
          contactJid: 'peer@example.com',
          emailAddress: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 91);
      when(
        () => transport.getFreshMessageCount(
          91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 3);

      final count = await service.getFreshMessageCount(
        Chat(
          jid: 'peer@axi.im',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          contactJid: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );

      expect(count, 3);
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ).called(1);
      verifyNever(
        () => database.upsertEmailChatAccount(
          chatJid: 'peer@axi.im',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'getFreshMessageCount falls back to stored mapping when direct resolution fails',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => database.getDeltaChatIdForAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 77);
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenThrow(const DeltaSafeException('chat lookup failed'));
      when(
        () => transport.getFreshMessageCount(
          77,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 5);

      final count = await service.getFreshMessageCount(
        Chat(
          jid: 'peer@example.com',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          emailAddress: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );

      expect(count, 5);
      verify(
        () => transport.getFreshMessageCount(
          77,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'markNoticedChat clears unread count on the canonical direct chat row',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      final storedChat = Chat(
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        contactJid: 'peer@example.com',
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
        unreadCount: 3,
      );

      when(
        () => database.getChat('peer@example.com'),
      ).thenAnswer((_) async => storedChat);
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 91);
      when(
        () => transport.markNoticedChat(
          91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => true);

      final noticed = await service.markNoticedChat(
        Chat(
          jid: 'dc-91@delta.chat',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          contactJid: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );

      expect(noticed, isTrue);
      verify(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) =>
                  updated.jid == 'peer@example.com' && updated.unreadCount == 0,
            ),
          ),
        ),
      ).called(1);
      verifyNever(
        () => database.updateChat(
          any(
            that: predicate<Chat>(
              (Chat updated) => updated.jid == 'dc-91@delta.chat',
            ),
          ),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'searchMessages does not widen chat-scoped searches when chat resolution fails',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.searchMessages(
          chatId: any(named: 'chatId'),
          query: any(named: 'query'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => const <int>[]);

      final results = await service.searchMessages(
        chat: Chat(
          jid: 'dc-88@delta.chat',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          emailFromAddress: 'alice@example.org',
        ),
        query: 'needle',
      );

      expect(results, isEmpty);
      verifyNever(
        () => transport.searchMessages(
          chatId: 0,
          query: 'needle',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'backfillChatHistory uses the canonical direct chat row after rehydration',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(() => database.getChat('peer@example.com')).thenAnswer(
        (_) async => Chat(
          jid: 'peer@example.com',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          contactJid: 'peer@example.com',
          emailAddress: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
      );
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 91);
      when(
        () => database.countChatMessages(
          'peer@example.com',
          filter: MessageTimelineFilter.directOnly,
          includePseudoMessages: false,
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => transport.backfillChatHistory(
          chatId: any(named: 'chatId'),
          chatJid: any(named: 'chatJid'),
          desiredWindow: any(named: 'desiredWindow'),
          beforeMessageId: any(named: 'beforeMessageId'),
          beforeTimestamp: any(named: 'beforeTimestamp'),
          filter: any(named: 'filter'),
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async {});

      await service.backfillChatHistory(
        chat: Chat(
          jid: 'dc-91@delta.chat',
          title: 'Peer',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          transport: MessageTransport.email,
          contactJid: 'peer@example.com',
          emailFromAddress: 'alice@example.org',
        ),
        desiredWindow: 5,
        beforeMessageId: 42,
      );

      verify(
        () => database.countChatMessages(
          'peer@example.com',
          filter: MessageTimelineFilter.directOnly,
          includePseudoMessages: false,
        ),
      ).called(1);
      verifyNever(
        () => database.countChatMessages(
          'dc-91@delta.chat',
          filter: any(named: 'filter'),
          includePseudoMessages: any(named: 'includePseudoMessages'),
        ),
      );
      verify(
        () => transport.backfillChatHistory(
          chatId: 91,
          chatJid: 'peer@example.com',
          desiredWindow: 5,
          beforeMessageId: 42,
          beforeTimestamp: null,
          filter: MessageTimelineFilter.directOnly,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'shareContextForMessage returns null when share row is missing',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      final message = Message(
        stanzaID: 'dc-msg-15',
        senderJid: 'dc-self@delta.chat',
        chatJid: 'dc-1@delta.chat',
        timestamp: DateTime.now(),
        body: 'Fan-out body',
        encryptionProtocol: EncryptionProtocol.none,
        deltaMsgId: 15,
      );

      when(
        () => database.getShareIdForDeltaMessage(15),
      ).thenAnswer((_) async => null);

      final result = await service.shareContextForMessage(message);

      expect(result, isNull);
      verify(() => database.getShareIdForDeltaMessage(15)).called(1);
      verifyNever(() => database.getParticipantsForShare(any()));

      addTearDown(service.shutdown);
    },
  );

  test('shareContextForMessage resolves participants from database', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.org',
      passwordOverride: 'password',
    );

    final message = Message(
      stanzaID: 'dc-msg-15',
      senderJid: 'dc-self@delta.chat',
      chatJid: 'dc-1@delta.chat',
      timestamp: DateTime.now(),
      body: 'Fan-out body',
      encryptionProtocol: EncryptionProtocol.none,
      deltaMsgId: 15,
    );
    const participant = MessageParticipantData(
      shareId: 'share-1',
      contactJid: 'dc-1@delta.chat',
      role: MessageParticipantRole.recipient,
    );

    when(
      () => database.getShareIdForDeltaMessage(15),
    ).thenAnswer((_) async => 'share-1');
    when(
      () => database.getParticipantsForShare('share-1'),
    ).thenAnswer((_) async => [participant]);
    when(() => database.getChat('dc-1@delta.chat')).thenAnswer(
      (_) async => Chat(
        jid: 'dc-1@delta.chat',
        title: 'Bob',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
      ),
    );

    final contextResult = await service.shareContextForMessage(message);

    expect(contextResult, isNotNull);
    expect(contextResult!.participants, hasLength(1));
    expect(contextResult.participants.first.title, 'Bob');

    addTearDown(service.shutdown);
  });
}
