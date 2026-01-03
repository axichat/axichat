// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xml/xml.dart';

part 'calendar_sync_message.freezed.dart';
part 'calendar_sync_message.g.dart';

const int _calendarSyncEnvelopeMaxLength = 256 * 1024;
const int _calendarSyncTypeMaxLength = 64;
const int _calendarSyncEntityMaxLength = 64;
const int _calendarSyncChecksumMaxLength = 256;
const int _calendarSyncSnapshotChecksumMaxLength = 256;
const int _calendarSyncTaskIdMaxLength = 128;
const int _calendarSyncOperationMaxLength = 64;
const int _calendarSyncSnapshotUrlMaxLength = 2048;
const int _calendarSyncDataMaxLength = 200000;
const int _calendarSyncTimestampMaxLength = 64;
const int _calendarSyncSnapshotVersionMaxLength = 16;

/// Valid message types for calendar sync.
abstract final class CalendarSyncType {
  static const String request = 'calendar_request';
  static const String full = 'calendar_full';
  static const String update = 'calendar_update';
  static const String snapshot = 'calendar_snapshot';

  static const List<String> all = [request, full, update, snapshot];
}

class CalendarSyncAttachment {
  const CalendarSyncAttachment({
    required this.url,
    required this.fileName,
    this.mimeType,
  });

  final String url;
  final String fileName;
  final String? mimeType;
}

class CalendarSyncOutbound {
  const CalendarSyncOutbound({
    required this.envelope,
    this.attachment,
  });

  final String envelope;
  final CalendarSyncAttachment? attachment;
}

class CalendarSyncInbound {
  const CalendarSyncInbound({
    required this.message,
    this.stanzaId,
    this.receivedAt,
    this.isFromMam = false,
  });

  final CalendarSyncMessage message;
  final String? stanzaId;
  final DateTime? receivedAt;
  final bool isFromMam;

  DateTime get appliedTimestamp => receivedAt ?? message.timestamp;
}

@freezed
class CalendarSyncMessage with _$CalendarSyncMessage {
  static const int maxEnvelopeLength = _calendarSyncEnvelopeMaxLength;

  const factory CalendarSyncMessage({
    /// Message type: request, full, update, or snapshot.
    required String type,
    Map<String, dynamic>? data,
    String? checksum,
    required DateTime timestamp,
    String? taskId,
    String? operation,
    @Default('task') String entity,

    /// True if this message references an attachment-based snapshot.
    @Default(false) bool isSnapshot,

    /// Checksum of the snapshot file (for integrity verification).
    String? snapshotChecksum,

    /// Snapshot format version for compatibility checks.
    int? snapshotVersion,

    /// URL of the snapshot attachment (for file-based snapshots).
    String? snapshotUrl,
  }) = _CalendarSyncMessage;

  factory CalendarSyncMessage.fromJson(Map<String, dynamic> json) =>
      _$CalendarSyncMessageFromJson(json);

  factory CalendarSyncMessage.request() => CalendarSyncMessage(
        type: CalendarSyncType.request,
        timestamp: DateTime.now(),
      );

  factory CalendarSyncMessage.full({
    required Map<String, dynamic> data,
    required String checksum,
  }) =>
      CalendarSyncMessage(
        type: CalendarSyncType.full,
        data: data,
        checksum: checksum,
        timestamp: DateTime.now(),
      );

  factory CalendarSyncMessage.update({
    required String taskId,
    required String operation,
    Map<String, dynamic>? data,
    String entity = 'task',
  }) =>
      CalendarSyncMessage(
        type: CalendarSyncType.update,
        data: data,
        timestamp: DateTime.now(),
        taskId: taskId,
        operation: operation,
        entity: entity,
      );

  /// Creates a snapshot message referencing an attachment-based snapshot.
  factory CalendarSyncMessage.snapshot({
    required String snapshotChecksum,
    required int snapshotVersion,
    required String snapshotUrl,
  }) =>
      CalendarSyncMessage(
        type: CalendarSyncType.snapshot,
        timestamp: DateTime.now(),
        isSnapshot: true,
        snapshotChecksum: snapshotChecksum,
        snapshotVersion: snapshotVersion,
        snapshotUrl: snapshotUrl,
      );

  const CalendarSyncMessage._();

  XmlElement toXmppExtension() {
    final element = XmlElement(XmlName('calendar_sync'));

    element.children.addAll([
      XmlElement(XmlName('type'))..innerText = type,
      XmlElement(XmlName('timestamp'))..innerText = timestamp.toIso8601String(),
    ]);

    element.children.add(
      XmlElement(XmlName('entity'))..innerText = entity,
    );

    if (checksum != null) {
      element.children.add(
        XmlElement(XmlName('checksum'))..innerText = checksum!,
      );
    }

    if (taskId != null) {
      element.children.add(
        XmlElement(XmlName('task_id'))..innerText = taskId!,
      );
    }

    if (operation != null) {
      element.children.add(
        XmlElement(XmlName('operation'))..innerText = operation!,
      );
    }

    if (data != null) {
      element.children.add(
        XmlElement(XmlName('data'))..innerText = jsonEncode(data!),
      );
    }

    if (isSnapshot) {
      element.children.add(
        XmlElement(XmlName('is_snapshot'))..innerText = 'true',
      );
    }

    if (snapshotChecksum != null) {
      element.children.add(
        XmlElement(XmlName('snapshot_checksum'))..innerText = snapshotChecksum!,
      );
    }

    if (snapshotVersion != null) {
      element.children.add(
        XmlElement(XmlName('snapshot_version'))
          ..innerText = snapshotVersion.toString(),
      );
    }

    if (snapshotUrl != null) {
      element.children.add(
        XmlElement(XmlName('snapshot_url'))..innerText = snapshotUrl!,
      );
    }

    return element;
  }

