import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/calendar_task_ics_message.dart';
import 'package:axichat/src/common/wire_reference_id.dart';
import 'package:axichat/src/xmpp/pubsub/address_block_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/pubsub/chat_settings_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/contacts_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/pubsub/drafts_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/message_collections_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/settings_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/spam_pubsub_manager.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moxlib/moxlib.dart' as moxlib;
import 'package:moxxmpp/moxxmpp.dart' as mox;

const _userFullJid = 'user@example.com/resource';
const _userBareJid = 'user@example.com';
const _authPassword = 'password';
const _fromJid = _userBareJid;
const _bookmarksNode = 'urn:xmpp:bookmarks:1';

const _roomJid = 'room@conference.example.com';
const _roomName = 'Room Name';
const _roomNick = 'RoomNick';
const _autojoinValue = 'true';
const _conferenceTag = 'conference';
const _conferenceNameAttr = 'name';
const _conferenceAutojoinAttr = 'autojoin';
const _conferenceJidAttr = 'jid';
const _nickTag = 'nick';

const _messageCollectionsNode = 'urn:axi:message-collections';
const _contactsNode = 'urn:axi:contacts';
const _collectionId = 'important';
const _customCollectionId = 'Projects';
const _contactFolderRuleAddress = 'contact@example.com';
const _messageReferenceId = 'important-message-id';
const _messageChatJid = 'chat@example.com';
const _settingsNode = 'urn:axi:settings';
const _chatSettingsTag = 'chat-settings';
const _chatSettingsAddressAttr = 'address';
const _chatSettingsUpdatedAtAttr = 'updated_at';
const _chatSettingsSourceIdAttr = 'source_id';
const _chatSettingsDataTag = 'data';

const _peerBareJid = 'peer@example.com';
const _convTag = 'conv';
const _convPeerAttr = 'peer';
const _convLastTsAttr = 'last_ts';
const _convLastIdAttr = 'last_id';
const _convPinnedAttr = 'pinned';
const _convArchivedAttr = 'archived';
const _lastIdValue = 'msg-1';
const _pinnedValue = 'true';
const _archivedValue = 'false';
const _lastTsYear = 2024;
const _lastTsMonth = 5;
const _lastTsDay = 6;
const _lastTsHour = 12;
const _lastTsMinute = 30;
const _lastTsSecond = 0;

const mox.Stanza? _noStanza = null;

mox.XMLNode _serializedNode(mox.XMLNode node) =>
    mox.XMLNode.fromString(node.toXml());

mox.XmppManagerAttributes _testAttributes({
  required List<mox.XmppEvent> sentEvents,
}) {
  final fullJid = mox.JID.fromString(_userFullJid);
  return mox.XmppManagerAttributes(
    sendStanza: (_) async => _noStanza,
    sendNonza: (_) {},
    getManagerById: <T extends mox.XmppManagerBase>(_) => null,
    sendEvent: sentEvents.add,
    getConnectionSettings: () =>
        mox.ConnectionSettings(jid: fullJid, password: _authPassword),
    getFullJID: () => fullJid,
    getSocket: () => throw UnimplementedError(),
    getConnection: () => throw UnimplementedError(),
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );
}

mox.XmppManagerAttributes _testAttributesWithPubSub({
  required PubSubManager pubSubManager,
}) {
  final fullJid = mox.JID.fromString(_userFullJid);
  return mox.XmppManagerAttributes(
    sendStanza: (_) async => _noStanza,
    sendNonza: (_) {},
    getManagerById: <T extends mox.XmppManagerBase>(id) {
      if (id == mox.pubsubManager) {
        return pubSubManager as T;
      }
      return null;
    },
    sendEvent: (_) {},
    getConnectionSettings: () =>
        mox.ConnectionSettings(jid: fullJid, password: _authPassword),
    getFullJID: () => fullJid,
    getSocket: () => throw UnimplementedError(),
    getConnection: () => throw UnimplementedError(),
    getNegotiatorById: <T extends mox.XmppFeatureNegotiatorBase>(String _) =>
        null,
  );
}

