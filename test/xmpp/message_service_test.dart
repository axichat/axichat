// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';

import 'package:axichat/main.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/common/file_metadata_tools.dart';
import 'package:axichat/src/xmpp/muc/occupant.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/storage/state_store.dart';
import 'package:axichat/src/xmpp/pubsub/contacts_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/pubsub/message_collections_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

final messageEvents = List.generate(3, (_) => generateRandomMessageEvent());

class MockMucManager extends Mock implements MUCManager {}

class FakeJid extends Fake implements mox.JID {}

class RecordingMessageCollectionsPubSubTransport extends PubSubManager {
  int publishCount = 0;
  int subscribeCount = 0;
  final Map<String, mox.XMLNode> publishedItems = <String, mox.XMLNode>{};
  final List<mox.XMLNode> publishedItemsInOrder = <mox.XMLNode>[];

  @override
  Future<String?> resolveSendLastPublishedItemForNode({
    required mox.JID host,
    required String node,
  }) async => null;

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async => const moxlib.Result(true);

  @override
  Future<String?> createNode(mox.JID jid, {String? nodeId}) async =>
      nodeId ?? 'created-node';

  @override
  Future<String?> createNodeWithConfig(
    mox.JID jid,
    mox.NodeConfig config, {
    String? nodeId,
  }) async => nodeId ?? 'created-node';

  @override
  Future<moxlib.Result<mox.PubSubError, mox.SubscriptionInfo>> subscribe(
    mox.JID jid,
    String node,
  ) async {
    subscribeCount += 1;
    return moxlib.Result(
      mox.SubscriptionInfo(
        jid: jid.toBare().toString(),
        node: node,
        state: mox.SubscriptionState.subscribed,
      ),
    );
  }

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> publish(
    mox.JID jid,
    String node,
    mox.XMLNode payload, {
    String? id,
    mox.PubSubPublishOptions? options,
    bool autoCreate = false,
    mox.NodeConfig? createNodeConfig,
  }) async {
    publishCount += 1;
    final itemId = id ?? 'item-$publishCount';
    publishedItems['$node|$itemId'] = payload;
    publishedItemsInOrder.add(payload);
    return const moxlib.Result(true);
  }
}

mox.XmppManagerAttributes _messageCollectionsTestAttributes({
  required PubSubManager pubSubManager,
  required String accountJid,
}) {
  final fullJid = mox.JID.fromString(accountJid);
  return mox.XmppManagerAttributes(
    sendStanza: (_) async => null,
    sendNonza: (_) {},
    getManagerById: <T extends mox.XmppManagerBase>(String id) {
      if (id == mox.pubsubManager) {
        return pubSubManager as T;
      }
      return null;
    },
    sendEvent: (_) {},
    getConnectionSettings: () =>
        mox.ConnectionSettings(jid: fullJid, password: password),
    getFullJID: () => fullJid,
    getSocket: () => throw UnimplementedError(),
    getConnection: () => throw UnimplementedError(),
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );
}

