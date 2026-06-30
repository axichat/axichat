// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/email_validation.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/xml_safety.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const conversationIndexNode = 'urn:axi:conversations';
const conversationIndexNotifyFeature = 'urn:axi:conversations+notify';
const conversationAnnotationsNode = 'urn:axi:conversation-annotations:1';
const conversationAnnotationsNotifyFeature =
    'urn:axi:conversation-annotations:1+notify';

const _convTag = 'conv';
const _peerAttr = 'peer';
const _kindAttr = 'kind';
const _lastTsAttr = 'last_ts';
const _lastIdAttr = 'last_id';
const _pinnedAttr = 'pinned';
const _hiddenAttr = 'hidden';
const _mutedUntilAttr = 'muted_until';
const _archivedAttr = 'archived';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _conversationIndexBootstrapOperationName =
    'ConversationIndexManager.bootstrapOnNegotiations';
const String _conversationIndexRefreshOperationName =
    'ConversationIndexManager.refreshFromServer';
const String _conversationAnnotationsBootstrapOperationName =
    'ConversationAnnotationsManager.bootstrapOnNegotiations';
const String _conversationAnnotationsRefreshOperationName =
    'ConversationAnnotationsManager.refreshFromServer';

const Object _convItemFieldUnset = Object();

enum ConvItemKind {
  direct,
  email,
  group;

  String get wireValue => switch (this) {
    ConvItemKind.direct => 'direct',
    ConvItemKind.email => 'email',
    ConvItemKind.group => 'group',
  };

  String get itemIdPrefix => switch (this) {
    ConvItemKind.direct => '',
    ConvItemKind.email => 'email',
    ConvItemKind.group => 'group',
  };

  static ConvItemKind fromWireValue(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'email' => ConvItemKind.email,
      'group' || 'muc' => ConvItemKind.group,
      _ => ConvItemKind.direct,
    };
  }
}

final class ConvItem {
  ConvItem({
    required mox.JID peerBare,
    required this.lastTimestamp,
    this.lastId,
    this.pinned = false,
    this.archived = false,
    this.hidden,
    this.mutedUntil,
  }) : kind = ConvItemKind.direct,
       peer = peerBare.toBare().toString();

  ConvItem.email({
    required String peer,
    required this.lastTimestamp,
    this.lastId,
    this.pinned = false,
    this.archived = false,
    this.hidden,
    this.mutedUntil,
  }) : kind = ConvItemKind.email,
       peer = _normalizeEmailPeer(peer);

  ConvItem.group({
    required mox.JID peerBare,
    required this.lastTimestamp,
    this.lastId,
    this.pinned = false,
    this.archived = false,
    this.hidden,
    this.mutedUntil,
  }) : kind = ConvItemKind.group,
       peer = peerBare.toBare().toString();

  const ConvItem._({
    required this.peer,
    required this.kind,
    required this.lastTimestamp,
    required this.lastId,
    required this.pinned,
    required this.archived,
    required this.hidden,
    required this.mutedUntil,
  });

  final String peer;
  final ConvItemKind kind;
  final DateTime lastTimestamp;
  final String? lastId;
  final bool pinned;
  final DateTime? mutedUntil;
  final bool archived;
  final bool? hidden;

  bool get isDirect => kind == ConvItemKind.direct;

  bool get isEmail => kind == ConvItemKind.email;

  bool get isGroup => kind == ConvItemKind.group;

  mox.JID get peerBare => mox.JID.fromString(peer).toBare();

  String get itemId => itemIdFor(kind: kind, peer: peer);

  ConvItem normalized() {
    return copyWith(peer: _normalizePeerForKind(kind, peer));
  }

  static String itemIdFor({required ConvItemKind kind, required String peer}) {
    final normalized = _normalizePeerForKind(kind, peer);
    if (kind == ConvItemKind.direct) {
      return normalized;
    }
    return '${kind.itemIdPrefix}:$normalized';
  }

