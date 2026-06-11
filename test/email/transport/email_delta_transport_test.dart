import 'dart:async';
import 'dart:isolate';
import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
import 'package:axichat/src/email/transport/email_delta_worker_runtime.dart';
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
    registerFallbackValue(MessageTimelineFilter.directOnly);
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
          deltaChatId: chatId,
        ),
      ).thenAnswer((_) async => null);
      when(() => database.updateMessage(any())).thenAnswer((_) async {});
      when(() => database.getMessageByStanzaID(any())).thenAnswer((
        invocation,
      ) async {
        final stanzaId = invocation.positionalArguments.first as String;
        return stanzaId == pendingMessage?.stanzaID ? pendingMessage : null;
      });
      when(() => context.getChat(chatId)).thenAnswer(
        (_) async => const DeltaChat(
          id: chatId,
          name: 'Alice',
          contactAddress: 'alice@example.com',
        ),
      );
      when(() => context.getQuotedMessage(any())).thenAnswer((_) async => null);
      when(
        () => database.isEmailAddressBlocked(any()),
      ).thenAnswer((_) async => false);
      when(
        () => database.isEmailAddressSpam(any()),
      ).thenAnswer((_) async => false);
      when(
        () => database.getEmailBlocklistEntry(any()),
      ).thenAnswer((_) async => null);
      when(
        () => database.upsertEmailChatAccount(
          chatJid: any(named: 'chatJid'),
          deltaAccountId: any(named: 'deltaAccountId'),
          deltaChatId: any(named: 'deltaChatId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.ensureEmailEncryptionStatusMarkerForChat(any()),
      ).thenAnswer((_) async {});
      when(
        () => database.getChat('alice@example.com'),
      ).thenAnswer((_) async => chat);
      when(
        () => database.getChatMessages(
          any(),
          start: any(named: 'start'),
          end: any(named: 'end'),
          filter: any(named: 'filter'),
        ),
      ).thenAnswer((_) async => const <Message>[]);
      when(
        () => database.repairChatSummaryPreservingTimestamp(any()),
      ).thenAnswer((_) async {});
      when(
        () => database.repairUnreadCountForChat(
          any(),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => database.getMessagesByOriginID(
          any(),
          chatJid: any(named: 'chatJid'),
        ),
      ).thenAnswer((_) async => const <Message>[]);
      when(() => database.getFileMetadata(any())).thenAnswer((_) async => null);
      when(
        () => context.getMessageRfc822Body(any()),
      ).thenAnswer((_) async => null);
      when(
        () => context.getMessageIdsByRfc724Mid(any()),
      ).thenAnswer((_) async => const <int>[]);

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      expect(await transport.isConfigured(), isTrue);

      await transport.sendText(chatId: chatId, body: 'hello');

      final savedRow = pendingMessage;
      expect(savedRow, isNotNull);
      expect(savedRow!.timestamp, staleDeltaTimestamp);
      expect(savedRow.deltaMsgId, msgId);
      expect(savedRow.deltaChatId, chatId);
      expect(savedRow.deltaAccountId, DeltaAccountDefaults.legacyId);
      expect(savedRow.originID, 'origin@example.com');
      verifyNever(() => database.updateMessage(any()));
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

  test(
    'account events without account id are forwarded with source account',
    () async {
      const accountId = 1;
      final accounts = MockDeltaAccountsHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      final delivered = Completer<DeltaCoreEvent>();
      transport = EmailDeltaTransport(
        databaseBuilder: () async => database,
        deltaSafe: deltaSafe,
        persistEvents: false,
      );
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

      transport.addEventListener((event) {
        if (!delivered.isCompleted) {
          delivered.complete(event);
        }
      });
      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.start();
      addTearDown(transport.stop);

      events.add(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: 10,
          data2: 42,
        ),
      );

      final event = await delivered.future.timeout(const Duration(seconds: 1));
      expect(event.accountId, accountId);
    },
  );

  test(
    'account events without account id are skipped with multiple sessions',
    () async {
      const primaryAccountId = 1;
      const secondAccountId = 2;
      final accounts = MockDeltaAccountsHandle();
      final secondContext = MockDeltaContextHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      final delivered = Completer<DeltaCoreEvent>();
      transport = EmailDeltaTransport(
        databaseBuilder: () async => database,
        deltaSafe: deltaSafe,
        persistEvents: false,
      );
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
      when(() => accounts.stopIo()).thenAnswer((_) async {});
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'one@example.com' : null;
      });
      when(
        () => context.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => secondContext.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => secondContext.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'two@example.com' : null;
      });
      when(
        () => secondContext.setConfig(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => database.replaceDeltaPlaceholderSelfJids(
          deltaAccountId: any(named: 'deltaAccountId'),
          resolvedAddress: any(named: 'resolvedAddress'),
          placeholderJids: any(named: 'placeholderJids'),
          selfJid: any(named: 'selfJid'),
          emailSelfJid: any(named: 'emailSelfJid'),
        ),
      ).thenAnswer((_) async {});

      transport.addEventListener((event) {
        if (!delivered.isCompleted) {
          delivered.complete(event);
        }
      });
      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.ensureAccountSession(secondAccountId);
      transport.setPrimaryAccountId(primaryAccountId);
      await transport.start();
      addTearDown(transport.stop);

      events.add(
        DeltaCoreEvent(
          type: DeltaEventType.incomingMsg.code,
          data1: 10,
          data2: 42,
        ),
      );
      await pumpEventQueue();

      expect(delivered.isCompleted, isFalse);
    },
  );

  test(
    'explicit legacy account requests do not route to primary in accounts mode',
    () async {
      const primaryAccountId = 1;
      const secondAccountId = 2;
      const msgId = 42;
      final accounts = MockDeltaAccountsHandle();
      final secondContext = MockDeltaContextHandle();
      final events = StreamController<DeltaCoreEvent>.broadcast();
      transport = EmailDeltaTransport(
        databaseBuilder: () async => database,
        deltaSafe: deltaSafe,
        persistEvents: false,
      );
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
      when(
        () => context.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => context.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'one@example.com' : null;
      });
      when(
        () => secondContext.open(passphrase: any(named: 'passphrase')),
      ).thenAnswer((_) async {});
      when(() => secondContext.getConfig(any())).thenAnswer((invocation) async {
        final key = invocation.positionalArguments.first as String;
        return key == 'addr' ? 'two@example.com' : null;
      });

      await transport.ensureInitialized(
        databasePrefix: 'email_delta_transport_test',
        databasePassphrase: 'test-passphrase',
      );
      await transport.ensureAccountSession(secondAccountId);
      transport.setPrimaryAccountId(primaryAccountId);

      final message = await transport.getMessage(
        msgId,
        accountId: DeltaAccountDefaults.legacyId,
      );

      expect(message, isNull);
      verifyNever(() => context.getMessage(msgId));
      verifyNever(() => secondContext.getMessage(msgId));
    },
  );

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

    await transport.ensureInitialized(
      databasePrefix: 'email_delta_transport_test',
      databasePassphrase: 'test-passphrase',
    );
    await transport.start();
    await transport.stop();

    await transport.dispose();

    verify(() => accounts.stopIo()).called(1);
  });

  test('worker runtime accepts cached account state before start', () async {
    final runtime = EmailDeltaWorkerRuntime();
    Object? uncaughtError;

    await runZonedGuarded(
      () async {
        runtime.hydrateAccountAddress(address: 'me@example.com', accountId: 7);
        runtime.setPrimaryAccountId(7);
        await pumpEventQueue();
      },
      (error, _) {
        uncaughtError = error;
      },
    );

    expect(uncaughtError, isNull);
    expect(runtime.activeAccountId, 7);
    expect(runtime.selfJidForAccount(7), 'me@example.com');

    await runtime.dispose();
  });

  test('worker runtime preserves typed errors across RPC', () async {
    ReceivePort? workerReceivePort;
    final runtime = EmailDeltaWorkerRuntime(
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            var initialized = false;
            final receivePort = ReceivePort('fake-email-delta-worker-errors');
            workerReceivePort = receivePort;
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              void respond(Object? result) {
                mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
              }

              void fail(String type, String message) {
                mainPort.send({
                  'jsonrpc': '2.0',
                  'id': id,
                  'error': {'code': -32000, 'type': type, 'message': message},
                });
              }

              switch (op) {
                case 'runtimeState':
                  respond({
                    'accountsSupported': true,
                    'accountsActive': initialized,
                    'activeAccountId': initialized ? 7 : 0,
                    'isIoRunning': false,
                    'selfJids': initialized ? {'7': 'me@example.com'} : {},
                  });
                  return;
                case 'ensureInitialized':
                  initialized = true;
                  respond(null);
                  return;
                case 'configureAccount':
                  fail('DeltaOperationException', 'IMAP login failed');
                  return;
                case 'runImex':
                  fail(
                    'EmailDeltaImexTimeoutException',
                    'Delta import/export timed out.',
                  );
                  return;
                case 'dispose':
                  respond(null);
                  receivePort.close();
                  return;
                default:
                  respond(null);
                  return;
              }
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(() async {
      await runtime.dispose();
      workerReceivePort?.close();
    });

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_error_test',
      databasePassphrase: 'passphrase',
    );

    await expectLater(
      runtime.configureAccount(
        address: 'me@example.com',
        password: 'wrong',
        displayName: 'Me',
      ),
      throwsA(
        isA<DeltaOperationException>().having(
          (error) => error.message,
          'message',
          'IMAP login failed',
        ),
      ),
    );
    await expectLater(
      runtime.runImex(
        mode: 1,
        path: '/tmp/export',
        timeout: const Duration(milliseconds: 10),
      ),
      throwsA(isA<EmailDeltaImexTimeoutException>()),
    );
  });

  test('worker runtime reinitializes after preserved restart', () async {
    final operations = <String>[];
    final runtime = EmailDeltaWorkerRuntime(
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            var initialized = false;
            final receivePort = ReceivePort('fake-email-delta-worker');
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              operations.add(op);
              void respond(Object? result) {
                mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
              }

              switch (op) {
                case 'runtimeState':
                  respond({
                    'accountsSupported': true,
                    'accountsActive': initialized,
                    'activeAccountId': initialized ? 7 : 0,
                    'isIoRunning': false,
                    'selfJids': initialized ? {'7': 'me@example.com'} : {},
                  });
                  return;
                case 'ensureInitialized':
                  initialized = true;
                  respond(null);
                  return;
                case 'accountIds':
                  if (!initialized) {
                    mainPort.send({
                      'jsonrpc': '2.0',
                      'id': id,
                      'error': {'code': -32000, 'message': 'not initialized'},
                    });
                    return;
                  }
                  respond({
                    'accountIds': <int>[7],
                    'state': {
                      'accountsSupported': true,
                      'accountsActive': true,
                      'activeAccountId': 7,
                      'isIoRunning': false,
                      'selfJids': {'7': 'me@example.com'},
                    },
                  });
                  return;
                case 'dispose':
                  respond(null);
                  receivePort.close();
                  return;
                default:
                  respond(null);
                  return;
              }
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(runtime.dispose);

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_restart_test',
      databasePassphrase: 'passphrase',
    );
    await runtime.debugStopWorkerPreservingInitializationForTest();

    expect(await runtime.accountIds(), isNotEmpty);
    expect(operations, [
      'ensureInitialized',
      'runtimeState',
      'dispose',
      'ensureInitialized',
      'accountIds',
    ]);
  });

  test('worker runtime joins concurrent initialization requests', () async {
    final operations = <String>[];
    final runtime = EmailDeltaWorkerRuntime(
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            var initialized = false;
            final receivePort = ReceivePort('fake-email-delta-worker-join');
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              operations.add(op);
              void respond(Object? result) {
                mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
              }

              switch (op) {
                case 'runtimeState':
                  respond({
                    'accountsSupported': true,
                    'accountsActive': initialized,
                    'activeAccountId': initialized ? 7 : 0,
                    'isIoRunning': false,
                    'selfJids': initialized ? {'7': 'me@example.com'} : {},
                  });
                  return;
                case 'ensureInitialized':
                  initialized = true;
                  respond(null);
                  return;
                case 'accountIds':
                  respond({
                    'accountIds': <int>[7],
                    'state': {
                      'accountsSupported': true,
                      'accountsActive': true,
                      'activeAccountId': 7,
                      'isIoRunning': false,
                      'selfJids': {'7': 'me@example.com'},
                    },
                  });
                  return;
                case 'getCoreConfig':
                  respond('value');
                  return;
                case 'dispose':
                  respond(null);
                  receivePort.close();
                  return;
                default:
                  respond(null);
                  return;
              }
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(runtime.dispose);

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_join_test',
      databasePassphrase: 'passphrase',
    );
    await runtime.debugStopWorkerPreservingInitializationForTest();
    operations.clear();

    await Future.wait<Object?>([
      runtime.accountIds(),
      runtime.getCoreConfig('configured_addr'),
    ]);

    expect(
      operations.where((operation) => operation == 'ensureInitialized'),
      hasLength(1),
    );
    expect(operations, contains('accountIds'));
    expect(operations, contains('getCoreConfig'));
  });

  test(
    'worker survives an RPC timeout when the health probe succeeds',
    () async {
      final operations = <String>[];
      final workerReceivePorts = <ReceivePort>[];
      final runtime = EmailDeltaWorkerRuntime(
        debugBackgroundFetchRpcGracePeriod: const Duration(milliseconds: 20),
        debugWorkerStarter:
            ({
              required mainPort,
              required deltaDatabasePath,
              required databasePrefix,
              required databasePassphrase,
              required emailEncryptionBetaEnabledByAddress,
              required xmppSelfJid,
            }) async {
              var initialized = false;
              final receivePort = ReceivePort(
                'fake-email-delta-worker-timeout',
              );
              workerReceivePorts.add(receivePort);
              receivePort.listen((message) {
                final request = (message as Map).cast<Object?, Object?>();
                final id = request['id'] as int;
                final method = request['method'] as String;
                final op = method.substring('axichat.email.'.length);
                operations.add(op);
                void respond(Object? result) {
                  mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
                }

                switch (op) {
                  case 'runtimeState':
                    respond({
                      'accountsSupported': true,
                      'accountsActive': initialized,
                      'activeAccountId': initialized ? 7 : 0,
                      'isIoRunning': false,
                      'selfJids': initialized ? {'7': 'me@example.com'} : {},
                    });
                    return;
                  case 'ensureInitialized':
                    initialized = true;
                    respond(null);
                    return;
                  case 'performBackgroundFetch':
                    return;
                  case 'accountIds':
                    respond({
                      'accountIds': <int>[7],
                      'state': {
                        'accountsSupported': true,
                        'accountsActive': true,
                        'activeAccountId': 7,
                        'isIoRunning': false,
                        'selfJids': {'7': 'me@example.com'},
                      },
                    });
                    return;
                  case 'dispose':
                    respond(null);
                    receivePort.close();
                    return;
                  default:
                    respond(null);
                    return;
                }
              });
              return receivePort.sendPort;
            },
      );
      addTearDown(() async {
        await runtime.dispose(requestWorkerDispose: false);
        for (final receivePort in workerReceivePorts) {
          receivePort.close();
        }
      });

      await runtime.ensureInitialized(
        databasePrefix: 'worker_runtime_timeout_test',
        databasePassphrase: 'passphrase',
      );

      Object? uncaughtError;
      await runZonedGuarded(
        () async {
          await expectLater(
            runtime.performBackgroundFetch(const Duration(milliseconds: 20)),
            throwsA(
              isA<EmailDeltaWorkerRuntimeException>().having(
                (error) => error.message,
                'message',
                'Delta worker performBackgroundFetch timed out.',
              ),
            ),
          );
        },
        (error, _) {
          uncaughtError = error;
        },
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));
      operations.clear();
      expect(uncaughtError, isNull);
      expect(await runtime.accountIds(), [7]);
      expect(operations, ['accountIds']);
      expect(workerReceivePorts, hasLength(1));
    },
  );

  test('worker delivers events again after dispose and restart', () async {
    final mainPorts = <SendPort>[];
    final workerReceivePorts = <ReceivePort>[];
    final runtime = EmailDeltaWorkerRuntime(
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            mainPorts.add(mainPort);
            final receivePort = ReceivePort('fake-email-delta-worker-events');
            workerReceivePorts.add(receivePort);
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              if (op == 'runtimeState') {
                mainPort.send({
                  'jsonrpc': '2.0',
                  'id': id,
                  'result': {
                    'accountsSupported': true,
                    'accountsActive': true,
                    'activeAccountId': 7,
                    'isIoRunning': false,
                    'selfJids': {'7': 'me@example.com'},
                  },
                });
                return;
              }
              mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': null});
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(() async {
      await runtime.dispose(requestWorkerDispose: false);
      for (final receivePort in workerReceivePorts) {
        receivePort.close();
      }
    });

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_event_revival_test',
      databasePassphrase: 'passphrase',
    );
    await runtime.dispose(requestWorkerDispose: false);

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_event_revival_test',
      databasePassphrase: 'passphrase',
    );
    final received = <DeltaCoreEvent>[];
    final subscription = runtime.events.listen(received.add);
    addTearDown(subscription.cancel);
    mainPorts.last.send({
      'jsonrpc': '2.0',
      'method': 'axichat.email.event',
      'params': {'event': DeltaCoreEvent(type: 2005, data1: 7, data2: 70)},
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(received, hasLength(1));
    expect(received.single.data2, 70);
  });

  test('worker restarts when the health probe also times out', () async {
    final operations = <String>[];
    final workerReceivePorts = <ReceivePort>[];
    final runtime = EmailDeltaWorkerRuntime(
      debugBackgroundFetchRpcGracePeriod: const Duration(milliseconds: 20),
      debugWorkerHealthProbeTimeout: const Duration(milliseconds: 20),
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            var initialized = false;
            var sawBackgroundFetch = false;
            final receivePort = ReceivePort('fake-email-delta-worker-hung');
            final workerIndex = workerReceivePorts.length;
            workerReceivePorts.add(receivePort);
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              operations.add(op);
              void respond(Object? result) {
                mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
              }

              if (workerIndex == 0 && op == 'performBackgroundFetch') {
                sawBackgroundFetch = true;
                return;
              }
              if (workerIndex == 0 && sawBackgroundFetch && op != 'dispose') {
                return;
              }
              switch (op) {
                case 'runtimeState':
                  respond({
                    'accountsSupported': true,
                    'accountsActive': initialized,
                    'activeAccountId': initialized ? 7 : 0,
                    'isIoRunning': false,
                    'selfJids': initialized ? {'7': 'me@example.com'} : {},
                  });
                  return;
                case 'ensureInitialized':
                  initialized = true;
                  respond(null);
                  return;
                case 'accountIds':
                  respond({
                    'accountIds': <int>[7],
                    'state': {
                      'accountsSupported': true,
                      'accountsActive': true,
                      'activeAccountId': 7,
                      'isIoRunning': false,
                      'selfJids': {'7': 'me@example.com'},
                    },
                  });
                  return;
                case 'dispose':
                  respond(null);
                  receivePort.close();
                  return;
                default:
                  respond(null);
                  return;
              }
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(() async {
      await runtime.dispose(requestWorkerDispose: false);
      for (final receivePort in workerReceivePorts) {
        receivePort.close();
      }
    });

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_probe_restart_test',
      databasePassphrase: 'passphrase',
    );

    await expectLater(
      runtime.performBackgroundFetch(const Duration(milliseconds: 20)),
      throwsA(isA<EmailDeltaWorkerRuntimeException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(await runtime.accountIds(), [7]);
    expect(workerReceivePorts, hasLength(2));
  });

  test('worker runtime forced dispose skips queued dispose request', () async {
    final operations = <String>[];
    ReceivePort? workerReceivePort;
    final runtime = EmailDeltaWorkerRuntime(
      debugWorkerStarter:
          ({
            required mainPort,
            required deltaDatabasePath,
            required databasePrefix,
            required databasePassphrase,
            required emailEncryptionBetaEnabledByAddress,
            required xmppSelfJid,
          }) async {
            var initialized = false;
            final receivePort = ReceivePort('fake-email-delta-worker-dispose');
            workerReceivePort = receivePort;
            receivePort.listen((message) {
              final request = (message as Map).cast<Object?, Object?>();
              final id = request['id'] as int;
              final method = request['method'] as String;
              final op = method.substring('axichat.email.'.length);
              operations.add(op);
              void respond(Object? result) {
                mainPort.send({'jsonrpc': '2.0', 'id': id, 'result': result});
              }

              switch (op) {
                case 'runtimeState':
                  respond({
                    'accountsSupported': true,
                    'accountsActive': initialized,
                    'activeAccountId': initialized ? 7 : 0,
                    'isIoRunning': false,
                    'selfJids': initialized ? {'7': 'me@example.com'} : {},
                  });
                  return;
                case 'ensureInitialized':
                  initialized = true;
                  respond(null);
                  return;
                case 'dispose':
                  return;
                default:
                  respond(null);
                  return;
              }
            });
            return receivePort.sendPort;
          },
    );
    addTearDown(() async {
      workerReceivePort?.close();
      workerReceivePort = null;
      await runtime.dispose(requestWorkerDispose: false);
    });

    await runtime.ensureInitialized(
      databasePrefix: 'worker_runtime_forced_dispose_test',
      databasePassphrase: 'passphrase',
    );
    await runtime.dispose(requestWorkerDispose: false);
    workerReceivePort?.close();
    workerReceivePort = null;

    expect(operations, isNot(contains('dispose')));
  });
}
