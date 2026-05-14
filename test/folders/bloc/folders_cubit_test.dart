import 'dart:async';

import 'package:axichat/src/common/search/search_models.dart';
import 'package:axichat/src/folders/bloc/folders_cubit.dart';
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
  late StreamController<List<FolderMessageItem>> foldersController;
  late StreamController<List<MessageCollectionEntry>> collectionsController;
  late StreamController<List<MessageCollectionMembershipEntry>>
  membershipsController;
  late StreamController<Map<String, String>> contactFolderRulesController;

  setUp(() {
    xmppService = MockXmppService();
    foldersController = StreamController<List<FolderMessageItem>>.broadcast();
    collectionsController =
        StreamController<List<MessageCollectionEntry>>.broadcast();
    membershipsController =
        StreamController<List<MessageCollectionMembershipEntry>>.broadcast();
    contactFolderRulesController =
        StreamController<Map<String, String>>.broadcast();

    when(
      () => xmppService.messageCollectionItemsStream(
        any(),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) => foldersController.stream);
    when(
      () => xmppService.messageCollectionsStream(
        includeInactive: any(named: 'includeInactive'),
        includeSystem: any(named: 'includeSystem'),
      ),
    ).thenAnswer((_) => collectionsController.stream);
    when(
      () => xmppService.allMessageCollectionMembershipsStream(
        includeInactive: any(named: 'includeInactive'),
        chatJid: any(named: 'chatJid'),
      ),
    ).thenAnswer((_) => membershipsController.stream);
    when(
      () => xmppService.contactFolderRulesStream(),
    ).thenAnswer((_) => contactFolderRulesController.stream);
  });

  tearDown(() async {
    await foldersController.close();
    await collectionsController.close();
    await membershipsController.close();
    await contactFolderRulesController.close();
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

    expect(cubit.state.collectionId, SystemMessageCollection.important.id);
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

  test('createFolder emits terminal success state', () async {
    final collection = MessageCollectionEntry(
      id: 'Projects',
      title: null,
      isSystem: false,
      sortOrder: 0,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
      active: true,
    );
    when(
      () => xmppService.createMessageCollection(title: 'Projects'),
    ).thenAnswer((_) async => collection);

    final cubit = FoldersCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    expect(await cubit.createFolder('Projects'), collection);
    expect(
      cubit.state.actionState,
      const FoldersActionSuccess(
        action: FoldersActionType.createFolder,
        collectionId: 'Projects',
      ),
    );
  });

  test('createFolder emits terminal name failure state', () async {
    when(
      () => xmppService.createMessageCollection(title: 'Projects'),
    ).thenThrow(
      const MessageCollectionNameException(
        MessageCollectionNameFailure.duplicate,
      ),
    );

    final cubit = FoldersCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    expect(await cubit.createFolder('Projects'), isNull);
    expect(
      cubit.state.actionState,
      const FoldersActionFailure(
        action: FoldersActionType.createFolder,
        reason: FoldersFailureReason.invalidName,
        nameFailure: MessageCollectionNameFailure.duplicate,
      ),
    );
  });

  test(
    'removeItem emits terminal failure when service cannot remove',
    () async {
      final item = FolderMessageItem(
        collectionId: 'Projects',
        chatJid: 'peer@axi.im',
        messageReferenceId: 'message-1',
        messageStanzaId: 'message-1',
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: DateTime.utc(2026),
        active: true,
        message: null,
        chat: null,
      );
      when(
        () => xmppService.removeMessageCollectionMembership(item),
      ).thenAnswer((_) async => false);

      final cubit = FoldersCubit(xmppService: xmppService);
      addTearDown(cubit.close);

      expect(await cubit.removeItem(item), isFalse);
      expect(
        cubit.state.actionState,
        const FoldersActionFailure(
          action: FoldersActionType.removeMembership,
          reason: FoldersFailureReason.removeFailed,
          collectionId: 'Projects',
          chatJid: 'peer@axi.im',
          messageReferenceId: 'message-1',
        ),
      );
    },
  );

  test('exposes explicit and rule-derived folder ids separately', () async {
    final chat = Chat(
      jid: 'alpha@example.com',
      title: 'Alpha',
      type: ChatType.chat,
      lastChangeTimestamp: DateTime.utc(2026),
    );
    final message = Message(
      stanzaID: 'message-1',
      senderJid: 'alpha@example.com',
      chatJid: 'alpha@example.com',
    );

    final cubit = FoldersCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    collectionsController.add([
      MessageCollectionEntry(
        id: SystemMessageCollection.important.id,
        title: null,
        isSystem: true,
        sortOrder: 0,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        active: true,
      ),
      MessageCollectionEntry(
        id: SystemMessageCollection.receipts.id,
        title: null,
        isSystem: true,
        sortOrder: 1,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
        active: true,
      ),
    ]);
    membershipsController.add([
      MessageCollectionMembershipEntry(
        collectionId: SystemMessageCollection.important.id,
        chatJid: 'alpha@example.com',
        messageReferenceId: 'message-1',
        messageStanzaId: 'message-1',
        messageOriginId: null,
        messageMucStanzaId: null,
        deltaAccountId: null,
        deltaMsgId: null,
        addedAt: DateTime.utc(2026),
        active: true,
      ),
    ]);
    contactFolderRulesController.add({
      'alpha@example.com': SystemMessageCollection.receipts.id,
    });
    await pumpEventQueue();

    expect(
      cubit.state.explicitActiveCollectionIdsForMessage(
        chat: chat,
        message: message,
      ),
      {SystemMessageCollection.important.id},
    );
    expect(
      cubit.state.ruleDerivedCollectionIdsForMessage(
        chat: chat,
        message: message,
      ),
      {SystemMessageCollection.receipts.id},
    );
  });

  test('does not remove contact-rule-derived folder items', () async {
    final item = FolderMessageItem(
      collectionId: 'Projects',
      chatJid: 'peer@axi.im',
      messageReferenceId: 'message-1',
      messageStanzaId: 'message-1',
      messageOriginId: null,
      messageMucStanzaId: null,
      deltaAccountId: null,
      deltaMsgId: null,
      addedAt: DateTime.utc(2026),
      active: true,
      message: null,
      chat: null,
      isContactRuleDerived: true,
    );

    final cubit = FoldersCubit(xmppService: xmppService);
    addTearDown(cubit.close);

    expect(await cubit.removeItem(item), isFalse);
    verifyNever(() => xmppService.removeMessageCollectionMembership(item));
  });
}
