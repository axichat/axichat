// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String addressBlockPubSubNode = 'urn:axi:address-blocklist';
const String addressBlockNotifyFeature = 'urn:axi:address-blocklist+notify';

const int addressBlockSyncMaxItems = 500;

const String _blockTag = 'block';
const String _blockAddressAttr = 'address';
const String _blockUpdatedAtAttr = 'updated_at';
const String _blockSourceIdAttr = 'source_id';
const String _defaultMaxItems = '$addressBlockSyncMaxItems';
const String _blockSourceIdFallback = syncLegacySourceId;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _addressBlockBootstrapOperationName =
    'AddressBlockPubSubManager.bootstrapOnNegotiations';
const String _addressBlockRefreshOperationName =
    'AddressBlockPubSubManager.refreshFromServer';

final class AddressBlockSyncPayload {
  const AddressBlockSyncPayload({
    required this.address,
    required this.updatedAt,
    required this.sourceId,
  });

  final String address;
  final DateTime updatedAt;
  final String sourceId;

  String get itemId => address;

  AddressBlockSyncPayload copyWith({
    String? address,
    DateTime? updatedAt,
    String? sourceId,
  }) {
    return AddressBlockSyncPayload(
      address: address ?? this.address,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  static AddressBlockSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _blockTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != addressBlockPubSubNode) {
      return null;
    }

    final rawAddress = node.attributes[_blockAddressAttr]?.toString();
    final resolvedAddress = rawAddress == null || rawAddress.isEmpty
        ? itemId?.trim()
        : rawAddress;
    if (resolvedAddress == null || resolvedAddress.isEmpty) {
      return null;
    }
    final normalizedAddress = resolvedAddress.toBareJidOrNull(
      maxBytes: syncAddressMaxBytes,
    );
    if (normalizedAddress == null) {
      return null;
    }

    final rawUpdatedAt = node.attributes[_blockUpdatedAtAttr]
        ?.toString()
        .trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null) {
      return null;
    }

    final rawSourceId = node.attributes[_blockSourceIdAttr]?.toString().trim();
    final resolvedSourceId = _normalizeSourceId(rawSourceId);

    return AddressBlockSyncPayload(
      address: normalizedAddress,
      updatedAt: parsedUpdatedAt.toUtc(),
      sourceId: resolvedSourceId,
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _blockTag,
      xmlns: addressBlockPubSubNode,
      attributes: {
        _blockAddressAttr: address,
        _blockUpdatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _blockSourceIdAttr: sourceId,
      },
    );
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _blockSourceIdFallback;
    }
    final clamped = clampUtf8Value(trimmed, maxBytes: syncSourceIdMaxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return _blockSourceIdFallback;
    }
    return clamped;
  }
}

sealed class AddressBlockSyncUpdate {
  const AddressBlockSyncUpdate();
}

final class AddressBlockSyncUpdated extends AddressBlockSyncUpdate {
  const AddressBlockSyncUpdated(this.payload);

  final AddressBlockSyncPayload payload;
}

final class AddressBlockSyncRetracted extends AddressBlockSyncUpdate {
  const AddressBlockSyncRetracted(this.address);

  final String address;
}

final class AddressBlockSyncUpdatedEvent extends mox.XmppEvent {
  AddressBlockSyncUpdatedEvent(this.payload);

  final AddressBlockSyncPayload payload;
}

final class AddressBlockSyncRetractedEvent extends mox.XmppEvent {
  AddressBlockSyncRetractedEvent(this.address);

  final String address;
}

final class AddressBlockPubSubManager
    extends PepItemPubSubNodeManager<AddressBlockSyncPayload>
    implements PubSubHubDelegate {
  AddressBlockPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.address_block';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    addressBlockSyncRateLimit,
  );

  final StreamController<AddressBlockSyncUpdate> _updatesController =
      StreamController<AddressBlockSyncUpdate>.broadcast();
  Stream<AddressBlockSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => addressBlockPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _addressBlockBootstrapOperationName;

  @override
  String get refreshOperationName => _addressBlockRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubAddressBlock;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  Future<bool> publishBlock(AddressBlockSyncPayload payload) =>
      publishItem(payload);

  Future<bool> retractBlock(String address) => retractItem(address);

  @override
  AddressBlockSyncPayload? parsePayload(
    mox.XMLNode payload, {
    String? itemId,
  }) => AddressBlockSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(AddressBlockSyncPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(AddressBlockSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(AddressBlockSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(AddressBlockSyncUpdated(payload));
    }
    getAttributes().sendEvent(AddressBlockSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String address) {
    if (!_updatesController.isClosed) {
      _updatesController.add(AddressBlockSyncRetracted(address));
    }
    getAttributes().sendEvent(AddressBlockSyncRetractedEvent(address));
  }
}
