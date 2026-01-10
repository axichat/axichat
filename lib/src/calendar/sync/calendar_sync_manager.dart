// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:axichat/src/calendar/models/calendar_exceptions.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/common/safe_logging.dart';

/// Threshold of updates before sending a snapshot.
const int kSnapshotThreshold = 50;
const int _calendarSyncBatchIntervalSeconds = 30;
const Duration _calendarSyncBatchInterval =
    Duration(seconds: _calendarSyncBatchIntervalSeconds);
const String _snapshotFallbackName =
    'calendar_snapshot${CalendarSnapshotCodec.fileExtension}';
const String _snapshotChecksumMismatchLog =
    'Snapshot checksum mismatch - ignoring snapshot';
const String _snapshotVersionUnsupportedLogPrefix =
    'Snapshot version unsupported - ignoring snapshot (version: ';
const String _snapshotVersionUnsupportedLogSuffix = ')';
const String _inlineSnapshotSentLog = 'Sent inline calendar snapshot';
const String _inlineSnapshotFailedLog = 'Error sending inline snapshot';
const String _batchFlushFailedLog = 'Failed to flush batched calendar updates';
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
  Timer? _batchFlushTimer;

  /// Handles an incoming calendar sync message.
  Future<bool> onCalendarMessage(CalendarSyncInbound inbound) async {
    final message = inbound.message;
    try {
      switch (message.type) {
        case CalendarSyncType.request:
          return await _handleRequestMessage(message);
        case CalendarSyncType.full:
          return await _handleFullMessage(message, inbound: inbound);
        case CalendarSyncType.update:
          return await _handleUpdateMessage(message, inbound: inbound);
        case CalendarSyncType.snapshot:
          return await _handleSnapshotMessage(message, inbound: inbound);
        default:
          SafeLogging.debugLog(
              'Unknown calendar sync message type: ${message.type}');
          throw CalendarSyncException(
              'Unknown sync message type: ${message.type}');
      }
    } catch (e) {
      SafeLogging.debugLog('Error handling calendar message: $e',
          name: 'CalendarSyncManager');
      if (e is CalendarException) {
        rethrow;
      }
      throw CalendarSyncException(
          'Failed to process sync message', e.toString());
    }
  }

  /// Handles a snapshot message by merging the attached model.
  Future<bool> _handleSnapshotMessage(
    CalendarSyncMessage message, {
    required CalendarSyncInbound inbound,
  }) async {
    if (message.data == null) return false;

    try {
      final int? snapshotVersion = message.snapshotVersion;
      if (snapshotVersion != null &&
          snapshotVersion > CalendarSnapshotCodec.currentVersion) {
        SafeLogging.debugLog(
          '$_snapshotVersionUnsupportedLogPrefix'
          '$snapshotVersion'
          '$_snapshotVersionUnsupportedLogSuffix',
          name: 'CalendarSyncManager',
        );
        return false;
      }
      final remoteModel = CalendarModel.fromJson(message.data!);
      final localModel = _readModel();
      final snapshotChecksum = message.snapshotChecksum ?? message.checksum;

      SafeLogging.debugLog(
        'Applying snapshot (checksum: ${message.snapshotChecksum})',
        name: 'CalendarSyncManager',
      );

      if (snapshotChecksum != null &&
          snapshotChecksum != remoteModel.calculateChecksum()) {
        SafeLogging.debugLog(
          _snapshotChecksumMismatchLog,
          name: 'CalendarSyncManager',
        );
        return false;
      }

      if (snapshotChecksum != null && localModel.checksum == snapshotChecksum) {
        final state = _readSyncState().resetCounter().copyWith(
              lastAppliedTimestamp: inbound.appliedTimestamp,
              lastAppliedStanzaId: inbound.stanzaId,
              lastSnapshotChecksum: snapshotChecksum,
            );
        await _writeSyncState(state);
        return true;
      }

      final mergedModel = localModel.mergeWith(remoteModel);
      await _applyModel(mergedModel);

      final state = _readSyncState().resetCounter().copyWith(
            lastAppliedTimestamp: inbound.appliedTimestamp,
            lastAppliedStanzaId: inbound.stanzaId,
            lastSnapshotChecksum: snapshotChecksum,
          );
      await _writeSyncState(state);
      return true;
    } catch (e) {
      SafeLogging.debugLog('Error handling snapshot message: $e');
    }
    return false;
  }

  Future<bool> _handleRequestMessage(CalendarSyncMessage message) async {
    try {
      await _flushPendingEnvelopes();
      return await _maybeSendSnapshot();
    } catch (e) {
      SafeLogging.debugLog('Error handling request message: $e',
          name: 'CalendarSyncManager');
      throw CalendarSyncException('Failed to send calendar data', e.toString());
    }
  }

  Future<bool> _handleFullMessage(
    CalendarSyncMessage message, {
    required CalendarSyncInbound inbound,
  }) async {
    if (message.data == null) return false;

    try {
      final remoteModel = CalendarModel.fromJson(message.data!);
      final localModel = _readModel();

      // Use checksum for conflict detection
      final localChecksum = _calculateChecksum(localModel.toJson());
      final remoteChecksum =
          message.checksum ?? _calculateChecksum(message.data!);

      if (localChecksum == remoteChecksum) {
        SafeLogging.debugLog('Calendars already in sync - no changes needed');
        await _recordAppliedMessage(message, inbound: inbound);
        return true;
      }

      SafeLogging.debugLog(
          'Calendar conflict detected - merging models (local: $localChecksum, remote: $remoteChecksum)');
      final mergedModel = localModel.mergeWith(remoteModel);
      await _applyModel(mergedModel);
      await _recordAppliedMessage(message, inbound: inbound);
      return true;
    } catch (e) {
      SafeLogging.debugLog('Error handling full calendar message: $e');
    }
    return false;
  }

  Future<bool> _handleUpdateMessage(
    CalendarSyncMessage message, {
    required CalendarSyncInbound inbound,
  }) async {
    if (message.data == null || message.taskId == null) return false;

    try {
      bool applied = false;
      final String operation =
          message.operation ?? _calendarSyncOperationUpdate;
      switch (message.entity) {
        case _calendarSyncEntityDayEvent:
          final DayEvent event = DayEvent.fromJson(message.data!);
          applied = await _mergeDayEvent(event, operation);
          break;
        case _calendarSyncEntityCriticalPath:
          final path = CalendarCriticalPath.fromJson(message.data!);
          applied = await _mergeCriticalPath(path, operation);
          break;
        case _calendarSyncEntityJournal:
          final CalendarJournal journal =
              CalendarJournal.fromJson(message.data!);
          applied = await _mergeJournal(journal, operation);
          break;
        default:
          final task = CalendarTask.fromJson(message.data!);
          applied = await _mergeTask(task, operation);
          break;
      }

      await _incrementCounterAndMaybeSnapshot(
        allowSnapshot: !inbound.isFromMam,
      );
      await _recordAppliedMessage(message, inbound: inbound);
      return applied;
    } catch (e) {
      SafeLogging.debugLog('Error handling calendar update: $e');
    }
    return false;
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
  Future<bool> _maybeSendSnapshot() async {
    final model = _readModel();
    if (!model.hasCalendarData) {
      return false;
    }

    final sendSnapshot = _sendSnapshotFile;
    if (sendSnapshot == null) {
      return _sendInlineSnapshot(model);
    }

    bool sent = false;
    try {
      final tempDir = await getTemporaryDirectory();
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

        SafeLogging.debugLog(
          'Sent calendar snapshot (checksum: ${result.checksum})',
          name: 'CalendarSyncManager',
        );
        sent = true;
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      SafeLogging.debugLog('Error sending snapshot: $e',
          name: 'CalendarSyncManager');
    }
    if (!sent) {
      return _sendInlineSnapshot(model);
    }
    return sent;
  }

  Future<bool> _sendInlineSnapshot(CalendarModel model) async {
    try {
      final checksum = CalendarSnapshotCodec.computeChecksum(model);
      final syncMessage = CalendarSyncMessage(
        type: CalendarSyncType.snapshot,
        timestamp: DateTime.now(),
        data: model.toJson(),
        checksum: checksum,
        isSnapshot: true,
        snapshotChecksum: checksum,
        snapshotVersion: CalendarSnapshotCodec.currentVersion,
      );

      final messageJson = jsonEncode({
        'calendar_sync': syncMessage.toJson(),
      });

      await _sendCalendarMessage(
        CalendarSyncOutbound(envelope: messageJson),
      );

      final state = _readSyncState()
          .resetCounter()
          .copyWith(lastSnapshotChecksum: checksum);
      await _writeSyncState(state);

      SafeLogging.debugLog(
        '$_inlineSnapshotSentLog (checksum: $checksum)',
        name: 'CalendarSyncManager',
      );
      return true;
    } catch (e) {
      SafeLogging.debugLog('$_inlineSnapshotFailedLog: $e',
          name: 'CalendarSyncManager');
    }
    return false;
  }

  /// Send task update to other devices
  Future<void> sendTaskUpdate(CalendarTask task, String operation) async {
    _queueUpdate(
      payloadId: task.id,
      operation: operation,
      data: task.toJson(),
      entity: _calendarSyncEntityTask,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  Future<void> sendDayEventUpdate(DayEvent event, String operation) async {
    _queueUpdate(
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
    _queueUpdate(
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
    _queueUpdate(
      payloadId: path.id,
      operation: operation,
      data: path.toJson(),
      entity: _calendarSyncEntityCriticalPath,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  /// Request a calendar snapshot from other devices.
  Future<void> requestFullSync() async {
    await _flushPendingEnvelopes();
    final syncMessage = CalendarSyncMessage.request();

    final messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    await _sendEnvelope(CalendarSyncOutbound(envelope: messageJson));
  }

  /// Push a calendar snapshot to other devices.
  Future<void> pushFullSync() async {
    await _flushPendingEnvelopes();
    await _maybeSendSnapshot();
  }

  void _queueUpdate({
    required String payloadId,
    required String operation,
    required Map<String, dynamic> data,
    required String entity,
  }) {
    final CalendarSyncMessage syncMessage = CalendarSyncMessage.update(
      taskId: payloadId,
      operation: operation,
      data: data,
      entity: entity,
    );

    final String messageJson = jsonEncode({
      'calendar_sync': syncMessage.toJson(),
    });
    _queueEnvelope(CalendarSyncOutbound(envelope: messageJson));
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

  Future<bool> _mergeTask(CalendarTask remoteTask, String operation) async {
    final currentModel = _readModel();

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final localTask = currentModel.tasks[remoteTask.id];
        if (localTask == null) {
          final DateTime? deletedAt =
              currentModel.deletedTaskIds[remoteTask.id];
          if (deletedAt != null && !remoteTask.modifiedAt.isAfter(deletedAt)) {
            return false;
          }
          final Map<String, DateTime> updatedDeletedTaskIds = deletedAt == null
              ? currentModel.deletedTaskIds
              : Map<String, DateTime>.from(currentModel.deletedTaskIds)
            ..remove(remoteTask.id);
          final CalendarModel baseModel = deletedAt == null
              ? currentModel
              : currentModel.copyWith(deletedTaskIds: updatedDeletedTaskIds);
          updatedModel = baseModel.addTask(remoteTask);
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
          return false;
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
            return false;
          }
        }
        updatedModel = currentModel.deleteTask(remoteTask.id);
        break;
      default:
        SafeLogging.debugLog('Unknown task operation: $operation');
        return false;
    }

    await _applyModel(updatedModel);
    return true;
  }

  Future<bool> _mergeDayEvent(DayEvent remoteEvent, String operation) async {
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
          return false;
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
            return false;
          }
        }
        updatedModel = currentModel.deleteDayEvent(remoteEvent.id);
        break;
      default:
        SafeLogging.debugLog('Unknown day event operation: $operation');
        return false;
    }

    await _applyModel(updatedModel);
    return true;
  }

  Future<bool> _mergeCriticalPath(
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
          return false;
        }
        break;
      case _calendarSyncOperationDelete:
        final existing = currentModel.criticalPaths[remotePath.id];
        if (existing != null &&
            existing.modifiedAt.isAfter(remotePath.modifiedAt)) {
          return false;
        }
        updatedModel = currentModel.removeCriticalPath(remotePath.id);
        break;
      default:
        SafeLogging.debugLog('Unknown critical path operation: $operation');
        return false;
    }

    await _applyModel(updatedModel);
    return true;
  }

  Future<bool> _mergeJournal(
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
          return false;
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
            return false;
          }
        }
        updatedModel = currentModel.deleteJournal(remoteJournal.id);
        break;
      default:
        SafeLogging.debugLog('Unknown journal operation: $operation');
        return false;
    }

    await _applyModel(updatedModel);
    return true;
  }

  String _snapshotAttachmentName(File file) {
    final candidate = p.basename(file.path).trim();
    return candidate.isNotEmpty ? candidate : _snapshotFallbackName;
  }

  void _queueEnvelope(CalendarSyncOutbound outbound) {
    _pendingEnvelopes.add(outbound);
    _ensureBatchTimer();
  }

  Future<void> _sendEnvelope(CalendarSyncOutbound outbound) async {
    try {
      await _sendCalendarMessage(outbound);
    } catch (_) {
      _queueEnvelope(outbound);
      rethrow;
    }
  }

  void _ensureBatchTimer() {
    if (_batchFlushTimer != null) {
      return;
    }
    _batchFlushTimer = Timer.periodic(
      _calendarSyncBatchInterval,
      _onBatchTimerTick,
    );
  }

  void _onBatchTimerTick(Timer timer) {
    if (_pendingEnvelopes.isEmpty) {
      _stopBatchTimer();
      return;
    }
    unawaited(_flushPendingEnvelopes().catchError(_logBatchFlushError));
  }

  void _stopBatchTimer() {
    _batchFlushTimer?.cancel();
    _batchFlushTimer = null;
  }

  void _logBatchFlushError(Object error, StackTrace stackTrace) {
    SafeLogging.debugLog(
      '$_batchFlushFailedLog: $error',
      name: 'CalendarSyncManager',
      stackTrace: stackTrace,
    );
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
      if (_pendingEnvelopes.isEmpty) {
        _stopBatchTimer();
      }
    }
  }
}
