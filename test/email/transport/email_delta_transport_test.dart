import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/models/email_attachment.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/util/delta_message_ids.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:delta_ffi/delta_safe.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../mocks.dart';

class MockDeltaSafe extends Mock implements DeltaSafe {}

class MockDeltaAccountsHandle extends Mock implements DeltaAccountsHandle {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => supportPath;
}

final class _CancelFailingDeltaEventStream extends Stream<DeltaCoreEvent> {
  _CancelFailingDeltaEventStream(this.subscription);

  final StreamSubscription<DeltaCoreEvent> subscription;

  @override
  StreamSubscription<DeltaCoreEvent> listen(
    void Function(DeltaCoreEvent event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => subscription;
}

final class _CancelFailingDeltaEventSubscription
    implements StreamSubscription<DeltaCoreEvent> {
  @override
  Future<void> cancel() => Future<void>.error(Exception('cancel failed'));

  @override
  Future<E> asFuture<E>([E? futureValue]) => Completer<E>().future;

  @override
  bool get isPaused => false;

  @override
  void onData(void Function(DeltaCoreEvent data)? handleData) {}

  @override
  void onDone(void Function()? handleDone) {}

  @override
  void onError(Function? handleError) {}

  @override
  void pause([Future<void>? resumeSignal]) {}

  @override
  void resume() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockDeltaSafe deltaSafe;
  late MockDeltaContextHandle context;
  late MockXmppDatabase database;
  late EmailDeltaTransport transport;
  late PathProviderPlatform originalPathProvider;
  late Directory supportDir;

  setUpAll(() {
    registerFallbackValue(fallbackMessage);
    registerFallbackValue(
      const FileMetadataData(id: 'fallback-file', filename: 'fallback.txt'),
    );
    registerFallbackValue(<String>[]);
    registerFallbackValue(Duration.zero);
  });

  setUp(() async {
    originalPathProvider = PathProviderPlatform.instance;
    supportDir = await Directory.systemTemp.createTemp(
      'email_delta_transport_test',
    );
    PathProviderPlatform.instance = _FakePathProviderPlatform(supportDir.path);
    deltaSafe = MockDeltaSafe();
    context = MockDeltaContextHandle();
    database = MockXmppDatabase();
    transport = EmailDeltaTransport(
      databaseBuilder: () async => database,
      deltaSafe: deltaSafe,
    );
    when(() => context.supportsMessageRfc724Mid).thenReturn(true);
    when(() => context.supportsMessageInfo).thenReturn(true);
    when(() => context.getMessageInfo(any())).thenAnswer((_) async => null);
  });

  StreamController<DeltaCoreEvent> stubInitializedSingleContext() {
    final events = StreamController<DeltaCoreEvent>.broadcast();
    when(
      () => deltaSafe.createAccounts(directory: any(named: 'directory')),
    ).thenThrow(const DeltaAllocationException('accounts unavailable'));
    when(
      () => deltaSafe.createContext(
        databasePath: any(named: 'databasePath'),
        osName: any(named: 'osName'),
      ),
    ).thenAnswer((_) async => context);
    when(
      () => context.open(passphrase: any(named: 'passphrase')),
    ).thenAnswer((_) async {});
    when(
      () => context.getConfig('addr'),
    ).thenAnswer((_) async => 'me@example.com');
    when(() => context.events()).thenAnswer((_) => events.stream);
    when(
      () => context.getMessageIdsByRfc724Mid(any()),
    ).thenAnswer((_) async => const <int>[]);
    when(
      () => database.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        resolvedAddress: 'me@example.com',
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.removeDeltaPlaceholderDuplicates(
        deltaAccountId: DeltaAccountDefaults.legacyId,
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});
    return events;
  }

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    if (await supportDir.exists()) {
      await supportDir.delete(recursive: true);
    }
  });