  ConvItem copyWith({
    String? peer,
    mox.JID? peerBare,
    DateTime? lastTimestamp,
    Object? lastId = _convItemFieldUnset,
    ConvItemKind? kind,
    bool? pinned,
    Object? mutedUntil = _convItemFieldUnset,
    bool? archived,
    Object? hidden = _convItemFieldUnset,
  }) {
    final nextKind = kind ?? this.kind;
    final nextPeer = peerBare?.toBare().toString() ?? peer ?? this.peer;
    return ConvItem._(
      peer: _normalizePeerForKind(nextKind, nextPeer),
      kind: nextKind,
      lastTimestamp: lastTimestamp ?? this.lastTimestamp,
      lastId: identical(lastId, _convItemFieldUnset)
          ? this.lastId
          : lastId as String?,
      pinned: pinned ?? this.pinned,
      mutedUntil: identical(mutedUntil, _convItemFieldUnset)
          ? this.mutedUntil
          : mutedUntil as DateTime?,
      archived: archived ?? this.archived,
      hidden: identical(hidden, _convItemFieldUnset)
          ? this.hidden
          : hidden as bool?,
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

  static bool? _parseNullableBool(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => null,
    };
  }

  static DateTime? _parseTimestamp(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return DateTime.tryParse(normalized);
  }

  static String _normalizeEmailPeer(String peer) => peer.trim().toLowerCase();

  static String _normalizePeerForKind(ConvItemKind kind, String peer) {
    final trimmed = peer.trim();
    if (trimmed.isEmpty) {
      return '';
    }
    switch (kind) {
      case ConvItemKind.email:
        return _normalizeEmailPeer(trimmed);
      case ConvItemKind.direct:
      case ConvItemKind.group:
        try {
          return mox.JID.fromString(trimmed).toBare().toString();
        } on Exception {
          return trimmed;
        }
    }
  }

  static String? _parsePeerForKind(String rawPeer, ConvItemKind kind) {
    switch (kind) {
      case ConvItemKind.email:
        final normalized = _normalizeEmailPeer(rawPeer);
        return normalized.isValidEmailAddress ? normalized : null;
      case ConvItemKind.direct:
      case ConvItemKind.group:
        try {
          return mox.JID.fromString(rawPeer).toBare().toString();
        } on Exception {
          return null;
        }
    }
  }

  static ConvItem? fromXml(
    mox.XMLNode node, {
    String xmlns = conversationIndexNode,
  }) {
    if (node.tag != _convTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != xmlns) {
      return null;
    }

    final rawPeer = node.attributes[_peerAttr]?.toString().trim();
    if (rawPeer == null || rawPeer.isEmpty) {
      return null;
    }

    final kind = ConvItemKind.fromWireValue(
      node.attributes[_kindAttr]?.toString(),
    );
    final peer = _parsePeerForKind(rawPeer, kind);
    if (peer == null || peer.isEmpty) {
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
    final hiddenRaw = node.attributes[_hiddenAttr]?.toString();
    final mutedUntilRaw = node.attributes[_mutedUntilAttr]?.toString();
    final mutedUntil = _parseTimestamp(mutedUntilRaw)?.toUtc();

    return ConvItem._(
      peer: peer,
      kind: kind,
      lastTimestamp: lastTimestamp,
      lastId: lastId?.isNotEmpty == true ? lastId : null,
      pinned: _parseBool(pinnedRaw, defaultValue: false),
      archived: _parseBool(archivedRaw, defaultValue: false),
      hidden: _parseNullableBool(hiddenRaw),
      mutedUntil: mutedUntil,
    );
  }

  mox.XMLNode toXml({String xmlns = conversationIndexNode}) {
    final lastTs = lastTimestamp.toUtc().toIso8601String();
    final mutedUntilIso = mutedUntil?.toUtc().toIso8601String();
    final trimmedLastId = lastId?.trim();
    return mox.XMLNode.xmlns(
      tag: _convTag,
      xmlns: xmlns,
      attributes: {
        _peerAttr: escapeXmlAttribute(_normalizePeerForKind(kind, peer)),
        _kindAttr: kind.wireValue,
        _lastTsAttr: lastTs,
        if (trimmedLastId?.isNotEmpty == true)
          _lastIdAttr: escapeXmlAttribute(trimmedLastId!),
        _pinnedAttr: pinned.toString(),
        _archivedAttr: archived.toString(),
        if (hidden != null) _hiddenAttr: hidden!.toString(),
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

abstract class _ConversationItemPubSubManager
    extends PepItemPubSubNodeManager<ConvItem>
    implements PubSubHubDelegate {
  _ConversationItemPubSubManager({
    required String managerId,
    required String nodeId,
    required String bootstrapOperationName,
    required String refreshOperationName,
    required Set<ConvItemKind> allowedKinds,
    String? maxItems,
  }) : _maxItems = maxItems ?? _defaultMaxItems,
       _nodeId = nodeId,
       _bootstrapOperationName = bootstrapOperationName,
       _refreshOperationName = refreshOperationName,
       _allowedKinds = allowedKinds,
       super(managerId);

  static const String _defaultMaxItems = '1000';

  final String _maxItems;
  final String _nodeId;
  final String _bootstrapOperationName;
  final String _refreshOperationName;
  final Set<ConvItemKind> _allowedKinds;

  final StreamController<ConvItemUpdate> _updatesController =
      StreamController<ConvItemUpdate>.broadcast();
  Stream<ConvItemUpdate> get updates => _updatesController.stream;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    conversationIndexSyncRateLimit,
  );

  @override
  String get nodeId => _nodeId;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _bootstrapOperationName;

  @override
  String get refreshOperationName => _refreshOperationName;

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

  bool _allows(ConvItem item) => _allowedKinds.contains(item.kind);

  ConvItem? cachedForPeer(mox.JID peerBare) =>
      cachedForIdentity(kind: ConvItemKind.direct, peer: peerBare.toString());

  ConvItem? cachedForIdentity({
    required ConvItemKind kind,
    required String peer,
  }) => cache[ConvItem.itemIdFor(kind: kind, peer: peer)];

  void cacheSnapshot(Iterable<ConvItem> items, {required bool isComplete}) {
    final previousCache = Map<String, ConvItem>.from(cache);
    if (isComplete) {
      cache.clear();
    }
    for (final item in items) {
      if (!_allows(item)) continue;
      final itemId = itemIdOf(item);
      cache[itemId] = mergeRefreshedItem(item, cached: previousCache[itemId]);
    }
  }

  Future<bool> upsert(ConvItem item) async {
    final normalized = item.normalized();
    if (!_allows(normalized)) return false;
    return publishItem(normalized);
  }

  Future<bool> retract(String itemId) => retractItem(itemId);

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
    if (!_allows(incoming)) return null;
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
      hidden: incoming.hidden ?? resolvedCache.hidden,
      mutedUntil: incoming.mutedUntil,
    );

    if (merged.lastTimestamp.toUtc() == resolvedCache.lastTimestamp.toUtc() &&
        (merged.lastId ?? '') == (resolvedCache.lastId ?? '') &&
        merged.pinned == resolvedCache.pinned &&
        merged.archived == resolvedCache.archived &&
        merged.hidden == resolvedCache.hidden &&
        merged.mutedUntil?.toUtc() == resolvedCache.mutedUntil?.toUtc()) {
      return null;
    }
    return merged;
  }

  @override
  ConvItem? parsePayload(mox.XMLNode payload, {String? itemId}) {
    final item = ConvItem.fromXml(payload, xmlns: nodeId);
    if (item == null || !_allows(item)) return null;
    return item;
  }

  @override
  bool ignoreUnparsedPayload(mox.XMLNode payload, {String? itemId}) {
    final item = ConvItem.fromXml(payload, xmlns: nodeId);
    return item != null && !_allows(item);
  }

  @override
  String itemIdOf(ConvItem payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(ConvItem payload) => payload.toXml(xmlns: nodeId);

  @override
  void emitUpdatePayload(ConvItem payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(ConvItemUpdated(payload));
    }
    getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    if (itemId.contains(':')) {
      return;
    }
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

final class ConversationIndexManager extends _ConversationItemPubSubManager {
  ConversationIndexManager({super.maxItems})
    : super(
        managerId: managerId,
        nodeId: conversationIndexNode,
        bootstrapOperationName: _conversationIndexBootstrapOperationName,
        refreshOperationName: _conversationIndexRefreshOperationName,
        allowedKinds: const {ConvItemKind.direct},
      );

  static const String managerId = 'axi.conversation.index';
}

final class ConversationAnnotationsManager
    extends _ConversationItemPubSubManager {
  ConversationAnnotationsManager({super.maxItems})
    : super(
        managerId: managerId,
        nodeId: conversationAnnotationsNode,
        bootstrapOperationName: _conversationAnnotationsBootstrapOperationName,
        refreshOperationName: _conversationAnnotationsRefreshOperationName,
        allowedKinds: const {ConvItemKind.email, ConvItemKind.group},
      );

  static const String managerId = 'axi.conversation.annotations';
}
