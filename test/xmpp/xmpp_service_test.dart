import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/foreground_socket.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../mocks.dart';

class MockPresenceManager extends Mock implements XmppPresenceManager {}

class MockUserAvatarManager extends Mock implements mox.UserAvatarManager {}

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.supportPath);

  final String supportPath;

  @override
  Future<String?> getApplicationSupportPath() async => supportPath;
}

class _FakeForegroundBridge implements ForegroundTaskBridge {
  final Set<String> acquiredClients = <String>{};
  final Map<String, ForegroundTaskMessageHandler> _listeners =
      <String, ForegroundTaskMessageHandler>{};

  @override
  Future<void> acquire({
    required String clientId,
    ForegroundServiceConfig? config,
  }) async {
    acquiredClients.add(clientId);
  }

  @override
  Future<void> release(String clientId) async {
    acquiredClients.remove(clientId);
  }

  @override
  Future<void> send(List<Object> parts) async {}

  @override
  void registerListener(String clientId, ForegroundTaskMessageHandler handler) {
    _listeners[clientId] = handler;
  }

  @override
  void unregisterListener(String clientId) {
    _listeners.remove(clientId);
  }
}

class RecordingMamManager extends mox.MAMManager {
  int queryCount = 0;
  mox.JID? lastTo;
  mox.MAMQueryOptions? lastOptions;
  mox.ResultSetManagement? lastRsm;
  Duration? lastTimeout;

  @override
  Future<mox.MAMQueryResult?> queryArchive({
    mox.JID? to,
    mox.MAMQueryOptions? options,
    mox.ResultSetManagement? rsm,
    Duration? timeout,
  }) async {
    queryCount += 1;
    lastTo = to;
    lastOptions = options;
    lastRsm = rsm;
    lastTimeout = timeout;
    return const mox.MAMQueryResult(
      messages: <mox.MAMMessage>[],
      complete: true,
    );
  }
}

class RecordingAvatarPubSubManager extends SafePubSubManager {
  int publishCount = 0;
  final Map<String, mox.XMLNode> _publishedItems = <String, mox.XMLNode>{};

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async => const moxlib.Result(true);

  @override
  Future<String?> createNode(mox.JID jid, {String? nodeId}) async =>
      nodeId ?? 'created-node';

