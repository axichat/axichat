// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';
import '../security_corpus/security_corpus.dart';

const String _defaultMessageBody = 'hello';
const String _defaultMessageType = 'chat';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
    registerFallbackValue(mox.ChatMarker.received);
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late StreamController<mox.XmppEvent> eventStreamController;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift.inMemory();
    eventStreamController = StreamController<mox.XmppEvent>.broadcast();

    prepareMockConnection();

    when(() => mockConnection.asBroadcastStream())
        .thenAnswer((_) => eventStreamController.stream);

    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
  });

  tearDown(() async {
    await eventStreamController.close();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  test('validates carbon origin checks from corpus', () async {
    await connectSuccessfully(xmppService);
    final corpus = SecurityCorpus.load();

    for (final entry in corpus.messageOriginCarbons) {
      final stanzaId = uuid.v4();
      final extensions = mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        const mox.MessageBodyData(_defaultMessageBody),
        mox.MessageIdData(stanzaId),
        const mox.CarbonsData(true),
      ]);
      final event = mox.MessageEvent(
        mox.JID.fromString(entry.from),
        mox.JID.fromString(entry.to),
        false,
        extensions,
        id: stanzaId,
        type: _defaultMessageType,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored != null, entry.expectation.isValid);
    }
  });

  test('validates MAM origin checks from corpus', () async {
    await connectSuccessfully(xmppService);
    final corpus = SecurityCorpus.load();

    for (final entry in corpus.messageOriginMam) {
      final stanzaId = uuid.v4();
      final extensions = mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
        const mox.MessageBodyData(_defaultMessageBody),
        mox.MessageIdData(stanzaId),
      ]);
      final event = mox.MessageEvent(
        mox.JID.fromString(entry.from),
        mox.JID.fromString(entry.to),
        false,
        extensions,
        id: stanzaId,
        type: entry.type ?? _defaultMessageType,
        isFromMAM: true,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored != null, entry.expectation.isValid);
    }
  });
}
