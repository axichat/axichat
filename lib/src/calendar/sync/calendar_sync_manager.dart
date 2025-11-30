import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';

import 'package:axichat/src/calendar/models/calendar_exceptions.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';

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
  final List<String> _pendingEnvelopes = <String>[];
  Future<void>? _pendingFlush;

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
      await _flushPendingEnvelopes();
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
      if (message.entity == 'day_event') {
        final DayEvent event = DayEvent.fromJson(message.data!);
        await _mergeDayEvent(event, message.operation ?? 'update');
        return;
      }
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
    await _sendEnvelope(
      messageJson,
      clearQueueUntil: _pendingEnvelopes.length,
    );
  }

  /// Send task update to other devices
  Future<void> sendTaskUpdate(CalendarTask task, String operation) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: task.id,
      operation: operation,
      data: task.toJson(),
      entity: 'task',
    );
  }

  Future<void> sendDayEventUpdate(DayEvent event, String operation) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: event.id,
      operation: operation,
      data: event.toJson(),
      entity: 'day_event',
    );
  }

  /// Request full calendar sync from other devices
  Future<void> requestFullSync() async {
    await _flushPendingEnvelopes();
    final syncMessage = CalendarSyncMessage.request();

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendCalendarMessage(messageJson);
  }

  /// Push full calendar to other devices
  Future<void> pushFullSync() async {
    await _flushPendingEnvelopes();
    final model = _readModel();
    await _sendFullCalendar(model);
  }

  Future<void> _sendUpdate({
    required String payloadId,
    required String operation,
    required Map<String, dynamic> data,
    required String entity,
  }) async {
    final syncMessage = CalendarSyncMessage.update(
      taskId: payloadId,
      operation: operation,
      data: data,
      entity: entity,
    );

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendEnvelope(messageJson);
  }

  String _calculateChecksum(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  CalendarModel _mergeModels(CalendarModel local, CalendarModel remote) {
    final mergedTasks = <String, CalendarTask>{};
    final allIds = <String>{
      ...local.tasks.keys,
      ...remote.tasks.keys,
    };

    for (final id in allIds) {
      final localTask = local.tasks[id];
      final remoteTask = remote.tasks[id];

      if (localTask == null && remoteTask != null) {
        mergedTasks[id] = remoteTask;
        continue;
      }

      if (localTask != null && remoteTask == null) {
        // Preserve local-only tasks; deletion must be explicit via update ops,
        // not inferred from wall-clock skew between devices.
        mergedTasks[id] = localTask;
        continue;
      }

      if (localTask != null && remoteTask != null) {
        mergedTasks[id] = remoteTask.modifiedAt.isAfter(localTask.modifiedAt)
            ? remoteTask
            : localTask;
      }
    }

    final Map<String, DayEvent> mergedDayEvents = <String, DayEvent>{};
    final Set<String> allEventIds = <String>{
      ...local.dayEvents.keys,
      ...remote.dayEvents.keys,
    };

    for (final String id in allEventIds) {
      final DayEvent? localEvent = local.dayEvents[id];
      final DayEvent? remoteEvent = remote.dayEvents[id];

      if (localEvent == null && remoteEvent != null) {
        mergedDayEvents[id] = remoteEvent;
        continue;
      }

      if (localEvent != null && remoteEvent == null) {
        mergedDayEvents[id] = localEvent;
        continue;
      }

      if (localEvent != null && remoteEvent != null) {
        mergedDayEvents[id] = remoteEvent.modifiedAt.isAfter(
          localEvent.modifiedAt,
        )
            ? remoteEvent
            : localEvent;
      }
    }

    final mergedPaths = <String, CalendarCriticalPath>{};
    final allPathIds = <String>{
      ...local.criticalPaths.keys,
      ...remote.criticalPaths.keys,
    };

    for (final id in allPathIds) {
      final CalendarCriticalPath? localPath = local.criticalPaths[id];
      final CalendarCriticalPath? remotePath = remote.criticalPaths[id];

      if (localPath == null && remotePath != null) {
        mergedPaths[id] = remotePath;
        continue;
      }

      if (localPath != null && remotePath == null) {
        mergedPaths[id] = localPath;
        continue;
      }

      if (localPath != null && remotePath != null) {
        mergedPaths[id] = remotePath.modifiedAt.isAfter(localPath.modifiedAt)
            ? remotePath
            : localPath;
      }
    }

    final merged = CalendarModel(
      tasks: mergedTasks,
      dayEvents: mergedDayEvents,
      criticalPaths: mergedPaths,
      lastModified: DateTime.now(),
      checksum: '',
    );
    return merged.copyWith(checksum: merged.calculateChecksum());
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
        break;
      case 'delete':
        final existing = currentModel.tasks[remoteTask.id];
        if (existing != null &&
            existing.modifiedAt.isAfter(remoteTask.modifiedAt)) {
          return;
        }
        updatedModel = currentModel.deleteTask(remoteTask.id);
        break;
      default:
        developer.log('Unknown task operation: $operation');
        return;
    }

    await _applyModel(updatedModel);
  }

  Future<void> _mergeDayEvent(DayEvent remoteEvent, String operation) async {
    final CalendarModel currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case 'add':
      case 'update':
        final DayEvent? localEvent = currentModel.dayEvents[remoteEvent.id];
        if (localEvent == null) {
          updatedModel = currentModel.addDayEvent(remoteEvent);
        } else if (remoteEvent.modifiedAt.isAfter(localEvent.modifiedAt)) {
          updatedModel = currentModel.updateDayEvent(remoteEvent);
        } else {
          return;
        }
        break;
      case 'delete':
        final DayEvent? existing = currentModel.dayEvents[remoteEvent.id];
        if (existing != null &&
            existing.modifiedAt.isAfter(remoteEvent.modifiedAt)) {
          return;
        }
        updatedModel = currentModel.deleteDayEvent(remoteEvent.id);
        break;
      default:
        developer.log('Unknown day event operation: $operation');
        return;
    }

    await _applyModel(updatedModel);
  }

  Future<void> _sendEnvelope(
    String envelope, {
    int clearQueueUntil = 0,
  }) async {
    try {
      await _flushPendingEnvelopes();
      await _sendCalendarMessage(envelope);
      _clearPendingUpTo(clearQueueUntil);
      if (_pendingEnvelopes.isNotEmpty) {
        await _flushPendingEnvelopes();
      }
    } catch (_) {
      _pendingEnvelopes.add(envelope);
      rethrow;
    }
  }

  void _clearPendingUpTo(int clearQueueUntil) {
    if (clearQueueUntil <= 0 || _pendingEnvelopes.isEmpty) {
      return;
    }
    final toClear = clearQueueUntil > _pendingEnvelopes.length
        ? _pendingEnvelopes.length
        : clearQueueUntil;
    if (toClear > 0) {
      _pendingEnvelopes.removeRange(0, toClear);
    }
  }

  Future<void> _flushPendingEnvelopes() async {
    if (_pendingEnvelopes.isEmpty && _pendingFlush == null) {
      return;
    }
    if (_pendingFlush != null) {
      await _pendingFlush;
      if (_pendingEnvelopes.isEmpty) {
        return;
      }
    }

    _pendingFlush = _drainPendingEnvelopes();
    await _pendingFlush;
  }

  Future<void> _drainPendingEnvelopes() async {
    try {
      while (_pendingEnvelopes.isNotEmpty) {
        final envelope = _pendingEnvelopes.first;
        await _sendCalendarMessage(envelope);
        _pendingEnvelopes.removeAt(0);
      }
    } finally {
      _pendingFlush = null;
    }
  }
}
