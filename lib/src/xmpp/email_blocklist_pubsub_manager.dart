// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/jid_extensions.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String emailBlocklistPubSubNode = 'urn:axi:email-blocklist';
const String emailBlocklistNotifyFeature = 'urn:axi:email-blocklist+notify';

const int emailBlocklistSyncMaxItems = 500;

const String _blockTag = 'block';
const String _blockAddressAttr = 'address';
const String _blockUpdatedAtAttr = 'updated_at';
const String _blockSourceIdAttr = 'source_id';
const String _publishModelPublishers = 'publishers';
const String _sendLastOnSubscribe = 'on_subscribe';
const String _defaultMaxItems = '$emailBlocklistSyncMaxItems';
const String _blockSourceIdFallback = syncLegacySourceId;
const bool _notifyEnabled = true;
const bool _deliverNotificationsEnabled = true;
const bool _deliverPayloadsEnabled = true;
const bool _persistItemsEnabled = true;
const bool _presenceBasedDeliveryDisabled = false;
const Duration _ensureNodeBackoff = Duration(minutes: 5);

final class EmailBlocklistSyncPayload {
  const EmailBlocklistSyncPayload({
    required this.address,
    required this.updatedAt,
    required this.sourceId,
  });

  final String address;
  final DateTime updatedAt;
  final String sourceId;

  String get itemId => address;

  EmailBlocklistSyncPayload copyWith({
    String? address,
    DateTime? updatedAt,
    String? sourceId,
  }) {
    return EmailBlocklistSyncPayload(
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  static EmailBlocklistSyncPayload? fromXml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _blockTag) return null;
    if (node.attributes['xmlns']?.toString() != emailBlocklistPubSubNode) {
      return null;
    }

    final rawAddress = node.attributes[_blockAddressAttr]?.toString();
    final resolvedAddress =
        rawAddress == null || rawAddress.isEmpty ? itemId?.trim() : rawAddress;
    if (resolvedAddress == null || resolvedAddress.isEmpty) return null;
    final normalizedAddress =
        resolvedAddress.toBareJidOrNull(maxBytes: syncAddressMaxBytes);
    if (normalizedAddress == null) return null;

    final rawUpdatedAt =
        node.attributes[_blockUpdatedAtAttr]?.toString().trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) return null;
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null) return null;

    final rawSourceId = node.attributes[_blockSourceIdAttr]?.toString().trim();
    final resolvedSourceId = _normalizeSourceId(rawSourceId);

    return EmailBlocklistSyncPayload(
      address: normalizedAddress,
      updatedAt: parsedUpdatedAt.toUtc(),
      sourceId: resolvedSourceId,
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _blockTag,
      xmlns: emailBlocklistPubSubNode,
      attributes: {
        _blockAddressAttr: address,
        _blockUpdatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _blockSourceIdAttr: sourceId,
      },
    );
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return _blockSourceIdFallback;
    final clamped = clampUtf8Value(trimmed, maxBytes: syncSourceIdMaxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return _blockSourceIdFallback;
    }
    return clamped;
  }
}

sealed class EmailBlocklistSyncUpdate {
  const EmailBlocklistSyncUpdate();
}

final class EmailBlocklistSyncUpdated extends EmailBlocklistSyncUpdate {
  const EmailBlocklistSyncUpdated(this.payload);

  final EmailBlocklistSyncPayload payload;
}

final class EmailBlocklistSyncRetracted extends EmailBlocklistSyncUpdate {
  const EmailBlocklistSyncRetracted(this.address);

  final String address;
}

final class EmailBlocklistSyncUpdatedEvent extends mox.XmppEvent {
  EmailBlocklistSyncUpdatedEvent(this.payload);

  final EmailBlocklistSyncPayload payload;
}

final class EmailBlocklistSyncRetractedEvent extends mox.XmppEvent {
  EmailBlocklistSyncRetractedEvent(this.address);

  final String address;
}

final class EmailBlocklistPubSubManager extends mox.XmppManagerBase {
  EmailBlocklistPubSubManager({
    String? maxItems,
  })  : _maxItems = maxItems ?? _defaultMaxItems,
        super(managerId);

  static const String managerId = 'axi.email_blocklist';

  final String _maxItems;
  var _accessModel = mox.AccessModel.whitelist;

  final StreamController<EmailBlocklistSyncUpdate> _updatesController =
      StreamController<EmailBlocklistSyncUpdate>.broadcast();
  Stream<EmailBlocklistSyncUpdate> get updates => _updatesController.stream;

