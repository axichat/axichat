// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub_manager.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String messageCollectionsPubSubNode = 'urn:axi:message-collections';
const String messageCollectionsNotifyFeature =
    'urn:axi:message-collections+notify';

const int messageCollectionSyncMaxItems = 5000;

const String _entryTag = 'entry';
const String _collectionIdAttr = 'collection_id';
const String _chatJidAttr = 'chat_jid';
const String _messageReferenceIdAttr = 'message_reference_id';
const String _messageStanzaIdAttr = 'message_stanza_id';
const String _messageOriginIdAttr = 'message_origin_id';
const String _messageMucStanzaIdAttr = 'message_muc_stanza_id';
const String _deltaAccountIdAttr = 'delta_account_id';
const String _deltaMsgIdAttr = 'delta_msg_id';
const String _updatedAtAttr = 'updated_at';
const String _activeAttr = 'active';
const String _sourceIdAttr = 'source_id';
const String _publishModelPublishers = 'publishers';
const String _defaultMaxItems = '$messageCollectionSyncMaxItems';
const bool _notifyEnabled = true;
const bool _deliverNotificationsEnabled = true;
const bool _deliverPayloadsEnabled = true;
const bool _persistItemsEnabled = true;
const bool _presenceBasedDeliveryDisabled = false;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const int _collectionIdMaxBytes = 128;
const int _messageReferenceIdMaxBytes = 1024;

final class MessageCollectionSyncPayload {
  const MessageCollectionSyncPayload({
    required this.collectionId,
    required this.chatJid,
    required this.messageReferenceId,
    required this.updatedAt,
    required this.active,
    required this.sourceId,
    this.messageStanzaId,
    this.messageOriginId,
    this.messageMucStanzaId,
    this.deltaAccountId,
    this.deltaMsgId,
  });

  final String collectionId;
  final String chatJid;
  final String messageReferenceId;
  final String? messageStanzaId;
  final String? messageOriginId;
  final String? messageMucStanzaId;
  final int? deltaAccountId;
  final int? deltaMsgId;
  final DateTime updatedAt;
  final bool active;
  final String sourceId;

  String get itemId => itemIdFor(
    collectionId: collectionId,
    chatJid: chatJid,
    messageReferenceId: messageReferenceId,
  );

  Set<String> get aliases => <String>{
    messageReferenceId,
    ?messageStanzaId,
    ?messageOriginId,
    ?messageMucStanzaId,
  };

  static String itemIdFor({
    required String collectionId,
    required String chatJid,
    required String messageReferenceId,
  }) {
    final digest = crypto.sha256.convert(
      utf8.encode('$collectionId\n$chatJid\n$messageReferenceId'),
    );
    return digest.toString();
  }

