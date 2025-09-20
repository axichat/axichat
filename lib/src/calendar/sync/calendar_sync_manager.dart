import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';

import '../models/calendar_exceptions.dart';
import '../models/calendar_model.dart';
import '../models/calendar_sync_message.dart';
import '../models/calendar_task.dart';

class CalendarSyncManager {
  CalendarSyncManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
    required Future<void> Function(String) sendCalendarMessage,
  })  : _readModel = readModel,
        _applyModel = applyModel,
        _sendCalendarMessage = sendCalendarMessage;

  final CalendarModel Function() _readModel;
  final Future<void> Function(CalendarModel) _applyModel;
  final Future<void> Function(String) _sendCalendarMessage;

  Future<void> onCalendarMessage(CalendarSyncMessage message) async {
    try {
      switch (message.type) {
        case 'calendar_request':
          await _handleRequestMessage(message);
        case 'calendar_full':
          await _handleFullMessage(message);
        case 'calendar_update':
          await _handleUpdateMessage(message);
        default:
          developer.log('Unknown calendar sync message type: ${message.type}');
          throw CalendarSyncException(
              'Unknown sync message type: ${message.type}');
      }
    } catch (e) {
      developer.log('Error handling calendar message: $e',
          name: 'CalendarSyncManager');
      if (e is CalendarException) {
        rethrow;
      }
      throw CalendarSyncException(
          'Failed to process sync message', e.toString());
    }
  }

  Future<void> _handleRequestMessage(CalendarSyncMessage message) async {
    try {
      final model = _readModel();
      await _sendFullCalendar(model);
    } catch (e) {
      developer.log('Error handling request message: $e',
          name: 'CalendarSyncManager');
      throw CalendarSyncException('Failed to send calendar data', e.toString());
    }
  }

  Future<void> _handleFullMessage(CalendarSyncMessage message) async {
    if (message.data == null) return;

    try {
      final remoteModel = CalendarModel.fromJson(message.data!);
      final localModel = _readModel();

      // Use checksum for conflict detection
      final localChecksum = _calculateChecksum(localModel.toJson());
      final remoteChecksum =
          message.checksum ?? _calculateChecksum(message.data!);

      if (localChecksum == remoteChecksum) {
        developer.log('Calendars already in sync - no changes needed');
        return;
      }

      developer.log(
          'Calendar conflict detected - merging models (local: $localChecksum, remote: $remoteChecksum)');
      final mergedModel = _mergeModels(localModel, remoteModel);
      await _applyModel(mergedModel);
    } catch (e) {
      developer.log('Error handling full calendar message: $e');
    }
  }

  Future<void> _handleUpdateMessage(CalendarSyncMessage message) async {
    if (message.data == null || message.taskId == null) return;

    try {
      final task = CalendarTask.fromJson(message.data!);
      await _mergeTask(task, message.operation ?? 'update');
    } catch (e) {
      developer.log('Error handling calendar update: $e');
    }
  }

  Future<void> _sendFullCalendar(CalendarModel model) async {
    final syncMessage = CalendarSyncMessage.full(
      data: model.toJson(),
      checksum: model.checksum,
    );

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendCalendarMessage(messageJson);
  }

  /// Send task update to other devices
  Future<void> sendTaskUpdate(CalendarTask task, String operation) async {
    await _sendTaskUpdate(task, operation);
  }

  /// Request full calendar sync from other devices
  Future<void> requestFullSync() async {
    final syncMessage = CalendarSyncMessage.request();

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendCalendarMessage(messageJson);
  }

  /// Push full calendar to other devices
  Future<void> pushFullSync() async {
    final model = _readModel();
    await _sendFullCalendar(model);
  }

  Future<void> _sendTaskUpdate(CalendarTask task, String operation) async {
    final syncMessage = CalendarSyncMessage.update(
      taskId: task.id,
      operation: operation,
      data: task.toJson(),
    );

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendCalendarMessage(messageJson);
  }

  String _calculateChecksum(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  CalendarModel _mergeModels(CalendarModel local, CalendarModel remote) {
    final mergedTasks = <String, CalendarTask>{...local.tasks};

    for (final task in remote.tasks.values) {
      final localTask = mergedTasks[task.id];
      if (localTask == null || task.modifiedAt.isAfter(localTask.modifiedAt)) {
        mergedTasks[task.id] = task;
      }
    }

    return local.copyWith(
      tasks: mergedTasks,
      lastModified: DateTime.now(),
    );
  }

  Future<void> _mergeTask(CalendarTask remoteTask, String operation) async {
    final currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case 'add':
      case 'update':
        final localTask = currentModel.tasks[remoteTask.id];
        if (localTask == null ||
            remoteTask.modifiedAt.isAfter(localTask.modifiedAt)) {
          updatedModel = currentModel.updateTask(remoteTask);
        } else {
          return;
        }
      case 'delete':
        updatedModel = currentModel.deleteTask(remoteTask.id);
      default:
        developer.log('Unknown task operation: $operation');
        return;
    }

    await _applyModel(updatedModel);
  }
}
