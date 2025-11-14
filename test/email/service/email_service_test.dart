import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/service/fan_out_models.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:fake_async/fake_async.dart';
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
  void registerListener(
    String clientId,
    ForegroundTaskMessageHandler handler,
  ) {
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
        unawaited(result);
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
    registerFallbackValue(<FutureOr<bool>>[]);
    registerFallbackValue(MessageTimelineFilter.directOnly);
  });

  setUp(() {
    credentialStore = MockCredentialStore();
    database = MockXmppDatabase();
    notificationService = MockNotificationService();
    transport = MockEmailDeltaTransport();
    foregroundBridge = FakeForegroundBridge();

    when(() => transport.addEventListener(any())).thenAnswer((invocation) {
      listener =
          invocation.positionalArguments.first as void Function(DeltaCoreEvent);
    });
    when(() => transport.removeEventListener(any())).thenAnswer((_) {});
    when(() => transport.events)
        .thenAnswer((_) => const Stream<DeltaCoreEvent>.empty());
    when(() => transport.selfJid).thenReturn('dc-self@user.delta.chat');
    when(() => transport.start()).thenAnswer((_) async {});
    when(() => transport.stop()).thenAnswer((_) async {});
    when(() => transport.notifyNetworkAvailable()).thenAnswer((_) async {});
    when(() => transport.notifyNetworkLost()).thenAnswer((_) async {});
    when(() => transport.performBackgroundFetch(any()))
        .thenAnswer((_) async => true);
    when(() => transport.registerPushToken(any())).thenAnswer((_) async {});
    when(
      () => transport.sendText(
        chatId: any(named: 'chatId'),
        body: any(named: 'body'),
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => transport.sendAttachment(
        chatId: any(named: 'chatId'),
        attachment: any(named: 'attachment'),
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
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
      ),
    ).thenAnswer((_) async {});
    when(() => credentialStore.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(() => credentialStore.delete(key: any(named: 'key')))
        .thenAnswer((_) async => true);
    when(
      () => credentialStore.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async => true);
    when(() => notificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async {});
  });

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
  }

  test('marks chats as email and raises notifications on incoming events',
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

    when(() => database.getMessageByStanzaID('dc-msg-$msgId'))
        .thenAnswer((_) async => message);
    when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);

    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    listener(
      const DeltaCoreEvent(
        type: DeltaEventType.incomingMsg,
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
      const DeltaCoreEvent(
        type: DeltaEventType.incomingMsgBunch,
        data1: 0,
        data2: 0,
      ),
    );

    await pumpMicrotasks();

    verify(
      () => notificationService.sendNotification(
        title: chat.title,
        body: message.body,
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: chat.jid,
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('flushes pending notifications after debounce when no bunch arrives',
      () {
    fakeAsync((async) {
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
      when(() => database.getMessageByStanzaID('dc-msg-$msgId'))
          .thenAnswer((_) async => message);
      when(() => database.getChat(chat.jid)).thenAnswer((_) async => chat);

      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      );

      listener(
        const DeltaCoreEvent(
          type: DeltaEventType.incomingMsg,
          data1: chatId,
          data2: msgId,
        ),
      );

      async.flushMicrotasks();
      verifyNever(
        () => notificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        ),
      );

      async.elapse(const Duration(milliseconds: 600));
      async.flushMicrotasks();

      verify(
        () => notificationService.sendNotification(
          title: chat.title,
          body: message.body,
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: chat.jid,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    });
  });

  test('setClientState keeps IO in sync with app lifecycle', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
    );

    await service.start();
    verify(() => transport.start()).called(1);

    await service.setClientState(false);
    verify(() => transport.stop()).called(1);

    await service.setClientState(true);
    verify(() => transport.start()).called(2);

    addTearDown(service.shutdown);
  });

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
    );

    verify(() => transport.registerPushToken('token-123')).called(1);
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
    );

    expect(
      await service.performBackgroundFetch(
        timeout: const Duration(seconds: 5),
      ),
      isTrue,
    );

    verify(
      () => transport.performBackgroundFetch(
        const Duration(seconds: 5),
      ),
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
    verifyNever(() => transport.start());
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isFalse,
    );
    expect(foregroundBridge.sent, isEmpty);
    addTearDown(service.shutdown);
  });

  test('foreground keepalive performs periodic fetches', () async {
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
    );

    await service.setForegroundKeepalive(true);
    verify(() => transport.performBackgroundFetch(any())).called(1);
    clearInteractions(transport);
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isTrue,
    );

    foregroundBridge.emit(
      '$emailKeepaliveTickPrefix$join${DateTime.now().millisecondsSinceEpoch}',
    );
    await pumpMicrotasks();
    verify(() => transport.performBackgroundFetch(any())).called(1);
    clearInteractions(transport);

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
    verifyNever(() => transport.performBackgroundFetch(any()));
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
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
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
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('fanOutSend delivers to multiple recipients and records share metadata',
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
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.assignShareOriginator(
        shareId: any(named: 'shareId'),
        originatorDcMsgId: any(named: 'originatorDcMsgId'),
      ),
    ).thenAnswer((_) async {});
    when(() => database.getParticipantsForShare(any()))
        .thenAnswer((_) async => const <MessageParticipantData>[]);
    when(
      () => transport.sendText(
        chatId: any(named: 'chatId'),
        body: any(named: 'body'),
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
      ),
    ).thenAnswer(
      (invocation) async => (invocation.namedArguments[#chatId] as int) + 100,
    );

    final report = await service.fanOutSend(
      targets: [FanOutTarget.chat(chatA), FanOutTarget.chat(chatB)],
      body: 'Hello everyone',
    );

    expect(report.statuses, hasLength(2));
    expect(
        report.statuses
            .every((status) => status.state == FanOutRecipientState.sent),
        isTrue);
    final participantsCapture = verify(
      () => database.createMessageShare(
        share: any(named: 'share'),
        participants: captureAny(named: 'participants'),
      ),
    ).captured.single as List<MessageParticipantData>;
    expect(participantsCapture, hasLength(3));
    verify(
      () => transport.sendText(
        chatId: chatA.deltaChatId!,
        body: any(named: 'body'),
        shareId: report.shareId,
        localBodyOverride: any(named: 'localBodyOverride'),
      ),
    ).called(1);
    verify(
      () => transport.sendText(
        chatId: chatB.deltaChatId!,
        body: any(named: 'body'),
        shareId: report.shareId,
        localBodyOverride: any(named: 'localBodyOverride'),
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('ensureProvisioned scopes credentials per jid and domain', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      chatmailDomain: 'chatmail.example',
    );

    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@axi.im',
    );

    verify(
      () => credentialStore.write(
        key: any(named: 'key'),
        value: 'alice@chatmail.example',
      ),
    ).called(1);

    verify(
      () => transport.configureAccount(
        address: 'alice@chatmail.example',
        password: any(named: 'password'),
        displayName: any(named: 'displayName'),
        additional: any(named: 'additional'),
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test('shutdown only clears scoped credentials when requested', () async {
    final deletedKeys = <String>[];
    when(() => credentialStore.delete(key: any(named: 'key'))).thenAnswer(
      (invocation) async {
        final key = invocation.namedArguments[#key] as RegisteredCredentialKey;
        deletedKeys.add(key.value);
        return true;
      },
    );

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
    );

    await service.shutdown(jid: 'bob@axi.im');
    expect(deletedKeys, isEmpty);

    await service.shutdown(jid: 'bob@axi.im', clearCredentials: true);

    expect(deletedKeys.length, greaterThanOrEqualTo(2));
    expect(deletedKeys.every((key) => key.contains('bob@axi.im')), isTrue);
  });

  test('fanOutSend preserves participant count when retrying a subset',
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
    );

    const shareId = '01HX5R8W7YAYR5K1R7Q7MB5G4W';
    final createdAt = DateTime.utc(2024, 5, 4);
    final existingShare = MessageShareData(
      shareId: shareId,
      originatorDcMsgId: 41,
      subjectToken: '[s:1234]',
      createdAt: createdAt,
      participantCount: 3,
    );
    when(() => database.getMessageShareById(shareId))
        .thenAnswer((_) async => existingShare);

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
        contactJid: 'dc-self@delta.chat',
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

    when(() => database.getParticipantsForShare(shareId))
        .thenAnswer((_) async => existingParticipants);
    final capturedShares = <MessageShareData>[];
    final capturedParticipants = <List<MessageParticipantData>>[];
    when(
      () => database.createMessageShare(
        share: captureAny(named: 'share'),
        participants: captureAny(named: 'participants'),
      ),
    ).thenAnswer((invocation) async {
      capturedShares.add(invocation.namedArguments[#share] as MessageShareData);
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
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
      ),
    ).thenAnswer((_) async => 202);

    await service.fanOutSend(
      targets: [FanOutTarget.chat(chatBob)],
      body: 'Retrying Carol only',
      shareId: shareId,
    );

    expect(capturedShares.single.shareId, shareId);
    expect(capturedShares.single.participantCount, 3);
    expect(capturedParticipants.single.map((p) => p.contactJid).toSet(), {
      'dc-self@delta.chat',
      chatAlice.jid,
      chatBob.jid,
    });

    addTearDown(service.shutdown);
  });

  test('shareContextForMessage returns null when message lacks delta id',
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
  });

  test('shareContextForMessage returns null when share row is missing',
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

    when(() => database.getShareIdForDeltaMessage(15))
        .thenAnswer((_) async => null);

    final result = await service.shareContextForMessage(message);

    expect(result, isNull);
    verify(() => database.getShareIdForDeltaMessage(15)).called(1);
    verifyNever(() => database.getParticipantsForShare(any()));

    addTearDown(service.shutdown);
  });

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

    when(() => database.getShareIdForDeltaMessage(15))
        .thenAnswer((_) async => 'share-1');
    when(() => database.getParticipantsForShare('share-1'))
        .thenAnswer((_) async => [participant]);
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
