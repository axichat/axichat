import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart';
import 'package:chat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

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
    registerFallbackValue(FakeUserAgent());
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late List<Message> messagesByTimestamp;

  setUp(() {
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
    resetMocktailState();
  });

  group('messageStream', () {
    test(
      'When messages are added to the chat\'s database, emits the new message history in order.',
      () async {
        expectLater(
          xmppService.messageStream(messagesByTimestamp[0].chatJid),
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

        guaranteeSuccessfulConnection();

        xmppService.connect(
          jid: jid,
          password: password,
          databasePrefix: '',
          databasePassphrase: '',
        );

        for (final message in messagesByTimestamp) {
          await database.saveMessage(message);
        }
      },
    );

    test(
      'When messages are edited in the chat\'s database, emits the updated message history in order.',
      () async {
        guaranteeSuccessfulConnection();

        xmppService.connect(
          jid: jid,
          password: password,
          databasePrefix: '',
          databasePassphrase: '',
        );

        for (final message in messagesByTimestamp) {
          await database.saveMessage(message);
        }

        await Future.delayed(const Duration(milliseconds: 500));

        expectLater(
          xmppService.messageStream(messagesByTimestamp[0].chatJid),
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

        await Future.delayed(const Duration(milliseconds: 500));
        messagesByTimestamp[0] = messagesByTimestamp[0].copyWith(acked: true);
        await database.markMessageAcked(messagesByTimestamp[0].stanzaID);

        await Future.delayed(const Duration(milliseconds: 500));
        messagesByTimestamp[1] =
            messagesByTimestamp[1].copyWith(received: true);

        await Future.delayed(const Duration(milliseconds: 500));
        await database.markMessageReceived(messagesByTimestamp[1].stanzaID);

        await Future.delayed(const Duration(milliseconds: 500));
        messagesByTimestamp[2] =
            messagesByTimestamp[2].copyWith(displayed: true);
        await database.markMessageDisplayed(messagesByTimestamp[2].stanzaID);
      },
    );
  });
}
