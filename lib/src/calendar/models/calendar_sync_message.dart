import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:xml/xml.dart';

part 'calendar_sync_message.freezed.dart';
part 'calendar_sync_message.g.dart';

@freezed
class CalendarSyncMessage with _$CalendarSyncMessage {
  const factory CalendarSyncMessage({
    required String
        type, // 'calendar_request', 'calendar_full', 'calendar_update'
    Map<String, dynamic>? data,
    String? checksum,
    required DateTime timestamp,
    String? taskId,
    String? operation, // 'add', 'update', 'delete'
    @Default('task') String entity, // 'task', 'day_event'
  }) = _CalendarSyncMessage;

  factory CalendarSyncMessage.fromJson(Map<String, dynamic> json) =>
      _$CalendarSyncMessageFromJson(json);

  factory CalendarSyncMessage.request() => CalendarSyncMessage(
        type: 'calendar_request',
        timestamp: DateTime.now(),
      );

  factory CalendarSyncMessage.full({
    required Map<String, dynamic> data,
    required String checksum,
  }) =>
      CalendarSyncMessage(
        type: 'calendar_full',
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
        type: 'calendar_update',
        data: data,
        timestamp: DateTime.now(),
        taskId: taskId,
        operation: operation,
        entity: entity,
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
    if (type == null ||
        !['calendar_request', 'calendar_full', 'calendar_update']
            .contains(type)) {
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

    return CalendarSyncMessage(
      type: type,
      data: data,
      checksum: checksum,
      timestamp: timestamp,
      taskId: taskId,
      operation: operation,
      entity: entity,
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
