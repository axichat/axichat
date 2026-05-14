// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String contactsPubSubNode = 'urn:axi:contacts';
const String contactsNotifyFeature = 'urn:axi:contacts+notify';
const int contactsSyncMaxItems = 5000;

const String _contactTag = 'contact';
const String _fieldTag = 'field';
const String _addressKeyAttr = 'address_key';
const String _activeAttr = 'active';
const String _manualAttr = 'manual';
const String _favoriteAttr = 'favorite';
const String _displayOverrideAttr = 'display_override';
const String _folderCollectionIdAttr = 'folder_collection_id';
const String _updatedAtAttr = 'updated_at';
const String _activeUpdatedAtAttr = 'active_updated_at';
const String _manualUpdatedAtAttr = 'manual_updated_at';
const String _favoriteUpdatedAtAttr = 'favorite_updated_at';
const String _displayNameUpdatedAtAttr = 'display_name_updated_at';
const String _folderRuleUpdatedAtAttr = 'folder_rule_updated_at';
const String _sourceIdAttr = 'source_id';
const String _fieldIdAttr = 'field_id';
const String _fieldKindAttr = 'kind';
const String _fieldLabelAttr = 'label';
const String _fieldValueAttr = 'value';
const String _fieldSortOrderAttr = 'sort_order';
const String _defaultMaxItems = '$contactsSyncMaxItems';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _bootstrapOperationName =
    'ContactsPubSubManager.bootstrapOnNegotiations';
const String _refreshOperationName = 'ContactsPubSubManager.refreshFromServer';
const int _contactValueMaxBytes = 4096;
const int _contactFieldIdMaxBytes = 128;

final class ContactSyncFieldPayload {
  const ContactSyncFieldPayload({
    required this.fieldId,
    required this.kind,
    required this.value,
    required this.sortOrder,
    required this.active,
    required this.updatedAt,
    required this.sourceId,
    this.label,
  });

  final String fieldId;
  final ContactDetailFieldKind kind;
  final String? label;
  final String value;
  final int sortOrder;
  final bool active;
  final DateTime updatedAt;
  final String sourceId;

  static ContactSyncFieldPayload? fromXml(mox.XMLNode node) {
    if (node.tag != _fieldTag) return null;
    final fieldId = _normalizeFieldValue(
      node.attributes[_fieldIdAttr]?.toString(),
      maxBytes: _contactFieldIdMaxBytes,
    );
    final kind = ContactDetailFieldKind.fromSyncName(
      node.attributes[_fieldKindAttr]?.toString(),
    );
    final value = _normalizeFieldValue(
      node.attributes[_fieldValueAttr]?.toString(),
      maxBytes: _contactValueMaxBytes,
    );
    final updatedAt = _parseDateTimeAttr(node.attributes[_updatedAtAttr]);
    if (fieldId == null || kind == null || value == null || updatedAt == null) {
      return null;
    }
    return ContactSyncFieldPayload(
      fieldId: fieldId,
      kind: kind,
      label: _normalizeFieldValue(
        node.attributes[_fieldLabelAttr]?.toString(),
        maxBytes: _contactValueMaxBytes,
      ),
      value: value,
      sortOrder:
          _parsePositiveIntAttr(node.attributes[_fieldSortOrderAttr]) ?? 0,
      active: _parseBoolAttr(node.attributes[_activeAttr]) ?? true,
      updatedAt: updatedAt,
      sourceId: _normalizeSourceId(node.attributes[_sourceIdAttr]?.toString()),
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode(
      tag: _fieldTag,
      attributes: {
        _fieldIdAttr: fieldId,
        _fieldKindAttr: kind.syncName,
        _fieldLabelAttr: ?label,
        _fieldValueAttr: value,
        _fieldSortOrderAttr: sortOrder.toString(),
        _activeAttr: active ? '1' : '0',
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _sourceIdAttr: sourceId,
      },
    );
  }
}

final class ContactSyncPayload {
  const ContactSyncPayload({
    required this.addressKey,
    required this.active,
    required this.manual,
    required this.favorited,
    required this.updatedAt,
    required this.sourceId,
    this.displayNameOverride,
    this.folderCollectionId,
    this.activeUpdatedAt,
    this.manualUpdatedAt,
    this.favoriteUpdatedAt,
    this.displayNameUpdatedAt,
    this.folderRuleUpdatedAt,
    this.fields = const <ContactSyncFieldPayload>[],
  });

  final String addressKey;
  final bool active;
  final bool manual;
  final bool favorited;
  final String? displayNameOverride;
  final String? folderCollectionId;
  final DateTime updatedAt;
  final DateTime? activeUpdatedAt;
  final DateTime? manualUpdatedAt;
  final DateTime? favoriteUpdatedAt;
  final DateTime? displayNameUpdatedAt;
  final DateTime? folderRuleUpdatedAt;
  final String sourceId;
  final List<ContactSyncFieldPayload> fields;

  String get itemId => itemIdFor(addressKey: addressKey);

