// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/draft_limits.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/storage/models/file_models.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
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
const String _defaultMaxItems = '$draftSyncMaxItems';
const String _draftSourceIdFallback = DraftDefaults.sourceLegacyId;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _draftsPubSubBootstrapOperationName =
    'DraftsPubSubManager.bootstrapOnNegotiations';
const String _draftsPubSubRefreshOperationName =
    'DraftsPubSubManager.refreshFromServer';

final class DraftRecipient {
  const DraftRecipient({required this.jid, required this.role});

  final String jid;
  final String role;

  DraftRecipient copyWith({String? jid, String? role}) {
    return DraftRecipient(jid: jid ?? this.jid, role: role ?? this.role);
  }

  static DraftRecipient? fromXml(mox.XMLNode node) {
    if (node.tag != _recipientTag) {
      return null;
    }
    final rawJid = node.attributes[_recipientJidAttr]?.toString();
    final normalizedJid = rawJid?.toBareJidOrNull(
      maxBytes: draftSyncMaxRecipientBytes,
    );
    if (normalizedJid == null) {
      return null;
    }
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
    if (node.tag != _attachmentTag) {
      return null;
    }
    final rawId = _normalizeIdAttr(node.attributes[_attachmentIdAttr]);
    if (rawId == null || rawId.isEmpty) {
      return null;
    }
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
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final clamped = clampUtf8Value(normalized, maxBytes: maxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return null;
    }
    return clamped;
  }

  static String? _normalizeIdAttr(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
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
    if (normalized == null) {
      return null;
    }
    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasAuthority || !uri.hasScheme) {
      return null;
    }
    final scheme = uri.scheme.toLowerCase();
    if (!draftSyncAllowedAttachmentSchemes.contains(scheme)) {
      return null;
    }
    return uri.toString();
  }

  static int? _parsePositiveIntAttr(Object? value, {int? maxValue}) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    final parsed = int.tryParse(normalized);
    return _normalizePositiveInt(parsed, maxValue: maxValue);
  }

  static int? _normalizePositiveInt(int? value, {int? maxValue}) {
    if (value == null || value <= 0) {
      return null;
    }
    if (maxValue != null && value > maxValue) {
      return null;
    }
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
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
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
      updatedAt: parsedUpdatedAt,
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
                .toList(growable: false),
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
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    final clamped = clampUtf8Value(trimmed, maxBytes: maxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return null;
    }
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

final class DraftsPubSubManager
    extends PepItemPubSubNodeManager<DraftSyncPayload>
    implements PubSubHubDelegate {
  DraftsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.drafts';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(draftSyncRateLimit);

  final StreamController<DraftSyncUpdate> _updatesController =
      StreamController<DraftSyncUpdate>.broadcast();
  Stream<DraftSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => draftsPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _draftsPubSubBootstrapOperationName;

  @override
  String get refreshOperationName => _draftsPubSubRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubDrafts;

  @override
  bool get publishAutoCreate => true;

  @override
  bool get treatMissingNodeAsEmptySnapshot => true;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  Future<bool> publishDraft(DraftSyncPayload payload) => publishItem(payload);

  Future<bool> retractDraft(String syncId) => retractItem(syncId);

  @override
  DraftSyncPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      DraftSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(DraftSyncPayload payload) => payload.syncId;

  @override
  mox.XMLNode payloadToXml(DraftSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(DraftSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(DraftSyncUpdated(payload));
    }
    getAttributes().sendEvent(DraftSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String syncId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(DraftSyncRetracted(syncId));
    }
    getAttributes().sendEvent(DraftSyncRetractedEvent(syncId));
  }
}
