// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const conversationIndexNode = 'urn:axi:conversations';
const conversationIndexNotifyFeature = 'urn:axi:conversations+notify';

const _convTag = 'conv';
const _peerAttr = 'peer';
const _lastTsAttr = 'last_ts';
const _lastIdAttr = 'last_id';
const _pinnedAttr = 'pinned';
const _mutedUntilAttr = 'muted_until';
const _archivedAttr = 'archived';
const Duration _ensureNodeBackoff = Duration(minutes: 5);

final class ConvItem {
  const ConvItem({
    required this.peerBare,
    required this.lastTimestamp,
    this.lastId,
    this.pinned = false,
    this.archived = false,
    this.mutedUntil,
  });

  final mox.JID peerBare;
  final DateTime lastTimestamp;
  final String? lastId;
  final bool pinned;
  final DateTime? mutedUntil;
  final bool archived;

  String get itemId => peerBare.toBare().toString();

  ConvItem copyWith({
    mox.JID? peerBare,
    DateTime? lastTimestamp,
    String? lastId,
    bool? pinned,
    DateTime? mutedUntil,
    bool? archived,
  }) {
    return ConvItem(
      peerBare: peerBare ?? this.peerBare,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      lastId: lastId ?? this.lastId,
      pinned: pinned ?? this.pinned,
      mutedUntil: mutedUntil ?? this.mutedUntil,
      archived: archived ?? this.archived,
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

  static DateTime? _parseTimestamp(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return DateTime.tryParse(normalized);
  }

  static ConvItem? fromXml(mox.XMLNode node) {
    if (node.tag != _convTag) return null;
    if (node.attributes['xmlns']?.toString() != conversationIndexNode) {
      return null;
    }

    final rawPeer = node.attributes[_peerAttr]?.toString().trim();
    if (rawPeer == null || rawPeer.isEmpty) return null;
    late final mox.JID peer;
    try {
      peer = mox.JID.fromString(rawPeer).toBare();
    } on Exception {
      return null;
    }

    final lastTsRaw = node.attributes[_lastTsAttr]?.toString();
    final lastTimestamp = _parseTimestamp(lastTsRaw)?.toUtc();
    if (lastTimestamp == null) return null;

    final lastId = node.attributes[_lastIdAttr]?.toString().trim();
    final pinnedRaw = node.attributes[_pinnedAttr]?.toString();
    final archivedRaw = node.attributes[_archivedAttr]?.toString();
    final mutedUntilRaw = node.attributes[_mutedUntilAttr]?.toString();
    final mutedUntil = _parseTimestamp(mutedUntilRaw)?.toUtc();

    return ConvItem(
      peerBare: peer,
      lastTimestamp: lastTimestamp,
      lastId: lastId?.isNotEmpty == true ? lastId : null,
      pinned: _parseBool(pinnedRaw, defaultValue: false),
      archived: _parseBool(archivedRaw, defaultValue: false),
      mutedUntil: mutedUntil,
    );
  }

  mox.XMLNode toXml() {
    final lastTs = lastTimestamp.toUtc().toIso8601String();
    final mutedUntilIso = mutedUntil?.toUtc().toIso8601String();
    final trimmedLastId = lastId?.trim();
    return mox.XMLNode.xmlns(
      tag: _convTag,
      xmlns: conversationIndexNode,
      attributes: {
        _peerAttr: peerBare.toBare().toString(),
        _lastTsAttr: lastTs,
        if (trimmedLastId?.isNotEmpty == true) _lastIdAttr: trimmedLastId!,
        _pinnedAttr: pinned.toString(),
        _archivedAttr: archived.toString(),
        if (mutedUntilIso?.isNotEmpty == true) _mutedUntilAttr: mutedUntilIso!,
      },
    );
  }
}

const List<ConvItem> _emptyConvItems = <ConvItem>[];

sealed class ConvItemUpdate {
  const ConvItemUpdate();
}

final class ConvItemUpdated extends ConvItemUpdate {
  const ConvItemUpdated(this.item);

  final ConvItem item;
}

final class ConvItemRetracted extends ConvItemUpdate {
  const ConvItemRetracted(this.peerBare);

  final mox.JID peerBare;
}

final class ConversationIndexItemUpdatedEvent extends mox.XmppEvent {
  ConversationIndexItemUpdatedEvent(this.item);

  final ConvItem item;
}

final class ConversationIndexItemRetractedEvent extends mox.XmppEvent {
  ConversationIndexItemRetractedEvent(this.peerBare);

  final mox.JID peerBare;
}

final class ConversationIndexManager extends mox.XmppManagerBase {
  ConversationIndexManager({
    String? maxItems,
  })  : _maxItems = maxItems ?? _defaultMaxItems,
        super(managerId);

  static const String managerId = 'axi.conversation.index';
  static const String _defaultMaxItems = '1000';
  static const String _publishModelPublishers = 'publishers';
  static const String _sendLastOnSubscribe = 'on_sub';
  static const bool _notifyEnabled = true;
  static const bool _deliverNotificationsEnabled = true;
  static const bool _deliverPayloadsEnabled = true;
  static const bool _persistItemsEnabled = true;
  static const bool _presenceBasedDeliveryDisabled = false;

  final String _maxItems;

  final StreamController<ConvItemUpdate> _updatesController =
      StreamController<ConvItemUpdate>.broadcast();
  Stream<ConvItemUpdate> get updates => _updatesController.stream;

  final Map<String, ConvItem> _cache = {};
  final SyncRateLimiter _rateLimiter =
      SyncRateLimiter(conversationIndexSyncRateLimit);
  DateTime? _lastEnsureAttempt;
  bool _ensureNodeInFlight = false;
  bool _ensureNodePending = false;
  bool _nodeReady = false;

  @override
  Future<bool> isSupported() async => true;

  ConvItem? cachedForPeer(mox.JID peerBare) =>
      _cache[peerBare.toBare().toString()];

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
        sendLastPublishedItem: _sendLastOnSubscribe,
      );

  mox.NodeConfig _createNodeConfig() => _nodeConfig().toNodeConfig();

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
        accessModel: mox.AccessModel.whitelist.value,
        maxItems: _maxItems,
        persistItems: _persistItemsEnabled,
        publishModel: _publishModelPublishers,
        sendLastPublishedItem: _sendLastOnSubscribe,
      );

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getFullJID().toBare();
    } on Exception {
      return null;
    }
  }

  SafePubSubManager? _pubSub() =>
      getAttributes().getManagerById<SafePubSubManager>(mox.pubsubManager);

  int? _parseMaxItems(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) return null;
    return int.tryParse(normalized);
  }

  int _resolveFetchLimit() {
    final parsed = _parseMaxItems(_maxItems);
    if (parsed != null) return parsed;
    return int.parse(_defaultMaxItems);
  }

  bool _isSnapshotComplete({
    required int itemsCount,
    required int maxItems,
  }) =>
      itemsCount < maxItems;

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

  bool _shouldProcessSyncEvent() {
    if (_rateLimiter.allowEvent()) {
      return true;
    }
    if (_rateLimiter.shouldRefreshNow()) {
      unawaited(_refreshFromServer());
    }
    return false;
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
          await pubsub.configureNode(host, conversationIndexNode, config);
      if (!configured.isType<mox.PubSubError>()) {
        _nodeReady = true;
        return;
      }
      final configuredError = configured.get<mox.PubSubError>();
      final shouldCreateNode = configuredError.indicatesMissingNode;
      if (!shouldCreateNode) {
        return;
      }

      try {
        await pubsub.createNodeWithConfig(
          host,
          _createNodeConfig(),
          nodeId: conversationIndexNode,
        );
        final applied =
            await pubsub.configureNode(host, conversationIndexNode, config);
        if (!applied.isType<mox.PubSubError>()) {
          _nodeReady = true;
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        await pubsub.createNode(host, nodeId: conversationIndexNode);
        final applied =
            await pubsub.configureNode(host, conversationIndexNode, config);
        if (!applied.isType<mox.PubSubError>()) {
          _nodeReady = true;
        }
      } on Exception {
        return;
      }
    } finally {
      _ensureNodeInFlight = false;
      final shouldRetry = _ensureNodePending && !_nodeReady;
      _ensureNodePending = false;
      if (shouldRetry) {
        unawaited(_bootstrap());
      }
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    final result = await pubsub.subscribe(host, conversationIndexNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.MalformedResponseError) return;
      return;
    }
  }

  Future<List<ConvItem>> fetchAll() async {
    final result = await fetchAllWithStatus();
    return result.items;
  }

  Future<PubSubFetchResult<ConvItem>> fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const PubSubFetchResult(
        items: _emptyConvItems,
        isSuccess: false,
        isComplete: false,
      );
    }

    final fetchLimit = _resolveFetchLimit();
    final result = await pubsub.getItems(
      host,
      conversationIndexNode,
      maxItems: fetchLimit,
    );
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) {
        _cache.clear();
        return const PubSubFetchResult(
          items: _emptyConvItems,
          isSuccess: true,
          isComplete: true,
        );
      }
      return const PubSubFetchResult(
        items: _emptyConvItems,
        isSuccess: false,
        isComplete: false,
      );
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = items
        .map((item) => item.payload)
        .whereType<mox.XMLNode>()
        .map(ConvItem.fromXml)
        .whereType<ConvItem>()
        .toList(growable: false);
    _cache
      ..clear()
      ..addAll({
        for (final entry in parsed) entry.itemId: entry,
      });
    return PubSubFetchResult(
      items: List<ConvItem>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: _isSnapshotComplete(
        itemsCount: parsed.length,
        maxItems: fetchLimit,
      ),
    );
  }

  Future<void> upsert(ConvItem item) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final normalized = item.copyWith(peerBare: item.peerBare.toBare());
    final id = normalized.itemId;
    final payload = normalized.toXml();
    final result = await pubsub.publish(
      host,
      conversationIndexNode,
      payload,
      id: id,
      options: _publishOptions(),
      autoCreate: true,
      createNodeConfig: _createNodeConfig(),
    );
    if (result.isType<mox.PubSubError>()) {
      return;
    }

    _cache[id] = normalized;
    final update = ConvItemUpdated(normalized);
    if (!_updatesController.isClosed) {
      _updatesController.add(update);
    }
    getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(normalized));
  }

  Future<void> archive(mox.JID peer, bool archived) async {
    final cached = cachedForPeer(peer);
    final baseline = cached ??
        ConvItem(
          peerBare: peer.toBare(),
          lastTimestamp: DateTime.timestamp().toUtc(),
        );
    final next = baseline.copyWith(archived: archived);
    await upsert(next);
  }

  Future<void> pin(mox.JID peer, bool pinned) async {
    final cached = cachedForPeer(peer);
    final baseline = cached ??
        ConvItem(
          peerBare: peer.toBare(),
          lastTimestamp: DateTime.timestamp().toUtc(),
        );
    final next = baseline.copyWith(pinned: pinned);
    await upsert(next);
  }

  Future<void> mute(mox.JID peer, DateTime? until) async {
    final cached = cachedForPeer(peer);
    final baseline = cached ??
        ConvItem(
          peerBare: peer.toBare(),
          lastTimestamp: DateTime.timestamp().toUtc(),
        );
    final next = baseline.copyWith(mutedUntil: until?.toUtc());
    await upsert(next);
  }

  String? _maxLastId(String? a, String? b) {
    final aTrimmed = a?.trim();
    final bTrimmed = b?.trim();
    if (aTrimmed?.isNotEmpty != true) {
      return bTrimmed?.isNotEmpty == true ? bTrimmed : null;
    }
    if (bTrimmed?.isNotEmpty != true) return aTrimmed;
    return aTrimmed!.compareTo(bTrimmed!) >= 0 ? aTrimmed : bTrimmed;
  }

  ConvItem? _mergeIncoming(
    ConvItem incoming, {
    ConvItem? cached,
  }) {
    final resolvedCache = cached ?? _cache[incoming.itemId];
    if (resolvedCache == null) return incoming;

    final incomingTs = incoming.lastTimestamp.toUtc();
    final cachedTs = resolvedCache.lastTimestamp.toUtc();
    final mergedLastTimestamp =
        incomingTs.isAfter(cachedTs) ? incomingTs : cachedTs;

    final String? mergedLastId;
    if (incomingTs.isAfter(cachedTs)) {
      mergedLastId = incoming.lastId;
    } else if (incomingTs.isBefore(cachedTs)) {
      mergedLastId = resolvedCache.lastId;
    } else {
      mergedLastId = _maxLastId(resolvedCache.lastId, incoming.lastId);
    }

    final merged = resolvedCache.copyWith(
      lastTimestamp: mergedLastTimestamp,
      lastId: mergedLastId,
      pinned: incoming.pinned,
      archived: incoming.archived,
      mutedUntil: incoming.mutedUntil,
    );

    if (merged.lastTimestamp.toUtc() == resolvedCache.lastTimestamp.toUtc() &&
        (merged.lastId ?? '') == (resolvedCache.lastId ?? '') &&
        merged.pinned == resolvedCache.pinned &&
        merged.archived == resolvedCache.archived &&
        (merged.mutedUntil?.toUtc() == resolvedCache.mutedUntil?.toUtc())) {
      return null;
    }
    return merged;
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != conversationIndexNode) return;
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
    if (!_shouldProcessSyncEvent()) return;

    ConvItem? parsed;
    if (event.item.payload case final payload?) {
      parsed = ConvItem.fromXml(payload);
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null && itemId.isNotEmpty) {
        final itemResult =
            await pubsub.getItem(host, conversationIndexNode, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          final payload = itemResult.get<mox.PubSubItem>().payload;
          if (payload != null) {
            parsed = ConvItem.fromXml(payload);
          }
        }
      }
    }

    if (parsed == null) return;
    final merged = _mergeIncoming(parsed);
    if (merged == null) return;
    final maxItems = _resolveFetchLimit();
    if (_cache.length >= maxItems && !_cache.containsKey(merged.itemId)) {
      await _refreshFromServer();
      return;
    }

    _cache[merged.itemId] = merged;
    final update = ConvItemUpdated(merged);
    if (!_updatesController.isClosed) {
      _updatesController.add(update);
    }
    getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(merged));
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != conversationIndexNode) return;
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
    if (event.itemIds.isEmpty) return;
    if (!_shouldProcessSyncEvent()) return;
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) continue;
      _cache.remove(normalized);
      late final mox.JID peer;
      try {
        peer = mox.JID.fromString(normalized).toBare();
      } on Exception {
        continue;
      }
      final update = ConvItemRetracted(peer);
      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
      getAttributes().sendEvent(ConversationIndexItemRetractedEvent(peer));
    }
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != conversationIndexNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (event.from.toBare().toString() != host.toString()) return;
    await _refreshFromServer();
  }

  Future<void> _handleSubscriptionChanged(
    PubSubSubscriptionChangedEvent event,
  ) async {
    if (event.node != conversationIndexNode) return;
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
    if (event.node != conversationIndexNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    _ensureNodePending = true;
    if (!_ensureNodeInFlight) {
      unawaited(_bootstrap());
    }
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != conversationIndexNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    _ensureNodePending = true;
    if (!_ensureNodeInFlight) {
      unawaited(_bootstrap());
    }
  }

  Future<void> _refreshFromServer() async {
    final previousCache = Map<String, ConvItem>.from(_cache);
    final items = await fetchAll();
    final freshIds = items.map((item) => item.itemId).toSet();
    _cache.clear();
    for (final item in items) {
      final merged =
          _mergeIncoming(item, cached: previousCache[item.itemId]) ?? item;
      _cache[merged.itemId] = merged;
      final update = ConvItemUpdated(merged);
      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
      getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(merged));
    }

    final removedIds = previousCache.keys
        .where((id) => !freshIds.contains(id))
        .toList(growable: false);
    for (final id in removedIds) {
      final removed = previousCache[id];
      if (removed == null) continue;
      final update = ConvItemRetracted(removed.peerBare);
      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
      getAttributes().sendEvent(
        ConversationIndexItemRetractedEvent(removed.peerBare),
      );
    }
  }

  void _clearCache() {
    if (_cache.isEmpty) return;
    final items = _cache.values.toList(growable: false);
    _cache.clear();
    for (final item in items) {
      final update = ConvItemRetracted(item.peerBare);
      if (!_updatesController.isClosed) {
        _updatesController.add(update);
      }
      getAttributes().sendEvent(
        ConversationIndexItemRetractedEvent(item.peerBare),
      );
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
