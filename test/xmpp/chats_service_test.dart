import 'dart:async';
import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/notifications/notification_service.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

import '../mocks.dart';

bool compareChats(Chat a, Chat b) =>
    a.jid == b.jid &&
    a.title == b.title &&
    a.type == b.type &&
    a.lastMessage == b.lastMessage &&
    a.lastChangeTimestamp.floorSeconds == b.lastChangeTimestamp.floorSeconds &&
    a.unreadCount == b.unreadCount &&
    a.open == b.open &&
    a.muted == b.muted &&
    a.favorited == b.favorited &&
    a.encryptionProtocol == b.encryptionProtocol &&
    a.chatState == b.chatState;

class ChatMatcher extends Matcher {
  const ChatMatcher(this.chat);

  final Chat chat;

  @override
  Description describe(Description description) =>
      description.add(chat.toString());

  @override
  bool matches(covariant Chat otherChat, Map matchState) =>
      compareChats(chat, otherChat);
}

const String _managerAccountJid = 'user@example.com/resource';
const String _managerPassword = 'password';

mox.XmppManagerAttributes _buildManagerAttributes({
  required Future<mox.XMLNode?> Function(mox.StanzaDetails details) sendStanza,
}) {
  final fullJid = mox.JID.fromString(_managerAccountJid);
  return mox.XmppManagerAttributes(
    sendStanza: sendStanza,
    sendNonza: (_) {},
    getManagerById: <T extends mox.XmppManagerBase>(_) => null,
    sendEvent: (_) {},
    getConnectionSettings: () =>
        mox.ConnectionSettings(jid: fullJid, password: _managerPassword),
    getFullJID: () => fullJid,
    getSocket: () => throw UnimplementedError(),
    getConnection: () => throw UnimplementedError(),
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(FakeStanzaDetails());
    registerFallbackValue(MessageNotificationChannel.chat);
    registerFallbackValue(mox.ChatState.active);
    registerFallbackValue(FakeUserAgent());
    registerOmemoFallbacks();
  });

  late XmppService xmppService;
  late XmppDatabase database;
  late List<String> chatJids;

  setUp(() {
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
      buildStateStore: (_, _) => mockStateStore,
      buildDatabase: (_, _) => database,
      notificationService: mockNotificationService,
    );
    chatJids = List.generate(4, (_) => generateRandomJid());

    prepareMockConnection();
  });

  tearDown(() async {
    await database.deleteAll();
    await xmppService.close();
  });

  tearDown(() {
    resetMocktailState();
  });

  group('chatsStream', () {
    //TODO(eliot): Fix test flakiness due to unstable sort.
    test(
      'When chats are added to the database, emits the new chat list in order.',
      () async {
        final chats = chatJids.map(Chat.fromJid).toList();

        expectLater(
          xmppService.chatsStream(),
          emitsInOrder([
            [],
            ...List.generate(
              chatJids.length,
              (index) => ChatsService.sortChats(
                chats.sublist(0, index),
              ).map((e) => ChatMatcher(e)).toList(),
            ),
          ]),
        );

        await connectSuccessfully(xmppService);

        for (final chat in chats) {
          await pumpEventQueue();
          await database.createChat(chat);
        }
      },
    );

    test(
      'When messages are edited in the chat\'s database, emits the updated message history in order.',
      () async {
        await connectSuccessfully(xmppService);

        for (final jid in chatJids) {
          await database.createChat(Chat.fromJid(jid));
        }

        await pumpEventQueue();

        final chats = ChatsService.sortChats(
          await database.getChats(start: 0, end: double.maxFinite.toInt()),
        );

        final chats0 = chats[0].copyWith(
          lastMessage: 'text',
          lastChangeTimestamp: DateTime.now(),
          unreadCount: 1,
        );
        final chats1 = chats[1].copyWith(
          open: true,
          lastChangeTimestamp: DateTime.now().add(const Duration(seconds: 1)),
        );
        final chats2 = chats[2].copyWith(
          muted: true,
          lastChangeTimestamp: DateTime.now().add(const Duration(seconds: 2)),
        );
        final chats3 = chats[3].copyWith(
          favorited: true,
          lastChangeTimestamp: DateTime.now().add(const Duration(seconds: 3)),
        );

        expectLater(
          xmppService.chatsStream(),
          emitsInOrder([
            chats.map((e) => ChatMatcher(e)).toList(),
            chats.map((e) => ChatMatcher(e)).toList(),
            ChatsService.sortChats([
              chats0,
              ...chats.sublist(1),
            ]).map((e) => ChatMatcher(e)).toList(),
            ChatsService.sortChats([
              chats0,
              chats1,
              ...chats.sublist(2),
            ]).map((e) => ChatMatcher(e)).toList(),
            ChatsService.sortChats([
              chats0,
              chats1,
              chats2,
              ...chats.sublist(3),
            ]).map((e) => ChatMatcher(e)).toList(),
            ChatsService.sortChats([
              chats0,
              chats1,
              chats2,
              chats3,
            ]).map((e) => ChatMatcher(e)).toList(),
          ]),
        );

        await pumpEventQueue();
        await database.updateChat(chats0);

        await pumpEventQueue();
        await database.updateChat(chats1);

        await pumpEventQueue();
        await database.updateChat(chats2);

        await pumpEventQueue();
        await database.updateChat(chats3);
      },
    );
  });

  test(
    'When chat state updates, accurately passes it to the connection.',
    () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});

      const state = mox.ChatState.active;
      await xmppService.sendChatState(jid: jid, state: state);

      verify(
        () => mockConnection.sendChatState(jid: jid, state: state),
      ).called(1);
    },
  );

  test(
    'Inbound chat-state updates keep typing participants in sync.',
    () async {
      final controller = StreamController<mox.XmppEvent>();
      when(
        () => mockConnection.asBroadcastStream(),
      ).thenAnswer((_) => controller.stream);

      await connectSuccessfully(xmppService);

      final peerJid = generateRandomJid();
      expectLater(
        xmppService.typingParticipantsStream(peerJid),
        emitsInOrder([
          <String>[],
          <String>[peerJid],
          <String>[],
        ]),
      );

      controller.add(
        mox.MessageEvent(
          mox.JID.fromString(peerJid),
          mox.JID.fromString(xmppService.myJid!),
          false,
          mox.TypedMap<mox.StanzaHandlerExtension>.fromList([
            const mox.MessageBodyData('typing'),
            const mox.MessageIdData('chat-state-typing'),
            mox.ChatState.composing,
          ]),
          id: 'chat-state-typing',
          type: 'chat',
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
            const mox.MessageBodyData('paused'),
            const mox.MessageIdData('chat-state-paused'),
            mox.ChatState.paused,
          ]),
          id: 'chat-state-paused',
          type: 'chat',
        ),
      );
      await pumpEventQueue();
      await pumpEventQueue();

      await controller.close();
    },
  );

  test(
    'recipientAddressSuggestionsStream excludes the local welcome chat.',
    () async {
      await connectSuccessfully(xmppService);

      const welcomeJid = 'axichat@welcome.axichat.invalid';
      const peerJid = 'friend@example.com';
      await database.createChat(Chat.fromJid(welcomeJid));
      await database.createChat(Chat.fromJid(peerJid));

      final suggestions = await xmppService
          .recipientAddressSuggestionsStream()
          .first;

      expect(suggestions, [peerJid]);
    },
  );

  test(
    'Conversation index reconciliation preserves the local welcome chat.',
    () async {
      await connectSuccessfully(xmppService);

      const welcomeChatJid = 'axichat@welcome.axichat.invalid';
      await database.createChat(
        Chat.fromJid(
          welcomeChatJid,
        ).copyWith(archived: false, type: ChatType.chat),
      );

      await xmppService.applyConversationIndexSnapshot(const (
        items: <ConvItem>[],
        isSuccess: true,
        isComplete: true,
      ));

      final chat = await database.getChat(welcomeChatJid);
      expect(chat, isNotNull);
      expect(chat?.archived, isFalse);
    },
  );

  test(
    'Conversation index reconciliation preserves direct chats when the snapshot is empty.',
    () async {
      await connectSuccessfully(xmppService);

      final peerJid = chatJids.first;
      await database.createChat(
        Chat.fromJid(peerJid).copyWith(archived: false, type: ChatType.chat),
      );

      await xmppService.applyConversationIndexSnapshot(const (
        items: <ConvItem>[],
        isSuccess: true,
        isComplete: true,
      ));

      final chat = await database.getChat(peerJid);
      expect(chat, isNotNull);
      expect(chat?.archived, isFalse);
    },
  );

  test(
    'Conversation index normalizes an existing self chat title to Saved Messages.',
    () async {
      await connectSuccessfully(xmppService);

      final selfJid = xmppService.myJid!;
      await database.createChat(
        Chat(
          jid: selfJid,
          title: 'Me',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2024, 1, 1, 9),
          contactJid: selfJid,
        ),
      );

      await xmppService.applyConversationIndexItems([
        ConvItem(
          peerBare: mox.JID.fromString(selfJid).toBare(),
          lastTimestamp: DateTime.utc(2024, 1, 1, 10),
        ),
      ]);

      final chat = await database.getChat(selfJid);
      expect(chat?.title, 'Saved Messages');
    },
  );

  test(
    'Conversation index reconciliation repairs stale chat subtitles from stored messages.',
    () async {
      await connectSuccessfully(xmppService);

      final peerJid = chatJids.first;
      final messageTimestamp = DateTime.utc(2024, 1, 2, 10);
      final snapshotTimestamp = DateTime.utc(2024, 1, 2, 12);

      await database.createChat(
        Chat.fromJid(peerJid).copyWith(
          lastMessage: 'FWD: stale@example.com',
          lastChangeTimestamp: DateTime.utc(2024, 1, 2, 9),
        ),
      );
      await database.saveMessage(
        Message(
          stanzaID: 'repair-subtitle-1',
          senderJid: peerJid,
          chatJid: peerJid,
          timestamp: messageTimestamp,
          body: 'Newest stored body',
          encryptionProtocol: EncryptionProtocol.none,
        ),
      );
      final chat = await database.getChat(peerJid);
      await database.updateChat(
        chat!.copyWith(lastMessage: 'FWD: stale@example.com'),
      );

      await xmppService.applyConversationIndexSnapshot((
        items: <ConvItem>[
          ConvItem(
            peerBare: mox.JID.fromString(peerJid),
            lastTimestamp: snapshotTimestamp,
          ),
        ],
        isSuccess: true,
        isComplete: true,
      ));

      final repaired = await database.getChat(peerJid);
      expect(repaired?.lastMessage, 'Newest stored body');
      expect(repaired?.lastChangeTimestamp, snapshotTimestamp);
    },
  );

  group('openChat', () {
    test('Opens the given chat.', () async {
      await connectSuccessfully(xmppService);
      clearInteractions(mockConnection);

      when(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});

      await xmppService.openChat(jid);

      await pumpEventQueue();

      final chat = await database.getChat(jid);
      expect(chat?.open, isTrue);

      verify(
        () =>
            mockConnection.sendChatState(jid: jid, state: mox.ChatState.active),
      ).called(1);
    });

    test(
      'Creating a direct XMPP chat waits for snapshot resolution before publishing.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);
        clearInteractions(mockConnection);

        await xmppService.openChat(peerJid);
        await pumpEventQueue();

        verifyNever(() => mockConnection.sendStanza(any()));

        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
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
      },
    );

    test(
      'Creating a blank direct XMPP chat uses the empty timestamp baseline.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});

        await xmppService.openChat(peerJid);
        await pumpEventQueue();

        final chat = await database.getChat(peerJid);
        expect(chat, isNotNull);
        expect(
          chat?.lastChangeTimestamp,
          DateTime.fromMillisecondsSinceEpoch(0),
        );
      },
    );

    test(
      'A snapshot-backed direct XMPP chat seed is not republished.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);

        await xmppService.openChat(peerJid);
        await pumpEventQueue();
        clearInteractions(mockConnection);

        await xmppService.applyConversationIndexSnapshot((
          items: <ConvItem>[
            ConvItem(
              peerBare: mox.JID.fromString(peerJid).toBare(),
              lastTimestamp: DateTime.utc(2024, 1, 1, 10),
            ),
          ],
          isSuccess: true,
          isComplete: true,
        ));
        await pumpEventQueue();

        verifyNever(() => mockConnection.sendStanza(any()));
      },
    );

    test(
      'A complete snapshot backfills an existing local direct XMPP chat that is missing remotely.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);
        await database.createChat(
          Chat.fromJid(peerJid).copyWith(archived: false),
        );
        clearInteractions(mockConnection);

        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
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

        final chat = await database.getChat(peerJid);
        expect(chat?.archived, isFalse);
      },
    );

    test(
      'A failed direct XMPP chat seed remains pending for the next snapshot flush.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        var publishAttempts = 0;
        when(() => mockConnection.sendStanza(any())).thenAnswer((_) async {
          publishAttempts++;
          return publishAttempts == 1
              ? mox.Stanza.iq(type: 'error')
              : mox.Stanza.iq(type: 'result');
        });
        await mockConnection.registerManagers([ConversationIndexManager()]);
        clearInteractions(mockConnection);

        await xmppService.openChat(peerJid);
        await pumpEventQueue();

        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
        await pumpEventQueue();
        expect(publishAttempts, 1);

        await xmppService.applyConversationIndexSnapshot(const (
          items: <ConvItem>[],
          isSuccess: true,
          isComplete: true,
        ));
        await pumpEventQueue();
        expect(publishAttempts, 2);
      },
    );

    test(
      'Opening an existing direct XMPP chat does not publish a conversation index entry.',
      () async {
        final peerJid = mox.JID.fromString(jid).toBare().toString();
        await connectSuccessfully(xmppService);

        when(
          () => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => mockConnection.sendStanza(any()),
        ).thenAnswer((_) async => mox.Stanza.iq(type: 'result'));
        await mockConnection.registerManagers([ConversationIndexManager()]);
        await database.createChat(Chat.fromJid(peerJid));
        clearInteractions(mockConnection);

        await xmppService.openChat(peerJid);
        await pumpEventQueue();

        verifyNever(() => mockConnection.sendStanza(any()));
      },
    );

    test('If a different chat is already open, closes it.', () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});

      final existingChatJid = generateRandomJid();

      await database.createChat(Chat.fromJid(existingChatJid));
      await database.openChat(existingChatJid);

      final beforeOpen = await database.getChat(jid);
      expect(beforeOpen, isNull);

      var existingChat = await database.getChat(existingChatJid);
      expect(existingChat?.open, isTrue);

      await xmppService.openChat(jid);

      await pumpEventQueue();

      final afterOpen = await database.getChat(jid);
      expect(afterOpen?.open, isTrue);

      existingChat = await database.getChat(existingChatJid);
      expect(existingChat?.open, isFalse);

      verify(
        () => mockConnection.sendChatState(
          jid: existingChatJid,
          state: mox.ChatState.inactive,
        ),
      ).called(1);
    });

    test('Opening the local welcome chat does not send chat state.', () async {
      await connectSuccessfully(xmppService);
      clearInteractions(mockConnection);

      when(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});

      const welcomeJid = 'axichat@welcome.axichat.invalid';
      await xmppService.openChat(welcomeJid);

      await pumpEventQueue();

      final chat = await database.getChat(welcomeJid);
      expect(chat?.open, isTrue);
      verifyNever(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      );
    });
  });

  test('closeChat closes any open chats.', () async {
    await connectSuccessfully(xmppService);

    when(
      () => mockConnection.sendChatState(
        jid: any(named: 'jid'),
        state: any(named: 'state'),
      ),
    ).thenAnswer((_) async {});

    await database.createChat(Chat.fromJid(jid));
    await database.openChat(jid);

    final beforeClose = await database.getChat(jid);
    expect(beforeClose?.open, isTrue);

    await xmppService.closeChat();

    await pumpEventQueue();

    final afterClose = await database.getChat(jid);
    expect(afterClose?.open, isFalse);

    verify(
      () =>
          mockConnection.sendChatState(jid: jid, state: mox.ChatState.inactive),
    ).called(1);
  });

  test(
    'closeChat does not send chat state for the local welcome chat.',
    () async {
      await connectSuccessfully(xmppService);

      when(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      ).thenAnswer((_) async {});

      const welcomeJid = 'axichat@welcome.axichat.invalid';
      await database.createChat(Chat.fromJid(welcomeJid));
      await database.openChat(welcomeJid);
      clearInteractions(mockConnection);

      await xmppService.closeChat();

      await pumpEventQueue();

      final afterClose = await database.getChat(welcomeJid);
      expect(afterClose?.open, isFalse);
      verifyNever(
        () => mockConnection.sendChatState(
          jid: any(named: 'jid'),
          state: any(named: 'state'),
        ),
      );
    },
  );

  test(
    'MUCManager.sendAdminIq throws when the server rejects the admin IQ',
    () async {
      final manager = MUCManager()
        ..register(
          _buildManagerAttributes(
            sendStanza: (_) async => mox.Stanza.iq(type: 'error'),
          ),
        );

      await expectLater(
        manager.sendAdminIq(
          roomJid: 'room@conference.example.com',
          items: [
            mox.XMLNode(
              tag: 'item',
              attributes: {
                'jid': 'invitee@example.com',
                'affiliation': 'member',
              },
            ),
          ],
        ),
        throwsA(isA<XmppMessageException>()),
      );
    },
  );
}
