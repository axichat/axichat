import 'dart:async';

import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/xmpp_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

class MockXmppMucService extends Mock implements XmppService, MucService {}

Chat _chat({
  required String jid,
  required String title,
  required DateTime timestamp,
  bool spam = false,
  bool favorited = false,
  DateTime? spamUpdatedAt,
  ChatPrimaryView primaryView = ChatPrimaryView.chat,
  MessageTransport transport = MessageTransport.xmpp,
}) {
  return Chat(
    jid: jid,
    title: title,
    type: ChatType.chat,
    primaryView: primaryView,
    lastChangeTimestamp: timestamp,
    transport: transport,
    spam: spam,
    favorited: favorited,
    spamUpdatedAt: spamUpdatedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late StreamController<List<Chat>> chatsStreamController;

  setUp(() {
    xmppService = MockXmppService();
    chatsStreamController = StreamController<List<Chat>>.broadcast();

    when(
      () => xmppService.chatsStream(),
    ).thenAnswer((_) => chatsStreamController.stream);
    when(
      () => xmppService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => xmppService.cachedChatList).thenReturn(const <Chat>[]);
  });

  tearDown(() async {
    await chatsStreamController.close();
  });

  test('spam search filters and query are applied in cubit', () async {
    final now = DateTime(2024, 1, 1);
    final items = <Chat>[
      _chat(
        jid: 'email@example.com',
        title: 'Spam Email',
        timestamp: now,
        spam: true,
        transport: MessageTransport.email,
      ),
      _chat(jid: 'xmpp@axi.im', title: 'Spam Xmpp', timestamp: now, spam: true),
      _chat(
        jid: 'notspam@axi.im',
        title: 'Not Spam',
        timestamp: now,
        spam: false,
      ),
    ];
    when(() => xmppService.cachedChatList).thenReturn(items);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    cubit.updateSpamSearchSnapshot(
      active: true,
      query: 'email',
      filterId: SearchFilterId.email,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.spamVisibleItems.length, 1);
    expect(cubit.state.spamVisibleItems.single.jid, 'email@example.com');
  });

  test('spam list uses spamUpdatedAt for sorting', () async {
    final now = DateTime(2024, 1, 1, 12, 0);
    final older = DateTime(2024, 1, 1, 10, 0);
    final newer = DateTime(2024, 1, 1, 14, 0);
    final items = <Chat>[
      _chat(
        jid: 'first@example.com',
        title: 'First',
        timestamp: older,
        spam: true,
        spamUpdatedAt: newer,
      ),
      _chat(
        jid: 'second@example.com',
        title: 'Second',
        timestamp: now,
        spam: true,
      ),
    ];
    when(() => xmppService.cachedChatList).thenReturn(items);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    cubit.updateSpamSearchSnapshot(
      active: false,
      query: '',
      filterId: SearchFilterId.all,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.spamVisibleItems.first.jid, 'first@example.com');
  });

  test('visible chats keep favorites at the top', () async {
    final now = DateTime(2024, 1, 1, 12, 0);
    final items = <Chat>[
      _chat(
        jid: 'newest@axi.im',
        title: 'Newest',
        timestamp: now.add(const Duration(hours: 1)),
      ),
      _chat(
        jid: 'favorite@axi.im',
        title: 'Favorite',
        timestamp: now,
        favorited: true,
      ),
    ];
    when(() => xmppService.cachedChatList).thenReturn(items);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    expect(cubit.state.visibleItems.first.jid, 'favorite@axi.im');
  });

  test('stored details route falls back to main without a focused message', () {
    expect(
      resolveStoredChatRoute(
        route: ChatRouteIndex.details,
        hasChat: true,
        hasFocusedMessage: false,
      ),
      ChatRouteIndex.main,
    );
  });

  test('stored details route is preserved when the focused message exists', () {
    expect(
      resolveStoredChatRoute(
        route: ChatRouteIndex.details,
        hasChat: true,
        hasFocusedMessage: true,
      ),
      ChatRouteIndex.details,
    );
  });

  test(
    'stored calendar route is preserved while the chat is still loading',
    () {
      expect(
        resolveStoredChatRoute(
          route: ChatRouteIndex.calendar,
          hasChat: false,
          hasFocusedMessage: false,
        ),
        ChatRouteIndex.calendar,
      );
    },
  );

  test(
    'opening an important message keeps the target reference in state',
    () async {
      when(() => xmppService.openChat(any())).thenAnswer((_) async {});

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      await cubit.openImportantMessage(
        jid: 'friend@axi.im',
        messageReferenceId: 'important-reference',
      );

      expect(cubit.state.openJid, 'friend@axi.im');
      expect(cubit.state.pendingOpenMessageChatJid, 'friend@axi.im');
      expect(cubit.state.pendingOpenMessageReferenceId, 'important-reference');
      expect(cubit.state.pendingOpenMessageRequestId, 1);
    },
  );

  test(
    'opening a calendar-first room defaults to the calendar route',
    () async {
      final room = _chat(
        jid: 'planning@conference.axi.im',
        title: 'Planning',
        timestamp: DateTime(2024, 1, 1),
        primaryView: ChatPrimaryView.calendar,
      ).copyWith(type: ChatType.groupChat);
      when(() => xmppService.cachedChatList).thenReturn([room]);
      when(() => xmppService.openChat(any())).thenAnswer((_) async {});

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      await cubit.openChat(jid: room.jid);

      expect(cubit.state.openJid, room.jid);
      expect(cubit.state.openChatRoute, ChatRouteIndex.calendar);
      expect(cubit.state.openChatCalendar, isTrue);
    },
  );

  test(
    'opening a room before chat hydration resolves to calendar when metadata arrives',
    () async {
      final room = _chat(
        jid: 'planning@conference.axi.im',
        title: 'Planning',
        timestamp: DateTime(2024, 1, 1),
        primaryView: ChatPrimaryView.calendar,
      ).copyWith(type: ChatType.groupChat);
      when(() => xmppService.openChat(any())).thenAnswer((_) async {});

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      await cubit.openChat(jid: room.jid);
      expect(cubit.state.openChatRoute, ChatRouteIndex.main);

      chatsStreamController.add([room]);
      await pumpEventQueue();

      expect(cubit.state.openJid, room.jid);
      expect(cubit.state.openChatRoute, ChatRouteIndex.calendar);
      expect(cubit.state.openChatCalendar, isTrue);
    },
  );

  test(
    'explicit main route is preserved when calendar metadata arrives later',
    () async {
      final room = _chat(
        jid: 'planning@conference.axi.im',
        title: 'Planning',
        timestamp: DateTime(2024, 1, 1),
        primaryView: ChatPrimaryView.calendar,
      ).copyWith(type: ChatType.groupChat);
      when(() => xmppService.openChat(any())).thenAnswer((_) async {});

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      await cubit.openChat(jid: room.jid, route: ChatRouteIndex.main);

      chatsStreamController.add([room]);
      await pumpEventQueue();

      expect(cubit.state.openJid, room.jid);
      expect(cubit.state.openChatRoute, ChatRouteIndex.main);
      expect(cubit.state.openChatCalendar, isFalse);
    },
  );

  test('create room conflict surfaces alreadyExists failure state', () async {
    final xmppMucService = MockXmppMucService();
    when(
      () => xmppMucService.chatsStream(),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppMucService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => xmppMucService.cachedChatList).thenReturn(const <Chat>[]);
    when(
      () => xmppMucService.createRoom(
        name: any(named: 'name'),
        nickname: any(named: 'nickname'),
        avatar: any(named: 'avatar'),
        primaryView: ChatPrimaryView.chat,
      ),
    ).thenThrow(XmppMucCreateConflictException());

    final cubit = ChatsCubit(xmppService: xmppMucService);
    addTearDown(cubit.close);

    await cubit.createChatRoom(title: 'Roomy');

    expect(cubit.state.creationStatus.isFailure, isTrue);
    expect(cubit.state.creationFailure, ChatsCreateRoomFailure.alreadyExists);
  });

  test('create room forwards the selected primary view', () async {
    final xmppMucService = MockXmppMucService();
    when(
      () => xmppMucService.chatsStream(),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppMucService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(() => xmppMucService.cachedChatList).thenReturn(const <Chat>[]);
    when(
      () => xmppMucService.createRoom(
        name: 'Roadmap',
        nickname: null,
        avatar: null,
        primaryView: ChatPrimaryView.calendar,
      ),
    ).thenAnswer((_) async => 'roadmap@conference.axi.im');
    when(() => xmppMucService.openChat(any())).thenAnswer((_) async {});

    final cubit = ChatsCubit(xmppService: xmppMucService);
    addTearDown(cubit.close);

    await cubit.createChatRoom(
      title: 'Roadmap',
      primaryView: ChatPrimaryView.calendar,
    );

    verify(
      () => xmppMucService.createRoom(
        name: 'Roadmap',
        nickname: null,
        avatar: null,
        primaryView: ChatPrimaryView.calendar,
      ),
    ).called(1);
  });
}
