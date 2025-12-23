import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'package:axichat/src/calendar/models/calendar_exceptions.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';

/// Threshold of updates before sending a snapshot.
const int kSnapshotThreshold = 50;
const String _snapshotFallbackName =
    'calendar_snapshot${CalendarSnapshotCodec.fileExtension}';
const String _snapshotChecksumMismatchLog =
    'Snapshot checksum mismatch - ignoring snapshot';
const String _calendarSyncEntityTask = 'task';
const String _calendarSyncEntityDayEvent = 'day_event';
const String _calendarSyncEntityCriticalPath = 'critical_path';
const String _calendarSyncEntityJournal = 'journal';
const String _calendarSyncOperationAdd = 'add';
const String _calendarSyncOperationUpdate = 'update';
const String _calendarSyncOperationDelete = 'delete';
const int _calendarSequenceDefault = 0;

class CalendarSyncManager {
  CalendarSyncManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
    required Future<void> Function(CalendarSyncOutbound) sendCalendarMessage,
    Future<CalendarSnapshotUploadResult> Function(File file)? sendSnapshotFile,
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
  final Future<void> Function(CalendarSyncOutbound) _sendCalendarMessage;
  final Future<CalendarSnapshotUploadResult> Function(File file)?
      _sendSnapshotFile;
  final CalendarSyncState Function() _readSyncState;
  final Future<void> Function(CalendarSyncState) _writeSyncState;
  final List<CalendarSyncOutbound> _pendingEnvelopes = <CalendarSyncOutbound>[];
  Future<void>? _pendingFlush;

