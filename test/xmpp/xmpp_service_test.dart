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
import 'package:uuid/uuid.dart';

import '../mocks.dart';

const jid = 'jid@axi.im/resource';
const password = 'password';
const from = 'from@axi.im';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
  });

  late XmppDatabase database;
  late MockNotificationService notificationService;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    notificationService = MockNotificationService();
    eventStreamController = StreamController<mox.XmppEvent>();

    when(() => mockConnection.hasConnectionSettings).thenReturn(false);

    when(() => mockConnection.registerFeatureNegotiators(any()))
        .thenAnswer((_) async {});

    when(() => mockConnection.registerManagers(any())).thenAnswer((_) async {});

    when(() => mockConnection.loadStreamState()).thenAnswer((_) async {});
    when(() => mockConnection.setUserAgent(any())).thenAnswer((_) {});
    when(() => mockConnection.setFastToken(any())).thenAnswer((_) {});

    when(() => mockConnection.saltedPassword).thenReturn('');

    when(() => mockConnection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);
  });

  tearDown(() async {
    await eventStreamController.close();
    await database.close();
  });

  group('XmppService event handler', () {
    late XmppService xmppService;

    setUp(() async {
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: (_, __) => mockStateStore,
        buildDatabase: (_, __) => database,
        notificationService: notificationService,
      );
      mockSuccessfulConnection();

      await xmppService.connect(
        jid: jid,
        password: password,
        databasePrefix: '',
        databasePassphrase: '',
      );
    });

    tearDown(() async {
      await xmppService.close();
    });

    final stanzaID = const Uuid().v4();
    const text =
        ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
    final standardMessage = mox.MessageEvent(
      mox.JID.fromString(from),
      mox.JID.fromString(jid),
      false,
      mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        const mox.MessageBodyData(text),
        const mox.MarkableData(true),
        mox.MessageIdData(stanzaID),
        mox.ChatState.active,
      ]),
      id: stanzaID,
    );

    test(
        'Given a standard text message, writes it to the database and notifies the user.',
        () async {
      when(() => notificationService.sendNotification(
            title: any(named: 'title'),
            body: any(named: 'body'),
            groupKey: any(named: 'groupKey'),
            extraConditions: any(named: 'extraConditions'),
          )).thenAnswer((_) async {});

      final beforeMessage = await database.getMessageByStanzaID(stanzaID);
      expect(beforeMessage, isNull);

      eventStreamController.add(standardMessage);

      await Future.delayed(const Duration(seconds: 1));

      final afterMessage = await database.getMessageByStanzaID(stanzaID);
      expect(afterMessage?.stanzaID, equals(stanzaID));
      expect(afterMessage?.body, equals(text));

      verify(() => notificationService.sendNotification(
            title: standardMessage.from.toBare().toString(),
            body: text,
            groupKey: any(named: 'groupKey'),
            extraConditions: any(named: 'extraConditions'),
          )).called(1);
    });

    test('Given a connection change, emits the corresponding connection state.',
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
    });

    test(
        'Given a stanza acknowledgement, marks the correct message in the database acked.',
        () async {
      final message = Message(
        stanzaID: stanzaID,
        senderJid: from,
        chatJid: from,
      );
      await database.saveMessage(message);

      final beforeAcked = await database.getMessageByStanzaID(stanzaID);
      expect(beforeAcked?.acked, isFalse);

      eventStreamController
          .add(mox.StanzaAckedEvent(mox.Stanza(tag: 'message', id: stanzaID)));

      await Future.delayed(const Duration(seconds: 1));

      final afterAcked = await database.getMessageByStanzaID(stanzaID);
      expect(afterAcked?.acked, isTrue);
    });

    test(
        'Given a delivery receipt, marks the correct message in the database received.',
        () async {
      final message = Message(
        stanzaID: stanzaID,
        senderJid: from,
        chatJid: from,
      );
      await database.saveMessage(message);

      final beforeReceived = await database.getMessageByStanzaID(stanzaID);
      expect(beforeReceived?.received, isFalse);

      eventStreamController.add(mox.DeliveryReceiptReceivedEvent(
        from: mox.JID.fromString(from),
        id: stanzaID,
      ));

      await Future.delayed(const Duration(seconds: 1));

      final afterReceived = await database.getMessageByStanzaID(stanzaID);
      expect(afterReceived?.received, isTrue);
    });
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

    late XmppService xmppService;

    setUp(() {
      builtStateStore = false;
      builtDatabase = false;
      xmppService = XmppService(
        buildConnection: () => mockConnection,
        buildStateStore: buildStateStore,
        buildDatabase: buildDatabase,
        notificationService: notificationService,
      );
    });

    tearDown(() async {
      await xmppService.close();
      resetMocktailState();
    });

    test('Given valid credentials, connect initialises the databases.',
        () async {
      mockSuccessfulConnection();

      await xmppService.connect(
        jid: jid,
        password: password,
        databasePrefix: '',
        databasePassphrase: '',
      );

      expect(builtStateStore, true);
      expect(builtDatabase, true);
    });

    test(
        'Given invalid credentials, connect throws an XmppAuthenticationException.',
        () async {
      mockUnsuccessfulConnection();

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
    });
  });
}