  @override
  Future<String?> createNodeWithConfig(
    mox.JID jid,
    mox.NodeConfig config, {
    String? nodeId,
  }) async => nodeId ?? 'created-node';

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    publishCount += 1;
    final itemId = id ?? 'item-$publishCount';
    _publishedItems[_publishedKey(node, itemId)] = payload;
    return const moxlib.Result(true);
  }

  @override
  Future<moxlib.Result<mox.PubSubError, mox.PubSubItem>> getItem(
    mox.JID jid,
    String node,
    String id, {
    String? subId,
  }) async {
    final payload = _publishedItems[_publishedKey(node, id)];
    if (payload == null) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    return moxlib.Result(mox.PubSubItem(id: id, node: node, payload: payload));
  }

  @override
  Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
    mox.JID jid,
    String node, {
    int? maxItems,
    String? subId,
  }) async {
    final items = _publishedItems.entries
        .where((entry) => entry.key.startsWith('$node|'))
        .map(
          (entry) => mox.PubSubItem(
            id: entry.key.split('|').last,
            node: node,
            payload: entry.value,
          ),
        )
        .toList(growable: false);
    if (items.isEmpty) {
      return moxlib.Result(mox.ItemNotFoundError());
    }
    if (maxItems == null || items.length <= maxItems) {
      return moxlib.Result(items);
    }
    return moxlib.Result(items.take(maxItems).toList(growable: false));
  }

  String _publishedKey(String node, String id) => '$node|$id';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeStanzaDetails());
    registerFallbackValue(MessageNotificationChannel.chat);
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();

    prepareMockConnection();

    when(
      () => mockConnection.asBroadcastStream(),
    ).thenAnswer((_) => eventStreamController.stream);
  });

  tearDown(() async {
    await eventStreamController.close();
    await database.close();
    resetMocktailState();
  });

  group('XmppService event handler', () {
    late mox.MessageEvent messageEvent;
    late Message message;

    setUp(() async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);

      when(
        () => mockNotificationService.sendNotification(
          title: any(named: 'title'),
          body: any(named: 'body'),
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
        ),
      ).thenAnswer((_) async {});

      messageEvent = generateRandomMessageEvent();
      message = Message.fromMox(messageEvent);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    tearDown(() {
      resetMocktailState();
    });

    test('When stream negotiations complete, requests the roster.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);

      verifyNever(() => mockConnection.requestRoster());

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

      await pumpEventQueue();

      verify(() => mockConnection.requestRoster()).called(1);
    });

    test(
      'When stream negotiations resume, does not request the roster.',
      () async {
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);

        verifyNever(() => mockConnection.requestRoster());

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

        await pumpEventQueue();

        verifyNever(() => mockConnection.requestRoster());
      },
    );

    test(
      'When stream negotiations complete, requests the blocklist.',
      () async {
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);

        verifyNever(() => mockConnection.requestBlocklist());

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue();

        verify(() => mockConnection.requestBlocklist()).called(1);
      },
    );

    test('When stream negotiations resume, requests the blocklist.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);

      verifyNever(() => mockConnection.requestBlocklist());

      eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

      await pumpEventQueue();

      verify(() => mockConnection.requestBlocklist()).called(1);
    });

    test(
      'When stream negotiations complete, sends initial presence.',
      () async {
        final presenceManager = MockPresenceManager();
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);
        when(
          () => presenceManager.sendInitialPresence(),
        ).thenAnswer((_) async {});

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue();

        verify(() => presenceManager.sendInitialPresence()).called(1);
      },
    );

    test(
      'When stream negotiations resume, does not send initial presence.',
      () async {
        final presenceManager = MockPresenceManager();
        when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
        when(
          () => mockConnection.requestRoster(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.requestBlocklist(),
        ).thenAnswer((_) async => null);
        when(
          () => mockConnection.getManager<XmppPresenceManager>(),
        ).thenReturn(presenceManager);
        when(
          () => presenceManager.sendInitialPresence(),
        ).thenAnswer((_) async {});

        eventStreamController.add(mox.StreamNegotiationsDoneEvent(true));

        await pumpEventQueue();

        verifyNever(() => presenceManager.sendInitialPresence());
      },
    );

    test('When a resource is bound, stores the bound resource.', () async {
      when(() => mockConnection.carbonsEnabled).thenAnswer((_) => true);
      when(() => mockConnection.requestRoster()).thenAnswer((_) async => null);
      when(
        () => mockConnection.requestBlocklist(),
      ).thenAnswer((_) async => null);

      eventStreamController.add(mox.ResourceBoundEvent('axi-res'));

      await pumpEventQueue();

      verify(
        () => mockStateStore.write(
          key: xmppService.resourceStorageKey,
          value: 'axi-res',
        ),
      ).called(1);
    });

    test(
      'Caches a signup self avatar draft after stream ready and publishes it immediately.',
      () async {
        final originalPathProvider = PathProviderPlatform.instance;
        final tempDir = await Directory.systemTemp.createTemp(
          'axichat-avatar-',
        );
        final supportDir = Directory(p.join(tempDir.path, 'support'));
        await supportDir.create(recursive: true);
        PathProviderPlatform.instance = _FakePathProviderPlatform(
          supportDir.path,
        );
        final stateStoreValues = <String, Object?>{};
        final pubsubManager = RecordingAvatarPubSubManager();
        final userAvatarManager = MockUserAvatarManager();
        try {
          when(() => mockStateStore.read(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            return stateStoreValues[key.value];
          });
          when(
            () => mockStateStore.write(
              key: any(named: 'key'),
              value: any(named: 'value'),
            ),
          ).thenAnswer((invocation) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues[key.value] = invocation.namedArguments[#value];
            return true;
          });
          when(() => mockStateStore.delete(key: any(named: 'key'))).thenAnswer((
            invocation,
          ) async {
            final key = invocation.namedArguments[#key] as RegisteredStateKey;
            stateStoreValues.remove(key.value);
            return true;
          });

          when(
            () => mockConnection.getManager<SafePubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.PubSubManager>(),
          ).thenReturn(pubsubManager);
          when(
            () => mockConnection.getManager<mox.UserAvatarManager>(),
          ).thenReturn(userAvatarManager);
          when(
            () => mockConnection.getManager<mox.VCardManager>(),
          ).thenReturn(null);
          when(() => mockConnection.hasConnectionSettings).thenReturn(true);

          eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));
          await pumpEventQueue();

          expect(pubsubManager.publishCount, equals(0));

          await xmppService.cacheSelfAvatarDraft(
            AvatarUploadPayload(
              bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
              mimeType: 'image/png',
              width: 1,
              height: 1,
              hash: 'signup-avatar-hash',
            ),
          );

          await pumpEventQueue();

          expect(pubsubManager.publishCount, equals(2));
          expect(
            stateStoreValues[xmppService.selfAvatarPendingPublishKey.value],
            isNull,
          );
          expect(
            (await xmppService.getOwnAvatar())?.hash,
            'signup-avatar-hash',
          );
        } finally {
          PathProviderPlatform.instance = originalPathProvider;
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('Given a standard text message, writes it to the database.', () async {
      final beforeMessage = await database.getMessageByStanzaID(
        messageEvent.id!,
      );
      expect(beforeMessage, isNull);

      eventStreamController.add(messageEvent);

      await pumpEventQueue();

      final afterMessage = await database.getMessageByStanzaID(
        messageEvent.id!,
      );
      expect(afterMessage?.stanzaID, equals(messageEvent.id!));
      expect(afterMessage?.body, equals(messageEvent.text));
    });

    test(
      'Given a standard text message from the bare account domain, writes it to the database.',
      () async {
        const stanzaId = 'server-domain-message';
        const body = 'Welcome to the server';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('axi.im'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
        );

        final beforeMessage = await database.getMessageByStanzaID(stanzaId);
        expect(beforeMessage, isNull);

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final afterMessage = await database.getMessageByStanzaID(stanzaId);
        final chat = await database.getChat('axi.im');
        expect(afterMessage?.stanzaID, equals(stanzaId));
        expect(afterMessage?.body, equals(body));
        expect(afterMessage?.chatJid, equals('axi.im'));
        expect(afterMessage?.senderJid, equals('axi.im'));
        expect(chat?.title, equals('axi.im'));
      },
    );

    test(
      'Given a headline message from the bare account domain, writes it to the database.',
      () async {
        const stanzaId = 'server-domain-headline';
        const body = 'Account created';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('axi.im'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
          type: 'headline',
        );

        final beforeMessage = await database.getMessageByStanzaID(stanzaId);
        expect(beforeMessage, isNull);

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final afterMessage = await database.getMessageByStanzaID(stanzaId);
        final chat = await database.getChat('axi.im');
        expect(afterMessage?.stanzaID, equals(stanzaId));
        expect(afterMessage?.body, equals(body));
        expect(afterMessage?.chatJid, equals('axi.im'));
        expect(afterMessage?.senderJid, equals('axi.im'));
        expect(chat?.title, equals('axi.im'));
      },
    );

    test(
      'Given archived duplicate welcome messages from the bare account domain, trims and stores only one.',
      () async {
        const trimmedBody = 'Welcome to Axichat';
        final timestamp = DateTime.utc(2026, 3, 1, 12, 0, 0);

        mox.MessageEvent buildWelcomeEvent(String stanzaId, String body) {
          return mox.MessageEvent(
            mox.JID.fromString('axi.im'),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageBodyData(body),
              mox.MessageIdData(stanzaId),
              mox.DelayedDeliveryData(mox.JID.fromString('axi.im'), timestamp),
            ]),
            id: stanzaId,
            isFromMAM: true,
          );
        }

        eventStreamController.add(
          buildWelcomeEvent('welcome-message-1', '  $trimmedBody \n'),
        );
        eventStreamController.add(
          buildWelcomeEvent('welcome-message-2', '\t$trimmedBody  '),
        );

        await pumpEventQueue(times: 20);

        final messages = await database.getChatMessages(
          'axi.im',
          start: 0,
          end: 10,
        );
        expect(messages, hasLength(1));
        expect(messages.single.body, equals(trimmedBody));
      },
    );

    test(
      'Given a message from a non-server bare domain, does not label the chat with that domain.',
      () async {
        const stanzaId = 'other-domain-message';
        const body = 'External bare-domain message';
        final systemMessageEvent = mox.MessageEvent(
          mox.JID.fromString('example.com'),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            const mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
        );

        eventStreamController.add(systemMessageEvent);

        await pumpEventQueue();

        final chat = await database.getChat('example.com');
        expect(chat?.title, isEmpty);
      },
    );

    test('Given a standard text message, notifies the user.', () async {
      eventStreamController.add(messageEvent);

      await pumpEventQueue();

      verify(
        () => mockNotificationService.sendMessageNotification(
          title: any(named: 'title'),
          body: messageEvent.text,
          extraConditions: any(named: 'extraConditions'),
          allowForeground: any(named: 'allowForeground'),
          payload: any(named: 'payload'),
          threadKey: any(named: 'threadKey'),
          showPreviewOverride: any(named: 'showPreviewOverride'),
          channel: MessageNotificationChannel.chat,
        ),
      ).called(1);
    });

    test(
      'Given a connection change, emits the corresponding connection state.',
      () async {
        expectLater(
          xmppService.connectivityStream,
          emitsInOrder([
            ConnectionState.connecting,
            ConnectionState.connected,
            ConnectionState.error,
            ConnectionState.notConnected,
            ConnectionState.error,
            ConnectionState.connected,
            ConnectionState.connecting,
          ]),
        );

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.error,
            mox.XmppConnectionState.connected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.notConnected,
            mox.XmppConnectionState.error,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.error,
            mox.XmppConnectionState.notConnected,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.error,
          ),
        );
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connecting,
            mox.XmppConnectionState.connected,
          ),
        );
      },
    );

    test(
      'Given a stanza acknowledgement, marks the correct message in the database acked.',
      () async {
        await database.saveMessage(message);

        final beforeAcked = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(beforeAcked?.acked, isFalse);

        eventStreamController.add(
          mox.StanzaAckedEvent(
            mox.Stanza(tag: 'message', id: message.stanzaID),
          ),
        );

        await pumpEventQueue();

        final afterAcked = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(afterAcked?.acked, isTrue);
      },
    );

    test(
      'Given a displayed chat marker, marks the correct message in the database displayed.',
      () async {
        await database.saveMessage(message);

        final beforeDisplayed = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(beforeDisplayed?.acked, isFalse);

        eventStreamController.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(message.senderJid),
            mox.ChatMarker.displayed,
            message.stanzaID,
          ),
        );

        await pumpEventQueue();

        final afterDisplayed = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(afterDisplayed?.displayed, isTrue);
        expect(afterDisplayed?.received, isTrue);
        expect(afterDisplayed?.acked, isTrue);
      },
    );

    test(
      'Given a delivery receipt, marks the correct message in the database received.',
      () async {
        await database.saveMessage(message);

        final beforeReceived = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(beforeReceived?.received, isFalse);

        eventStreamController.add(
          mox.DeliveryReceiptReceivedEvent(
            from: mox.JID.fromString(message.senderJid),
            id: message.stanzaID,
          ),
        );

        await pumpEventQueue();

        final afterReceived = await database.getMessageByStanzaID(
          message.stanzaID,
        );
        expect(afterReceived?.received, isTrue);
      },
    );

    test(
      'When stream negotiations complete on a fresh login, runs a MAM catch-up.',
      () async {
        final mamManager = RecordingMamManager();
        await xmppService.setMamSupportOverride(true);
        when(() => mockConnection.carbonsEnabled).thenReturn(false);
        when(
          () => mockConnection.enableCarbons(),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.getManager<mox.MAMManager>(),
        ).thenReturn(mamManager);

        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.connecting,
          ),
        );
        eventStreamController.add(mox.StreamNegotiationsDoneEvent(false));

        await pumpEventQueue(times: 20);

        expect(mamManager.queryCount, 1);
        expect(mamManager.lastTo, isNull);
        expect(mamManager.lastOptions?.withJid, isNull);
      },
    );
  });

  group('connect', () {
    bool builtStateStore = false;
    bool builtDatabase = false;

    XmppStateStore buildStateStore(String _, String _) {
      builtStateStore = true;
      return mockStateStore;
    }

    XmppDatabase buildDatabase(String _, String _) {
      builtDatabase = true;
      return database;
    }

    setUp(() {
      builtStateStore = false;
      builtDatabase = false;
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: buildStateStore,
        buildDatabase: buildDatabase,
        notificationService: mockNotificationService,
      );
    });

    tearDown(() async {
      await xmppService.close();
    });

    tearDown(() {
      resetMocktailState();
    });

    test('Given valid credentials, initialises the databases.', () async {
      await connectSuccessfully(xmppService);

      expect(builtStateStore, true);
      expect(builtDatabase, true);
    });

    test('Given valid credentials, registers all feature managers.', () async {
      await connectSuccessfully(xmppService);

      verify(
        () => mockConnection.registerManagers(
          any(
            that: predicate<List<mox.XmppManagerBase>>(
              (items) => items.indexed.every((e) {
                final (index, manager) = e;
                return manager.runtimeType ==
                    xmppService.featureManagers[index].runtimeType;
              }),
            ),
          ),
        ),
      ).called(1);
    });

    test('Uses the Axichat entity capabilities manager wrapper.', () {
      final runtimeTypes = xmppService.featureManagers
          .map((manager) => manager.runtimeType.toString())
          .toList(growable: false);

      expect(runtimeTypes, contains('_AxiEntityCapabilitiesManager'));
      expect(runtimeTypes, isNot(contains('EntityCapabilitiesManager')));
    });

    test(
      'Given invalid credentials, throws an XmppAuthenticationException.',
      () async {
        await expectLater(
          () => connectUnsuccessfully(xmppService),
          throwsA(isA<XmppAuthenticationException>()),
        );

        await pumpEventQueue();

        expect(builtDatabase, false);
      },
    );

    test(
      'Attempting to connect when already connected throws an XmppAlreadyConnectedException.',
      () async {
        await connectSuccessfully(xmppService);
        eventStreamController.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();

        await expectLater(
          () => xmppService.connect(
            jid: jid,
            password: password,
            databasePrefix: '',
            databasePassphrase: '',
          ),
          throwsA(isA<XmppAlreadyConnectedException>()),
        );
      },
    );
  });

  group('burn', () {
    setUp(() async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );
      await connectSuccessfully(xmppService);
    });

    tearDown(() async {
      await xmppService.close();
      await pumpEventQueue();
    });

    tearDown(() {
      resetMocktailState();
    });

    test('Burn removes the avatar cache directory.', () async {
      final originalPathProvider = PathProviderPlatform.instance;
      final tempDir = await Directory.systemTemp.createTemp('axichat-burn-');
      final supportDir = Directory(p.join(tempDir.path, 'support'));
      await supportDir.create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        supportDir.path,
      );
      final avatarDirectory = Directory(p.join(supportDir.path, 'avatars'));

      try {
        when(
          () => mockStateStore.deleteAll(burn: true),
        ).thenAnswer((_) async => true);

        await xmppService.cacheSelfAvatarDraft(
          AvatarUploadPayload(
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
            mimeType: 'image/png',
            width: 1,
            height: 1,
            hash: 'burn-avatar-hash',
          ),
        );

        expect(await avatarDirectory.exists(), isTrue);

        await xmppService.burn();

        expect(await avatarDirectory.exists(), isFalse);
      } finally {
        PathProviderPlatform.instance = originalPathProvider;
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });

  group('XmppConnection', () {});

  group('XmppSocketWrapper', () {
    late ServerSocket serverSocket;
    late Future<Socket> acceptedSocketFuture;

    setUp(() async {
      serverSocket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      acceptedSocketFuture = serverSocket.first;
    });

    tearDown(() async {
      await serverSocket.close();
    });

    test(
      'closeStreams detaches the active socket before the controllers close',
      () async {
        final wrapper = XmppSocketWrapper();
        Socket? peerSocket;
        Object? uncaughtError;
        StackTrace? uncaughtStackTrace;

        await runZonedGuarded(
          () async {
            final connected = await wrapper.connect(
              'axi.im',
              host: InternetAddress.loopbackIPv4.address,
              port: serverSocket.port,
            );

            expect(connected, isTrue);

            peerSocket = await acceptedSocketFuture;

            await wrapper.closeStreams();

            try {
              peerSocket!.add('<message />'.codeUnits);
              await peerSocket!.flush();
            } on SocketException {
              // The client may already be detached; either outcome is valid.
            }

            peerSocket!.destroy();
            await pumpEventQueue();
          },
          (Object error, StackTrace stackTrace) {
            uncaughtError = error;
            uncaughtStackTrace = stackTrace;
          },
        );

        try {
          await peerSocket?.close();
        } on SocketException {
          // The peer socket may already be destroyed.
        }

        expect(
          uncaughtError,
          isNull,
          reason: '$uncaughtError\n$uncaughtStackTrace',
        );
      },
    );
  });

  test(
    'Failed foreground migration releases the abandoned foreground connection',
    () async {
      final originalBridge = foregroundTaskBridge;
      final bridge = _FakeForegroundBridge();
      final foregroundConnection = MockXmppConnection();
      final fallbackConnection = MockXmppConnection();
      final settings = XmppConnectionSettings(
        jid: mox.JID.fromString(jid),
        password: password,
      );

      foregroundTaskBridge = bridge;
      withForeground = true;
      foregroundServiceActive.value = false;
      addTearDown(() {
        foregroundTaskBridge = originalBridge;
        withForeground = false;
        foregroundServiceActive.value = false;
      });

      void prepareAdditionalConnection(
        MockXmppConnection connection, {
        required XmppSocketWrapper socketWrapper,
      }) {
        when(() => connection.hasConnectionSettings).thenReturn(true);
        when(() => connection.connectionSettings).thenReturn(settings);
        when(() => connection.socketWrapper).thenReturn(socketWrapper);
        when(
          () => connection.registerFeatureNegotiators(any()),
        ).thenAnswer((_) async {});
        when(() => connection.registerManagers(any())).thenAnswer((_) async {});
        when(() => connection.loadStreamState()).thenAnswer((_) async {});
        when(
          () => connection.setShouldReconnect(any()),
        ).thenAnswer((_) async {});
        when(() => connection.setUserAgent(any())).thenAnswer((_) {});
        when(() => connection.setFastToken(any())).thenAnswer((_) {});
        when(
          () => connection.asBroadcastStream(),
        ).thenAnswer((_) => const Stream<mox.XmppEvent>.empty());
        when(
          () => connection.omemoActivityStream,
        ).thenAnswer((_) => const Stream<mox.OmemoActivityEvent>.empty());
        when(() => connection.enableCarbons()).thenAnswer((_) async => true);
        when(() => connection.requestRoster()).thenAnswer(
          (_) =>
              Future<
                moxlib.Result<mox.RosterRequestResult, mox.RosterError>?
              >.value(null),
        );
        when(
          () => connection.requestBlocklist(),
        ).thenAnswer((_) => Future<List<String>?>.value(null));
        when(() => connection.discoInfoQuery(any())).thenAnswer((_) async {
          final discoInfo = mox.DiscoInfo(
            const [mox.mamXmlns],
            const [],
            const [],
            null,
            mox.JID.fromString(jid),
          );
          return moxlib.Result<mox.StanzaError, mox.DiscoInfo>(discoInfo);
        });
        when(() => connection.saltedPassword).thenReturn('');
        when(() => connection.disconnect()).thenAnswer((_) async {});
      }

      prepareMockConnection();
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      when(() => mockConnection.connectionSettings).thenReturn(settings);
      when(
        () => mockConnection.isReconnecting(),
      ).thenAnswer((_) async => false);
      when(() => mockConnection.disconnect()).thenAnswer((_) async {});

      final foregroundSocket = ForegroundSocketWrapper(bridge: bridge);
      prepareAdditionalConnection(
        foregroundConnection,
        socketWrapper: foregroundSocket,
      );
      when(
        () => foregroundConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).thenAnswer((_) async {
        await bridge.acquire(clientId: foregroundClientXmpp);
        return const moxlib.Result<bool, mox.XmppError>(false);
      });
      when(() => foregroundConnection.reset()).thenAnswer((_) async {
        await bridge.release(foregroundClientXmpp);
      });

      prepareAdditionalConnection(
        fallbackConnection,
        socketWrapper: XmppSocketWrapper(),
      );
      when(
        () => fallbackConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).thenAnswer((_) async => const moxlib.Result<bool, mox.XmppError>(true));
      when(() => fallbackConnection.reset()).thenAnswer((_) async {});

      var connectionBuilds = 0;
      xmppService = XmppService(
        buildConnection: () {
          connectionBuilds++;
          if (connectionBuilds == 1) {
            return mockConnection;
          }
          if (connectionBuilds == 2) {
            return foregroundConnection;
          }
          return fallbackConnection;
        },
        buildStateStore: (_, _) => mockStateStore,
        buildDatabase: (_, _) => database,
        notificationService: mockNotificationService,
      );

      await connectSuccessfully(xmppService);
      eventStreamController.add(
        mox.ConnectionStateChangedEvent(
          ConnectionState.connected,
          ConnectionState.connecting,
        ),
      );
      await pumpEventQueue();
      TestWidgetsFlutterBinding.ensureInitialized()
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      foregroundServiceActive.value = true;

      await xmppService.ensureForegroundSocketIfActive();

      expect(bridge.acquiredClients, isEmpty);
      verify(
        () => foregroundConnection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        ),
      ).called(1);
      verify(() => foregroundConnection.reset()).called(1);

      await xmppService.close();
    },
  );
}
