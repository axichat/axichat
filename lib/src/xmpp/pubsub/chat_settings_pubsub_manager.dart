// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/message_content_limits.dart';
import 'package:axichat/src/common/sync_rate_limiter.dart';
import 'package:axichat/src/storage/models.dart';
import 'package:axichat/src/xmpp/pubsub/pep_item_pubsub_node_manager.dart';
import 'package:axichat/src/xmpp/pubsub/pubsub_hub_manager.dart';
import 'package:axichat/src/xmpp/xmpp_operation_events.dart';
import 'package:crypto/crypto.dart' as crypto;
import 'package:moxxmpp/moxxmpp.dart' as mox;

const String chatSettingsPubSubNode = 'urn:axi:chat-settings';
const String chatSettingsNotifyFeature = 'urn:axi:chat-settings+notify';
const int chatSettingsSyncMaxItems = 1000;
const int chatSettingsSyncMaxPayloadBytes = 32 * 1024;
const int chatSettingsSyncSourceIdMaxBytes = 128;

const String _chatSettingsTag = 'chat-settings';
const String _chatSettingsDataTag = 'data';
const String _addressAttr = 'address';
const String _updatedAtAttr = 'updated_at';
const String _sourceIdAttr = 'source_id';
const String _defaultMaxItems = '$chatSettingsSyncMaxItems';
const String _sourceIdFallback = 'legacy';
const Duration _ensureNodeBackoff = Duration(minutes: 5);
const String _bootstrapOperationName =
    'ChatSettingsPubSubManager.bootstrapOnNegotiations';
const String _refreshOperationName =
    'ChatSettingsPubSubManager.refreshFromServer';

final class ChatSettingsSyncPayload {
  const ChatSettingsSyncPayload({
    required this.addressKey,
    required this.settings,
    required this.updatedAt,
    required this.sourceId,
  });

  final String addressKey;
  final Map<String, dynamic> settings;
  final DateTime updatedAt;
  final String sourceId;

  String get itemId => itemIdFor(addressKey: addressKey);

  String? get encodedSettings => encodeSettingsData(settings);

  static String itemIdFor({required String addressKey}) {
    final digest = crypto.sha256.convert(utf8.encode(addressKey));
    return 'chat-settings:$digest';
  }

  static String? encodeSettingsData(Object? raw) {
    final normalized = normalizeSettingsData(raw);
    if (normalized == null) {
      return null;
    }
    final encoded = jsonEncode(normalized);
    if (!isWithinUtf8ByteLimit(
      encoded,
      maxBytes: chatSettingsSyncMaxPayloadBytes,
    )) {
      return null;
    }
    return encoded;
  }

  static Map<String, dynamic>? decodeSettingsData(String? raw) {
    final normalized = raw?.trim();
    if (normalized == null || normalized.isEmpty) {
      return const <String, dynamic>{};
    }
    if (!isWithinUtf8ByteLimit(
      normalized,
      maxBytes: chatSettingsSyncMaxPayloadBytes,
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
    final settings = <String, dynamic>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      final settingId = settingIdForKey(key);
      if (settingId == null) {
        continue;
      }
      if (entry.value == null) {
        settings[key] = null;
        continue;
      }
      final value = _normalizeSettingValue(settingId, entry.value);
      if (value != null) {
        settings[key] = value;
      }
    }
    return Map<String, dynamic>.unmodifiable(settings);
  }

  static ChatSettingsSyncPayload? fromChat(
    Chat chat, {
    Set<ChatSettingId> clearedSettings = const <ChatSettingId>{},
  }) {
    final addressKey = normalizedAddressKey(chat.jid);
    if (addressKey == null || addressKey.isEmpty) {
      return null;
    }
    final updatedAt = chat.chatSettingsUpdatedAt;
    final sourceId = chat.chatSettingsSourceId?.trim();
    if (updatedAt == null || sourceId == null || sourceId.isEmpty) {
      return null;
    }
    final settings = <String, dynamic>{...chat.chatSettingsSyncJson};
    for (final settingId in clearedSettings) {
      settings[settingId.syncKey] = null;
    }
    return ChatSettingsSyncPayload(
      addressKey: addressKey,
      settings: settings,
      updatedAt: updatedAt.toUtc(),
      sourceId: sourceId,
    );
  }

  static ChatSettingsSyncPayload? fromXml(mox.XMLNode node, {String? itemId}) {
    if (node.tag != _chatSettingsTag) {
      return null;
    }
    if (node.attributes['xmlns']?.toString() != chatSettingsPubSubNode) {
      return null;
    }
    final addressKey = normalizedAddressKey(
      node.attributes[_addressAttr]?.toString(),
    );
    final rawUpdatedAt = node.attributes[_updatedAtAttr]?.toString().trim();
    if (addressKey == null || addressKey.isEmpty || rawUpdatedAt == null) {
      return null;
    }
    final updatedAt = DateTime.tryParse(rawUpdatedAt)?.toUtc();
    if (updatedAt == null) {
      return null;
    }
    final settings = decodeSettingsData(
      node.firstTag(_chatSettingsDataTag)?.innerText(),
    );
    if (settings == null) {
      return null;
    }
    final payload = ChatSettingsSyncPayload(
      addressKey: addressKey,
      settings: settings,
      updatedAt: updatedAt,
      sourceId: _normalizeSourceId(node.attributes[_sourceIdAttr]?.toString()),
    );
    final resolvedItemId = itemId?.trim();
    if (resolvedItemId != null &&
        resolvedItemId.isNotEmpty &&
        resolvedItemId != payload.itemId) {
      return null;
    }
    return payload;
  }

  mox.XMLNode toXml() {
    final encodedSettings = encodeSettingsData(settings);
    if (encodedSettings == null) {
      throw StateError('Chat settings sync payload is not serializable.');
    }
    return mox.XMLNode.xmlns(
      tag: _chatSettingsTag,
      xmlns: chatSettingsPubSubNode,
      attributes: {
        _addressAttr: addressKey,
        _updatedAtAttr: updatedAt.toUtc().toIso8601String(),
        _sourceIdAttr: _normalizeSourceId(sourceId),
      },
      children: [mox.XMLNode(tag: _chatSettingsDataTag, text: encodedSettings)],
    );
  }

  Chat applyToChat(Chat chat) {
    var next = chat;
    for (final entry in settings.entries) {
      final settingId = settingIdForKey(entry.key);
      if (settingId == null) {
        continue;
      }
      next = settingId.applySyncedValue(
        next,
        entry.value,
        updatedAt: updatedAt.toUtc(),
        sourceId: sourceId,
      );
    }
    return next;
  }

  static ChatSettingId? settingIdForKey(String key) {
    for (final settingId in ChatSettingId.syncedSettings) {
      if (settingId.syncKey == key) {
        return settingId;
      }
    }
    return null;
  }

  static Object? _normalizeSettingValue(
    ChatSettingId settingId,
    Object? value,
  ) {
    return switch (settingId) {
      ChatSettingId.attachmentAutoDownload => switch (value?.toString()) {
        'allowed' => AttachmentAutoDownload.allowed.name,
        'blocked' => AttachmentAutoDownload.blocked.name,
        _ => null,
      },
      ChatSettingId.notificationPreview => switch (value?.toString()) {
        'show' => NotificationPreviewSetting.show.name,
        'hide' => NotificationPreviewSetting.hide.name,
        _ => null,
      },
      ChatSettingId.notificationBehavior => switch (value?.toString()) {
        'muted' => ChatNotificationBehavior.muted.name,
        'alwaysNotify' => ChatNotificationBehavior.alwaysNotify.name,
        _ => null,
      },
      _ => value is bool ? value : null,
    };
  }

  static String _normalizeSourceId(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return _sourceIdFallback;
    }
    final clamped = clampUtf8Value(
      trimmed,
      maxBytes: chatSettingsSyncSourceIdMaxBytes,
    );
    if (clamped == null || clamped.trim().isEmpty) {
      return _sourceIdFallback;
    }
    return clamped;
  }
}

