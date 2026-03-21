import 'package:axichat/src/xmpp/pubsub/bookmarks_manager.dart';
import 'package:axichat/src/xmpp/pubsub/conversation_index_manager.dart';
import 'package:axichat/src/xmpp/pubsub/drafts_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/message_collections_pubsub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/settings_pubsub_manager.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:flutter_test/flutter_test.dart';
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
const _collectionId = 'important';
const _messageReferenceId = 'important-message-id';
const _messageChatJid = 'chat@example.com';
const _settingsNode = 'urn:axi:settings';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
        messageReferenceId: _messageReferenceId,
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
      expect(update.payload.collectionId, _collectionId);
      expect(update.payload.chatJid, _messageChatJid);
      expect(update.payload.messageReferenceId, _messageReferenceId);
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

    final parsed = DraftSyncPayload.fromXml(payload.toXml());

    expect(parsed, isNotNull);
    expect(parsed?.quotingStanzaId, 'quoted-origin-id');
    expect(parsed?.quotingReferenceKind, MessageReferenceKind.originId);
  });
}
