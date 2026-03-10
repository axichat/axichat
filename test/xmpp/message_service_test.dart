// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/muc/muc_models.dart';
import 'package:axichat/src/notifications/bloc/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

final messageEvents = List.generate(3, (_) => generateRandomMessageEvent());

class MockMucManager extends Mock implements MUCManager {}

class FakeJid extends Fake implements mox.JID {}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeMessageEvent());
    registerFallbackValue(FakeUserAgent());
    registerFallbackValue(FakeJid());
    registerFallbackValue(FakeStanzaDetails());
    registerOmemoFallbacks();
    registerFallbackValue(mox.ChatMarker.received);
    registerFallbackValue(MessageNotificationChannel.chat);
    resetForegroundNotifier(value: false);
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late List<Message> messagesByTimestamp;
  late MockMucManager mucManager;

  setUp(() {
    mockConnection = MockXmppConnection();
    mockCredentialStore = MockCredentialStore();
    mockStateStore = MockXmppStateStore();
    mockNotificationService = MockNotificationService();
    mucManager = MockMucManager();
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
      buildStateStore: (_, _) => mockStateStore,
      buildDatabase: (_, _) => database,
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
          emitsInOrder(
            List.filled(
              messagesByTimestamp.length,
              predicate<List<Message>>(
                (items) => items.reversed.indexed.every((e) {
                  final (index, message) = e;
                  final original = messagesByTimestamp[index];
                  return compareMessages(original, message);
                }),
              ),
            ),
          ),
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
          emitsInOrder(
            List.filled(
              messagesByTimestamp.length,
              predicate<List<Message>>(
                (items) => items.reversed.indexed.every((e) {
                  final (index, message) = e;
                  final original = messagesByTimestamp[index];
                  return compareMessages(original, message);
                }),
              ),
            ),
          ),
        );

        messagesByTimestamp[0] = messagesByTimestamp[0].copyWith(
          body: '',
          edited: true,
        );
        await database.saveMessageEdit(
          stanzaID: messagesByTimestamp[0].stanzaID,
          body: '',
        );

        await pumpEventQueue();
        messagesByTimestamp[0] = messagesByTimestamp[0].copyWith(acked: true);
        await database.markMessageAcked(messagesByTimestamp[0].stanzaID);

        await pumpEventQueue();
        messagesByTimestamp[1] = messagesByTimestamp[1].copyWith(
          received: true,
        );

        await pumpEventQueue();
        await database.markMessageReceived(messagesByTimestamp[1].stanzaID);

        await pumpEventQueue();
        messagesByTimestamp[2] = messagesByTimestamp[2].copyWith(
          displayed: true,
        );
        await database.markMessageDisplayed(messagesByTimestamp[2].stanzaID);
      },
    );

    test('Self chat stream hides calendar sync envelopes', () async {
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

      final calendarMessage = Message.fromMox(
        syncEvent,
      ).copyWith(timestamp: DateTime.timestamp().toLocal());
      final normalMessage = Message.fromMox(normalEvent).copyWith(
        timestamp: DateTime.timestamp().toLocal().add(
          const Duration(seconds: 1),
        ),
      );

      final emissions = <List<Message>>[];
      final subscription = xmppService
          .messageStreamForChat(selfJid)
          .listen(emissions.add);

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
        emissions
            .expand((items) => items)
            .any((message) => message.body == syncEnvelope),
        isFalse,
      );
    });
  });

  group('sendMessage', () {
    final messageID = uuid.v4();
    final jid = generateRandomJid();
    const text = 'text';

    test('Given a valid message, saves it to the database.', () async {
      await connectSuccessfully(xmppService);

      final beforeMessage = await database.getMessageByStanzaID(messageID);
      expect(beforeMessage, isNull);

      when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      await xmppService.sendMessage(jid: jid, text: text);

      final afterMessage = await database.getMessageByStanzaID(messageID);
      expect(
        afterMessage,
        isA<Message>()
            .having((m) => m.stanzaID, 'stanzaID', messageID)
            .having((m) => m.chatJid, 'chatJid', jid)
            .having((m) => m.body, 'body', text),
      );
    });

    test(
      'Given a valid message, sends a message packet to the connection.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

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

    test('Given an invalid message, throws an XmppMessageException.', () async {
      await connectSuccessfully(xmppService);

      final beforeMessage = await database.getMessageByStanzaID(messageID);
      expect(beforeMessage, isNull);

      when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => false);

      expectLater(
        () => xmppService.sendMessage(jid: jid, text: text),
        throwsA(isA<XmppMessageException>()),
      );
    });

    test(
      'Given an invalid message, saves the message with an error to the database.',
      () async {
        await connectSuccessfully(xmppService);

        final beforeMessage = await database.getMessageByStanzaID(messageID);
        expect(beforeMessage, isNull);

        when(() => mockConnection.generateId()).thenAnswer((_) => messageID);
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => false);

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

    test(
      'Repairs stale MUC chat typing before sending a bare room message.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        when(() => mucManager.getRoomState(any())).thenAnswer(
          (_) async => mox.RoomState(
            roomJid: mox.JID.fromString(roomJid),
            joined: true,
            nick: roomNick,
          ),
        );
        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.chat,
            myNickname: roomNick,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: '$roomJid/$roomNick',
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.sendMessage(jid: roomJid, text: text);

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having((event) => event.type, 'type', 'groupchat')
                  .having(
                    (event) => event.to.toBare().toString(),
                    'to',
                    roomJid,
                  ),
            ),
          ),
        ).called(1);
        final chat = await database.getChat(roomJid);
        expect(chat?.type, ChatType.groupChat);
      },
    );

    test(
      'Repairs stale MUC manager joined state from ready self presence before sending.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: false,
          nick: roomNick,
        );
        when(
          () => mucManager.getRoomState(any()),
        ).thenAnswer((_) async => managerRoomState);
        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: roomNick,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: '$roomJid/$roomNick',
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.sendMessage(jid: roomJid, text: text);

        verifyNever(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        );
        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having((event) => event.type, 'type', 'groupchat')
                  .having(
                    (event) => event.to.toBare().toString(),
                    'to',
                    roomJid,
                  ),
            ),
          ),
        ).called(1);
      },
    );
  });

  group('reactToMessage', () {
    const sameDomainJid = 'friend@axi.im';
    const emoji = '\u{1F44D}';

    test('Allows same-domain reactions when disco fails', () async {
      await connectSuccessfully(xmppService);
      when(() => mockConnection.discoInfoQuery(any())).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
          mox.ServiceUnavailableError(),
        ),
      );
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      const stanzaId = 'same-domain-reaction';
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: sameDomainJid,
          chatJid: sameDomainJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        ),
      );

      await xmppService.reactToMessage(stanzaID: stanzaId, emoji: emoji);

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>().having(
              (event) =>
                  event.extensions.get<mox.MessageReactionsData>()?.messageId,
              'reaction target',
              stanzaId,
            ),
          ),
        ),
      ).called(1);
      final reactions = await database.getReactionsForMessageSender(
        messageId: stanzaId,
        senderJid: xmppService.myJid!,
      );
      expect(
        reactions.map((reaction) => reaction.emoji).toList(),
        equals(const <String>[emoji]),
      );
    });

    test(
      'Applies inbound reactions when the target matches message originID',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        const stanzaId = 'stored-stanza-id';
        const originId = 'stable-origin-id';
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            originID: originId,
            senderJid: sameDomainJid,
            chatJid: sameDomainJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        final reactionEvent = mox.MessageEvent(
          mox.JID.fromString(sameDomainJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageReactionsData(originId, <String>[emoji]),
          ]),
          id: uuid.v4(),
          type: 'chat',
        );

        controller.add(reactionEvent);
        await pumpEventQueue();
        await pumpEventQueue();

        final reactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: sameDomainJid,
        );
        expect(
          reactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[emoji]),
        );

        await controller.close();
      },
    );
  });

  group('sendReadMarker', () {
    test('Allows @axi.im read markers when disco fails', () async {
      const axiPeerJid = 'friend@axi.im';
      const stanzaId = 'axi-read-marker';
      await connectSuccessfully(xmppService);
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
          messageType: any(named: 'messageType'),
        ),
      ).thenAnswer((_) async => true);

      await xmppService.sendReadMarker(axiPeerJid, stanzaId);

      verify(
        () => mockConnection.sendChatMarker(
          to: axiPeerJid,
          stanzaID: stanzaId,
          marker: mox.ChatMarker.received,
          messageType: 'chat',
        ),
      ).called(1);
      verify(
        () => mockConnection.sendChatMarker(
          to: axiPeerJid,
          stanzaID: stanzaId,
          marker: mox.ChatMarker.displayed,
          messageType: 'chat',
        ),
      ).called(1);
    });
  });

  group('_acknowledgeMessage', () {
    test(
      'Assumes reaction support for bare MUC room JIDs without disco',
      () async {
        const roomJid = 'room@conference.axi.im';
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');

        final capabilities = await xmppService.resolvePeerCapabilities(
          jid: roomJid,
        );

        expect(capabilities.features, contains(mox.messageReactionsXmlns));
        verifyNever(() => mockConnection.discoInfoQuery(roomJid));
      },
    );

    test('Assumes current peer capabilities for @axi.im contacts', () async {
      await connectSuccessfully(xmppService);

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: 'friend@axi.im',
      );

      expect(capabilities.features, contains(mox.chatMarkersXmlns));
      expect(capabilities.features, contains(mox.deliveryXmlns));
      expect(capabilities.features, contains(mox.messageReactionsXmlns));
      expect(capabilities.features, contains(mox.chatStateXmlns));
      expect(capabilities.features, contains(mox.omemoXmlns));
    });

    test('Caches disco capabilities per peer', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);
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
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

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
    });

    test('Skips carbon echoes', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);
      when(() => mockConnection.discoInfoQuery(any())).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
          mox.ServiceUnavailableError(),
        ),
      );
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

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
    });
  });

  group('calendar sync handling', () {
    test(
      'Calendar sync envelopes are handled without storing chat messages',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
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
}
