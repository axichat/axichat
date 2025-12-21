import 'dart:async';

import 'package:moxxmpp/moxxmpp.dart' as mox;

const _bookmarksNode = 'urn:xmpp:bookmarks:1';
const _bookmarksNotifyFeature = 'urn:xmpp:bookmarks:1+notify';
const _conferenceTag = 'conference';
const _conferenceJidAttr = 'jid';
const _conferenceNameAttr = 'name';
const _conferenceAutojoinAttr = 'autojoin';
const _extensionsTag = 'extensions';
const _nickTag = 'nick';
const _passwordTag = 'password';
const _publishModelPublishers = 'publishers';
const _sendLastPublishedItemNever = 'never';
const _defaultMaxItems = 'max';

final class MucBookmark {
  const MucBookmark({
    required this.roomBare,
    this.name,
    this.nick,
    this.password,
    this.autojoin = false,
    this.extensions = const [],
  });

  final mox.JID roomBare;
  final String? name;
  final bool autojoin;
  final String? nick;
  final String? password;
  final List<mox.XMLNode> extensions;

  MucBookmark copyWith({
    mox.JID? roomBare,
    String? name,
    bool? autojoin,
    String? nick,
    String? password,
    List<mox.XMLNode>? extensions,
  }) {
    return MucBookmark(
      roomBare: roomBare ?? this.roomBare,
      name: name ?? this.name,
      autojoin: autojoin ?? this.autojoin,
      nick: nick ?? this.nick,
      password: password ?? this.password,
      extensions: extensions ?? this.extensions,
    );
  }

  static bool _parseBool(String? value, {required bool defaultValue}) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => defaultValue,
    };
  }

  static String? _normalize(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  static String? _normalizeBareJid(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }

  static MucBookmark? fromBookmarks2Xml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _conferenceTag) return null;
    if (node.attributes['xmlns']?.toString() != _bookmarksNode) return null;

    final rawRoomJid = _normalizeBareJid(itemId) ??
        _normalizeBareJid(node.attributes[_conferenceJidAttr]?.toString());
    if (rawRoomJid == null || rawRoomJid.isEmpty) return null;

    late final mox.JID jid;
    try {
      jid = mox.JID.fromString(rawRoomJid).toBare();
    } on Exception {
      return null;
    }

    final rawName =
        _normalize(node.attributes[_conferenceNameAttr]?.toString());
    final rawAutojoin =
        _normalize(node.attributes[_conferenceAutojoinAttr]?.toString());
    final nick = _normalize(node.firstTag(_nickTag)?.innerText());
    final password = _normalize(node.firstTag(_passwordTag)?.innerText());
    final extensionsNode = node.firstTag(_extensionsTag);
    final extensions = extensionsNode?.children ?? const <mox.XMLNode>[];

    return MucBookmark(
      roomBare: jid,
      name: rawName,
      autojoin: _parseBool(rawAutojoin, defaultValue: false),
      nick: nick,
      password: password,
      extensions: List<mox.XMLNode>.unmodifiable(extensions),
    );
  }

  mox.XMLNode toBookmarks2Xml() {
    final trimmedName = _normalize(name);
    final trimmedNick = _normalize(nick);
    final trimmedPassword = _normalize(password);
    return mox.XMLNode.xmlns(
      tag: _conferenceTag,
      xmlns: _bookmarksNode,
      attributes: {
        if (trimmedName?.isNotEmpty == true) _conferenceNameAttr: trimmedName!,
        if (autojoin) _conferenceAutojoinAttr: 'true',
      },
      children: [
        if (trimmedNick?.isNotEmpty == true)
          mox.XMLNode(tag: _nickTag, text: trimmedNick),
        if (trimmedPassword?.isNotEmpty == true)
          mox.XMLNode(tag: _passwordTag, text: trimmedPassword),
        if (extensions.isNotEmpty)
          mox.XMLNode(
            tag: _extensionsTag,
            children: List<mox.XMLNode>.from(extensions),
          ),
      ],
    );
  }
}

sealed class MucBookmarkUpdate {
  const MucBookmarkUpdate();
}

final class MucBookmarkUpdated extends MucBookmarkUpdate {
  const MucBookmarkUpdated(this.bookmark);

  final MucBookmark bookmark;
}

final class MucBookmarkRetracted extends MucBookmarkUpdate {
  const MucBookmarkRetracted(this.roomBare);

  final mox.JID roomBare;
}

final class MucBookmarkUpdatedEvent extends mox.XmppEvent {
  MucBookmarkUpdatedEvent(this.bookmark);

  final MucBookmark bookmark;
}

final class MucBookmarkRetractedEvent extends mox.XmppEvent {
  MucBookmarkRetractedEvent(this.roomBare);

  final mox.JID roomBare;
}

final class BookmarksManager extends mox.XmppManagerBase {
  BookmarksManager({
    String? maxItems,
  })  : _maxItems = maxItems ?? _defaultMaxItems,
        super(managerId);

  static const String managerId = 'axi.bookmarks';
  static const String bookmarksNotifyFeature = _bookmarksNotifyFeature;

  final String _maxItems;

  final StreamController<MucBookmarkUpdate> _updatesController =
      StreamController<MucBookmarkUpdate>.broadcast();
  Stream<MucBookmarkUpdate> get updates => _updatesController.stream;

