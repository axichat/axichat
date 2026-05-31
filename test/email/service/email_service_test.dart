import 'dart:async';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/foreground_task_messages.dart';
import 'package:axichat/src/common/html_content.dart';
import 'package:axichat/src/common/synthetic_forward.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/models/fan_out_recipient_state.dart';
import 'package:axichat/src/email/service/email_service.dart';
import 'package:axichat/src/email/models/email_sync_state.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/common/chat_subject_codec.dart';
import 'package:axichat/src/common/synthetic_reply.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/credential_store.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/connection/foreground_socket.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../mocks.dart';

class MockEmailDeltaTransport extends Mock implements EmailDeltaTransport {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

class FakeForegroundBridge implements ForegroundTaskBridge {
  final Map<String, ForegroundTaskMessageHandler> _listeners = {};
  final Set<String> _acquiredClients = <String>{};
  final List<List<Object>> sent = [];

  bool isClientAcquired(String clientId) => _acquiredClients.contains(clientId);

  @override
  Future<bool> isRunning() async => _acquiredClients.isNotEmpty;

  @override
  Future<bool> stopIfRunning() async {
    final running = _acquiredClients.isNotEmpty;
    _acquiredClients.clear();
    _listeners.clear();
    return running;
  }

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
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCredentialStore credentialStore;
  late MockXmppDatabase database;
  late MockNotificationService notificationService;
  late MockEmailDeltaTransport transport;
  late FakeForegroundBridge foregroundBridge;
  late PathProviderPlatform originalPathProvider;
  late Directory temporaryDirectory;

  late void Function(DeltaCoreEvent) listener;

