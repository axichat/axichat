// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/storage/models/chat_models.dart';

const String _availabilityShareSourceTypeKey = 'type';
const String _availabilityShareSourceChatJidKey = 'chatJid';
const String _availabilityShareSourcePersonalValue = 'personal';
const String _availabilityShareSourceChatValue = 'chat';
const ChatType _availabilityShareDefaultChatType = ChatType.chat;

const String _availabilityShareRecordIdKey = 'id';
const String _availabilityShareRecordSourceKey = 'source';
const String _availabilityShareRecordChatJidKey = 'chatJid';
const String _availabilityShareRecordChatTypeKey = 'chatType';
const String _availabilityShareRecordOverlayKey = 'overlay';
const String _availabilityShareRecordUpdatedAtKey = 'updatedAt';
const String _availabilityShareRecordLockOverlayKey = 'lockOverlay';

const String _availabilityPresetIdKey = 'id';
const String _availabilityPresetOverlayKey = 'overlay';
const String _availabilityPresetNameKey = 'name';
const String _availabilityPresetUpdatedAtKey = 'updatedAt';

enum CalendarAvailabilityShareSourceType {
  personal,
  chat;

  bool get isPersonal => this == CalendarAvailabilityShareSourceType.personal;
  bool get isChat => this == CalendarAvailabilityShareSourceType.chat;

  String get storageValue => switch (this) {
        CalendarAvailabilityShareSourceType.personal =>
          _availabilityShareSourcePersonalValue,
        CalendarAvailabilityShareSourceType.chat =>
          _availabilityShareSourceChatValue,
      };

  static CalendarAvailabilityShareSourceType? fromStorageValue(String? value) =>
      switch (value) {
        _availabilityShareSourcePersonalValue =>
          CalendarAvailabilityShareSourceType.personal,
        _availabilityShareSourceChatValue =>
          CalendarAvailabilityShareSourceType.chat,
        _ => null,
      };
}

class CalendarAvailabilityShareSource {
  const CalendarAvailabilityShareSource.personal()
      : type = CalendarAvailabilityShareSourceType.personal,
        chatJid = null;

  const CalendarAvailabilityShareSource.chat({
    required this.chatJid,
  }) : type = CalendarAvailabilityShareSourceType.chat;

  final CalendarAvailabilityShareSourceType type;
  final String? chatJid;

  bool get isPersonal => type.isPersonal;
  bool get isChat => type.isChat;

  Map<String, dynamic> toJson() => {
        _availabilityShareSourceTypeKey: type.storageValue,
        if (chatJid != null) _availabilityShareSourceChatJidKey: chatJid,
      };

  static CalendarAvailabilityShareSource? fromJson(
    Map<String, dynamic> json,
  ) {
    final typeValue = json[_availabilityShareSourceTypeKey] as String?;
    final type = CalendarAvailabilityShareSourceType.fromStorageValue(
      typeValue,
    );
    if (type == null) {
      return null;
    }
    if (type.isPersonal) {
      return const CalendarAvailabilityShareSource.personal();
    }
    final chatJid = json[_availabilityShareSourceChatJidKey] as String?;
    if (chatJid == null || chatJid.trim().isEmpty) {
      return null;
    }
    return CalendarAvailabilityShareSource.chat(chatJid: chatJid);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarAvailabilityShareSource &&
      other.type == type &&
      other.chatJid == chatJid;

  @override
  int get hashCode => Object.hash(type, chatJid);
}

class CalendarAvailabilityShareRecord {
  CalendarAvailabilityShareRecord({
    required this.id,
    required this.source,
    required this.chatJid,
    required this.chatType,
    required this.overlay,
    this.lockOverlay = false,
    this.updatedAt,
  });

  final String id;
  final CalendarAvailabilityShareSource source;
  final String chatJid;
  final ChatType chatType;
  final CalendarAvailabilityOverlay overlay;
  final bool lockOverlay;
  final DateTime? updatedAt;

  CalendarAvailabilityShareRecord copyWith({
    String? id,
    CalendarAvailabilityShareSource? source,
    String? chatJid,
    ChatType? chatType,
    CalendarAvailabilityOverlay? overlay,
    bool? lockOverlay,
    DateTime? updatedAt,
  }) =>
      CalendarAvailabilityShareRecord(
        id: id ?? this.id,
        source: source ?? this.source,
        chatJid: chatJid ?? this.chatJid,
        chatType: chatType ?? this.chatType,
        overlay: overlay ?? this.overlay,
        lockOverlay: lockOverlay ?? this.lockOverlay,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        _availabilityShareRecordIdKey: id,
        _availabilityShareRecordSourceKey: source.toJson(),
        _availabilityShareRecordChatJidKey: chatJid,
        _availabilityShareRecordChatTypeKey: chatType.name,
        _availabilityShareRecordOverlayKey: overlay.toJson(),
        if (lockOverlay) _availabilityShareRecordLockOverlayKey: lockOverlay,
        if (updatedAt != null)
          _availabilityShareRecordUpdatedAtKey: updatedAt!.toIso8601String(),
      };