  static MessageCollectionSyncPayload? fromXml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _entryTag) return null;
    if (node.attributes['xmlns']?.toString() != messageCollectionsPubSubNode) {
      return null;
    }
    final collectionId = _normalizeCollectionId(
      node.attributes[_collectionIdAttr]?.toString(),
    );
    final chatJid = _normalizeChatJid(
      node.attributes[_chatJidAttr]?.toString(),
    );
    final messageReferenceId = _normalizeReferenceValue(
      node.attributes[_messageReferenceIdAttr]?.toString(),
    );
    final rawUpdatedAt = node.attributes[_updatedAtAttr]?.toString().trim();
    final parsedUpdatedAt = rawUpdatedAt == null || rawUpdatedAt.isEmpty
        ? null
        : DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (collectionId == null ||
        chatJid == null ||
        messageReferenceId == null ||
        parsedUpdatedAt == null) {
      return null;
    }
    final active = _parseBoolAttr(node.attributes[_activeAttr]) ?? true;
    final sourceId = _normalizeSourceId(
      node.attributes[_sourceIdAttr]?.toString(),
    );
    final payload = MessageCollectionSyncPayload(
      collectionId: collectionId,
      chatJid: chatJid,
      messageReferenceId: messageReferenceId,
      messageStanzaId: _normalizeReferenceValue(
        node.attributes[_messageStanzaIdAttr]?.toString(),
      ),
      messageOriginId: _normalizeReferenceValue(
        node.attributes[_messageOriginIdAttr]?.toString(),
      ),
      messageMucStanzaId: _normalizeReferenceValue(
        node.attributes[_messageMucStanzaIdAttr]?.toString(),
      ),
      deltaAccountId: _parsePositiveIntAttr(
        node.attributes[_deltaAccountIdAttr],
      ),
      deltaMsgId: _parsePositiveIntAttr(node.attributes[_deltaMsgIdAttr]),
      updatedAt: parsedUpdatedAt,
      active: active,
      sourceId: sourceId,
    );
    if (itemId != null &&
        itemId.trim().isNotEmpty &&
        payload.itemId != itemId) {
      return null;
    }
    return payload;
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _entryTag,
      xmlns: messageCollectionsPubSubNode,
      attributes: {
        _collectionIdAttr: collectionId,
        _chatJidAttr: chatJid,
        _messageReferenceIdAttr: messageReferenceId,
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _activeAttr: active ? '1' : '0',
        _sourceIdAttr: sourceId,
        _messageStanzaIdAttr: ?messageStanzaId,
        _messageOriginIdAttr: ?messageOriginId,
        _messageMucStanzaIdAttr: ?messageMucStanzaId,
        if (deltaAccountId != null)
          _deltaAccountIdAttr: deltaAccountId!.toString(),
        if (deltaMsgId != null) _deltaMsgIdAttr: deltaMsgId!.toString(),
      },
    );
  }

  static String? _normalizeCollectionId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final clamped = clampUtf8Value(normalized, maxBytes: _collectionIdMaxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return null;
    }
    return clamped;
  }

  static String? _normalizeChatJid(String? value) =>
      value?.toBareJidOrNull(maxBytes: syncAddressMaxBytes);

  static String? _normalizeReferenceValue(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final clamped = clampUtf8Value(
      normalized,
      maxBytes: _messageReferenceIdMaxBytes,
    );
    if (clamped == null || clamped.trim().isEmpty) {
      return null;
    }
    return clamped;
  }

  static int? _parsePositiveIntAttr(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    if (parsed == null || parsed < 0) {
      return null;
    }
    return parsed;
  }

  static bool? _parseBoolAttr(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    return switch (normalized) {
      '1' || 'true' => true,
      '0' || 'false' => false,
      _ => null,
    };
  }

  static String _normalizeSourceId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return syncLegacySourceId;
    }
    final clamped = clampUtf8Value(normalized, maxBytes: syncSourceIdMaxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return syncLegacySourceId;
    }
    return clamped;
  }
}

final class MessageCollectionSyncUpdatedEvent extends mox.XmppEvent {
  MessageCollectionSyncUpdatedEvent(this.payload);

  final MessageCollectionSyncPayload payload;
}

final class MessageCollectionsPubSubManager extends mox.XmppManagerBase {
  MessageCollectionsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.message_collections';

  final String _maxItems;
  var _accessModel = mox.AccessModel.whitelist;
  final Map<String, MessageCollectionSyncPayload> _cache = {};
  final SyncRateLimiter _rateLimiter = SyncRateLimiter(
    messageCollectionSyncRateLimit,
  );
  DateTime? _lastEnsureAttempt;
  bool _ensureNodeInFlight = false;
  bool _ensureNodePending = false;
  bool _nodeReady = false;
  bool _subscriptionReady = false;
  Completer<void>? _ensureNodeCompleter;
  Completer<void>? _subscribeCompleter;

