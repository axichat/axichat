// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/draft_limits.dart';
import 'package:axichat/src/common/fire_and_forget.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/storage/models/file_models.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/xmpp/pubsub_events.dart';
import 'package:axichat/src/xmpp/pubsub_error_extensions.dart';
import 'package:axichat/src/xmpp/pubsub_forms.dart';
import 'package:axichat/src/xmpp/pubsub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
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
const String _recipientRoleDefault = 'to';
const String _subjectTag = 'subject';
const String _bodyTag = 'body';
const String _htmlTag = 'html';
const String _quoteIdAttr = 'quote_id';
const String _quoteKindAttr = 'quote_kind';
const String _attachmentsTag = 'attachments';
const String _attachmentTag = 'attachment';
const String _attachmentIdAttr = 'id';
const String _attachmentUrlAttr = 'url';
const String _attachmentNameAttr = 'name';
const String _attachmentMimeAttr = 'mime';
const String _attachmentSizeAttr = 'size';
const String _attachmentWidthAttr = 'width';
const String _attachmentHeightAttr = 'height';
const String _publishModelPublishers = 'publishers';
const String _defaultMaxItems = '$draftSyncMaxItems';
const String _draftSourceIdFallback = DraftDefaults.sourceLegacyId;
const bool _notifyEnabled = true;
const bool _deliverNotificationsEnabled = true;
const bool _deliverPayloadsEnabled = true;
const bool _persistItemsEnabled = true;
const bool _presenceBasedDeliveryDisabled = false;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _draftsPubSubBootstrapOperationName =
    'DraftsPubSubManager.bootstrapOnNegotiations';
const String _draftsPubSubRefreshOperationName =
    'DraftsPubSubManager.refreshFromServer';
final XmppOperationEvent _draftsEnsureStartEvent = XmppOperationEvent(
  kind: XmppOperationKind.pubSubDrafts,
  stage: XmppOperationStage.start,
);
final XmppOperationEvent _draftsEnsureSuccessEvent = XmppOperationEvent(
  kind: XmppOperationKind.pubSubDrafts,
  stage: XmppOperationStage.end,
);
final XmppOperationEvent _draftsEnsureFailureEvent = XmppOperationEvent(
  kind: XmppOperationKind.pubSubDrafts,
  stage: XmppOperationStage.end,
  isSuccess: false,
);

final class DraftRecipient {
  const DraftRecipient({required this.jid, required this.role});

  final String jid;
  final String role;

  DraftRecipient copyWith({String? jid, String? role}) {
    return DraftRecipient(jid: jid ?? this.jid, role: role ?? this.role);
  }

  static DraftRecipient? fromXml(mox.XMLNode node) {
    if (node.tag != _recipientTag) return null;
    final rawJid = node.attributes[_recipientJidAttr]?.toString();
    final normalizedJid = rawJid?.toBareJidOrNull(
      maxBytes: draftSyncMaxRecipientBytes,
    );
    if (normalizedJid == null) return null;
    final rawRole = node.attributes[_recipientRoleAttr]?.toString().trim();
    final normalizedRole = rawRole?.toLowerCase();
    final resolvedRole = draftSyncAllowedRecipientRoles.contains(normalizedRole)
        ? normalizedRole!
        : _recipientRoleDefault;
    return DraftRecipient(jid: normalizedJid, role: resolvedRole);
  }

  mox.XMLNode toXml() {
    final normalizedRole = role.trim().toLowerCase();
    final resolvedRole = draftSyncAllowedRecipientRoles.contains(normalizedRole)
        ? normalizedRole
        : _recipientRoleDefault;
    return mox.XMLNode(
      tag: _recipientTag,
      attributes: {_recipientJidAttr: jid, _recipientRoleAttr: resolvedRole},
    );
  }
}

final class DraftAttachmentRef {
  const DraftAttachmentRef({
    required this.id,
    this.url,
    this.filename,
    this.mimeType,
    this.sizeBytes,
    this.width,
    this.height,
  });

  final String id;
  final String? url;
  final String? filename;
  final String? mimeType;
  final int? sizeBytes;
  final int? width;
  final int? height;

