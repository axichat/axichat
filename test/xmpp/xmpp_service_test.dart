import 'dart:async';
import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    eventStreamController = StreamController<mox.XmppEvent>();

    prepareMockConnection();

    when(() => mockConnection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);
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
        buildStateStore: (_, __) => mockStateStore,
        buildDatabase: (_, __) => database,
        notificationService: mockNotificationService,
      );
      guaranteeSuccessfulConnection();

      await xmppService.connect(
        jid: jid,
        password: password,
        databasePrefix: '',
        databasePassphrase: '',
      );

      messageEvent = generateRandomMessageEvent();
      message = xmppService.generateMessageFromMox(messageEvent);
    });

    tearDown(() async {
      await database.deleteAll();
      await xmppService.close();
    });

    test(
      'Given a standard text message, writes it to the database and notifies the user.',
      () async {
        when(() => mockNotificationService.sendNotification(
              title: any(named: 'title'),
              body: any(named: 'body'),
              groupKey: any(named: 'groupKey'),
              extraConditions: any(named: 'extraConditions'),
            )).thenAnswer((_) async {});

        final beforeMessage =
            await database.getMessageByStanzaID(messageEvent.id!);
        expect(beforeMessage, isNull);

        eventStreamController.add(messageEvent);

        await Future.delayed(const Duration(seconds: 1));

        final afterMessage =
            await database.getMessageByStanzaID(messageEvent.id!);
        expect(afterMessage?.stanzaID, equals(messageEvent.id!));
        expect(afterMessage?.body, equals(messageEvent.text));

        verify(() => mockNotificationService.sendNotification(
              title: messageEvent.from.toBare().toString(),
              body: messageEvent.text,
              groupKey: any(named: 'groupKey'),
              extraConditions: any(named: 'extraConditions'),
            )).called(1);
      },
    );

    test(
      'Given a connection change, emits the corresponding connection state.',
      () async {
        expectLater(
          xmppService.connectivityStream,
          emitsInOrder([
            ConnectionState.notConnected,
            ConnectionState.connecting,
            ConnectionState.connected,
            ConnectionState.error,
            ConnectionState.notConnected,
            ConnectionState.error,
            ConnectionState.connected,
            ConnectionState.connecting,
          ]),
        );

        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.notConnected,
          mox.XmppConnectionState.notConnected,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connecting,
          mox.XmppConnectionState.notConnected,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.connecting,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.error,
          mox.XmppConnectionState.connected,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.notConnected,
          mox.XmppConnectionState.error,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.error,
          mox.XmppConnectionState.notConnected,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connected,
          mox.XmppConnectionState.error,
        ));
        eventStreamController.add(mox.ConnectionStateChangedEvent(
          mox.XmppConnectionState.connecting,
          mox.XmppConnectionState.connected,
        ));
      },
    );

    test(
      'Given a stanza acknowledgement, marks the correct message in the database acked.',
      () async {
        await database.saveMessage(message);

        final beforeAcked =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(beforeAcked?.acked, isFalse);

        eventStreamController.add(mox.StanzaAckedEvent(
            mox.Stanza(tag: 'message', id: message.stanzaID)));

        await Future.delayed(const Duration(seconds: 1));

        final afterAcked =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(afterAcked?.acked, isTrue);
      },
    );

    test(
      'Given a displayed chat marker, marks the correct message in the database displayed.',
      () async {
        await database.saveMessage(message);

        final beforeDisplayed =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(beforeDisplayed?.acked, isFalse);

        eventStreamController.add(mox.ChatMarkerEvent(
            mox.JID.fromString(message.senderJid),
            mox.ChatMarker.displayed,
            message.stanzaID));

        await Future.delayed(const Duration(seconds: 1));

        final afterDisplayed =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(afterDisplayed?.displayed, isTrue);
        expect(afterDisplayed?.received, isTrue);
        expect(afterDisplayed?.acked, isTrue);
      },
    );

    test(
      'Given a delivery receipt, marks the correct message in the database received.',
      () async {
        await database.saveMessage(message);

        final beforeReceived =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(beforeReceived?.received, isFalse);

        eventStreamController.add(mox.DeliveryReceiptReceivedEvent(
          from: mox.JID.fromString(message.senderJid),
          id: message.stanzaID,
        ));

        await Future.delayed(const Duration(seconds: 1));

        final afterReceived =
            await database.getMessageByStanzaID(message.stanzaID);
        expect(afterReceived?.received, isTrue);
      },
    );
  });

  group('XmppService authentication', () {
    bool builtStateStore = false;
    bool builtDatabase = false;

    XmppStateStore buildStateStore(String _, String __) {
      builtStateStore = true;
      return mockStateStore;
    }

    XmppDatabase buildDatabase(String _, String __) {
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

    test(
      'Given valid credentials, connect initialises the databases.',
      () async {
        guaranteeSuccessfulConnection();

        await xmppService.connect(
          jid: jid,
          password: password,
          databasePrefix: '',
          databasePassphrase: '',
        );

        expect(builtStateStore, true);
        expect(builtDatabase, true);
      },
    );

    test(
      'Given invalid credentials, connect throws an XmppAuthenticationException.',
      () async {
        guaranteeUnsuccessfulConnection();

        await expectLater(
          () => xmppService.connect(
            jid: jid,
            password: password,
            databasePrefix: '',
            databasePassphrase: '',
          ),
          throwsA(isA<XmppAuthenticationException>()),
        );

        expect(builtDatabase, false);
      },
    );
  });
}