  setUpAll(() {
    registerFallbackValue(MessageTransport.xmpp);
    registerFallbackValue(MessageNotificationChannel.chat);
    registerFallbackValue(<FutureOr<bool>>[]);
    registerFallbackValue(<Contact>[]);
    registerFallbackValue(<String>[]);
    registerFallbackValue(<int>[]);
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
    registerFallbackValue(
      Message(
        stanzaID: 'fallback-stanza',
        senderJid: 'fallback@axi.im',
        chatJid: 'fallback@axi.im',
        body: 'fallback',
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
    registerFallbackValue(
      EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'fallback@example.com',
        fingerprint: 'fallback',
        deltaContactId: 1,
        deltaChatId: 1,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    );
  });

  setUp(() async {
    originalPathProvider = PathProviderPlatform.instance;
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'email_service_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(
      temporaryDirectory.path,
    );
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
    when(() => transport.stopEventDeliveryForLogout()).thenAnswer((_) async {});
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
    when(() => transport.connectivityDetails()).thenAnswer((_) async => null);
    when(
      () => transport.chatSendCapabilities(
        chatId: any(named: 'chatId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer(
      (_) async => const DeltaChatSendCapabilities(
        exists: true,
        canSend: true,
        isEncrypted: true,
      ),
    );
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
      () => transport.setCoreConfig(
        key: any(named: 'key'),
        value: any(named: 'value'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => transport.setCoreConfigIfSupported(
        key: any(named: 'key'),
        value: any(named: 'value'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () =>
          transport.markSeenMessages(any(), accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => true);
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
        forcePlaintext: any(named: 'forcePlaintext'),
        skipAutocrypt: any(named: 'skipAutocrypt'),
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
        forcePlaintext: any(named: 'forcePlaintext'),
        skipAutocrypt: any(named: 'skipAutocrypt'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => transport.sendTextWithQuote(
        chatId: any(named: 'chatId'),
        body: any(named: 'body'),
        quotedMessageId: any(named: 'quotedMessageId'),
        quotedStanzaId: any(named: 'quotedStanzaId'),
        subject: any(named: 'subject'),
        htmlBody: any(named: 'htmlBody'),
        accountId: any(named: 'accountId'),
        forcePlaintext: any(named: 'forcePlaintext'),
        skipAutocrypt: any(named: 'skipAutocrypt'),
      ),
    ).thenAnswer((_) async => 1);
    when(
      () => transport.forwardMessages(
        messageIds: any(named: 'messageIds'),
        toChatId: any(named: 'toChatId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => true);
    when(
      () => transport.getChatMessageIds(
        chatId: any(named: 'chatId'),
        beforeMessageId: any(named: 'beforeMessageId'),
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () =>
          transport.hydrateMessages(any(), accountId: any(named: 'accountId')),
    ).thenAnswer((_) async {});
    when(
      () => transport.getMessage(any(), accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => null);
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
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.removeDeltaPlaceholderDuplicates(
        deltaAccountId: any(named: 'deltaAccountId'),
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: any(named: 'emailSelfJid'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.getDeltaChatIdsForAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
      ),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () => database.getEmailTrustedContactKey(
        deltaAccountId: any(named: 'deltaAccountId'),
        address: any(named: 'address'),
      ),
    ).thenAnswer((_) async => null);
    when(
      () => database.upsertEmailTrustedContactKey(any()),
    ).thenAnswer((_) async {});
    when(
      () => database.upsertEmailChatAccount(
        chatJid: any(named: 'chatJid'),
        deltaAccountId: any(named: 'deltaAccountId'),
        deltaChatId: any(named: 'deltaChatId'),
      ),
    ).thenAnswer((_) async {});
    when(() => database.updateChat(any())).thenAnswer((_) async {});
    when(() => database.updateMessage(any())).thenAnswer((_) async {});
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
      () => database.getEmailMessagesByRfcGroup(
        chatJid: any(named: 'chatJid'),
        originID: any(named: 'originID'),
        deltaAccountId: any(named: 'deltaAccountId'),
      ),
    ).thenAnswer((_) async => const <Message>[]);
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

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  Future<void> pumpMicrotasks() async {
    await Future<void>.delayed(Duration.zero);
  }

  EmailService createService() => EmailService(
    credentialStore: credentialStore,
    databaseBuilder: () async => database,
    transport: transport,
    notificationService: notificationService,
    foregroundBridge: foregroundBridge,
  );

  Future<EmailService> createProvisionedService() async {
    final service = createService();
    addTearDown(service.shutdown);
    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'passphrase',
      jid: 'alice@example.com',
      passwordOverride: 'password',
      persistCredentials: false,
    );
    return service;
  }

  File temporaryFile(String name) =>
      File(p.join(temporaryDirectory.path, name));

  String privateKeyBlock(String label) =>
      '-----BEGIN PGP PRIVATE KEY BLOCK-----\n'
      '$label\n'
      '-----END PGP PRIVATE KEY BLOCK-----\n';

  String publicKeyBlock(String label) =>
      '-----BEGIN PGP PUBLIC KEY BLOCK-----\n'
      '$label\n'
      '-----END PGP PUBLIC KEY BLOCK-----\n';

  DeltaOpenPgpKeyMetadata privateKeyMetadata(String fingerprint) =>
      DeltaOpenPgpKeyMetadata(
        kind: DeltaOpenPgpKeyKind.private,
        fingerprint: fingerprint,
        userIds: const ['Alice <alice@example.com>'],
        hasExpectedAddress: true,
        hasEncryptionCapability: true,
      );

  DeltaOpenPgpKeyMetadata publicKeyMetadata(
    String fingerprint, {
    bool hasExpectedAddress = true,
    bool hasEncryptionCapability = true,
  }) => DeltaOpenPgpKeyMetadata(
    kind: DeltaOpenPgpKeyKind.public,
    fingerprint: fingerprint,
    userIds: const ['Friend <friend@example.com>'],
    hasExpectedAddress: hasExpectedAddress,
    hasEncryptionCapability: hasEncryptionCapability,
  );

  Future<File> writeArchive(String name, Map<String, List<int>> entries) async {
    final archive = Archive();
    for (final entry in entries.entries) {
      archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
    }
    final bytes = ZipEncoder().encode(archive);
    return temporaryFile(name).writeAsBytes(bytes, flush: true);
  }

  void emitNetworkError() {
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.error.code,
        data1: 0,
        data2: 0,
        data2Text: 'network offline',
      ),
    );
  }

  void emitConnectivityChanged() {
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.connectivityChanged.code,
        data1: 0,
        data2: 0,
      ),
    );
  }

  void emitBackgroundFetchDone() {
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.accountsBackgroundFetchDone.code,
        data1: 0,
        data2: 0,
      ),
    );
  }

  void emitChannelOverflow() {
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.channelOverflow.code,
        data1: 0,
        data2: 0,
      ),
    );
  }

  test('active encryption account info reports an existing self key', () async {
    final service = await createProvisionedService();
    when(
      () => transport.getCoreConfig(
        'key_id',
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => 'self-key-id');

    final account = await service.activeEncryptionAccountInfo();

    expect(account?.normalizedAddress, 'alice@example.com');
    expect(account?.deltaAccountId, DeltaAccountDefaults.legacyId);
    expect(account?.hasSelfKey, isTrue);
  });

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

  test('seeds attachment auto-download settings into injected transport', () {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      autoDownloadImages: true,
      autoDownloadDocuments: true,
    );
    addTearDown(service.shutdown);

    verify(
      () => transport.updateAttachmentAutoDownloadSettings(
        imagesEnabled: true,
        videosEnabled: false,
        documentsEnabled: true,
        archivesEnabled: false,
      ),
    ).called(1);
  });

  test('per-chat MDN override restores global read receipt config', () async {
    when(() => transport.accountIds()).thenAnswer((_) async => const <int>[1]);
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      emailReadReceiptsEnabled: true,
    );
    addTearDown(service.shutdown);
    await service.ensureProvisioned(
      displayName: 'Alice',
      databasePrefix: 'alice',
      databasePassphrase: 'secret',
      jid: 'alice@example.com',
      passwordOverride: 'password',
      persistCredentials: false,
    );
    clearInteractions(transport);

    final marked = await service.markSeenMessages(const <Message>[
      Message(
        stanzaID: 'dc-msg-10',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        deltaAccountId: 1,
        deltaMsgId: 10,
      ),
    ], sendReadReceipts: false);

    expect(marked, isTrue);
    verifyInOrder([
      () => transport.setCoreConfig(
        key: 'mdns_enabled',
        value: '0',
        accountId: 1,
      ),
      () => transport.markSeenMessages(const <int>[10], accountId: 1),
      () => transport.setCoreConfig(
        key: 'mdns_enabled',
        value: '1',
        accountId: 1,
      ),
    ]);
  });

  test(
    'markSeenMessages expands RFC email siblings before syncing Core',
    () async {
      when(
        () => transport.accountIds(),
      ).thenAnswer((_) async => const <int>[1]);
      const first = Message(
        stanzaID: 'dc-msg-10',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        originID: 'message@example.com',
        deltaAccountId: 1,
        deltaChatId: 2,
        deltaMsgId: 10,
      );
      const second = Message(
        stanzaID: 'dc-msg-11',
        senderJid: 'sender@example.com',
        chatJid: 'chat@example.com',
        originID: 'message@example.com',
        deltaAccountId: 1,
        deltaChatId: 2,
        deltaMsgId: 11,
      );
      when(
        () => database.getEmailMessagesByRfcGroup(
          chatJid: 'chat@example.com',
          originID: 'message@example.com',
          deltaAccountId: 1,
        ),
      ).thenAnswer((_) async => const <Message>[first, second]);
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        emailReadReceiptsEnabled: true,
      );
      addTearDown(service.shutdown);
      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'secret',
        jid: 'alice@example.com',
        passwordOverride: 'password',
        persistCredentials: false,
      );
      clearInteractions(transport);

      final marked = await service.markSeenMessages(const <Message>[
        first,
      ], sendReadReceipts: false);

      expect(marked, isTrue);
      verify(
        () => transport.markSeenMessages(const <int>[10, 11], accountId: 1),
      ).called(1);
    },
  );

  test('imports BYOK private key from a copied temp file', () async {
    final source = await temporaryFile(
      'alice.asc',
    ).writeAsString(privateKeyBlock('direct-source'), flush: true);
    final service = await createProvisionedService();
    String? importPath;
    String? importedArmored;

    when(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'alice@example.com',
        expectedKind: DeltaOpenPgpKeyKind.private,
      ),
    ).thenAnswer((_) async => privateKeyMetadata('ABC123'));
    when(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((invocation) async {
      final path = invocation.namedArguments[#path] as String;
      importPath = path;
      importedArmored = await File(path).readAsString();
      return const EmailDeltaImexResult(
        accountId: DeltaAccountDefaults.legacyId,
        exportedPaths: <String>[],
      );
    });
    when(
      () => transport.getCoreConfig(
        'key_id',
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => 'self-key-id');

    final account = await service.importEmailEncryptionPrivateKey(
      source,
      expectedFingerprint: 'ABC123',
      allowIdentityMismatch: false,
    );

    expect(account.normalizedAddress, 'alice@example.com');
    expect(importedArmored, privateKeyBlock('direct-source'));
    expect(importPath, isNot(source.path));
    expect(
      p.isWithin(
        p.join(temporaryDirectory.path, emailEncryptionKeyTempDirectoryName),
        importPath!,
      ),
      isTrue,
    );
    expect(await File(importPath!).exists(), isFalse);
    verify(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: importPath!,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).called(1);
  });

  test('rejects binary gpg before Delta import', () async {
    final source = await temporaryFile(
      'binary.gpg',
    ).writeAsBytes(const <int>[0, 1, 2, 3], flush: true);
    final service = await createProvisionedService();

    await expectLater(
      service.inspectEmailEncryptionPrivateKey(source),
      throwsA(isA<EmailEncryptionUnsupportedKeyFormatException>()),
    );

    verifyNever(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'alice@example.com',
        expectedKind: DeltaOpenPgpKeyKind.private,
      ),
    );
    verifyNever(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    );
  });

  test('selects the single default private key from a zip archive', () async {
    final defaultArmored = privateKeyBlock('default-key');
    final source = await writeArchive('delta-export.zip', <String, List<int>>{
      'other.asc': privateKeyBlock('other-key').codeUnits,
      'private-key-alice@example.com-default-ABC123.asc':
          defaultArmored.codeUnits,
    });
    final service = await createProvisionedService();
    String? importedArmored;

    when(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'alice@example.com',
        expectedKind: DeltaOpenPgpKeyKind.private,
      ),
    ).thenAnswer((invocation) async {
      final armored = invocation.namedArguments[#armored] as String;
      expect(armored, defaultArmored);
      return privateKeyMetadata('ABC123');
    });
    when(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((invocation) async {
      importedArmored = await File(
        invocation.namedArguments[#path] as String,
      ).readAsString();
      return const EmailDeltaImexResult(
        accountId: DeltaAccountDefaults.legacyId,
        exportedPaths: <String>[],
      );
    });
    when(
      () => transport.getCoreConfig(
        'key_id',
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer((_) async => 'self-key-id');

    await service.importEmailEncryptionPrivateKey(
      source,
      expectedFingerprint: 'ABC123',
      allowIdentityMismatch: false,
    );

    expect(importedArmored, defaultArmored);
  });

  test('rejects ambiguous zip private keys before Delta import', () async {
    final source = await writeArchive('ambiguous.zip', <String, List<int>>{
      'first.asc': privateKeyBlock('first-key').codeUnits,
      'second.asc': privateKeyBlock('second-key').codeUnits,
    });
    final service = await createProvisionedService();

    await expectLater(
      service.inspectEmailEncryptionPrivateKey(source),
      throwsA(isA<EmailEncryptionAmbiguousKeyArchiveException>()),
    );

    verifyNever(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'alice@example.com',
        expectedKind: DeltaOpenPgpKeyKind.private,
      ),
    );
    verifyNever(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    );
  });

  test('rejects unsafe nested zip key paths before Delta import', () async {
    final source = await writeArchive('unsafe.zip', <String, List<int>>{
      'nested/key.asc': privateKeyBlock('nested-key').codeUnits,
    });
    final service = await createProvisionedService();

    await expectLater(
      service.inspectEmailEncryptionPrivateKey(source),
      throwsA(isA<EmailEncryptionUnsupportedKeyFormatException>()),
    );

    verifyNever(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'alice@example.com',
        expectedKind: DeltaOpenPgpKeyKind.private,
      ),
    );
    verifyNever(
      () => transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
        accountId: DeltaAccountDefaults.legacyId,
      ),
    );
  });

  test(
    'create export zips the current operation default self key files',
    () async {
      final service = await createProvisionedService();
      const privateName = 'private-key-alice@example.com-default-ABC123.asc';
      const publicName = 'public-key-alice@example.com-default-ABC123.asc';
      final privateArmored = privateKeyBlock('selected-private');
      final publicArmored = publicKeyBlock('selected-public');
      String? operationDirectoryPath;

      when(
        () => transport.runImex(
          mode: DeltaImexMode.exportSelfKeys,
          path: any(named: 'path'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((invocation) async {
        final operationDirectory = Directory(
          invocation.namedArguments[#path] as String,
        );
        operationDirectoryPath = operationDirectory.path;
        final privateKey = File(p.join(operationDirectory.path, privateName));
        final publicKey = File(p.join(operationDirectory.path, publicName));
        final ignored = File(
          p.join(
            operationDirectory.path,
            'private-key-alice@example.com-2.asc',
          ),
        );
        final parentOld = File(
          p.join(operationDirectory.parent.path, 'old.asc'),
        );
        await privateKey.writeAsString(privateArmored, flush: true);
        await publicKey.writeAsString(publicArmored, flush: true);
        await ignored.writeAsString(privateKeyBlock('ignored'), flush: true);
        await parentOld.writeAsString(privateKeyBlock('old'), flush: true);
        return EmailDeltaImexResult(
          accountId: DeltaAccountDefaults.legacyId,
          exportedPaths: <String>[ignored.path],
        );
      });
      when(
        () => transport.inspectOpenPgpKey(
          armored: privateArmored,
          expectedAddress: 'alice@example.com',
          expectedKind: DeltaOpenPgpKeyKind.private,
        ),
      ).thenAnswer((_) async => privateKeyMetadata('ABC123'));
      when(
        () => transport.inspectOpenPgpKey(
          armored: publicArmored,
          expectedAddress: 'alice@example.com',
          expectedKind: DeltaOpenPgpKeyKind.public,
        ),
      ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
      when(
        () => transport.getCoreConfig(
          'key_id',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 'self-key-id');

      final export = await service.createEmailEncryptionKeyExport();
      final archive = ZipDecoder().decodeBytes(export.archiveBytes);

      expect(archive.files.map((file) => file.name), [privateName, publicName]);
      expect(archive.files.first.readBytes(), privateArmored.codeUnits);
      expect(await Directory(operationDirectoryPath!).exists(), isFalse);
    },
  );

  test(
    'create export fails when no default private key file is written',
    () async {
      final service = await createProvisionedService();
      String? operationDirectoryPath;

      when(
        () => transport.runImex(
          mode: DeltaImexMode.exportSelfKeys,
          path: any(named: 'path'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((invocation) async {
        final operationDirectory = Directory(
          invocation.namedArguments[#path] as String,
        );
        operationDirectoryPath = operationDirectory.path;
        await File(
          p.join(
            operationDirectory.path,
            'public-key-alice@example.com-default-ABC123.asc',
          ),
        ).writeAsString(publicKeyBlock('public-only'), flush: true);
        return const EmailDeltaImexResult(
          accountId: DeltaAccountDefaults.legacyId,
          exportedPaths: <String>[],
        );
      });
      when(
        () => transport.getCoreConfig(
          'key_id',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 'self-key-id');

      await expectLater(
        service.createEmailEncryptionKeyExport(),
        throwsA(isA<EmailEncryptionExportFailedException>()),
      );

      expect(await Directory(operationDirectoryPath!).exists(), isFalse);
    },
  );

  test(
    'create export cleans temp when default private key cannot be inspected',
    () async {
      final service = await createProvisionedService();
      String? operationDirectoryPath;

      when(
        () => transport.runImex(
          mode: DeltaImexMode.exportSelfKeys,
          path: any(named: 'path'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((invocation) async {
        final operationDirectory = Directory(
          invocation.namedArguments[#path] as String,
        );
        operationDirectoryPath = operationDirectory.path;
        await File(
          p.join(
            operationDirectory.path,
            'private-key-alice@example.com-default-ABC123.asc',
          ),
        ).writeAsBytes(<int>[
          ...privateKeyBlock('invalid-utf8').codeUnits,
          0xff,
        ], flush: true);
        return const EmailDeltaImexResult(
          accountId: DeltaAccountDefaults.legacyId,
          exportedPaths: <String>[],
        );
      });
      when(
        () => transport.getCoreConfig(
          'key_id',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 'self-key-id');

      await expectLater(
        service.createEmailEncryptionKeyExport(),
        throwsA(isA<EmailEncryptionExportFailedException>()),
      );

      expect(await Directory(operationDirectoryPath!).exists(), isFalse);
    },
  );

  test(
    'platform export completion rejects an empty archive before activation',
    () async {
      final source = await writeArchive('empty-export.zip', const {});
      final service = await createProvisionedService();

      await expectLater(
        service.completeEmailEncryptionKeyExportAfterPlatformSave(
          archiveBytes: await source.readAsBytes(),
          platformResultPath: '/document/axichat-email-openpgp-key.zip',
          normalizedAddress: 'alice@example.com',
        ),
        throwsA(isA<EmailEncryptionSaveFailedException>()),
      );
    },
  );

  test(
    'contact public key rejects private key material before Delta',
    () async {
      final source = await temporaryFile(
        'friend.asc',
      ).writeAsString(privateKeyBlock('not-public'), flush: true);
      final service = await createProvisionedService();

      await expectLater(
        service.inspectContactPublicKey(
          address: 'friend@example.com',
          source: source,
        ),
        throwsA(isA<EmailContactKeyUnsupportedFormatException>()),
      );

      verifyNever(
        () => transport.inspectOpenPgpKey(
          armored: any(named: 'armored'),
          expectedAddress: 'friend@example.com',
          expectedKind: DeltaOpenPgpKeyKind.public,
        ),
      );
    },
  );

  test('contact public key rejects missing key armor before Delta', () async {
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString('not an armored OpenPGP key', flush: true);
    final service = await createProvisionedService();

    await expectLater(
      service.inspectContactPublicKey(
        address: 'friend@example.com',
        source: source,
      ),
      throwsA(isA<EmailContactKeyUnsupportedFormatException>()),
    );

    verifyNever(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    );
  });

  test('contact public key rejects multiple key blocks before Delta', () async {
    final source = await temporaryFile('friend.asc').writeAsString(
      '${publicKeyBlock('first')}\n${publicKeyBlock('second')}',
      flush: true,
    );
    final service = await createProvisionedService();

    await expectLater(
      service.inspectContactPublicKey(
        address: 'friend@example.com',
        source: source,
      ),
      throwsA(isA<EmailContactKeyUnsupportedFormatException>()),
    );

    verifyNever(
      () => transport.inspectOpenPgpKey(
        armored: any(named: 'armored'),
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    );
  });

  test('imports and stores a matching contact public key', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();
    EmailTrustedContactKeyData? storedKey;

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('ABC123'),
        contactId: 17,
        chatId: 91,
      ),
    );
    when(() => database.upsertEmailTrustedContactKey(any())).thenAnswer((
      invocation,
    ) async {
      storedKey =
          invocation.positionalArguments.first as EmailTrustedContactKeyData;
    });

    final key = await service.importTrustedContactPublicKey(
      address: 'Friend@Example.COM',
      displayName: 'Friend',
      source: source,
      identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
      expectedFingerprint: 'ABC123',
    );

    expect(key.normalizedAddress, 'friend@example.com');
    expect(key.fingerprint, 'ABC123');
    expect(key.deltaContactId, 17);
    expect(key.deltaChatId, 91);
    expect(key.identityBinding, EmailOpenPgpIdentityBinding.addressMatch);
    expect(storedKey, isNotNull);
    expect(storedKey!.deltaAccountId, DeltaAccountDefaults.legacyId);
    expect(storedKey!.address, 'friend@example.com');
    expect(storedKey!.fingerprint, 'ABC123');
    expect(storedKey!.deltaContactId, 17);
    expect(storedKey!.deltaChatId, 91);
    expect(
      storedKey!.identityBinding,
      EmailOpenPgpIdentityBinding.addressMatch.name,
    );
  });

  test('contact public key identity mismatch requires confirmation', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer(
      (_) async => publicKeyMetadata('ABC123', hasExpectedAddress: false),
    );

    await expectLater(
      service.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: source,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABC123',
      ),
      throwsA(isA<EmailContactKeyImportFailedException>()),
    );

    verifyNever(
      () => transport.importContactPublicKey(
        address: any(named: 'address'),
        displayName: any(named: 'displayName'),
        armoredPublicKey: any(named: 'armoredPublicKey'),
        accountId: any(named: 'accountId'),
      ),
    );
    verifyNever(() => database.upsertEmailTrustedContactKey(any()));
  });

  test('confirmed contact public key identity mismatch is stored', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();
    EmailTrustedContactKeyData? storedKey;

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer(
      (_) async => publicKeyMetadata('ABC123', hasExpectedAddress: false),
    );
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('ABC123', hasExpectedAddress: false),
        contactId: 17,
        chatId: 91,
      ),
    );
    when(() => database.upsertEmailTrustedContactKey(any())).thenAnswer((
      invocation,
    ) async {
      storedKey =
          invocation.positionalArguments.first as EmailTrustedContactKeyData;
    });

    final key = await service.importTrustedContactPublicKey(
      address: 'friend@example.com',
      displayName: 'Friend',
      source: source,
      identityBinding: EmailOpenPgpIdentityBinding.userConfirmed,
      expectedFingerprint: 'ABC123',
    );

    expect(key.identityBinding, EmailOpenPgpIdentityBinding.userConfirmed);
    expect(
      storedKey!.identityBinding,
      EmailOpenPgpIdentityBinding.userConfirmed.name,
    );
  });

  test('contact public key Delta result mismatch is not persisted', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('DIFFERENT'),
        contactId: 17,
        chatId: 91,
      ),
    );

    await expectLater(
      service.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: source,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABC123',
      ),
      throwsA(isA<EmailContactKeyImportFailedException>()),
    );

    verifyNever(() => database.upsertEmailTrustedContactKey(any()));
  });

  test('contact public key invalid Delta ids are not persisted', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('ABC123'),
        contactId: 0,
        chatId: 91,
      ),
    );

    await expectLater(
      service.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: source,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABC123',
      ),
      throwsA(isA<EmailContactKeyImportFailedException>()),
    );

    verifyNever(() => database.upsertEmailTrustedContactKey(any()));
  });

  test('contact public key self Delta contact id is not persisted', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('ABC123'),
        contactId: DeltaContactId.self,
        chatId: 91,
      ),
    );

    await expectLater(
      service.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: source,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABC123',
      ),
      throwsA(isA<EmailContactKeyImportFailedException>()),
    );

    verifyNever(() => database.upsertEmailTrustedContactKey(any()));
  });