bool compareMessages(Message a, Message b) =>
    a.stanzaID == b.stanzaID &&
    a.senderJid == b.senderJid &&
    a.senderRealJid == b.senderRealJid &&
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

  group('draft autosave preference', () {
    test('updates the local draft without changing draft content', () async {
      when(() => mockStateStore.read(key: any(named: 'key'))).thenReturn(null);
      await connectSuccessfully(xmppService);
      final draftId = await database.saveDraft(
        jids: const ['peer@axi.im'],
        body: 'Saved body',
        draftSyncId: 'sync-autosave-toggle',
        draftUpdatedAt: DateTime.utc(2026, 3, 11, 10),
        draftSourceId: 'source',
        draftRecipients: const [],
        subject: 'Saved subject',
      );

      await xmppService.updateDraftAutosaveEnabled(id: draftId, enabled: false);

      final saved = await database.getDraft(draftId);
      expect(saved?.body, 'Saved body');
      expect(saved?.subject, 'Saved subject');
      expect(saved?.autosaveEnabled, isFalse);
    });
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

    test(
      'Selects typed direct and MUC references without losing the kind.',
      () {
        const stanzaId = 'local-stanza-id';
        const originId = 'origin-id';
        const mucStanzaId = 'room-stanza-id';
        final message = Message(
          stanzaID: stanzaId,
          originID: originId,
          mucStanzaId: mucStanzaId,
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.timestamp(),
          body: text,
        );

        final currentDirect = message.outboundReference(isGroupChat: false);
        expect(currentDirect?.kind, MessageReferenceKind.stanzaId);
        expect(currentDirect?.value, stanzaId);

        final preferredDirect = message.outboundReference(
          isGroupChat: false,
          directPolicy: DirectMessageReferencePolicy.preferOriginId,
        );
        expect(preferredDirect?.kind, MessageReferenceKind.originId);
        expect(preferredDirect?.value, originId);

        final mucReference = message.outboundReference(isGroupChat: true);
        expect(mucReference?.kind, MessageReferenceKind.mucStanzaId);
        expect(mucReference?.value, mucStanzaId);
      },
    );

    test(
      'Uses feature-specific message references for direct and MUC chats.',
      () {
        const stanzaId = 'local-stanza-id';
        const originId = 'origin-id';
        const mucStanzaId = 'room-stanza-id';
        final message = Message(
          stanzaID: stanzaId,
          originID: originId,
          mucStanzaId: mucStanzaId,
          senderJid: jid,
          chatJid: jid,
          timestamp: DateTime.timestamp(),
          body: text,
        );

        expect(
          message.markerReference(isGroupChat: false)?.kind,
          MessageReferenceKind.stanzaId,
        );
        expect(
          message.receiptReference(isGroupChat: false)?.kind,
          MessageReferenceKind.stanzaId,
        );
        expect(
          message.replyReference(isGroupChat: false)?.kind,
          MessageReferenceKind.originId,
        );
        expect(
          message.reactionReference(isGroupChat: false)?.kind,
          MessageReferenceKind.originId,
        );
        expect(
          message.collectionReference(isGroupChat: false)?.kind,
          MessageReferenceKind.originId,
        );
        expect(
          message.replyReference(isGroupChat: true)?.kind,
          MessageReferenceKind.mucStanzaId,
        );
        expect(
          message.reactionReference(isGroupChat: true)?.kind,
          MessageReferenceKind.mucStanzaId,
        );
        expect(
          message.markerReference(isGroupChat: true)?.kind,
          MessageReferenceKind.mucStanzaId,
        );
        expect(message.receiptReference(isGroupChat: true), isNull);
      },
    );

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

    test(
      'Given an existing direct chat, sending a message does not publish a conversation index update.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);
        await database.createChat(Chat.fromJid(jid));

        clearInteractions(mockConnection);

        await xmppService.sendMessage(jid: jid, text: text);

        verifyNever(
          () => mockConnection.getManager<ConversationIndexManager>(),
        );
      },
    );

    test(
      'Given a first direct outbound message, publishes a conversation index seed.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);
        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
        clearInteractions(mockConnection);

        await xmppService.sendMessage(jid: jid, text: text);
        await pumpEventQueue();

        final capturedStanzas = verify(
          () => mockConnection.sendStanza(captureAny()),
        ).captured.cast<mox.StanzaDetails>();
        final publishStanza = capturedStanzas
            .map((details) => details.stanza)
            .singleWhere(
              (stanza) =>
                  stanza
                      .firstTag('pubsub', xmlns: mox.pubsubXmlns)
                      ?.firstTag('publish')
                      ?.attributes['node'] ==
                  conversationIndexNode,
            );
        final payload = publishStanza
            .firstTag('pubsub', xmlns: mox.pubsubXmlns)
            ?.firstTag('publish')
            ?.firstTag('item')
            ?.firstTag('conv', xmlns: conversationIndexNode);
        expect(
          payload?.attributes['peer'],
          mox.JID.fromString(jid).toBare().toString(),
        );
        expect(payload?.attributes['last_id'], isNull);
      },
    );

    test(
      'Given a first direct inbound message, publishes a conversation index seed.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);
        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
        clearInteractions(mockConnection);

        const peerJid = 'friend@axi.im';
        const stanzaId = 'first-direct-inbound';
        final event = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('hello'),
            mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
          type: 'chat',
        );

        controller.add(event);
        await pumpEventQueue();
        await pumpEventQueue();

        final capturedStanzas = verify(
          () => mockConnection.sendStanza(captureAny()),
        ).captured.cast<mox.StanzaDetails>();
        final publishStanza = capturedStanzas
            .map((details) => details.stanza)
            .singleWhere(
              (stanza) =>
                  stanza
                      .firstTag('pubsub', xmlns: mox.pubsubXmlns)
                      ?.firstTag('publish')
                      ?.attributes['node'] ==
                  conversationIndexNode,
            );
        final payload = publishStanza
            .firstTag('pubsub', xmlns: mox.pubsubXmlns)
            ?.firstTag('publish')
            ?.firstTag('item')
            ?.firstTag('conv', xmlns: conversationIndexNode);
        expect(payload?.attributes['peer'], peerJid);
        expect(payload?.attributes['last_id'], isNull);

        await controller.close();
      },
    );

    test('Requests delivery receipts on normal direct messages.', () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      await xmppService.sendMessage(jid: jid, text: text);

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>().having(
              (event) => event.extensions
                  .get<mox.MessageDeliveryReceiptData>()
                  ?.receiptRequested,
              'delivery receipt request',
              true,
            ),
          ),
        ),
      ).called(1);
    });

    test('Serializes delivery receipt request XML for outbound messages.', () {
      final nodes = messageDeliveryReceiptRequestSendingCallback(
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          const mox.MessageDeliveryReceiptData(true),
        ]),
      );

      expect(nodes, hasLength(1));
      expect(nodes.single.tag, 'request');
      expect(nodes.single.attributes['xmlns'], mox.deliveryXmlns);
    });

    test('Emits origin-id on normal direct messages.', () async {
      const directStanzaId = 'direct-stanza-id';
      const directOriginId = 'direct-origin-id';

      await connectSuccessfully(xmppService);

      final generatedIds = <String>[directStanzaId, directOriginId].iterator;
      when(() => mockConnection.generateId()).thenAnswer((_) {
        generatedIds.moveNext();
        return generatedIds.current;
      });
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      await xmppService.sendMessage(jid: jid, text: text);

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>().having(
              (event) => event.extensions.get<mox.StableIdData>()?.originId,
              'origin-id',
              directOriginId,
            ),
          ),
        ),
      ).called(1);
    });

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
      'resendMessage preserves forwarded metadata on the resent copy',
      () async {
        await connectSuccessfully(xmppService);

        const originalStanzaId = 'forwarded-original';
        const resentStanzaId = 'forwarded-resent';
        const resentOriginId = 'forwarded-resent-origin';
        final originalMessage = Message(
          stanzaID: originalStanzaId,
          senderJid: jid,
          chatJid: jid,
          body: 'Retry forwarded',
          timestamp: DateTime.timestamp(),
          pseudoMessageData: const <String, dynamic>{
            'forwarded': true,
            'forwardedFromJid': 'sender@example.com',
            'forwardedOriginalSenderLabel': 'Sender',
          },
        );
        await database.saveMessage(originalMessage);

        final generatedIds = <String>[resentStanzaId, resentOriginId].iterator;
        when(() => mockConnection.generateId()).thenAnswer((_) {
          generatedIds.moveNext();
          return generatedIds.current;
        });
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        final resent = await xmppService.resendMessage(originalStanzaId);

        final resentMessage = await database.getMessageByStanzaID(
          resentStanzaId,
        );
        expect(resent, isTrue);
        expect(
          resentMessage,
          isA<Message>()
              .having((message) => message.body, 'body', 'Retry forwarded')
              .having((message) => message.isForwarded, 'isForwarded', true)
              .having(
                (message) => message.forwardedFromJid,
                'forwardedFromJid',
                'sender@example.com',
              )
              .having(
                (message) => message.forwardedOriginalSenderLabel,
                'forwardedOriginalSenderLabel',
                'Sender',
              ),
        );
      },
    );

    test(
      'resendMessage returns false when the original message is missing',
      () async {
        await connectSuccessfully(xmppService);

        final resent = await xmppService.resendMessage('missing-original');

        expect(resent, isFalse);
      },
    );

    test(
      'Repairs stale MUC chat typing before sending a bare room message.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
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
      'Sends with current MUC self presence when manager state is stale.',
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

    test(
      'Stores and fails a MUC text message when send preparation fails.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        when(
          () => mucManager.getRoomState(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenThrow(Exception('join failed'));
        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
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

        await expectLater(
          xmppService.sendMessage(
            jid: roomJid,
            text: text,
            chatType: ChatType.groupChat,
          ),
          throwsA(isA<XmppMessageException>()),
        );

        final messages = await database.getChatMessages(
          roomJid,
          start: 0,
          end: 10,
        );
        expect(messages, hasLength(1));
        expect(messages.single.body, text);
        expect(messages.single.error, MessageError.unknown);
        verifyNever(() => mockConnection.sendMessage(any()));
      },
    );

    test(
      'Stores and fails a MUC attachment when send preparation fails.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        const fileName = 'failed-prepare.txt';
        final attachment = Attachment(
          path: '/tmp/$fileName',
          fileName: fileName,
          sizeBytes: 12,
          mimeType: 'text/plain',
        );
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        when(
          () => mucManager.getRoomState(any()),
        ).thenAnswer((_) async => null);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenThrow(Exception('join failed'));
        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
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

        await expectLater(
          xmppService.sendAttachment(
            jid: roomJid,
            attachment: attachment,
            chatType: ChatType.groupChat,
          ),
          throwsA(isA<XmppMessageException>()),
        );

        final messages = await database.getChatMessages(
          roomJid,
          start: 0,
          end: 10,
        );
        expect(messages, hasLength(1));
        expect(messages.single.fileMetadataID, isNotNull);
        expect(messages.single.error, MessageError.unknown);
        verifyNever(() => mockConnection.sendMessage(any()));
        verifyNever(() => mockConnection.sendStanza(any()));
      },
    );

    test(
      'Refreshes the stored outbound MUC identity after preparation changes nick.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const oldNick = 'old';
        const newNick = 'new';
        const body = 'nick changed during prepare';
        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: false,
          nick: oldNick,
        );
        when(
          () => mucManager.getRoomState(any()),
        ).thenAnswer((_) async => managerRoomState);
        when(
          () => mucManager.joinRoom(
            any(),
            any(),
            maxHistoryStanzas: any(named: 'maxHistoryStanzas'),
          ),
        ).thenAnswer((_) async {
          managerRoomState
            ..joined = true
            ..nick = newNick;
          xmppService.updateOccupantFromPresence(
            roomJid: roomJid,
            occupantId: '$roomJid/$newNick',
            nick: newNick,
            realJid: xmppService.myJid,
            affiliation: OccupantAffiliation.member,
            role: OccupantRole.participant,
            isPresent: true,
            fromPresence: true,
          );
          return const moxlib.Result<bool, mox.MUCError>(true);
        });
        when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: oldNick,
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );

        await xmppService.sendMessage(
          jid: roomJid,
          text: body,
          chatType: ChatType.groupChat,
        );

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>().having(
                (event) => event.from.toString(),
                'from',
                '$roomJid/$newNick',
              ),
            ),
          ),
        ).called(1);
        final messages = await database.getChatMessages(
          roomJid,
          start: 0,
          end: 10,
        );
        expect(messages, hasLength(1));
        expect(messages.single.senderJid, '$roomJid/$newNick');
        expect(messages.single.senderRealJid, xmppService.myJid);
      },
    );

    test('Uses origin-id for direct replies.', () async {
      const peerJid = 'friend@axi.im';
      const quotedStanzaId = 'quoted-local-stanza-id';
      const quotedOriginId = 'quoted-origin-id';
      const quotedBody = 'quoted';
      const replyBody = 'reply';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.generateId()).thenAnswer((_) => uuid.v4());
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      final quotedMessage = Message(
        stanzaID: quotedStanzaId,
        originID: quotedOriginId,
        senderJid: peerJid,
        chatJid: peerJid,
        timestamp: DateTime.timestamp(),
        body: quotedBody,
      );
      await database.saveMessage(quotedMessage);

      await xmppService.sendMessage(
        jid: peerJid,
        text: replyBody,
        quotedMessage: quotedMessage,
        chatType: ChatType.chat,
      );

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>()
                .having((event) => event.type, 'type', 'chat')
                .having(
                  (event) => event.extensions.get<mox.ReplyData>()?.id,
                  'reply target',
                  quotedOriginId,
                )
                .having((event) => event.text, 'text', replyBody),
          ),
        ),
      ).called(1);

      final messages = await database.getChatMessages(
        peerJid,
        start: 0,
        end: 10,
      );
      final reply = messages.firstWhere((message) => message.body == replyBody);
      expect(reply.quoting, quotedOriginId);
      expect(reply.quotingReferenceKind, MessageReferenceKind.originId);
    });

    test('Uses room stanza-id for MUC replies.', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const quotedStanzaId = 'quoted-local-stanza-id';
      const quotedMucStanzaId = 'quoted-room-stanza-id';
      const quotedBody = 'quoted';
      const replyBody = 'reply';

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
      final quotedMessage = Message(
        stanzaID: quotedStanzaId,
        mucStanzaId: quotedMucStanzaId,
        senderJid: occupantId,
        occupantID: occupantId,
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: quotedBody,
      );
      await database.saveMessage(
        quotedMessage,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
        fromPresence: true,
      );

      await xmppService.sendMessage(
        jid: roomJid,
        text: replyBody,
        quotedMessage: quotedMessage,
        chatType: ChatType.groupChat,
      );

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>()
                .having((event) => event.type, 'type', 'groupchat')
                .having(
                  (event) => event.extensions.get<mox.ReplyData>()?.id,
                  'reply target',
                  quotedMucStanzaId,
                )
                .having((event) => event.text, 'text', replyBody),
          ),
        ),
      ).called(1);

      final messages = await database.getChatMessages(
        roomJid,
        start: 0,
        end: 10,
      );
      final reply = messages.firstWhere((message) => message.body == replyBody);
      expect(reply.quoting, quotedMucStanzaId);
      expect(reply.quotingReferenceKind, MessageReferenceKind.mucStanzaId);
    });

    test(
      'Allows MUC replies to self messages stored with opaque occupant ids.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        const opaqueOccupantId = 'occupant-id-self';
        const quotedStanzaId = 'quoted-local-stanza-id';
        const quotedMucStanzaId = 'quoted-room-stanza-id';
        const quotedBody = 'quoted';
        const replyBody = 'reply';

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: true,
          nick: roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
        ).thenAnswer((_) async => managerRoomState);
        when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
        final quotedMessage = Message(
          stanzaID: quotedStanzaId,
          mucStanzaId: quotedMucStanzaId,
          senderJid: opaqueOccupantId,
          occupantID: opaqueOccupantId,
          chatJid: roomJid,
          timestamp: DateTime.timestamp(),
          body: quotedBody,
        );
        await database.saveMessage(
          quotedMessage,
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: opaqueOccupantId,
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.sendMessage(
          jid: roomJid,
          text: replyBody,
          quotedMessage: quotedMessage,
          chatType: ChatType.groupChat,
        );

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having((event) => event.type, 'type', 'groupchat')
                  .having(
                    (event) => event.extensions.get<mox.ReplyData>()?.id,
                    'reply target',
                    quotedMucStanzaId,
                  )
                  .having((event) => event.text, 'text', replyBody),
            ),
          ),
        ).called(1);
      },
    );

    test(
      'Stores opaque self occupant ids separately from sender JIDs for MUC sends',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        const opaqueOccupantId = 'occupant-id-self';
        const replyBody = 'hello';

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: true,
          nick: roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
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
          occupantId: opaqueOccupantId,
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        await xmppService.sendMessage(
          jid: roomJid,
          text: replyBody,
          chatType: ChatType.groupChat,
        );

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>().having(
                (event) => event.from.toString(),
                'from',
                '$roomJid/$roomNick',
              ),
            ),
          ),
        ).called(1);

        final messages = await database.getChatMessages(
          roomJid,
          start: 0,
          end: 10,
        );
        final stored = messages.firstWhere(
          (message) => message.body == replyBody,
        );
        expect(stored.senderJid, equals('$roomJid/$roomNick'));
        expect(stored.senderRealJid, equals(xmppService.myJid));
        expect(stored.occupantID, equals(opaqueOccupantId));
      },
    );

    test('Stores known inbound MUC sender real JIDs', () async {
      const roomJid = 'room@conference.axi.im';
      const senderNick = 'friend';
      const senderRealJid = 'friend@axi.im';
      const body = 'hello from a known occupant';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: '$roomJid/$senderNick',
        nick: senderNick,
        realJid: senderRealJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString('$roomJid/$senderNick'),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData(body),
            mox.MessageIdData('known-muc-sender-stanza'),
          ]),
          id: 'known-muc-sender-stanza',
          type: 'groupchat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(
        'known-muc-sender-stanza',
      );
      expect(stored?.senderJid, '$roomJid/$senderNick');
      expect(stored?.senderRealJid, senderRealJid);
      expect(stored?.occupantID, isNull);
      await controller.close();
    });

    test(
      'Does not store MUC real JID from same-nick occupant lookup',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderRealJid = 'friend@axi.im';
        const body = 'hello from reused nick';
        const stanzaId = 'same-nick-muc-sender-stanza';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: 'opaque-occupant-id',
          nick: senderNick,
          realJid: senderRealJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString('$roomJid/$senderNick'),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData(body),
              mox.MessageIdData(stanzaId),
            ]),
            id: stanzaId,
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.senderJid, '$roomJid/$senderNick');
        expect(stored?.senderRealJid, isNull);
        await controller.close();
      },
    );

    test('MAM replay matches stored MUC messages by room stanza-id', () async {
      const roomJid = 'room@conference.axi.im';
      const mucStanzaId = 'room-stable-message-id';
      const localStanzaId = 'local-muc-stanza-id';
      const archivedStanzaId = 'archived-muc-stanza-id';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      await database.saveMessage(
        Message(
          stanzaID: localStanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: '$roomJid/old',
          senderRealJid: xmppService.myJid,
          chatJid: roomJid,
          timestamp: DateTime.utc(2026, 1, 1, 10),
          body: 'local copy',
        ),
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString('$roomJid/old'),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('archived copy'),
            mox.MessageIdData(archivedStanzaId),
            mox.StableIdData(null, [
              mox.StanzaId(mucStanzaId, mox.JID.fromString(roomJid)),
            ]),
          ]),
          id: archivedStanzaId,
          type: 'groupchat',
          isFromMAM: true,
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final messages = await database.getChatMessages(
        roomJid,
        start: 0,
        end: 10,
      );
      final stored = await database.getMessageByStanzaID(localStanzaId);
      final replay = await database.getMessageByStanzaID(archivedStanzaId);
      expect(messages, hasLength(1));
      expect(stored?.senderRealJid, xmppService.myJid);
      expect(stored?.acked, isTrue);
      expect(replay, isNull);
      await controller.close();
    });

    test(
      'MAM replay does not hydrate MUC real JID from room state occupant id',
      () async {
        const roomJid = 'room@conference.axi.im';
        const mucStanzaId = 'room-stable-occupant-id-message';
        const localStanzaId = 'local-occupant-id-message';
        const archivedStanzaId = 'archived-occupant-id-message';
        const occupantId = 'opaque-self-occupant';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: occupantId,
          nick: 'old',
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );
        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            mucStanzaId: mucStanzaId,
            occupantID: occupantId,
            senderJid: '$roomJid/old',
            chatJid: roomJid,
            timestamp: DateTime.utc(2026, 1, 1, 10),
            body: 'legacy local copy',
          ),
          chatType: ChatType.groupChat,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString('$roomJid/old'),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('archived copy'),
              const mox.OccupantIdData(occupantId),
              mox.MessageIdData(archivedStanzaId),
              mox.StableIdData(null, [
                mox.StanzaId(mucStanzaId, mox.JID.fromString(roomJid)),
              ]),
            ]),
            id: archivedStanzaId,
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        final replay = await database.getMessageByStanzaID(archivedStanzaId);
        expect(stored?.senderRealJid, isNull);
        expect(replay, isNull);
        await controller.close();
      },
    );

    test('MAM replay does not infer MUC real JID from reused nick', () async {
      const roomJid = 'room@conference.axi.im';
      const mucStanzaId = 'room-stable-reused-nick-message';
      const localStanzaId = 'local-reused-nick-message';
      const archivedStanzaId = 'archived-reused-nick-message';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: '$roomJid/old',
        nick: 'old',
        realJid: 'other@axi.im',
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
      );
      await database.saveMessage(
        Message(
          stanzaID: localStanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: '$roomJid/old',
          chatJid: roomJid,
          timestamp: DateTime.utc(2026, 1, 1, 10),
          body: 'legacy local copy',
        ),
        chatType: ChatType.groupChat,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString('$roomJid/old'),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('archived copy'),
            mox.MessageIdData(archivedStanzaId),
            mox.StableIdData(null, [
              mox.StanzaId(mucStanzaId, mox.JID.fromString(roomJid)),
            ]),
          ]),
          id: archivedStanzaId,
          type: 'groupchat',
          isFromMAM: true,
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(localStanzaId);
      final replay = await database.getMessageByStanzaID(archivedStanzaId);
      expect(stored?.senderRealJid, isNull);
      expect(replay, isNull);
      await controller.close();
    });

    test(
      'MAM replay does not infer MUC real JID from current self nick',
      () async {
        const roomJid = 'room@conference.axi.im';
        const currentNick = 'current';
        const mucStanzaId = 'room-stable-current-self-nick-message';
        const localStanzaId = 'local-current-self-nick-message';
        const archivedStanzaId = 'archived-current-self-nick-message';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: '$roomJid/$currentNick',
          nick: currentNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
        );
        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: '$roomJid/$currentNick',
            chatJid: roomJid,
            timestamp: DateTime.utc(2026, 1, 1, 10),
            body: 'legacy local copy',
          ),
          chatType: ChatType.groupChat,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString('$roomJid/$currentNick'),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('archived copy'),
              mox.MessageIdData(archivedStanzaId),
              mox.StableIdData(null, [
                mox.StanzaId(mucStanzaId, mox.JID.fromString(roomJid)),
              ]),
            ]),
            id: archivedStanzaId,
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        final replay = await database.getMessageByStanzaID(archivedStanzaId);
        expect(stored?.senderRealJid, isNull);
        expect(replay, isNull);
        await controller.close();
      },
    );

    test('Rejects MUC replies without a room stanza-id.', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const quotedStanzaId = 'quoted-local-stanza-id';
      const quotedBody = 'quoted';
      const replyBody = 'reply';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
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
      final quotedMessage = Message(
        stanzaID: quotedStanzaId,
        senderJid: occupantId,
        occupantID: occupantId,
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: quotedBody,
      );
      await database.saveMessage(
        quotedMessage,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );

      await expectLater(
        () => xmppService.sendMessage(
          jid: roomJid,
          text: replyBody,
          quotedMessage: quotedMessage,
          chatType: ChatType.groupChat,
        ),
        throwsA(isA<XmppMessageException>()),
      );

      verifyNever(() => mockConnection.sendMessage(any()));
    });
  });

  group('reaction namespace normalization', () {
    const sameDomainJid = 'friend@axi.im';
    const emoji = '\u{1F44D}';

    test('adds the reactions namespace to bare reaction payloads', () {
      final stanza = mox.Stanza.message(
        from: sameDomainJid,
        to: jid,
        type: 'chat',
        id: 'reaction-message',
        children: [
          mox.XMLNode(
            tag: 'reactions',
            attributes: const {'id': 'target-message'},
            children: [mox.XMLNode(tag: 'reaction', text: emoji)],
          ),
        ],
      );

      final normalized = normalizeReactionNamespace(stanza);

      expect(normalized, isTrue);
      expect(
        stanza.firstTag('reactions', xmlns: mox.messageReactionsXmlns),
        isNotNull,
      );
    });

    test('does not rewrite already namespaced reaction payloads', () {
      final stanza = mox.Stanza.message(
        from: sameDomainJid,
        to: jid,
        type: 'chat',
        id: 'reaction-message',
        children: [
          mox.XMLNode.xmlns(
            tag: 'reactions',
            xmlns: mox.messageReactionsXmlns,
            attributes: const {'id': 'target-message'},
            children: [mox.XMLNode(tag: 'reaction', text: emoji)],
          ),
        ],
      );

      final normalized = normalizeReactionNamespace(stanza);

      expect(normalized, isFalse);
      expect(
        stanza.firstTag('reactions', xmlns: mox.messageReactionsXmlns),
        isNotNull,
      );
    });
  });

  group('reactToMessage', () {
    const sameDomainJid = 'friend@axi.im';
    const emoji = '\u{1F44D}';

    test('Uses origin-id for direct reactions.', () async {
      const stanzaId = 'same-domain-reaction-stanza-id';
      const originId = 'same-domain-reaction-origin-id';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

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

      await xmppService.reactToMessage(stanzaID: stanzaId, emoji: emoji);

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>().having(
              (event) =>
                  event.extensions.get<mox.MessageReactionsData>()?.messageId,
              'reaction target',
              originId,
            ),
          ),
        ),
      ).called(1);
    });

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
            that: isA<mox.MessageEvent>()
                .having(
                  (event) => event.extensions
                      .get<mox.MessageReactionsData>()
                      ?.messageId,
                  'reaction target',
                  stanzaId,
                )
                .having(
                  (event) => event.extensions
                      .get<mox.MessageProcessingHintData>()
                      ?.hints,
                  'processing hints',
                  contains(mox.MessageProcessingHint.store),
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

    test('Allows direct reactions without capability lookups', () async {
      const peerJid = 'friend@example.net';
      const stanzaId = 'unknown-domain-reaction';
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

      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: peerJid,
          chatJid: peerJid,
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
      verifyNever(() => mockConnection.discoInfoQuery(peerJid));
    });

    test('Sends MUC reactions as groupchat stanzas', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const stanzaId = 'muc-reaction-target';
      const mucStanzaId = 'room-stable-stanza-id';

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: '$roomJid/$roomNick',
          chatJid: roomJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        ),
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
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

      await xmppService.reactToMessage(stanzaID: stanzaId, emoji: emoji);

      final sentEvent =
          verify(() => mockConnection.sendMessage(captureAny())).captured.single
              as mox.MessageEvent;
      expect(sentEvent.type, 'groupchat');
      expect(
        sentEvent.extensions.get<mox.MessageReactionsData>()?.messageId,
        mucStanzaId,
      );
      expect(sentEvent.to.toBare().toString(), roomJid);
      expect(sentEvent.extensions.get<mox.MessageIdData>()?.id, isNotEmpty);
    });

    test('Does not send MUC reactions without a room stanza-id', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const stanzaId = 'muc-reaction-target-missing-stable-id';

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: '$roomJid/$roomNick',
          chatJid: roomJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        ),
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
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

      await xmppService.reactToMessage(stanzaID: stanzaId, emoji: emoji);

      verifyNever(() => mockConnection.sendMessage(any()));
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

    test(
      'Queues direct reactions until the target message is stored',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        const stanzaId = 'stored-later-stanza-id';
        const originId = 'stored-later-origin-id';

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(sameDomainJid),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(originId, <String>[emoji]),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        expect(await database.getMessageByStanzaID(stanzaId), isNull);

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(sameDomainJid),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('hello'),
              const mox.StableIdData(originId, null),
            ]),
            id: stanzaId,
            type: 'chat',
          ),
        );
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

    test('Rejects direct reactions from unrelated senders', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      const stanzaId = 'stored-stanza-id';
      const originId = 'stable-origin-id';
      const unauthorizedSender = 'intruder@axi.im';
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

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(unauthorizedSender),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageReactionsData(originId, <String>[emoji]),
          ]),
          id: uuid.v4(),
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final reactions = await database.getReactionsForMessageSender(
        messageId: stanzaId,
        senderJid: unauthorizedSender,
      );
      expect(reactions, isEmpty);

      await controller.close();
    });

    test('Ignores stale delayed direct reaction updates', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      const stanzaId = 'stored-stanza-id';
      const originId = 'stable-origin-id';
      const newerEmoji = '\u{1F44D}';
      const staleEmoji = '\u{1F525}';
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
      await database.replaceReactions(
        messageId: stanzaId,
        senderJid: sameDomainJid,
        emojis: const [newerEmoji],
        updatedAt: DateTime.utc(2026, 3, 10, 12),
        identityVerified: true,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(sameDomainJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageReactionsData(originId, <String>[staleEmoji]),
            mox.DelayedDeliveryData(
              mox.JID.fromString(sameDomainJid),
              DateTime.utc(2026, 3, 9, 12),
            ),
          ]),
          id: uuid.v4(),
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final reactions = await database.getReactionsForMessageSender(
        messageId: stanzaId,
        senderJid: sameDomainJid,
      );
      expect(
        reactions.map((reaction) => reaction.emoji).toList(),
        equals(const <String>[newerEmoji]),
      );

      await controller.close();
    });

    test(
      'Applies inbound MUC reactions when the target matches room stanza-id',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderOccupantId = '$roomJid/$senderNick';
        const senderRealJid = 'friend@axi.im';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';

        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: true,
          nick: 'me',
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
        ).thenAnswer((_) async => managerRoomState);
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            occupantID: senderOccupantId,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          realJid: senderRealJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        final reactionEvent = mox.MessageEvent(
          mox.JID.fromString(senderOccupantId),
          mox.JID.fromString(roomJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageReactionsData(mucStanzaId, <String>[emoji]),
          ]),
          id: uuid.v4(),
          type: 'groupchat',
        );

        controller.add(reactionEvent);
        await pumpEventQueue();
        await pumpEventQueue();

        final reactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderRealJid,
        );
        expect(
          reactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[emoji]),
        );

        await controller.close();
      },
    );

    test(
      'Keeps archived MUC reactions unverified when only room state matches',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderOccupantId = '$roomJid/$senderNick';
        const senderRealJid = 'friend@axi.im';
        const stanzaId = 'stored-archived-reaction-muc-stanza-id';
        const mucStanzaId = 'archived-reaction-room-stanza-id';

        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            occupantID: senderOccupantId,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          realJid: senderRealJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(mucStanzaId, <String>[emoji]),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final canonicalReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderRealJid,
        );
        expect(canonicalReactions, isEmpty);
        final rawReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderOccupantId,
        );
        expect(
          rawReactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[emoji]),
        );
        final state = await database.getReactionState(
          messageId: stanzaId,
          senderJid: senderOccupantId,
        );
        expect(state?.identityVerified, isFalse);

        await controller.close();
      },
    );

    test('Stores new MUC reactions without verified sender identity', () async {
      const roomJid = 'room@conference.axi.im';
      const senderNick = 'friend';
      const senderOccupantId = '$roomJid/friend';
      const stanzaId = 'stored-muc-stanza-id';
      const mucStanzaId = 'room-stanza-id';

      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      await database.createChat(
        Chat(
          jid: roomJid,
          title: 'Room',
          type: ChatType.groupChat,
          myNickname: 'me',
          lastChangeTimestamp: DateTime.timestamp(),
          contactJid: roomJid,
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: senderOccupantId,
          occupantID: senderOccupantId,
          chatJid: roomJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        ),
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: senderOccupantId,
        nick: senderNick,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
        fromPresence: true,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(senderOccupantId),
          mox.JID.fromString(roomJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageReactionsData(mucStanzaId, <String>[emoji]),
          ]),
          id: uuid.v4(),
          type: 'groupchat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final reactions = await database.getReactionsForMessageSender(
        messageId: stanzaId,
        senderJid: senderOccupantId,
      );
      expect(
        reactions.map((reaction) => reaction.emoji).toList(),
        equals(const <String>[emoji]),
      );
      final state = await database.getReactionState(
        messageId: stanzaId,
        senderJid: senderOccupantId,
      );
      expect(state, isNotNull);
      expect(state?.identityVerified, isFalse);

      await controller.close();
    });

    test(
      'Allows MUC reaction updates from the same unresolved occupant once continuity exists',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderOccupantId = '$roomJid/friend';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';
        const updatedEmoji = '\u{1F525}';

        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            occupantID: senderOccupantId,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        await database.replaceReactions(
          messageId: stanzaId,
          senderJid: senderOccupantId,
          emojis: const [emoji],
          updatedAt: DateTime.utc(2026, 3, 10, 12),
          identityVerified: false,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(mucStanzaId, <String>[
                updatedEmoji,
              ]),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final reactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderOccupantId,
        );
        expect(
          reactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[updatedEmoji]),
        );

        await controller.close();
      },
    );

    test(
      'Tracks MUC reaction continuity by real JID across nick changes',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderJid = 'friend@axi.im';
        const oldSenderNick = 'friend';
        const newSenderNick = 'friend-renamed';
        const oldSenderOccupantJid = '$roomJid/$oldSenderNick';
        const newSenderOccupantJid = '$roomJid/$newSenderNick';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';
        const updatedEmoji = '\u{1F525}';

        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: oldSenderOccupantJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: oldSenderOccupantJid,
          nick: oldSenderNick,
          realJid: senderJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(oldSenderOccupantJid),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(mucStanzaId, <String>[emoji]),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: newSenderOccupantJid,
          nick: newSenderNick,
          realJid: senderJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(newSenderOccupantJid),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(mucStanzaId, <String>[
                updatedEmoji,
              ]),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final reactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderJid,
        );
        final oldNickReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: oldSenderOccupantJid,
        );
        final newNickReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: newSenderOccupantJid,
        );
        expect(
          reactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[updatedEmoji]),
        );
        expect(oldNickReactions, isEmpty);
        expect(newNickReactions, isEmpty);

        await controller.close();
      },
    );

    test(
      'Clears stale room nick reaction aliases when a MUC sender resolves to a real JID',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderJid = 'friend@axi.im';
        const senderNick = 'friend';
        const senderOccupantJid = '$roomJid/$senderNick';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';
        const updatedEmoji = '\u{1F525}';

        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantJid,
          nick: senderNick,
          realJid: senderJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        await database.replaceReactions(
          messageId: stanzaId,
          senderJid: senderOccupantJid,
          emojis: const [emoji],
          updatedAt: DateTime.utc(2026, 3, 10, 12),
          identityVerified: false,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantJid),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageReactionsData(mucStanzaId, <String>[
                updatedEmoji,
              ]),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final verifiedReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderJid,
        );
        final nickAliasReactions = await database.getReactionsForMessageSender(
          messageId: stanzaId,
          senderJid: senderOccupantJid,
        );

        expect(
          verifiedReactions.map((reaction) => reaction.emoji).toList(),
          equals(const <String>[updatedEmoji]),
        );
        expect(nickAliasReactions, isEmpty);

        await controller.close();
      },
    );
  });

  group('sendReadMarker', () {
    test('Allows bare-JID read markers when support is unknown', () async {
      const peerJid = 'friend@example.net';
      const stanzaId = 'bare-read-marker';
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

      await xmppService.sendReadMarker(peerJid, stanzaId);

      verify(
        () => mockConnection.sendChatMarker(
          to: peerJid,
          stanzaID: stanzaId,
          marker: mox.ChatMarker.displayed,
          messageType: 'chat',
        ),
      ).called(1);
      verifyNever(() => mockConnection.discoInfoQuery(peerJid));
    });

    test('Allows full-JID read markers without capability lookups', () async {
      const peerJid = 'friend@example.net/phone';
      const stanzaId = 'full-read-marker';
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

      await xmppService.sendReadMarker(peerJid, stanzaId);

      verify(
        () => mockConnection.sendChatMarker(
          to: peerJid,
          stanzaID: stanzaId,
          marker: mox.ChatMarker.displayed,
          messageType: 'chat',
        ),
      ).called(1);
      verifyNever(() => mockConnection.discoInfoQuery(peerJid));
    });

    test(
      'Uses stanza-id for direct read markers even when origin-id exists',
      () async {
        const peerJid = 'friend@example.net';
        const stanzaId = 'bare-read-marker';
        const originId = 'bare-read-marker-origin';
        await connectSuccessfully(xmppService);
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );
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

        await xmppService.sendReadMarker(peerJid, stanzaId);

        verify(
          () => mockConnection.sendChatMarker(
            to: peerJid,
            stanzaID: stanzaId,
            marker: mox.ChatMarker.displayed,
            messageType: 'chat',
          ),
        ).called(1);
      },
    );

    test(
      'Retries only the latest queued read marker after negotiation',
      () async {
        const peerJid = 'friend@example.net';
        const olderStanzaId = 'older-read-marker';
        const latestStanzaId = 'latest-read-marker';
        final controller = StreamController<mox.XmppEvent>.broadcast();
        final sentStanzaIds = <String>[];
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((invocation) async {
          sentStanzaIds.add(invocation.namedArguments[#stanzaID] as String);
          return sentStanzaIds.length == 3;
        });

        await connectSuccessfully(xmppService);

        await xmppService.sendReadMarker(peerJid, olderStanzaId);
        await xmppService.sendReadMarker(peerJid, latestStanzaId);
        controller.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        await xmppService.setMamSupportOverride(false);
        await xmppService.runBootstrapOperations(
          XmppBootstrapTrigger.resumedNegotiation,
        );

        expect(sentStanzaIds, <String>[
          olderStanzaId,
          latestStanzaId,
          latestStanzaId,
        ]);

        await controller.close();
      },
    );

    test(
      'Clears stale queued read markers after a newer immediate send succeeds',
      () async {
        const peerJid = 'friend@example.net';
        const olderStanzaId = 'older-read-marker';
        const latestStanzaId = 'latest-read-marker';
        final controller = StreamController<mox.XmppEvent>.broadcast();
        final sentStanzaIds = <String>[];
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((invocation) async {
          sentStanzaIds.add(invocation.namedArguments[#stanzaID] as String);
          return sentStanzaIds.length > 1;
        });

        await connectSuccessfully(xmppService);

        await xmppService.sendReadMarker(peerJid, olderStanzaId);
        await xmppService.sendReadMarker(peerJid, latestStanzaId);
        await xmppService.runBootstrapOperations(
          XmppBootstrapTrigger.resumedNegotiation,
        );

        expect(sentStanzaIds, <String>[olderStanzaId, latestStanzaId]);

        await controller.close();
      },
    );
  });

  group('originID hot paths', () {
    const peerJid = 'friend@axi.im';
    const originId = 'origin-hot-path-id';
    const localStanzaId = 'local-stanza-id';

    test('Collapses duplicate direct self-echoes by origin-id.', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      await database.saveMessage(
        Message(
          stanzaID: localStanzaId,
          originID: originId,
          senderJid: xmppService.myJid!,
          chatJid: peerJid,
          timestamp: DateTime.timestamp(),
          body: 'local',
        ),
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(xmppService.myJid!),
          mox.JID.fromString(peerJid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('self echo'),
            const mox.StableIdData(originId, null),
            mox.MessageIdData('server-stanza-id'),
          ]),
          id: 'server-stanza-id',
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final messages = await database.getChatMessages(
        peerJid,
        start: 0,
        end: 10,
      );
      expect(messages, hasLength(1));
      expect(messages.single.stanzaID, localStanzaId);

      await controller.close();
    });

    test(
      'Does not let a different chat claim a duplicate direct self-echo by origin-id.',
      () async {
        const otherPeerJid = 'other@axi.im';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'other-chat-stanza-id',
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: otherPeerJid,
            timestamp: DateTime.timestamp(),
            body: 'other chat',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(xmppService.myJid!),
            mox.JID.fromString(peerJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('self echo'),
              const mox.StableIdData(originId, null),
              mox.MessageIdData('server-stanza-id'),
            ]),
            id: 'server-stanza-id',
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final peerMessages = await database.getChatMessages(
          peerJid,
          start: 0,
          end: 10,
        );
        final otherMessages = await database.getChatMessages(
          otherPeerJid,
          start: 0,
          end: 10,
        );
        expect(peerMessages, hasLength(1));
        expect(otherMessages, hasLength(1));

        await controller.close();
      },
    );

    test(
      'Applies delivery receipts to outgoing direct messages by origin-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        controller.add(
          mox.DeliveryReceiptReceivedEvent(
            from: mox.JID.fromString(peerJid),
            id: originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);

        await controller.close();
      },
    );

    test(
      'Keeps delivery receipts scoped to the sender chat when origin-id collides.',
      () async {
        const otherPeerJid = 'other@axi.im';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'peer',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: 'other-chat-stanza-id',
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: otherPeerJid,
            timestamp: DateTime.timestamp(),
            body: 'other',
          ),
        );

        controller.add(
          mox.DeliveryReceiptReceivedEvent(
            from: mox.JID.fromString(peerJid),
            id: originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final peerStored = await database.getMessageByStanzaID(localStanzaId);
        final otherStored = await database.getMessageByStanzaID(
          'other-chat-stanza-id',
        );
        expect(peerStored?.acked, isTrue);
        expect(peerStored?.received, isTrue);
        expect(otherStored?.acked, isFalse);
        expect(otherStored?.received, isFalse);

        await controller.close();
      },
    );

    test(
      'Applies chat markers to outgoing direct messages by origin-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        controller.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(peerJid),
            mox.ChatMarker.displayed,
            originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(stored?.displayed, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies archived peer chat markers to outgoing direct messages.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'older-outgoing',
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 11, 59),
            body: 'older',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'latest',
          ),
        );

        controller.add(
          XmppTransportChatMarkerEvent(
            from: mox.JID.fromString(peerJid),
            to: mox.JID.fromString(xmppService.myJid!),
            type: mox.ChatMarker.displayed,
            id: originId,
            isCarbon: false,
            isFromMAM: true,
            messageType: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final older = await database.getMessageByStanzaID('older-outgoing');
        final latest = await database.getMessageByStanzaID(localStanzaId);
        expect(older?.acked, isTrue);
        expect(older?.received, isTrue);
        expect(older?.displayed, isTrue);
        expect(latest?.acked, isTrue);
        expect(latest?.received, isTrue);
        expect(latest?.displayed, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies delayed peer chat markers to outgoing direct messages.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'latest',
          ),
        );

        controller.add(
          XmppTransportChatMarkerEvent(
            from: mox.JID.fromString(peerJid),
            to: mox.JID.fromString(xmppService.myJid!),
            type: mox.ChatMarker.displayed,
            id: originId,
            isCarbon: false,
            isFromMAM: false,
            isDelayed: true,
            messageType: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(stored?.displayed, isTrue);

        await controller.close();
      },
    );

    test(
      'Does not treat acknowledged chat markers as displayed reads.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        controller.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(peerJid),
            mox.ChatMarker.acknowledged,
            originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(stored?.displayed, isFalse);

        await controller.close();
      },
    );

    test(
      'Applies received chat markers through the referenced outgoing message.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'older-outgoing',
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 11, 59),
            body: 'older',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'latest',
          ),
        );

        controller.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(peerJid),
            mox.ChatMarker.received,
            originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final older = await database.getMessageByStanzaID('older-outgoing');
        final latest = await database.getMessageByStanzaID(localStanzaId);
        expect(older?.acked, isTrue);
        expect(older?.received, isTrue);
        expect(older?.displayed, isFalse);
        expect(latest?.acked, isTrue);
        expect(latest?.received, isTrue);
        expect(latest?.displayed, isFalse);

        await controller.close();
      },
    );

    test(
      'Queues delivery receipts until the referenced outgoing message is stored.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'older-outgoing-receipt',
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 11, 59),
            body: 'older',
          ),
        );

        controller.add(
          mox.DeliveryReceiptReceivedEvent(
            from: mox.JID.fromString(peerJid),
            id: originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'latest',
          ),
        );
        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('trigger pending receipt replay'),
              mox.MessageIdData('trigger-pending-receipt'),
            ]),
            id: 'trigger-pending-receipt',
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final older = await database.getMessageByStanzaID(
          'older-outgoing-receipt',
        );
        final latest = await database.getMessageByStanzaID(localStanzaId);
        expect(older?.acked, isFalse);
        expect(older?.received, isFalse);
        expect(latest?.acked, isTrue);
        expect(latest?.received, isTrue);
        expect(latest?.displayed, isFalse);

        await controller.close();
      },
    );

    test(
      'Queues peer chat markers until the referenced outgoing message is stored.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'older-outgoing-pending-marker',
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 11, 59),
            body: 'older',
          ),
        );

        controller.add(
          mox.ChatMarkerEvent(
            mox.JID.fromString(peerJid),
            mox.ChatMarker.displayed,
            originId,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: xmppService.myJid!,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'latest',
          ),
        );
        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('trigger pending marker replay'),
              mox.MessageIdData('trigger-pending-marker'),
            ]),
            id: 'trigger-pending-marker',
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final older = await database.getMessageByStanzaID(
          'older-outgoing-pending-marker',
        );
        final latest = await database.getMessageByStanzaID(localStanzaId);
        expect(older?.acked, isTrue);
        expect(older?.received, isTrue);
        expect(older?.displayed, isTrue);
        expect(latest?.acked, isTrue);
        expect(latest?.received, isTrue);
        expect(latest?.displayed, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies self carbon displayed markers to inbound direct messages through the anchor.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: 'peer-message-1',
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 0),
            body: 'first',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.utc(2026, 3, 18, 12, 1),
            body: 'second',
          ),
        );

        controller.add(
          XmppTransportChatMarkerEvent(
            from: mox.JID.fromString(xmppService.myJid!),
            to: mox.JID.fromString(peerJid),
            type: mox.ChatMarker.displayed,
            id: originId,
            isCarbon: true,
            isFromMAM: false,
            messageType: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final firstStored = await database.getMessageByStanzaID(
          'peer-message-1',
        );
        final secondStored = await database.getMessageByStanzaID(localStanzaId);
        final chat = await database.getChat(peerJid);
        expect(firstStored?.displayed, isTrue);
        expect(secondStored?.displayed, isTrue);
        expect(chat?.unreadCount, 0);

        await controller.close();
      },
    );

    test(
      'Applies self archived displayed markers after the referenced message arrives.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        controller.add(
          XmppTransportChatMarkerEvent(
            from: mox.JID.fromString(xmppService.myJid!),
            to: mox.JID.fromString(peerJid),
            type: mox.ChatMarker.displayed,
            id: originId,
            isCarbon: false,
            isFromMAM: true,
            messageType: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('late archive message'),
              mox.MessageIdData(localStanzaId),
              const mox.StableIdData(originId, null),
            ]),
            id: localStanzaId,
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        final chat = await database.getChat(peerJid);
        expect(stored?.displayed, isTrue);
        expect(chat?.unreadCount, 0);

        await controller.close();
      },
    );

    test(
      'Keeps self displayed marker replay scoped to the marker destination chat.',
      () async {
        const otherPeerJid = 'other@axi.im';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'peer',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: 'other-chat-stanza-id',
            originID: originId,
            senderJid: otherPeerJid,
            chatJid: otherPeerJid,
            timestamp: DateTime.timestamp(),
            body: 'other',
          ),
        );

        controller.add(
          XmppTransportChatMarkerEvent(
            from: mox.JID.fromString(xmppService.myJid!),
            to: mox.JID.fromString(peerJid),
            type: mox.ChatMarker.displayed,
            id: originId,
            isCarbon: true,
            isFromMAM: false,
            messageType: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final peerStored = await database.getMessageByStanzaID(localStanzaId);
        final otherStored = await database.getMessageByStanzaID(
          'other-chat-stanza-id',
        );
        expect(peerStored?.displayed, isTrue);
        expect(otherStored?.displayed, isFalse);

        await controller.close();
      },
    );

    test(
      'Applies direct corrections when the target matches stanza-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'before',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('after'),
              const mox.LastMessageCorrectionData(localStanzaId),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.body, 'after');
        expect(stored?.edited, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies direct corrections when the target matches origin-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'before',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('after'),
              const mox.LastMessageCorrectionData(originId),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.body, 'after');
        expect(stored?.edited, isTrue);

        await controller.close();
      },
    );

    test(
      'Keeps direct corrections scoped to the sender chat when origin-id collides.',
      () async {
        const otherPeerJid = 'other@axi.im';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'before',
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: 'other-chat-stanza-id',
            originID: originId,
            senderJid: otherPeerJid,
            chatJid: otherPeerJid,
            timestamp: DateTime.timestamp(),
            body: 'other',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('after'),
              const mox.LastMessageCorrectionData(originId),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final peerStored = await database.getMessageByStanzaID(localStanzaId);
        final otherStored = await database.getMessageByStanzaID(
          'other-chat-stanza-id',
        );
        expect(peerStored?.body, 'after');
        expect(otherStored?.body, 'other');

        await controller.close();
      },
    );

    test(
      'Applies direct retractions when the target matches stanza-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageRetractionData(localStanzaId, null),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.retracted, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies direct retractions when the target matches origin-id.',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);

        await database.saveMessage(
          Message(
            stanzaID: localStanzaId,
            originID: originId,
            senderJid: peerJid,
            chatJid: peerJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageRetractionData(originId, null),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(localStanzaId);
        expect(stored?.retracted, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies MUC corrections when the target matches room stanza-id.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderOccupantId = '$roomJid/friend';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            occupantID: senderOccupantId,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'before',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('after'),
              const mox.LastMessageCorrectionData(mucStanzaId),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.body, 'after');
        expect(stored?.edited, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies MUC retractions when the target matches room stanza-id.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderNick = 'friend';
        const senderOccupantId = '$roomJid/friend';
        const stanzaId = 'stored-muc-stanza-id';
        const mucStanzaId = 'room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: 'me',
            lastChangeTimestamp: DateTime.timestamp(),
            contactJid: roomJid,
          ),
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            occupantID: senderOccupantId,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: senderOccupantId,
          nick: senderNick,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(roomJid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageRetractionData(mucStanzaId, null),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.retracted, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies archived MUC corrections with stored real JID on exact room stanza-id and sender match.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderOccupantId = '$roomJid/friend';
        const senderRealJid = 'friend@axi.im';
        const stanzaId = 'stored-archived-muc-correction';
        const mucStanzaId = 'archived-room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            senderRealJid: senderRealJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'before',
          ),
          chatType: ChatType.groupChat,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('after'),
              const mox.LastMessageCorrectionData(mucStanzaId),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.body, 'after');
        expect(stored?.edited, isTrue);

        await controller.close();
      },
    );

    test(
      'Applies archived MUC retractions with stored real JID on exact room stanza-id and sender match.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderOccupantId = '$roomJid/friend';
        const senderRealJid = 'friend@axi.im';
        const stanzaId = 'stored-archived-muc-retraction';
        const mucStanzaId = 'archived-room-retraction-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: senderOccupantId,
            senderRealJid: senderRealJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(senderOccupantId),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              mox.MessageRetractionData(mucStanzaId, null),
              mox.MessageIdData(uuid.v4()),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.retracted, isTrue);

        await controller.close();
      },
    );

    test(
      'Rejects archived MUC mutations with stored real JID on sender mismatch or local-id-only target.',
      () async {
        const roomJid = 'room@conference.axi.im';
        const senderOccupantId = '$roomJid/friend';
        const otherOccupantId = '$roomJid/other';
        const senderRealJid = 'friend@axi.im';
        const localOnlyStanzaId = 'local-only-target-stanza';
        const localOnlyMucStanzaId = 'different-room-stanza-id';
        const senderMismatchStanzaId = 'sender-mismatch-stanza';
        const senderMismatchMucStanzaId = 'sender-mismatch-room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        await database.saveMessage(
          Message(
            stanzaID: localOnlyStanzaId,
            mucStanzaId: localOnlyMucStanzaId,
            senderJid: senderOccupantId,
            senderRealJid: senderRealJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'before local id',
          ),
          chatType: ChatType.groupChat,
        );
        await database.saveMessage(
          Message(
            stanzaID: senderMismatchStanzaId,
            mucStanzaId: senderMismatchMucStanzaId,
            senderJid: senderOccupantId,
            senderRealJid: senderRealJid,
            chatJid: roomJid,
            timestamp: DateTime.timestamp(),
            body: 'before sender mismatch',
          ),
          chatType: ChatType.groupChat,
        );

        controller
          ..add(
            mox.MessageEvent(
              mox.JID.fromString(senderOccupantId),
              mox.JID.fromString(xmppService.myJid!),
              false,
              mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
                const mox.MessageBodyData('bad local id edit'),
                const mox.LastMessageCorrectionData(localOnlyStanzaId),
                mox.MessageIdData(uuid.v4()),
              ]),
              id: uuid.v4(),
              type: 'groupchat',
              isFromMAM: true,
            ),
          )
          ..add(
            mox.MessageEvent(
              mox.JID.fromString(otherOccupantId),
              mox.JID.fromString(xmppService.myJid!),
              false,
              mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
                mox.MessageRetractionData(senderMismatchMucStanzaId, null),
                mox.MessageIdData(uuid.v4()),
              ]),
              id: uuid.v4(),
              type: 'groupchat',
              isFromMAM: true,
            ),
          );
        await pumpEventQueue();
        await pumpEventQueue();

        final localOnlyStored = await database.getMessageByStanzaID(
          localOnlyStanzaId,
        );
        final senderMismatchStored = await database.getMessageByStanzaID(
          senderMismatchStanzaId,
        );
        expect(localOnlyStored?.body, 'before local id');
        expect(localOnlyStored?.edited, isFalse);
        expect(senderMismatchStored?.retracted, isFalse);

        await controller.close();
      },
    );
  });

  group('pinMessage', () {
    test('Uses stanza id as the canonical stored direct pin id', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      const originId = 'direct-origin-id';

      await connectSuccessfully(xmppService);
      final message = Message(
        stanzaID: stanzaId,
        originID: originId,
        senderJid: 'jid@axi.im',
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);

      final pinned = await database.getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: stanzaId,
      );
      expect(pinned?.active, isTrue);
      expect(
        await database.getPinnedMessage(
          chatJid: chatJid,
          messageStanzaId: originId,
        ),
        isNull,
      );
    });

    test('Uses stanza id for direct pins without origin id', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';

      await connectSuccessfully(xmppService);
      final message = Message(
        stanzaID: stanzaId,
        senderJid: 'jid@axi.im',
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);

      final pinned = await database.getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: stanzaId,
      );
      expect(pinned?.active, isTrue);
    });

    test('Allows outbound direct pins for peer-authored messages', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';

      await connectSuccessfully(xmppService);
      final message = Message(
        stanzaID: stanzaId,
        senderJid: chatJid,
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);

      final pinned = await database.getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: stanzaId,
      );
      expect(pinned?.active, isTrue);
    });

    test('Rejects direct pins when any active pin already exists', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      const selfPinnerJid = 'jid@axi.im';
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: stanzaId,
      );

      await connectSuccessfully(xmppService);
      final message = Message(
        stanzaID: stanzaId,
        senderJid: selfPinnerJid,
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );
      await database.applyMessagePinMutation(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: chatJid,
        pinnedAt: DateTime.utc(2026, 5, 26),
        active: true,
        identityVerified: true,
      );

      await expectLater(
        xmppService.pinMessage(chatJid: chatJid, message: message),
        throwsA(isA<XmppPinAlreadyPinnedException>()),
      );

      expect(
        await database.getMessagePin(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
        ),
        isNull,
      );
      verifyNever(() => mockConnection.sendMessage(any()));
    });

    test('Sends direct pin mutation before pinned stream is active', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';

      await connectSuccessfully(xmppService);
      xmppService.setPinSyncActiveForChat(chatJid, active: false);
      when(() => mockConnection.generateId()).thenReturn('pin-mutation-1');
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      final message = Message(
        stanzaID: stanzaId,
        senderJid: 'jid@axi.im',
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);
      await untilCalled(() => mockConnection.sendMessage(any()));

      verify(
        () => mockConnection.sendMessage(
          any(
            that: isA<mox.MessageEvent>()
                .having((event) => event.to.toString(), 'to', chatJid)
                .having(
                  (event) =>
                      event.extensions.get<PinMessageMutationData>()?.messageId,
                  'pin target',
                  stanzaId,
                )
                .having(
                  (event) =>
                      event.extensions.get<PinMessageMutationData>()?.pinned,
                  'pin action',
                  true,
                ),
          ),
        ),
      ).called(1);
    });

    test('Rejects repeat direct pins without queuing another flush', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      final sendCompleter = Completer<bool>();
      var sendAttempts = 0;

      await connectSuccessfully(xmppService);
      xmppService.setPinSyncActiveForChat(chatJid, active: false);
      when(() => mockConnection.generateId()).thenReturn('pin-mutation-1');
      when(() => mockConnection.sendMessage(any())).thenAnswer((_) {
        sendAttempts += 1;
        return sendCompleter.future;
      });

      final message = Message(
        stanzaID: stanzaId,
        senderJid: 'jid@axi.im',
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);
      await untilCalled(() => mockConnection.sendMessage(any()));
      await expectLater(
        xmppService.pinMessage(chatJid: chatJid, message: message),
        throwsA(isA<XmppPinAlreadyPinnedException>()),
      );
      await pumpEventQueue();

      expect(sendAttempts, 1);

      sendCompleter.complete(true);
      await pumpEventQueue();
    });

    test(
      'Sends direct unpin mutation before pinned stream is active',
      () async {
        const chatJid = 'peer@axi.im';
        const stanzaId = 'direct-stanza-id';

        await connectSuccessfully(xmppService);
        xmppService.setPinSyncActiveForChat(chatJid, active: false);
        when(() => mockConnection.generateId()).thenReturn('unpin-mutation-1');
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        final message = Message(
          stanzaID: stanzaId,
          senderJid: 'jid@axi.im',
          chatJid: chatJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        );
        await database.applyMessagePinMutation(
          chatJid: chatJid,
          reference: const MessageReference(
            kind: MessageReferenceKind.stanzaId,
            value: stanzaId,
          ),
          pinnerJid: 'jid@axi.im',
          pinnedAt: DateTime.timestamp(),
          active: true,
          identityVerified: true,
        );

        await xmppService.unpinMessage(chatJid: chatJid, message: message);
        await untilCalled(() => mockConnection.sendMessage(any()));

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having((event) => event.to.toString(), 'to', chatJid)
                  .having(
                    (event) => event.extensions
                        .get<PinMessageMutationData>()
                        ?.messageId,
                    'pin target',
                    stanzaId,
                  )
                  .having(
                    (event) =>
                        event.extensions.get<PinMessageMutationData>()?.pinned,
                    'pin action',
                    false,
                  ),
            ),
          ),
        ).called(1);
      },
    );

    test('Direct self unpin removes the local pinned aggregate', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: stanzaId,
      );

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(false);
      final message = Message(
        stanzaID: stanzaId,
        senderJid: 'jid@axi.im',
        chatJid: chatJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);
      expect(
        await database.getPinnedMessageAggregates(
          chatJid: chatJid,
          selfPinnerJid: 'jid@axi.im',
        ),
        hasLength(1),
      );

      await xmppService.unpinMessage(chatJid: chatJid, message: message);

      final selfPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: 'jid@axi.im',
      );
      expect(
        await database.getPinnedMessageAggregates(
          chatJid: chatJid,
          selfPinnerJid: 'jid@axi.im',
        ),
        isEmpty,
      );
      expect(selfPin?.active, isFalse);
      expect(
        await database.getPinnedMessage(
          chatJid: chatJid,
          messageStanzaId: stanzaId,
        ),
        isNull,
      );
    });

    test('Direct sent message unpin clears the pinned stream', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'sent-direct-stanza-id';
      const originId = 'sent-direct-origin-id';
      var generatedId = 0;

      await connectSuccessfully(xmppService);
      when(() => mockConnection.generateId()).thenAnswer((_) {
        final ids = [stanzaId, originId];
        return ids[generatedId++];
      });
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      await xmppService.sendMessage(jid: chatJid, text: 'hello');
      final sentMessage = await database.getMessageByReferenceId(
        stanzaId,
        chatJid: chatJid,
      );
      expect(sentMessage, isNotNull);
      expect(sentMessage!.senderJid, xmppService.myJid);

      when(() => mockConnection.hasConnectionSettings).thenReturn(false);
      final emissions = <List<PinnedMessageAggregate>>[];
      final subscription = xmppService
          .pinnedMessagesStream(chatJid)
          .listen(emissions.add);
      await pumpEventQueue();

      await xmppService.pinMessage(chatJid: chatJid, message: sentMessage);
      await pumpEventQueue();
      expect(emissions.last, hasLength(1));
      expect(emissions.last.single.messageReferenceId, stanzaId);
      expect(emissions.last.single.pinnedBySelf, isTrue);

      await xmppService.unpinMessage(chatJid: chatJid, message: sentMessage);
      await pumpEventQueue();

      expect(emissions.last, isEmpty);
      await subscription.cancel();
    });

    test('Direct self unpin clears legacy origin-id pin rows', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      const originId = 'direct-origin-id';
      const selfPinnerJid = 'jid@axi.im';
      const stanzaReference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: stanzaId,
      );
      const originReference = MessageReference(
        kind: MessageReferenceKind.originId,
        value: originId,
      );
      final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(false);
      final message = Message(
        stanzaID: stanzaId,
        originID: originId,
        senderJid: selfPinnerJid,
        chatJid: chatJid,
        timestamp: pinnedAt,
        body: 'hello',
      );
      await database.saveMessage(message);
      await database.applyMessagePinMutation(
        chatJid: chatJid,
        reference: stanzaReference,
        pinnerJid: selfPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      await database.applyMessagePinMutation(
        chatJid: chatJid,
        reference: originReference,
        pinnerJid: selfPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );

      await xmppService.unpinMessage(chatJid: chatJid, message: message);

      final stanzaPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: stanzaReference,
        pinnerJid: selfPinnerJid,
      );
      final originPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: originReference,
        pinnerJid: selfPinnerJid,
      );
      expect(stanzaPin?.active, isFalse);
      expect(originPin?.active, isFalse);
      expect(
        await database.getPinnedMessageAggregates(
          chatJid: chatJid,
          selfPinnerJid: selfPinnerJid,
        ),
        isEmpty,
      );
    });

    test(
      'Direct self unpin leaves peer pin rows active for the same target',
      () async {
        const chatJid = 'peer@axi.im';
        const stanzaId = 'direct-stanza-id';
        const selfPinnerJid = 'jid@axi.im';
        final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);
        const reference = MessageReference(
          kind: MessageReferenceKind.stanzaId,
          value: stanzaId,
        );

        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(false);
        final message = Message(
          stanzaID: stanzaId,
          senderJid: selfPinnerJid,
          chatJid: chatJid,
          timestamp: pinnedAt,
          body: 'hello',
        );
        await database.saveMessage(message);
        await database.applyMessagePinMutation(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
          pinnedAt: pinnedAt,
          active: true,
          identityVerified: true,
        );
        await database.applyMessagePinMutation(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: chatJid,
          pinnedAt: pinnedAt,
          active: true,
          identityVerified: false,
        );

        await xmppService.unpinMessage(chatJid: chatJid, message: message);

        final selfPin = await database.getMessagePin(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
        );
        final peerPin = await database.getMessagePin(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: chatJid,
        );
        expect(selfPin?.active, isFalse);
        expect(peerPin?.active, isTrue);
        final aggregates = await database.getPinnedMessageAggregates(
          chatJid: chatJid,
          selfPinnerJid: selfPinnerJid,
        );
        expect(aggregates, hasLength(1));
        expect(aggregates.single.pinCount, 1);
        expect(aggregates.single.pinnedBySelf, isFalse);
      },
    );

    test(
      'Explicit pinned sync retries pending direct mutation without active stream',
      () async {
        const chatJid = 'peer@axi.im';
        const stanzaId = 'direct-stanza-id';
        var generatedId = 0;
        var sendAttempts = 0;

        await connectSuccessfully(xmppService);
        await xmppService.setMamSupportOverride(false);
        xmppService.setPinSyncActiveForChat(chatJid, active: false);
        when(
          () => mockConnection.generateId(),
        ).thenAnswer((_) => 'pin-mutation-${generatedId++}');
        when(() => mockConnection.sendMessage(any())).thenAnswer((_) async {
          sendAttempts += 1;
          return sendAttempts > 1;
        });

        final message = Message(
          stanzaID: stanzaId,
          senderJid: 'jid@axi.im',
          chatJid: chatJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        );

        await xmppService.pinMessage(chatJid: chatJid, message: message);
        await untilCalled(() => mockConnection.sendMessage(any()));

        expect(sendAttempts, 1);

        await xmppService.syncPinnedMessagesForChat(chatJid);

        expect(sendAttempts, 2);
        final sentEvents = verify(
          () => mockConnection.sendMessage(captureAny()),
        ).captured.cast<mox.MessageEvent>().toList();
        expect(
          sentEvents.last.extensions.get<PinMessageMutationData>()?.messageId,
          stanzaId,
        );
        expect(
          sentEvents.last.extensions.get<PinMessageMutationData>()?.pinned,
          isTrue,
        );
      },
    );

    test('Inbound direct unpin only clears the peer pin row', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'direct-stanza-id';
      const selfPinnerJid = 'jid@axi.im';
      final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);
      final peerUnpinnedAt = pinnedAt.add(const Duration(minutes: 1));
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockConnection.sendChatMarker(
          to: any(named: 'to'),
          stanzaID: any(named: 'stanzaID'),
          marker: any(named: 'marker'),
        ),
      ).thenAnswer((_) async => true);

      await connectSuccessfully(xmppService);
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: chatJid,
          chatJid: chatJid,
          timestamp: pinnedAt,
          body: 'hello',
        ),
      );
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: stanzaId,
      );
      await database.applyMessagePinMutation(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: selfPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      await database.applyMessagePinMutation(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: chatJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(chatJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            PinMessageMutationData(
              reference: reference,
              pinned: false,
              timestamp: peerUnpinnedAt,
            ),
          ]),
          id: uuid.v4(),
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final aggregates = await database.getPinnedMessageAggregates(
        chatJid: chatJid,
        selfPinnerJid: selfPinnerJid,
      );
      final selfPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: selfPinnerJid,
      );
      final peerPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: chatJid,
      );

      expect(aggregates, hasLength(1));
      expect(aggregates.single.pinCount, 1);
      expect(aggregates.single.pinnedBySelf, isTrue);
      expect(selfPin?.active, isTrue);
      expect(peerPin?.active, isFalse);

      await controller.close();
    });

    test('Inbound direct pin can target a local-authored message', () async {
      const chatJid = 'peer@axi.im';
      const stanzaId = 'local-authored-stanza-id';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          senderJid: 'jid@axi.im',
          chatJid: chatJid,
          timestamp: DateTime.utc(2026, 5, 26, 11, 24),
          body: 'hello',
        ),
      );
      const reference = MessageReference(
        kind: MessageReferenceKind.stanzaId,
        value: stanzaId,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(chatJid),
          mox.JID.fromString(jid),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            PinMessageMutationData(
              reference: reference,
              pinned: true,
              timestamp: DateTime.utc(2026, 5, 26, 11, 25),
            ),
          ]),
          id: uuid.v4(),
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final aggregates = await database.getPinnedMessageAggregates(
        chatJid: chatJid,
        selfPinnerJid: 'jid@axi.im',
      );
      final peerPin = await database.getMessagePin(
        chatJid: chatJid,
        reference: reference,
        pinnerJid: chatJid,
      );

      expect(aggregates, hasLength(1));
      expect(aggregates.single.pinCount, 1);
      expect(aggregates.single.pinnedBySelf, isFalse);
      expect(peerPin?.active, isTrue);

      await controller.close();
    });

    test(
      'Inbound direct pin is ignored when the message is already pinned',
      () async {
        const chatJid = 'peer@axi.im';
        const stanzaId = 'already-pinned-inbound-stanza-id';
        const selfPinnerJid = 'jid@axi.im';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            senderJid: selfPinnerJid,
            chatJid: chatJid,
            timestamp: DateTime.utc(2026, 5, 26, 11, 24),
            body: 'hello',
          ),
        );
        const reference = MessageReference(
          kind: MessageReferenceKind.stanzaId,
          value: stanzaId,
        );
        await database.applyMessagePinMutation(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
          pinnedAt: DateTime.utc(2026, 5, 26, 11, 24),
          active: true,
          identityVerified: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(chatJid),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              PinMessageMutationData(
                reference: reference,
                pinned: true,
                timestamp: DateTime.utc(2026, 5, 26, 11, 25),
              ),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final aggregates = await database.getPinnedMessageAggregates(
          chatJid: chatJid,
          selfPinnerJid: selfPinnerJid,
        );
        final peerPin = await database.getMessagePin(
          chatJid: chatJid,
          reference: reference,
          pinnerJid: chatJid,
        );

        expect(aggregates, hasLength(1));
        expect(aggregates.single.pinCount, 1);
        expect(aggregates.single.pinnedBySelf, isTrue);
        expect(peerPin, isNull);

        await controller.close();
      },
    );

    test(
      'Inbound direct pin rejects origin id disguised as stanza id',
      () async {
        const chatJid = 'peer@axi.im';
        const stanzaId = 'direct-stanza-id';
        const originId = 'direct-origin-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            originID: originId,
            senderJid: chatJid,
            chatJid: chatJid,
            timestamp: DateTime.utc(2026, 5, 26, 11, 24),
            body: 'hello',
          ),
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(chatJid),
            mox.JID.fromString(jid),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              PinMessageMutationData(
                reference: const MessageReference(
                  kind: MessageReferenceKind.stanzaId,
                  value: originId,
                ),
                pinned: true,
                timestamp: DateTime.utc(2026, 5, 26, 11, 25),
              ),
            ]),
            id: uuid.v4(),
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        expect(
          await database.getPinnedMessageAggregates(
            chatJid: chatJid,
            selfPinnerJid: chatJid,
          ),
          isEmpty,
        );
        expect(
          await database.getPinnedMessage(
            chatJid: chatJid,
            messageStanzaId: stanzaId,
          ),
          isNull,
        );

        await controller.close();
      },
    );

    test('Skips direct origin-only pins', () async {
      const chatJid = 'peer@axi.im';
      const originId = 'direct-origin-id';

      await connectSuccessfully(xmppService);
      const message = Message(
        stanzaID: '',
        originID: originId,
        senderJid: chatJid,
        chatJid: chatJid,
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: chatJid, message: message);

      final pinned = await database.getPinnedMessage(
        chatJid: chatJid,
        messageStanzaId: originId,
      );
      expect(pinned, isNull);
    });

    test('Uses room stanza-id as the canonical stored MUC pin id', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const stanzaId = 'pin-local-stanza-id';
      const mucStanzaId = 'pin-room-stanza-id';
      const body = 'hello';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
      final message = Message(
        stanzaID: stanzaId,
        mucStanzaId: mucStanzaId,
        senderJid: occupantId,
        occupantID: occupantId,
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: body,
      );
      await database.saveMessage(
        message,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
        fromPresence: true,
      );
      xmppService.setPinSyncActiveForChat(roomJid, active: true);

      await xmppService.pinMessage(chatJid: roomJid, message: message);

      final pinned = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      expect(pinned?.active, isTrue);
      expect(
        await database.getPinnedMessage(
          chatJid: roomJid,
          messageStanzaId: stanzaId,
        ),
        isNull,
      );
    });

    test('Moderator MUC unpin clears every pin row', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const stanzaId = 'pin-local-stanza-id';
      const mucStanzaId = 'pin-room-stanza-id';
      const selfPinnerJid = 'jid@axi.im';
      const peerPinnerJid = 'peer@axi.im';
      final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn('pin-mutation-1');
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);
      await database.createChat(
        Chat(
          jid: roomJid,
          title: 'Room',
          type: ChatType.groupChat,
          myNickname: roomNick,
          lastChangeTimestamp: pinnedAt,
          contactJid: roomJid,
        ),
      );
      final message = Message(
        stanzaID: stanzaId,
        mucStanzaId: mucStanzaId,
        senderJid: '$roomJid/friend',
        occupantID: '$roomJid/friend',
        chatJid: roomJid,
        timestamp: pinnedAt,
        body: 'hello',
      );
      await database.saveMessage(
        message,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.moderator,
        isPresent: true,
        fromPresence: true,
      );
      const reference = MessageReference(
        kind: MessageReferenceKind.mucStanzaId,
        value: mucStanzaId,
      );
      await database.applyMessagePinMutation(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: selfPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      await database.applyMessagePinMutation(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: peerPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      xmppService.setPinSyncActiveForChat(roomJid, active: true);

      await xmppService.unpinMessage(chatJid: roomJid, message: message);
      await untilCalled(() => mockConnection.sendMessage(any()));

      final sentEvent =
          verify(() => mockConnection.sendMessage(captureAny())).captured.single
              as mox.MessageEvent;
      final mutation = sentEvent.extensions.get<PinMessageMutationData>();
      expect(mutation?.messageId, mucStanzaId);
      expect(mutation?.pinned, isFalse);
      expect(mutation?.scope, PinMessageMutationScope.all);
      expect(
        await database.getPinnedMessageAggregates(
          chatJid: roomJid,
          selfPinnerJid: selfPinnerJid,
        ),
        isEmpty,
      );
      final legacy = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      expect(legacy?.active, isFalse);
    });

    test('Pending MUC clear-all flushes before a newer re-pin', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const stanzaId = 'pin-local-stanza-id';
      const mucStanzaId = 'pin-room-stanza-id';
      const selfPinnerJid = 'jid@axi.im';
      const peerPinnerJid = 'peer@axi.im';
      final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);
      var generatedId = 0;

      await connectSuccessfully(xmppService);
      await xmppService.setMucServiceHost('conference.axi.im');
      await xmppService.setMamSupportOverride(false);
      when(
        () => mockStateStore.read(
          key: XmppStateStore.registerKey(
            'pin_sync_archive_bootstrap_$roomJid',
          ),
        ),
      ).thenReturn(DateTime.timestamp().toUtc().toIso8601String());
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(
        () => mockConnection.generateId(),
      ).thenAnswer((_) => 'pin-mutation-${generatedId++}');
      when(() => mockConnection.sendMessage(any())).thenAnswer((_) async {
        return true;
      });
      await database.createChat(
        Chat(
          jid: roomJid,
          title: 'Room',
          type: ChatType.groupChat,
          myNickname: roomNick,
          lastChangeTimestamp: pinnedAt,
          contactJid: roomJid,
        ),
      );
      final message = Message(
        stanzaID: stanzaId,
        mucStanzaId: mucStanzaId,
        senderJid: '$roomJid/friend',
        occupantID: '$roomJid/friend',
        chatJid: roomJid,
        timestamp: pinnedAt,
        body: 'hello',
      );
      await database.saveMessage(
        message,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.updateOccupantFromPresence(
        roomJid: roomJid,
        occupantId: occupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.moderator,
        isPresent: true,
        fromPresence: true,
      );
      const reference = MessageReference(
        kind: MessageReferenceKind.mucStanzaId,
        value: mucStanzaId,
      );
      await database.applyMessagePinMutation(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: selfPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      await database.applyMessagePinMutation(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: peerPinnerJid,
        pinnedAt: pinnedAt,
        active: true,
        identityVerified: true,
      );
      xmppService.setPinSyncActiveForChat(roomJid, active: true);
      when(() => mockConnection.hasConnectionSettings).thenReturn(false);

      await xmppService.unpinMessage(chatJid: roomJid, message: message);
      final clearAllTombstone = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      await Future<void>.delayed(const Duration(milliseconds: 1));
      await xmppService.pinMessage(chatJid: roomJid, message: message);
      final activeAggregate = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);

      await xmppService.syncPinnedMessagesForChat(roomJid);

      final sentEvents = verify(
        () => mockConnection.sendMessage(captureAny()),
      ).captured.cast<mox.MessageEvent>().toList();
      final mutations = sentEvents
          .map((event) => event.extensions.get<PinMessageMutationData>())
          .toList(growable: false);

      expect(clearAllTombstone?.active, isFalse);
      expect(activeAggregate?.active, isTrue);
      expect(sentEvents, hasLength(2));
      expect(mutations.first?.messageId, mucStanzaId);
      expect(mutations.first?.pinned, isFalse);
      expect(mutations.first?.scope, PinMessageMutationScope.all);
      expect(mutations.first?.timestamp, clearAllTombstone?.pinnedAt);
      expect(mutations.last?.messageId, mucStanzaId);
      expect(mutations.last?.pinned, isTrue);
      expect(mutations.last?.scope, PinMessageMutationScope.own);
    });

    test('Allows participant MUC pins for peer-authored messages', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const stanzaId = 'pin-local-stanza-id';
      const mucStanzaId = 'pin-room-stanza-id';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(false);
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
        occupantId: occupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
        fromPresence: true,
      );
      final message = Message(
        stanzaID: stanzaId,
        mucStanzaId: mucStanzaId,
        senderJid: '$roomJid/friend',
        occupantID: '$roomJid/friend',
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );

      await xmppService.pinMessage(chatJid: roomJid, message: message);

      verifyNever(() => mockConnection.sendMessage(any()));
      final pinned = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      expect(pinned?.active, isTrue);
    });

    test('Allows participant MUC pins for own room-nick messages', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const opaqueOccupantId = 'occupant-id-self';
      const stanzaId = 'pin-local-stanza-id';
      const mucStanzaId = 'pin-room-stanza-id';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
      await xmppService.setMucServiceHost('conference.axi.im');
      when(
        () => mockConnection.getManager<MUCManager>(),
      ).thenReturn(mucManager);
      final managerRoomState = mox.RoomState(
        roomJid: mox.JID.fromString(roomJid),
        joined: true,
        nick: roomNick,
      );
      when(
        () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
      ).thenAnswer((_) async => managerRoomState);
      when(() => mockConnection.generateId()).thenReturn('pin-mutation-1');
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
        occupantId: opaqueOccupantId,
        nick: roomNick,
        realJid: xmppService.myJid,
        affiliation: OccupantAffiliation.member,
        role: OccupantRole.participant,
        isPresent: true,
        fromPresence: true,
      );
      final message = Message(
        stanzaID: stanzaId,
        mucStanzaId: mucStanzaId,
        senderJid: '$roomJid/$roomNick',
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );
      await database.saveMessage(
        message,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );

      await xmppService.pinMessage(chatJid: roomJid, message: message);
      await untilCalled(() => mockConnection.sendMessage(any()));

      final pinned = await database.getPinnedMessage(
        chatJid: roomJid,
        messageStanzaId: mucStanzaId,
      );
      expect(pinned?.active, isTrue);
    });

    test(
      'Participant MUC unpin clears stale self room-nick pin rows',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        const roomNickPinnerJid = '$roomJid/$roomNick';
        const selfPinnerJid = 'jid@axi.im';
        const opaqueOccupantId = 'occupant-id-self';
        const stanzaId = 'pin-local-stanza-id';
        const mucStanzaId = 'pin-room-stanza-id';
        const reference = MessageReference(
          kind: MessageReferenceKind.mucStanzaId,
          value: mucStanzaId,
        );
        final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);

        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(false);
        await database.createChat(
          Chat(
            jid: roomJid,
            title: 'Room',
            type: ChatType.groupChat,
            myNickname: roomNick,
            lastChangeTimestamp: pinnedAt,
            contactJid: roomJid,
          ),
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: opaqueOccupantId,
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        final message = Message(
          stanzaID: stanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: roomNickPinnerJid,
          occupantID: opaqueOccupantId,
          chatJid: roomJid,
          timestamp: pinnedAt,
          body: 'hello',
        );
        await database.saveMessage(
          message,
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        await database.applyMessagePinMutation(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
          pinnedAt: pinnedAt,
          active: true,
          identityVerified: true,
        );
        await database.applyMessagePinMutation(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: roomNickPinnerJid,
          pinnedAt: pinnedAt,
          active: true,
          identityVerified: false,
        );

        await xmppService.unpinMessage(chatJid: roomJid, message: message);

        final selfPin = await database.getMessagePin(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: selfPinnerJid,
        );
        final roomNickPin = await database.getMessagePin(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: roomNickPinnerJid,
        );

        verifyNever(() => mockConnection.sendMessage(any()));
        expect(selfPin?.active, isFalse);
        expect(roomNickPin?.active, isFalse);
        expect(
          await database.getPinnedMessageAggregates(
            chatJid: roomJid,
            selfPinnerJid: selfPinnerJid,
          ),
          isEmpty,
        );
      },
    );

    test(
      'Inbound participant MUC pin can target another occupant message',
      () async {
        const roomJid = 'room@conference.axi.im';
        const pinnerJid = '$roomJid/pinner';
        const targetJid = '$roomJid/friend';
        const stanzaId = 'muc-local-stanza-id';
        const mucStanzaId = 'muc-room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: pinnerJid,
          nick: 'pinner',
          realJid: 'pinner@axi.im',
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: targetJid,
            occupantID: targetJid,
            chatJid: roomJid,
            timestamp: DateTime.utc(2026, 5, 26, 11, 24),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(pinnerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              PinMessageMutationData(
                reference: const MessageReference(
                  kind: MessageReferenceKind.mucStanzaId,
                  value: mucStanzaId,
                ),
                pinned: true,
                timestamp: DateTime.utc(2026, 5, 26, 11, 25),
              ),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final aggregates = await database.getPinnedMessageAggregates(
          chatJid: roomJid,
          selfPinnerJid: 'jid@axi.im',
        );
        const reference = MessageReference(
          kind: MessageReferenceKind.mucStanzaId,
          value: mucStanzaId,
        );
        final pinnerPin = await database.getMessagePin(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: 'pinner@axi.im',
        );

        expect(aggregates, hasLength(1));
        expect(aggregates.single.pinCount, 1);
        expect(aggregates.single.pinnedBySelf, isFalse);
        expect(pinnerPin?.active, isTrue);

        await controller.close();
      },
    );

    test(
      'Inbound participant MUC pin can target their own occupant message',
      () async {
        const roomJid = 'room@conference.axi.im';
        const pinnerJid = '$roomJid/pinner';
        const stanzaId = 'muc-local-stanza-id';
        const mucStanzaId = 'muc-room-stanza-id';
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: pinnerJid,
          nick: 'pinner',
          realJid: 'pinner@axi.im',
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.participant,
          isPresent: true,
          fromPresence: true,
        );
        await database.saveMessage(
          Message(
            stanzaID: stanzaId,
            mucStanzaId: mucStanzaId,
            senderJid: pinnerJid,
            occupantID: pinnerJid,
            chatJid: roomJid,
            timestamp: DateTime.utc(2026, 5, 26, 11, 24),
            body: 'hello',
          ),
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(pinnerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              PinMessageMutationData(
                reference: const MessageReference(
                  kind: MessageReferenceKind.mucStanzaId,
                  value: mucStanzaId,
                ),
                pinned: true,
                timestamp: DateTime.utc(2026, 5, 26, 11, 25),
              ),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        final aggregates = await database.getPinnedMessageAggregates(
          chatJid: roomJid,
          selfPinnerJid: 'pinner@axi.im',
        );
        expect(aggregates, hasLength(1));
        expect(aggregates.single.messageReferenceId, mucStanzaId);

        await controller.close();
      },
    );

    test('Archived self MUC pin stores the account JID', () async {
      const roomJid = 'room@conference.axi.im';
      const selfOccupantJid = '$roomJid/oldme';
      const stanzaId = 'self-muc-local-stanza-id';
      const mucStanzaId = 'self-muc-room-stanza-id';
      final pinnedAt = DateTime.utc(2026, 5, 26, 11, 25);
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);
      await database.saveMessage(
        Message(
          stanzaID: stanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: selfOccupantJid,
          senderRealJid: xmppService.myJid,
          occupantID: selfOccupantJid,
          chatJid: roomJid,
          timestamp: DateTime.utc(2026, 5, 26, 11, 24),
          body: 'hello',
        ),
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      const reference = MessageReference(
        kind: MessageReferenceKind.mucStanzaId,
        value: mucStanzaId,
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(selfOccupantJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            PinMessageMutationData(
              reference: reference,
              pinned: true,
              timestamp: pinnedAt,
            ),
          ]),
          id: uuid.v4(),
          type: 'groupchat',
          isFromMAM: true,
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final selfPin = await database.getMessagePin(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: xmppService.myJid!,
      );
      final roomNickPin = await database.getMessagePin(
        chatJid: roomJid,
        reference: reference,
        pinnerJid: selfOccupantJid,
      );
      final aggregates = await database.getPinnedMessageAggregates(
        chatJid: roomJid,
        selfPinnerJid: xmppService.myJid!,
      );

      expect(selfPin?.active, isTrue);
      expect(selfPin?.identityVerified, isTrue);
      expect(roomNickPin, isNull);
      expect(aggregates, hasLength(1));
      expect(aggregates.single.pinnedBySelf, isTrue);

      await controller.close();
    });

    test(
      'Archived moderator MUC clear-all applies without present target',
      () async {
        const roomJid = 'room@conference.axi.im';
        const moderatorJid = '$roomJid/moderator';
        const mucStanzaId = 'missing-muc-room-stanza-id';
        final pinnedAt = DateTime.utc(2026, 5, 26, 11, 24);
        final clearedAt = pinnedAt.add(const Duration(minutes: 1));
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);

        await connectSuccessfully(xmppService);
        await xmppService.setMucServiceHost('conference.axi.im');
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: moderatorJid,
          nick: 'moderator',
          realJid: 'moderator@axi.im',
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.moderator,
          isPresent: false,
          fromPresence: false,
        );
        const reference = MessageReference(
          kind: MessageReferenceKind.mucStanzaId,
          value: mucStanzaId,
        );
        await database.applyMessagePinMutation(
          chatJid: roomJid,
          reference: reference,
          pinnerJid: 'peer@axi.im',
          pinnedAt: pinnedAt,
          active: true,
          identityVerified: true,
        );

        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(moderatorJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              PinMessageMutationData(
                reference: reference,
                pinned: false,
                scope: PinMessageMutationScope.all,
                timestamp: clearedAt,
              ),
            ]),
            id: uuid.v4(),
            type: 'groupchat',
            isFromMAM: true,
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        expect(
          await database.getPinnedMessageAggregates(
            chatJid: roomJid,
            selfPinnerJid: 'peer@axi.im',
          ),
          isEmpty,
        );
        final legacy = await database.getPinnedMessage(
          chatJid: roomJid,
          messageStanzaId: mucStanzaId,
        );
        expect(legacy?.active, isFalse);
        expect(legacy?.pinnedAt, clearedAt);

        await controller.close();
      },
    );

    test(
      'Uses room nick sender JIDs for opaque self occupant pin mutations',
      () async {
        const roomJid = 'room@conference.axi.im';
        const roomNick = 'me';
        const opaqueOccupantId = 'occupant-id-self';
        const stanzaId = 'pin-local-stanza-id';
        const mucStanzaId = 'pin-room-stanza-id';

        await connectSuccessfully(xmppService);
        when(() => mockConnection.hasConnectionSettings).thenReturn(true);
        await xmppService.setMucServiceHost('conference.axi.im');
        when(
          () => mockConnection.getManager<MUCManager>(),
        ).thenReturn(mucManager);
        final managerRoomState = mox.RoomState(
          roomJid: mox.JID.fromString(roomJid),
          joined: true,
          nick: roomNick,
        );
        when(
          () => mucManager.getRoomState(mox.JID.fromString(roomJid)),
        ).thenAnswer((_) async => managerRoomState);
        when(() => mockConnection.generateId()).thenReturn(uuid.v4());
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
        final message = Message(
          stanzaID: stanzaId,
          mucStanzaId: mucStanzaId,
          senderJid: '$roomJid/friend',
          occupantID: 'occupant-id-friend',
          chatJid: roomJid,
          timestamp: DateTime.timestamp(),
          body: 'hello',
        );
        await database.saveMessage(
          message,
          chatType: ChatType.groupChat,
          selfJid: xmppService.myJid,
        );
        xmppService.updateOccupantFromPresence(
          roomJid: roomJid,
          occupantId: opaqueOccupantId,
          nick: roomNick,
          realJid: xmppService.myJid,
          affiliation: OccupantAffiliation.member,
          role: OccupantRole.moderator,
          isPresent: true,
          fromPresence: true,
        );
        xmppService.setPinSyncActiveForChat(roomJid, active: true);

        await xmppService.pinMessage(chatJid: roomJid, message: message);
        await untilCalled(() => mockConnection.sendMessage(any()));

        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>().having(
                (event) => event.from.toString(),
                'from',
                '$roomJid/$roomNick',
              ),
            ),
          ),
        ).called(1);
      },
    );

    test('Does not send a MUC pin mutation without a room stanza-id', () async {
      const roomJid = 'room@conference.axi.im';
      const roomNick = 'me';
      const occupantId = '$roomJid/$roomNick';
      const stanzaId = 'pin-local-stanza-id';

      await connectSuccessfully(xmppService);
      when(() => mockConnection.hasConnectionSettings).thenReturn(true);
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
      final message = Message(
        stanzaID: stanzaId,
        senderJid: occupantId,
        occupantID: occupantId,
        chatJid: roomJid,
        timestamp: DateTime.timestamp(),
        body: 'hello',
      );
      await database.saveMessage(
        message,
        chatType: ChatType.groupChat,
        selfJid: xmppService.myJid,
      );
      xmppService.setPinSyncActiveForChat(roomJid, active: true);

      await xmppService.pinMessage(chatJid: roomJid, message: message);

      verifyNever(() => mockConnection.sendMessage(any()));
      expect(
        await database.getPinnedMessage(
          chatJid: roomJid,
          messageStanzaId: stanzaId,
        ),
        isNull,
      );
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

    test('Bypasses all feature guards for @axi.im contacts', () async {
      await connectSuccessfully(xmppService);

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: 'friend@axi.im',
      );

      expect(capabilities.assumeAllFeatures, isTrue);
      expect(capabilities.features, isEmpty);
      expect(capabilities.supportsMarkers, isTrue);
      expect(capabilities.supportsReceipts, isTrue);
      expect(capabilities.supportsFeature(mox.messageReactionsXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.chatStateXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.mamXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.omemoXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.httpFileUploadXmlns), isTrue);
      expect(capabilities.capabilitiesResolvedAt, isNotNull);
      verifyNever(() => mockConnection.discoInfoQuery('friend@axi.im'));
    });

    test('Bypasses all feature guards for same-domain contacts', () async {
      await connectSuccessfully(
        xmppService,
        accountJid: 'me@example.com/resource',
      );

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: 'friend@example.com',
      );

      expect(capabilities.assumeAllFeatures, isTrue);
      expect(capabilities.features, isEmpty);
      expect(capabilities.supportsMarkers, isTrue);
      expect(capabilities.supportsReceipts, isTrue);
      expect(capabilities.supportsFeature(mox.messageReactionsXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.chatStateXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.mamXmlns), isTrue);
      expect(capabilities.supportsFeature(mox.omemoXmlns), isTrue);
      expect(capabilities.capabilitiesResolvedAt, isNotNull);
      verifyNever(() => mockConnection.discoInfoQuery('friend@example.com'));
    });

    test('Bypasses all feature guards for the account JID', () async {
      await connectSuccessfully(xmppService);

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: xmppService.myJid!,
      );

      expect(capabilities.assumeAllFeatures, isTrue);
      expect(capabilities.supportsFeature(mox.mamXmlns), isTrue);
      verifyNever(() => mockConnection.discoInfoQuery(xmppService.myJid!));
    });

    test(
      'Allows arbitrary feature checks for trusted peers without disco',
      () async {
        await connectSuccessfully(xmppService);

        final decision = await xmppService.decideFeatureSupport(
          jid: 'friend@axi.im',
          feature: mox.httpFileUploadXmlns,
          featureLabel: 'HTTP upload',
        );

        expect(decision.isAllowed, isTrue);
        verifyNever(() => mockConnection.discoInfoQuery('friend@axi.im'));
      },
    );

    test('Queries disco for unknown-domain contacts', () async {
      const peerJid = 'friend@example.net';
      await connectSuccessfully(xmppService);
      when(() => mockConnection.discoInfoQuery(peerJid)).thenAnswer(
        (_) async => moxlib.Result<mox.StanzaError, mox.DiscoInfo>(
          mox.DiscoInfo(
            const <String>[mox.chatMarkersXmlns, mox.deliveryXmlns],
            const <mox.Identity>[],
            const <mox.DataForm>[],
            null,
            mox.JID.fromString(peerJid),
          ),
        ),
      );

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: peerJid,
      );

      expect(capabilities.assumeAllFeatures, isFalse);
      expect(capabilities.features, contains(mox.chatMarkersXmlns));
      expect(capabilities.features, contains(mox.deliveryXmlns));
      verify(() => mockConnection.discoInfoQuery(peerJid)).called(1);
    });

    test('Observing peer chat markers updates cached marker support', () async {
      const peerJid = 'friend@example.net';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      controller.add(
        mox.ChatMarkerEvent(
          mox.JID.fromString(peerJid),
          mox.ChatMarker.displayed,
          'marker-id',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: peerJid,
      );

      expect(capabilities.supportsMarkers, isTrue);
      expect(capabilities.features, contains(mox.chatMarkersXmlns));
      verifyNever(() => mockConnection.discoInfoQuery(peerJid));

      await controller.close();
    });

    test('Observing peer receipts updates cached receipt support', () async {
      const peerJid = 'friend@example.net';
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      controller.add(
        mox.DeliveryReceiptReceivedEvent(
          from: mox.JID.fromString(peerJid),
          id: 'receipt-id',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      final capabilities = await xmppService.resolvePeerCapabilities(
        jid: peerJid,
      );

      expect(capabilities.supportsReceipts, isTrue);
      expect(capabilities.features, contains(mox.deliveryXmlns));
      verifyNever(() => mockConnection.discoInfoQuery(peerJid));

      await controller.close();
    });

    test('Does not disco before direct auto-acks', () async {
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

      const peerJid = 'friend@example.net/phone';
      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('hello'),
            const mox.MarkableData(true),
            const mox.MessageDeliveryReceiptData(true),
            mox.MessageIdData('direct-auto-ack'),
          ]),
          id: 'direct-auto-ack',
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      verifyNever(() => mockConnection.discoInfoQuery(any()));

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

    test('Accepts valid received carbons from peers', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      const peerJid = 'friend@example.net';
      const stanzaId = 'received-carbon-message';
      final carbonEvent = mox.MessageEvent(
        mox.JID.fromString(peerJid),
        mox.JID.fromString(xmppService.myJid!),
        false,
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          const mox.CarbonsData(true),
          const mox.MessageBodyData('carbon copy'),
          mox.MessageIdData(stanzaId),
        ]),
        id: stanzaId,
        type: 'chat',
      );

      controller.add(carbonEvent);
      await pumpEventQueue();
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored?.chatJid, peerJid);
      expect(stored?.body, 'carbon copy');

      await controller.close();
    });

    test('Does not acknowledge archived direct messages', () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockConnection.sendChatMarker(
          to: any(named: 'to'),
          stanzaID: any(named: 'stanzaID'),
          marker: any(named: 'marker'),
          messageType: any(named: 'messageType'),
        ),
      ).thenAnswer((_) async => true);
      when(
        () => mockConnection.sendMessage(any()),
      ).thenAnswer((_) async => true);

      await connectSuccessfully(xmppService);

      const peerJid = 'friend@axi.im';
      const stanzaId = 'mam-direct-message';
      final timestamp = DateTime.utc(2026, 3, 10, 12);
      final event = mox.MessageEvent(
        mox.JID.fromString(peerJid),
        mox.JID.fromString(xmppService.myJid!),
        false,
        mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
          const mox.MessageBodyData('Missed while offline'),
          const mox.MarkableData(true),
          const mox.MessageDeliveryReceiptData(true),
          mox.MessageIdData(stanzaId),
          mox.DelayedDeliveryData(mox.JID.fromString(peerJid), timestamp),
        ]),
        id: stanzaId,
        type: 'chat',
        isFromMAM: true,
      );

      controller.add(event);
      await pumpEventQueue();
      await pumpEventQueue();

      final stored = await database.getMessageByStanzaID(stanzaId);
      expect(stored?.acked, isFalse);
      expect(stored?.received, isFalse);
      verifyNever(
        () => mockConnection.sendChatMarker(
          to: any(named: 'to'),
          stanzaID: any(named: 'stanzaID'),
          marker: any(named: 'marker'),
          messageType: any(named: 'messageType'),
        ),
      );
      verifyNever(() => mockConnection.sendMessage(any()));

      await controller.close();
    });

    test(
      'Preserves archived origin-id messages without acknowledging them',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        const peerJid = 'friend@axi.im';
        const stanzaId = 'mam-direct-message-with-origin';
        const originId = 'mam-direct-message-origin';
        final timestamp = DateTime.utc(2026, 3, 10, 13);
        final event = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('Missed while offline'),
            const mox.MarkableData(true),
            const mox.MessageDeliveryReceiptData(true),
            mox.MessageIdData(stanzaId),
            const mox.StableIdData(originId, null),
            mox.DelayedDeliveryData(mox.JID.fromString(peerJid), timestamp),
          ]),
          id: stanzaId,
          type: 'chat',
          isFromMAM: true,
        );

        controller.add(event);
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.originID, originId);
        expect(stored?.acked, isFalse);
        expect(stored?.received, isFalse);
        verifyNever(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        );
        verifyNever(() => mockConnection.sendMessage(any()));

        await controller.close();
      },
    );

    test(
      'Does not send XEP-0184 receipts for archived direct messages',
      () async {
        final controller = StreamController<mox.XmppEvent>();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        const peerJid = 'friend@axi.im';
        const stanzaId = 'mam-direct-receipt-only';
        final timestamp = DateTime.utc(2026, 3, 11, 12);
        final event = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('Offline receipt request'),
            const mox.MessageDeliveryReceiptData(true),
            mox.MessageIdData(stanzaId),
            mox.DelayedDeliveryData(mox.JID.fromString(peerJid), timestamp),
          ]),
          id: stanzaId,
          type: 'chat',
          isFromMAM: true,
        );

        controller.add(event);
        await pumpEventQueue();
        await pumpEventQueue();

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isFalse);
        expect(stored?.received, isFalse);
        verifyNever(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        );
        verifyNever(() => mockConnection.sendMessage(any()));

        await controller.close();
      },
    );

    test(
      'Replies to direct receipt requests and markable messages without disco',
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
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((_) async => true);
        when(
          () => mockConnection.sendMessage(any()),
        ).thenAnswer((_) async => true);

        await connectSuccessfully(xmppService);

        const peerJid = 'friend@example.net/phone';
        const stanzaId = 'unknown-domain-direct-message';
        final event = mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('Unknown domain'),
            const mox.MarkableData(true),
            const mox.MessageDeliveryReceiptData(true),
            mox.MessageIdData(stanzaId),
          ]),
          id: stanzaId,
          type: 'chat',
        );

        controller.add(event);
        await pumpEventQueue();
        await pumpEventQueue();

        verify(
          () => mockConnection.sendChatMarker(
            to: peerJid,
            stanzaID: stanzaId,
            marker: mox.ChatMarker.received,
            messageType: 'chat',
          ),
        ).called(1);
        verify(
          () => mockConnection.sendMessage(
            any(
              that: isA<mox.MessageEvent>()
                  .having(
                    (message) => message.to.toString(),
                    'receipt target',
                    peerJid,
                  )
                  .having(
                    (message) => message.extensions
                        .get<mox.MessageDeliveryReceivedData>()
                        ?.id,
                    'delivery receipt id',
                    stanzaId,
                  ),
            ),
          ),
        ).called(1);
        verifyNever(() => mockConnection.discoInfoQuery(peerJid));

        final stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);

        await controller.close();
      },
    );

    test(
      'Queues failed direct auto-acks and flushes them after negotiation',
      () async {
        final controller = StreamController<mox.XmppEvent>.broadcast();
        var markerAttempts = 0;
        var receiptAttempts = 0;
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((_) async {
          markerAttempts += 1;
          return markerAttempts > 1;
        });
        when(() => mockConnection.sendMessage(any())).thenAnswer((_) async {
          receiptAttempts += 1;
          return receiptAttempts > 1;
        });

        await connectSuccessfully(xmppService);

        const peerJid = 'friend@example.net/phone';
        const stanzaId = 'queued-direct-auto-ack';
        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('Queue failed auto-acks'),
              const mox.MarkableData(true),
              const mox.MessageDeliveryReceiptData(true),
              mox.MessageIdData(stanzaId),
            ]),
            id: stanzaId,
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        var stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isFalse);
        expect(stored?.received, isFalse);
        expect(markerAttempts, 1);
        expect(receiptAttempts, 1);

        controller.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        await xmppService.setMamSupportOverride(false);
        await xmppService.runBootstrapOperations(
          XmppBootstrapTrigger.resumedNegotiation,
        );

        stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(markerAttempts, 2);
        expect(receiptAttempts, 2);

        await controller.close();
      },
    );

    test(
      'Marks direct auto-acks sent when one requested reply succeeds',
      () async {
        final controller = StreamController<mox.XmppEvent>.broadcast();
        var receiptAttempts = 0;
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => controller.stream);
        when(
          () => mockStateStore.read(key: any(named: 'key')),
        ).thenReturn(null);
        when(
          () => mockConnection.sendChatMarker(
            to: any(named: 'to'),
            stanzaID: any(named: 'stanzaID'),
            marker: any(named: 'marker'),
            messageType: any(named: 'messageType'),
          ),
        ).thenAnswer((_) async => true);
        when(() => mockConnection.sendMessage(any())).thenAnswer((_) async {
          receiptAttempts += 1;
          return receiptAttempts > 1;
        });

        await connectSuccessfully(xmppService);

        const peerJid = 'friend@example.net/phone';
        const stanzaId = 'partial-direct-auto-ack';
        controller.add(
          mox.MessageEvent(
            mox.JID.fromString(peerJid),
            mox.JID.fromString(xmppService.myJid!),
            false,
            mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
              const mox.MessageBodyData('Partial auto-ack'),
              const mox.MarkableData(true),
              const mox.MessageDeliveryReceiptData(true),
              mox.MessageIdData(stanzaId),
            ]),
            id: stanzaId,
            type: 'chat',
          ),
        );
        await pumpEventQueue();
        await pumpEventQueue();

        var stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(receiptAttempts, 1);

        controller.add(
          mox.ConnectionStateChangedEvent(
            mox.XmppConnectionState.connected,
            mox.XmppConnectionState.notConnected,
          ),
        );
        await pumpEventQueue();
        await xmppService.setMamSupportOverride(false);
        await xmppService.runBootstrapOperations(
          XmppBootstrapTrigger.resumedNegotiation,
        );

        stored = await database.getMessageByStanzaID(stanzaId);
        expect(stored?.acked, isTrue);
        expect(stored?.received, isTrue);
        expect(receiptAttempts, 2);

        await controller.close();
      },
    );
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

  group('important folder sync', () {
    test(
      'createMessageCollection publishes the folder record payload',
      () async {
        final transport = RecordingMessageCollectionsPubSubTransport();
        final manager = MessageCollectionsPubSubManager()
          ..register(
            _messageCollectionsTestAttributes(
              pubSubManager: transport,
              accountJid: 'owner@example.com/resource',
            ),
          );

        when(
          () => mockConnection.getManager<MessageCollectionsPubSubManager>(),
        ).thenReturn(manager);

        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        final collection = await xmppService.createMessageCollection(
          title: 'Projects',
        );

        expect(collection.id, 'Projects');
        expect(collection.title, isNull);
        expect(collection.active, isTrue);
        expect(transport.publishCount, 1);
        expect(transport.subscribeCount, 1);

        final payload = MessageCollectionRecordSyncPayload.fromXml(
          transport.publishedItems.values.single,
        );
        expect(payload, isNotNull);
        expect(payload!.collectionId, 'Projects');
        expect(payload.active, isTrue);
      },
    );

    test('createMessageCollection rejects invalid folder names', () async {
      await expectLater(
        xmppService.createMessageCollection(title: '   '),
        throwsA(
          isA<MessageCollectionNameException>().having(
            (error) => error.failure,
            'failure',
            MessageCollectionNameFailure.empty,
          ),
        ),
      );
      await expectLater(
        xmppService.createMessageCollection(title: 'Important'),
        throwsA(
          isA<MessageCollectionNameException>().having(
            (error) => error.failure,
            'failure',
            MessageCollectionNameFailure.reserved,
          ),
        ),
      );
      await expectLater(
        xmppService.createMessageCollection(title: 'Receipts'),
        throwsA(
          isA<MessageCollectionNameException>().having(
            (error) => error.failure,
            'failure',
            MessageCollectionNameFailure.reserved,
          ),
        ),
      );

      await connectSuccessfully(
        xmppService,
        accountJid: 'owner@example.com/resource',
      );
      await xmppService.createMessageCollection(title: 'Projects');

      await expectLater(
        xmppService.createMessageCollection(title: ' projects '),
        throwsA(
          isA<MessageCollectionNameException>().having(
            (error) => error.failure,
            'failure',
            MessageCollectionNameFailure.duplicate,
          ),
        ),
      );
    });

    test('MessageCollectionSyncUpdatedEvent cannot mutate important', () async {
      final events = StreamController<mox.XmppEvent>.broadcast();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => events.stream);

      await connectSuccessfully(
        xmppService,
        accountJid: 'owner@example.com/resource',
      );

      events.add(
        MessageCollectionSyncUpdatedEvent(
          MessageCollectionRecordSyncPayload(
            collectionId: SystemMessageCollection.important.id,
            updatedAt: DateTime.utc(2026, 4, 15, 9, 30),
            active: false,
          ),
        ),
      );

      await pumpEventQueue(times: 10);

      final important = await database.getMessageCollection(
        SystemMessageCollection.important.id,
      );
      expect(important, isNotNull);
      expect(important!.isSystem, isTrue);
      expect(important.active, isTrue);
      expect(important.title, isNull);

      await events.close();
    });

    test(
      'setMessageCollectionMembership publishes the important membership payload',
      () async {
        final transport = RecordingMessageCollectionsPubSubTransport();
        final manager = MessageCollectionsPubSubManager()
          ..register(
            _messageCollectionsTestAttributes(
              pubSubManager: transport,
              accountJid: 'owner@example.com/resource',
            ),
          );

        when(
          () => mockConnection.getManager<MessageCollectionsPubSubManager>(),
        ).thenReturn(manager);

        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        final chat = Chat.fromJid('friend@example.com');
        final message =
            Message.fromMox(
              generateRandomMessageEvent(senderJid: chat.jid),
            ).copyWith(
              chatJid: chat.jid,
              senderJid: chat.jid,
              timestamp: DateTime.timestamp().toUtc(),
            );

        final changed = await xmppService.setMessageCollectionMembership(
          collectionId: SystemMessageCollection.important.id,
          chat: chat,
          message: message,
          active: true,
        );

        expect(changed, isTrue);
        expect(transport.publishCount, 1);
        expect(transport.subscribeCount, 1);
        expect(transport.publishedItems, hasLength(1));

        final payload = MessageCollectionSyncPayload.fromXml(
          transport.publishedItems.values.single,
        );
        expect(payload, isNotNull);
        expect(payload!.collectionId, SystemMessageCollection.important.id);
        expect(payload.chatJid, chat.jid);
        expect(payload.active, isTrue);

        final entry = await database.getMessageCollectionMembership(
          collectionId: SystemMessageCollection.important.id,
          chatJid: chat.jid,
          messageReferenceId: payload.messageReferenceId,
        );
        expect(entry, isNotNull);
        expect(entry!.active, isTrue);
      },
    );

    test(
      'setMessageCollectionMembership reports unsupported messages without writing',
      () async {
        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        final chat = Chat.fromJid('friend@example.com');
        final message = Message(
          stanzaID: '',
          senderJid: chat.jid,
          chatJid: chat.jid,
          body: 'No stable reference',
          timestamp: DateTime.timestamp().toUtc(),
        );

        final changed = await xmppService.setMessageCollectionMembership(
          collectionId: 'receipts',
          chat: chat,
          message: message,
          active: true,
        );

        expect(changed, isFalse);
        expect(
          await database.getMessageCollectionMembership(
            collectionId: 'receipts',
            chatJid: chat.jid,
            messageReferenceId: '',
          ),
          isNull,
        );
      },
    );

    test(
      'removeMessageCollectionMembership tombstones only the membership',
      () async {
        final transport = RecordingMessageCollectionsPubSubTransport();
        final manager = MessageCollectionsPubSubManager()
          ..register(
            _messageCollectionsTestAttributes(
              pubSubManager: transport,
              accountJid: 'owner@example.com/resource',
            ),
          );

        when(
          () => mockConnection.getManager<MessageCollectionsPubSubManager>(),
        ).thenReturn(manager);

        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        const collectionId = 'Projects';
        await database.applyMessageCollectionDefinitionMutation(
          collectionId: collectionId,
          updatedAt: DateTime.utc(2026, 4, 15, 10),
          active: true,
        );
        final chat = Chat.fromJid('friend@example.com');
        final message =
            Message.fromMox(
              generateRandomMessageEvent(senderJid: chat.jid),
            ).copyWith(
              chatJid: chat.jid,
              senderJid: chat.jid,
              timestamp: DateTime.timestamp().toUtc(),
            );
        await database.createChat(chat);
        await database.saveMessage(message);

        final added = await xmppService.setMessageCollectionMembership(
          collectionId: collectionId,
          chat: chat,
          message: message,
          active: true,
        );
        expect(added, isTrue);
        final messageReferenceId = message
            .collectionReference(isGroupChat: false)!
            .value;
        final activeEntry = await database.getMessageCollectionMembership(
          collectionId: collectionId,
          chatJid: chat.jid,
          messageReferenceId: messageReferenceId,
        );
        expect(activeEntry, isNotNull);
        expect(activeEntry!.active, isTrue);

        final removed = await xmppService.removeMessageCollectionMembership(
          FolderMessageItem(
            collectionId: activeEntry.collectionId,
            chatJid: activeEntry.chatJid,
            messageReferenceId: activeEntry.messageReferenceId,
            messageStanzaId: activeEntry.messageStanzaId,
            messageOriginId: activeEntry.messageOriginId,
            messageMucStanzaId: activeEntry.messageMucStanzaId,
            deltaAccountId: activeEntry.deltaAccountId,
            deltaMsgId: activeEntry.deltaMsgId,
            addedAt: activeEntry.addedAt,
            active: activeEntry.active,
            message: message,
            chat: chat,
          ),
        );
        expect(removed, isTrue);

        final removedEntry = await database.getMessageCollectionMembership(
          collectionId: collectionId,
          chatJid: chat.jid,
          messageReferenceId: messageReferenceId,
        );
        final savedMessage = await database.getMessageByReferenceId(
          messageReferenceId,
          chatJid: chat.jid,
        );
        final payload = MessageCollectionSyncPayload.fromXml(
          transport.publishedItems.values.single,
        );

        expect(transport.publishCount, 2);
        expect(removedEntry, isNotNull);
        expect(removedEntry!.active, isFalse);
        expect(savedMessage, isNotNull);
        expect(payload, isNotNull);
        expect(payload!.collectionId, collectionId);
        expect(payload.active, isFalse);
      },
    );

    test(
      'removeMessageCollectionMembership rejects contact-rule-derived items',
      () async {
        final removed = await xmppService.removeMessageCollectionMembership(
          FolderMessageItem(
            collectionId: SystemMessageCollection.receipts.id,
            chatJid: 'friend@example.com',
            messageReferenceId: 'message-1',
            messageStanzaId: 'message-1',
            messageOriginId: null,
            messageMucStanzaId: null,
            deltaAccountId: null,
            deltaMsgId: null,
            addedAt: DateTime.utc(2026, 4, 15, 10),
            active: true,
            message: null,
            chat: null,
            isContactRuleDerived: true,
          ),
        );

        expect(removed, isFalse);
        expect(await database.getAllMessageCollectionMemberships(), isEmpty);
      },
    );

    test(
      'MessageCollectionSyncUpdatedEvent applies remote important changes',
      () async {
        final events = StreamController<mox.XmppEvent>.broadcast();
        when(
          () => mockConnection.asBroadcastStream(),
        ).thenAnswer((_) => events.stream);

        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        const chatJid = 'friend@example.com';
        const messageReferenceId = 'remote-reference';
        final updatedAt = DateTime.utc(2026, 4, 15, 10, 30);

        events.add(
          MessageCollectionSyncUpdatedEvent(
            MessageCollectionSyncPayload(
              collectionId: SystemMessageCollection.important.id,
              chatJid: chatJid,
              messageReferenceId: messageReferenceId,
              updatedAt: updatedAt,
              active: true,
              sourceId: 'remote-device',
            ),
          ),
        );

        await pumpEventQueue(times: 10);

        final entry = await database.getMessageCollectionMembership(
          collectionId: SystemMessageCollection.important.id,
          chatJid: chatJid,
          messageReferenceId: messageReferenceId,
        );
        expect(entry, isNotNull);
        expect(entry!.active, isTrue);
        expect(entry.addedAt.toUtc(), updatedAt);

        await events.close();
      },
    );

    test(
      'contact folder rule sync publishes only the contact payload',
      () async {
        final contactTransport = RecordingMessageCollectionsPubSubTransport();
        final contactsManager = ContactsPubSubManager()
          ..register(
            _messageCollectionsTestAttributes(
              pubSubManager: contactTransport,
              accountJid: 'owner@example.com/resource',
            ),
          );
        final collectionTransport =
            RecordingMessageCollectionsPubSubTransport();
        final collectionsManager = MessageCollectionsPubSubManager()
          ..register(
            _messageCollectionsTestAttributes(
              pubSubManager: collectionTransport,
              accountJid: 'owner@example.com/resource',
            ),
          );

        when(
          () => mockConnection.getManager<ContactsPubSubManager>(),
        ).thenReturn(contactsManager);
        when(
          () => mockConnection.getManager<MessageCollectionsPubSubManager>(),
        ).thenReturn(collectionsManager);

        await connectSuccessfully(
          xmppService,
          accountJid: 'owner@example.com/resource',
        );

        await xmppService.setContactFolderRule(
          address: 'friend@example.com',
          collectionId: SystemMessageCollection.important.id,
        );
        await xmppService.clearContactFolderRule(address: 'friend@example.com');

        expect(collectionTransport.publishCount, 0);
        expect(contactTransport.publishCount, 2);
        expect(
          contactTransport.publishedItems.keys,
          everyElement(startsWith('$contactsPubSubNode|')),
        );
        expect(await database.getAllMessageCollectionMemberships(), isEmpty);

        final setPayload = ContactSyncPayload.fromXml(
          contactTransport.publishedItemsInOrder.first,
        );
        final clearPayload = ContactSyncPayload.fromXml(
          contactTransport.publishedItemsInOrder.last,
        );

        expect(setPayload, isNotNull);
        expect(setPayload!.addressKey, 'friend@example.com');
        expect(
          setPayload.folderCollectionId,
          SystemMessageCollection.important.id,
        );
        expect(clearPayload, isNotNull);
        expect(clearPayload!.addressKey, 'friend@example.com');
        expect(clearPayload.folderCollectionId, isNull);
      },
    );
  });
}
