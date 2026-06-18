// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/common/xml_safety.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String calendarSnapshotPubSubNode = 'urn:axi:calendar:personal';
const String calendarSnapshotNotifyFeature = 'urn:axi:calendar:personal+notify';

const int calendarSnapshotPubSubMaxItems = 1;
const int calendarSnapshotPubSubMaxPayloadBytes = 256 * 1024;
const int calendarSnapshotPubSubSourceIdMaxBytes = 128;

const String _calendarTag = 'calendar';
const String _snapshotTag = 'snapshot';
const String _updatedAtAttr = 'updated_at';
const String _sourceIdAttr = 'source_id';
const String _checksumAttr = 'checksum';
const String _versionAttr = 'version';
const String _encodingAttr = 'encoding';
const String _snapshotEncoding = 'gzip+base64';
const String _currentItemId = 'current';
const String _defaultMaxItems = '$calendarSnapshotPubSubMaxItems';
const String _sourceIdFallback = 'legacy';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _bootstrapOperationName =
    'CalendarSnapshotPubSubManager.bootstrapOnNegotiations';
const String _refreshOperationName =
    'CalendarSnapshotPubSubManager.refreshFromServer';

final class PersonalCalendarSnapshotPubSubPayload {
  const PersonalCalendarSnapshotPubSubPayload({
    required this.model,
    required this.updatedAt,
    required this.sourceId,
    required this.checksum,
    required this.version,
    required this.encodedSnapshot,
  });

  static const String currentItemId = _currentItemId;

  final CalendarModel model;
  final DateTime updatedAt;
  final String sourceId;
  final String checksum;
  final int version;
  final String encodedSnapshot;

  String get itemId => _currentItemId;

  static Future<PersonalCalendarSnapshotPubSubPayload?> create({
    required CalendarModel model,
    required DateTime updatedAt,
    required String sourceId,
  }) async {
    final bytes = await CalendarSnapshotCodec.encodeAsync(model);
    final encoded = base64Encode(bytes);
    if (!isWithinUtf8ByteLimit(
      encoded,
      maxBytes: calendarSnapshotPubSubMaxPayloadBytes,
    )) {
      return null;
    }
    final decoded = CalendarSnapshotCodec.decode(bytes);
    if (decoded == null) {
      return null;
    }
    return PersonalCalendarSnapshotPubSubPayload(
      model: decoded.model,
      updatedAt: updatedAt.toUtc(),
      sourceId: _normalizeSourceId(sourceId),
      checksum: decoded.checksum,
      version: decoded.version,
      encodedSnapshot: encoded,
    );
  }

  static PersonalCalendarSnapshotPubSubPayload? fromXml(
    mox.XMLNode node, {
    String? itemId,
  }) {
    if (node.tag != _calendarTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != calendarSnapshotPubSubNode) {
      return null;
    }
    final resolvedItemId = itemId?.trim();
    if (resolvedItemId != null &&
        resolvedItemId.isNotEmpty &&
        resolvedItemId != _currentItemId) {
      return null;
    }
    final rawUpdatedAt = node.attributes[_updatedAtAttr]?.toString().trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) {
      return null;
    }
    final updatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (updatedAt == null) {
      return null;
    }
    final rawVersion = node.attributes[_versionAttr]?.toString().trim();
    final version = rawVersion == null ? null : int.tryParse(rawVersion);
    if (version == null || version > CalendarSnapshotCodec.currentVersion) {
      return null;
    }
    final checksum = node.attributes[_checksumAttr]?.toString().trim();
    if (checksum == null || checksum.isEmpty) {
      return null;
    }
    final snapshotNode = node.firstTag(_snapshotTag);
    if (snapshotNode == null ||
        snapshotNode.attributes[_encodingAttr]?.toString() !=
            _snapshotEncoding) {
      return null;
    }
    final encodedSnapshot = snapshotNode.innerText().trim();
    if (!isWithinUtf8ByteLimit(
      encodedSnapshot,
      maxBytes: calendarSnapshotPubSubMaxPayloadBytes,
    )) {
      return null;
    }
    final Uint8List snapshotBytes;
    try {
      snapshotBytes = base64Decode(encodedSnapshot);
    } on FormatException {
      return null;
    }
    final decoded = CalendarSnapshotCodec.decode(snapshotBytes);
    if (decoded == null ||
        decoded.version != version ||
        decoded.checksum != checksum ||
        !CalendarSnapshotCodec.verifyChecksum(decoded)) {
      return null;
    }
    return PersonalCalendarSnapshotPubSubPayload(
      model: decoded.model,
      updatedAt: updatedAt,
      sourceId: _normalizeSourceId(node.attributes[_sourceIdAttr]?.toString()),
      checksum: checksum,
      version: version,
      encodedSnapshot: encodedSnapshot,
    );
  }

  mox.XMLNode toXml() {
    if (!isWithinUtf8ByteLimit(
      encodedSnapshot,
      maxBytes: calendarSnapshotPubSubMaxPayloadBytes,
    )) {
      throw StateError('Calendar snapshot PubSub payload is too large.');
    }
    return mox.XMLNode.xmlns(
      tag: _calendarTag,
      xmlns: calendarSnapshotPubSubNode,
      attributes: {
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _sourceIdAttr: escapeXmlAttribute(_normalizeSourceId(sourceId)),
        _checksumAttr: escapeXmlAttribute(checksum),
        _versionAttr: version.toString(),
      },
      children: [
        mox.XMLNode(
          tag: _snapshotTag,
          attributes: const {_encodingAttr: _snapshotEncoding},
          text: escapeXmlText(encodedSnapshot),
        ),
      ],
    );
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _sourceIdFallback;
    }
    final clamped = clampUtf8Value(
      trimmed,
      maxBytes: calendarSnapshotPubSubSourceIdMaxBytes,
    );
    if (clamped == null || clamped.trim().isEmpty) {
      return _sourceIdFallback;
    }
    return clamped;
  }
}

