import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:axichat/src/calendar/models/calendar_exceptions.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';

/// Threshold of updates before sending a snapshot.
const int kSnapshotThreshold = 50;

/// Result of sending a snapshot file.
class SnapshotSendResult {
  const SnapshotSendResult({
    required this.url,
    required this.checksum,
    required this.version,
  });

  final String url;
  final String checksum;
  final int version;
}

class CalendarSyncManager {
  CalendarSyncManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
    required Future<void> Function(String) sendCalendarMessage,
    Future<SnapshotSendResult> Function(File file)? sendSnapshotFile,
    CalendarSyncState Function()? readSyncState,
    Future<void> Function(CalendarSyncState)? writeSyncState,
  })  : _readModel = readModel,
        _applyModel = applyModel,
        _sendCalendarMessage = sendCalendarMessage,
        _sendSnapshotFile = sendSnapshotFile,
        _readSyncState = readSyncState ?? CalendarSyncState.read,
        _writeSyncState = writeSyncState ?? ((s) => s.write());

  final CalendarModel Function() _readModel;
  final Future<void> Function(CalendarModel) _applyModel;
  final Future<void> Function(String) _sendCalendarMessage;
  final Future<SnapshotSendResult> Function(File file)? _sendSnapshotFile;
  final CalendarSyncState Function() _readSyncState;
  final Future<void> Function(CalendarSyncState) _writeSyncState;
  final List<String> _pendingEnvelopes = <String>[];
  Future<void>? _pendingFlush;

  /// Whether the manager is currently rehydrating from MAM.
  bool _rehydrating = false;

  /// Sets the rehydrating flag to prevent snapshot feedback loops.
  void setRehydrating(bool value) {
    _rehydrating = value;
  }

  /// Whether the manager is currently rehydrating.
  bool get isRehydrating => _rehydrating;

  /// Handles an incoming calendar sync message.
  ///
  /// If [stanzaId] is provided, it will be recorded in the sync state.
  Future<void> onCalendarMessage(
    CalendarSyncMessage message, {
    String? stanzaId,
  }) async {
    try {
      switch (message.type) {
        case CalendarSyncType.request:
          await _handleRequestMessage(message);
        case CalendarSyncType.full:
          await _handleFullMessage(message, stanzaId: stanzaId);
        case CalendarSyncType.update:
          await _handleUpdateMessage(message, stanzaId: stanzaId);
        case CalendarSyncType.snapshot:
          await _handleSnapshotMessage(message, stanzaId: stanzaId);
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

  /// Handles a snapshot message by merging the attached model.
  Future<void> _handleSnapshotMessage(
    CalendarSyncMessage message, {
    String? stanzaId,
  }) async {
    if (message.data == null) return;

    try {
      final remoteModel = CalendarModel.fromJson(message.data!);
      final localModel = _readModel();

      developer.log(
        'Applying snapshot (checksum: ${message.snapshotChecksum})',
        name: 'CalendarSyncManager',
      );

      final mergedModel = _mergeModels(localModel, remoteModel);
      await _applyModel(mergedModel);

      final state = _readSyncState().resetCounter().copyWith(
            lastAppliedTimestamp: message.timestamp,
            lastAppliedStanzaId: stanzaId,
            lastSnapshotChecksum: message.snapshotChecksum,
          );
      await _writeSyncState(state);
    } catch (e) {
      developer.log('Error handling snapshot message: $e');
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

  Future<void> _handleFullMessage(
    CalendarSyncMessage message, {
    String? stanzaId,
  }) async {
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
        await _recordAppliedMessage(message, stanzaId: stanzaId);
        return;
      }

      developer.log(
          'Calendar conflict detected - merging models (local: $localChecksum, remote: $remoteChecksum)');
      final mergedModel = _mergeModels(localModel, remoteModel);
      await _applyModel(mergedModel);
      await _recordAppliedMessage(message, stanzaId: stanzaId);
    } catch (e) {
      developer.log('Error handling full calendar message: $e');
    }
  }

  Future<void> _handleUpdateMessage(
    CalendarSyncMessage message, {
    String? stanzaId,
  }) async {
    if (message.data == null || message.taskId == null) return;

    try {
      switch (message.entity) {
        case 'day_event':
          final DayEvent event = DayEvent.fromJson(message.data!);
          await _mergeDayEvent(event, message.operation ?? 'update');
        case 'critical_path':
          final path = CalendarCriticalPath.fromJson(message.data!);
          await _mergeCriticalPath(path, message.operation ?? 'update');
        default:
          final task = CalendarTask.fromJson(message.data!);
          await _mergeTask(task, message.operation ?? 'update');
      }

      await _incrementCounterAndMaybeSnapshot();
      await _recordAppliedMessage(message, stanzaId: stanzaId);
    } catch (e) {
      developer.log('Error handling calendar update: $e');
    }
  }

  /// Records that a message was applied, updating the sync state.
  Future<void> _recordAppliedMessage(
    CalendarSyncMessage message, {
    String? stanzaId,
  }) async {
    final state = _readSyncState().copyWith(
      lastAppliedTimestamp: message.timestamp,
      lastAppliedStanzaId: stanzaId,
    );
    await _writeSyncState(state);
  }

  /// Increments the update counter and sends a snapshot if threshold reached.
  Future<void> _incrementCounterAndMaybeSnapshot() async {
    if (_rehydrating) return;

    final state = _readSyncState().incrementCounter();
    await _writeSyncState(state);

    if (state.updatesSinceSnapshot >= kSnapshotThreshold) {
      await _maybeSendSnapshot();
    }
  }

  /// Sends a snapshot if the calendar has content and snapshot sending is available.
  Future<void> _maybeSendSnapshot() async {
    final sendSnapshot = _sendSnapshotFile;
    if (sendSnapshot == null || _rehydrating) return;

    final model = _readModel();
    if (model.tasks.isEmpty &&
        model.dayEvents.isEmpty &&
        model.criticalPaths.isEmpty) {
      return;
    }

    try {
      final tempDir = Directory.systemTemp;
      final file = await CalendarSnapshotCodec.encodeToFile(
        model,
        directory: tempDir,
      );

      try {
        final result = await sendSnapshot(file);

        final syncMessage = CalendarSyncMessage.snapshot(
          snapshotChecksum: result.checksum,
          snapshotVersion: result.version,
          snapshotUrl: result.url,
        );

        final messageJson = jsonEncode({
          'calendar_sync': syncMessage.toJson(),
        });

        await _sendCalendarMessage(messageJson);

        final state = _readSyncState()
            .resetCounter()
            .copyWith(lastSnapshotChecksum: result.checksum);
        await _writeSyncState(state);

        developer.log(
          'Sent calendar snapshot (checksum: ${result.checksum})',
          name: 'CalendarSyncManager',
        );
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      developer.log('Error sending snapshot: $e', name: 'CalendarSyncManager');
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
    await _incrementCounterAndMaybeSnapshot();
  }

  Future<void> sendDayEventUpdate(DayEvent event, String operation) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: event.id,
      operation: operation,
      data: event.toJson(),
      entity: 'day_event',
    );
    await _incrementCounterAndMaybeSnapshot();
  }

  /// Send critical path update to other devices
  Future<void> sendCriticalPathUpdate(
    CalendarCriticalPath path,
    String operation,
  ) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: path.id,
      operation: operation,
      data: path.toJson(),
      entity: 'critical_path',
    );
    await _incrementCounterAndMaybeSnapshot();
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
    // Merge tombstones first (keep latest deletion time for each)
    final mergedDeletedTaskIds =
        _mergeTombstones(local.deletedTaskIds, remote.deletedTaskIds);
    final mergedDeletedDayEventIds =
        _mergeTombstones(local.deletedDayEventIds, remote.deletedDayEventIds);
    final mergedDeletedCriticalPathIds = _mergeTombstones(
      local.deletedCriticalPathIds,
      remote.deletedCriticalPathIds,
    );

    final mergedTasks = <String, CalendarTask>{};
    final allIds = <String>{
      ...local.tasks.keys,
      ...remote.tasks.keys,
    };

    for (final id in allIds) {
      // Skip tasks that are in tombstones
      if (mergedDeletedTaskIds.containsKey(id)) {
        continue;
      }

      final localTask = local.tasks[id];
      final remoteTask = remote.tasks[id];

      if (localTask == null && remoteTask != null) {
        mergedTasks[id] = remoteTask;
        continue;
      }

      if (localTask != null && remoteTask == null) {
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
      // Skip day events that are in tombstones
      if (mergedDeletedDayEventIds.containsKey(id)) {
        continue;
      }

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
      // Skip critical paths that are in tombstones
      if (mergedDeletedCriticalPathIds.containsKey(id)) {
        continue;
      }

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
      deletedTaskIds: mergedDeletedTaskIds,
      deletedDayEventIds: mergedDeletedDayEventIds,
      deletedCriticalPathIds: mergedDeletedCriticalPathIds,
      lastModified: DateTime.now(),
      checksum: '',
    );
    return merged.copyWith(checksum: merged.calculateChecksum());
  }

  Map<String, DateTime> _mergeTombstones(
    Map<String, DateTime> local,
    Map<String, DateTime> remote,
  ) {
    final merged = <String, DateTime>{};
    final allIds = <String>{...local.keys, ...remote.keys};
    for (final id in allIds) {
      final localTime = local[id];
      final remoteTime = remote[id];
      if (localTime == null) {
        merged[id] = remoteTime!;
      } else if (remoteTime == null) {
        merged[id] = localTime;
      } else {
        merged[id] = remoteTime.isAfter(localTime) ? remoteTime : localTime;
      }
    }
    return merged;
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

  Future<void> _mergeCriticalPath(
    CalendarCriticalPath remotePath,
    String operation,
  ) async {
    final currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case 'add':
      case 'update':
        final localPath = currentModel.criticalPaths[remotePath.id];
        if (localPath == null) {
          updatedModel = currentModel.addCriticalPath(remotePath);
        } else if (remotePath.modifiedAt.isAfter(localPath.modifiedAt)) {
          updatedModel = currentModel.updateCriticalPath(remotePath);
        } else {
          return;
        }
      case 'delete':
        final existing = currentModel.criticalPaths[remotePath.id];
        if (existing != null &&
            existing.modifiedAt.isAfter(remotePath.modifiedAt)) {
          return;
        }
        updatedModel = currentModel.removeCriticalPath(remotePath.id);
      default:
        developer.log('Unknown critical path operation: $operation');
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
