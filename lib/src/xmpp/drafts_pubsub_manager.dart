import 'dart:async';

import 'package:axichat/src/common/transport.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/safe_pubsub_manager.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String draftsPubSubNode = 'urn:axi:drafts';
const String draftsNotifyFeature = 'urn:axi:drafts+notify';

const String _draftTag = 'draft';
const String _draftSyncIdAttr = 'id';
const String _draftUpdatedAtAttr = 'updated_at';
const String _draftSourceIdAttr = 'source_id';
const String _recipientsTag = 'recipients';
const String _recipientTag = 'recipient';
const String _recipientJidAttr = 'jid';
const String _recipientRoleAttr = 'role';
const String _recipientTransportAttr = 'transport';
const String _recipientRoleDefault = 'to';
const String _subjectTag = 'subject';
const String _bodyTag = 'body';
const String _htmlTag = 'html';
const String _attachmentsTag = 'attachments';
const String _attachmentTag = 'attachment';
const String _attachmentIdAttr = 'id';
const String _publishModelPublishers = 'publishers';
const String _sendLastOnSubscribe = 'on_subscribe';
const String _defaultMaxItems = '200';
const bool _notifyEnabled = true;
const bool _deliverNotificationsEnabled = true;
const bool _deliverPayloadsEnabled = true;
const bool _persistItemsEnabled = true;
const bool _presenceBasedDeliveryDisabled = false;

final class DraftRecipient {
  const DraftRecipient({
    required this.jid,
    required this.role,
    required this.transport,
  });

  final String jid;
  final String role;
  final MessageTransport transport;

  DraftRecipient copyWith({
    String? jid,
    String? role,
    MessageTransport? transport,
  }) {
    return DraftRecipient(
      jid: jid ?? this.jid,
      role: role ?? this.role,
      transport: transport ?? this.transport,
    );
  }

  static DraftRecipient? fromXml(mox.XMLNode node) {
    if (node.tag != _recipientTag) return null;
    final rawJid = node.attributes[_recipientJidAttr]?.toString().trim();
    if (rawJid == null || rawJid.isEmpty) return null;
    final rawRole = node.attributes[_recipientRoleAttr]?.toString().trim();
    final rawTransport =
        node.attributes[_recipientTransportAttr]?.toString().trim();
    final resolvedRole =
        rawRole == null || rawRole.isEmpty ? _recipientRoleDefault : rawRole;
    final resolvedTransport = rawTransport == null || rawTransport.isEmpty
        ? MessageTransport.xmpp
        : MessageTransportCodec.fromWireValue(rawTransport);
    return DraftRecipient(
      jid: rawJid,
      role: resolvedRole,
      transport: resolvedTransport,
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode(
      tag: _recipientTag,
      attributes: {
        _recipientJidAttr: jid,
        _recipientRoleAttr: role,
        _recipientTransportAttr: transport.wireValue,
      },
    );
  }
}

final class DraftSyncPayload {
  const DraftSyncPayload({
    required this.syncId,
    required this.updatedAt,
    required this.sourceId,
    required this.recipients,
    this.subject,
    this.body,
    this.html,
    this.attachmentMetadataIds = const <String>[],
  });

  final String syncId;
  final DateTime updatedAt;
  final String sourceId;
  final List<DraftRecipient> recipients;
  final String? subject;
  final String? body;
  final String? html;
  final List<String> attachmentMetadataIds;

  List<String> get recipientJids =>
      recipients.map((recipient) => recipient.jid).toList(growable: false);

  DraftSyncPayload copyWith({
    String? syncId,
    DateTime? updatedAt,
    String? sourceId,
    List<DraftRecipient>? recipients,
    String? subject,
    String? body,
    String? html,
    List<String>? attachmentMetadataIds,
  }) {
    return DraftSyncPayload(
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
      recipients: recipients ?? this.recipients,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      html: html ?? this.html,
      attachmentMetadataIds:
          attachmentMetadataIds ?? this.attachmentMetadataIds,
    );
  }

  static DraftSyncPayload? fromXml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _draftTag) return null;
    if (node.attributes['xmlns']?.toString() != draftsPubSubNode) {
      return null;
    }

    final rawSyncId = node.attributes[_draftSyncIdAttr]?.toString().trim();
    final resolvedSyncId =
        rawSyncId == null || rawSyncId.isEmpty ? itemId?.trim() : rawSyncId;
    if (resolvedSyncId == null || resolvedSyncId.isEmpty) return null;