  Future<void> close() async {}

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> onXmppEvent(mox.XmppEvent event) async {
    if (event is mox.PubSubNotificationEvent) {
      fireAndForget(() => _handleNotification(event));
      return;
    }
    if (event is mox.PubSubItemsRetractedEvent) {
      fireAndForget(() => _handleRetractions(event));
      return;
    }
    if (event is PubSubItemsRefreshedEvent) {
      fireAndForget(() => _handleRefreshEvent(event));
      return;
    }
    if (event is PubSubSubscriptionChangedEvent) {
      fireAndForget(() => _handleSubscriptionChanged(event));
      return;
    }
    if (event is mox.PubSubNodeDeletedEvent) {
      fireAndForget(() => _handleNodeDeleted(event));
      return;
    }
    if (event is mox.PubSubNodePurgedEvent) {
      fireAndForget(() => _handleNodePurged(event));
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

  AxiPubSubNodeConfig _nodeConfig(
    mox.AccessModel accessModel, {
    String? sendLastPublishedItem,
  }) => AxiPubSubNodeConfig(
    accessModel: accessModel,
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
    sendLastPublishedItem: sendLastPublishedItem,
  );

  Future<mox.PubSubError?> _configureNodeWithFallback(
    PubSubManager pubsub,
    mox.JID host,
    String node,
    AxiPubSubNodeConfig config,
  ) async {
    final configured = await pubsub.configureNode(host, node, config);
    if (!configured.isType<mox.PubSubError>()) {
      return null;
    }
    final error = configured.get<mox.PubSubError>();
    if (error.indicatesMissingNode) {
      return error;
    }
    final sendLastValue = config.sendLastPublishedItem?.trim();
    if (sendLastValue == null || sendLastValue.isEmpty) {
      return error;
    }
    final strippedResult = await pubsub.configureNode(
      host,
      node,
      config.withoutSendLastPublishedItem(),
    );
    if (!strippedResult.isType<mox.PubSubError>()) {
      return null;
    }
    return strippedResult.get<mox.PubSubError>();
  }

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
    accessModel: _accessModel.value,
    maxItems: _maxItems,
    persistItems: _persistItemsEnabled,
    publishModel: _publishModelPublishers,
  );

  mox.JID? _selfPepHost() {
    try {
      return getAttributes().getFullJID().toBare();
    } on Exception {
      return null;
    }
  }

  PubSubManager? _pubSub() =>
      getAttributes().getManagerById<PubSubManager>(mox.pubsubManager);

  Future<String?> _resolveSendLastPublishedItem(
    PubSubManager pubsub,
    mox.JID host,
  ) => pubsub.resolveSendLastPublishedItemForNode(
    host: host,
    node: messageCollectionsPubSubNode,
  );

  int _resolveFetchLimit() {
    final parsed = int.tryParse(_maxItems.trim());
    if (parsed != null) {
      return parsed;
    }
    return int.parse(_defaultMaxItems);
  }

  bool _isSnapshotComplete({required int itemsCount, required int maxItems}) =>
      itemsCount < maxItems;

  void _setAccessModel(mox.AccessModel accessModel) {
    _accessModel = accessModel;
    _nodeReady = true;
  }

  bool _shouldAttemptEnsureNode() {
    if (_ensureNodeInFlight || _nodeReady) {
      return false;
    }
    final lastAttempt = _lastEnsureAttempt;
    if (lastAttempt == null) {
      return true;
    }
    return DateTime.timestamp().difference(lastAttempt) >= _ensureNodeBackoff;
  }

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null || _nodeReady) {
      return;
    }
    final activeCompleter = _ensureNodeCompleter;
    if (activeCompleter != null) {
      await activeCompleter.future;
      return;
    }
    if (!_shouldAttemptEnsureNode()) {
      return;
    }
    final completer = Completer<void>();
    _ensureNodeCompleter = completer;
    _ensureNodeInFlight = true;
    _lastEnsureAttempt = DateTime.timestamp();
    try {
      final sendLastPublishedItem = await _resolveSendLastPublishedItem(
        pubsub,
        host,
      );
      final primaryConfig = _nodeConfig(
        mox.AccessModel.whitelist,
        sendLastPublishedItem: sendLastPublishedItem,
      );
      final fallbackConfig = _nodeConfig(
        mox.AccessModel.authorize,
        sendLastPublishedItem: sendLastPublishedItem,
      );
      final primaryError = await _configureNodeWithFallback(
        pubsub,
        host,
        messageCollectionsPubSubNode,
        primaryConfig,
      );
      if (primaryError == null) {
        _setAccessModel(mox.AccessModel.whitelist);
        return;
      }
      final fallbackError = await _configureNodeWithFallback(
        pubsub,
        host,
        messageCollectionsPubSubNode,
        fallbackConfig,
      );
      if (fallbackError == null) {
        _setAccessModel(mox.AccessModel.authorize);
        return;
      }
      if (!primaryError.indicatesMissingNode &&
          !fallbackError.indicatesMissingNode) {
        return;
      }
      try {
        await pubsub.createNodeWithConfig(
          host,
          primaryConfig.toNodeConfig(),
          nodeId: messageCollectionsPubSubNode,
        );
      } on Exception {
        try {
          await pubsub.createNodeWithConfig(
            host,
            fallbackConfig.toNodeConfig(),
            nodeId: messageCollectionsPubSubNode,
          );
        } on Exception {
          try {
            await pubsub.createNode(host, nodeId: messageCollectionsPubSubNode);
          } on Exception {
            return;
          }
        }
      }
      final appliedPrimary = await _configureNodeWithFallback(
        pubsub,
        host,
        messageCollectionsPubSubNode,
        primaryConfig,
      );
      if (appliedPrimary == null) {
        _setAccessModel(mox.AccessModel.whitelist);
        return;
      }
      final appliedFallback = await _configureNodeWithFallback(
        pubsub,
        host,
        messageCollectionsPubSubNode,
        fallbackConfig,
      );
      if (appliedFallback == null) {
        _setAccessModel(mox.AccessModel.authorize);
      }
    } finally {
      _ensureNodeInFlight = false;
      _ensureNodeCompleter = null;
      completer.complete();
      final shouldRetry = _ensureNodePending && !_nodeReady;
      _ensureNodePending = false;
      if (shouldRetry) {
        fireAndForget(_bootstrap);
      }
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null || _subscriptionReady) {
      return;
    }
    final activeCompleter = _subscribeCompleter;
    if (activeCompleter != null) {
      await activeCompleter.future;
      return;
    }
    final completer = Completer<void>();
    _subscribeCompleter = completer;
    try {
      final result = await pubsub.subscribe(host, messageCollectionsPubSubNode);
      if (result.isType<mox.PubSubError>()) {
        return;
      }
      _subscriptionReady = true;
    } finally {
      _subscribeCompleter = null;
      completer.complete();
    }
  }

  Future<PubSubFetchResult<MessageCollectionSyncPayload>>
  fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const PubSubFetchResult(
        items: <MessageCollectionSyncPayload>[],
        isSuccess: false,
      );
    }
    final limit = _resolveFetchLimit();
    if (limit <= 0) {
      return const PubSubFetchResult(
        items: <MessageCollectionSyncPayload>[],
        isSuccess: true,
      );
    }
    final result = await pubsub.getItems(
      host,
      messageCollectionsPubSubNode,
      maxItems: limit,
    );
    if (result.isType<mox.PubSubError>()) {
      return const PubSubFetchResult(
        items: <MessageCollectionSyncPayload>[],
        isSuccess: false,
      );
    }
    final items = result.get<List<mox.PubSubItem>>();
    if (items.isEmpty) {
      return const PubSubFetchResult(
        items: <MessageCollectionSyncPayload>[],
        isSuccess: true,
      );
    }
    var hadParseFailure = false;
    final parsed = <MessageCollectionSyncPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) {
        hadParseFailure = true;
        continue;
      }
      final parsedPayload = MessageCollectionSyncPayload.fromXml(
        payload,
        itemId: item.id,
      );
      if (parsedPayload == null) {
        hadParseFailure = true;
        continue;
      }
      parsed.add(parsedPayload);
    }
    return PubSubFetchResult(
      items: List<MessageCollectionSyncPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete:
          !hadParseFailure &&
          _isSnapshotComplete(itemsCount: items.length, maxItems: limit),
    );
  }

  Future<bool> publishEntry(MessageCollectionSyncPayload payload) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return false;
    }
    final result = await pubsub.publish(
      host,
      messageCollectionsPubSubNode,
      payload.toXml(),
      id: payload.itemId,
      options: _publishOptions(),
    );
    if (result.isType<mox.PubSubError>()) {
      return false;
    }
    _cache[payload.itemId] = payload;
    getAttributes().sendEvent(MessageCollectionSyncUpdatedEvent(payload));
    return true;
  }

  bool _shouldProcessSyncEvent() {
    if (_rateLimiter.allowEvent()) {
      return true;
    }
    if (_rateLimiter.shouldRefreshNow()) {
      fireAndForget(_refreshFromServer);
    }
    return false;
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) {
      return;
    }
    if (!_shouldProcessSyncEvent()) {
      return;
    }
    MessageCollectionSyncPayload? parsed;
    if (event.item.payload case final payload?) {
      parsed = MessageCollectionSyncPayload.fromXml(
        payload,
        itemId: event.item.id,
      );
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (pubsub == null || itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      final itemResult = await pubsub.getItem(
        host,
        messageCollectionsPubSubNode,
        itemId,
      );
      if (!itemResult.isType<mox.PubSubError>()) {
        final item = itemResult.get<mox.PubSubItem>();
        final payload = item.payload;
        if (payload != null) {
          parsed = MessageCollectionSyncPayload.fromXml(
            payload,
            itemId: itemId,
          );
        }
      }
    }
    if (parsed == null) {
      return;
    }
    final maxItems = _resolveFetchLimit();
    if (_cache.length >= maxItems && !_cache.containsKey(parsed.itemId)) {
      await _refreshFromServer();
      return;
    }
    _cache[parsed.itemId] = parsed;
    getAttributes().sendEvent(MessageCollectionSyncUpdatedEvent(parsed));
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) {
      return;
    }
    if (!_shouldProcessSyncEvent()) {
      return;
    }
    await _refreshFromServer();
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || event.from.toBare().toString() != host.toString()) {
      return;
    }
    await _refreshFromServer();
  }

  Future<void> _handleSubscriptionChanged(
    PubSubSubscriptionChangedEvent event,
  ) async {
    if (event.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null) {
      return;
    }
    final subscriber = event.subscriberJid?.trim();
    if (subscriber == null || subscriber.isEmpty) {
      return;
    }
    late final mox.JID subscriberJid;
    try {
      subscriberJid = mox.JID.fromString(subscriber).toBare();
    } on Exception {
      return;
    }
    if (subscriberJid.toString() != host.toString()) {
      return;
    }
    if (event.state == mox.SubscriptionState.subscribed) {
      _subscriptionReady = true;
      return;
    }
    _subscriptionReady = false;
    await subscribe();
  }

  Future<void> _handleNodeDeleted(mox.PubSubNodeDeletedEvent event) async {
    if (event.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !_isFromHost(event.from, host)) {
      return;
    }
    _clearCache();
    _nodeReady = false;
    _subscriptionReady = false;
    _lastEnsureAttempt = null;
    _ensureNodePending = true;
    if (!_ensureNodeInFlight) {
      fireAndForget(_bootstrap);
    }
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != messageCollectionsPubSubNode) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !_isFromHost(event.from, host)) {
      return;
    }
    _clearCache();
    await _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    final snapshot = await fetchAllWithStatus();
    if (!snapshot.isSuccess) {
      return;
    }
    _cache
      ..clear()
      ..addEntries(snapshot.items.map((item) => MapEntry(item.itemId, item)));
    for (final payload in snapshot.items) {
      getAttributes().sendEvent(MessageCollectionSyncUpdatedEvent(payload));
    }
  }

  bool _isFromHost(String from, mox.JID host) {
    final normalized = from.trim();
    if (normalized.isEmpty) {
      return false;
    }
    try {
      return mox.JID.fromString(normalized).toBare().toString() ==
          host.toString();
    } on Exception {
      return normalized == host.toString();
    }
  }

  void _clearCache() {
    _cache.clear();
  }
}
