import 'dart:async';

import 'package:axichat/src/chats/bloc/chats_cubit.dart';
import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

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
}