    final rawUpdatedAt =
        node.attributes[_draftUpdatedAtAttr]?.toString().trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) return null;
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null) return null;

    final rawSourceId = node.attributes[_draftSourceIdAttr]?.toString().trim();
    final resolvedSourceId =
        rawSourceId == null || rawSourceId.isEmpty ? '' : rawSourceId;

    final recipientsNode = node.firstTag(_recipientsTag);
    final recipients = recipientsNode
            ?.findTags(_recipientTag)
            .map(DraftRecipient.fromXml)
            .whereType<DraftRecipient>()
            .toList(growable: false) ??
        const <DraftRecipient>[];

    final subject = _normalizeText(node.firstTag(_subjectTag)?.innerText());
    final body = _normalizeText(node.firstTag(_bodyTag)?.innerText());
    final html = _normalizeText(node.firstTag(_htmlTag)?.innerText());

    final attachmentsNode = node.firstTag(_attachmentsTag);
    final attachmentIds = attachmentsNode
            ?.findTags(_attachmentTag)
            .map((child) => child.attributes[_attachmentIdAttr]?.toString())
            .whereType<String>()
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList(growable: false) ??
        const <String>[];

    return DraftSyncPayload(
      syncId: resolvedSyncId,
      updatedAt: parsedUpdatedAt.toUtc(),
      sourceId: resolvedSourceId,
      recipients: recipients,
      subject: subject,
      body: body,
      html: html,
      attachmentMetadataIds: attachmentIds,
    );
  }

  mox.XMLNode toXml() {
    final updatedAtIso = updatedAt.toUtc().toIso8601String();
    final trimmedSourceId = sourceId.trim();
    return mox.XMLNode.xmlns(
      tag: _draftTag,
      xmlns: draftsPubSubNode,
      attributes: {
        _draftSyncIdAttr: syncId,
        _draftUpdatedAtAttr: updatedAtIso,
        if (trimmedSourceId.isNotEmpty) _draftSourceIdAttr: trimmedSourceId,
      },
      children: [
        if (recipients.isNotEmpty)
          mox.XMLNode(
            tag: _recipientsTag,
            children: recipients.map((recipient) => recipient.toXml()).toList(),
          ),
        if (subject case final value?)
          mox.XMLNode(tag: _subjectTag, text: value),
        if (body case final value?) mox.XMLNode(tag: _bodyTag, text: value),
        if (html case final value?) mox.XMLNode(tag: _htmlTag, text: value),
        if (attachmentMetadataIds.isNotEmpty)
          mox.XMLNode(
            tag: _attachmentsTag,
            children: attachmentMetadataIds
                .map(
                  (id) => mox.XMLNode(
                    tag: _attachmentTag,
                    attributes: {_attachmentIdAttr: id},
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  static String? _normalizeText(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}

sealed class DraftSyncUpdate {
  const DraftSyncUpdate();
}

final class DraftSyncUpdated extends DraftSyncUpdate {
  const DraftSyncUpdated(this.payload);

  final DraftSyncPayload payload;
}

final class DraftSyncRetracted extends DraftSyncUpdate {
  const DraftSyncRetracted(this.syncId);

  final String syncId;
}

final class DraftSyncUpdatedEvent extends mox.XmppEvent {
  DraftSyncUpdatedEvent(this.payload);

  final DraftSyncPayload payload;
}

final class DraftSyncRetractedEvent extends mox.XmppEvent {
  DraftSyncRetractedEvent(this.syncId);

  final String syncId;
}

final class DraftsPubSubManager extends mox.XmppManagerBase {
  DraftsPubSubManager({
    String? maxItems,
  })  : _maxItems = maxItems ?? _defaultMaxItems,
        super(managerId);

  static const String managerId = 'axi.drafts';

  final String _maxItems;

  final StreamController<DraftSyncUpdate> _updatesController =
      StreamController<DraftSyncUpdate>.broadcast();
  Stream<DraftSyncUpdate> get updates => _updatesController.stream;

  final Map<String, DraftSyncPayload> _cache = {};

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

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;

    final primaryConfig = _nodeConfig(mox.AccessModel.whitelist);
    final configured = await pubsub.configureNode(
      host,
      draftsPubSubNode,
      primaryConfig,
    );
    if (!configured.isType<mox.PubSubError>()) {
      return;
    }

    final fallbackConfig = _nodeConfig(mox.AccessModel.authorize);
    final fallbackConfigured = await pubsub.configureNode(
      host,
      draftsPubSubNode,
      fallbackConfig,
    );
    if (!fallbackConfigured.isType<mox.PubSubError>()) {
      return;
    }

    try {
      final created = await pubsub.createNodeWithConfig(
        host,
        _createNodeConfig(mox.AccessModel.whitelist),
        nodeId: draftsPubSubNode,
      );
      if (created != null) {
        await pubsub.configureNode(host, draftsPubSubNode, primaryConfig);
        return;
      }
    } on Exception {
      // ignore and retry below
    }

    try {
      final created = await pubsub.createNode(host, nodeId: draftsPubSubNode);
      if (created == null) return;
      await pubsub.configureNode(host, draftsPubSubNode, primaryConfig);
    } on Exception {
      return;
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    final result = await pubsub.subscribe(host, draftsPubSubNode);
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      if (error is mox.MalformedResponseError) return;
      return;
    }
  }

  Future<List<DraftSyncPayload>> fetchAll() async {
    final result = await fetchAllWithStatus();
    return result.items;
  }

  Future<PubSubFetchResult<DraftSyncPayload>> fetchAllWithStatus() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) {
      return const PubSubFetchResult(
        items: <DraftSyncPayload>[],
        isSuccess: false,
        isComplete: false,
      );
    }

    final result = await pubsub.getItems(
      host,
      draftsPubSubNode,
      maxItems: _resolveFetchLimit(),
    );
    if (result.isType<mox.PubSubError>()) {
      final error = result.get<mox.PubSubError>();
      final missing =
          error is mox.ItemNotFoundError || error is mox.NoItemReturnedError;
      if (missing) {
        _cache.clear();
        return const PubSubFetchResult(
          items: <DraftSyncPayload>[],
          isSuccess: true,
          isComplete: true,
        );
      }
      return const PubSubFetchResult(
        items: <DraftSyncPayload>[],
        isSuccess: false,
        isComplete: false,
      );
    }

    final items = result.get<List<mox.PubSubItem>>();
    final parsed = <DraftSyncPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) continue;
      final parsedPayload = DraftSyncPayload.fromXml(
        payload,
        itemId: item.id,
      );
      if (parsedPayload == null) continue;
      parsed.add(parsedPayload);
    }
    return PubSubFetchResult(
      items: List<DraftSyncPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: true,
    );
  }

  Future<void> publishDraft(DraftSyncPayload payload) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    final result = await pubsub.publish(
      host,
      draftsPubSubNode,
      payload.toXml(),
      id: payload.syncId,
      options: _publishOptions(),
      autoCreate: true,
      createNodeConfig: _createNodeConfig(mox.AccessModel.whitelist),
    );
    if (result.isType<mox.PubSubError>()) return;
    _cache[payload.syncId] = payload;
    _emitUpdate(payload);
  }

  Future<void> retractDraft(String syncId) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    final normalized = syncId.trim();
    if (normalized.isEmpty) return;
    final result = await pubsub.retract(
      host,
      draftsPubSubNode,
      normalized,
      notify: _notifyEnabled,
    );
    if (result.isType<mox.PubSubError>()) return;
    _cache.remove(normalized);
    _emitRetraction(normalized);
  }

  void _emitUpdate(DraftSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(DraftSyncUpdated(payload));
    }
    getAttributes().sendEvent(DraftSyncUpdatedEvent(payload));
  }

  void _emitRetraction(String syncId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(DraftSyncRetracted(syncId));
    }
    getAttributes().sendEvent(DraftSyncRetractedEvent(syncId));
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != draftsPubSubNode) return;

    DraftSyncPayload? parsed;
    if (event.item.payload case final payload?) {
      parsed = DraftSyncPayload.fromXml(payload, itemId: event.item.id);
    } else {
      final pubsub = _pubSub();
      final host = _selfPepHost();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null && host != null && itemId.isNotEmpty) {
        final itemResult = await pubsub.getItem(host, draftsPubSubNode, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          final item = itemResult.get<mox.PubSubItem>();
          final payload = item.payload;
          if (payload != null) {
            parsed = DraftSyncPayload.fromXml(
              payload,
              itemId: itemId,
            );
          }
        }
      }
    }

    if (parsed == null) return;
    _cache[parsed.syncId] = parsed;
    _emitUpdate(parsed);
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != draftsPubSubNode) return;
    if (event.itemIds.isEmpty) return;
    for (final itemId in event.itemIds) {
      final normalized = itemId.trim();
      if (normalized.isEmpty) continue;
      _cache.remove(normalized);
      _emitRetraction(normalized);
    }
  }

  Future<void> _handleRefreshEvent(PubSubItemsRefreshedEvent event) async {
    if (event.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (event.from.toBare().toString() != host.toString()) return;
    await _refreshFromServer();
  }

  Future<void> _handleSubscriptionChanged(
    PubSubSubscriptionChangedEvent event,
  ) async {
    if (event.node != draftsPubSubNode) return;
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
    if (event.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
  }

  Future<void> _refreshFromServer() async {
    final previousCache = Map<String, DraftSyncPayload>.from(_cache);
    final items = await fetchAll();
    final freshIds = items.map((item) => item.syncId).toSet();
    _cache
      ..clear()
      ..addEntries(items.map((item) => MapEntry(item.syncId, item)));
    for (final item in items) {
      _emitUpdate(item);
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
    for (final syncId in items) {
      _emitRetraction(syncId);
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
