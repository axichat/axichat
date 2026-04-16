// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String homeBadgeMarkersPubSubNode = 'urn:axi:home-badge-markers';
const String homeBadgeMarkersNotifyFeature =
    'urn:axi:home-badge-markers+notify';

const int homeBadgeMarkersSyncMaxItems = 3;

const String _homeBadgeMarkerTag = 'home-badge-marker';
const String _homeBadgeBucketAttr = 'bucket';
const String _homeBadgeSeenAtAttr = 'seen_at';
const String _defaultMaxItems = '$homeBadgeMarkersSyncMaxItems';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _homeBadgeMarkersBootstrapOperationName =
    'HomeBadgeMarkersPubSubManager.bootstrapOnNegotiations';
const String _homeBadgeMarkersRefreshOperationName =
    'HomeBadgeMarkersPubSubManager.refreshFromServer';

enum HomeBadgeBucket {
  drafts,
  important,
  spam;

  String get itemId => switch (this) {
    HomeBadgeBucket.drafts => 'drafts',
    HomeBadgeBucket.important => 'important',
    HomeBadgeBucket.spam => 'spam',
  };

  static HomeBadgeBucket? fromItemId(String? value) {
    final normalized = value?.trim();
    return switch (normalized) {
      'drafts' => HomeBadgeBucket.drafts,
      'important' => HomeBadgeBucket.important,
      'spam' => HomeBadgeBucket.spam,
      _ => null,
    };
  }
}

final class HomeBadgeMarkerPayload {
  const HomeBadgeMarkerPayload({required this.bucket, required this.seenAt});

  final HomeBadgeBucket bucket;
  final DateTime seenAt;

  String get itemId => bucket.itemId;

  @override
  bool operator ==(Object other) {
    return other is HomeBadgeMarkerPayload &&
        other.bucket == bucket &&
        other.seenAt == seenAt;
  }

  @override
  int get hashCode => Object.hash(bucket, seenAt);

  static HomeBadgeMarkerPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _homeBadgeMarkerTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != homeBadgeMarkersPubSubNode) {
      return null;
    }

    final bucket = HomeBadgeBucket.fromItemId(
      node.attributes[_homeBadgeBucketAttr]?.toString() ?? itemId,
    );
    if (bucket == null) {
      return null;
    }

    final rawSeenAt = node.attributes[_homeBadgeSeenAtAttr]?.toString().trim();
    final parsedSeenAt = rawSeenAt == null || rawSeenAt.isEmpty
        ? null
        : DateTime.tryParse(rawSeenAt)?.toUtc();
    if (parsedSeenAt == null) {
      return null;
    }

    return HomeBadgeMarkerPayload(bucket: bucket, seenAt: parsedSeenAt);
  }

  mox.XMLNode toXml() {
    return mox.XMLNode.xmlns(
      tag: _homeBadgeMarkerTag,
      xmlns: homeBadgeMarkersPubSubNode,
      attributes: <String, String>{
        _homeBadgeBucketAttr: bucket.itemId,
        _homeBadgeSeenAtAttr: seenAt.toUtc().toIso8601String(),
      },
    );
  }
}

sealed class HomeBadgeMarkerSyncUpdate {
  const HomeBadgeMarkerSyncUpdate();
}

final class HomeBadgeMarkerSyncUpdated extends HomeBadgeMarkerSyncUpdate {
  const HomeBadgeMarkerSyncUpdated(this.payload);

  final HomeBadgeMarkerPayload payload;
}

final class HomeBadgeMarkerSyncRetracted extends HomeBadgeMarkerSyncUpdate {
  const HomeBadgeMarkerSyncRetracted(this.bucket);

  final HomeBadgeBucket bucket;
}

final class HomeBadgeMarkerSyncUpdatedEvent extends mox.XmppEvent {
  HomeBadgeMarkerSyncUpdatedEvent(this.payload);

  final HomeBadgeMarkerPayload payload;
}

final class HomeBadgeMarkerSyncRetractedEvent extends mox.XmppEvent {
  HomeBadgeMarkerSyncRetractedEvent(this.bucket);

  final HomeBadgeBucket bucket;
}

final class HomeBadgeMarkersPubSubManager
    extends PepItemPubSubNodeManager<HomeBadgeMarkerPayload>
    implements PubSubHubDelegate {
  HomeBadgeMarkersPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.home-badge-markers';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(settingsSyncRateLimit);

  final StreamController<HomeBadgeMarkerSyncUpdate> _updatesController =
      StreamController<HomeBadgeMarkerSyncUpdate>.broadcast();

  Stream<HomeBadgeMarkerSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => homeBadgeMarkersPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _homeBadgeMarkersBootstrapOperationName;

  @override
  String get refreshOperationName => _homeBadgeMarkersRefreshOperationName;

  @override
  XmppOperationKind get operationKind => XmppOperationKind.pubSubFetch;

  @override
  Future<void> close() async {
    if (_updatesController.isClosed) {
      return;
    }
    await _updatesController.close();
  }

  Future<bool> publishHomeBadgeMarker(HomeBadgeMarkerPayload payload) =>
      publishItem(payload);

  Future<bool> retractHomeBadgeMarker(HomeBadgeBucket bucket) =>
      retractItem(bucket.itemId);

  @override
  HomeBadgeMarkerPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      HomeBadgeMarkerPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(HomeBadgeMarkerPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(HomeBadgeMarkerPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(HomeBadgeMarkerPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(HomeBadgeMarkerSyncUpdated(payload));
    }
    getAttributes().sendEvent(HomeBadgeMarkerSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    final bucket = HomeBadgeBucket.fromItemId(itemId);
    if (bucket == null) {
      return;
    }
    if (!_updatesController.isClosed) {
      _updatesController.add(HomeBadgeMarkerSyncRetracted(bucket));
    }
    getAttributes().sendEvent(HomeBadgeMarkerSyncRetractedEvent(bucket));
  }
}
