// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/xml_safety.dart';
import 'package:axichat/src/email/util/email_message_ids.dart';
import 'package:axichat/src/storage/models/message_models.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String messageCollectionsPubSubNode = 'urn:axi:message-collections';
const String messageCollectionsNotifyFeature =
    'urn:axi:message-collections+notify';

const int messageCollectionSyncMaxItems = 1000;

const String _entryTag = 'entry';
const String _collectionTag = 'collection';
const String _collectionIdAttr = 'collection_id';
const String _chatJidAttr = 'chat_jid';
const String _messageReferenceIdAttr = 'message_reference_id';
const String _messageStanzaIdAttr = 'message_stanza_id';
const String _messageOriginIdAttr = 'message_origin_id';
const String _messageMucStanzaIdAttr = 'message_muc_stanza_id';
const String _updatedAtAttr = 'updated_at';
const String _activeAttr = 'active';
const String _sourceIdAttr = 'source_id';
const String _defaultMaxItems = '$messageCollectionSyncMaxItems';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _messageCollectionsBootstrapOperationName =
    'MessageCollectionsPubSubManager.bootstrapOnNegotiations';
const String _messageCollectionsRefreshOperationName =
    'MessageCollectionsPubSubManager.refreshFromServer';
const int _collectionIdMaxBytes = 128;

sealed class MessageCollectionSyncItem {
  const MessageCollectionSyncItem();

  String get itemId;
  String get collectionId;
  DateTime get updatedAt;
  bool get active;
}

final class MessageCollectionSyncPayload extends MessageCollectionSyncItem {
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
  });

  @override
  final String collectionId;
  final String chatJid;
  final String messageReferenceId;
  final String? messageStanzaId;
  final String? messageOriginId;
  final String? messageMucStanzaId;
  @override
  final DateTime updatedAt;
  @override
  final bool active;
  final String sourceId;

  @override
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
    final rawMessageReferenceId = node.attributes[_messageReferenceIdAttr]
        ?.toString();
    final rawMessageStanzaId = node.attributes[_messageStanzaIdAttr]
        ?.toString();
    final rawMessageOriginId = node.attributes[_messageOriginIdAttr]
        ?.toString();
    final rawMessageMucStanzaId = node.attributes[_messageMucStanzaIdAttr]
        ?.toString();
    final messageStanzaId = _parseXmppReference(rawMessageStanzaId);
    final messageMucStanzaId = _parseXmppReference(rawMessageMucStanzaId);
    final messageOriginId = _parseOriginReference(
      rawMessageOriginId,
      hasXmppAlias: messageStanzaId != null || messageMucStanzaId != null,
    );
    final messageReferenceId = _parseCanonicalReference(
      value: rawMessageReferenceId,
      messageStanzaId: messageStanzaId,
      messageOriginId: messageOriginId,
      messageMucStanzaId: messageMucStanzaId,
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
      messageStanzaId: messageStanzaId,
      messageOriginId: messageOriginId,
      messageMucStanzaId: messageMucStanzaId,
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

  static String? _parseCanonicalReference({
    required String? value,
    required String? messageStanzaId,
    required String? messageOriginId,
    required String? messageMucStanzaId,
  }) {
    final normalized = value?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        _isLegacyReferenceValue(normalized)) {
      return null;
    }
    if (messageMucStanzaId == normalized) {
      return messageMucStanzaId;
    }
    if (messageStanzaId == normalized) {
      return messageStanzaId;
    }
    if (messageOriginId == normalized) {
      return messageOriginId;
    }
    if (messageStanzaId == null && messageMucStanzaId == null) {
      final emailReference = _parseEmailMessageReference(normalized);
      if (emailReference != null) {
        return emailReference;
      }
    }
    return _parseXmppReference(normalized);
  }

  static String? _parseOriginReference(
    String? value, {
    required bool hasXmppAlias,
  }) {
    final normalized = value?.trim();
    if (normalized == null ||
        normalized.isEmpty ||
        _isLegacyReferenceValue(normalized)) {
      return null;
    }
    if (!hasXmppAlias) {
      final emailReference = _parseEmailMessageReference(normalized);
      if (emailReference != null) {
        return emailReference;
      }
    }
    return _parseXmppReference(normalized);
  }

  static String? _parseXmppReference(String? value) {
    final normalized = normalizeWireMessageReferenceValue(value);
    if (normalized == null || _isLegacyReferenceValue(normalized)) {
      return null;
    }
    return normalized;
  }

  static String? _parseEmailMessageReference(String? value) {
    final genuine = genuineEmailMessageId(value);
    final normalized = normalizeWireMessageReferenceValue(genuine);
    if (normalized == null ||
        !normalized.contains('@') ||
        _isLegacyReferenceValue(normalized)) {
      return null;
    }
    return normalized;
  }

  static bool _isLegacyReferenceValue(String? value) =>
      isLegacyWireMessageReferenceValue(value);

  mox.XMLNode toXml() {
    final stanzaId = _parseXmppReference(messageStanzaId);
    final mucStanzaId = _parseXmppReference(messageMucStanzaId);
    final originId = _parseOriginReference(
      messageOriginId,
      hasXmppAlias: stanzaId != null || mucStanzaId != null,
    );
    return mox.XMLNode.xmlns(
      tag: _entryTag,
      xmlns: messageCollectionsPubSubNode,
      attributes: {
        _collectionIdAttr: escapeXmlAttribute(collectionId),
        _chatJidAttr: escapeXmlAttribute(chatJid),
        _messageReferenceIdAttr: escapeXmlAttribute(messageReferenceId),
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _activeAttr: active ? '1' : '0',
        _sourceIdAttr: escapeXmlAttribute(sourceId),
        _messageStanzaIdAttr: ?escapeXmlAttributeOrNull(stanzaId),
        _messageOriginIdAttr: ?escapeXmlAttributeOrNull(originId),
        _messageMucStanzaIdAttr: ?escapeXmlAttributeOrNull(mucStanzaId),
      },
    );
  }

  static String? _normalizeCollectionId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (!isWithinUtf8ByteLimit(normalized, maxBytes: _collectionIdMaxBytes)) {
      return null;
    }
    return normalized;
  }

  static String? _normalizeChatJid(String? value) =>
      value?.toBareJidOrNull(maxBytes: syncAddressMaxBytes);

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

