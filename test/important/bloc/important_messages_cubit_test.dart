import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/important/bloc/important_messages_cubit.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<String>{});
  });

  late MockXmppService xmppService;
  late StreamController<List<MessageCollectionMembershipEntry>>
  importantController;

  setUp(() {
    xmppService = MockXmppService();
    importantController =
        StreamController<List<MessageCollectionMembershipEntry>>.broadcast();

    when(
      () => xmppService.importantMessagesStream(chatJid: any(named: 'chatJid')),
    ).thenAnswer((_) => importantController.stream);
  });

  tearDown(() async {
    await importantController.close();
  });

  test(
    'filters only the important message items for the active query',
    () async {
      const chatJid = 'peer@axi.im';
      final entries = <MessageCollectionMembershipEntry>[
        MessageCollectionMembershipEntry(
          collectionId: SystemMessageCollection.important.id,
          chatJid: chatJid,
          messageReferenceId: 'important-match',
          messageStanzaId: 'important-match',
          messageOriginId: null,
          messageMucStanzaId: null,
          deltaAccountId: null,
          deltaMsgId: null,
          addedAt: DateTime.utc(2026, 3, 12, 10),
          active: true,
        ),
        MessageCollectionMembershipEntry(
          collectionId: SystemMessageCollection.important.id,
          chatJid: chatJid,
          messageReferenceId: 'important-other',
          messageStanzaId: 'important-other',
          messageOriginId: null,
          messageMucStanzaId: null,
          deltaAccountId: null,
          deltaMsgId: null,
          addedAt: DateTime.utc(2026, 3, 12, 11),
          active: true,
        ),
      ];
      final messages = <Message>[
        Message(
          stanzaID: 'important-match',
          senderJid: chatJid,
          chatJid: chatJid,
          body: 'Unique body match in an important message',
          timestamp: DateTime.utc(2026, 3, 12, 10),
        ),
        Message(
          stanzaID: 'important-other',
          senderJid: chatJid,
          chatJid: chatJid,
          body: 'Different content',
          timestamp: DateTime.utc(2026, 3, 12, 11),
        ),
      ];
      final chats = <Chat>[
        Chat(
          jid: chatJid,
          title: 'General chat',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 3, 12, 11),
        ),
      ];

      when(
        () => xmppService.loadMessagesByReferenceIds(
          any(),
          chatJid: any(named: 'chatJid'),
        ),
      ).thenAnswer((_) async => messages);
      when(
        () => xmppService.loadChatsByJids(any()),
      ).thenAnswer((_) async => chats);

      final cubit = ImportantMessagesCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      importantController.add(entries);
      await pumpEventQueue();

      expect(cubit.state.visibleItems, hasLength(2));

      cubit.updateFilter(
        query: 'unique body match',
        sortOrder: SearchSortOrder.newestFirst,
      );

      expect(cubit.state.visibleItems, hasLength(1));
      expect(
        cubit.state.visibleItems?.single.messageReferenceId,
        'important-match',
      );
    },
  );
}
