// ignore_for_file: depend_on_referenced_packages

import 'dart:async';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';
import '../security_corpus/security_corpus.dart';

const String _roomJid = 'room@conference.axi.im';
const String _roomSender = 'room@conference.axi.im/nick';
const String _accountJid = 'jid@axi.im/resource';
const String _reactionEmoji = '\u{1F44D}';
const String _fallbackMessageBody = 'hello';

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

  Future<String> seedMessage() async {
    final stanzaId = uuid.v4();
    final message = Message(
      stanzaID: stanzaId,
      senderJid: _roomSender,
      chatJid: _roomJid,
      timestamp: DateTime.timestamp(),
      body: _fallbackMessageBody,
    );
    await database.saveMessage(message, chatType: ChatType.groupChat);
    return stanzaId;
  }

  Future<mox.MessageEvent> buildReactionEvent({
    required String targetId,
    required bool isFromMam,
  }) async {
    final extensions = mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
      mox.MessageReactionsData(targetId, const <String>[_reactionEmoji]),
    ]);
    return mox.MessageEvent(
      mox.JID.fromString(_roomSender),
      mox.JID.fromString(_accountJid),
      false,
      extensions,
      id: uuid.v4(),
      type: 'groupchat',
      isFromMAM: isFromMam,
    );
  }

  test('applies group mutation authorization from corpus', () async {
    await connectSuccessfully(xmppService);
    final corpus = SecurityCorpus.load();

    for (final entry in corpus.groupMutationCases) {
      final targetId = await seedMessage();
      final event = await buildReactionEvent(
        targetId: targetId,
        isFromMam: entry.isFromMam,
      );

      eventStreamController.add(event);
      await pumpEventQueue();

      final reactions = await database.getReactionsForMessageSender(
        messageId: targetId,
        senderJid: _roomSender,
      );
      if (entry.expectation.isAuthorized) {
        expect(
          reactions.map((reaction) => reaction.emoji).toList(),
          contains(_reactionEmoji),
        );
      } else {
        expect(reactions, isEmpty);
      }
    }
  });
}
