import 'dart:async';
import 'dart:io';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/email/sync/delta_event_consumer.dart';
import 'package:axichat/src/email/transport/email_delta_transport.dart';
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
      when(
        () => context.getConfig('addr'),
      ).thenAnswer((_) async => 'me@example.com');
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
}