sealed class ChatSettingsSyncUpdate {
  const ChatSettingsSyncUpdate();
}

final class ChatSettingsSyncUpdated extends ChatSettingsSyncUpdate {
  const ChatSettingsSyncUpdated(this.payload);

  final ChatSettingsSyncPayload payload;
}

final class ChatSettingsSyncRetracted extends ChatSettingsSyncUpdate {
  const ChatSettingsSyncRetracted(this.itemId);

  final String itemId;
}

final class ChatSettingsSyncUpdatedEvent extends mox.XmppEvent {
  ChatSettingsSyncUpdatedEvent(this.payload);

  final ChatSettingsSyncPayload payload;
}

final class ChatSettingsSyncRetractedEvent extends mox.XmppEvent {
  ChatSettingsSyncRetractedEvent(this.itemId);

  final String itemId;
}

final class ChatSettingsPubSubManager
    extends PepItemPubSubNodeManager<ChatSettingsSyncPayload>
    implements PubSubHubDelegate {
  ChatSettingsPubSubManager({String? maxItems})
    : _maxItems = maxItems ?? _defaultMaxItems,
      super(managerId);

  static const String managerId = 'axi.chat.settings';

  final String _maxItems;

  @override
  final SyncRateLimiter rateLimiter = SyncRateLimiter(settingsSyncRateLimit);

  final StreamController<ChatSettingsSyncUpdate> _updatesController =
      StreamController<ChatSettingsSyncUpdate>.broadcast();

  Stream<ChatSettingsSyncUpdate> get updates => _updatesController.stream;

  @override
  String get nodeId => chatSettingsPubSubNode;

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

  Future<bool> publishSettings(ChatSettingsSyncPayload payload) =>
      publishItem(payload);

  @override
  ChatSettingsSyncPayload? parsePayload(
    mox.XMLNode payload, {
    String? itemId,
  }) => ChatSettingsSyncPayload.fromXml(payload, itemId: itemId);

  @override
  String itemIdOf(ChatSettingsSyncPayload payload) => payload.itemId;

  @override
  mox.XMLNode payloadToXml(ChatSettingsSyncPayload payload) => payload.toXml();

  @override
  void emitUpdatePayload(ChatSettingsSyncPayload payload) {
    if (!_updatesController.isClosed) {
      _updatesController.add(ChatSettingsSyncUpdated(payload));
    }
    getAttributes().sendEvent(ChatSettingsSyncUpdatedEvent(payload));
  }

  @override
  void emitRetractionId(String itemId) {
    if (!_updatesController.isClosed) {
      _updatesController.add(ChatSettingsSyncRetracted(itemId));
    }
    getAttributes().sendEvent(ChatSettingsSyncRetractedEvent(itemId));
  }
}