  test(
    'sendText applies the Delta timestamp reported for the sent message',
    () async {
      const chatId = 7;
      const msgId = 70;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
        emailFromAddress: 'me@example.com',
      );
      final staleDeltaTimestamp = DateTime.timestamp().subtract(
        const Duration(minutes: 10),
      );
      Message? pendingMessage;

      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenThrow(const DeltaAllocationException('accounts unavailable'));
      when(
        () => deltaSafe.createContext(
          databasePath: any(named: 'databasePath'),
          osName: any(named: 'osName'),
        ),
      ).thenAnswer((_) async => context);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => context.isConfigured).thenReturn(true);
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
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
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      ).thenAnswer((invocation) async {
        pendingMessage = invocation.positionalArguments.first as Message;
      });
      when(
        () => context.sendText(
          chatId: chatId,
          message: 'hello',
          subject: any(named: 'subject'),
          html: any(named: 'html'),
          forcePlaintext: false,
          skipAutocrypt: false,
        ),
      ).thenAnswer((_) async => msgId);
      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          text: 'hello',
          timestamp: staleDeltaTimestamp,
          isOutgoing: true,
        ),
      );
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => 'Message-ID: <origin@example.com>');
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => pendingMessage?.copyWith(
          deltaMsgId: msgId,
          deltaChatId: chatId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          originID: 'origin@example.com',
        ),
      );
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => pendingMessage);
      when(() => database.updateMessage(any())).thenAnswer((_) async {});

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      expect(await transport.isConfigured(), isTrue);

      await transport.sendText(chatId: chatId, body: 'hello');

      final localPending = pendingMessage;
      expect(localPending, isNotNull);
      expect(localPending!.timestamp, isNot(staleDeltaTimestamp));
      final updated =
          verify(() => database.updateMessage(captureAny())).captured.single
              as Message;
      expect(updated.deltaMsgId, msgId);
      expect(updated.deltaChatId, chatId);
      expect(updated.deltaAccountId, DeltaAccountDefaults.legacyId);
      expect(updated.timestamp, staleDeltaTimestamp);
    },
  );

  test(
    'sendAttachment without caption does not persist a generated body',
    () async {
      const chatId = 7;
      const msgId = 72;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
        emailFromAddress: 'me@example.com',
      );
      final sentTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      Message? pendingMessage;

      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenThrow(const DeltaAllocationException('accounts unavailable'));
      when(
        () => deltaSafe.createContext(
          databasePath: any(named: 'databasePath'),
          osName: any(named: 'osName'),
        ),
      ).thenAnswer((_) async => context);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => context.isConfigured).thenReturn(true);
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
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
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
      when(() => database.deleteFileMetadata(any())).thenAnswer((_) async {});
      when(
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      ).thenAnswer((invocation) async {
        pendingMessage = invocation.positionalArguments.first as Message;
      });
      when(
        () => context.sendFileMessage(
          chatId: chatId,
          viewType: any(named: 'viewType'),
          filePath: '/tmp/image.png',
          fileName: 'image.png',
          mimeType: 'image/png',
          text: any(named: 'text'),
          subject: any(named: 'subject'),
          html: any(named: 'html'),
          forcePlaintext: false,
          skipAutocrypt: false,
        ),
      ).thenAnswer((_) async => msgId);
      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          fileName: 'image.png',
          filePath: '/tmp/image.png',
          fileMime: 'image/png',
          fileSize: 1024,
          timestamp: sentTimestamp,
          isOutgoing: true,
        ),
      );
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => 'Message-ID: <attachment@example.com>');
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => pendingMessage?.copyWith(
          deltaMsgId: msgId,
          deltaChatId: chatId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
          originID: 'attachment@example.com',
        ),
      );
      when(
        () => database.getMessageByStanzaID(any()),
      ).thenAnswer((_) async => pendingMessage);
      when(() => database.updateMessage(any())).thenAnswer((_) async {});

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.isConfigured();

      await transport.sendAttachment(
        chatId: chatId,
        attachment: const EmailAttachment(
          path: '/tmp/image.png',
          fileName: 'image.png',
          sizeBytes: 1024,
          mimeType: 'image/png',
        ),
      );

      final localPending = pendingMessage;
      expect(localPending, isNotNull);
      expect(localPending!.body, isNull);
      expect(localPending.fileMetadataID, startsWith('dc-pending-'));
      final updated =
          verify(() => database.updateMessage(captureAny())).captured.single
              as Message;
      expect(updated.body, isNull);
      expect(updated.fileMetadataID, deltaFileMetadataId(msgId));
    },
  );

  test(
    'sendAttachment removes duplicate Delta row ingested before pending send is marked',
    () async {
      const chatId = 7;
      const msgId = 73;
      final chat = Chat(
        jid: 'alice@example.com',
        title: 'Alice',
        type: ChatType.chat,
        lastChangeTimestamp: DateTime.utc(2024, 1, 1),
        transport: MessageTransport.email,
        encryptionProtocol: EncryptionProtocol.none,
        deltaChatId: chatId,
        emailAddress: 'alice@example.com',
        emailFromAddress: 'me@example.com',
      );
      final sentTimestamp = DateTime.utc(2024, 1, 2, 3, 4, 5);
      final deltaStanzaId = deltaMessageStanzaId(msgId);
      final duplicateMessage = Message(
        stanzaID: deltaStanzaId,
        senderJid: 'me@example.com',
        chatJid: chat.jid,
        timestamp: sentTimestamp,
        originID: 'attachment@example.com',
        subject: 'Photos',
        deltaChatId: chatId,
        deltaMsgId: msgId,
        deltaAccountId: DeltaAccountDefaults.legacyId,
        fileMetadataID: deltaFileMetadataId(msgId),
      );
      Message? pendingMessage;
      Message? updatedPending;
      var duplicateDeleted = false;

      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenThrow(const DeltaAllocationException('accounts unavailable'));
      when(
        () => deltaSafe.createContext(
          databasePath: any(named: 'databasePath'),
          osName: any(named: 'osName'),
        ),
      ).thenAnswer((_) async => context);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => context.isConfigured).thenReturn(true);
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: DeltaAccountDefaults.legacyId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});
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
      when(() => database.saveFileMetadata(any())).thenAnswer((_) async {});
      when(() => database.deleteFileMetadata(any())).thenAnswer((_) async {});
      when(
        () => database.saveMessage(any(), selfJid: any(named: 'selfJid')),
      ).thenAnswer((invocation) async {
        pendingMessage = invocation.positionalArguments.first as Message;
      });
      when(
        () => context.sendFileMessage(
          chatId: chatId,
          viewType: any(named: 'viewType'),
          filePath: '/tmp/image.png',
          fileName: 'image.png',
          mimeType: 'image/png',
          text: 'Photos',
          subject: 'Photos',
          html: any(named: 'html'),
          forcePlaintext: false,
          skipAutocrypt: false,
        ),
      ).thenAnswer((_) async => msgId);
      when(() => context.getMessage(msgId)).thenAnswer(
        (_) async => DeltaMessage(
          id: msgId,
          chatId: chatId,
          subject: 'Photos',
          filePath: '/tmp/image.png',
          fileMime: 'image/png',
          fileSize: 1024,
          timestamp: sentTimestamp,
          isOutgoing: true,
        ),
      );
      when(
        () => context.getMessageMimeHeaders(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => context.getMessageRfc724Mid(msgId),
      ).thenAnswer((_) async => null);
      when(
        () => database.getMessageByDeltaId(
          msgId,
          deltaAccountId: DeltaAccountDefaults.legacyId,
        ),
      ).thenAnswer(
        (_) async => duplicateDeleted ? updatedPending : duplicateMessage,
      );
      when(() => database.getMessageByStanzaID(any())).thenAnswer((
        invocation,
      ) async {
        final stanzaId = invocation.positionalArguments.first as String;
        if (stanzaId == deltaStanzaId) {
          return duplicateDeleted ? null : duplicateMessage;
        }
        return pendingMessage;
      });
      when(() => database.updateMessage(any())).thenAnswer((invocation) async {
        updatedPending = invocation.positionalArguments.first as Message;
      });
      when(
        () => database.deleteMessage(
          deltaStanzaId,
          selfJid: 'me@example.com',
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {
        duplicateDeleted = true;
      });

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.isConfigured();

      await transport.sendAttachment(
        chatId: chatId,
        subject: 'Photos',
        attachment: const EmailAttachment(
          path: '/tmp/image.png',
          fileName: 'image.png',
          caption: 'Photos',
          sizeBytes: 1024,
          mimeType: 'image/png',
        ),
      );

      expect(updatedPending?.deltaMsgId, msgId);
      expect(updatedPending?.deltaChatId, chatId);
      expect(updatedPending?.deltaAccountId, DeltaAccountDefaults.legacyId);
      expect(updatedPending?.originID, 'attachment@example.com');
      verify(
        () => database.deleteMessage(
          deltaStanzaId,
          selfJid: 'me@example.com',
          emailSelfJid: 'me@example.com',
        ),
      ).called(1);
    },
  );

  test(
    'stopEventDeliveryAndAwaitActiveOperations waits for tracked chatlist refresh without stopping native IO',
    () async {
      const chatId = 9;
      final events = stubInitializedSingleContext();
      final getChatlistStarted = Completer<void>();
      final getChatlistCompleter = Completer<List<DeltaChatlistEntry>>();
      addTearDown(events.close);

      when(() => context.getChatlist()).thenAnswer((_) {
        if (!getChatlistStarted.isCompleted) {
          getChatlistStarted.complete();
        }
        return getChatlistCompleter.future;
      });
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      final refresh = transport.refreshChatlistSnapshot();
      await getChatlistStarted.future.timeout(const Duration(seconds: 1));

      var barrierCompleted = false;
      final barrier = transport
          .stopEventDeliveryAndAwaitActiveOperations()
          .whenComplete(() {
            barrierCompleted = true;
          });
      await pumpEventQueue();

      expect(barrierCompleted, isFalse);
      verifyNever(() => context.stopIo());

      getChatlistCompleter.complete(const [
        DeltaChatlistEntry(chatId: chatId, msgId: DeltaMessageId.dayMarker),
      ]);
      await refresh;
      await barrier;

      expect(barrierCompleted, isTrue);
      verifyNever(() => context.stopIo());
    },
  );

  test(
    'stopEventDeliveryAndAwaitActiveOperations prevents session registration from reattaching events',
    () async {
      const primaryAccountId = 1;
      const secondAccountId = 2;
      final accounts = MockDeltaAccountsHandle();
      final secondContext = MockDeltaContextHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      final secondOpenStarted = Completer<void>();
      final secondOpenCompleter = Completer<void>();
      addTearDown(events.close);

      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenAnswer((_) async => accounts);
      when(
        () => accounts.ensureAccount(
          legacyDatabasePath: any(named: 'legacyDatabasePath'),
        ),
      ).thenAnswer((_) async => primaryAccountId);
      when(() => accounts.contextFor(primaryAccountId)).thenReturn(context);
      when(
        () => accounts.contextFor(secondAccountId),
      ).thenReturn(secondContext);
      when(() => accounts.events()).thenAnswer((_) => events.stream);
      when(() => accounts.startIo()).thenAnswer((_) async {});
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => secondContext.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) {
        if (!secondOpenStarted.isCompleted) {
          secondOpenStarted.complete();
        }
        return secondOpenCompleter.future;
      });
      when(() => secondContext.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'two@example.com' : null;
      });
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

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.start();
      expect(events.hasListener, isTrue);

      final refresh = transport.refreshChatlistSnapshot(
        accountId: secondAccountId,
      );
      await secondOpenStarted.future.timeout(const Duration(seconds: 1));

      final barrier = transport.stopEventDeliveryAndAwaitActiveOperations();
      await pumpEventQueue();
      expect(events.hasListener, isFalse);

      secondOpenCompleter.complete();
      await refresh;
      await barrier;

      expect(events.hasListener, isFalse);
      verifyNever(() => accounts.stopIo());
    },
  );

  test(
    'stopEventDeliveryAndAwaitActiveOperations still waits when cancel fails',
    () async {
      const chatId = 10;
      final events = _CancelFailingDeltaEventStream(
        _CancelFailingDeltaEventSubscription(),
      );
      final getChatlistStarted = Completer<void>();
      final getChatlistCompleter = Completer<List<DeltaChatlistEntry>>();

      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenThrow(const DeltaAllocationException('accounts unavailable'));
      when(
        () => deltaSafe.createContext(
          databasePath: any(named: 'databasePath'),
          osName: any(named: 'osName'),
        ),
      ).thenAnswer((_) async => context);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(() => context.events()).thenAnswer((_) => events);
      when(() => context.startIo()).thenAnswer((_) async {});
      when(() => context.getChatlist()).thenAnswer((_) {
        if (!getChatlistStarted.isCompleted) {
          getChatlistStarted.complete();
        }
        return getChatlistCompleter.future;
      });
      when(
        () => context.getChatlist(flags: DeltaChatlistFlags.archivedOnly),
      ).thenAnswer((_) async => const <DeltaChatlistEntry>[]);
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

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.start();

      final refresh = transport.refreshChatlistSnapshot();
      await getChatlistStarted.future.timeout(const Duration(seconds: 1));

      var barrierCompleted = false;
      final barrierResult = transport
          .stopEventDeliveryAndAwaitActiveOperations()
          .then<Object?>((_) => null, onError: (error, _) => error)
          .whenComplete(() {
            barrierCompleted = true;
          });
      await pumpEventQueue();

      expect(barrierCompleted, isFalse);
      verifyNever(() => context.stopIo());

      getChatlistCompleter.complete(const [
        DeltaChatlistEntry(chatId: chatId, msgId: DeltaMessageId.dayMarker),
      ]);
      await refresh;

      expect(await barrierResult, isA<Exception>());
      expect(barrierCompleted, isTrue);
      verifyNever(() => context.stopIo());
    },
  );

  test('stop still stops native IO when event cancellation fails', () async {
    final events = _CancelFailingDeltaEventStream(
      _CancelFailingDeltaEventSubscription(),
    );

    when(
      () => deltaSafe.createAccounts(directory: any(named: 'directory')),
    ).thenThrow(const DeltaAllocationException('accounts unavailable'));
    when(
      () => deltaSafe.createContext(
        databasePath: any(named: 'databasePath'),
        osName: any(named: 'osName'),
      ),
    ).thenAnswer((_) async => context);
    when(
      () => context.open(passphrase: any(named: 'passphrase')),
    ).thenAnswer((_) async {});
    when(() => context.getConfig(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.first as String;
      return key == 'addr' ? 'me@example.com' : null;
    });
    when(
      () => context.setConfig(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => context.events()).thenAnswer((_) => events);
    when(() => context.startIo()).thenAnswer((_) async {});
    when(() => context.stopIo()).thenAnswer((_) async {});
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

    await transport.ensureInitialized(
      databasePrefix: 'email_delta_transport_test',
      databasePassphrase: 'test-passphrase',
    );
    await transport.start();

    await expectLater(transport.stop(), throwsA(isA<Exception>()));

    expect(transport.isIoRunning, isFalse);
    verify(() => context.stopIo()).called(1);
  });

  test(
    'runImex listens before starting and waits for success progress',
    () async {
      final events = stubInitializedSingleContext();
      addTearDown(events.close);
      var listenerAttachedWhenStarted = false;
      final started = Completer<void>();

      when(
        () => context.startImex(
          mode: DeltaImexMode.exportSelfKeys,
          path: any(named: 'path'),
        ),
      ).thenAnswer((_) async {
        listenerAttachedWhenStarted = events.hasListener;
        events.add(
          DeltaCoreEvent(
            type: DeltaEventType.imexFileWritten.code,
            data1: 0,
            data2: 0,
            data2Text: '/tmp/key.asc',
          ),
        );
        started.complete();
      });

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      final future = transport.runImex(
        mode: DeltaImexMode.exportSelfKeys,
        path: '/tmp/export',
        timeout: const Duration(seconds: 1),
      );
      var completed = false;
      unawaited(future.then((_) => completed = true));
      await started.future.timeout(const Duration(seconds: 1));

      expect(listenerAttachedWhenStarted, isTrue);
      expect(completed, isFalse);

      events.add(
        DeltaCoreEvent(
          type: DeltaEventType.imexProgress.code,
          data1: 1000,
          data2: 0,
        ),
      );

      final result = await future;

      expect(completed, isTrue);
      expect(result.accountId, DeltaAccountDefaults.legacyId);
      expect(result.exportedPaths, ['/tmp/key.asc']);
    },
  );

  test('runImex maps zero progress to IMEX failure', () async {
    final events = stubInitializedSingleContext();
    addTearDown(events.close);

    when(
      () => context.startImex(
        mode: DeltaImexMode.importSelfKeys,
        path: any(named: 'path'),
      ),
    ).thenAnswer((_) async {
      events.add(
        DeltaCoreEvent(
          type: DeltaEventType.imexProgress.code,
          data1: 0,
          data2: 0,
          data2Text: 'bad key',
        ),
      );
    });

    await transport.ensureInitialized(
      databasePrefix: 'email_delta_transport_test',
      databasePassphrase: 'test-passphrase',
    );

    await expectLater(
      transport.runImex(
        mode: DeltaImexMode.importSelfKeys,
        path: '/tmp/import.asc',
        timeout: const Duration(seconds: 1),
      ),
      throwsA(isA<EmailDeltaImexException>()),
    );
  });

  test(
    'performBackgroundFetch keeps temporary event subscription until fetch completes',
    () async {
      const accountId = 1;
      final accounts = MockDeltaAccountsHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      final fetchCompleter = Completer<bool>();
      addTearDown(events.close);
      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenAnswer((_) async => accounts);
      when(
        () => accounts.ensureAccount(
          legacyDatabasePath: any(named: 'legacyDatabasePath'),
        ),
      ).thenAnswer((_) async => accountId);
      when(() => accounts.contextFor(accountId)).thenReturn(context);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(
        () => context.getConfig('addr'),
      ).thenAnswer((_) async => 'me@example.com');
      when(() => accounts.events()).thenAnswer((_) => events.stream);
      when(
        () => accounts.backgroundFetch(any()),
      ).thenAnswer((_) => fetchCompleter.future);
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: accountId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: accountId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      final fetch = transport.performBackgroundFetch(
        const Duration(seconds: 5),
      );
      await pumpEventQueue();

      expect(events.hasListener, isTrue);

      fetchCompleter.complete(true);
      expect(await fetch, isTrue);
      await pumpEventQueue();

      expect(events.hasListener, isFalse);
    },
  );

  test(
    'performBackgroundFetch can attach temporary events after stop blocked delivery',
    () async {
      const accountId = 1;
      final accounts = MockDeltaAccountsHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      addTearDown(events.close);
      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenAnswer((_) async => accounts);
      when(
        () => accounts.ensureAccount(
          legacyDatabasePath: any(named: 'legacyDatabasePath'),
        ),
      ).thenAnswer((_) async => accountId);
      when(() => accounts.contextFor(accountId)).thenReturn(context);
      when(() => accounts.events()).thenAnswer((_) => events.stream);
      when(() => accounts.startIo()).thenAnswer((_) async {});
      when(() => accounts.stopIo()).thenAnswer((_) async {});
      when(() => accounts.backgroundFetch(any())).thenAnswer((_) async {
        expect(events.hasListener, isTrue);
        return true;
      });
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: accountId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: accountId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.start();
      expect(events.hasListener, isTrue);
      await transport.stop();
      expect(events.hasListener, isFalse);

      expect(
        await transport.performBackgroundFetch(const Duration(seconds: 5)),
        isTrue,
      );

      expect(events.hasListener, isFalse);
    },
  );

  test(
    'performBackgroundFetch skips temporary events after logout blocks delivery',
    () async {
      const accountId = 1;
      final accounts = MockDeltaAccountsHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      addTearDown(events.close);
      when(
        () => deltaSafe.createAccounts(directory: any(named: 'directory')),
      ).thenAnswer((_) async => accounts);
      when(
        () => accounts.ensureAccount(
          legacyDatabasePath: any(named: 'legacyDatabasePath'),
        ),
      ).thenAnswer((_) async => accountId);
      when(() => accounts.contextFor(accountId)).thenReturn(context);
      when(() => accounts.events()).thenAnswer((_) => events.stream);
      when(() => accounts.backgroundFetch(any())).thenAnswer((_) async => true);
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'me@example.com' : null;
      });
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: accountId,
          resolvedAddress: 'me@example.com',
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.removeDeltaPlaceholderDuplicates(
          deltaAccountId: accountId,
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: 'me@example.com',
        ),
      ).thenAnswer((_) async {});

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.stopEventDeliveryForLogout();

      expect(
        await transport.performBackgroundFetch(const Duration(seconds: 5)),
        isFalse,
      );
      expect(events.hasListener, isFalse);
      verifyNever(() => accounts.backgroundFetch(any()));
    },
  );

  test('start after stop re-enables persistent event delivery', () async {
    const accountId = 1;
    final accounts = MockDeltaAccountsHandle();
    final events = StreamController<DeltaCoreEvent>.broadcast();
    addTearDown(events.close);
    when(
      () => deltaSafe.createAccounts(directory: any(named: 'directory')),
    ).thenAnswer((_) async => accounts);
    when(
      () => accounts.ensureAccount(
        legacyDatabasePath: any(named: 'legacyDatabasePath'),
      ),
    ).thenAnswer((_) async => accountId);
    when(() => accounts.contextFor(accountId)).thenReturn(context);
    when(() => accounts.events()).thenAnswer((_) => events.stream);
    when(() => accounts.startIo()).thenAnswer((_) async {});
    when(() => accounts.stopIo()).thenAnswer((_) async {});
    when(
      () => context.open(passphrase: any(named: 'passphrase')),
    ).thenAnswer((_) async {});
    when(() => context.getConfig(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.first as String;
      return key == 'addr' ? 'me@example.com' : null;
    });
    when(
      () => context.setConfig(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: accountId,
        resolvedAddress: 'me@example.com',
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.removeDeltaPlaceholderDuplicates(
        deltaAccountId: accountId,
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});

    await transport.ensureInitialized(
      databasePrefix: 'email_delta_transport_test',
      databasePassphrase: 'test-passphrase',
    );
    await transport.start();
    expect(events.hasListener, isTrue);
    await transport.stop();
    expect(events.hasListener, isFalse);

    await transport.start();

    expect(events.hasListener, isTrue);
  });

  test('dispose after stop does not stop native IO twice', () async {
    const accountId = 1;
    final accounts = MockDeltaAccountsHandle();
    final events = StreamController<DeltaCoreEvent>.broadcast();
    addTearDown(events.close);
    when(
      () => deltaSafe.createAccounts(directory: any(named: 'directory')),
    ).thenAnswer((_) async => accounts);
    when(
      () => accounts.ensureAccount(
        legacyDatabasePath: any(named: 'legacyDatabasePath'),
      ),
    ).thenAnswer((_) async => accountId);
    when(() => accounts.contextFor(accountId)).thenReturn(context);
    when(() => accounts.events()).thenAnswer((_) => events.stream);
    when(() => accounts.startIo()).thenAnswer((_) async {});
    when(() => accounts.stopIo()).thenAnswer((_) async {});
    when(() => accounts.dispose()).thenAnswer((_) async {});
    when(
      () => context.open(passphrase: any(named: 'passphrase')),
    ).thenAnswer((_) async {});
    when(() => context.getConfig(any())).thenAnswer((invocation) async {
      final key = invocation.positionalArguments.first as String;
      return key == 'addr' ? 'me@example.com' : null;
    });
    when(
      () => context.setConfig(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => context.close()).thenAnswer((_) async {});
    when(
      () => database.replaceDeltaPlaceholderSelfJids(
        deltaAccountId: accountId,
        resolvedAddress: 'me@example.com',
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});
    when(
      () => database.removeDeltaPlaceholderDuplicates(
        deltaAccountId: accountId,
        placeholderJids: any(named: 'placeholderJids'),
        selfJid: any(named: 'selfJid'),
        emailSelfJid: 'me@example.com',
      ),
    ).thenAnswer((_) async {});

    await transport.ensureInitialized(
      databasePrefix: 'email_delta_transport_test',
      databasePassphrase: 'test-passphrase',
    );
    await transport.start();
    await transport.stop();

    await transport.dispose();

    verify(() => accounts.stopIo()).called(1);
  });
}
