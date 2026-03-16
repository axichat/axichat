// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const _bookmarksNode = bookmarksNodeXmlns;
const _conferenceTag = 'conference';
const _conferenceJidAttr = 'jid';
const _conferenceNameAttr = 'name';
const _conferenceAutojoinAttr = 'autojoin';
const _extensionsTag = 'extensions';
const _nickTag = 'nick';
const _passwordTag = 'password';
const _defaultMaxItems = 'max';
const int _bookmarksFetchLimitFallback = 1000;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _bookmarksBootstrapOperationName =
    'BookmarksManager.bootstrapOnNegotiations';
const String _bookmarksRefreshOperationName =
    'BookmarksManager.refreshFromServer';

final class MucBookmark {
  const MucBookmark({
    required this.roomBare,
    this.name,
    this.nick,
    this.password,
    this.autojoin = false,
    this.extensions = const [],
    this.preserveCachedExtensions = true,
  });

  final mox.JID roomBare;
  final String? name;
  final bool autojoin;
  final String? nick;
  final String? password;
  final List<mox.XMLNode> extensions;
  final bool preserveCachedExtensions;

  MucBookmark copyWith({
    mox.JID? roomBare,
    String? name,
    bool? autojoin,
    String? nick,
    String? password,
    List<mox.XMLNode>? extensions,
    bool? preserveCachedExtensions,
  }) {
    return MucBookmark(
      roomBare: roomBare ?? this.roomBare,
      name: name ?? this.name,
      autojoin: autojoin ?? this.autojoin,
      nick: nick ?? this.nick,
      password: password ?? this.password,
      extensions: extensions ?? this.extensions,
      preserveCachedExtensions:
          preserveCachedExtensions ?? this.preserveCachedExtensions,
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
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  static String? _normalizeBareJid(String? raw) {
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    try {
      return mox.JID.fromString(trimmed).toBare().toString();
    } on Exception {
      return null;
    }
  }

  static MucBookmark? fromBookmarks2Xml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _conferenceTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != _bookmarksNode) {
      return null;
    }

    final rawRoomJid =
        _normalizeBareJid(itemId) ??
        _normalizeBareJid(node.attributes[_conferenceJidAttr]?.toString());
    if (rawRoomJid == null || rawRoomJid.isEmpty) {
      return null;
    }

    late final mox.JID jid;
    try {
      jid = mox.JID.fromString(rawRoomJid).toBare();
    } on Exception {
      return null;
    }

    final rawName = _normalize(
      node.attributes[_conferenceNameAttr]?.toString(),
    );
    final rawAutojoin = _normalize(
      node.attributes[_conferenceAutojoinAttr]?.toString(),
    );
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
      preserveCachedExtensions: false,
    );
  }

  static MucBookmark? fromPubSubItem(mox.PubSubItem item) {
    final payload = item.payload;
    if (payload != null) {
      final parsed = fromBookmarks2Xml(payload, itemId: item.id);
      if (parsed != null) {
        return parsed;
      }
    }

    final rawRoomJid = _normalizeBareJid(item.id);
    if (rawRoomJid == null || rawRoomJid.isEmpty) {
      return null;
    }

    try {
      return MucBookmark(roomBare: mox.JID.fromString(rawRoomJid).toBare());
    } on Exception {
      return null;
    }
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

final class BookmarksManager extends PepItemPubSubNodeManager<MucBookmark>
    implements PubSubHubDelegate {
  BookmarksManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.bookmarks';

  final String _maxItems;

  final StreamController<MucBookmarkUpdate> _updatesController =
      StreamController<MucBookmarkUpdate>.broadcast();
  Stream<MucBookmarkUpdate> get updates => _updatesController.stream;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(bookmarksSyncRateLimit);

  @override
  String get nodeId => _bookmarksNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => '$_bookmarksFetchLimitFallback';

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _bookmarksBootstrapOperationName;

  @override
  String get refreshOperationName => _bookmarksRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubBookmarks;

  @override
  bool get publishAutoCreate => true;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  MucBookmark? cachedBookmark(mox.JID roomBareJid) =>
      cache[roomBareJid.toBare().toString()];

  Future<MucBookmark?> bookmarkForRoom(mox.JID roomBareJid) async {
    final normalizedRoom = roomBareJid.toBare().toString();
    final cached = cache[normalizedRoom];
    if (cached != null) {
      return cached;
    }
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return null;
    }
    final result = await pubsub.getItem(host, _bookmarksNode, normalizedRoom);
    if (result.isType<mox.PubSubError>()) {
      return null;
    }
    final bookmark = MucBookmark.fromPubSubItem(result.get<mox.PubSubItem>());
    if (bookmark == null) {
      return null;
    }
    cache[normalizedRoom] = bookmark;
    return bookmark;
  }

  Future<List<MucBookmark>> getBookmarks() async => fetchAll();

  Future<void> upsertBookmark(MucBookmark bookmark) async {
    final normalized = bookmark.copyWith(roomBare: bookmark.roomBare.toBare());
    final cached = cache[normalized.roomBare.toBare().toString()];
    final merged = _mergeBookmarks(incoming: normalized, cached: cached);
    await publishItem(merged);
  }

  Future<void> removeBookmark(mox.JID roomBareJid) async {
    await retractItem(roomBareJid.toBare().toString());
  }

  int _resolveFetchLimit() {
    final normalized = _maxItems.trim();
    if (normalized.isEmpty) {
      return _bookmarksFetchLimitFallback;
    }
    return int.tryParse(normalized) ?? _bookmarksFetchLimitFallback;
  }

  MucBookmark _mergeBookmarks({
    required MucBookmark incoming,
    MucBookmark? cached,
  }) {
    if (cached == null) {
      return incoming;
    }
    final mergedExtensions =
        incoming.preserveCachedExtensions && incoming.extensions.isEmpty
        ? cached.extensions
        : incoming.extensions;
    return incoming.copyWith(
      name: incoming.name ?? cached.name,
      nick: incoming.nick ?? cached.nick,
      password: incoming.password ?? cached.password,
      extensions: mergedExtensions,
      preserveCachedExtensions: false,
    );
  }

  PubSubManager? _pubSub() =>
      getAttributes().getManagerById<PubSubManager>(mox.pubsubManager);

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getConnectionSettings().jid.toBare();
    } on Exception {
      try {
        return getAttributes().getFullJID().toBare();
      } on Exception {
        return null;
      }
    }
  }

  @override
  Future<({List<MucBookmark> items, bool isSuccess, bool isComplete})>
  fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const (
        items: <MucBookmark>[],
        isSuccess: false,
        isComplete: false,
      );
    }

    final fetchLimit = _resolveFetchLimit();
    final result = await pubsub.getItems(
      host,
      _bookmarksNode,
      maxItems: fetchLimit,
    );
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) {
        final cachedItems = cache.values.toList(growable: false);
        return (
          items: List<MucBookmark>.unmodifiable(cachedItems),
          isSuccess: true,
          isComplete: false,
        );
      }
      return const (
        items: <MucBookmark>[],
        isSuccess: false,
        isComplete: false,
      );
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = items
        .map(MucBookmark.fromPubSubItem)
        .whereType<MucBookmark>()
        .toList(growable: false);
    cache
      ..clear()
      ..addAll({
        for (final entry in parsed) entry.roomBare.toBare().toString(): entry,
      });
    return (
      items: List<MucBookmark>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: parsed.length < fetchLimit,
    );
  }

  @override
  MucBookmark? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      MucBookmark.fromBookmarks2Xml(payload, itemId: itemId);

  @override
  String itemIdOf(MucBookmark payload) => payload.roomBare.toBare().toString();

  @override
  mox.XMLNode payloadToXml(MucBookmark payload) => payload.toBookmarks2Xml();

  @override
  void emitUpdatePayload(MucBookmark payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(MucBookmarkUpdated(payload));
    }
    getAttributes().sendEvent(MucBookmarkUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    late final mox.JID roomBare;
    try {
      roomBare = mox.JID.fromString(itemId).toBare();
    } on Exception {
      return;
    }
    if (!_updatesController.isClosed) {
      _updatesController.add(MucBookmarkRetracted(roomBare));
    }
    getAttributes().sendEvent(MucBookmarkRetractedEvent(roomBare));
  }

  @override
  MucBookmark mergeIncomingNotification(
    MucBookmark incoming, {
    MucBookmark? cached,
  }) => _mergeBookmarks(incoming: incoming, cached: cached);

  @override
  MucBookmark mergeRefreshedItem(MucBookmark incoming, {MucBookmark? cached}) =>
      _mergeBookmarks(incoming: incoming, cached: cached);
}
