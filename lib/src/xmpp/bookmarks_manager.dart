// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
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
const int _bookmarksFetchLimitFallback = 1000;
const _notifyEnabled = true;
const _deliverNotificationsEnabled = true;
const _deliverPayloadsEnabled = true;
const _persistItemsEnabled = true;
const _presenceBasedDeliveryDisabled = false;
const Duration _ensureNodeBackoff = Duration(minutes: 5);

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

const List<MucBookmark> _emptyMucBookmarks = <MucBookmark>[];

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
  DateTime? _lastEnsureAttempt;
  bool _ensureNodeInFlight = false;
  bool _nodeReady = false;

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
    if (event is PubSubItemsRefreshedEvent) {
      await _handleRefreshEvent(event);
      return;
    }
    if (event is PubSubSubscriptionChangedEvent) {
      await _handleSubscriptionChanged(event);
      return;
    }
    if (event is mox.PubSubNodeDeletedEvent) {
      await _handleNodeDeleted(event);
      return;
    }
    if (event is mox.PubSubNodePurgedEvent) {
      await _handleNodePurged(event);
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

  AxiPubSubNodeConfig _nodeConfig() => AxiPubSubNodeConfig(
        accessModel: mox.AccessModel.whitelist,
        publishModel: _publishModelPublishers,
        deliverNotifications: _deliverNotificationsEnabled,
        deliverPayloads: _deliverPayloadsEnabled,
        maxItems: _maxItems,
        notifyRetract: _notifyEnabled,
        notifyDelete: _notifyEnabled,
        notifyConfig: _notifyEnabled,
        notifySub: _notifyEnabled,
        presenceBasedDelivery: _presenceBasedDeliveryDisabled,
        persistItems: _persistItemsEnabled,
        sendLastPublishedItem: _sendLastPublishedItemNever,
      );

  mox.NodeConfig _createNodeConfig() => _nodeConfig().toNodeConfig();

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
        accessModel: mox.AccessModel.whitelist.value,
        maxItems: _maxItems,
        persistItems: _persistItemsEnabled,
        publishModel: _publishModelPublishers,
        sendLastPublishedItem: _sendLastPublishedItemNever,
      );

  SafePubSubManager? _pubSub() =>
      getAttributes().getManagerById<SafePubSubManager>(mox.pubsubManager);

  int? _parseMaxItems(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  int _resolveFetchLimit() =>
      _parseMaxItems(_maxItems) ?? _bookmarksFetchLimitFallback;

  bool _isSnapshotComplete({
    required int itemsCount,
    required int maxItems,
  }) =>
      itemsCount < maxItems;

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getFullJID().toBare();
    } on Exception {
      return null;
    }
  }

  bool _shouldAttemptEnsureNode() {
    if (_ensureNodeInFlight || _nodeReady) return false;
    final lastAttempt = _lastEnsureAttempt;
    if (lastAttempt == null) return true;
    final now = DateTime.timestamp();
    return now.difference(lastAttempt) >= _ensureNodeBackoff;
  }

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    if (!_shouldAttemptEnsureNode()) return;
    _ensureNodeInFlight = true;
    _lastEnsureAttempt = DateTime.timestamp();
    try {
      final config = _nodeConfig();
      final configured =
          await pubsub.configureNode(host, _bookmarksNode, config);
      if (!configured.isType<mox.PubSubError>()) {
        _nodeReady = true;
        return;
      }

      try {
        final created = await pubsub.createNodeWithConfig(
          host,
          _createNodeConfig(),
          nodeId: _bookmarksNode,
        );
        if (created != null) {
          final applied = await pubsub.configureNode(
            host,
            _bookmarksNode,
            config,
          );
          if (!applied.isType<mox.PubSubError>()) {
            _nodeReady = true;
          }
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        final created = await pubsub.createNode(host, nodeId: _bookmarksNode);
        if (created == null) return;
        final applied =
            await pubsub.configureNode(host, _bookmarksNode, config);
        if (!applied.isType<mox.PubSubError>()) {
          _nodeReady = true;
        }
      } on Exception {
        return;
      }
    } finally {
      _ensureNodeInFlight = false;
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
    final result = await fetchAllWithStatus();
    return result.items;
  }

  Future<PubSubFetchResult<MucBookmark>> fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const PubSubFetchResult(
        items: _emptyMucBookmarks,
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
        _cache.clear();
        return const PubSubFetchResult(
          items: _emptyMucBookmarks,
          isSuccess: true,
          isComplete: true,
        );
      }
      return const PubSubFetchResult(
        items: _emptyMucBookmarks,
        isSuccess: false,
        isComplete: false,
      );
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = items
        .map((item) => _parseItem(item))
        .whereType<MucBookmark>()
        .toList(growable: false);
    _cache
      ..clear()
      ..addAll({
        for (final entry in parsed) entry.roomBare.toBare().toString(): entry,
      });
    return PubSubFetchResult(
      items: List<MucBookmark>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: _isSnapshotComplete(
        itemsCount: parsed.length,
        maxItems: fetchLimit,
      ),
    );
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
      createNodeConfig: _createNodeConfig(),
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
    final result = await pubsub.retract(
      host,
      _bookmarksNode,
      normalizedRoom,
      notify: _notifyEnabled,
    );
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
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;

    MucBookmark? parsed;
    if (event.item.payload case final payload?) {
      parsed = MucBookmark.fromBookmarks2Xml(payload, itemId: event.item.id);
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null && itemId.isNotEmpty) {
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
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
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

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != _bookmarksNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (event.from.toBare().toString() != host.toString()) return;
    await _refreshFromServer();
  }

  Future<void> _handleSubscriptionChanged(
    PubSubSubscriptionChangedEvent event,
  ) async {
    if (event.node != _bookmarksNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    final subscriber = event.subscriberJid?.trim();
    if (subscriber == null || subscriber.isEmpty) return;

    late final mox.JID subscriberJid;
    try {
      subscriberJid = mox.JID.fromString(subscriber).toBare();
    } on Exception {
      return;
    }
    if (subscriberJid.toString() != host.toString()) return;

    if (event.state == mox.SubscriptionState.subscribed) return;
    await subscribe();
  }

  Future<void> _handleNodeDeleted(mox.PubSubNodeDeletedEvent event) async {
    if (event.node != _bookmarksNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    unawaited(_bootstrap());
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != _bookmarksNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    unawaited(_bootstrap());
  }

  Future<void> _refreshFromServer() async {
    final previousCache = Map<String, MucBookmark>.from(_cache);
    final items = await fetchAll();
    final freshIds =
        items.map((item) => item.roomBare.toBare().toString()).toSet();
    _cache.clear();
    for (final item in items) {
      final id = item.roomBare.toBare().toString();
      final cached = previousCache[id];
      final merged = _mergeBookmarks(incoming: item, cached: cached);
      _cache[id] = merged;
      _emitUpdate(merged);
    }

    final removedIds = previousCache.keys
        .where((id) => !freshIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      final removed = previousCache[id];
      if (removed == null) continue;
      _emitRetraction(removed.roomBare);
    }
  }

  void _clearCache() {
    if (_cache.isEmpty) return;
    final items = _cache.values.toList(growable: false);
    _cache.clear();
    for (final item in items) {
      _emitRetraction(item.roomBare);
    }
  }

  bool _isFromHost(String? from, mox.JID host) {
    final raw = from?.trim();
    if (raw == null || raw.isEmpty) return false;
    try {
      return mox.JID.fromString(raw).toBare().toString() == host.toString();
    } on Exception {
      return false;
    }
  }
}