final class _ReadableFailingConfigurePubSubManager extends PubSubManager {
  int configureCount = 0;
  int getItemsCount = 0;

  @override
  Future<moxlib.Result<mox.PubSubError, bool>> configureNode(
    mox.JID jid,
    String node,
    AxiPubSubNodeConfig config,
  ) async {
    configureCount += 1;
    return moxlib.Result(mox.UnknownPubSubError());
  }

  @override
  Future<String?> resolveSendLastPublishedItemForNode({
    required mox.JID host,
    required String node,
  }) async {
    return null;
  }

  @override
  Future<moxlib.Result<mox.PubSubError, List<mox.PubSubItem>>> getItems(
    mox.JID jid,
    String node, {
    int? maxItems,
    String? subId,
  }) async {
    getItemsCount += 1;
    return const moxlib.Result(<mox.PubSubItem>[]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'PEP manager does not repeat configure when readable node exists',
    () async {
      final pubSubManager = _ReadableFailingConfigurePubSubManager();
      final manager = ChatSettingsPubSubManager()
        ..register(_testAttributesWithPubSub(pubSubManager: pubSubManager));

      await manager.ensureNode();
      await manager.ensureNode();

      expect(
        pubSubManager.configureCount,
        manager.candidateAccessModels.length,
      );
      expect(pubSubManager.getItemsCount, 1);
    },
  );

  test(
    'ConversationIndexManager emits update from pubsub notification',
    () async {
      final sentEvents = <mox.XmppEvent>[];
      final manager = ConversationIndexManager()
        ..register(_testAttributes(sentEvents: sentEvents));

      final lastTimestamp = DateTime.utc(
        _lastTsYear,
        _lastTsMonth,
        _lastTsDay,
        _lastTsHour,
        _lastTsMinute,
        _lastTsSecond,
      );
      final payload = mox.XMLNode.xmlns(
        tag: _convTag,
        xmlns: conversationIndexNode,
        attributes: {
          _convPeerAttr: _peerBareJid,
          _convLastTsAttr: lastTimestamp.toIso8601String(),
          _convLastIdAttr: _lastIdValue,
          _convPinnedAttr: _pinnedValue,
          _convArchivedAttr: _archivedValue,
        },
      );

      final item = mox.PubSubItem(
        id: _peerBareJid,
        node: conversationIndexNode,
        payload: payload,
      );
      final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

      await manager.onXmppEvent(event);

      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<ConversationIndexItemUpdatedEvent>());

      final update = sentEvents.single as ConversationIndexItemUpdatedEvent;
      expect(update.item.peerBare.toString(), equals(_peerBareJid));
      expect(update.item.lastId, equals(_lastIdValue));
      expect(update.item.pinned, isTrue);
      expect(update.item.archived, isFalse);
      expect(update.item.lastTimestamp.toUtc(), equals(lastTimestamp.toUtc()));
    },
  );

  test('BookmarksManager emits update from pubsub notification', () async {
    final sentEvents = <mox.XmppEvent>[];
    final manager = BookmarksManager()
      ..register(_testAttributes(sentEvents: sentEvents));

    final payload = mox.XMLNode.xmlns(
      tag: _conferenceTag,
      xmlns: _bookmarksNode,
      attributes: {
        _conferenceNameAttr: _roomName,
        _conferenceAutojoinAttr: _autojoinValue,
        _conferenceJidAttr: _roomJid,
      },
      children: [mox.XMLNode(tag: _nickTag, text: _roomNick)],
    );
    final item = mox.PubSubItem(
      id: _roomJid,
      node: _bookmarksNode,
      payload: payload,
    );
    final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

    await manager.onXmppEvent(event);

    expect(sentEvents, hasLength(1));
    expect(sentEvents.single, isA<MucBookmarkUpdatedEvent>());

    final update = sentEvents.single as MucBookmarkUpdatedEvent;
    expect(update.bookmark.roomBare.toString(), equals(_roomJid));
    expect(update.bookmark.name, equals(_roomName));
    expect(update.bookmark.autojoin, isTrue);
    expect(update.bookmark.nick, equals(_roomNick));
  });