  /// Handles an incoming calendar sync message.
  Future<void> onCalendarMessage(CalendarSyncInbound inbound) async {
    final message = inbound.message;
    try {
      switch (message.type) {
        case CalendarSyncType.request:
          await _handleRequestMessage(message);
        case CalendarSyncType.full:
          await _handleFullMessage(message, inbound: inbound);
        case CalendarSyncType.update:
          await _handleUpdateMessage(message, inbound: inbound);
        case CalendarSyncType.snapshot:
          await _handleSnapshotMessage(message, inbound: inbound);
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
    required CalendarSyncInbound inbound,
  }) async {
    if (message.data == null) return;

    try {
      final remoteModel = CalendarModel.fromJson(message.data!);
      final localModel = _readModel();
      final snapshotChecksum = message.snapshotChecksum ?? message.checksum;

      developer.log(
        'Applying snapshot (checksum: ${message.snapshotChecksum})',
        name: 'CalendarSyncManager',
      );

      if (snapshotChecksum != null &&
          snapshotChecksum != remoteModel.calculateChecksum()) {
        developer.log(
          _snapshotChecksumMismatchLog,
          name: 'CalendarSyncManager',
        );
        return;
      }

      if (snapshotChecksum != null && localModel.checksum == snapshotChecksum) {
        await _recordAppliedMessage(message, inbound: inbound);
        return;
      }

      final mergedModel = localModel.mergeWith(remoteModel);
      await _applyModel(mergedModel);

      final state = _readSyncState().resetCounter().copyWith(
            lastAppliedTimestamp: inbound.appliedTimestamp,
            lastAppliedStanzaId: inbound.stanzaId,
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
    required CalendarSyncInbound inbound,
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
        await _recordAppliedMessage(message, inbound: inbound);
        return;
      }

      developer.log(
          'Calendar conflict detected - merging models (local: $localChecksum, remote: $remoteChecksum)');
      final mergedModel = localModel.mergeWith(remoteModel);
      await _applyModel(mergedModel);
      await _recordAppliedMessage(message, inbound: inbound);
    } catch (e) {
      developer.log('Error handling full calendar message: $e');
    }
  }

  Future<void> _handleUpdateMessage(
    CalendarSyncMessage message, {
    required CalendarSyncInbound inbound,
  }) async {
    if (message.data == null || message.taskId == null) return;

    try {
      final String operation =
          message.operation ?? _calendarSyncOperationUpdate;
      switch (message.entity) {
        case _calendarSyncEntityDayEvent:
          final DayEvent event = DayEvent.fromJson(message.data!);
          await _mergeDayEvent(event, operation);
          break;
        case _calendarSyncEntityCriticalPath:
          final path = CalendarCriticalPath.fromJson(message.data!);
          await _mergeCriticalPath(path, operation);
          break;
        case _calendarSyncEntityJournal:
          final CalendarJournal journal =
              CalendarJournal.fromJson(message.data!);
          await _mergeJournal(journal, operation);
          break;
        default:
          final task = CalendarTask.fromJson(message.data!);
          await _mergeTask(task, operation);
          break;
      }

      await _incrementCounterAndMaybeSnapshot(
        allowSnapshot: !inbound.isFromMam,
      );
      await _recordAppliedMessage(message, inbound: inbound);
    } catch (e) {
      developer.log('Error handling calendar update: $e');
    }
  }

  /// Records that a message was applied, updating the sync state.
  Future<void> _recordAppliedMessage(
    CalendarSyncMessage message, {
    required CalendarSyncInbound inbound,
  }) async {
    final state = _readSyncState().copyWith(
      lastAppliedTimestamp: inbound.appliedTimestamp,
      lastAppliedStanzaId: inbound.stanzaId,
    );
    await _writeSyncState(state);
  }

  /// Increments the update counter and sends a snapshot if threshold reached.
  Future<void> _incrementCounterAndMaybeSnapshot({
    required bool allowSnapshot,
  }) async {
    if (!allowSnapshot) return;
    final state = _readSyncState().incrementCounter();
    await _writeSyncState(state);

    if (state.updatesSinceSnapshot >= kSnapshotThreshold) {
      await _maybeSendSnapshot();
    }
  }

  /// Sends a snapshot if the calendar has content and snapshot sending is available.
  Future<void> _maybeSendSnapshot() async {
    final sendSnapshot = _sendSnapshotFile;
    if (sendSnapshot == null) return;

    final model = _readModel();
    if (!model.hasCalendarData) {
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
        final attachmentName = _snapshotAttachmentName(file);
        final attachment = CalendarSyncAttachment(
          url: result.url,
          fileName: attachmentName,
          mimeType: CalendarSnapshotCodec.mimeType,
        );

        final syncMessage = CalendarSyncMessage.snapshot(
          snapshotChecksum: result.checksum,
          snapshotVersion: result.version,
          snapshotUrl: result.url,
        );

        final messageJson = jsonEncode({
          'calendar_sync': syncMessage.toJson(),
        });

        await _sendCalendarMessage(
          CalendarSyncOutbound(
            envelope: messageJson,
            attachment: attachment,
          ),
        );

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
      CalendarSyncOutbound(envelope: messageJson),
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
      entity: _calendarSyncEntityTask,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  Future<void> sendDayEventUpdate(DayEvent event, String operation) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: event.id,
      operation: operation,
      data: event.toJson(),
      entity: _calendarSyncEntityDayEvent,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  Future<void> sendJournalUpdate(
    CalendarJournal journal,
    String operation,
  ) async {
    await _flushPendingEnvelopes();
    await _sendUpdate(
      payloadId: journal.id,
      operation: operation,
      data: journal.toJson(),
      entity: _calendarSyncEntityJournal,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
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
      entity: _calendarSyncEntityCriticalPath,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  /// Request full calendar sync from other devices
  Future<void> requestFullSync() async {
    await _flushPendingEnvelopes();
    final syncMessage = CalendarSyncMessage.request();

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendEnvelope(CalendarSyncOutbound(envelope: messageJson));
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
    await _sendEnvelope(CalendarSyncOutbound(envelope: messageJson));
  }

  String _calculateChecksum(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _shouldPreferRemote({
    required DateTime localModifiedAt,
    required DateTime remoteModifiedAt,
    required int localSequence,
    required int remoteSequence,
  }) {
    if (remoteModifiedAt.isAfter(localModifiedAt)) {
      return true;
    }
    if (localModifiedAt.isAfter(remoteModifiedAt)) {
      return false;
    }
    return remoteSequence > localSequence;
  }

  Future<void> _mergeTask(CalendarTask remoteTask, String operation) async {
    final currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final localTask = currentModel.tasks[remoteTask.id];
        if (localTask == null) {
          updatedModel = currentModel.updateTask(remoteTask);
          break;
        }
        final bool preferRemote = _shouldPreferRemote(
          localModifiedAt: localTask.modifiedAt,
          remoteModifiedAt: remoteTask.modifiedAt,
          localSequence:
              localTask.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              remoteTask.icsMeta?.sequence ?? _calendarSequenceDefault,
        );
        if (preferRemote) {
          updatedModel = currentModel.updateTask(remoteTask);
        } else {
          return;
        }
        break;
      case _calendarSyncOperationDelete:
        final existing = currentModel.tasks[remoteTask.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteTask.modifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                remoteTask.icsMeta?.sequence ?? _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return;
          }
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
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final DayEvent? localEvent = currentModel.dayEvents[remoteEvent.id];
        if (localEvent == null) {
          updatedModel = currentModel.addDayEvent(remoteEvent);
        } else if (_shouldPreferRemote(
          localModifiedAt: localEvent.modifiedAt,
          remoteModifiedAt: remoteEvent.modifiedAt,
          localSequence:
              localEvent.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              remoteEvent.icsMeta?.sequence ?? _calendarSequenceDefault,
        )) {
          updatedModel = currentModel.updateDayEvent(remoteEvent);
        } else {
          return;
        }
        break;
      case _calendarSyncOperationDelete:
        final DayEvent? existing = currentModel.dayEvents[remoteEvent.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteEvent.modifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                remoteEvent.icsMeta?.sequence ?? _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return;
          }
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
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final localPath = currentModel.criticalPaths[remotePath.id];
        if (localPath == null) {
          updatedModel = currentModel.addCriticalPath(remotePath);
        } else if (remotePath.modifiedAt.isAfter(localPath.modifiedAt)) {
          updatedModel = currentModel.updateCriticalPath(remotePath);
        } else {
          return;
        }
        break;
      case _calendarSyncOperationDelete:
        final existing = currentModel.criticalPaths[remotePath.id];
        if (existing != null &&
            existing.modifiedAt.isAfter(remotePath.modifiedAt)) {
          return;
        }
        updatedModel = currentModel.removeCriticalPath(remotePath.id);
        break;
      default:
        developer.log('Unknown critical path operation: $operation');
        return;
    }

    await _applyModel(updatedModel);
  }

  Future<void> _mergeJournal(
    CalendarJournal remoteJournal,
    String operation,
  ) async {
    final CalendarModel currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final CalendarJournal? localJournal =
            currentModel.journals[remoteJournal.id];
        if (localJournal == null) {
          updatedModel = currentModel.addJournal(remoteJournal);
        } else if (_shouldPreferRemote(
          localModifiedAt: localJournal.modifiedAt,
          remoteModifiedAt: remoteJournal.modifiedAt,
          localSequence:
              localJournal.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              remoteJournal.icsMeta?.sequence ?? _calendarSequenceDefault,
        )) {
          updatedModel = currentModel.updateJournal(remoteJournal);
        } else {
          return;
        }
        break;
      case _calendarSyncOperationDelete:
        final CalendarJournal? existing =
            currentModel.journals[remoteJournal.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteJournal.modifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                remoteJournal.icsMeta?.sequence ?? _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return;
          }
        }
        updatedModel = currentModel.deleteJournal(remoteJournal.id);
        break;
      default:
        developer.log('Unknown journal operation: $operation');
        return;
    }

    await _applyModel(updatedModel);
  }

  String _snapshotAttachmentName(File file) {
    final candidate = p.basename(file.path).trim();
    return candidate.isNotEmpty ? candidate : _snapshotFallbackName;
  }

  Future<void> _sendEnvelope(
    CalendarSyncOutbound outbound, {
    int clearQueueUntil = 0,
  }) async {
    try {
      await _flushPendingEnvelopes();
      await _sendCalendarMessage(outbound);
      _clearPendingUpTo(clearQueueUntil);
      if (_pendingEnvelopes.isNotEmpty) {
        await _flushPendingEnvelopes();
      }
    } catch (_) {
      _pendingEnvelopes.add(outbound);
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