  static String itemIdFor({required String addressKey}) {
    final digest = crypto.sha256.convert(utf8.encode(addressKey));
    return 'contact:$digest';
  }

  static ContactSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _contactTag) return null;
    if (node.attributes['xmlns']?.toString() != contactsPubSubNode) {
      return null;
    }
    final addressKey = node.attributes[_addressKeyAttr]
        ?.toString()
        .toBareJidOrNull(maxBytes: syncAddressMaxBytes);
    final updatedAt = _parseDateTimeAttr(node.attributes[_updatedAtAttr]);
    if (addressKey == null || updatedAt == null) {
      return null;
    }
    final payload = ContactSyncPayload(
      addressKey: addressKey,
      active: _parseBoolAttr(node.attributes[_activeAttr]) ?? true,
      manual: _parseBoolAttr(node.attributes[_manualAttr]) ?? false,
      favorited: _parseBoolAttr(node.attributes[_favoriteAttr]) ?? false,
      displayNameOverride: _normalizeFieldValue(
        node.attributes[_displayOverrideAttr]?.toString(),
        maxBytes: _contactValueMaxBytes,
      ),
      folderCollectionId: _normalizeCollectionId(
        node.attributes[_folderCollectionIdAttr]?.toString(),
      ),
      updatedAt: updatedAt,
      activeUpdatedAt: _parseDateTimeAttr(
        node.attributes[_activeUpdatedAtAttr],
      ),
      manualUpdatedAt: _parseDateTimeAttr(
        node.attributes[_manualUpdatedAtAttr],
      ),
      favoriteUpdatedAt: _parseDateTimeAttr(
        node.attributes[_favoriteUpdatedAtAttr],
      ),
      displayNameUpdatedAt: _parseDateTimeAttr(
        node.attributes[_displayNameUpdatedAtAttr],
      ),
      folderRuleUpdatedAt: _parseDateTimeAttr(
        node.attributes[_folderRuleUpdatedAtAttr],
      ),
      sourceId: _normalizeSourceId(node.attributes[_sourceIdAttr]?.toString()),
      fields: node.children
          .map(ContactSyncFieldPayload.fromXml)
          .whereType<ContactSyncFieldPayload>()
          .toList(growable: false),
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
      tag: _contactTag,
      xmlns: contactsPubSubNode,
      attributes: {
        _addressKeyAttr: addressKey,
        _activeAttr: active ? '1' : '0',
        _manualAttr: manual ? '1' : '0',
        _favoriteAttr: favorited ? '1' : '0',
        _displayOverrideAttr: ?displayNameOverride,
        _folderCollectionIdAttr: ?folderCollectionId,
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _activeUpdatedAtAttr: ?activeUpdatedAt?.toUtc().toIso8601String(),
        _manualUpdatedAtAttr: ?manualUpdatedAt?.toUtc().toIso8601String(),
        _favoriteUpdatedAtAttr: ?favoriteUpdatedAt?.toUtc().toIso8601String(),
        _displayNameUpdatedAtAttr: ?displayNameUpdatedAt
            ?.toUtc()
            .toIso8601String(),
        _folderRuleUpdatedAtAttr: ?folderRuleUpdatedAt
            ?.toUtc()
            .toIso8601String(),
        _sourceIdAttr: sourceId,
      },
      children: fields.map((field) => field.toXml()).toList(growable: false),
    );
  }
}

final class ContactSyncUpdatedEvent extends mox.XmppEvent {
  ContactSyncUpdatedEvent(this.payload);

  final ContactSyncPayload payload;
}

final class ContactsPubSubManager
    extends PepItemPubSubNodeManager<ContactSyncPayload>
    implements PubSubHubDelegate {
  ContactsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.contacts';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    messageCollectionSyncRateLimit,
  );

  @override
  String get nodeId => contactsPubSubNode;

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
  XmppOperationKind? get operationKind => null;

  @override
  bool get refreshOnRetractionEvent => true;

  @override
  bool get rebuildNodeOnPurge => false;

  @override
  bool get emitRetractionsOnClear => false;

  @override
  bool get emitRetractionsFromCompleteSnapshot => false;

  Future<bool> publishEntry(ContactSyncPayload payload) => publishItem(payload);

  @override
  ContactSyncPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      ContactSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(ContactSyncPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(ContactSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(ContactSyncPayload payload) {
    getAttributes().sendEvent(ContactSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {}
}

DateTime? _parseDateTimeAttr(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return DateTime.tryParse(normalized)?.toUtc();
}

String? _normalizeFieldValue(String? value, {required int maxBytes}) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return clampUtf8Value(normalized, maxBytes: maxBytes);
}

String? _normalizeCollectionId(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  if (!isWithinUtf8ByteLimit(normalized, maxBytes: 128)) {
    return null;
  }
  return normalized;
}

int? _parsePositiveIntAttr(Object? value) {
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

bool? _parseBoolAttr(Object? value) {
  final normalized = value?.toString().trim().toLowerCase();
  return switch (normalized) {
    '1' || 'true' => true,
    '0' || 'false' => false,
    _ => null,
  };
}

String _normalizeSourceId(String? value) {
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
