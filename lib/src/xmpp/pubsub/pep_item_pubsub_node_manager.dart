// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_node_session.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

abstract class PepItemPubSubNodeManager<TPayload> extends mox.XmppManagerBase
    implements PubSubHubEventDelegate {
  PepItemPubSubNodeManager(super.managerId);

  static const String publishModelPublishers = 'publishers';
  static const bool notifyEnabled = true;
  static const bool deliverNotificationsEnabled = true;
  static const bool deliverPayloadsEnabled = true;
  static const bool persistItemsEnabled = true;
  static const bool presenceBasedDeliveryDisabled = false;

  final Map<String, TPayload> cache = <String, TPayload>{};
  final PubSubNodeSession nodeSession = PubSubNodeSession();
  mox.AccessModel accessModel = mox.AccessModel.whitelist;

  String get nodeId;
  String get maxItemsValue;
  String get defaultMaxItemsValue;
  Duration get ensureNodeBackoff;
  String get bootstrapOperationName;
  String get refreshOperationName;
  XmppOperationKind? get operationKind;
  SyncRateLimiter get rateLimiter;

  List<mox.AccessModel> get candidateAccessModels => const <mox.AccessModel>[
    mox.AccessModel.whitelist,
    mox.AccessModel.authorize,
  ];

  bool get publishAutoCreate => false;
  bool get treatMissingNodeAsEmptySnapshot => false;
  bool get rebuildNodeOnPurge => true;
  bool get refreshOnRetractionEvent => false;
  bool get emitRetractionsOnClear => true;
  bool get emitRetractionsFromCompleteSnapshot => true;

  TPayload? parsePayload(mox.XMLNode payload, {String? itemId});
  String itemIdOf(TPayload payload);
  mox.XMLNode payloadToXml(TPayload payload);
  void emitUpdatePayload(TPayload payload);
  void emitRetractionId(String itemId);

  TPayload? mergeIncomingNotification(TPayload incoming, {TPayload? cached}) =>
      incoming;

  TPayload mergeRefreshedItem(TPayload incoming, {TPayload? cached}) =>
      incoming;

  XmppOperationEvent? get _ensureStartEvent => operationKind == null
      ? null
      : XmppOperationEvent(
          kind: operationKind!,
          stage: XmppOperationStage.start,
        );

  XmppOperationEvent? get _ensureSuccessEvent => operationKind == null
      ? null
      : XmppOperationEvent(kind: operationKind!, stage: XmppOperationStage.end);

  XmppOperationEvent? get _ensureFailureEvent => operationKind == null
      ? null
      : XmppOperationEvent(
          kind: operationKind!,
          stage: XmppOperationStage.end,
          isSuccess: false,
        );

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<void> close() async {}

  @override
  bool handlesPubSubEvent(mox.XmppEvent event) {
    final host = _selfPepHost();
    if (host == null) {
      return false;
    }
    return switch (event) {
      mox.PubSubNotificationEvent(:final item) =>
        item.node == nodeId && event.isFromPepOwner(host),
      mox.PubSubItemsRetractedEvent(:final node) =>
        node == nodeId && event.isFromPepOwner(host),
      PubSubItemsRefreshedEvent(:final node, :final from) =>
        node == nodeId && from.toBare().toString() == host.toString(),
      PubSubSubscriptionChangedEvent(:final node, :final subscriberJid) =>
        node == nodeId &&
            _matchesSubscriberHost(subscriberJid: subscriberJid, host: host),
      mox.PubSubNodeDeletedEvent(:final node, :final from) =>
        node == nodeId && _isFromHost(from, host),
      mox.PubSubNodePurgedEvent(:final node, :final from) =>
        node == nodeId && _isFromHost(from, host),
      _ => false,
    };
  }

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

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null || nodeSession.nodeReady) {
      return;
    }
    final activeEnsure = nodeSession.activeEnsure;
    if (activeEnsure != null) {
      await activeEnsure;
      return;
    }
    if (!nodeSession.shouldAttemptEnsure(ensureNodeBackoff)) {
      return;
    }

    final completer = nodeSession.beginEnsure();
    var success = false;
    final ensureStartEvent = _ensureStartEvent;
    if (ensureStartEvent != null) {
      getAttributes().sendEvent(ensureStartEvent);
    }
    try {
      final sendLastPublishedItem = await _resolveSendLastPublishedItem(
        pubsub,
        host,
      );
      final configs = <mox.AccessModel, AxiPubSubNodeConfig>{
        for (final candidate in candidateAccessModels)
          candidate: _nodeConfig(
            candidate,
            sendLastPublishedItem: sendLastPublishedItem,
          ),
      };
      final errors = <mox.AccessModel, mox.PubSubError>{};
      for (final candidate in candidateAccessModels) {
        final error = await _configureNodeWithFallback(
          pubsub,
          host,
          nodeId,
          configs[candidate]!,
        );
        if (error == null) {
          _setAccessModel(candidate);
          success = true;
          return;
        }
        errors[candidate] = error;
      }
      final shouldCreateNode = errors.values.any(
        (error) => error.indicatesMissingNode,
      );
      if (!shouldCreateNode) {
        return;
      }

      for (final candidate in candidateAccessModels) {
        try {
          await pubsub.createNodeWithConfig(
            host,
            configs[candidate]!.toNodeConfig(),
            nodeId: nodeId,
          );
          final appliedError = await _configureNodeWithFallback(
            pubsub,
            host,
            nodeId,
            configs[candidate]!,
          );
          if (appliedError == null) {
            _setAccessModel(candidate);
            success = true;
            return;
          }
        } on Exception {
          // ignore and retry below
        }
      }

      try {
        await pubsub.createNode(host, nodeId: nodeId);
      } on Exception {
        return;
      }
      for (final candidate in candidateAccessModels) {
        final appliedError = await _configureNodeWithFallback(
          pubsub,
          host,
          nodeId,
          configs[candidate]!,
        );
        if (appliedError == null) {
          _setAccessModel(candidate);
          success = true;
          return;
        }
      }
    } finally {
      nodeSession.completeEnsure(completer);
      final ensureEvent = success ? _ensureSuccessEvent : _ensureFailureEvent;
      if (ensureEvent != null) {
        getAttributes().sendEvent(ensureEvent);
      }
      if (nodeSession.takePendingRetry()) {
        fireAndForget(_bootstrap, operationName: bootstrapOperationName);
      }
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null || nodeSession.subscriptionReady) {
      return;
    }
    final activeSubscribe = nodeSession.activeSubscribe;
    if (activeSubscribe != null) {
      await activeSubscribe;
      return;
    }
    final completer = nodeSession.beginSubscribe();
    try {
      final result = await pubsub.subscribe(host, nodeId);
      if (result.isType<mox.PubSubError>()) {
        final error = result.get<mox.PubSubError>();
        if (error is mox.MalformedResponseError) {
          return;
        }
        return;
      }
      nodeSession.markSubscriptionReady();
    } finally {
      nodeSession.finishSubscribe(completer);
    }
  }

  Future<({List<TPayload> items, bool isSuccess, bool isComplete})>
  fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return (items: <TPayload>[], isSuccess: false, isComplete: false);
    }

    final fetchLimit = _resolveFetchLimit();
    if (fetchLimit <= 0) {
      return (items: <TPayload>[], isSuccess: true, isComplete: true);
    }

    final result = await pubsub.getItems(host, nodeId, maxItems: fetchLimit);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing && treatMissingNodeAsEmptySnapshot) {
        cache.clear();
        return (items: <TPayload>[], isSuccess: true, isComplete: true);
      }
      return (items: <TPayload>[], isSuccess: false, isComplete: false);
    }

    final items = result.get<List<mox.PubSubItem>>();
    var hadParseFailure = false;
    final parsed = <TPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) {
        hadParseFailure = true;
        continue;
      }
      final parsedPayload = parsePayload(payload, itemId: item.id);
      if (parsedPayload == null) {
        hadParseFailure = true;
        continue;
      }
      parsed.add(parsedPayload);
    }

    return (
      items: List<TPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete:
          !hadParseFailure &&
          _isSnapshotComplete(itemsCount: items.length, maxItems: fetchLimit),
    );
  }

  Future<List<TPayload>> fetchAll() async {
    final snapshot = await fetchAllWithStatus();
    return snapshot.items;
  }

  Future<bool> publishItem(TPayload payload) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return false;
    }
    final itemId = itemIdOf(payload);
    final result = await pubsub.publish(
      host,
      nodeId,
      payloadToXml(payload),
      id: itemId,
      options: _publishOptions(),
      autoCreate: publishAutoCreate,
      createNodeConfig: publishAutoCreate
          ? _nodeConfig(accessModel).toNodeConfig()
          : null,
    );
    if (result.isType<mox.PubSubError>()) {
      return false;
    }
    cache[itemId] = payload;
    emitUpdatePayload(payload);
    return true;
  }

  Future<bool> retractItem(String itemId) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return false;
    }
    final normalized = itemId.trim();
    if (normalized.isEmpty) {
      return false;
    }
    final result = await pubsub.retract(
      host,
      nodeId,
      normalized,
      notify: notifyEnabled,
    );
    if (result.isType<mox.PubSubError>()) {
      return false;
    }
    cache.remove(normalized);
    emitRetractionId(normalized);
    return true;
  }

  Future<void> refreshFromServer() => _refreshFromServer();

  AxiPubSubNodeConfig _nodeConfig(
    mox.AccessModel accessModel, {
    String? sendLastPublishedItem,
  }) => AxiPubSubNodeConfig(
    accessModel: accessModel,
    publishModel: publishModelPublishers,
    deliverNotifications: deliverNotificationsEnabled,
    deliverPayloads: deliverPayloadsEnabled,
    maxItems: maxItemsValue,
    notifyRetract: notifyEnabled,
    notifyDelete: notifyEnabled,
    notifyConfig: notifyEnabled,
    notifySub: notifyEnabled,
    presenceBasedDelivery: presenceBasedDeliveryDisabled,
    persistItems: persistItemsEnabled,
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
    if (error.indicatesMissingNode || !config.hasSendLastPublishedItem) {
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
    accessModel: accessModel.value,
    maxItems: maxItemsValue,
    persistItems: persistItemsEnabled,
    publishModel: publishModelPublishers,
  );

  Future<void> _bootstrap() async {
    try {
      await ensureNode();
      await subscribe();
    } on Exception {
      return;
    }
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

  Future<String?> _resolveSendLastPublishedItem(
    PubSubManager pubsub,
    mox.JID host,
  ) => pubsub.resolveSendLastPublishedItemForNode(host: host, node: nodeId);

  int? _parseMaxItems(String raw) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return int.tryParse(normalized);
  }

  int _resolveFetchLimit() =>
      _parseMaxItems(maxItemsValue) ?? int.parse(defaultMaxItemsValue);

  bool _isSnapshotComplete({required int itemsCount, required int maxItems}) =>
      itemsCount < maxItems;

  void _setAccessModel(mox.AccessModel accessModel) {
    this.accessModel = accessModel;
    nodeSession.markNodeReady();
  }

  bool _shouldProcessSyncEvent() {
    if (rateLimiter.allowEvent()) {
      return true;
    }
    if (rateLimiter.shouldRefreshNow()) {
      fireAndForget(_refreshFromServer, operationName: refreshOperationName);
    }
    return false;
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != nodeId) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) {
      return;
    }
    if (!_shouldProcessSyncEvent()) {
      return;
    }

    TPayload? parsed;
    if (event.item.payload case final payload?) {
      parsed = parsePayload(payload, itemId: event.item.id);
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null) {
        final itemResult = await pubsub.getItem(host, nodeId, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          final item = itemResult.get<mox.PubSubItem>();
          final payload = item.payload;
          if (payload != null) {
            parsed = parsePayload(payload, itemId: itemId);
          }
        }
      }
    }

    if (parsed == null) {
      return;
    }
    final merged = mergeIncomingNotification(
      parsed,
      cached: cache[itemIdOf(parsed)],
    );
    if (merged == null) {
      return;
    }
    final itemId = itemIdOf(merged);
    final maxItems = _resolveFetchLimit();
    if (cache.length >= maxItems && !cache.containsKey(itemId)) {
      await _refreshFromServer();
      return;
    }
    cache[itemId] = merged;
    emitUpdatePayload(merged);
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != nodeId) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) {
      return;
    }
    if (event.itemIds.isEmpty || !_shouldProcessSyncEvent()) {
      return;
    }
    if (refreshOnRetractionEvent) {
      await _refreshFromServer();
      return;
    }
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) {
        continue;
      }
      cache.remove(normalized);
      emitRetractionId(normalized);
    }
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != nodeId) {
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
    if (event.node != nodeId) {
      return;
    }
    final host = _selfPepHost();
    final subscriber = event.subscriberJid?.trim();
    if (host == null || subscriber == null || subscriber.isEmpty) {
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
      nodeSession.markSubscriptionReady();
      return;
    }
    nodeSession.markSubscriptionStale();
    await subscribe();
  }

  Future<void> _handleNodeDeleted(mox.PubSubNodeDeletedEvent event) async {
    if (event.node != nodeId) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !_isFromHost(event.from, host)) {
      return;
    }
    _clearCache();
    nodeSession.resetForNodeRebuild();
    if (!nodeSession.ensureInFlight) {
      fireAndForget(_bootstrap, operationName: bootstrapOperationName);
    }
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != nodeId) {
      return;
    }
    final host = _selfPepHost();
    if (host == null || !_isFromHost(event.from, host)) {
      return;
    }
    _clearCache();
    if (rebuildNodeOnPurge) {
      nodeSession.resetForNodeRebuild();
      if (!nodeSession.ensureInFlight) {
        fireAndForget(_bootstrap, operationName: bootstrapOperationName);
      }
      return;
    }
    await _refreshFromServer();
  }

  Future<void> _refreshFromServer() async {
    final snapshot = await fetchAllWithStatus();
    if (!snapshot.isSuccess) {
      return;
    }
    final items = snapshot.items;
    final freshIds = items.map(itemIdOf).toSet();
    final previousCache = Map<String, TPayload>.from(cache);
    if (snapshot.isComplete) {
      cache.clear();
    } else {
      cache.addAll(previousCache);
    }
    for (final item in items) {
      final itemId = itemIdOf(item);
      final merged = mergeRefreshedItem(item, cached: previousCache[itemId]);
      cache[itemId] = merged;
      emitUpdatePayload(merged);
    }
    if (!snapshot.isComplete || !emitRetractionsFromCompleteSnapshot) {
      return;
    }
    final removedIds = previousCache.keys
        .where((itemId) => !freshIds.contains(itemId))
        .toList(growable: false);
    for (final itemId in removedIds) {
      emitRetractionId(itemId);
    }
  }

  void _clearCache() {
    if (cache.isEmpty) {
      return;
    }
    if (!emitRetractionsOnClear) {
      cache.clear();
      return;
    }
    final itemIds = cache.keys.toList(growable: false);
    cache.clear();
    for (final itemId in itemIds) {
      emitRetractionId(itemId);
    }
  }

  bool _isFromHost(String? from, mox.JID host) {
    final raw = from?.trim();
    if (raw == null || raw.isEmpty) {
      return false;
    }
    try {
      return mox.JID.fromString(raw).toBare().toString() == host.toString();
    } on Exception {
      return false;
    }
  }

  bool _matchesSubscriberHost({
    required String? subscriberJid,
    required mox.JID host,
  }) {
    final raw = subscriberJid?.trim();
    if (raw == null || raw.isEmpty) {
      return false;
    }
    try {
      return mox.JID.fromString(raw).toBare().toString() == host.toString();
    } on Exception {
      return false;
    }
  }
}
