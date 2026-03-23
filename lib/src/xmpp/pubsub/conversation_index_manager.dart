// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
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
const String _conversationIndexBootstrapOperationName =
    'ConversationIndexManager.bootstrapOnNegotiations';
const String _conversationIndexRefreshOperationName =
    'ConversationIndexManager.refreshFromServer';

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
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  static ConvItem? fromXml(mox.XMLNode node) {
    if (node.tag != _convTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != conversationIndexNode) {
      return null;
    }

    final rawPeer = node.attributes[_peerAttr]?.toString().trim();
    if (rawPeer == null || rawPeer.isEmpty) {
      return null;
    }
    late final mox.JID peer;
    try {
      peer = mox.JID.fromString(rawPeer).toBare();
    } on Exception {
      return null;
    }

    final lastTsRaw = node.attributes[_lastTsAttr]?.toString();
    final lastTimestamp = _parseTimestamp(lastTsRaw)?.toUtc();
    if (lastTimestamp == null) {
      return null;
    }

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

final class ConversationIndexManager extends PepItemPubSubNodeManager<ConvItem>
    implements PubSubHubDelegate {
  ConversationIndexManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.conversation.index';
  static const String _defaultMaxItems = '1000';

  final String _maxItems;

  final StreamController<ConvItemUpdate> _updatesController =
      StreamController<ConvItemUpdate>.broadcast();
  Stream<ConvItemUpdate> get updates => _updatesController.stream;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    conversationIndexSyncRateLimit,
  );

  @override
  String get nodeId => conversationIndexNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _conversationIndexBootstrapOperationName;

  @override
  String get refreshOperationName => _conversationIndexRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubConversations;

  @override
  bool get treatMissingNodeAsEmptySnapshot => true;

  @override
  bool get publishAutoCreate => true;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  ConvItem? cachedForPeer(mox.JID peerBare) =>
      cache[peerBare.toBare().toString()];

  void cacheSnapshot(Iterable<ConvItem> items, {required bool isComplete}) {
    final previousCache = Map<String, ConvItem>.from(cache);
    if (isComplete) {
      cache.clear();
    }
    for (final item in items) {
      final itemId = itemIdOf(item);
      cache[itemId] = mergeRefreshedItem(item, cached: previousCache[itemId]);
    }
  }

  Future<bool> upsert(ConvItem item) async {
    final normalized = item.copyWith(peerBare: item.peerBare.toBare());
    return publishItem(normalized);
  }

  Future<void> archive(mox.JID peer, bool archived) async {
    final cached = cachedForPeer(peer);
    final baseline =
        cached ??
        ConvItem(
          peerBare: peer.toBare(),
          lastTimestamp: DateTime.timestamp().toUtc(),
        );
    final next = baseline.copyWith(archived: archived);
    await upsert(next);
  }

  Future<void> pin(mox.JID peer, bool pinned) async {
    final cached = cachedForPeer(peer);
    final baseline =
        cached ??
        ConvItem(
          peerBare: peer.toBare(),
          lastTimestamp: DateTime.timestamp().toUtc(),
        );
    final next = baseline.copyWith(pinned: pinned);
    await upsert(next);
  }

  Future<void> mute(mox.JID peer, DateTime? until) async {
    final cached = cachedForPeer(peer);
    final baseline =
        cached ??
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
    if (bTrimmed?.isNotEmpty != true) {
      return aTrimmed;
    }
    return aTrimmed!.compareTo(bTrimmed!) >= 0 ? aTrimmed : bTrimmed;
  }

  ConvItem? _mergeIncoming(ConvItem incoming, {ConvItem? cached}) {
    final resolvedCache = cached ?? cache[incoming.itemId];
    if (resolvedCache == null) {
      return incoming;
    }

    final incomingTs = incoming.lastTimestamp.toUtc();
    final cachedTs = resolvedCache.lastTimestamp.toUtc();
    final mergedLastTimestamp = incomingTs.isAfter(cachedTs)
        ? incomingTs
        : cachedTs;

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
        merged.mutedUntil?.toUtc() == resolvedCache.mutedUntil?.toUtc()) {
      return null;
    }
    return merged;
  }

  @override
  ConvItem? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      ConvItem.fromXml(payload);

  @override
  String itemIdOf(ConvItem payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(ConvItem payload) => payload.toXml();

  @override
  void emitUpdatePayload(ConvItem payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(ConvItemUpdated(payload));
    }
    getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    late final mox.JID peer;
    try {
      peer = mox.JID.fromString(itemId).toBare();
    } on Exception {
      return;
    }
    if (!_updatesController.isClosed) {
      _updatesController.add(ConvItemRetracted(peer));
    }
    getAttributes().sendEvent(ConversationIndexItemRetractedEvent(peer));
  }

  @override
  ConvItem? mergeIncomingNotification(ConvItem incoming, {ConvItem? cached}) =>
      _mergeIncoming(incoming, cached: cached);

  @override
  ConvItem mergeRefreshedItem(ConvItem incoming, {ConvItem? cached}) =>
      _mergeIncoming(incoming, cached: cached) ?? incoming;
}
