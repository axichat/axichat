import 'dart:async';
import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

class MockPresenceManager extends Mock implements XmppPresenceManager {}

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
      await database.deleteAll();
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
}
