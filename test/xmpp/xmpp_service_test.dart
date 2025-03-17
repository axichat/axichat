import 'dart:async';
import 'dart:io';

import 'package:chat/src/common/capability.dart';
import 'package:chat/src/common/policy.dart';
import 'package:chat/src/storage/credential_store.dart';
import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/state_store.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;
import 'package:uuid/uuid.dart';

import '../mocks.dart';

const jid = 'jid@axi.im/resource';
const password = 'password';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeUserAgent());
  });

  late MockXmppConnection connection;
  late MockCredentialStore credentialStore;
  late MockXmppStateStore stateStore;
  late XmppDatabase database;
  late MockNotificationService notificationService;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    connection = MockXmppConnection();
    credentialStore = MockCredentialStore();
    stateStore = MockXmppStateStore();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    notificationService = MockNotificationService();
    eventStreamController = StreamController<mox.XmppEvent>();

    when(() => connection.hasConnectionSettings).thenReturn(false);

    when(() => connection.registerFeatureNegotiators(any()))
        .thenAnswer((_) async {});

    when(() => connection.registerManagers(any())).thenAnswer((_) async {});

    when(() => connection.loadStreamState()).thenAnswer((_) async {});
    when(() => connection.setUserAgent(any())).thenAnswer((_) {});
    when(() => connection.setFastToken(any())).thenAnswer((_) {});

    when(() => connection.saltedPassword).thenReturn('');

    when(() => connection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);
  });

  tearDown(() async {
    await eventStreamController.close();
    await database.close();
  });

  void mockSuccessfulConnection() {
    when(() => stateStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);

    when(() => connection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        )).thenAnswer((_) async => const Result<bool, mox.XmppError>(true));

    when(() => stateStore.close()).thenAnswer((_) async {});
  }

  void mockUnsuccessfulConnection() {
    when(() => stateStore.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        )).thenAnswer((_) async => true);

    when(() => connection.connect(
          shouldReconnect: false,
          waitForConnection: true,
          waitUntilLogin: true,
        )).thenAnswer((_) async => const Result<bool, mox.XmppError>(false));

    when(() => stateStore.close()).thenAnswer((_) async {});
  }

  group('XmppService event handler', () {
    late XmppService xmppService;

    setUp(() {
      xmppService = XmppService(
        buildConnection: () => connection,
        buildStateStore: (_, __) => stateStore,
        buildDatabase: (_, __) => database,
        notificationService: notificationService,
      );
    });

    tearDown(() async {
      await xmppService.close();
    });

    final stanzaID = const Uuid().v4();
    const text =
        ' !"#\$%&\'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~';
    final standardMessage = mox.MessageEvent(
      mox.JID.fromString('from'),
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

    test('Given a standard text message, the handler writes it to the database',
        () async {
      mockSuccessfulConnection();

      await xmppService.connect(
        jid: jid,
        password: password,
        databasePrefix: '',
        databasePassphrase: '',
      );

      when(() => notificationService.sendNotification(
            title: any(named: 'title'),
            body: any(named: 'body'),
            groupKey: any(named: 'groupKey'),
            extraConditions: any(named: 'extraConditions'),
          )).thenAnswer((_) async {});

      final beforeMessage = await database.getMessageByStanzaID(stanzaID);
      expect(beforeMessage, isNull);

      eventStreamController.sink.add(standardMessage);

      await Future.delayed(const Duration(seconds: 1));

      final afterMessage = await database.getMessageByStanzaID(stanzaID);
      expect(afterMessage?.stanzaID, equals(stanzaID));
      expect(afterMessage?.body, equals(text));
    });
  });

  group('XmppService authentication', () {
    bool builtStateStore = false;
    bool builtDatabase = false;

    XmppStateStore buildStateStore(String _, String __) {
      builtStateStore = true;
      return stateStore;
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
        buildConnection: () => connection,
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