sealed class PersonalCalendarSnapshotPubSubUpdate {
  const PersonalCalendarSnapshotPubSubUpdate();
}

final class PersonalCalendarSnapshotPubSubUpdated
    extends PersonalCalendarSnapshotPubSubUpdate {
  const PersonalCalendarSnapshotPubSubUpdated(this.payload);

  final PersonalCalendarSnapshotPubSubPayload payload;
}

final class PersonalCalendarSnapshotPubSubRetracted
    extends PersonalCalendarSnapshotPubSubUpdate {
  const PersonalCalendarSnapshotPubSubRetracted(this.itemId);

  final String itemId;
}

final class PersonalCalendarSnapshotPubSubUpdatedEvent extends mox.XmppEvent {
  PersonalCalendarSnapshotPubSubUpdatedEvent(this.payload);

  final PersonalCalendarSnapshotPubSubPayload payload;
}

final class PersonalCalendarSnapshotPubSubRetractedEvent extends mox.XmppEvent {
  PersonalCalendarSnapshotPubSubRetractedEvent(this.itemId);

  final String itemId;
}

final class CalendarSnapshotPubSubManager
    extends PepItemPubSubNodeManager<PersonalCalendarSnapshotPubSubPayload>
    implements PubSubHubDelegate {
  CalendarSnapshotPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.calendar.snapshot';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(
    calendarSnapshotSyncRateLimit,
  );

  final StreamController<PersonalCalendarSnapshotPubSubUpdate>
  _updatesController =
      StreamController<PersonalCalendarSnapshotPubSubUpdate>.broadcast();

  Stream<PersonalCalendarSnapshotPubSubUpdate> get updates =>
      _updatesController.stream;

  @override
  String get nodeId => calendarSnapshotPubSubNode;

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
  XmppOperationKind get operationKind =>
      XmppOperationKind.pubSubCalendarSnapshot;

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

  Future<bool> publishSnapshot(PersonalCalendarSnapshotPubSubPayload payload) =>
      publishItem(payload);

  @override
  PersonalCalendarSnapshotPubSubPayload? parsePayload(
    mox.XMLNode payload, {
    String? itemId,
  }) => PersonalCalendarSnapshotPubSubPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(PersonalCalendarSnapshotPubSubPayload payload) =>
      payload.itemId;

  @override
  mox.XMLNode payloadToXml(PersonalCalendarSnapshotPubSubPayload payload) =>
      payload.toXml();

  @override
  void emitUpdatePayload(PersonalCalendarSnapshotPubSubPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(PersonalCalendarSnapshotPubSubUpdated(payload));
    }
    getAttributes().sendEvent(
      PersonalCalendarSnapshotPubSubUpdatedEvent(payload),
    );
  }

  @override
  void emitRetractionId(String itemId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(PersonalCalendarSnapshotPubSubRetracted(itemId));
    }
    getAttributes().sendEvent(
      PersonalCalendarSnapshotPubSubRetractedEvent(itemId),
    );
  }
}