  test(
    'MessageCollectionsPubSubManager emits update from pubsub notification',
    () async {
      final sentEvents = <mox.XmppEvent>[];
      final manager = MessageCollectionsPubSubManager()
        ..register(_testAttributes(sentEvents: sentEvents));

      final updatedAt = DateTime.utc(2026, 3, 12, 9, 30);
      final payload = MessageCollectionSyncPayload(
        collectionId: _collectionId,
        chatJid: _messageChatJid,
        messageReferenceId: WireReferenceId.tryFrom(_messageReferenceId)!,
        updatedAt: updatedAt,
        active: true,
        sourceId: 'device-a',
      );
      final item = mox.PubSubItem(
        id: payload.itemId,
        node: _messageCollectionsNode,
        payload: payload.toXml(),
      );
      final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

      await manager.onXmppEvent(event);
      await pumpEventQueue();

      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<MessageCollectionSyncUpdatedEvent>());

      final update = sentEvents.single as MessageCollectionSyncUpdatedEvent;
      expect(update.payload, isA<MessageCollectionSyncPayload>());
      final updatedPayload = update.payload as MessageCollectionSyncPayload;
      expect(updatedPayload.collectionId, _collectionId);
      expect(updatedPayload.chatJid, _messageChatJid);
      expect(updatedPayload.messageReferenceId, _messageReferenceId);
      expect(updatedPayload.updatedAt.toUtc(), updatedAt);
      expect(updatedPayload.active, isTrue);
    },
  );

  test(
    'MessageCollectionsPubSubManager emits collection record update',
    () async {
      final sentEvents = <mox.XmppEvent>[];
      final manager = MessageCollectionsPubSubManager()
        ..register(_testAttributes(sentEvents: sentEvents));

      final updatedAt = DateTime.utc(2026, 3, 12, 9, 45);
      final payload = MessageCollectionRecordSyncPayload(
        collectionId: _customCollectionId,
        updatedAt: updatedAt,
        active: true,
      );
      final item = mox.PubSubItem(
        id: payload.itemId,
        node: _messageCollectionsNode,
        payload: payload.toXml(),
      );
      final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

      await manager.onXmppEvent(event);
      await pumpEventQueue();

      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<MessageCollectionSyncUpdatedEvent>());

      final update = sentEvents.single as MessageCollectionSyncUpdatedEvent;
      expect(update.payload, isA<MessageCollectionRecordSyncPayload>());
      final updatedPayload =
          update.payload as MessageCollectionRecordSyncPayload;
      expect(updatedPayload.collectionId, _customCollectionId);
      expect(updatedPayload.updatedAt.toUtc(), updatedAt);
      expect(updatedPayload.active, isTrue);
    },
  );

  test(
    'ContactsPubSubManager emits folder rule update from pubsub notification',
    () async {
      final sentEvents = <mox.XmppEvent>[];
      final manager = ContactsPubSubManager()
        ..register(_testAttributes(sentEvents: sentEvents));

      final updatedAt = DateTime.utc(2026, 3, 12, 10, 15);
      final payload = ContactSyncPayload(
        addressKey: _contactFolderRuleAddress,
        active: true,
        manual: true,
        favorited: false,
        folderCollectionId: _customCollectionId,
        updatedAt: updatedAt,
        folderRuleUpdatedAt: updatedAt,
        sourceId: 'device-a',
      );
      final item = mox.PubSubItem(
        id: payload.itemId,
        node: _contactsNode,
        payload: payload.toXml(),
      );
      final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

      await manager.onXmppEvent(event);
      await pumpEventQueue();

      expect(sentEvents, hasLength(1));
      expect(sentEvents.single, isA<ContactSyncUpdatedEvent>());

      final update = sentEvents.single as ContactSyncUpdatedEvent;
      expect(update.payload.addressKey, _contactFolderRuleAddress);
      expect(update.payload.folderCollectionId, _customCollectionId);
      expect(update.payload.updatedAt.toUtc(), updatedAt);
      expect(update.payload.active, isTrue);
    },
  );

  test('SettingsPubSubManager emits update from pubsub notification', () async {
    final sentEvents = <mox.XmppEvent>[];
    final manager = SettingsPubSubManager()
      ..register(_testAttributes(sentEvents: sentEvents));

    final updatedAt = DateTime.utc(2026, 3, 12, 10, 45);
    final payload = SettingsSyncPayload(
      settings: const <String, dynamic>{
        'language': 'german',
        'auto_download_images': false,
      },
      updatedAt: updatedAt,
      sourceId: 'device-a',
    );
    final item = mox.PubSubItem(
      id: SettingsSyncPayload.currentItemId,
      node: _settingsNode,
      payload: payload.toXml(),
    );
    final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

    await manager.onXmppEvent(event);
    await pumpEventQueue();

    expect(sentEvents, hasLength(1));
    expect(sentEvents.single, isA<SettingsSyncUpdatedEvent>());

    final update = sentEvents.single as SettingsSyncUpdatedEvent;
    expect(update.payload.settings['language'], 'german');
    expect(update.payload.settings['auto_download_images'], isFalse);
    expect(update.payload.updatedAt.toUtc(), updatedAt);
    expect(update.payload.sourceId, 'device-a');
  });

  test('app-owned pubsub payloads escape XML-sensitive data', () {
    const special = 'A&B <C> "D" \'E\'';
    const sourceId = 'device & <one> "two" \'three\'';
    final updatedAt = DateTime.utc(2026, 3, 12, 12);
    final settings = SettingsSyncPayload(
      settings: const <String, dynamic>{'language': special},
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
    final parsedSettings = SettingsSyncPayload.fromXml(
      _serializedNode(settings.toXml()),
      itemId: settings.itemId,
    );
    expect(parsedSettings?.settings['language'], special);
    expect(parsedSettings?.sourceId, sourceId);

    final chatSettings = ChatSettingsSyncPayload(
      addressKey: _messageChatJid,
      settings: const <String, dynamic>{'email_read_receipts': null},
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
    final parsedChatSettings = ChatSettingsSyncPayload.fromXml(
      _serializedNode(chatSettings.toXml()),
      itemId: chatSettings.itemId,
    );
    expect(parsedChatSettings?.sourceId, sourceId);
    expect(
      parsedChatSettings?.settings,
      containsPair('email_read_receipts', isNull),
    );

    final addressBlock = AddressBlockSyncPayload(
      address: _messageChatJid,
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
    final parsedAddressBlock = AddressBlockSyncPayload.fromXml(
      _serializedNode(addressBlock.toXml()),
      itemId: addressBlock.itemId,
    );
    expect(parsedAddressBlock?.address, _messageChatJid);
    expect(parsedAddressBlock?.sourceId, sourceId);

    final spam = SpamSyncPayload(
      jid: _messageChatJid,
      updatedAt: updatedAt,
      sourceId: sourceId,
    );
    final parsedSpam = SpamSyncPayload.fromXml(
      _serializedNode(spam.toXml()),
      itemId: spam.itemId,
    );
    expect(parsedSpam?.jid, _messageChatJid);
    expect(parsedSpam?.sourceId, sourceId);

    final conversation = ConvItem(
      peerBare: mox.JID.fromString(_messageChatJid).toBare(),
      lastTimestamp: updatedAt,
      lastId: special,
      pinned: true,
      archived: true,
    );
    final parsedConversation = ConvItem.fromXml(
      _serializedNode(conversation.toXml()),
    );
    expect(parsedConversation?.peerBare.toString(), _messageChatJid);
    expect(parsedConversation?.lastId, special);
    expect(parsedConversation?.pinned, isTrue);
    expect(parsedConversation?.archived, isTrue);

    final contact = ContactSyncPayload(
      addressKey: _contactFolderRuleAddress,
      active: true,
      manual: true,
      favorited: false,
      displayNameOverride: special,
      folderCollectionId: special,
      updatedAt: updatedAt,
      sourceId: sourceId,
      fields: [
        ContactSyncFieldPayload(
          fieldId: 'field-1',
          kind: ContactDetailFieldKind.note,
          label: special,
          value: special,
          sortOrder: 1,
          active: true,
          updatedAt: updatedAt,
          sourceId: sourceId,
        ),
      ],
    );
    final parsedContact = ContactSyncPayload.fromXml(
      _serializedNode(contact.toXml()),
      itemId: contact.itemId,
    );
    expect(parsedContact?.displayNameOverride, special);
    expect(parsedContact?.folderCollectionId, special);
    expect(parsedContact?.fields.single.label, special);
    expect(parsedContact?.fields.single.value, special);
    expect(parsedContact?.fields.single.sourceId, sourceId);

    final bookmark = MucBookmark(
      roomBare: mox.JID.fromString(_roomJid).toBare(),
      name: special,
      nick: special,
      password: special,
      autojoin: true,
    );
    final parsedBookmark = MucBookmark.fromBookmarks2Xml(
      _serializedNode(bookmark.toBookmarks2Xml()),
      itemId: _roomJid,
    );
    expect(parsedBookmark?.name, special);
    expect(parsedBookmark?.nick, special);
    expect(parsedBookmark?.password, special);

    final collection = MessageCollectionSyncPayload(
      collectionId: special,
      chatJid: _messageChatJid,
      messageReferenceId: WireReferenceId.tryFrom(special)!,
      messageOriginId: WireReferenceId.tryFrom(special),
      updatedAt: updatedAt,
      active: true,
      sourceId: sourceId,
    );
    final parsedCollection = MessageCollectionSyncPayload.fromXml(
      _serializedNode(collection.toXml()),
      itemId: collection.itemId,
    );
    expect(parsedCollection?.collectionId, special);
    expect(parsedCollection?.messageReferenceId, special);
    expect(parsedCollection?.messageOriginId, special);
    expect(parsedCollection?.sourceId, sourceId);
  });

  test('ChatSettingsPubSubManager ignores malformed settings data', () async {
    final sentEvents = <mox.XmppEvent>[];
    final manager = ChatSettingsPubSubManager()
      ..register(_testAttributes(sentEvents: sentEvents));
    final updatedAt = DateTime.utc(2026, 3, 12, 11, 15);
    final payload = mox.XMLNode.xmlns(
      tag: _chatSettingsTag,
      xmlns: chatSettingsPubSubNode,
      attributes: {
        _chatSettingsAddressAttr: _peerBareJid,
        _chatSettingsUpdatedAtAttr: updatedAt.toIso8601String(),
        _chatSettingsSourceIdAttr: 'device-a',
      },
      children: [mox.XMLNode(tag: _chatSettingsDataTag, text: '{not json')],
    );
    final item = mox.PubSubItem(
      id: ChatSettingsSyncPayload.itemIdFor(addressKey: _peerBareJid),
      node: chatSettingsPubSubNode,
      payload: payload,
    );
    final event = mox.PubSubNotificationEvent(item: item, from: _fromJid);

    await manager.onXmppEvent(event);
    await pumpEventQueue();

    expect(sentEvents, isEmpty);
  });

  test(
    'ChatSettingsSyncPayload applies explicit null without clearing absent keys',
    () {
      final updatedAt = DateTime.utc(2026, 3, 12, 11, 20);
      final local = Chat.fromJid(_peerBareJid).copyWith(
        markerResponsive: true,
        emailRemoteImagesEnabled: true,
        emailReadReceiptsEnabled: true,
      );
      final payload = ChatSettingsSyncPayload(
        addressKey: _peerBareJid,
        settings: {ChatSettingId.emailReadReceipts.syncKey: null},
        updatedAt: updatedAt,
        sourceId: 'device-a',
      );

      final parsed = ChatSettingsSyncPayload.fromXml(
        _serializedNode(payload.toXml()),
      );
      final applied = parsed?.applyToChat(local);

      expect(parsed?.settings, containsPair('email_read_receipts', isNull));
      expect(applied?.emailReadReceiptsEnabled, isNull);
      expect(applied?.markerResponsive, isTrue);
      expect(applied?.emailRemoteImagesEnabled, isTrue);
      expect(applied?.chatSettingsUpdatedAt, updatedAt);
      expect(applied?.chatSettingsSourceId, 'device-a');
    },
  );

  test(
    'ChatSettingsSyncPayload includes targeted clears beside remaining overrides',
    () {
      final updatedAt = DateTime.utc(2026, 3, 12, 11, 25);
      final chat = Chat.fromJid(_peerBareJid).copyWith(
        markerResponsive: true,
        emailReadReceiptsEnabled: null,
        chatSettingsUpdatedAt: updatedAt,
        chatSettingsSourceId: 'device-a',
      );

      final payload = ChatSettingsSyncPayload.fromChat(
        chat,
        clearedSettings: {ChatSettingId.emailReadReceipts},
      );

      expect(payload?.settings, containsPair('read_receipts', isTrue));
      expect(payload?.settings, containsPair('email_read_receipts', isNull));
    },
  );

  test('MucBookmark parses id-only pubsub items', () {
    final item = mox.PubSubItem(id: _roomJid, node: _bookmarksNode);

    final bookmark = MucBookmark.fromPubSubItem(item);

    expect(bookmark, isNotNull);
    expect(bookmark?.roomBare.toString(), equals(_roomJid));
    expect(bookmark?.name, isNull);
    expect(bookmark?.autojoin, isFalse);
    expect(bookmark?.nick, isNull);
  });

  test('DraftSyncPayload round-trips quoted reference metadata', () {
    final payload = DraftSyncPayload(
      syncId: 'draft-sync-id',
      updatedAt: DateTime.utc(2026, 3, 11, 12),
      sourceId: 'device-a',
      recipients: const [DraftRecipient(jid: _peerBareJid, role: 'to')],
      body: 'hello',
      quotingStanzaId: 'quoted-origin-id',
      quotingReferenceKind: MessageReferenceKind.originId,
    );

    final parsed = DraftSyncPayload.fromXml(_serializedNode(payload.toXml()));

    expect(parsed, isNotNull);
    expect(parsed?.quotingStanzaId, 'quoted-origin-id');
    expect(parsed?.quotingReferenceKind, MessageReferenceKind.originId);
  });

  test('DraftSyncPayload normalizes calendar task payload to read-only', () {
    final task = CalendarTask(
      id: 'task-1',
      title: 'Review launch notes',
      createdAt: DateTime.utc(2026, 3, 11, 8),
      modifiedAt: DateTime.utc(2026, 3, 11, 9),
    );
    final payload = DraftSyncPayload(
      syncId: 'draft-sync-id',
      updatedAt: DateTime.utc(2026, 3, 11, 12),
      sourceId: 'device-a',
      recipients: const [DraftRecipient(jid: _peerBareJid, role: 'to')],
      body: 'hello',
      calendarTaskIcsMessage: CalendarTaskIcsMessage(
        task: task,
        readOnly: false,
      ),
    );

    final parsed = DraftSyncPayload.fromXml(_serializedNode(payload.toXml()));

    expect(parsed, isNotNull);
    expect(parsed?.body, 'hello');
    expect(parsed?.calendarTaskIcsMessage?.task, task);
    expect(parsed?.calendarTaskIcsMessage?.readOnly, isTrue);
  });

  test('DraftSyncPayload round-trips forwarded blocks', () {
    final block = DraftForwardedBlock(
      blockId: 'forward-block-1',
      sourceMessageId: 'source-message-1',
      senderJid: _peerBareJid,
      senderLabel: 'Peer <label> & "team" \'x\'',
      timestamp: DateTime.utc(2026, 3, 11, 8),
      originalSubject: 'Original <subject> & "code"',
      originalPlainText: 'Original text & symbols',
      originalHtml:
          '<!doctype html><html xmlns=http://www.w3.org/1999/xhtml><body><p>Hey & welcome</p></body></html>',
      quotedContext: const DraftForwardedQuoteContext(
        senderLabel: 'Original sender <label> & "team"',
        plainText: 'Quoted text <safe> & sound',
      ),
      conversionState: DraftForwardedBlockConversionState.convertedText,
      convertedText: 'Edited forwarded text <plain> & kept',
    );
    final payload = DraftSyncPayload(
      syncId: 'draft-sync-id',
      updatedAt: DateTime.utc(2026, 3, 11, 12),
      sourceId: 'device-a',
      recipients: const [DraftRecipient(jid: _peerBareJid, role: 'to')],
      body: 'hello',
      forwardedBlocks: [block],
    );

    final xml = payload.toXml().toXml();
    final parsed = DraftSyncPayload.fromXml(mox.XMLNode.fromString(xml));

    expect(xml, isNot(contains('<!doctype html>')));
    expect(xml, contains('&lt;!doctype html&gt;'));
    expect(parsed, isNotNull);
    expect(parsed?.forwardedBlocks, [block]);
  });

  test('DraftSyncPayload replaces XML-invalid control characters', () {
    const unsafe = 'visible\u0001text';
    final sanitized = 'visible${String.fromCharCode(0xfffd)}text';
    final payload = DraftSyncPayload(
      syncId: 'draft-sync-id',
      updatedAt: DateTime.utc(2026, 3, 11, 12),
      sourceId: unsafe,
      recipients: const [DraftRecipient(jid: _peerBareJid, role: 'to')],
      subject: unsafe,
      body: unsafe,
      html: unsafe,
      forwardedBlocks: const [
        DraftForwardedBlock(
          blockId: 'forward-block-1',
          sourceMessageId: 'source-message-1',
          senderJid: _peerBareJid,
          senderLabel: unsafe,
          originalPlainText: unsafe,
        ),
      ],
    );

    final xml = payload.toXml().toXml();
    final parsed = DraftSyncPayload.fromXml(mox.XMLNode.fromString(xml));

    expect(xml, isNot(contains('\u0001')));
    expect(parsed?.sourceId, sanitized);
    expect(parsed?.subject, sanitized);
    expect(parsed?.body, sanitized);
    expect(parsed?.html, sanitized);
    expect(parsed?.forwardedBlocks.single.senderLabel, sanitized);
    expect(parsed?.forwardedBlocks.single.originalPlainText, sanitized);
  });

  test('DraftSyncPayload ignores invalid calendar task payload only', () {
    final updatedAt = DateTime.utc(2026, 3, 11, 12);
    final payload = mox.XMLNode.xmlns(
      tag: 'draft',
      xmlns: draftsPubSubNode,
      attributes: {
        'id': 'draft-sync-id',
        'updated_at': updatedAt.toIso8601String(),
        'source_id': 'device-a',
      },
      children: [
        mox.XMLNode(tag: 'body', text: 'hello'),
        mox.XMLNode(tag: 'calendar_task_ics', text: '{not json'),
      ],
    );

    final parsed = DraftSyncPayload.fromXml(payload);

    expect(parsed, isNotNull);
    expect(parsed?.body, 'hello');
    expect(parsed?.calendarTaskIcsMessage, isNull);
  });
}
