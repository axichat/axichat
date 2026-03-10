import 'dart:async';

import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/request_status.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/home/service/home_refresh_sync_service.dart';
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
  DateTime? spamUpdatedAt,
}) {
  return Chat(
    jid: jid,
    title: title,
    type: ChatType.chat,
    lastChangeTimestamp: timestamp,
    spam: spam,
    spamUpdatedAt: spamUpdatedAt,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockXmppService xmppService;
  late MockHomeRefreshSyncService homeRefreshSyncService;
  late StreamController<List<Chat>> chatsStreamController;

  setUp(() {
    xmppService = MockXmppService();
    homeRefreshSyncService = MockHomeRefreshSyncService();
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
    when(
      () => homeRefreshSyncService.syncUpdates,
    ).thenAnswer((_) => const Stream<HomeRefreshSyncUpdate>.empty());
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

    final cubit = ChatsCubit(
      xmppService: xmppService,
      homeRefreshSyncService: homeRefreshSyncService,
    );
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

    final cubit = ChatsCubit(
      xmppService: xmppService,
      homeRefreshSyncService: homeRefreshSyncService,
    );
    addTearDown(cubit.close);

    cubit.updateSpamSearchSnapshot(
      active: false,
      query: '',
      filterId: SearchFilterId.all,
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.spamVisibleItems.first.jid, 'first@example.com');
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
      ),
    ).thenThrow(XmppMucCreateConflictException());

    final cubit = ChatsCubit(
      xmppService: xmppMucService,
      homeRefreshSyncService: homeRefreshSyncService,
    );
    addTearDown(cubit.close);

    await cubit.createChatRoom(title: 'Roomy');

    expect(cubit.state.creationStatus.isFailure, isTrue);
    expect(cubit.state.creationFailure, ChatsCreateRoomFailure.alreadyExists);
  });
}
