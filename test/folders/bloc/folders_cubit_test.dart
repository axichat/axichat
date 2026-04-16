import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
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
  late StreamController<List<FolderMessageItem>> foldersController;

  setUp(() {
    xmppService = MockXmppService();
    foldersController = StreamController<List<FolderMessageItem>>.broadcast();

    when(
      () => xmppService.messageCollectionItemsStream(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) => foldersController.stream);
  });

  tearDown(() async {
    await foldersController.close();
  });

  test('filters only the active folder items for the current query', () async {
    const chatJid = 'peer@axi.im';
    final items = <FolderMessageItem>[
      FolderMessageItem(
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
        message: Message(
          stanzaID: 'important-match',
          senderJid: chatJid,
          chatJid: chatJid,
          body: 'Unique body match in an important message',
          timestamp: DateTime.utc(2026, 3, 12, 10),
        ),
        chat: Chat(
          jid: chatJid,
          title: 'General chat',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 3, 12, 11),
        ),
      ),
      FolderMessageItem(
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
        message: Message(
          stanzaID: 'important-other',
          senderJid: chatJid,
          chatJid: chatJid,
          body: 'Different content',
          timestamp: DateTime.utc(2026, 3, 12, 11),
        ),
        chat: Chat(
          jid: chatJid,
          title: 'General chat',
          type: ChatType.chat,
          lastChangeTimestamp: DateTime.utc(2026, 3, 12, 11),
        ),
      ),
    ];

    final cubit = FoldersCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    foldersController.add(items);
    await pumpEventQueue();

    expect(cubit.state.folder, FolderCollection.important);
    expect(cubit.state.visibleItems, hasLength(2));

    cubit.updateCriteria(
      query: 'unique body match',
      sortOrder: SearchSortOrder.newestFirst,
    );

    expect(cubit.state.visibleItems, hasLength(1));
    expect(
      cubit.state.visibleItems?.single.messageReferenceId,
      'important-match',
    );
  });
}
