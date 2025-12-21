import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xml/xml.dart';

part 'calendar_sync_message.freezed.dart';
part 'calendar_sync_message.g.dart';

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

    final type = getText('type');
    if (type == null || !CalendarSyncType.all.contains(type)) {
      throw ArgumentError('Invalid or missing sync message type');
    }

    final timestampStr = getText('timestamp');
    if (timestampStr == null) {
      throw ArgumentError('Missing timestamp');
    }

    final timestamp = DateTime.parse(timestampStr);
    final checksum = getText('checksum');
    final taskId = getText('task_id');
    final operation = getText('operation');
    final entity = getText('entity') ?? 'task';

    Map<String, dynamic>? data;
    final dataStr = getText('data');
    if (dataStr != null && dataStr.isNotEmpty) {
      try {
        data = jsonDecode(dataStr) as Map<String, dynamic>;
      } catch (e) {
        throw ArgumentError('Invalid data format: $e');
      }
    }

    final isSnapshot = getText('is_snapshot') == 'true';
    final snapshotChecksum = getText('snapshot_checksum');
    final snapshotVersionStr = getText('snapshot_version');
    final snapshotVersion =
        snapshotVersionStr != null ? int.tryParse(snapshotVersionStr) : null;
    final snapshotUrl = getText('snapshot_url');

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
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final payload = decoded['calendar_sync'];
      if (payload is! Map<String, dynamic>) {
        return null;
      }
      return CalendarSyncMessage.fromJson(payload);
    } catch (_) {
      return null;
    }
  }

  static bool isCalendarSyncEnvelope(String raw) =>
      tryParseEnvelope(raw) != null;
}
