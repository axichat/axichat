// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/anti_abuse_sync.dart';
import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String spamPubSubNode = 'urn:axi:spam';
const String spamNotifyFeature = 'urn:axi:spam+notify';

const int spamSyncMaxItems = 500;

const String _spamTag = 'spam';
const String _spamJidAttr = 'jid';
const String _spamUpdatedAtAttr = 'updated_at';
const String _spamSourceIdAttr = 'source_id';
const String _defaultMaxItems = '$spamSyncMaxItems';
const String _spamSourceIdFallback = syncLegacySourceId;
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _spamPubSubBootstrapOperationName =
    'SpamPubSubManager.bootstrapOnNegotiations';
const String _spamPubSubRefreshOperationName =
    'SpamPubSubManager.refreshFromServer';

final class SpamSyncPayload {
  const SpamSyncPayload({
    required this.jid,
    required this.updatedAt,
    required this.sourceId,
  });

  final String jid;
  final DateTime updatedAt;
  final String sourceId;

  String get itemId => jid;

  SpamSyncPayload copyWith({
    String? jid,
    DateTime? updatedAt,
    String? sourceId,
  }) {
    return SpamSyncPayload(
      jid: jid ?? this.jid,
      updatedAt: updatedAt ?? this.updatedAt,
      sourceId: sourceId ?? this.sourceId,
    );
  }

  static SpamSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _spamTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != spamPubSubNode) {
      return null;
    }

    final rawJid = node.attributes[_spamJidAttr]?.toString();
    final resolvedJid = rawJid == null || rawJid.isEmpty
        ? itemId?.trim()
        : rawJid;
    if (resolvedJid == null || resolvedJid.isEmpty) {
      return null;
    }
    final normalizedJid = resolvedJid.toBareJidOrNull(
      maxBytes: syncAddressMaxBytes,
    );
    if (normalizedJid == null) {
      return null;
    }

    final rawUpdatedAt = node.attributes[_spamUpdatedAtAttr]?.toString().trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt);
    if (parsedUpdatedAt == null) {
      return null;
    }

    final rawSourceId = node.attributes[_spamSourceIdAttr]?.toString().trim();
    final resolvedSourceId = _normalizeSourceId(rawSourceId);

    return SpamSyncPayload(
      jid: normalizedJid,
      updatedAt: parsedUpdatedAt.toUtc(),
      sourceId: resolvedSourceId,
    );
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _spamTag,
      xmlns: spamPubSubNode,
      attributes: {
        _spamJidAttr: jid,
        _spamUpdatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _spamSourceIdAttr: sourceId,
      },
    );
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _spamSourceIdFallback;
    }
    final clamped = clampUtf8Value(trimmed, maxBytes: syncSourceIdMaxBytes);
    if (clamped == null || clamped.trim().isEmpty) {
      return _spamSourceIdFallback;
    }
    return clamped;
  }
}

sealed class SpamSyncUpdate {
  const SpamSyncUpdate();
}

final class SpamSyncUpdated extends SpamSyncUpdate {
  const SpamSyncUpdated(this.payload);

  final SpamSyncPayload payload;
}

final class SpamSyncRetracted extends SpamSyncUpdate {
  const SpamSyncRetracted(this.jid);

  final String jid;
}

final class SpamSyncUpdatedEvent extends mox.XmppEvent {
  SpamSyncUpdatedEvent(this.payload);

  final SpamSyncPayload payload;
}

final class SpamSyncRetractedEvent extends mox.XmppEvent {
  SpamSyncRetractedEvent(this.jid);

  final String jid;
}

final class SpamPubSubManager extends PepItemPubSubNodeManager<SpamSyncPayload>
    implements PubSubHubDelegate {
  SpamPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.spam';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(spamSyncRateLimit);

  final StreamController<SpamSyncUpdate> _updatesController =
      StreamController<SpamSyncUpdate>.broadcast();

  Stream<SpamSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => spamPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _spamPubSubBootstrapOperationName;

  @override
  String get refreshOperationName => _spamPubSubRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubSpam;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  Future<bool> publishSpam(SpamSyncPayload payload) => publishItem(payload);

  Future<bool> retractSpam(String jid) => retractItem(jid);

  @override
  SpamSyncPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      SpamSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(SpamSyncPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(SpamSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(SpamSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(SpamSyncUpdated(payload));
    }
    getAttributes().sendEvent(SpamSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String jid) {
    if (!_updatesController.isClosed) {
      _updatesController.add(SpamSyncRetracted(jid));
    }
    getAttributes().sendEvent(SpamSyncRetractedEvent(jid));
  }
}