  test('contact public key special Delta chat id is not persisted', () async {
    final armored = publicKeyBlock('friend-public-key');
    final source = await temporaryFile(
      'friend.asc',
    ).writeAsString(armored, flush: true);
    final service = await createProvisionedService();

    when(
      () => transport.inspectOpenPgpKey(
        armored: armored,
        expectedAddress: 'friend@example.com',
        expectedKind: DeltaOpenPgpKeyKind.public,
      ),
    ).thenAnswer((_) async => publicKeyMetadata('ABC123'));
    when(
      () => transport.importContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        armoredPublicKey: armored,
        accountId: DeltaAccountDefaults.legacyId,
      ),
    ).thenAnswer(
      (_) async => DeltaContactPublicKeyImport(
        metadata: publicKeyMetadata('ABC123'),
        contactId: 17,
        chatId: DeltaChatId.lastSpecial,
      ),
    );

    await expectLater(
      service.importTrustedContactPublicKey(
        address: 'friend@example.com',
        displayName: 'Friend',
        source: source,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch,
        expectedFingerprint: 'ABC123',
      ),
      throwsA(isA<EmailContactKeyImportFailedException>()),
    );

    verifyNever(() => database.upsertEmailTrustedContactKey(any()));
  });

  test(
    'flushes multiple pending notifications immediately for a chat-scoped bunch',
    () async {
      const chatId = 11;
      const firstMsgId = 88;
      const secondMsgId = 89;
      final firstMessage = Message(
        stanzaID: 'dc-msg-$firstMsgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        timestamp: DateTime.now(),
        body: 'First batched hello',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final secondMessage = Message(
        stanzaID: 'dc-msg-$secondMsgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
        body: 'Second batched hello',
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
        () => database.getMessageByStanzaID('dc-msg-$firstMsgId'),
      ).thenAnswer((_) async => firstMessage);
      when(
        () => database.getMessageByStanzaID('dc-msg-$secondMsgId'),
      ).thenAnswer((_) async => secondMessage);
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
          data2: firstMsgId,
        ),
      );
      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: chatId,
          data2: secondMsgId,
        ),
      );

      await pumpMicrotasks();
      verifyNever(
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
      );

      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsgBunch.code,
          data1: chatId,
          data2: 0,
        ),
      );

      await pumpMicrotasks();

      verify(
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
      ).called(2);
    },
  );

  test(
    'notifies RFC email group leader when incoming event is a sibling',
    () async {
      const chatId = 12;
      const accountId = 1;
      const firstMsgId = 200;
      const secondMsgId = 201;
      final firstMessage = Message(
        stanzaID: 'dc-msg-$firstMsgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        originID: 'message@example.com',
        deltaAccountId: accountId,
        deltaChatId: chatId,
        deltaMsgId: firstMsgId,
        timestamp: DateTime.now(),
        body: 'First RFC group hello',
        encryptionProtocol: EncryptionProtocol.none,
      );
      final secondMessage = Message(
        stanzaID: 'dc-msg-$secondMsgId',
        senderJid: 'peer@axi.im',
        chatJid: 'dc-$chatId@delta.chat',
        originID: 'message@example.com',
        deltaAccountId: accountId,
        deltaChatId: chatId,
        deltaMsgId: secondMsgId,
        timestamp: DateTime.now().add(const Duration(seconds: 1)),
        body: 'Second RFC group hello',
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
        () => database.getMessageByStanzaID('dc-msg-$secondMsgId'),
      ).thenAnswer((_) async => secondMessage);
      when(
        () => database.getEmailMessagesByRfcGroup(
          chatJid: secondMessage.chatJid,
          originID: 'message@example.com',
          deltaAccountId: accountId,
        ),
      ).thenAnswer((_) async => [firstMessage, secondMessage]);
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
          data2: secondMsgId,
          accountId: accountId,
        ),
      );
      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsgBunch.code,
          data1: chatId,
          data2: 0,
          accountId: accountId,
        ),
      );

      await pumpMicrotasks();

      verify(
        () => notificationService.sendMessageNotification(
          title: chat.displayName,
          body: firstMessage.body,
          senderName: chat.displayName,
          senderKey: firstMessage.senderJid,
          conversationTitle: chat.displayName,
          sentAt: firstMessage.timestamp,
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

  test('dedupes RFC email group notifications in one flush', () async {
    const chatId = 13;
    const accountId = 1;
    const firstMsgId = 210;
    const secondMsgId = 211;
    final firstMessage = Message(
      stanzaID: 'dc-msg-$firstMsgId',
      senderJid: 'peer@axi.im',
      chatJid: 'dc-$chatId@delta.chat',
      originID: 'message@example.com',
      deltaAccountId: accountId,
      deltaChatId: chatId,
      deltaMsgId: firstMsgId,
      timestamp: DateTime.now(),
      body: 'First RFC group hello',
      encryptionProtocol: EncryptionProtocol.none,
    );
    final secondMessage = Message(
      stanzaID: 'dc-msg-$secondMsgId',
      senderJid: 'peer@axi.im',
      chatJid: 'dc-$chatId@delta.chat',
      originID: 'message@example.com',
      deltaAccountId: accountId,
      deltaChatId: chatId,
      deltaMsgId: secondMsgId,
      timestamp: DateTime.now().add(const Duration(seconds: 1)),
      body: 'Second RFC group hello',
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
      () => database.getMessageByStanzaID('dc-msg-$firstMsgId'),
    ).thenAnswer((_) async => firstMessage);
    when(
      () => database.getMessageByStanzaID('dc-msg-$secondMsgId'),
    ).thenAnswer((_) async => secondMessage);
    when(
      () => database.getEmailMessagesByRfcGroup(
        chatJid: firstMessage.chatJid,
        originID: 'message@example.com',
        deltaAccountId: accountId,
      ),
    ).thenAnswer((_) async => [firstMessage, secondMessage]);
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
        data2: firstMsgId,
        accountId: accountId,
      ),
    );
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.incomingMsg.code,
        data1: chatId,
        data2: secondMsgId,
        accountId: accountId,
      ),
    );
    listener(
      DeltaCoreEvent(
        type: DeltaEventType.incomingMsgBunch.code,
        data1: chatId,
        data2: 0,
        accountId: accountId,
      ),
    );

    await pumpMicrotasks();

    verify(
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
        channel: MessageNotificationChannel.email,
      ),
    ).called(1);
  });

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
        'sync_msgs': '0',
        'show_emails': '2',
        'send_pw': 'password',
        'mdns_enabled': '0',
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

  test(
    'start reapplies Delta self-sync suppression for all active sessions',
    () async {
      when(
        () => transport.accountIds(),
      ).thenAnswer((_) async => const <int>[1, 2]);
      when(() => transport.activeAccountId).thenReturn(1);
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
      clearInteractions(transport);

      await service.stop();
      clearInteractions(transport);

      await service.start();

      verify(
        () =>
            transport.setCoreConfig(key: 'sync_msgs', value: '0', accountId: 1),
      ).called(1);
      verify(
        () =>
            transport.setCoreConfig(key: 'sync_msgs', value: '0', accountId: 2),
      ).called(1);
      addTearDown(service.shutdown);
    },
  );

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

  test(
    'syncSessionState keeps home refresh fetch and chatlist work active',
    () async {
      when(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).thenAnswer((_) async => const <int>[]);
      when(
        () => transport.getBlockedContactIds(),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.replaceContacts(any())).thenAnswer((_) async {});
      when(
        () => database.getEmailSpamlist(),
      ).thenAnswer((_) async => <EmailSpamEntry>[]);
      when(
        () => database.getEmailBlocklist(),
      ).thenAnswer((_) async => <EmailBlocklistEntry>[]);

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
      when(() => transport.isConfigured()).thenAnswer((_) async => true);
      clearInteractions(transport);
      clearInteractions(database);

      expect(await service.syncSessionState(), isTrue);

      final captured = verify(
        () => transport.performBackgroundFetch(captureAny()),
      ).captured;
      expect(captured, [const Duration(seconds: 15)]);
      verify(() => transport.refreshChatlistSnapshot()).called(1);
      verify(() => database.replaceContacts(any())).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'syncSessionState skips home refresh fetch while transport IO is running',
    () async {
      when(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).thenAnswer((_) async => const <int>[]);
      when(
        () => transport.getBlockedContactIds(),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.replaceContacts(any())).thenAnswer((_) async {});
      when(
        () => database.getEmailSpamlist(),
      ).thenAnswer((_) async => <EmailSpamEntry>[]);
      when(
        () => database.getEmailBlocklist(),
      ).thenAnswer((_) async => <EmailBlocklistEntry>[]);

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
      when(() => transport.isConfigured()).thenAnswer((_) async => true);
      when(() => transport.isIoRunning).thenReturn(true);
      clearInteractions(transport);
      clearInteractions(database);

      expect(await service.syncSessionState(), isTrue);

      verifyNever(() => transport.performBackgroundFetch(any()));
      verify(() => transport.refreshChatlistSnapshot()).called(1);
      verify(() => database.replaceContacts(any())).called(1);

      addTearDown(service.shutdown);
    },
  );

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

  test('foreground keepalive repairs stale foreground lease', () async {
    when(
      () => transport.performBackgroundFetch(any()),
    ).thenAnswer((_) async => false);

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
    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isTrue,
    );

    await foregroundBridge.release(foregroundClientEmailKeepalive);
    foregroundBridge.sent.clear();

    await service.setForegroundKeepalive(true);
    await pumpMicrotasks();

    expect(
      foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
      isTrue,
    );
    expect(
      foregroundBridge.sent,
      contains(
        predicate<List<Object>>(
          (message) =>
              message.length == 3 &&
              message[0] == emailKeepalivePrefix &&
              message[1] == emailKeepaliveStartCommand,
        ),
      ),
    );

    await service.shutdown();
  });

  test(
    'foreground keepalive re-acquires email lease while XMPP keeps service running',
    () async {
      when(
        () => transport.performBackgroundFetch(any()),
      ).thenAnswer((_) async => false);

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
      await foregroundBridge.acquire(clientId: foregroundClientXmpp);
      await foregroundBridge.release(foregroundClientEmailKeepalive);
      foregroundBridge.sent.clear();

      await service.setForegroundKeepalive(true);

      expect(foregroundBridge.isClientAcquired(foregroundClientXmpp), isTrue);
      expect(
        foregroundBridge.isClientAcquired(foregroundClientEmailKeepalive),
        isTrue,
      );
      expect(
        foregroundBridge.sent,
        contains(
          predicate<List<Object>>(
            (message) =>
                message.length == 3 &&
                message[0] == emailKeepalivePrefix &&
                message[1] == emailKeepaliveStartCommand,
          ),
        ),
      );

      await service.shutdown();
      await foregroundBridge.release(foregroundClientXmpp);
    },
  );

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
        forcePlaintext: any(named: 'forcePlaintext'),
        skipAutocrypt: any(named: 'skipAutocrypt'),
      ),
    ).thenAnswer((_) async => 77);

    final msgId = await service.sendAttachment(
      chat: chat,
      attachment: attachment,
    );

    expect(msgId, 1);
    verify(
      () => transport.sendAttachment(
        chatId: chat.deltaChatId!,
        attachment: any(
          named: 'attachment',
          that: predicate<EmailAttachment>(
            (EmailAttachment sentAttachment) =>
                sentAttachment.path == attachment.path &&
                sentAttachment.fileName == attachment.fileName &&
                sentAttachment.sizeBytes == attachment.sizeBytes &&
                sentAttachment.mimeType == attachment.mimeType &&
                (sentAttachment.caption ?? '').isEmpty,
          ),
        ),
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        captionOverride: any(named: 'captionOverride'),
        htmlCaption: any(named: 'htmlCaption'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
        forcePlaintext: true,
        skipAutocrypt: true,
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test(
    'sendAttachment prepares plain caption HTML fallback in service',
    () async {
      final service = await createProvisionedService();
      final chat = Chat(
        jid: 'dc-6@delta.chat',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 6,
      );
      const attachment = EmailAttachment(
        path: '/tmp/file.txt',
        fileName: 'file.txt',
        sizeBytes: 12,
        mimeType: 'text/plain',
        caption: 'File caption',
      );

      await service.sendAttachment(chat: chat, attachment: attachment);

      final capturedAttachment =
          verify(
                () => transport.sendAttachment(
                  chatId: chat.deltaChatId!,
                  attachment: captureAny(named: 'attachment'),
                  subject: any(named: 'subject'),
                  shareId: any(named: 'shareId'),
                  captionOverride: 'File caption',
                  htmlCaption: HtmlContentCodec.normalizeHtml(
                    HtmlContentCodec.fromPlainText('File caption'),
                  ),
                  quotingStanzaId: any(named: 'quotingStanzaId'),
                  accountId: any(named: 'accountId'),
                  forcePlaintext: true,
                  skipAutocrypt: true,
                ),
              ).captured.single
              as EmailAttachment;
      expect(capturedAttachment.caption, 'File caption');
    },
  );

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
          forcePlaintext: any(named: 'forcePlaintext'),
          skipAutocrypt: any(named: 'skipAutocrypt'),
        ),
      ).thenAnswer(
        (invocation) async => (invocation.namedArguments[#chatId] as int) + 100,
      );

      final report = await service.fanOutSend(
        targets: [
          Contact.chat(chat: chatA, shareSignatureEnabled: true),
          Contact.chat(chat: chatB, shareSignatureEnabled: true),
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
      final capturedSendText = verify(
        () => transport.sendText(
          chatId: chatA.deltaChatId!,
          body: captureAny(named: 'body'),
          subject: any(named: 'subject'),
          shareId: report.shareId,
          localBodyOverride: captureAny(named: 'localBodyOverride'),
          htmlBody: captureAny(named: 'htmlBody'),
          quotingStanzaId: 'quoted-stanza',
          accountId: any(named: 'accountId'),
          forcePlaintext: true,
          skipAutocrypt: true,
        ),
      ).captured;
      expect(capturedSendText[0] as String, contains('Hello everyone'));
      expect(capturedSendText[1], 'Hello everyone');
      final capturedHtml = capturedSendText[2] as String?;
      expect(capturedHtml, isNotNull);
      expect(capturedHtml, contains('data-axichat-share-token'));
      expect(
        HtmlContentCodec.toPlainText(capturedHtml!),
        contains('Hello everyone'),
      );
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
          forcePlaintext: true,
          skipAutocrypt: true,
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
          throw const DeltaConfigurationTimeoutException();
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
    'addContactAddress saves an email contact without creating a chat',
    () async {
      Iterable<Contact>? savedContacts;
      when(
        () => transport.createContact(
          address: 'friend@example.com',
          displayName: 'Friend',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 7);
      when(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).thenAnswer((_) async => [7]);
      when(
        () => transport.getBlockedContactIds(),
      ).thenAnswer((_) async => const <int>[]);
      when(() => transport.getContact(7)).thenAnswer(
        (_) async => const DeltaContact(
          id: 7,
          address: 'friend@example.com',
          name: 'Friend',
        ),
      );
      when(() => database.replaceContacts(any())).thenAnswer((
        invocation,
      ) async {
        savedContacts =
            invocation.positionalArguments.first as Iterable<Contact>;
      });
      when(
        () => database.getEmailSpamlist(),
      ).thenAnswer((_) async => <EmailSpamEntry>[]);
      when(
        () => database.getEmailBlocklist(),
      ).thenAnswer((_) async => <EmailBlocklistEntry>[]);
      when(
        () => database.getChatsByJids(any()),
      ).thenAnswer((_) async => <Chat>[]);

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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      await service.addContactAddress(
        address: 'friend@example.com',
        displayName: 'Friend',
      );

      verify(
        () => transport.createContact(
          address: 'friend@example.com',
          displayName: 'Friend',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verifyNever(
        () => transport.ensureChatForAddress(
          address: any(named: 'address'),
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      );
      expect(savedContacts, isNotNull);
      expect(savedContacts!.single.resolvedAddress, 'friend@example.com');
      expect(savedContacts!.single.providedDisplayName, 'Friend');

      addTearDown(service.shutdown);
    },
  );

  test(
    'deleteContactsByNativeIds reconciles contacts even when Delta deletes are stale',
    () async {
      Iterable<Contact>? savedContacts;
      when(() => transport.deleteContact(7)).thenAnswer((_) async => false);
      when(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).thenAnswer((_) async => const <int>[]);
      when(
        () => transport.getBlockedContactIds(),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.replaceContacts(any())).thenAnswer((
        invocation,
      ) async {
        savedContacts =
            invocation.positionalArguments.first as Iterable<Contact>;
      });
      when(
        () => database.getEmailSpamlist(),
      ).thenAnswer((_) async => <EmailSpamEntry>[]);
      when(
        () => database.getEmailBlocklist(),
      ).thenAnswer((_) async => <EmailBlocklistEntry>[]);
      when(
        () => database.getChatsByJids(any()),
      ).thenAnswer((_) async => <Chat>[]);

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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      await service.deleteContactsByNativeIds(const ['delta_contact_7']);

      verify(() => transport.deleteContact(7)).called(1);
      verify(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).called(1);
      verify(() => database.replaceContacts(any())).called(1);
      expect(savedContacts, isEmpty);

      addTearDown(service.shutdown);
    },
  );

  test(
    'removeTrustedContactPublicKey removes native pinned key before clearing local key',
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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      final key = EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'friend@example.com',
        fingerprint: 'ABCD',
        deltaContactId: 17,
        deltaChatId: 91,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.timestamp(),
      );
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async => key);
      when(
        () => transport.removeContactPublicKey(
          address: 'friend@example.com',
          fingerprint: 'ABCD',
          contactId: 17,
          chatId: 91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const DeltaContactPublicKeyRemoval(
          contactId: 17,
          chatId: 91,
          fallbackContactId: 18,
          fingerprint: 'ABCD',
        ),
      );
      when(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ).thenAnswer((_) async {});

      await service.removeTrustedContactPublicKey('friend@example.com');

      verifyInOrder([
        () => transport.removeContactPublicKey(
          address: 'friend@example.com',
          fingerprint: 'ABCD',
          contactId: 17,
          chatId: 91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ]);

      addTearDown(service.shutdown);
    },
  );

  test(
    'removeTrustedContactPublicKey clears legacy self contact mapping locally',
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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      final key = EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'friend@example.com',
        fingerprint: 'ABCD',
        deltaContactId: DeltaContactId.self,
        deltaChatId: 91,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.timestamp(),
      );
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async => key);
      when(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ).thenAnswer((_) async {});

      await service.removeTrustedContactPublicKey('friend@example.com');

      verifyNever(
        () => transport.removeContactPublicKey(
          address: any(named: 'address'),
          fingerprint: any(named: 'fingerprint'),
          contactId: any(named: 'contactId'),
          chatId: any(named: 'chatId'),
          accountId: any(named: 'accountId'),
        ),
      );
      verify(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).called(1);
      verify(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'removeTrustedContactPublicKey clears legacy special chat mapping locally',
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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      final key = EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'friend@example.com',
        fingerprint: 'ABCD',
        deltaContactId: 17,
        deltaChatId: DeltaChatId.lastSpecial,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.timestamp(),
      );
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async => key);
      when(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: DeltaChatId.lastSpecial,
        ),
      ).thenAnswer((_) async {});

      await service.removeTrustedContactPublicKey('friend@example.com');

      verifyNever(
        () => transport.removeContactPublicKey(
          address: any(named: 'address'),
          fingerprint: any(named: 'fingerprint'),
          contactId: any(named: 'contactId'),
          chatId: any(named: 'chatId'),
          accountId: any(named: 'accountId'),
        ),
      );
      verify(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).called(1);
      verify(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: DeltaChatId.lastSpecial,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'removeTrustedContactPublicKey keeps local key when native removal fails',
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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      final key = EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'friend@example.com',
        fingerprint: 'ABCD',
        deltaContactId: 17,
        deltaChatId: 91,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.timestamp(),
      );
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async => key);
      when(
        () => transport.removeContactPublicKey(
          address: 'friend@example.com',
          fingerprint: 'ABCD',
          contactId: 17,
          chatId: 91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenThrow(
        const DeltaOperationException(
          'remove contact OpenPGP key: active_key_still_present',
        ),
      );

      await expectLater(
        service.removeTrustedContactPublicKey('friend@example.com'),
        throwsA(isA<EmailContactKeyRemoveFailedException>()),
      );

      verify(
        () => transport.removeContactPublicKey(
          address: 'friend@example.com',
          fingerprint: 'ABCD',
          contactId: 17,
          chatId: 91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verifyNever(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: any(named: 'deltaAccountId'),
          address: any(named: 'address'),
        ),
      );
      verifyNever(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );
      verifyNever(
        () => transport.getContact(any(), accountId: any(named: 'accountId')),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'removeTrustedContactPublicKey keeps local key when native removal throws',
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
        databasePassphrase: 'secret',
        jid: 'alice@axi.im',
        passwordOverride: 'password',
      );

      final key = EmailTrustedContactKeyData(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'friend@example.com',
        fingerprint: 'ABCD',
        deltaContactId: 17,
        deltaChatId: 91,
        identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
        userIdsJson: '[]',
        importedAt: DateTime.timestamp(),
      );
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'friend@example.com',
        ),
      ).thenAnswer((_) async => key);
      when(
        () => transport.removeContactPublicKey(
          address: 'friend@example.com',
          fingerprint: 'ABCD',
          contactId: 17,
          chatId: 91,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenThrow(const DeltaOperationException('delete failed'));

      await expectLater(
        service.removeTrustedContactPublicKey('friend@example.com'),
        throwsA(isA<EmailContactKeyRemoveFailedException>()),
      );

      verifyNever(
        () => database.deleteEmailTrustedContactKey(
          deltaAccountId: any(named: 'deltaAccountId'),
          address: any(named: 'address'),
        ),
      );
      verifyNever(
        () => database.deleteEmailChatAccountsForDeltaChat(
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );
      verifyNever(
        () => transport.getContact(any(), accountId: any(named: 'accountId')),
      );

      addTearDown(service.shutdown);
    },
  );

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

  test(
    'logout shutdown returns while native dispose is still pending',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      final disposeCompleter = Completer<void>();
      when(
        () => transport.dispose(),
      ).thenAnswer((_) => disposeCompleter.future);

      final stopwatch = Stopwatch()..start();
      await service.shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout);
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      expect(service.hasActiveSession, isFalse);
      await untilCalled(() => transport.dispose());
      expect(
        service.ensureChatForAddress(address: 'friend@axi.im'),
        throwsA(isA<EmailServiceStoppingException>()),
      );

      disposeCompleter.complete();
      await pumpMicrotasks();
    },
  );

  test(
    'logout shutdown does not wait for pre-DB chatlist refresh before returning',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      final refreshCompleter = Completer<void>();
      when(
        () => transport.refreshChatlistSnapshot(
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) => refreshCompleter.future);

      final networkFuture = service.handleNetworkAvailable();
      await untilCalled(
        () => transport.refreshChatlistSnapshot(
          accountId: any(named: 'accountId'),
        ),
      );

      var shutdownCompleted = false;
      final shutdownFuture = service
          .shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout)
          .whenComplete(() {
            shutdownCompleted = true;
          });
      await pumpMicrotasks();

      await shutdownFuture;

      expect(shutdownCompleted, isTrue);
      verify(() => transport.stopEventDeliveryForLogout()).called(1);
      verifyNever(() => transport.dispose());

      refreshCompleter.complete();
      await networkFuture;

      await untilCalled(() => transport.dispose());
      verify(() => transport.dispose()).called(1);
    },
  );

  test(
    'logout shutdown does not wait for native fetch before closing app DB',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      final fetchCompleter = Completer<bool>();
      when(
        () => transport.performBackgroundFetch(any()),
      ).thenAnswer((_) => fetchCompleter.future);

      final networkFuture = service.handleNetworkAvailable();
      await untilCalled(() => transport.performBackgroundFetch(any()));

      var shutdownCompleted = false;
      final shutdownFuture = service
          .shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout)
          .whenComplete(() {
            shutdownCompleted = true;
          });
      await shutdownFuture;

      expect(shutdownCompleted, isTrue);
      verifyNever(
        () => transport.refreshChatlistSnapshot(
          accountId: any(named: 'accountId'),
        ),
      );
      verifyNever(() => transport.dispose());

      fetchCompleter.complete(true);
      await networkFuture;
      await untilCalled(() => transport.dispose());
    },
  );

  test(
    'logout native cleanup waits for matching in-flight stop before dispose',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );
      await service.start();

      final stopCompleter = Completer<void>();
      when(() => transport.stop()).thenAnswer((_) => stopCompleter.future);

      final stopFuture = service.stop();
      await untilCalled(() => transport.stop());

      final shutdownFuture = service.shutdown(
        jid: 'bob@axi.im',
        mode: EmailShutdownMode.logout,
      );
      await shutdownFuture;
      await pumpMicrotasks();

      verifyNever(() => transport.dispose());

      stopCompleter.complete();
      await stopFuture;
      await untilCalled(() => transport.dispose());

      verify(() => transport.stop()).called(1);
      verify(() => transport.dispose()).called(1);
    },
  );

  test(
    'logout shutdown waits for active contacts app DB work before returning',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      final replaceStarted = Completer<void>();
      final replaceCompleter = Completer<void>();
      when(
        () => transport.getContactIds(flags: any(named: 'flags')),
      ).thenAnswer((_) async => const <int>[7]);
      when(() => transport.getContact(7)).thenAnswer(
        (_) async => const DeltaContact(
          id: 7,
          address: 'friend@example.com',
          name: 'Friend',
        ),
      );
      when(
        () => transport.getBlockedContactIds(),
      ).thenAnswer((_) async => const <int>[]);
      when(() => database.replaceContacts(any())).thenAnswer((_) {
        if (!replaceStarted.isCompleted) {
          replaceStarted.complete();
        }
        return replaceCompleter.future;
      });
      when(
        () => database.getEmailSpamlist(),
      ).thenAnswer((_) async => <EmailSpamEntry>[]);
      when(
        () => database.getEmailBlocklist(),
      ).thenAnswer((_) async => <EmailBlocklistEntry>[]);
      when(
        () => database.getChatsByJids(any()),
      ).thenAnswer((_) async => <Chat>[]);

      final syncFuture = service.syncContactsFromCore();
      await replaceStarted.future;

      var shutdownCompleted = false;
      final shutdownFuture = service
          .shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout)
          .whenComplete(() {
            shutdownCompleted = true;
          });
      await pumpMicrotasks();

      expect(shutdownCompleted, isFalse);

      replaceCompleter.complete();
      await syncFuture;
      await shutdownFuture;

      expect(shutdownCompleted, isTrue);
    },
  );

  test(
    'logout shutdown waits for active read-state app DB work before returning',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
        emailReadReceiptsEnabled: true,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      const message = Message(
        stanzaID: 'dc-msg-10',
        senderJid: 'friend@example.com',
        chatJid: 'friend@example.com',
        originID: 'message@example.com',
        deltaAccountId: 1,
        deltaChatId: 2,
        deltaMsgId: 10,
      );
      final groupLookupStarted = Completer<void>();
      final groupLookupCompleter = Completer<List<Message>>();
      when(
        () => database.getEmailMessagesByRfcGroup(
          chatJid: message.chatJid,
          originID: 'message@example.com',
          deltaAccountId: 1,
        ),
      ).thenAnswer((_) {
        if (!groupLookupStarted.isCompleted) {
          groupLookupStarted.complete();
        }
        return groupLookupCompleter.future;
      });

      final markFuture = service.markSeenMessages(const [
        message,
      ], sendReadReceipts: false);
      await groupLookupStarted.future;

      var shutdownCompleted = false;
      final shutdownFuture = service
          .shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout)
          .whenComplete(() {
            shutdownCompleted = true;
          });
      await pumpMicrotasks();

      expect(shutdownCompleted, isFalse);

      groupLookupCompleter.complete(const [message]);
      await markFuture;
      await shutdownFuture;

      expect(shutdownCompleted, isTrue);
    },
  );

  test(
    'logout shutdown waits for active reaction notification DB work',
    () async {
      final service = await createProvisionedService();
      const chatId = 22;
      const msgId = 221;
      const accountId = 1;
      final message = Message(
        stanzaID: 'dc-msg-$msgId',
        senderJid: 'friend@example.com',
        chatJid: 'friend@example.com',
        body: 'hello',
        timestamp: DateTime.now(),
        deltaAccountId: accountId,
        deltaChatId: chatId,
        deltaMsgId: msgId,
      );
      final lookupStarted = Completer<void>();
      final lookupCompleter = Completer<Message?>();
      when(
        () => database.getMessageByDeltaId(msgId, deltaAccountId: accountId),
      ).thenAnswer((_) {
        if (!lookupStarted.isCompleted) {
          lookupStarted.complete();
        }
        return lookupCompleter.future;
      });

      listener(
        DeltaCoreEvent(
          type: DeltaEventType.incomingReaction.code,
          data1: chatId,
          data2: msgId,
          data2Text: '+1',
          accountId: accountId,
        ),
      );
      await lookupStarted.future;

      var shutdownCompleted = false;
      final shutdownFuture = service
          .shutdown(jid: 'alice@example.com', mode: EmailShutdownMode.logout)
          .whenComplete(() {
            shutdownCompleted = true;
          });
      await pumpMicrotasks();

      expect(shutdownCompleted, isFalse);

      lookupCompleter.complete(message);
      await shutdownFuture;

      expect(shutdownCompleted, isTrue);
    },
  );

  test('logout shutdown waits for active send chat binding DB work', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      transportFactory: () => transport,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );

    when(
      () => transport.isConfigured(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => true);

    final chat = Chat(
      jid: 'friend@example.com',
      title: 'Friend',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      transport: MessageTransport.email,
      emailAddress: 'friend@example.com',
      emailFromAddress: 'bob@axi.im',
    );
    final lookupStarted = Completer<void>();
    final lookupCompleter = Completer<Chat?>();
    when(() => database.getChat('friend@example.com')).thenAnswer((_) {
      if (!lookupStarted.isCompleted) {
        lookupStarted.complete();
      }
      return lookupCompleter.future;
    });

    final sendFuture = service.sendMessage(chat: chat, body: 'hello');
    await lookupStarted.future;

    var shutdownCompleted = false;
    final shutdownFuture = service
        .shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout)
        .whenComplete(() {
          shutdownCompleted = true;
        });
    await pumpMicrotasks();

    expect(shutdownCompleted, isFalse);

    lookupCompleter.complete(chat);
    await expectLater(
      sendFuture,
      throwsA(isA<EmailServiceStoppingException>()),
    );
    await shutdownFuture;

    expect(shutdownCompleted, isTrue);
    verifyNever(
      () => transport.sendText(
        chatId: any(named: 'chatId'),
        body: any(named: 'body'),
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        localBodyOverride: any(named: 'localBodyOverride'),
        htmlBody: any(named: 'htmlBody'),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: any(named: 'accountId'),
        forcePlaintext: any(named: 'forcePlaintext'),
        skipAutocrypt: any(named: 'skipAutocrypt'),
      ),
    );
  });

  test('provisioning waits for pending logout native cleanup', () async {
    final service = EmailService(
      credentialStore: credentialStore,
      databaseBuilder: () async => database,
      transport: transport,
      notificationService: notificationService,
      foregroundBridge: foregroundBridge,
      transportFactory: () => transport,
    );

    await service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob',
      databasePassphrase: 'secret',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );

    final disposeCompleter = Completer<void>();
    when(() => transport.dispose()).thenAnswer((_) => disposeCompleter.future);

    await service.shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout);
    await untilCalled(() => transport.dispose());
    clearInteractions(transport);

    final provisionFuture = service.ensureProvisioned(
      displayName: 'Bob',
      databasePrefix: 'bob2',
      databasePassphrase: 'secret2',
      jid: 'bob@axi.im',
      passwordOverride: 'password',
    );
    await pumpMicrotasks();

    verifyNever(
      () => transport.ensureInitialized(
        databasePrefix: 'bob2',
        databasePassphrase: 'secret2',
      ),
    );

    disposeCompleter.complete();
    await provisionFuture;

    verify(
      () => transport.ensureInitialized(
        databasePrefix: 'bob2',
        databasePassphrase: 'secret2',
      ),
    ).called(1);
    await service.shutdown(jid: 'bob@axi.im');
  });

  test(
    'logout shutdown blocks runtime re-entry while cleanup is pending',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        transportFactory: () => transport,
      );

      await service.ensureProvisioned(
        displayName: 'Bob',
        databasePrefix: 'bob',
        databasePassphrase: 'secret',
        jid: 'bob@axi.im',
        passwordOverride: 'password',
      );

      final disposeCompleter = Completer<void>();
      when(
        () => transport.dispose(),
      ).thenAnswer((_) => disposeCompleter.future);

      await service.shutdown(jid: 'bob@axi.im', mode: EmailShutdownMode.logout);
      await untilCalled(() => transport.dispose());
      clearInteractions(transport);

      await service.ensureEventChannelActive();
      await service.handleNetworkAvailable();

      verifyNever(() => transport.addEventListener(any()));
      verifyNever(() => transport.start());
      verifyNever(() => transport.notifyNetworkAvailable());

      disposeCompleter.complete();
      await pumpMicrotasks();
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

  test(
    'shutdown does not hang behind active Delta connectivity work',
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

      final connectivityCompleter = Completer<int>();
      when(
        () => transport.connectivity(),
      ).thenAnswer((_) => connectivityCompleter.future);

      emitConnectivityChanged();
      await untilCalled(() => transport.connectivity());

      final stopwatch = Stopwatch()..start();
      await service.stop();
      stopwatch.stop();

      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 2)));
      connectivityCompleter.complete(4000);
      await pumpMicrotasks();
      await service.shutdown(jid: 'bob@axi.im');
    },
  );

  test(
    'connectivityChanged at offline level stays offline without catch-up',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(credentialStore);
        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 1000);

        emitConnectivityChanged();
        await untilCalled(() => transport.connectivity());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.offline);
        verifyNever(() => transport.bootstrapFromCore());
        verifyNever(() => transport.performBackgroundFetch(any()));
        verifyNever(() => transport.refreshChatlistSnapshot());
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'connectivityChanged at connecting level does not run catch-up',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(credentialStore);
        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        emitConnectivityChanged();
        await untilCalled(() => transport.connectivity());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verifyNever(() => transport.bootstrapFromCore());
        verifyNever(() => transport.performBackgroundFetch(any()));
        verifyNever(() => transport.refreshChatlistSnapshot());
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'connectivityChanged at connecting level with running IO stays recovering',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(credentialStore);
        clearInteractions(transport);
        when(() => transport.isIoRunning).thenReturn(true);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        emitConnectivityChanged();
        await untilCalled(() => transport.connectivity());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verifyNever(() => transport.bootstrapFromCore());
        verifyNever(() => transport.performBackgroundFetch(any()));
        verifyNever(() => transport.refreshChatlistSnapshot());
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'connectivityChanged at working level runs bootstrap and catch-up',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(credentialStore);
        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 3000);

        emitConnectivityChanged();
        await untilCalled(() => transport.refreshChatlistSnapshot());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.ready);
        verify(() => transport.bootstrapFromCore()).called(1);
        verify(() => transport.performBackgroundFetch(any())).called(1);
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'background fetch done at connecting level does not settle ready',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(credentialStore);
        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        emitBackgroundFetchDone();
        await untilCalled(() => transport.refreshChatlistSnapshot());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verify(() => transport.bootstrapFromCore()).called(1);
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  for (final connectivity in const [2000, 3000]) {
    test(
      'home refresh fetch applies connectivity $connectivity state',
      () async {
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
          emitNetworkError();
          await pumpMicrotasks();
          expect(service.syncState.status, EmailSyncStatus.offline);

          clearInteractions(transport);
          when(
            () => transport.connectivity(),
          ).thenAnswer((_) async => connectivity);

          expect(await service.refreshHistoryForHomeRefresh(), isTrue);

          expect(service.syncState.status, switch (connectivity) {
            2000 => EmailSyncStatus.recovering,
            _ => EmailSyncStatus.ready,
          });
          verify(
            () => transport.performBackgroundFetch(const Duration(seconds: 15)),
          ).called(1);
          verify(() => transport.refreshChatlistSnapshot()).called(1);
        } finally {
          await service.shutdown(jid: 'bob@axi.im');
        }
      },
    );
  }

  test(
    'home unread refresh skips background fetch while transport IO is running',
    () async {
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

        clearInteractions(transport);
        when(() => transport.isIoRunning).thenReturn(true);

        expect(await service.refreshUnreadForHomeRefresh(), isTrue);

        verifyNever(() => transport.performBackgroundFetch(any()));
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'background fetch completion keeps ready during transient offline sample',
    () async {
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

        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 1000);

        expect(await service.refreshHistoryForHomeRefresh(), isTrue);

        expect(service.syncState.status, EmailSyncStatus.ready);
        verify(
          () => transport.performBackgroundFetch(const Duration(seconds: 15)),
        ).called(1);
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'connectivityChanged at connected level runs bootstrap and catch-up',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 4000);

        emitConnectivityChanged();
        await untilCalled(() => transport.refreshChatlistSnapshot());
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.ready);
        verify(() => transport.bootstrapFromCore()).called(1);
        verify(() => transport.performBackgroundFetch(any())).called(1);
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

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
    'channel overflow skips background fetch while transport IO is running',
    () async {
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

        clearInteractions(transport);
        when(() => transport.isIoRunning).thenReturn(true);

        emitChannelOverflow();
        await untilCalled(() => transport.refreshChatlistSnapshot());
        await pumpMicrotasks();

        verifyNever(() => transport.performBackgroundFetch(any()));
        verify(() => transport.notifyNetworkAvailable()).called(1);
        verify(() => transport.refreshChatlistSnapshot()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'connecting connectivity downgrades a ready sync state after grace',
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
        return 2000;
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

        expect(service.syncState.status, EmailSyncStatus.recovering);
        expect(connectivityCalls, greaterThanOrEqualTo(2));
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

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

  test('timed out connectivity confirmation keeps ready sync state', () async {
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
    final confirmation = Completer<int>();
    when(() => transport.connectivity()).thenAnswer((_) {
      connectivityCalls++;
      if (connectivityCalls == 1) {
        return Future<int>.value(1000);
      }
      return confirmation.future;
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

      await Future<void>.delayed(const Duration(milliseconds: 3400));
      await pumpMicrotasks();

      expect(service.syncState.status, EmailSyncStatus.ready);
      expect(connectivityCalls, greaterThanOrEqualTo(2));
      confirmation.complete(1000);
    } finally {
      await service.shutdown(jid: 'bob@axi.im');
    }
  });

  test(
    'handleNetworkAvailable restarts transport when Delta stays offline',
    () async {
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

        clearInteractions(transport);
        when(() => transport.connectivity()).thenAnswer((_) async => 1000);

        await service.handleNetworkAvailable();
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.offline);
        verify(() => transport.notifyNetworkAvailable()).called(2);
        verify(() => transport.removeEventListener(any())).called(1);
        verify(() => transport.stop()).called(1);
        verify(() => transport.addEventListener(any())).called(1);
        verify(() => transport.start()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'handleNetworkAvailable leaves Delta connecting without restarting transport',
    () async {
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

        clearInteractions(transport);
        when(() => transport.isIoRunning).thenReturn(true);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        await service.handleNetworkAvailable();
        await Future<void>.delayed(const Duration(milliseconds: 2200));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verify(() => transport.notifyNetworkAvailable()).called(1);
        verifyNever(() => transport.removeEventListener(any()));
        verifyNever(() => transport.stop());
        verifyNever(() => transport.addEventListener(any()));
        verifyNever(() => transport.start());
        verifyNever(
          () => transport.performBackgroundFetch(const Duration(seconds: 25)),
        );
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'handleForegroundResumeNetworkAvailable restarts transport when Delta stays connecting',
    () async {
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

        clearInteractions(transport);
        when(() => transport.isIoRunning).thenReturn(true);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        await service.handleForegroundResumeNetworkAvailable();
        await Future<void>.delayed(const Duration(milliseconds: 4300));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verify(() => transport.notifyNetworkAvailable()).called(3);
        verify(() => transport.removeEventListener(any())).called(1);
        verify(() => transport.stop()).called(1);
        verify(() => transport.addEventListener(any())).called(1);
        verify(() => transport.start()).called(1);
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  test(
    'handleForegroundResumeNetworkAvailable only re-notifies when Delta reaches working',
    () async {
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

        clearInteractions(transport);
        var connectivityCalls = 0;
        when(() => transport.isIoRunning).thenReturn(true);
        when(() => transport.connectivity()).thenAnswer((_) async {
          connectivityCalls++;
          return connectivityCalls >= 5 ? 3000 : 2000;
        });

        await service.handleForegroundResumeNetworkAvailable();
        await Future<void>.delayed(const Duration(milliseconds: 4300));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.ready);
        verify(() => transport.notifyNetworkAvailable()).called(2);
        verifyNever(() => transport.removeEventListener(any()));
        verifyNever(() => transport.stop());
        verifyNever(() => transport.addEventListener(any()));
        verifyNever(() => transport.start());
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
    },
  );

  for (final connectivity in const [3000, 4000]) {
    test(
      'handleNetworkAvailable does not restart transport at connectivity $connectivity',
      () async {
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

          clearInteractions(transport);
          when(() => transport.connectivity()).thenAnswer((_) async {
            return connectivity;
          });

          await service.handleNetworkAvailable();
          await Future<void>.delayed(const Duration(milliseconds: 2200));
          await pumpMicrotasks();

          verify(() => transport.notifyNetworkAvailable()).called(1);
          verifyNever(() => transport.removeEventListener(any()));
          verifyNever(() => transport.stop());
          verifyNever(() => transport.addEventListener(any()));
          verifyNever(() => transport.start());
        } finally {
          await service.shutdown(jid: 'bob@axi.im');
        }
      },
    );
  }

  test(
    'home refresh recovery leaves Delta connecting without restart',
    () async {
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
        emitNetworkError();
        await pumpMicrotasks();
        expect(service.syncState.status, EmailSyncStatus.offline);

        clearInteractions(transport);
        when(() => transport.isConfigured()).thenAnswer((_) async => true);
        when(() => transport.connectivity()).thenAnswer((_) async => 2000);

        expect(await service.recoverForHomeRefresh(), isTrue);
        expect(service.syncState.status, EmailSyncStatus.recovering);

        await Future<void>.delayed(const Duration(milliseconds: 2200));
        await pumpMicrotasks();

        expect(service.syncState.status, EmailSyncStatus.recovering);
        verify(() => transport.notifyNetworkAvailable()).called(1);
        verifyNever(() => transport.removeEventListener(any()));
        verifyNever(() => transport.stop());
        verifyNever(() => transport.addEventListener(any()));
        verifyNever(() => transport.start());
      } finally {
        await service.shutdown(jid: 'bob@axi.im');
      }
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

  test(
    'credential-clearing shutdown blocks re-entry while dispose is in flight',
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
      await service.ensureEventChannelActive();

      clearInteractions(transport);
      final disposeCompleter = Completer<void>();
      when(
        () => transport.dispose(),
      ).thenAnswer((_) => disposeCompleter.future);

      final shutdownFuture = service.shutdown(jid: 'bob@axi.im');
      await untilCalled(() => transport.dispose());

      await service.ensureEventChannelActive();
      await service.handleNetworkAvailable();

      verifyNever(() => transport.addEventListener(any()));
      verifyNever(() => transport.start());
      verifyNever(() => transport.notifyNetworkAvailable());

      disposeCompleter.complete();
      await shutdownFuture;
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

    final shutdownFuture = service.shutdown(
      jid: 'bob@axi.im',
      clearCredentials: true,
    );
    await untilCalled(() => transport.dispose());

    await service.ensureEventChannelActive();
    await service.handleNetworkAvailable();

    verifyNever(() => transport.addEventListener(any()));
    verifyNever(() => transport.start());
    verifyNever(() => transport.notifyNetworkAvailable());

    disposeCompleter.complete();
    await shutdownFuture;
  });

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
      when(
        () => transport.ensureChatForAddress(
          address: 'carol@example.com',
          displayName: 'Carol',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 2);
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
          forcePlaintext: any(named: 'forcePlaintext'),
          skipAutocrypt: any(named: 'skipAutocrypt'),
        ),
      ).thenAnswer((_) async => 202);

      await service.fanOutSend(
        targets: [Contact.chat(chat: chatBob, shareSignatureEnabled: true)],
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
        forcePlaintext: true,
        skipAutocrypt: true,
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
          htmlBody: HtmlContentCodec.normalizeHtml(
            HtmlContentCodec.fromPlainText(syntheticReply.body),
          ),
          quotingStanzaId: 'quoted-xmpp-stanza',
          accountId: DeltaAccountDefaults.legacyId,
          forcePlaintext: true,
          skipAutocrypt: true,
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
          forcePlaintext: any(named: 'forcePlaintext'),
          skipAutocrypt: any(named: 'skipAutocrypt'),
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
          htmlBody: HtmlContentCodec.normalizeHtml(
            HtmlContentCodec.fromPlainText('Reply body'),
          ),
          accountId: DeltaAccountDefaults.legacyId,
          forcePlaintext: true,
          skipAutocrypt: true,
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
          forcePlaintext: true,
          skipAutocrypt: true,
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
    'sendMessage ignores stale active Delta chat owned by another address',
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
          jid: 'other@example.com',
          title: 'Other',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.now(),
          deltaChatId: 88,
          emailAddress: 'other@example.com',
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
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'Address-owned send');

      verify(
        () => transport.sendText(
          chatId: 99,
          body: 'Address-owned send',
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: DeltaAccountDefaults.legacyId,
          forcePlaintext: true,
          skipAutocrypt: true,
        ),
      ).called(1);
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 99,
        ),
      ).called(1);
      verifyNever(
        () => database.upsertEmailChatAccount(
          chatJid: 'other@example.com',
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'beta send uses trusted contact public key chat when encrypted-sendable',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        emailEncryptionBetaEnabledByAddress: const {'alice@example.org': true},
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.selfJidForAccount(any()),
      ).thenReturn('alice@example.org');
      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'peer@example.com',
        ),
      ).thenAnswer(
        (_) async => EmailTrustedContactKeyData(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'peer@example.com',
          fingerprint: 'ABC123',
          deltaContactId: 17,
          deltaChatId: 77,
          identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
          userIdsJson: '[]',
          importedAt: DateTime.timestamp(),
        ),
      );
      when(
        () => transport.chatSendCapabilities(
          chatId: 77,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const DeltaChatSendCapabilities(
          exists: true,
          canSend: true,
          isEncrypted: true,
        ),
      );

      final chat = Chat(
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'Trusted key send');

      verify(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'peer@example.com',
        ),
      ).called(1);
      verify(
        () => transport.chatSendCapabilities(
          chatId: 77,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verifyNever(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      );
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 77,
        ),
      ).called(1);
      verify(
        () => transport.sendText(
          chatId: 77,
          body: 'Trusted key send',
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: DeltaAccountDefaults.legacyId,
          forcePlaintext: false,
          skipAutocrypt: false,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'beta send fails closed when trusted contact public key chat is not encrypted-sendable',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        emailEncryptionBetaEnabledByAddress: const {'alice@example.org': true},
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.selfJidForAccount(any()),
      ).thenReturn('alice@example.org');
      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => database.getEmailTrustedContactKey(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'peer@example.com',
        ),
      ).thenAnswer(
        (_) async => EmailTrustedContactKeyData(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          address: 'peer@example.com',
          fingerprint: 'ABC123',
          deltaContactId: 17,
          deltaChatId: 77,
          identityBinding: EmailOpenPgpIdentityBinding.addressMatch.name,
          userIdsJson: '[]',
          importedAt: DateTime.timestamp(),
        ),
      );
      when(
        () => transport.chatSendCapabilities(
          chatId: 77,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const DeltaChatSendCapabilities(
          exists: true,
          canSend: true,
          isEncrypted: false,
        ),
      );

      final chat = Chat(
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await expectLater(
        service.sendMessage(chat: chat, body: 'Trusted key send'),
        throwsA(isA<EmailServiceTrustedContactKeyUnavailableException>()),
      );
      verifyNever(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: any(named: 'displayName'),
          accountId: any(named: 'accountId'),
        ),
      );
      verifyNever(
        () => transport.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: any(named: 'accountId'),
          forcePlaintext: any(named: 'forcePlaintext'),
          skipAutocrypt: any(named: 'skipAutocrypt'),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test('beta-off send ignores trusted contact public key mappings', () async {
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
      () => transport.selfJidForAccount(any()),
    ).thenReturn('alice@example.org');
    when(
      () => transport.isConfigured(accountId: any(named: 'accountId')),
    ).thenAnswer((_) async => true);
    when(
      () => transport.ensureChatForAddress(
        address: 'peer@example.com',
        displayName: 'Peer',
        accountId: any(named: 'accountId'),
      ),
    ).thenAnswer((_) async => 99);

    final chat = Chat(
      jid: 'peer@example.com',
      title: 'Peer',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
      emailAddress: 'peer@example.com',
      emailFromAddress: 'alice@example.org',
    );

    await service.sendMessage(chat: chat, body: 'Plain send');

    verifyNever(
      () => database.getEmailTrustedContactKey(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        address: 'peer@example.com',
      ),
    );
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
        body: 'Plain send',
        subject: any(named: 'subject'),
        shareId: any(named: 'shareId'),
        localBodyOverride: 'Plain send',
        htmlBody: HtmlContentCodec.normalizeHtml(
          HtmlContentCodec.fromPlainText('Plain send'),
        ),
        quotingStanzaId: any(named: 'quotingStanzaId'),
        accountId: DeltaAccountDefaults.legacyId,
        forcePlaintext: true,
        skipAutocrypt: true,
      ),
    ).called(1);

    addTearDown(service.shutdown);
  });

  test(
    'beta send ignores stored mappings that are not encrypted sendable chats',
    () async {
      final service = EmailService(
        credentialStore: credentialStore,
        databaseBuilder: () async => database,
        transport: transport,
        notificationService: notificationService,
        foregroundBridge: foregroundBridge,
        emailEncryptionBetaEnabledByAddress: const {'alice@example.org': true},
      );

      await service.ensureProvisioned(
        displayName: 'Alice',
        databasePrefix: 'alice',
        databasePassphrase: 'passphrase',
        jid: 'alice@example.org',
        passwordOverride: 'password',
      );

      when(
        () => transport.selfJidForAccount(any()),
      ).thenReturn('alice@example.org');
      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => database.getDeltaChatIdsForAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => const [88]);
      when(
        () => transport.chatSendCapabilities(
          chatId: 88,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => const DeltaChatSendCapabilities(
          exists: true,
          canSend: true,
          isEncrypted: false,
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
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await service.sendMessage(chat: chat, body: 'Beta send');

      verify(
        () => transport.chatSendCapabilities(
          chatId: 88,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
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
          body: 'Beta send',
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: DeltaAccountDefaults.legacyId,
          forcePlaintext: false,
          skipAutocrypt: false,
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'sendMessage fails closed instead of using stale active Delta chat',
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
        () => database.getDeltaChatIdsForAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => const [77]);
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenThrow(const DeltaOperationException('chat lookup failed'));

      final chat = Chat(
        jid: 'peer@example.com',
        title: 'Peer',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 999,
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      await expectLater(
        service.sendMessage(chat: chat, body: 'Mapped fallback send'),
        throwsA(isA<Exception>()),
      );
      verifyNever(
        () => transport.sendText(
          chatId: any(named: 'chatId'),
          body: any(named: 'body'),
          subject: any(named: 'subject'),
          shareId: any(named: 'shareId'),
          localBodyOverride: any(named: 'localBodyOverride'),
          htmlBody: any(named: 'htmlBody'),
          quotingStanzaId: any(named: 'quotingStanzaId'),
          accountId: any(named: 'accountId'),
          forcePlaintext: any(named: 'forcePlaintext'),
          skipAutocrypt: any(named: 'skipAutocrypt'),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'forwardMessages preserves the original author label for native email forwards',
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
          address: 'target@example.com',
          displayName: 'target@example.com',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 88);

      var getChatMessageIdsCallCount = 0;
      when(
        () => transport.getChatMessageIds(
          chatId: 88,
          beforeMessageId: any(named: 'beforeMessageId'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {
        getChatMessageIdsCallCount += 1;
        return getChatMessageIdsCallCount == 1
            ? const <int>[11, 12]
            : const <int>[11, 12, 301];
      });
      when(
        () =>
            transport.getMessage(301, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 301,
          chatId: 88,
          text: 'Forwarded body',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );

      final forwardedCopy = Message(
        stanzaID: 'dc-msg-301',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body: 'Forwarded body',
        timestamp: DateTime.now(),
        deltaMsgId: 301,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      when(
        () => database.getMessageByDeltaId(
          301,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => forwardedCopy);

      final targetChat = Chat(
        jid: 'target@delta.chat',
        title: 'target@example.com',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'target@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final sourceMessage = Message(
        stanzaID: 'dc-msg-77',
        senderJid: 'forwarder@example.com',
        chatJid: 'forwarder@delta.chat',
        body: 'Forwarded body',
        timestamp: DateTime.now(),
        deltaMsgId: 77,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        subject: 'FWD: original@example.com',
      );

      final forwarded = await service.forwardMessages(
        messages: [sourceMessage],
        toChat: targetChat,
      );

      expect(forwarded, isTrue);
      verify(
        () => transport.forwardMessages(
          messageIds: [77],
          toChatId: 88,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verify(
        () => transport.hydrateMessages([
          301,
        ], accountId: DeltaAccountDefaults.legacyId),
      ).called(1);
      verify(
        () => database.updateMessage(
          any(
            that: isA<Message>().having(
              (message) => message.pseudoMessageData,
              'pseudoMessageData',
              allOf(
                containsPair('forwarded', true),
                containsPair('forwardedFromJid', 'forwarder@example.com'),
                containsPair(
                  'forwardedOriginalSenderLabel',
                  'original@example.com',
                ),
              ),
            ),
          ),
        ),
      ).called(1);

      addTearDown(service.shutdown);
    },
  );

  test(
    'forwardMessages waits for all native copies and matches them by content',
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
          address: 'target@example.com',
          displayName: 'target@example.com',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 88);

      var getChatMessageIdsCallCount = 0;
      when(
        () => transport.getChatMessageIds(
          chatId: 88,
          beforeMessageId: any(named: 'beforeMessageId'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {
        getChatMessageIdsCallCount += 1;
        return switch (getChatMessageIdsCallCount) {
          1 => const <int>[11, 12],
          2 => const <int>[11, 12, 301, 302],
          _ => const <int>[11, 12, 301, 302, 303],
        };
      });
      when(
        () =>
            transport.getMessage(301, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 301,
          chatId: 88,
          text: 'Forwarded first',
          subject: 'FWD: first@example.com',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );
      when(
        () =>
            transport.getMessage(302, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 302,
          chatId: 88,
          text: 'Unrelated note',
          subject: 'Something else',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );
      when(
        () =>
            transport.getMessage(303, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 303,
          chatId: 88,
          text:
              '-------- Forwarded message --------\n'
              'From: Original Two <second@example.com>\n'
              'Subject: Quarterly plan\n'
              '\n'
              'Forwarded second',
          subject: 'Quarterly plan',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );

      final forwardedCopyOne = Message(
        stanzaID: 'dc-msg-301',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body: 'Forwarded first',
        subject: 'FWD: first@example.com',
        timestamp: DateTime.now(),
        deltaMsgId: 301,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      final unrelatedMessage = Message(
        stanzaID: 'dc-msg-302',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body: 'Unrelated note',
        subject: 'Something else',
        timestamp: DateTime.now(),
        deltaMsgId: 302,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      final forwardedCopyTwo = Message(
        stanzaID: 'dc-msg-303',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body:
            '-------- Forwarded message --------\n'
            'From: Original Two <second@example.com>\n'
            'Subject: Quarterly plan\n'
            '\n'
            'Forwarded second',
        subject: 'Quarterly plan',
        timestamp: DateTime.now(),
        deltaMsgId: 303,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      when(
        () => database.getMessageByDeltaId(
          301,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => forwardedCopyOne);
      when(
        () => database.getMessageByDeltaId(
          302,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => unrelatedMessage);
      when(
        () => database.getMessageByDeltaId(
          303,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => forwardedCopyTwo);

      final targetChat = Chat(
        jid: 'target@delta.chat',
        title: 'target@example.com',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'target@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final sourceMessages = [
        Message(
          stanzaID: 'dc-msg-77',
          senderJid: 'forwarder-one@example.com',
          chatJid: 'forwarder-one@delta.chat',
          body: 'Forwarded first',
          subject: 'FWD: first@example.com',
          timestamp: DateTime.now(),
          deltaMsgId: 77,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        Message(
          stanzaID: 'dc-msg-78',
          senderJid: 'forwarder-two@example.com',
          chatJid: 'forwarder-two@delta.chat',
          body:
              '-------- Forwarded message --------\n'
              'From: Original Two <second@example.com>\n'
              'Subject: Quarterly plan\n'
              '\n'
              'Forwarded second',
          subject: 'Quarterly plan',
          timestamp: DateTime.now(),
          deltaMsgId: 78,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ];

      final forwarded = await service.forwardMessages(
        messages: sourceMessages,
        toChat: targetChat,
      );

      expect(forwarded, isTrue);
      verify(
        () => transport.forwardMessages(
          messageIds: [77, 78],
          toChatId: 88,
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).called(1);
      verify(
        () => database.updateMessage(
          any(
            that: isA<Message>()
                .having((message) => message.deltaMsgId, 'deltaMsgId', 301)
                .having(
                  (message) => message.pseudoMessageData,
                  'pseudoMessageData',
                  allOf(
                    containsPair('forwarded', true),
                    containsPair(
                      'forwardedFromJid',
                      'forwarder-one@example.com',
                    ),
                    containsPair(
                      'forwardedOriginalSenderLabel',
                      'first@example.com',
                    ),
                  ),
                ),
          ),
        ),
      ).called(1);
      verify(
        () => database.updateMessage(
          any(
            that: isA<Message>()
                .having((message) => message.deltaMsgId, 'deltaMsgId', 303)
                .having(
                  (message) => message.pseudoMessageData,
                  'pseudoMessageData',
                  allOf(
                    containsPair('forwarded', true),
                    containsPair(
                      'forwardedFromJid',
                      'forwarder-two@example.com',
                    ),
                    containsPair(
                      'forwardedOriginalSenderLabel',
                      'second@example.com',
                    ),
                  ),
                ),
          ),
        ),
      ).called(1);
      verifyNever(
        () => database.updateMessage(
          any(
            that: isA<Message>().having(
              (message) => message.deltaMsgId,
              'deltaMsgId',
              302,
            ),
          ),
        ),
      );

      addTearDown(service.shutdown);
    },
  );

  test(
    'forwardMessages prefers subject-matched native forward provenance for repeated bodies',
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
          address: 'target@example.com',
          displayName: 'target@example.com',
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => 88);

      var getChatMessageIdsCallCount = 0;
      when(
        () => transport.getChatMessageIds(
          chatId: 88,
          beforeMessageId: any(named: 'beforeMessageId'),
          accountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async {
        getChatMessageIdsCallCount += 1;
        return getChatMessageIdsCallCount == 1
            ? const <int>[11]
            : const <int>[11, 401, 402];
      });
      when(
        () =>
            transport.getMessage(401, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 401,
          chatId: 88,
          text: 'Repeated forwarded body',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );
      when(
        () =>
            transport.getMessage(402, accountId: DeltaAccountDefaults.legacyId),
      ).thenAnswer(
        (_) async => DeltaMessage(
          id: 402,
          chatId: 88,
          text: 'Repeated forwarded body',
          subject: 'Alpha',
          timestamp: DateTime.now(),
          isOutgoing: true,
        ),
      );

      final forwardedCopyOne = Message(
        stanzaID: 'dc-msg-401',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body: 'Repeated forwarded body',
        timestamp: DateTime.now(),
        deltaMsgId: 401,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      final forwardedCopyTwo = Message(
        stanzaID: 'dc-msg-402',
        senderJid: 'alice@example.org',
        chatJid: 'target@delta.chat',
        body: 'Repeated forwarded body',
        subject: 'Alpha',
        timestamp: DateTime.now(),
        deltaMsgId: 402,
        deltaAccountId: DeltaAccountDefaults.legacyId,
      );
      when(
        () => database.getMessageByDeltaId(
          401,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => forwardedCopyOne);
      when(
        () => database.getMessageByDeltaId(
          402,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => forwardedCopyTwo);

      final targetChat = Chat(
        jid: 'target@delta.chat',
        title: 'target@example.com',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.now(),
        deltaChatId: 88,
        emailAddress: 'target@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final sourceMessages = [
        Message(
          stanzaID: 'dc-msg-91',
          senderJid: 'first@example.com',
          chatJid: 'first@delta.chat',
          body: 'Repeated forwarded body',
          subject: 'Alpha',
          timestamp: DateTime.now(),
          deltaMsgId: 91,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
        Message(
          stanzaID: 'dc-msg-92',
          senderJid: 'second@example.com',
          chatJid: 'second@delta.chat',
          body: 'Repeated forwarded body',
          subject: 'Alpha',
          timestamp: DateTime.now(),
          deltaMsgId: 92,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ];

      final forwarded = await service.forwardMessages(
        messages: sourceMessages,
        toChat: targetChat,
      );

      expect(forwarded, isTrue);
      verify(
        () => database.updateMessage(
          any(
            that: isA<Message>()
                .having((message) => message.deltaMsgId, 'deltaMsgId', 402)
                .having(
                  (message) => message.forwardedFromJid,
                  'forwardedFromJid',
                  'first@example.com',
                ),
          ),
        ),
      ).called(1);
      verify(
        () => database.updateMessage(
          any(
            that: isA<Message>()
                .having((message) => message.deltaMsgId, 'deltaMsgId', 401)
                .having(
                  (message) => message.forwardedFromJid,
                  'forwardedFromJid',
                  'second@example.com',
                ),
          ),
        ),
      ).called(1);

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
        () => database.getDeltaChatIdsForAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer((_) async => const [77]);
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenThrow(const DeltaOperationException('chat lookup failed'));
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
    'markNoticedChat resolves the canonical direct chat row before delegating',
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
        () => database.upsertEmailChatAccount(
          chatJid: 'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 91,
        ),
      ).called(1);
      verify(
        () => transport.markNoticedChat(
          91,
          accountId: DeltaAccountDefaults.legacyId,
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
        () => database.countEmailBackedChatMessages(
          'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
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
        () => database.countEmailBackedChatMessages(
          'peer@example.com',
          deltaAccountId: DeltaAccountDefaults.legacyId,
          filter: MessageTimelineFilter.directOnly,
          includePseudoMessages: false,
        ),
      ).called(1);
      verifyNever(
        () => database.countEmailBackedChatMessages(
          'dc-91@delta.chat',
          deltaAccountId: any(named: 'deltaAccountId'),
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
    'backfillChatHistory runs for mixed XMPP chats with email backing',
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

      final mixedChat = Chat(
        jid: 'peer@axi.im',
        title: 'Peer',
        type: ChatType.chat,
        transport: MessageTransport.xmpp,
        lastChangeTimestamp: DateTime.now(),
        contactJid: 'peer@axi.im',
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );
      final nativeEmailChat = Chat(
        jid: 'peer@example.com',
        title: 'Peer Email',
        type: ChatType.chat,
        transport: MessageTransport.email,
        lastChangeTimestamp: DateTime.now(),
        contactJid: 'peer@example.com',
        emailAddress: 'peer@example.com',
        emailFromAddress: 'alice@example.org',
      );

      when(
        () => transport.isConfigured(accountId: any(named: 'accountId')),
      ).thenAnswer((_) async => true);
      when(
        () => database.getChat(mixedChat.jid),
      ).thenAnswer((_) async => mixedChat);
      when(
        () => database.getChat(nativeEmailChat.jid),
      ).thenAnswer((_) async => nativeEmailChat);
      when(
        () => transport.ensureChatForAddress(
          address: 'peer@example.com',
          displayName: 'Peer',
          accountId: any(named: 'accountId'),
        ),
      ).thenAnswer((_) async => 92);
      when(
        () => database.countEmailBackedChatMessages(
          mixedChat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          filter: MessageTimelineFilter.directOnly,
          includePseudoMessages: false,
        ),
      ).thenAnswer((_) async => 1);
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
        chat: mixedChat,
        desiredWindow: 5,
        beforeTimestamp: DateTime(2024, 1, 1),
      );

      verify(
        () => database.countEmailBackedChatMessages(
          mixedChat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          filter: MessageTimelineFilter.directOnly,
          includePseudoMessages: false,
        ),
      ).called(1);
      verifyNever(() => database.getChat(nativeEmailChat.jid));
      verify(
        () => database.upsertEmailChatAccount(
          chatJid: mixedChat.jid,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          deltaChatId: 92,
        ),
      ).called(1);
      verifyNever(
        () => database.upsertEmailChatAccount(
          chatJid: nativeEmailChat.jid,
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      );
      verifyNever(
        () => database.countChatMessages(
          mixedChat.jid,
          filter: any(named: 'filter'),
          includePseudoMessages: any(named: 'includePseudoMessages'),
        ),
      );
      verify(
        () => transport.backfillChatHistory(
          chatId: 92,
          chatJid: mixedChat.jid,
          desiredWindow: 5,
          beforeMessageId: null,
          beforeTimestamp: DateTime(2024, 1, 1),
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
    final participantChat = Chat(
      jid: 'dc-1@delta.chat',
      title: 'Bob',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.now(),
    );
    when(
      () => database.getChatsByJids(
        any(
          that: predicate<Iterable<String>>(
            (Iterable<String> jids) =>
                jids.length == 1 && jids.first == 'dc-1@delta.chat',
          ),
        ),
      ),
    ).thenAnswer((_) async => [participantChat]);

    final contextResult = await service.shareContextForMessage(message);

    expect(contextResult, isNotNull);
    expect(contextResult!.participants, hasLength(1));
    expect(contextResult.participants.first.title, 'Bob');

    addTearDown(service.shutdown);
  });
}