  static CalendarSyncMessage fromXmppExtension(
      Map<String, XmlElement> extensions) {
    final calendarExt = extensions['calendar_sync'];
    if (calendarExt == null) {
      throw ArgumentError('Missing calendar_sync extension');
    }

    String? getText(String name) =>
        calendarExt.findElements(name).firstOrNull?.innerText;

    final type = _trimmedBoundedText(
      getText('type'),
      _calendarSyncTypeMaxLength,
    );
    if (type == null || !CalendarSyncType.all.contains(type)) {
      throw ArgumentError('Invalid or missing sync message type');
    }

    final timestampStr = _trimmedBoundedText(
      getText('timestamp'),
      _calendarSyncTimestampMaxLength,
    );
    if (timestampStr == null) {
      throw ArgumentError('Missing timestamp');
    }

    final timestamp = DateTime.parse(timestampStr);
    final checksum = _trimmedBoundedText(
        getText('checksum'), _calendarSyncChecksumMaxLength);
    final taskId =
        _trimmedBoundedText(getText('task_id'), _calendarSyncTaskIdMaxLength);
    final operation = _trimmedBoundedText(
      getText('operation'),
      _calendarSyncOperationMaxLength,
    );
    final entity = _trimmedBoundedText(
          getText('entity'),
          _calendarSyncEntityMaxLength,
        ) ??
        'task';

    Map<String, dynamic>? data;
    final dataStr = getText('data');
    if (dataStr != null && dataStr.isNotEmpty) {
      if (dataStr.length > _calendarSyncDataMaxLength) {
        throw ArgumentError('Invalid data size');
      }
      try {
        data = jsonDecode(dataStr) as Map<String, dynamic>;
      } catch (e) {
        throw ArgumentError('Invalid data format: $e');
      }
    }

    final isSnapshot = getText('is_snapshot') == 'true';
    final snapshotChecksum = _trimmedBoundedText(
      getText('snapshot_checksum'),
      _calendarSyncSnapshotChecksumMaxLength,
    );
    final snapshotVersionStr = _trimmedBoundedText(
      getText('snapshot_version'),
      _calendarSyncSnapshotVersionMaxLength,
    );
    final snapshotVersion =
        snapshotVersionStr != null ? int.tryParse(snapshotVersionStr) : null;
    final snapshotUrl = _trimmedBoundedText(
      getText('snapshot_url'),
      _calendarSyncSnapshotUrlMaxLength,
    );

    return CalendarSyncMessage(
      type: type,
      data: data,
      checksum: checksum,
      timestamp: timestamp,
      taskId: taskId,
      operation: operation,
      entity: entity,
      isSnapshot: isSnapshot,
      snapshotChecksum: snapshotChecksum,
      snapshotVersion: snapshotVersion,
      snapshotUrl: snapshotUrl,
    );
  }

  static CalendarSyncMessage? tryParseEnvelope(String raw) {
    try {
      if (raw.length > _calendarSyncEnvelopeMaxLength) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final payload = decoded['calendar_sync'];
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      final message = CalendarSyncMessage.fromJson(payload);
      if (!_isCalendarSyncMessageValid(message)) {
        return null;
      }
      return message;
    } catch (_) {
      return null;
    }
  }

  static bool isCalendarSyncEnvelope(String raw) =>
      tryParseEnvelope(raw) != null;
}

String? _trimmedBoundedText(String? value, int maxLength) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.length > maxLength) return null;
  return trimmed;
}

bool _isCalendarSyncMessageValid(CalendarSyncMessage message) {
  if (message.type.length > _calendarSyncTypeMaxLength) return false;
  if (!CalendarSyncType.all.contains(message.type)) return false;
  if (message.entity.length > _calendarSyncEntityMaxLength) return false;
  if (_exceedsMaxLength(message.checksum, _calendarSyncChecksumMaxLength)) {
    return false;
  }
  if (_exceedsMaxLength(message.taskId, _calendarSyncTaskIdMaxLength)) {
    return false;
  }
  if (_exceedsMaxLength(message.operation, _calendarSyncOperationMaxLength)) {
    return false;
  }
  if (_exceedsMaxLength(
    message.snapshotChecksum,
    _calendarSyncSnapshotChecksumMaxLength,
  )) {
    return false;
  }
  if (_exceedsMaxLength(
    message.snapshotUrl,
    _calendarSyncSnapshotUrlMaxLength,
  )) {
    return false;
  }
  final data = message.data;
  if (data != null) {
    try {
      final encoded = jsonEncode(data);
      if (encoded.length > _calendarSyncDataMaxLength) {
        return false;
      }
    } catch (_) {
      return false;
    }
  }
  return true;
}

bool _exceedsMaxLength(String? value, int maxLength) =>
    value != null && value.length > maxLength;