  DraftAttachmentRef copyWith({
    String? id,
    String? url,
    String? filename,
    String? mimeType,
    int? sizeBytes,
    int? width,
    int? height,
  }) {
    return DraftAttachmentRef(
      id: id ?? this.id,
      url: url ?? this.url,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  static DraftAttachmentRef? fromXml(mox.XMLNode node) {
    if (node.tag != _attachmentTag) return null;
    final rawId = _normalizeIdAttr(node.attributes[_attachmentIdAttr]);
    if (rawId == null || rawId.isEmpty) return null;
    final url = _normalizeUrlAttr(node.attributes[_attachmentUrlAttr]);
    final filename = _normalizeAttr(
      node.attributes[_attachmentNameAttr],
      maxBytes: draftSyncMaxAttachmentNameBytes,
    );
    final mimeType = _normalizeAttr(
      node.attributes[_attachmentMimeAttr],
      maxBytes: draftSyncMaxAttachmentMimeBytes,
    );
    final sizeBytes = _parsePositiveIntAttr(
      node.attributes[_attachmentSizeAttr],
      maxValue: draftSyncMaxAttachmentSizeBytes,
    );
    final width = _parsePositiveIntAttr(node.attributes[_attachmentWidthAttr]);
    final height = _parsePositiveIntAttr(
      node.attributes[_attachmentHeightAttr],
    );
    return DraftAttachmentRef(
      id: rawId,
      url: url,
      filename: filename,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
    );
  }

  mox.XMLNode toXml() {
    final normalizedUrl = _normalizeUrlAttr(url);
    final normalizedName = _normalizeAttr(
      filename,
      maxBytes: draftSyncMaxAttachmentNameBytes,
    );
    final normalizedMime = _normalizeAttr(
      mimeType,
      maxBytes: draftSyncMaxAttachmentMimeBytes,
    );
    final normalizedSize = _normalizePositiveInt(
      sizeBytes,
      maxValue: draftSyncMaxAttachmentSizeBytes,
    );
    final normalizedWidth = _normalizePositiveInt(width);
    final normalizedHeight = _normalizePositiveInt(height);
    return mox.XMLNode(
      tag: _attachmentTag,
      attributes: {
        _attachmentIdAttr: id,
        if (normalizedUrl != null && normalizedUrl.isNotEmpty)
          _attachmentUrlAttr: normalizedUrl,
        if (normalizedName != null && normalizedName.isNotEmpty)
          _attachmentNameAttr: normalizedName,
        if (normalizedMime != null && normalizedMime.isNotEmpty)
          _attachmentMimeAttr: normalizedMime,
        if (normalizedSize != null)
          _attachmentSizeAttr: normalizedSize.toString(),
        if (normalizedWidth != null)
          _attachmentWidthAttr: normalizedWidth.toString(),
        if (normalizedHeight != null)
          _attachmentHeightAttr: normalizedHeight.toString(),
      },
    );
  }

  static String? _normalizeAttr(Object? value, {required int maxBytes}) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    final clamped = clampUtf8Value(normalized, maxBytes: maxBytes);
    if (clamped == null || clamped.trim().isEmpty) return null;
    return clamped;
  }

  static String? _normalizeIdAttr(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    if (!isWithinUtf8ByteLimit(normalized, maxBytes: draftSyncMaxIdBytes)) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeUrlAttr(Object? value) {
    final normalized = _normalizeAttr(
      value,
      maxBytes: draftSyncMaxAttachmentUrlBytes,
    );
    if (normalized == null) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (!draftSyncAllowedAttachmentSchemes.contains(scheme)) {
      return null;
    }
    return uri.toString();
  }

  static int? _parsePositiveIntAttr(Object? value, {int? maxValue}) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) return null;
    final parsed = int.tryParse(normalized);
    return _normalizePositiveInt(parsed, maxValue: maxValue);
  }

