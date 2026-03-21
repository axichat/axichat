// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String settingsPubSubNode = 'urn:axi:settings';
const String settingsNotifyFeature = 'urn:axi:settings+notify';

const int settingsSyncMaxItems = 1;
const int settingsSyncMaxPayloadBytes = 64 * 1024;
const int settingsSyncSourceIdMaxBytes = 128;

const String _settingsTag = 'settings';
const String _settingsDataTag = 'data';
const String _settingsUpdatedAtAttr = 'updated_at';
const String _settingsSourceIdAttr = 'source_id';
const String _settingsItemId = 'current';
const String _defaultMaxItems = '$settingsSyncMaxItems';
const String _settingsSourceIdFallback = 'legacy';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _settingsPubSubBootstrapOperationName =
    'SettingsPubSubManager.bootstrapOnNegotiations';
const String _settingsPubSubRefreshOperationName =
    'SettingsPubSubManager.refreshFromServer';

final class SettingsSyncPayload {
  const SettingsSyncPayload({
    required this.settings,
    required this.updatedAt,
    required this.sourceId,
  });

  static const String currentItemId = _settingsItemId;

  final Map<String, dynamic> settings;
  final DateTime updatedAt;
  final String sourceId;

  String get itemId => _settingsItemId;

  static String? encodeSettingsData(Object? raw) {
    final normalized = normalizeSettingsData(raw);
    if (normalized == null) {
      return null;
    }
    final encoded = jsonEncode(normalized);
    if (!isWithinUtf8ByteLimit(
      encoded,
      maxBytes: settingsSyncMaxPayloadBytes,
    )) {
      return null;
    }
    return encoded;
  }

  static Map<String, dynamic>? decodeSettingsData(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    if (!isWithinUtf8ByteLimit(
      normalized,
      maxBytes: settingsSyncMaxPayloadBytes,
    )) {
      return null;
    }
    try {
      return normalizeSettingsData(jsonDecode(normalized));
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic>? normalizeSettingsData(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    try {
      final decoded = jsonDecode(jsonEncode(raw));
      if (decoded is! Map) {
        return null;
      }
      return Map<String, dynamic>.unmodifiable(
        decoded.map((key, value) => MapEntry(key.toString(), value)),
      );
    } on JsonUnsupportedObjectError {
      return null;
    } on FormatException {
      return null;
    }
  }

  static SettingsSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _settingsTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != settingsPubSubNode) {
      return null;
    }
    final resolvedItemId = itemId?.trim();
    if (resolvedItemId != null &&
        resolvedItemId.isNotEmpty &&
        resolvedItemId != _settingsItemId) {
      return null;
    }

    final rawUpdatedAt = node.attributes[_settingsUpdatedAtAttr]
        ?.toString()
        .trim();
    if (rawUpdatedAt == null || rawUpdatedAt.isEmpty) {
      return null;
    }
    final parsedUpdatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (parsedUpdatedAt == null) {
      return null;
    }

    final rawSourceId = node.attributes[_settingsSourceIdAttr]?.toString();
    final resolvedSourceId = _normalizeSourceId(rawSourceId);

    final settings = decodeSettingsData(
      node.firstTag(_settingsDataTag)?.innerText(),
    );
    if (settings == null) {
      return null;
    }

    return SettingsSyncPayload(
      settings: settings,
      updatedAt: parsedUpdatedAt,
      sourceId: resolvedSourceId,
    );
  }

  mox.XMLNode toXml() {
    final encodedSettings = encodeSettingsData(settings);
    if (encodedSettings == null) {
      throw StateError('Settings sync payload is not serializable.');
    }
    return mox.XMLNode.xmlns(
      tag: _settingsTag,
      xmlns: settingsPubSubNode,
      attributes: {
        _settingsUpdatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _settingsSourceIdAttr: _normalizeSourceId(sourceId),
      },
      children: [mox.XMLNode(tag: _settingsDataTag, text: encodedSettings)],
    );
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _settingsSourceIdFallback;
    }
    final clamped = clampUtf8Value(
      trimmed,
      maxBytes: settingsSyncSourceIdMaxBytes,
    );
    if (clamped == null || clamped.trim().isEmpty) {
      return _settingsSourceIdFallback;
    }
    return clamped;
  }
}

sealed class SettingsSyncUpdate {
  const SettingsSyncUpdate();
}

final class SettingsSyncUpdated extends SettingsSyncUpdate {
  const SettingsSyncUpdated(this.payload);

  final SettingsSyncPayload payload;
}

final class SettingsSyncRetracted extends SettingsSyncUpdate {
  const SettingsSyncRetracted(this.itemId);

  final String itemId;
}

final class SettingsSyncUpdatedEvent extends mox.XmppEvent {
  SettingsSyncUpdatedEvent(this.payload);

  final SettingsSyncPayload payload;
}

final class SettingsSyncRetractedEvent extends mox.XmppEvent {
  SettingsSyncRetractedEvent(this.itemId);

  final String itemId;
}

final class SettingsPubSubManager
    extends PepItemPubSubNodeManager<SettingsSyncPayload>
    implements PubSubHubDelegate {
  SettingsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.settings';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(settingsSyncRateLimit);

  final StreamController<SettingsSyncUpdate> _updatesController =
      StreamController<SettingsSyncUpdate>.broadcast();

  Stream<SettingsSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => settingsPubSubNode;

  @override
  String get maxItemsValue => _maxItems;

  @override
  String get defaultMaxItemsValue => _defaultMaxItems;

  @override
  Duration get ensureNodeBackoff => _ensureNodeBackoff;

  @override
  String get bootstrapOperationName => _settingsPubSubBootstrapOperationName;

  @override
  String get refreshOperationName => _settingsPubSubRefreshOperationName;

  @override
  XmppOperationKind? get operationKind => null;

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

  Future<bool> publishSettings(SettingsSyncPayload payload) =>
      publishItem(payload);

  Future<bool> retractSettings() => retractItem(_settingsItemId);

  @override
  SettingsSyncPayload? parsePayload(mox.XMLNode payload, {String? itemId}) =>
      SettingsSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(SettingsSyncPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(SettingsSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(SettingsSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(SettingsSyncUpdated(payload));
    }
    getAttributes().sendEvent(SettingsSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(SettingsSyncRetracted(itemId));
    }
    getAttributes().sendEvent(SettingsSyncRetractedEvent(itemId));
  }
}
