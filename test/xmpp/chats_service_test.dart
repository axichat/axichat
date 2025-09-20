import 'dart:io';

import 'package:axichat/main.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart' hide uuid;
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

main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  withForeground = false;

  setUpAll(() {
    registerFallbackValue(FakeCredentialKey());
    registerFallbackValue(FakeStateKey());
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
        final chats = chatJids.map((e) => Chat.fromJid(e)).toList();

        expectLater(
          xmppService.chatsStream(),
          emitsInOrder([
            [],
            ...List.generate(
              chatJids.length,
              (index) => ChatsService.sortChats(
                chats.sublist(0, index),
              ).map((e) => ChatMatcher(e)).toList(),
            )
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

        final chats = ChatsService.sortChats(await database.getChats(
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

      when(() => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          )).thenAnswer((_) async {});

      const state = mox.ChatState.active;
      await xmppService.sendChatState(jid: jid, state: state);

      verify(
        () => mockConnection.sendChatState(jid: jid, state: state),
      ).called(1);
    },
  );

  group('openChat', () {
    test('Opens the given chat.', () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          )).thenAnswer((_) async {});

      await xmppService.openChat(jid);

      await pumpEventQueue();

      final chat = await database.getChat(jid);
      expect(chat?.open, isTrue);

      verify(() => mockConnection.sendChatState(
            jid: jid,
            state: mox.ChatState.active,
          )).called(1);
    });

    test(
      'If a different chat is already open, closes it.',
      () async {
        await connectSuccessfully(xmppService);

        when(() => mockConnection.sendChatState(
              jid: any(named: 'jid'),
              state: any(named: 'state'),
            )).thenAnswer((_) async {});

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

        verify(() => mockConnection.sendChatState(
              jid: existingChatJid,
              state: mox.ChatState.inactive,
            )).called(1);
      },
    );
  });

  test(
    'closeChat closes any open chats.',
    () async {
      await connectSuccessfully(xmppService);

      when(() => mockConnection.sendChatState(
            jid: any(named: 'jid'),
            state: any(named: 'state'),
          )).thenAnswer((_) async {});

      await database.createChat(Chat.fromJid(jid));
      await database.openChat(jid);

      final beforeClose = await database.getChat(jid);
      expect(beforeClose?.open, isTrue);

      await xmppService.closeChat();

      await pumpEventQueue();

      final afterClose = await database.getChat(jid);
      expect(afterClose?.open, isFalse);

      verify(() => mockConnection.sendChatState(
            jid: jid,
            state: mox.ChatState.inactive,
          )).called(1);
    },
  );
}
