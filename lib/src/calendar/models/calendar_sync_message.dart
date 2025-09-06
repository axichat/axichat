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
    String? deviceId,
    String? taskId,
    String? operation, // 'add', 'update', 'delete'
  }) = _CalendarSyncMessage;

  factory CalendarSyncMessage.fromJson(Map<String, dynamic> json) =>
      _$CalendarSyncMessageFromJson(json);

  factory CalendarSyncMessage.request({required String deviceId}) =>
      CalendarSyncMessage(
        type: 'calendar_request',
        timestamp: DateTime.now(),
        deviceId: deviceId,
      );

  factory CalendarSyncMessage.full({
    required Map<String, dynamic> data,
    required String checksum,
    required String deviceId,
  }) =>
      CalendarSyncMessage(
        type: 'calendar_full',
        data: data,
        checksum: checksum,
        timestamp: DateTime.now(),
        deviceId: deviceId,
      );

  factory CalendarSyncMessage.update({
    required String taskId,
    required String operation,
    required String deviceId,
    Map<String, dynamic>? data,
  }) =>
      CalendarSyncMessage(
        type: 'calendar_update',
        data: data,
        timestamp: DateTime.now(),
        deviceId: deviceId,
        taskId: taskId,
        operation: operation,
      );

  const CalendarSyncMessage._();

  XmlElement toXmppExtension() {
    final element = XmlElement(XmlName('calendar_sync'));

    element.children.addAll([
      XmlElement(XmlName('type'))..innerText = type,
      XmlElement(XmlName('timestamp'))..innerText = timestamp.toIso8601String(),
    ]);

    if (deviceId != null) {
      element.children.add(
        XmlElement(XmlName('device_id'))..innerText = deviceId!,
      );
    }

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
    final deviceId = getText('device_id');
    final checksum = getText('checksum');
    final taskId = getText('task_id');
    final operation = getText('operation');

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
      deviceId: deviceId,
      taskId: taskId,
      operation: operation,
    );
  }
}