  static CalendarAvailabilityShareRecord? fromJson(
    Map<String, dynamic> json,
  ) {
    final id = json[_availabilityShareRecordIdKey] as String?;
    final sourceRaw = json[_availabilityShareRecordSourceKey];
    final chatJid = json[_availabilityShareRecordChatJidKey] as String?;
    final chatTypeValue = json[_availabilityShareRecordChatTypeKey] as String?;
    final overlayRaw = json[_availabilityShareRecordOverlayKey];
    final lockOverlay =
        json[_availabilityShareRecordLockOverlayKey] as bool? ?? false;
    if (id == null ||
        id.trim().isEmpty ||
        sourceRaw is! Map ||
        chatJid == null ||
        chatJid.trim().isEmpty ||
        overlayRaw is! Map) {
      return null;
    }
    final source = CalendarAvailabilityShareSource.fromJson(
      _normalizeJsonMap(sourceRaw),
    );
    if (source == null) {
      return null;
    }
    final overlay = CalendarAvailabilityOverlay.fromJson(
      _normalizeJsonMap(overlayRaw),
    );
    final chatType = _chatTypeFromString(chatTypeValue);
    final updatedAtValue =
        json[_availabilityShareRecordUpdatedAtKey] as String?;
    final updatedAt =
        updatedAtValue == null ? null : DateTime.tryParse(updatedAtValue);
    return CalendarAvailabilityShareRecord(
      id: id,
      source: source,
      chatJid: chatJid,
      chatType: chatType,
      overlay: overlay,
      lockOverlay: lockOverlay,
      updatedAt: updatedAt,
    );
  }
}

class CalendarAvailabilityPreset {
  CalendarAvailabilityPreset({
    required this.id,
    required this.overlay,
    this.name,
    this.updatedAt,
  });

  final String id;
  final CalendarAvailabilityOverlay overlay;
  final String? name;
  final DateTime? updatedAt;

  CalendarAvailabilityPreset copyWith({
    String? id,
    CalendarAvailabilityOverlay? overlay,
    String? name,
    DateTime? updatedAt,
  }) =>
      CalendarAvailabilityPreset(
        id: id ?? this.id,
        overlay: overlay ?? this.overlay,
        name: name ?? this.name,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        _availabilityPresetIdKey: id,
        _availabilityPresetOverlayKey: overlay.toJson(),
        if (name != null) _availabilityPresetNameKey: name,
        if (updatedAt != null)
          _availabilityPresetUpdatedAtKey: updatedAt!.toIso8601String(),
      };

  static CalendarAvailabilityPreset? fromJson(Map<String, dynamic> json) {
    final id = json[_availabilityPresetIdKey] as String?;
    final overlayRaw = json[_availabilityPresetOverlayKey];
    final name = json[_availabilityPresetNameKey] as String?;
    if (id == null || id.trim().isEmpty || overlayRaw is! Map) {
      return null;
    }
    final overlay = CalendarAvailabilityOverlay.fromJson(
      _normalizeJsonMap(overlayRaw),
    );
    final updatedAtValue = json[_availabilityPresetUpdatedAtKey] as String?;
    final updatedAt =
        updatedAtValue == null ? null : DateTime.tryParse(updatedAtValue);
    return CalendarAvailabilityPreset(
      id: id,
      overlay: overlay,
      name: name,
      updatedAt: updatedAt,
    );
  }
}

ChatType _chatTypeFromString(String? value) {
  if (value == null || value.trim().isEmpty) {
    return _availabilityShareDefaultChatType;
  }
  for (final type in ChatType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return _availabilityShareDefaultChatType;
}

Map<String, dynamic> _normalizeJsonMap(Map raw) {
  final Map<String, dynamic> normalized = <String, dynamic>{};
  for (final entry in raw.entries) {
    final Object? key = entry.key;
    if (key == null) {
      continue;
    }
    normalized[key.toString()] = _normalizeJsonValue(entry.value);
  }
  return normalized;
}

Object? _normalizeJsonValue(Object? value) {
  if (value is Map) {
    return _normalizeJsonMap(value);
  }
  if (value is List) {
    return value.map(_normalizeJsonValue).toList();
  }
  return value;
}
