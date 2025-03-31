import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart' hide uuid;
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

final messageEvents = [
  for (var i = 0; i < 3; i++) generateRandomMessageEvent()
];

bool compareMessages(Message a, Message b) =>
    a.stanzaID == b.stanzaID &&
    a.senderJid == b.senderJid &&
    a.chatJid == b.chatJid &&
    //Drift only has second precision in test environment
    a.timestamp!.second == b.timestamp!.second &&
    a.body == b.body &&
    a.acked == b.acked &&
    a.received == b.received &&
    a.displayed == b.displayed;

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late List<Message> messagesByTimestamp;

  setUp(() {
    mockXmppService = MockXmppService();
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    database = XmppDrift(
      file: File(''),
      passphrase: '',
      executor: NativeDatabase.memory(),
    );
    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
    messagesByTimestamp = messageEvents.indexed.map((e) {
      final (index, message) = e;
      return xmppService.generateMessageFromMox(message).copyWith(
            timestamp:
                DateTime.timestamp().toLocal().add(Duration(seconds: index)),
          );
    }).toList();

    prepareMockConnection();
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('messageStream', () {
    test(
      'When messages are added to the chat\'s database, emits the new message history in order.',
      () async {
        expectLater(
          xmppService.messageStreamForChat(messagesByTimestamp[0].chatJid),
          emitsInOrder(List.filled(
            messagesByTimestamp.length,
            predicate<List<Message>>(
              (items) => items.reversed.indexed.every(
                (e) {
                  final (index, message) = e;
                  final original = messagesByTimestamp[index];
                  return compareMessages(original, message);
                },
              ),
            ),
          )),
        );

        await connectSuccessfully(xmppService);

        for (final message in messagesByTimestamp) {
          await database.saveMessage(message);
        }
      },
    );

    test(
      'When messages are edited in the chat\'s database, emits the updated message history in order.',
      () async {
        await connectSuccessfully(xmppService);

        for (final message in messagesByTimestamp) {
          await database.saveMessage(message);
        }

        await pumpEventQueue();

        expectLater(
          xmppService.messageStreamForChat(messagesByTimestamp[0].chatJid),
          emitsInOrder(List.filled(
            messagesByTimestamp.length,
            predicate<List<Message>>(
              (items) => items.reversed.indexed.every(
                (e) {
                  final (index, message) = e;
                  final original = messagesByTimestamp[index];
                  return compareMessages(original, message);
                },
              ),
            ),
          )),
        );

        messagesByTimestamp[0] =
            messagesByTimestamp[0].copyWith(body: '', edited: true);
        await database.saveMessageEdit(
          stanzaID: messagesByTimestamp[0].stanzaID,
          body: '',
        );

        await pumpEventQueue();
        messagesByTimestamp[0] = messagesByTimestamp[0].copyWith(acked: true);
        await database.markMessageAcked(messagesByTimestamp[0].stanzaID);

        await pumpEventQueue();
        messagesByTimestamp[1] =
            messagesByTimestamp[1].copyWith(received: true);

        await pumpEventQueue();
        await database.markMessageReceived(messagesByTimestamp[1].stanzaID);

        await pumpEventQueue();
        messagesByTimestamp[2] =
            messagesByTimestamp[2].copyWith(displayed: true);
        await database.markMessageDisplayed(messagesByTimestamp[2].stanzaID);
      },
    );
  });

  group('sendMessage', () {
    test(
      'Given a valid message, sends a message packet to the connection.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(() => mockConnection.sendMessage(any())).thenAnswer((_) async {});

        const text = 'text';
        await xmppService.sendMessage(jid: jid, text: text);

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having((e) => e.to, 'to', mox.JID.fromString(jid))
                  .having((e) => e.text, 'text', text),
            ),
          ),
        ).called(1);
      },
    );
  });
}
