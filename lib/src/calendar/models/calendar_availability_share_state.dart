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
    this.updatedAt,
  });

  final String id;
  final CalendarAvailabilityShareSource source;
  final String chatJid;
  final ChatType chatType;
  final CalendarAvailabilityOverlay overlay;
  final DateTime? updatedAt;

  CalendarAvailabilityShareRecord copyWith({
    String? id,
    CalendarAvailabilityShareSource? source,
    String? chatJid,
    ChatType? chatType,
    CalendarAvailabilityOverlay? overlay,
    DateTime? updatedAt,
  }) =>
      CalendarAvailabilityShareRecord(
        id: id ?? this.id,
        source: source ?? this.source,
        chatJid: chatJid ?? this.chatJid,
        chatType: chatType ?? this.chatType,
        overlay: overlay ?? this.overlay,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        _availabilityShareRecordIdKey: id,
        _availabilityShareRecordSourceKey: source.toJson(),
        _availabilityShareRecordChatJidKey: chatJid,
        _availabilityShareRecordChatTypeKey: chatType.name,
        _availabilityShareRecordOverlayKey: overlay.toJson(),
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
    if (id == null ||
        id.trim().isEmpty ||
        sourceRaw is! Map ||
        chatJid == null ||
        chatJid.trim().isEmpty ||
        overlayRaw is! Map) {
      return null;
    }
    final source = CalendarAvailabilityShareSource.fromJson(
      Map<String, dynamic>.from(sourceRaw),
    );
    if (source == null) {
      return null;
    }
    final overlay = CalendarAvailabilityOverlay.fromJson(
      Map<String, dynamic>.from(overlayRaw),
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