  final Map<String, EmailBlocklistSyncPayload> _cache = {};
  final SyncRateLimiter _rateLimiter =
      SyncRateLimiter(emailBlocklistSyncRateLimit);
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

  AxiPubSubNodeConfig _nodeConfig(mox.AccessModel accessModel) =>
      AxiPubSubNodeConfig(
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
        sendLastPublishedItem: _sendLastOnSubscribe,
      );

  mox.NodeConfig _createNodeConfig(mox.AccessModel accessModel) =>
      _nodeConfig(accessModel).toNodeConfig();

  mox.PubSubPublishOptions _publishOptions() => mox.PubSubPublishOptions(
        accessModel: _accessModel.value,
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

  void _setAccessModel(mox.AccessModel accessModel) {
    _accessModel = accessModel;
    _nodeReady = true;
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
      final primaryConfig = _nodeConfig(mox.AccessModel.whitelist);
      final configured = await pubsub.configureNode(
        host,
        emailBlocklistPubSubNode,
        primaryConfig,
      );
      if (!configured.isType<mox.PubSubError>()) {
        _setAccessModel(mox.AccessModel.whitelist);
        return;
      }

      final fallbackConfig = _nodeConfig(mox.AccessModel.authorize);
      final fallbackConfigured = await pubsub.configureNode(
        host,
        emailBlocklistPubSubNode,
        fallbackConfig,
      );
      if (!fallbackConfigured.isType<mox.PubSubError>()) {
        _setAccessModel(mox.AccessModel.authorize);
        return;
      }

      try {
        final created = await pubsub.createNodeWithConfig(
          host,
          _createNodeConfig(mox.AccessModel.whitelist),
          nodeId: emailBlocklistPubSubNode,
        );
        if (created != null) {
          final applied = await pubsub.configureNode(
            host,
            emailBlocklistPubSubNode,
            primaryConfig,
          );
          if (!applied.isType<mox.PubSubError>()) {
            _setAccessModel(mox.AccessModel.whitelist);
            return;
          }
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        final created = await pubsub.createNodeWithConfig(
          host,
          _createNodeConfig(mox.AccessModel.authorize),
          nodeId: emailBlocklistPubSubNode,
        );
        if (created != null) {
          final applied = await pubsub.configureNode(
            host,
            emailBlocklistPubSubNode,
            fallbackConfig,
          );
          if (!applied.isType<mox.PubSubError>()) {
            _setAccessModel(mox.AccessModel.authorize);
            return;
          }
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        final created = await pubsub.createNode(
          host,
          nodeId: emailBlocklistPubSubNode,
        );
        if (created == null) return;
        final appliedPrimary = await pubsub.configureNode(
          host,
          emailBlocklistPubSubNode,
          primaryConfig,
        );
        if (!appliedPrimary.isType<mox.PubSubError>()) {
          _setAccessModel(mox.AccessModel.whitelist);
          return;
        }
        final appliedFallback = await pubsub.configureNode(
          host,
          emailBlocklistPubSubNode,
          fallbackConfig,
        );
        if (!appliedFallback.isType<mox.PubSubError>()) {
          _setAccessModel(mox.AccessModel.authorize);
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
    final result = await pubsub.subscribe(host, emailBlocklistPubSubNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.MalformedResponseError) return;
      return;
    }
  }

  Future<List<EmailBlocklistSyncPayload>> fetchAll() async {
    final snapshot = await fetchAllWithStatus();
    if (!snapshot.isSuccess) return const <EmailBlocklistSyncPayload>[];
    return snapshot.items;
  }

  Future<PubSubFetchResult<EmailBlocklistSyncPayload>>
      fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const PubSubFetchResult(
        items: <EmailBlocklistSyncPayload>[],
        isSuccess: false,
      );
    }

    final limit = _resolveFetchLimit();
    if (limit <= 0) {
      return const PubSubFetchResult(
        items: <EmailBlocklistSyncPayload>[],
        isSuccess: true,
      );
    }

    final result = await pubsub.getItems(
      host,
      emailBlocklistPubSubNode,
      maxItems: limit,
    );
    if (result.isType<mox.PubSubError>()) {
      return const PubSubFetchResult(
        items: <EmailBlocklistSyncPayload>[],
        isSuccess: false,
      );
    }

    final items = result.get<List<mox.PubSubItem>>();
    if (items.isEmpty) {
      return const PubSubFetchResult(
        items: <EmailBlocklistSyncPayload>[],
        isSuccess: true,
      );
    }

    var hadParseFailure = false;
    final parsed = <EmailBlocklistSyncPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) {
        hadParseFailure = true;
        continue;
      }
      final parsedPayload = EmailBlocklistSyncPayload.fromXml(
        payload,
        itemId: item.id,
      );
      if (parsedPayload == null) {
        hadParseFailure = true;
        continue;
      }
      parsed.add(parsedPayload);
    }
    final isComplete = !hadParseFailure &&
        _isSnapshotComplete(
          itemsCount: items.length,
          maxItems: limit,
        );

    return PubSubFetchResult(
      items: List<EmailBlocklistSyncPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: isComplete,
    );
  }

