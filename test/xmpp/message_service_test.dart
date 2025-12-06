// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/settings/message_storage_mode.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

final messageEvents = List.generate(3, (_) => generateRandomMessageEvent());

bool compareMessages(Message a, Message b) =>
    a.stanzaID == b.stanzaID &&
    a.senderJid == b.senderJid &&
    a.chatJid == b.chatJid &&
    //Drift only has second precision in test environment
    a.timestamp?.floorSeconds == b.timestamp?.floorSeconds &&
    a.body == b.body &&
    a.acked == b.acked &&
    a.received == b.received &&
    a.displayed == b.displayed;

main() {
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
  late List<Message> messagesByTimestamp;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    when(
      () => mockNotificationService.sendNotification(
        title: any(named: 'title'),
        body: any(named: 'body'),
        extraConditions: any(named: 'extraConditions'),
        allowForeground: any(named: 'allowForeground'),
        payload: any(named: 'payload'),
      ),
    ).thenAnswer((_) async {});
    database = XmppDrift.inMemory();
    xmppService = XmppService(
      buildConnection: () => mockConnection,
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
      notificationService: mockNotificationService,
    );
    messagesByTimestamp = messageEvents.indexed.map((e) {
      final (index, message) = e;
      return Message.fromMox(message).copyWith(
        timestamp: DateTime.timestamp().toLocal().add(Duration(seconds: index)),
      );
    }).toList();

    prepareMockConnection();
  });

  tearDown(() async {
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

    test(
      'Self chat stream hides calendar sync envelopes',
      () async {
        await connectSuccessfully(xmppService);
        final selfJid = xmppService.myJid!;
        final syncEnvelope = jsonEncode({
          'calendar_sync': CalendarSyncMessage.request().toJson(),
        });
        final syncEvent = mox.MessageEvent(
          mox.JID.fromString(selfJid),
          mox.JID.fromString(selfJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(syncEnvelope),
            mox.MessageIdData(uuid.v4()),
          ]),
          id: uuid.v4(),
        );
        final normalEvent = mox.MessageEvent(
          mox.JID.fromString(selfJid),
          mox.JID.fromString(selfJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('hello'),
            mox.MessageIdData(uuid.v4()),
          ]),
          id: uuid.v4(),
        );

        final calendarMessage = Message.fromMox(syncEvent).copyWith(
          timestamp: DateTime.timestamp().toLocal(),
        );
        final normalMessage = Message.fromMox(normalEvent).copyWith(
          timestamp:
              DateTime.timestamp().toLocal().add(const Duration(seconds: 1)),
        );

        final emissions = <List<Message>>[];
        final subscription =
            xmppService.messageStreamForChat(selfJid).listen(emissions.add);

        await database.saveMessage(calendarMessage);
        await database.saveMessage(normalMessage);
        await pumpEventQueue();
        await subscription.cancel();

        final latest = emissions.isEmpty ? <Message>[] : emissions.last;
        expect(
          latest,
          isA<List<Message>>()
              .having((items) => items.length, 'length', 1)
              .having((items) => items.first.body, 'body', normalMessage.body),
        );
        expect(
          emissions.expand((items) => items).any(
                (message) => message.body == syncEnvelope,
              ),
          isFalse,
        );
      },
    );
  });

  group('sendMessage', () {
    final messageID = uuid.v4();
    final jid = generateRandomJid();
    const text = 'text';

    test(
      'Given a valid message, saves it to the database.',
      () async {
        await connectSuccessfully(xmppService);

        final beforeMessage = await database.getMessageByStanzaID(messageID);
        expect(beforeMessage, isNull);

        when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

        await xmppService.sendMessage(jid: jid, text: text);

        final afterMessage = await database.getMessageByStanzaID(messageID);
        expect(
          afterMessage,
          isA<Message>()
              .having((m) => m.stanzaID, 'stanzaID', messageID)
              .having((m) => m.chatJid, 'chatJid', jid)
              .having((m) => m.body, 'body', text),
        );
      },
    );

    test(
      'Given a valid message, sends a message packet to the connection.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

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

    test(
      'Given an invalid message, throws an XmppMessageException.',
      () async {
        await connectSuccessfully(xmppService);

        final beforeMessage = await database.getMessageByStanzaID(messageID);
        expect(beforeMessage, isNull);

        when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => false);

        expectLater(
          () => xmppService.sendMessage(jid: jid, text: text),
          throwsA(isA<XmppMessageException>()),
        );
      },
    );

    test(
      'Given an invalid message, saves the message with an error to the database.',
      () async {
        await connectSuccessfully(xmppService);

        final beforeMessage = await database.getMessageByStanzaID(messageID);
        expect(beforeMessage, isNull);

        when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => false);

        try {
          await xmppService.sendMessage(jid: jid, text: text);
        } on XmppMessageException catch (_) {}

        await pumpEventQueue();

        final afterMessage = await database.getMessageByStanzaID(messageID);
        expect(
          afterMessage,
          isA<Message>()
              .having((m) => m.stanzaID, 'stanzaID', messageID)
              .having((m) => m.chatJid, 'chatJid', jid)
              .having((m) => m.body, 'body', text)
              .having((m) => m.error, 'error', MessageError.unknown),
        );
      },
    );
  });

  group('_acknowledgeMessage', () {
    test(
      'Caches disco capabilities per peer',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(() => mockConnection.asBroadcastStream())
            .thenAnswer((_) => controller.stream);
        when(() => mockConnection.discoInfoQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
            mox.ServiceUnavailableError(),
          ),
        );
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
          ),
        ).thenAnswer((_) async => true);
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        final event = generateRandomMessageEvent();
        controller.add(event);
        await pumpEventQueue();
        await pumpEventQueue();

        controller.add(
          generateRandomMessageEvent(senderJid: event.from.toString()),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        verify(
          () => mockConnection.discoInfoQuery(event.from.toBare().toString()),
        ).called(1);

        await controller.close();
      },
    );

    test(
      'Skips carbon echoes',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(() => mockConnection.asBroadcastStream())
            .thenAnswer((_) => controller.stream);
        when(() => mockConnection.discoInfoQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
            mox.ServiceUnavailableError(),
          ),
        );
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        final carbonEvent = mox.MessageEvent(
          mox.JID.fromString(jid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.CarbonsData(true),
            const mox.MarkableData(true),
            mox.MessageIdData(uuid.v4()),
          ]),
          id: uuid.v4(),
        );

        controller.add(carbonEvent);
        await pumpEventQueue();
        await pumpEventQueue();

        await controller.close();
      },
    );
  });

  group('calendar sync handling', () {
    test(
      'Calendar sync envelopes are handled without storing chat messages',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(() => mockConnection.asBroadcastStream())
            .thenAnswer((_) => controller.stream);
        when(() => mockConnection.discoInfoQuery(any())).thenAnswer(
          (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
            mox.ServiceUnavailableError(),
          ),
        );

        await connectSuccessfully(xmppService);

        final selfJid = xmppService.myJid!;
        final syncEnvelope = jsonEncode({
          'calendar_sync': CalendarSyncMessage.request().toJson(),
        });
        final stanzaId = uuid.v4();
        final syncEvent = mox.MessageEvent(
          mox.JID.fromString(selfJid),
          mox.JID.fromString(selfJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            mox.MessageBodyData(syncEnvelope),
            mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
        );

        controller.add(syncEvent);
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored, isNull);

        await controller.close();
      },
    );
  });

  group('server-only storage', () {
    test(
      'Uses an in-memory database and trims chat history to the cap',
      () async {
        xmppService.setMamSupportOverride(true);
        xmppService.updateMessageStorageMode(MessageStorageMode.serverOnly);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(() => mockConnection.sendMessage(any()))
            .thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        final memoryDb = await xmppService.database;
        expect(memoryDb, isA<XmppDrift>());
        expect((memoryDb as XmppDrift).isInMemory, isTrue);

        const targetJid = 'contact@axi.im';
        const targetCount = serverOnlyChatMessageCap + 10;
        try {
          for (var i = 0; i < targetCount; i++) {
            await xmppService.sendMessage(
              jid: targetJid,
              text: 'message $i',
            );
          }
        } on XmppUnknownException catch (error, stackTrace) {
          fail(
            'Unexpected XmppUnknownException: ${error.wrapped ?? error}\n'
            'wrappedType=${error.wrapped?.runtimeType ?? 'unknown'}\n'
            '$stackTrace',
          );
        }

        final storedCount = await memoryDb.countChatMessages(targetJid,
            includePseudoMessages: true);
        expect(storedCount, serverOnlyChatMessageCap);
      },
    );
  });
}
