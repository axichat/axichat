import 'dart:async';

import 'package:moxxmpp/moxxmpp.dart' as mox;

const conversationIndexNode = 'urn:ourapp:conversations';

const _convTag = 'conv';
const _peerAttr = 'peer';
const _lastTsAttr = 'last_ts';
const _lastIdAttr = 'last_id';
const _pinnedAttr = 'pinned';
const _mutedUntilAttr = 'muted_until';
const _archivedAttr = 'archived';

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
  static const String _sendLastOnSubscribe = 'on_subscribe';

  final String _maxItems;

  final StreamController<ConvItemUpdate> _updatesController =
      StreamController<ConvItemUpdate>.broadcast();
  Stream<ConvItemUpdate> get updates => _updatesController.stream;

  final Map<String, ConvItem> _cache = {};

  @override
  Future<bool> isSupported() async => true;

  ConvItem? cachedForPeer(mox.JID peerBare) =>
      _cache[peerBare.toBare().toString()];

  mox.NodeConfig _nodeConfig() => mox.NodeConfig(
        accessModel: mox.AccessModel.whitelist,
        publishModel: _publishModelPublishers,
        deliverNotifications: true,
        deliverPayloads: true,
        maxItems: _maxItems,
        notifyRetract: true,
        persistItems: true,
        sendLastPublishedItem: _sendLastOnSubscribe,
      );

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
        accessModel: mox.AccessModel.whitelist.value,
        maxItems: _maxItems,
        persistItems: true,
      );

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getFullJID().toBare();
    } on Exception {
      return null;
    }
  }

  mox.PubSubManager? _pubSub() =>
      getAttributes().getManagerById<mox.PubSubManager>(mox.pubsubManager);

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

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final config = _nodeConfig();

    final configured =
        await pubsub.configure(host, conversationIndexNode, config);
    if (!configured.isType<mox.PubSubError>()) {
      return;
    }

    try {
      final created = await pubsub.createNodeWithConfig(
        host,
        config,
        nodeId: conversationIndexNode,
      );
      if (created != null) return;
    } on Exception {
      // ignore and retry below
    }

    try {
      final created =
          await pubsub.createNode(host, nodeId: conversationIndexNode);
      if (created == null) return;
      await pubsub.configure(host, conversationIndexNode, config);
    } on Exception {
      return;
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
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return const [];

    final result = await pubsub.getItems(host, conversationIndexNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) return const [];
      return const [];
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = items
        .map((item) => item.payload)
        .whereType<mox.XMLNode>()
        .map(ConvItem.fromXml)
        .whereType<ConvItem>()
        .toList(growable: false);
    for (final entry in parsed) {
      _cache[entry.itemId] = entry;
    }
    return List<ConvItem>.unmodifiable(parsed);
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
      createNodeConfig: _nodeConfig(),
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

  ConvItem? _mergeIncoming(ConvItem incoming) {
    final cached = _cache[incoming.itemId];
    if (cached == null) return incoming;

    final incomingTs = incoming.lastTimestamp.toUtc();
    final cachedTs = cached.lastTimestamp.toUtc();
    final mergedLastTimestamp =
        incomingTs.isAfter(cachedTs) ? incomingTs : cachedTs;

    final String? mergedLastId;
    if (incomingTs.isAfter(cachedTs)) {
      mergedLastId = incoming.lastId;
    } else if (incomingTs.isBefore(cachedTs)) {
      mergedLastId = cached.lastId;
    } else {
      mergedLastId = _maxLastId(cached.lastId, incoming.lastId);
    }

    final merged = cached.copyWith(
      lastTimestamp: mergedLastTimestamp,
      lastId: mergedLastId,
      pinned: incoming.pinned,
      archived: incoming.archived,
      mutedUntil: incoming.mutedUntil,
    );

    if (merged.lastTimestamp.toUtc() == cached.lastTimestamp.toUtc() &&
        (merged.lastId ?? '') == (cached.lastId ?? '') &&
        merged.pinned == cached.pinned &&
        merged.archived == cached.archived &&
        (merged.mutedUntil?.toUtc() == cached.mutedUntil?.toUtc())) {
      return null;
    }
    return merged;
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != conversationIndexNode) return;

    ConvItem? parsed;
    if (event.item.payload case final payload?) {
      parsed = ConvItem.fromXml(payload);
    } else {
      final pubsub = _pubSub();
      final host = _selfPepHost();
      final itemId = event.item.id.trim();
      if (pubsub != null && host != null && itemId.isNotEmpty) {
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

    _cache[merged.itemId] = merged;
    final update = ConvItemUpdated(merged);
    if (!_updatesController.isClosed) {
      _updatesController.add(update);
    }
    getAttributes().sendEvent(ConversationIndexItemUpdatedEvent(merged));
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != conversationIndexNode) return;
    if (event.itemIds.isEmpty) return;
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
}