  final Map<String, MucBookmark> _cache = {};

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is mox.StreamNegotiationsDoneEvent) {
      if (event.resumed) return super.onXmppEvent(event);
      unawaited(_bootstrap());
      return super.onXmppEvent(event);
    }
    if (event is mox.PubSubNotificationEvent) {
      await _handleNotification(event);
      return;
    }
    if (event is mox.PubSubItemsRetractedEvent) {
      await _handleRetractions(event);
      return;
    }
    return super.onXmppEvent(event);
  }

  Future<void> _bootstrap() async {
    try {
      await ensureNode();
      await subscribe();
    } on Exception {
      return;
    }
  }

  mox.NodeConfig _nodeConfig() => mox.NodeConfig(
        accessModel: mox.AccessModel.whitelist,
        publishModel: _publishModelPublishers,
        deliverNotifications: true,
        deliverPayloads: true,
        maxItems: _maxItems,
        notifyRetract: true,
        persistItems: true,
        sendLastPublishedItem: _sendLastPublishedItemNever,
      );

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
        accessModel: mox.AccessModel.whitelist.value,
        maxItems: _maxItems,
        persistItems: true,
      );

  mox.PubSubManager? _pubSub() =>
      getAttributes().getManagerById<mox.PubSubManager>(mox.pubsubManager);

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getFullJID().toBare();
    } on Exception {
      return null;
    }
  }

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final config = _nodeConfig();
    final configured = await pubsub.configure(host, _bookmarksNode, config);
    if (!configured.isType<mox.PubSubError>()) {
      return;
    }

    try {
      final created = await pubsub.createNodeWithConfig(
        host,
        config,
        nodeId: _bookmarksNode,
      );
      if (created != null) return;
    } on Exception {
      // ignore and retry below
    }

    try {
      final created = await pubsub.createNode(host, nodeId: _bookmarksNode);
      if (created == null) return;
      await pubsub.configure(host, _bookmarksNode, config);
    } on Exception {
      return;
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    final result = await pubsub.subscribe(host, _bookmarksNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.MalformedResponseError) return;
    }
  }

  Future<List<MucBookmark>> getBookmarks() async => fetchAll();

  Future<List<MucBookmark>> fetchAll() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return const [];

    final result = await pubsub.getItems(host, _bookmarksNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) return const [];
      return const [];
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = items
        .map((item) => _parseItem(item))
        .whereType<MucBookmark>()
        .toList(growable: false);
    for (final entry in parsed) {
      _cache[entry.roomBare.toBare().toString()] = entry;
    }
    return List<MucBookmark>.unmodifiable(parsed);
  }

  Future<void> upsertBookmark(MucBookmark bookmark) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final normalized = bookmark.copyWith(roomBare: bookmark.roomBare.toBare());
    final cached = _cache[normalized.roomBare.toBare().toString()];
    final merged = _mergeBookmarks(incoming: normalized, cached: cached);
    final payload = merged.toBookmarks2Xml();
    final id = merged.roomBare.toBare().toString();
    final result = await pubsub.publish(
      host,
      _bookmarksNode,
      payload,
      id: id,
      options: _publishOptions(),
      autoCreate: true,
      createNodeConfig: _nodeConfig(),
    );
    if (result.isType<mox.PubSubError>()) {
      return;
    }

    _cache[id] = merged;
    _emitUpdate(merged);
  }

  Future<void> removeBookmark(mox.JID roomBareJid) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final normalizedRoom = roomBareJid.toBare().toString();
    final result = await pubsub.retract(host, _bookmarksNode, normalizedRoom);
    if (result.isType<mox.PubSubError>()) {
      return;
    }

    _cache.remove(normalizedRoom);
    _emitRetraction(roomBareJid);
  }

  MucBookmark? _parseItem(mox.PubSubItem item) {
    final payload = item.payload;
    if (payload == null) return null;
    return MucBookmark.fromBookmarks2Xml(payload, itemId: item.id);
  }

  MucBookmark _mergeBookmarks({
    required MucBookmark incoming,
    MucBookmark? cached,
  }) {
    if (cached == null) return incoming;
    final mergedExtensions = incoming.extensions.isNotEmpty
        ? incoming.extensions
        : cached.extensions;
    return incoming.copyWith(
      name: incoming.name ?? cached.name,
      nick: incoming.nick ?? cached.nick,
      password: incoming.password ?? cached.password,
      extensions: mergedExtensions,
    );
  }

  void _emitUpdate(MucBookmark bookmark) {
    if (!_updatesController.isClosed) {
      _updatesController.add(MucBookmarkUpdated(bookmark));
    }
    getAttributes().sendEvent(MucBookmarkUpdatedEvent(bookmark));
  }

  void _emitRetraction(mox.JID roomBare) {
    if (!_updatesController.isClosed) {
      _updatesController.add(MucBookmarkRetracted(roomBare));
    }
    getAttributes().sendEvent(MucBookmarkRetractedEvent(roomBare));
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != _bookmarksNode) return;

    MucBookmark? parsed;
    if (event.item.payload case final payload?) {
      parsed = MucBookmark.fromBookmarks2Xml(payload, itemId: event.item.id);
    } else {
      final pubsub = _pubSub();
      final host = _selfPepHost();
      final itemId = event.item.id.trim();
      if (pubsub != null && host != null && itemId.isNotEmpty) {
        final itemResult = await pubsub.getItem(host, _bookmarksNode, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          parsed = _parseItem(itemResult.get<mox.PubSubItem>());
        }
      }
    }

    if (parsed == null) return;
    final cached = _cache[parsed.roomBare.toBare().toString()];
    final merged = _mergeBookmarks(incoming: parsed, cached: cached);
    _cache[merged.roomBare.toBare().toString()] = merged;
    _emitUpdate(merged);
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != _bookmarksNode) return;
    if (event.itemIds.isEmpty) return;
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) continue;
      _cache.remove(normalized);
      late final mox.JID roomBare;
      try {
        roomBare = mox.JID.fromString(normalized).toBare();
      } on Exception {
        continue;
      }
      _emitRetraction(roomBare);
    }
  }
}