  Future<bool> publishBlock(EmailBlocklistSyncPayload payload) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return false;
    final result = await pubsub.publish(
      host,
      emailBlocklistPubSubNode,
      payload.toXml(),
      id: payload.itemId,
      options: _publishOptions(),
    );
    if (result.isType<mox.PubSubError>()) return false;
    _cache[payload.itemId] = payload;
    _emitUpdate(payload);
    return true;
  }

  Future<bool> retractBlock(String address) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return false;
    final normalized = address.trim();
    if (normalized.isEmpty) return false;
    final result = await pubsub.retract(
      host,
      emailBlocklistPubSubNode,
      normalized,
      notify: _notifyEnabled,
    );
    if (result.isType<mox.PubSubError>()) return false;
    _cache.remove(normalized);
    _emitRetraction(normalized);
    return true;
  }

  void _emitUpdate(EmailBlocklistSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(EmailBlocklistSyncUpdated(payload));
    }
    getAttributes().sendEvent(EmailBlocklistSyncUpdatedEvent(payload));
  }

  void _emitRetraction(String address) {
    if (!_updatesController.isClosed) {
      _updatesController.add(EmailBlocklistSyncRetracted(address));
    }
    getAttributes().sendEvent(EmailBlocklistSyncRetractedEvent(address));
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

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != emailBlocklistPubSubNode) return;
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
    if (!_shouldProcessSyncEvent()) return;

    EmailBlocklistSyncPayload? parsed;
    if (event.item.payload case final payload?) {
      parsed = EmailBlocklistSyncPayload.fromXml(
        payload,
        itemId: event.item.id,
      );
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null && itemId.isNotEmpty) {
        final itemResult =
            await pubsub.getItem(host, emailBlocklistPubSubNode, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          final item = itemResult.get<mox.PubSubItem>();
          final payload = item.payload;
          if (payload != null) {
            parsed = EmailBlocklistSyncPayload.fromXml(
              payload,
              itemId: itemId,
            );
          }
        }
      }
    }

    if (parsed == null) return;
    final maxItems = _resolveFetchLimit();
    if (_cache.length >= maxItems && !_cache.containsKey(parsed.itemId)) {
      await _refreshFromServer();
      return;
    }
    _cache[parsed.itemId] = parsed;
    _emitUpdate(parsed);
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != emailBlocklistPubSubNode) return;
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
    if (event.itemIds.isEmpty) return;
    if (!_shouldProcessSyncEvent()) return;
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) continue;
      _cache.remove(normalized);
      _emitRetraction(normalized);
    }
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != emailBlocklistPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (event.from.toBare().toString() != host.toString()) return;
    await _refreshFromServer();
  }

  Future<void> _handleSubscriptionChanged(
    PubSubSubscriptionChangedEvent event,
  ) async {
    if (event.node != emailBlocklistPubSubNode) return;
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
    if (event.node != emailBlocklistPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    unawaited(_bootstrap());
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != emailBlocklistPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeReady = false;
    _lastEnsureAttempt = null;
    unawaited(_bootstrap());
  }

  Future<void> _refreshFromServer() async {
    final snapshot = await fetchAllWithStatus();
    if (!snapshot.isSuccess) return;
    final items = snapshot.items;
    final freshIds = items.map((item) => item.itemId).toSet();
    final previousCache = Map<String, EmailBlocklistSyncPayload>.from(_cache);
    if (snapshot.isComplete) {
      _cache
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.itemId, item)));
    } else {
      for (final item in items) {
        _cache[item.itemId] = item;
      }
    }
    for (final item in items) {
      _emitUpdate(item);
    }
    if (!snapshot.isComplete) {
      return;
    }
    final removedIds =
        previousCache.keys.where((id) => !freshIds.contains(id)).toList();
    for (final id in removedIds) {
      _emitRetraction(id);
    }
  }

  void _clearCache() {
    if (_cache.isEmpty) return;
    final items = _cache.keys.toList(growable: false);
    _cache.clear();
    for (final address in items) {
      _emitRetraction(address);
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
