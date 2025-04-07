import 'dart:io';

import 'package:chat/src/storage/database.dart';
import 'package:chat/src/storage/models.dart' hide uuid;
import 'package:chat/src/xmpp/xmpp_service.dart';
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
    a.favourited == b.favourited &&
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

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
    registerFallbackValue(mox.ChatState.active);
    registerFallbackValue(FakeUserAgent());
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
      buildStateStore: (_, __) => mockStateStore,
      buildDatabase: (_, __) => database,
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
        expectLater(
          xmppService.chatsStream(),
          emitsInOrder([
            [],
            ...List.generate(
              chatJids.length,
              (index) => sortChats(
                chatJids.sublist(0, index).map((e) => Chat.fromJid(e)).toList(),
              ).reversed.map((e) => ChatMatcher(e)).toList(),
            )
          ]),
        );

        await connectSuccessfully(xmppService);

        for (final jid in chatJids) {
          await pumpEventQueue();
          await database.createChat(jid);
        }
      },
    );

    test(
      'When messages are edited in the chat\'s database, emits the updated message history in order.',
      () async {
        await connectSuccessfully(xmppService);

        for (final jid in chatJids) {
          await database.createChat(jid);
        }

        await pumpEventQueue();

        final chats = sortChats(await database.getChats(
          start: 0,
          end: double.maxFinite.toInt(),
        ));

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
          favourited: true,
          lastChangeTimestamp: DateTime.now().add(const Duration(seconds: 3)),
        );

        expectLater(
          xmppService.chatsStream(),
          emitsInOrder([
            chats.map((e) => ChatMatcher(e)).toList(),
            chats.map((e) => ChatMatcher(e)).toList(),
            sortChats([
              chats0,
              ...chats.sublist(1),
            ]).map((e) => ChatMatcher(e)).toList(),
            sortChats([
              chats0,
              chats1,
              ...chats.sublist(2),
            ]).map((e) => ChatMatcher(e)).toList(),
            sortChats([
              chats0,
              chats1,
              chats2,
              ...chats.sublist(3),
            ]).map((e) => ChatMatcher(e)).toList(),
            sortChats([
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

      when(() => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          )).thenAnswer((_) async {});

      const state = mox.ChatState.active;
      await xmppService.sendChatState(jid: jid, state: state);

      verify(
        () => mockConnection.sendChatState(
          jid: jid,
          state: state,
        ),
      ).called(1);
    },
  );
}