final class MessageCollectionRecordSyncPayload
    extends MessageCollectionSyncItem {
  const MessageCollectionRecordSyncPayload({
    required this.collectionId,
    required this.updatedAt,
    required this.active,
  });

  @override
  final String collectionId;
  @override
  final DateTime updatedAt;
  @override
  final bool active;

  @override
  String get itemId => itemIdFor(collectionId: collectionId);

  static String itemIdFor({required String collectionId}) {
    final digest = crypto.sha256.convert(utf8.encode(collectionId));
    return 'collection:$digest';
  }

  static MessageCollectionRecordSyncPayload? fromXml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _collectionTag) return null;
    if (node.attributes['xmlns']?.toString() != messageCollectionsPubSubNode) {
      return null;
    }
    final collectionId = MessageCollectionSyncPayload._normalizeCollectionId(
      node.attributes[_collectionIdAttr]?.toString(),
    );
    final rawUpdatedAt = node.attributes[_updatedAtAttr]?.toString().trim();
    final parsedUpdatedAt = rawUpdatedAt == null || rawUpdatedAt.isEmpty
        ? null
        : DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (collectionId == null || parsedUpdatedAt == null) {
      return null;
    }
    final payload = MessageCollectionRecordSyncPayload(
      collectionId: collectionId,
      updatedAt: parsedUpdatedAt,
      active:
          MessageCollectionSyncPayload._parseBoolAttr(
            node.attributes[_activeAttr],
          ) ??
          true,
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
      tag: _collectionTag,
      xmlns: messageCollectionsPubSubNode,
      attributes: {
        _collectionIdAttr: escapeXmlAttribute(collectionId),
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _activeAttr: active ? '1' : '0',
      },
    );
  }
}

final class MessageCollectionSyncUpdatedEvent extends mox.XmppEvent {
  MessageCollectionSyncUpdatedEvent(this.payload);

  final MessageCollectionSyncItem payload;
}

final class MessageCollectionsPubSubManager
    extends PepItemPubSubNodeManager<MessageCollectionSyncItem>
    implements PubSubHubDelegate {
  MessageCollectionsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.message_collections';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    messageCollectionSyncRateLimit,
  );

  @override
  String get nodeId => messageCollectionsPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName =>
      _messageCollectionsBootstrapOperationName;

  @override
  String get refreshOperationName => _messageCollectionsRefreshOperationName;

  @override
  XmppOperationKind? get operationKind => null;

  @override
  bool get refreshOnRetractionEvent => true;

  @override
  bool get rebuildNodeOnPurge => false;

  @override
  bool get emitRetractionsOnClear => false;

  @override
  bool get emitRetractionsFromCompleteSnapshot => false;

  Future<bool> publishEntry(MessageCollectionSyncItem payload) =>
      publishItem(payload);

  @override
  MessageCollectionSyncItem? parsePayload(
    mox.XMLNode payload, {
    String? itemId,
  }) {
    return switch (payload.tag) {
      _entryTag => MessageCollectionSyncPayload.fromXml(
        payload,
        itemId: itemId,
      ),
      _collectionTag => MessageCollectionRecordSyncPayload.fromXml(
        payload,
        itemId: itemId,
      ),
      _ => null,
    };
  }

  @override
  String itemIdOf(MessageCollectionSyncItem payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(MessageCollectionSyncItem payload) {
    return switch (payload) {
      MessageCollectionSyncPayload() => payload.toXml(),
      MessageCollectionRecordSyncPayload() => payload.toXml(),
    };
  }

  @override
  void emitUpdatePayload(MessageCollectionSyncItem payload) {
    getAttributes().sendEvent(MessageCollectionSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {}
}