  static int? _normalizePositiveInt(int? value, {int? maxValue}) {
    if (value == null || value <= 0) return null;
    if (maxValue != null && value > maxValue) return null;
    return value;
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
    this.quotingStanzaId,
    this.quotingReferenceKind,
    this.attachments = const <DraftAttachmentRef>[],
  });

  final String syncId;
  final DateTime updatedAt;
  final String sourceId;
  final List<DraftRecipient> recipients;
  final String? subject;
  final String? body;
  final String? html;
  final String? quotingStanzaId;
  final MessageReferenceKind? quotingReferenceKind;
  final List<DraftAttachmentRef> attachments;

  List<String> get recipientJids =>
      recipients.map((recipient) => recipient.jid).toList(growable: false);

  List<String> get attachmentMetadataIds =>
      attachments.map((attachment) => attachment.id).toList(growable: false);

  DraftSyncPayload copyWith({
    String? syncId,
    DateTime? updatedAt,
    String? sourceId,
    List<DraftRecipient>? recipients,
    String? subject,
    String? body,
    String? html,
    String? quotingStanzaId,
    MessageReferenceKind? quotingReferenceKind,
    List<DraftAttachmentRef>? attachments,
  }) {
    return DraftSyncPayload(
      syncId: syncId ?? this.syncId,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
      recipients: recipients ?? this.recipients,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      html: html ?? this.html,
      quotingStanzaId: quotingStanzaId ?? this.quotingStanzaId,
      quotingReferenceKind: quotingReferenceKind ?? this.quotingReferenceKind,
      attachments: attachments ?? this.attachments,
    );
  }

  static DraftSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _draftTag) return null;
    if (node.attributes['xmlns']?.toString() != draftsPubSubNode) {
      return null;
    }

    final rawSyncId = node.attributes[_draftSyncIdAttr]?.toString().trim();
    final resolvedSyncId = rawSyncId == null || rawSyncId.isEmpty
        ? itemId?.trim()
        : rawSyncId;
    if (resolvedSyncId == null || resolvedSyncId.isEmpty) return null;
    if (!isWithinUtf8ByteLimit(resolvedSyncId, maxBytes: draftSyncMaxIdBytes)) {
      return null;
    }

    final rawUpdatedAt = node.attributes[_draftUpdatedAtAttr]
        ?.toString()
        .trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) return null;
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null) return null;

    final rawSourceId = node.attributes[_draftSourceIdAttr]?.toString().trim();
    final resolvedSourceId =
        _normalizeText(rawSourceId, maxBytes: draftSyncMaxIdBytes) ??
        _draftSourceIdFallback;

    final recipientsNode = node.firstTag(_recipientsTag);
    final recipients =
        recipientsNode
            ?.findTags(_recipientTag)
            .map(DraftRecipient.fromXml)
            .whereType<DraftRecipient>()
            .toList(growable: false) ??
        const <DraftRecipient>[];

    final subject = _normalizeText(
      node.firstTag(_subjectTag)?.innerText(),
      maxBytes: draftSyncMaxSubjectBytes,
    );
    final body = _normalizeText(
      node.firstTag(_bodyTag)?.innerText(),
      maxBytes: draftSyncMaxBodyBytes,
    );
    final html = _normalizeText(
      node.firstTag(_htmlTag)?.innerText(),
      maxBytes: draftSyncMaxHtmlBytes,
    );
    final quotingStanzaId = _normalizeText(
      node.attributes[_quoteIdAttr]?.toString(),
      maxBytes: draftSyncMaxIdBytes,
    );
    final quotingReferenceKind = _parseReferenceKind(
      node.attributes[_quoteKindAttr]?.toString(),
    );

    final attachmentsNode = node.firstTag(_attachmentsTag);
    final attachments =
        attachmentsNode
            ?.findTags(_attachmentTag)
            .map(DraftAttachmentRef.fromXml)
            .whereType<DraftAttachmentRef>()
            .toList(growable: false) ??
        const <DraftAttachmentRef>[];
    if (recipients.length > draftSyncMaxRecipients) return null;
    if (attachments.length > draftSyncMaxAttachments) return null;

    return DraftSyncPayload(
      syncId: resolvedSyncId,
      updatedAt: parsedUpdatedAt.toUtc(),
      sourceId: resolvedSourceId,
      recipients: recipients,
      subject: subject,
      body: body,
      html: html,
      quotingStanzaId: quotingStanzaId,
      quotingReferenceKind: quotingReferenceKind,
      attachments: attachments,
    );
  }

  mox.XMLNode toXml() {
    final updatedAtIso = updatedAt.toUtc().toIso8601String();
    final normalizedSourceId = _normalizeText(
      sourceId,
      maxBytes: draftSyncMaxIdBytes,
    );
    final normalizedSubject = _normalizeText(
      subject,
      maxBytes: draftSyncMaxSubjectBytes,
    );
    final normalizedBody = _normalizeText(
      body,
      maxBytes: draftSyncMaxBodyBytes,
    );
    final normalizedHtml = _normalizeText(
      html,
      maxBytes: draftSyncMaxHtmlBytes,
    );
    final normalizedQuoteId = _normalizeText(
      quotingStanzaId,
      maxBytes: draftSyncMaxIdBytes,
    );
    final normalizedQuoteKind = _referenceKindAttrValue(quotingReferenceKind);
    final limitedRecipients = recipients.length > draftSyncMaxRecipients
        ? recipients.take(draftSyncMaxRecipients).toList(growable: false)
        : recipients;
    final limitedAttachments = attachments.length > draftSyncMaxAttachments
        ? attachments.take(draftSyncMaxAttachments).toList(growable: false)
        : attachments;
    return mox.XMLNode.xmlns(
      tag: _draftTag,
      xmlns: draftsPubSubNode,
      attributes: {
        _draftSyncIdAttr: syncId,
        _draftUpdatedAtAttr: updatedAtIso,
        _draftSourceIdAttr: ?normalizedSourceId,
        _quoteIdAttr: ?normalizedQuoteId,
        _quoteKindAttr: ?normalizedQuoteKind,
      },
      children: [
        if (limitedRecipients.isNotEmpty)
          mox.XMLNode(
            tag: _recipientsTag,
            children: limitedRecipients
                .map((recipient) => recipient.toXml())
                .toList(),
          ),
        if (normalizedSubject case final value?)
          mox.XMLNode(tag: _subjectTag, text: value),
        if (normalizedBody case final value?)
          mox.XMLNode(tag: _bodyTag, text: value),
        if (normalizedHtml case final value?)
          mox.XMLNode(tag: _htmlTag, text: value),
        if (limitedAttachments.isNotEmpty)
          mox.XMLNode(
            tag: _attachmentsTag,
            children: limitedAttachments
                .map((attachment) => attachment.toXml())
                .toList(),
          ),
      ],
    );
  }

  static String? _normalizeText(String? value, {required int maxBytes}) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    final clamped = clampUtf8Value(trimmed, maxBytes: maxBytes);
    if (clamped == null || clamped.trim().isEmpty) return null;
    return clamped;
  }

  static MessageReferenceKind? _parseReferenceKind(String? value) {
    return switch (value?.trim()) {
      'stanza' => MessageReferenceKind.stanzaId,
      'origin' => MessageReferenceKind.originId,
      'muc' => MessageReferenceKind.mucStanzaId,
      _ => null,
    };
  }

  static String? _referenceKindAttrValue(MessageReferenceKind? kind) {
    return switch (kind) {
      MessageReferenceKind.stanzaId => 'stanza',
      MessageReferenceKind.originId => 'origin',
      MessageReferenceKind.mucStanzaId => 'muc',
      null => null,
    };
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

final class _PubSubNodeSession {
  DateTime? _lastEnsureAttempt;
  bool _ensureInFlight = false;
  bool _ensurePending = false;
  bool _nodeReady = false;
  bool _subscriptionReady = false;
  Completer<void>? _ensureCompleter;
  Completer<void>? _subscribeCompleter;

  bool get nodeReady => _nodeReady;
  bool get subscriptionReady => _subscriptionReady;
  bool get ensureInFlight => _ensureInFlight;
  Future<void>? get activeEnsure => _ensureCompleter?.future;
  Future<void>? get activeSubscribe => _subscribeCompleter?.future;

  bool shouldAttemptEnsure(Duration backoff) {
    if (_ensureInFlight || _nodeReady) return false;
    final lastAttempt = _lastEnsureAttempt;
    if (lastAttempt == null) return true;
    return DateTime.timestamp().difference(lastAttempt) >= backoff;
  }

  Completer<void> beginEnsure() {
    final completer = Completer<void>();
    _ensureCompleter = completer;
    _ensureInFlight = true;
    _lastEnsureAttempt = DateTime.timestamp();
    return completer;
  }

  void completeEnsure(Completer<void> completer) {
    _ensureInFlight = false;
    _ensureCompleter = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  bool takePendingRetry() {
    final shouldRetry = _ensurePending && !_nodeReady;
    _ensurePending = false;
    return shouldRetry;
  }

  Completer<void> beginSubscribe() {
    final completer = Completer<void>();
    _subscribeCompleter = completer;
    return completer;
  }

  void finishSubscribe(Completer<void> completer) {
    _subscribeCompleter = null;
    if (!completer.isCompleted) {
      completer.complete();
    }
  }

  void markNodeReady() {
    _nodeReady = true;
  }

  void markSubscriptionReady() {
    _subscriptionReady = true;
  }

  void markSubscriptionStale() {
    _subscriptionReady = false;
  }

  void resetForNodeRebuild() {
    _nodeReady = false;
    _subscriptionReady = false;
    _lastEnsureAttempt = null;
    _ensurePending = true;
  }
}

final class DraftsPubSubManager extends mox.XmppManagerBase {
  DraftsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.drafts';

  final String _maxItems;
  var _accessModel = mox.AccessModel.whitelist;

  final StreamController<DraftSyncUpdate> _updatesController =
      StreamController<DraftSyncUpdate>.broadcast();
  Stream<DraftSyncUpdate> get updates => _updatesController.stream;

  Future<void> close() async {
    if (_updatesController.isClosed) return;
    await _updatesController.close();
  }

  final Map<String, DraftSyncPayload> _cache = {};
  final SyncRateLimiter _rateLimiter = SyncRateLimiter(draftSyncRateLimit);
  final _PubSubNodeSession _nodeSession = _PubSubNodeSession();

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

  mox.NodeConfig _createNodeConfig(
    mox.AccessModel accessModel, {
    String? sendLastPublishedItem,
  }) => _nodeConfig(
    accessModel,
    sendLastPublishedItem: sendLastPublishedItem,
  ).toNodeConfig();

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
    var error = configured.get<mox.PubSubError>();
    logger.fine(
      'PubSub node config failed. node=$node '
      'accessModel=${config.accessModel.value} '
      'error=${error.runtimeType}.',
    );
    if (error.indicatesMissingNode) {
      return error;
    }
    final sendLastValue = config.sendLastPublishedItem?.trim();
    final hasSendLast = sendLastValue != null && sendLastValue.isNotEmpty;
    if (!hasSendLast) {
      return error;
    }
    logger.fine(
      'PubSub node config retry without send_last. node=$node '
      'accessModel=${config.accessModel.value}.',
    );
    final stripped = config.withoutSendLastPublishedItem();
    final strippedResult = await pubsub.configureNode(host, node, stripped);
    if (!strippedResult.isType<mox.PubSubError>()) {
      logger.fine(
        'PubSub node configured without send_last. node=$node '
        'accessModel=${config.accessModel.value}.',
      );
      return null;
    }
    final strippedError = strippedResult.get<mox.PubSubError>();
    logger.fine(
      'PubSub node config failed without send_last. node=$node '
      'accessModel=${config.accessModel.value} '
      'error=${strippedError.runtimeType}.',
    );
    return strippedError;
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
    node: draftsPubSubNode,
  );

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

  bool _isSnapshotComplete({required int itemsCount, required int maxItems}) =>
      itemsCount < maxItems;

  void _setAccessModel(mox.AccessModel accessModel) {
    _accessModel = accessModel;
    _nodeSession.markNodeReady();
  }

  Future<void> ensureNode() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    if (_nodeSession.nodeReady) return;
    final activeEnsure = _nodeSession.activeEnsure;
    if (activeEnsure != null) {
      await activeEnsure;
      return;
    }
    if (!_nodeSession.shouldAttemptEnsure(_ensureNodeBackoff)) return;
    final completer = _nodeSession.beginEnsure();
    var success = false;
    getAttributes().sendEvent(_draftsEnsureStartEvent);
    try {
      final sendLastPublishedItem = await _resolveSendLastPublishedItem(
        pubsub,
        host,
      );
      final primaryConfig = _nodeConfig(
        mox.AccessModel.whitelist,
        sendLastPublishedItem: sendLastPublishedItem,
      );
      final primaryError = await _configureNodeWithFallback(
        pubsub,
        host,
        draftsPubSubNode,
        primaryConfig,
      );
      if (primaryError == null) {
        _setAccessModel(mox.AccessModel.whitelist);
        success = true;
        return;
      }

      final fallbackConfig = _nodeConfig(
        mox.AccessModel.authorize,
        sendLastPublishedItem: sendLastPublishedItem,
      );
      final fallbackError = await _configureNodeWithFallback(
        pubsub,
        host,
        draftsPubSubNode,
        fallbackConfig,
      );
      if (fallbackError == null) {
        _setAccessModel(mox.AccessModel.authorize);
        success = true;
        return;
      }
      final shouldCreateNode =
          primaryError.indicatesMissingNode ||
          fallbackError.indicatesMissingNode;
      if (!shouldCreateNode) {
        return;
      }
      logger.fine('PubSub node missing; creating node=$draftsPubSubNode.');

      try {
        await pubsub.createNodeWithConfig(
          host,
          primaryConfig.toNodeConfig(),
          nodeId: draftsPubSubNode,
        );
        final appliedError = await _configureNodeWithFallback(
          pubsub,
          host,
          draftsPubSubNode,
          primaryConfig,
        );
        if (appliedError == null) {
          _setAccessModel(mox.AccessModel.whitelist);
          success = true;
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        await pubsub.createNodeWithConfig(
          host,
          fallbackConfig.toNodeConfig(),
          nodeId: draftsPubSubNode,
        );
        final appliedError = await _configureNodeWithFallback(
          pubsub,
          host,
          draftsPubSubNode,
          fallbackConfig,
        );
        if (appliedError == null) {
          _setAccessModel(mox.AccessModel.authorize);
          success = true;
          return;
        }
      } on Exception {
        // ignore and retry below
      }

      try {
        await pubsub.createNode(host, nodeId: draftsPubSubNode);
        final appliedPrimaryError = await _configureNodeWithFallback(
          pubsub,
          host,
          draftsPubSubNode,
          primaryConfig,
        );
        if (appliedPrimaryError == null) {
          _setAccessModel(mox.AccessModel.whitelist);
          success = true;
          return;
        }
        final appliedFallbackError = await _configureNodeWithFallback(
          pubsub,
          host,
          draftsPubSubNode,
          fallbackConfig,
        );
        if (appliedFallbackError == null) {
          _setAccessModel(mox.AccessModel.authorize);
          success = true;
        }
      } on Exception {
        return;
      }
    } finally {
      _nodeSession.completeEnsure(completer);
      getAttributes().sendEvent(
        success ? _draftsEnsureSuccessEvent : _draftsEnsureFailureEvent,
      );
      if (_nodeSession.takePendingRetry()) {
        fireAndForget(
          _bootstrap,
          operationName: _draftsPubSubBootstrapOperationName,
        );
      }
    }
  }

  Future<void> subscribe() async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return;
    if (_nodeSession.subscriptionReady) return;
    final activeSubscribe = _nodeSession.activeSubscribe;
    if (activeSubscribe != null) {
      await activeSubscribe;
      return;
    }
    final completer = _nodeSession.beginSubscribe();
    try {
      final result = await pubsub.subscribe(host, draftsPubSubNode);
      if (result.isType<mox.PubSubError>()) {
        final error = result.get<mox.PubSubError>();
        if (error is mox.MalformedResponseError) return;
        return;
      }
      _nodeSession.markSubscriptionReady();
    } finally {
      _nodeSession.finishSubscribe(completer);
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

    final fetchLimit = _resolveFetchLimit();
    final result = await pubsub.getItems(
      host,
      draftsPubSubNode,
      maxItems: fetchLimit,
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
    var hadParseFailure = false;
    final parsed = <DraftSyncPayload>[];
    for (final item in items) {
      final payload = item.payload;
      if (payload == null) {
        hadParseFailure = true;
        continue;
      }
      final parsedPayload = DraftSyncPayload.fromXml(payload, itemId: item.id);
      if (parsedPayload == null) {
        hadParseFailure = true;
        continue;
      }
      parsed.add(parsedPayload);
    }
    final isComplete =
        !hadParseFailure &&
        _isSnapshotComplete(itemsCount: items.length, maxItems: fetchLimit);
    return PubSubFetchResult(
      items: List<DraftSyncPayload>.unmodifiable(parsed),
      isSuccess: true,
      isComplete: isComplete,
    );
  }

  Future<bool> publishDraft(DraftSyncPayload payload) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return false;
    final result = await pubsub.publish(
      host,
      draftsPubSubNode,
      payload.toXml(),
      id: payload.syncId,
      options: _publishOptions(),
      autoCreate: true,
      createNodeConfig: _createNodeConfig(_accessModel),
    );
    if (result.isType<mox.PubSubError>()) return false;
    _cache[payload.syncId] = payload;
    _emitUpdate(payload);
    return true;
  }

  Future<bool> retractDraft(String syncId) async {
    final pubsub = _pubSub();
    final host = _selfPepHost();
    if (pubsub == null || host == null) return false;
    final normalized = syncId.trim();
    if (normalized.isEmpty) return false;
    final result = await pubsub.retract(
      host,
      draftsPubSubNode,
      normalized,
      notify: _notifyEnabled,
    );
    if (result.isType<mox.PubSubError>()) return false;
    _cache.remove(normalized);
    _emitRetraction(normalized);
    return true;
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

  bool _shouldProcessSyncEvent() {
    if (_rateLimiter.allowEvent()) {
      return true;
    }
    if (_rateLimiter.shouldRefreshNow()) {
      fireAndForget(
        _refreshFromServer,
        operationName: _draftsPubSubRefreshOperationName,
      );
    }
    return false;
  }

  Future<void> _handleNotification(mox.PubSubNotificationEvent event) async {
    if (event.item.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null || !event.isFromPepOwner(host)) return;
    if (!_shouldProcessSyncEvent()) return;

    DraftSyncPayload? parsed;
    if (event.item.payload case final payload?) {
      parsed = DraftSyncPayload.fromXml(payload, itemId: event.item.id);
    } else {
      final pubsub = _pubSub();
      final itemId = event.item.id.trim();
      if (itemId.isEmpty) {
        await _refreshFromServer();
        return;
      }
      if (pubsub != null && itemId.isNotEmpty) {
        final itemResult = await pubsub.getItem(host, draftsPubSubNode, itemId);
        if (!itemResult.isType<mox.PubSubError>()) {
          final item = itemResult.get<mox.PubSubItem>();
          final payload = item.payload;
          if (payload != null) {
            parsed = DraftSyncPayload.fromXml(payload, itemId: itemId);
          }
        }
      }
    }

    if (parsed == null) return;
    final maxItems = _resolveFetchLimit();
    if (_cache.length >= maxItems && !_cache.containsKey(parsed.syncId)) {
      await _refreshFromServer();
      return;
    }
    _cache[parsed.syncId] = parsed;
    _emitUpdate(parsed);
  }

  Future<void> _handleRetractions(mox.PubSubItemsRetractedEvent event) async {
    if (event.node != draftsPubSubNode) return;
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

    if (event.state == mox.SubscriptionState.subscribed) {
      _nodeSession.markSubscriptionReady();
      return;
    }
    _nodeSession.markSubscriptionStale();
    await subscribe();
  }

  Future<void> _handleNodeDeleted(mox.PubSubNodeDeletedEvent event) async {
    if (event.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeSession.resetForNodeRebuild();
    if (!_nodeSession.ensureInFlight) {
      fireAndForget(
        _bootstrap,
        operationName: _draftsPubSubBootstrapOperationName,
      );
    }
  }

  Future<void> _handleNodePurged(mox.PubSubNodePurgedEvent event) async {
    if (event.node != draftsPubSubNode) return;
    final host = _selfPepHost();
    if (host == null) return;
    if (!_isFromHost(event.from, host)) return;
    _clearCache();
    _nodeSession.resetForNodeRebuild();
    if (!_nodeSession.ensureInFlight) {
      fireAndForget(
        _bootstrap,
        operationName: _draftsPubSubBootstrapOperationName,
      );
    }
  }

  Future<void> _refreshFromServer() async {
    final snapshot = await fetchAllWithStatus();
    if (!snapshot.isSuccess) return;
    final items = snapshot.items;
    final freshIds = items.map((item) => item.syncId).toSet();
    final previousCache = Map<String, DraftSyncPayload>.from(_cache);
    if (snapshot.isComplete) {
      _cache
        ..clear()
        ..addEntries(items.map((item) => MapEntry(item.syncId, item)));
    } else {
      for (final item in items) {
        _cache[item.syncId] = item;
      }
    }
    for (final item in items) {
      _emitUpdate(item);
    }
    if (!snapshot.isComplete) {
      return;
    }
    final removedIds = previousCache.keys
        .where((id) => !freshIds.contains(id))
        .toList();
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
