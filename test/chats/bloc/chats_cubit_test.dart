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
  int unreadCount = 0,
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
    unreadCount: unreadCount,
    spamUpdatedAt: spamUpdatedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late StreamController<List<Chat>> chatsStreamController;
  late StreamController<Map<String, String>> contactFolderRulesController;

  setUp(() {
    xmppService = MockXmppService();
    chatsStreamController = StreamController<List<Chat>>.broadcast();
    contactFolderRulesController =
        StreamController<Map<String, String>>.broadcast();

    when(
      () => xmppService.chatsStream(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => chatsStreamController.stream);
    when(
      () => xmppService.homeChatsStream(recentLimit: any(named: 'recentLimit')),
    ).thenAnswer((_) => chatsStreamController.stream);
    when(
      () => xmppService.allChatsStream(),
    ).thenAnswer((_) => chatsStreamController.stream);
    when(
      () => xmppService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => xmppService.contactFolderRulesStream(),
    ).thenAnswer((_) => contactFolderRulesController.stream);
    when(() => xmppService.cachedChatList).thenReturn(const <Chat>[]);
  });

  tearDown(() async {
    await chatsStreamController.close();
    await contactFolderRulesController.close();
  });

  test('loadMoreChats increases the subscribed chat window', () async {
    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    chatsStreamController.add(
      List.generate(
        50,
        (index) => _chat(
          jid: 'chat-$index@axi.im',
          title: 'Chat $index',
          timestamp: DateTime(2024, 1, 1).add(Duration(minutes: index)),
        ),
      ),
    );
    await pumpEventQueue();

    await cubit.loadMoreChats();

    verify(() => xmppService.homeChatsStream(recentLimit: 50)).called(1);
    verify(() => xmppService.homeChatsStream(recentLimit: 100)).called(1);
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

  test('spam filter does not stay applied when search is hidden', () async {
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
    ];
    when(() => xmppService.cachedChatList).thenReturn(items);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    cubit.updateSpamSearchSnapshot(
      active: true,
      query: '',
      filterId: SearchFilterId.email,
      sortOrder: SearchSortOrder.newestFirst,
    );
    expect(cubit.state.spamVisibleItems.map((chat) => chat.jid), [
      'email@example.com',
    ]);

    cubit.updateSpamSearchSnapshot(
      active: false,
      query: '',
      filterId: SearchFilterId.email,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(
      cubit.state.spamVisibleItems.map((chat) => chat.jid),
      containsAll(<String>['email@example.com', 'xmpp@axi.im']),
    );
  });

  test(
    'resetChatSettingOverrides scopes optimistic reset to target chats',
    () async {
      final now = DateTime(2026, 5, 19);
      final target = _chat(
        jid: 'Target@Example.com',
        title: 'Target',
        timestamp: now,
      ).copyWith(markerResponsive: true, emailReadReceiptsEnabled: false);
      final other = _chat(
        jid: 'other@example.com',
        title: 'Other',
        timestamp: now,
      ).copyWith(markerResponsive: true, emailReadReceiptsEnabled: false);
      when(() => xmppService.cachedChatList).thenReturn([target, other]);
      when(
        () => xmppService.resetChatSettingOverrides(
          ChatSettingId.emailReadReceipts,
          chatJids: any(named: 'chatJids'),
        ),
      ).thenAnswer((_) async => (localApplied: true, published: true));

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      await cubit.resetChatSettingOverrides(
        ChatSettingId.emailReadReceipts,
        chatJids: const ['target@example.com'],
      );

      final updatedTarget = cubit.state.items?.firstWhere(
        (chat) => chat.jid == target.jid,
      );
      final unchangedOther = cubit.state.items?.firstWhere(
        (chat) => chat.jid == other.jid,
      );
      expect(updatedTarget?.emailReadReceiptsEnabled, isNull);
      expect(updatedTarget?.markerResponsive, isTrue);
      expect(unchangedOther?.emailReadReceiptsEnabled, isFalse);
      expect(unchangedOther?.markerResponsive, isTrue);
    },
  );

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

  test(
    'visible chats sort by last change before favorite or unread state',
    () async {
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
          unreadCount: 3,
        ),
      ];
      when(() => xmppService.cachedChatList).thenReturn(items);

      final cubit = ChatsCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      expect(cubit.state.visibleItems.map((chat) => chat.jid), [
        'newest@axi.im',
        'favorite@axi.im',
      ]);
    },
  );

  test('axi.im server announcements count as contacts in chat filters', () {
    final now = DateTime(2024, 1, 1, 12);
    when(() => xmppService.cachedChatList).thenReturn([
      _chat(jid: 'axi.im', title: 'axi.im', timestamp: now),
      _chat(jid: 'stranger@example.com', title: 'Stranger', timestamp: now),
    ]);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    cubit.updateSearchSnapshot(
      active: true,
      query: '',
      filterId: SearchFilterId.contacts,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.visibleItems.map((chat) => chat.jid), ['axi.im']);

    cubit.updateSearchSnapshot(
      active: true,
      query: '',
      filterId: SearchFilterId.nonContacts,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.visibleItems.map((chat) => chat.jid), [
      'stranger@example.com',
    ]);
  });

  test('contact folder filters match contact rules only', () async {
    final now = DateTime(2024, 1, 1, 12);
    final importantChat = _chat(
      jid: 'alpha@example.com',
      title: 'Alpha',
      timestamp: now,
    );
    final explicitOnlyChat = _chat(
      jid: 'beta@example.com',
      title: 'Beta',
      timestamp: now.add(const Duration(minutes: 1)),
    );
    when(
      () => xmppService.cachedChatList,
    ).thenReturn([importantChat, explicitOnlyChat]);

    final cubit = ChatsCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    contactFolderRulesController.add({
      'alpha@example.com': SystemMessageCollection.important.id,
    });
    await pumpEventQueue();

    cubit.updateSearchSnapshot(
      active: true,
      query: '',
      filterId: SearchFilterId.contactFolderImportant,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.visibleItems.map((chat) => chat.jid), [
      'alpha@example.com',
    ]);
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
    'stored settings route is preserved while the chat is still loading',
    () {
      expect(
        resolveStoredChatRoute(
          route: ChatRouteIndex.settings,
          hasChat: false,
          hasFocusedMessage: false,
        ),
        ChatRouteIndex.settings,
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
      () => xmppMucService.chatsStream(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.homeChatsStream(
        recentLimit: any(named: 'recentLimit'),
      ),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppMucService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => xmppMucService.contactFolderRulesStream(),
    ).thenAnswer((_) => const Stream<Map<String, String>>.empty());
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
      () => xmppMucService.chatsStream(
        start: any(named: 'start'),
        end: any(named: 'end'),
      ),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.homeChatsStream(
        recentLimit: any(named: 'recentLimit'),
      ),
    ).thenAnswer((_) => const Stream<List<Chat>>.empty());
    when(
      () => xmppMucService.recipientAddressSuggestionsStream(),
    ).thenAnswer((_) => const Stream<List<String>>.empty());
    when(
      () => xmppMucService.demoResetStream,
    ).thenAnswer((_) => const Stream<void>.empty());
    when(
      () => xmppMucService.contactFolderRulesStream(),
    ).thenAnswer((_) => const Stream<Map<String, String>>.empty());
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
