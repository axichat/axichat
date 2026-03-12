// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
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
const Duration _calendarSyncBatchInterval = Duration(
  seconds: _calendarSyncBatchIntervalSeconds,
);
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
const Duration _calendarSyncFutureTimestampTolerance = Duration(minutes: 2);

class CalendarSyncManager {
  CalendarSyncManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
    required Future<void> Function(CalendarSyncOutbound) sendCalendarMessage,
    Future<CalendarSnapshotUploadResult> Function(File file)? sendSnapshotFile,
    CalendarSyncState Function()? readSyncState,
    Future<void> Function(CalendarSyncState)? writeSyncState,
  }) : _readModel = readModel,
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
  final ListQueue<CalendarSyncOutbound> _pendingEnvelopes =
      ListQueue<CalendarSyncOutbound>();
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
            'Unknown calendar sync message type: ${message.type}',
          );
          throw CalendarSyncException(
            'Unknown sync message type: ${message.type}',
          );
      }
    } catch (e) {
      SafeLogging.debugLog(
        'Error handling calendar message: $e',
        name: 'CalendarSyncManager',
      );
      if (e is CalendarException) {
        rethrow;
      }
      throw CalendarSyncException(
        'Failed to process sync message',
        e.toString(),
      );
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
        final CalendarSyncState state = _stateWithAdvancedCursor(
          _readSyncState().resetCounter().copyWith(
            lastSnapshotChecksum: snapshotChecksum,
          ),
          inbound,
        );
        await _writeSyncState(state);
        return true;
      }

      final mergedModel = _normalizeModelForSync(
        localModel.mergeWith(remoteModel),
      );
      await _applyModel(mergedModel);

      final CalendarSyncState state = _stateWithAdvancedCursor(
        _readSyncState().resetCounter().copyWith(
          lastSnapshotChecksum: snapshotChecksum,
        ),
        inbound,
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
      SafeLogging.debugLog(
        'Error handling request message: $e',
        name: 'CalendarSyncManager',
      );
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
        await _recordAppliedMessage(inbound: inbound);
        return true;
      }

      SafeLogging.debugLog(
        'Calendar conflict detected - merging models (local: $localChecksum, remote: $remoteChecksum)',
      );
      final mergedModel = _normalizeModelForSync(
        localModel.mergeWith(remoteModel),
      );
      await _applyModel(mergedModel);
      await _recordAppliedMessage(inbound: inbound);
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
          final CalendarJournal journal = CalendarJournal.fromJson(
            message.data!,
          );
          applied = await _mergeJournal(journal, operation);
          break;
        default:
          final task = CalendarTask.fromJson(message.data!);
          applied = await _mergeTask(task, operation);
          break;
      }

      if (applied) {
        await _incrementCounterAndMaybeSnapshot(
          allowSnapshot: !inbound.isFromMam,
        );
        await _recordAppliedMessage(inbound: inbound);
      }
      return applied;
    } catch (e) {
      SafeLogging.debugLog('Error handling calendar update: $e');
    }
    return false;
  }

  /// Records that a message was applied, updating the sync state.
  Future<void> _recordAppliedMessage({
    required CalendarSyncInbound inbound,
  }) async {
    final CalendarSyncState previous = _readSyncState();
    final CalendarSyncState state = _stateWithAdvancedCursor(previous, inbound);
    if (state == previous) {
      return;
    }
    await _writeSyncState(state);
  }

  CalendarSyncState _stateWithAdvancedCursor(
    CalendarSyncState state,
    CalendarSyncInbound inbound,
  ) {
    final DateTime? rawPrevious = state.lastAppliedTimestamp;
    final DateTime? previous = rawPrevious == null
        ? null
        : _boundSyncInstant(rawPrevious);
    final CalendarSyncState normalizedState =
        previous == null ||
            (rawPrevious != null &&
                _compareSyncInstants(previous, rawPrevious) == 0)
        ? state
        : state.copyWith(lastAppliedTimestamp: previous);
    final DateTime candidate = _trustedInboundCursorTimestamp(inbound);
    if (previous != null && !_isSyncInstantAfter(candidate, previous)) {
      return normalizedState;
    }
    return normalizedState.copyWith(
      lastAppliedTimestamp: candidate,
      lastAppliedStanzaId: inbound.stanzaId,
    );
  }

  DateTime _trustedInboundCursorTimestamp(CalendarSyncInbound inbound) {
    final DateTime trustedTimestamp = inbound.receivedAt == null
        ? _syncNowUtc()
        : inbound.receivedAt!.toUtc();
    return _boundSyncInstant(trustedTimestamp);
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
    final CalendarModel model = _normalizeModelForSync(_readModel());
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

        final messageJson = jsonEncode({'calendar_sync': syncMessage.toJson()});

        await _sendCalendarMessage(
          CalendarSyncOutbound(envelope: messageJson, attachment: attachment),
        );

        final state = _readSyncState().resetCounter().copyWith(
          lastSnapshotChecksum: result.checksum,
        );
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
      SafeLogging.debugLog(
        'Error sending snapshot: $e',
        name: 'CalendarSyncManager',
      );
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
        timestamp: _syncNowUtc(),
        data: model.toJson(),
        checksum: checksum,
        isSnapshot: true,
        snapshotChecksum: checksum,
        snapshotVersion: CalendarSnapshotCodec.currentVersion,
      );

      final messageJson = jsonEncode({'calendar_sync': syncMessage.toJson()});

      await _sendCalendarMessage(CalendarSyncOutbound(envelope: messageJson));

      final state = _readSyncState().resetCounter().copyWith(
        lastSnapshotChecksum: checksum,
      );
      await _writeSyncState(state);

      SafeLogging.debugLog(
        '$_inlineSnapshotSentLog (checksum: $checksum)',
        name: 'CalendarSyncManager',
      );
      return true;
    } catch (e) {
      SafeLogging.debugLog(
        '$_inlineSnapshotFailedLog: $e',
        name: 'CalendarSyncManager',
      );
    }
    return false;
  }

  /// Send task update to other devices
  Future<void> sendTaskUpdate(CalendarTask task, String operation) async {
    final CalendarTask normalizedTask = _normalizeTaskForSync(task);
    _queueUpdate(
      payloadId: normalizedTask.id,
      operation: operation,
      timestamp: _resolveRemoteModifiedAt(normalizedTask.modifiedAt),
      data: normalizedTask.toJson(),
      entity: _calendarSyncEntityTask,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  Future<void> sendDayEventUpdate(DayEvent event, String operation) async {
    final DayEvent normalizedEvent = _normalizeDayEventForSync(event);
    _queueUpdate(
      payloadId: normalizedEvent.id,
      operation: operation,
      timestamp: _resolveRemoteModifiedAt(normalizedEvent.modifiedAt),
      data: normalizedEvent.toJson(),
      entity: _calendarSyncEntityDayEvent,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  Future<void> sendJournalUpdate(
    CalendarJournal journal,
    String operation,
  ) async {
    final CalendarJournal normalizedJournal = _normalizeJournalForSync(journal);
    _queueUpdate(
      payloadId: normalizedJournal.id,
      operation: operation,
      timestamp: _resolveRemoteModifiedAt(normalizedJournal.modifiedAt),
      data: normalizedJournal.toJson(),
      entity: _calendarSyncEntityJournal,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  /// Send critical path update to other devices
  Future<void> sendCriticalPathUpdate(
    CalendarCriticalPath path,
    String operation,
  ) async {
    final CalendarCriticalPath normalizedPath = _normalizePathForSync(path);
    _queueUpdate(
      payloadId: normalizedPath.id,
      operation: operation,
      timestamp: _resolveRemoteModifiedAt(normalizedPath.modifiedAt),
      data: normalizedPath.toJson(),
      entity: _calendarSyncEntityCriticalPath,
    );
    await _incrementCounterAndMaybeSnapshot(allowSnapshot: true);
  }

  /// Request a calendar snapshot from other devices.
  Future<void> requestFullSync() async {
    await _flushPendingEnvelopes();
    final syncMessage = CalendarSyncMessage.request();

    final messageJson = jsonEncode({'calendar_sync': syncMessage.toJson()});
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
    required DateTime timestamp,
    required Map<String, dynamic> data,
    required String entity,
  }) {
    final CalendarSyncMessage syncMessage = CalendarSyncMessage(
      type: CalendarSyncType.update,
      timestamp: _normalizeSyncInstant(timestamp),
      taskId: payloadId,
      operation: operation,
      data: data,
      entity: entity.trim().isEmpty ? _calendarSyncEntityTask : entity,
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
    final int timestampComparison = _compareSyncInstants(
      remoteModifiedAt,
      localModifiedAt,
    );
    if (timestampComparison > 0) {
      return true;
    }
    if (timestampComparison < 0) {
      return false;
    }
    return remoteSequence > localSequence;
  }

  Future<bool> _mergeTask(CalendarTask remoteTask, String operation) async {
    final CalendarModel currentModel = _readModel();
    final CalendarTask normalizedRemoteTask = _normalizeTaskForSync(remoteTask);
    final DateTime remoteModifiedAt = _resolveRemoteModifiedAt(
      normalizedRemoteTask.modifiedAt,
    );
    final CalendarTask resolvedRemoteTask =
        _compareSyncInstants(
              normalizedRemoteTask.modifiedAt,
              remoteModifiedAt,
            ) ==
            0
        ? normalizedRemoteTask
        : normalizedRemoteTask.copyWith(modifiedAt: remoteModifiedAt);

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final CalendarTask? localTask =
            currentModel.tasks[resolvedRemoteTask.id];
        if (localTask == null) {
          final DateTime? deletedAt =
              currentModel.deletedTaskIds[resolvedRemoteTask.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
          CalendarModel baseModel = currentModel;
          if (deletedAt != null) {
            final Map<String, DateTime> updatedDeletedTaskIds =
                Map<String, DateTime>.from(currentModel.deletedTaskIds)
                  ..remove(resolvedRemoteTask.id);
            baseModel = currentModel.copyWith(
              deletedTaskIds: updatedDeletedTaskIds,
            );
          }
          updatedModel = baseModel.addTask(resolvedRemoteTask);
          break;
        }
        final bool preferRemote = _shouldPreferRemote(
          localModifiedAt: localTask.modifiedAt,
          remoteModifiedAt: remoteModifiedAt,
          localSequence:
              localTask.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              resolvedRemoteTask.icsMeta?.sequence ?? _calendarSequenceDefault,
        );
        if (preferRemote) {
          updatedModel = currentModel.updateTask(resolvedRemoteTask);
        } else {
          return false;
        }
        break;
      case _calendarSyncOperationDelete:
        final CalendarTask? existing =
            currentModel.tasks[resolvedRemoteTask.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteModifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                resolvedRemoteTask.icsMeta?.sequence ??
                _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return false;
          }
        } else {
          final DateTime? deletedAt =
              currentModel.deletedTaskIds[resolvedRemoteTask.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
        }
        CalendarModel baseModel = existing == null
            ? currentModel
            : currentModel.deleteTask(resolvedRemoteTask.id);
        if (existing != null) {
          baseModel = baseModel.copyWith(
            deletedTaskIds: Map<String, DateTime>.from(baseModel.deletedTaskIds)
              ..remove(resolvedRemoteTask.id),
          );
        }
        updatedModel = _withTaskTombstone(
          baseModel,
          resolvedRemoteTask.id,
          remoteModifiedAt,
        );
        if (identical(updatedModel, currentModel)) {
          return false;
        }
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
    final DayEvent normalizedRemoteEvent = _normalizeDayEventForSync(
      remoteEvent,
    );
    final DateTime remoteModifiedAt = _resolveRemoteModifiedAt(
      normalizedRemoteEvent.modifiedAt,
    );
    final DayEvent resolvedRemoteEvent =
        _compareSyncInstants(
              normalizedRemoteEvent.modifiedAt,
              remoteModifiedAt,
            ) ==
            0
        ? normalizedRemoteEvent
        : normalizedRemoteEvent.copyWith(modifiedAt: remoteModifiedAt);

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final DayEvent? localEvent =
            currentModel.dayEvents[resolvedRemoteEvent.id];
        if (localEvent == null) {
          final DateTime? deletedAt =
              currentModel.deletedDayEventIds[resolvedRemoteEvent.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
          CalendarModel baseModel = currentModel;
          if (deletedAt != null) {
            final Map<String, DateTime> updatedDeletedDayEventIds =
                Map<String, DateTime>.from(currentModel.deletedDayEventIds)
                  ..remove(resolvedRemoteEvent.id);
            baseModel = currentModel.copyWith(
              deletedDayEventIds: updatedDeletedDayEventIds,
            );
          }
          updatedModel = baseModel.addDayEvent(resolvedRemoteEvent);
        } else if (_shouldPreferRemote(
          localModifiedAt: localEvent.modifiedAt,
          remoteModifiedAt: remoteModifiedAt,
          localSequence:
              localEvent.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              resolvedRemoteEvent.icsMeta?.sequence ?? _calendarSequenceDefault,
        )) {
          updatedModel = currentModel.updateDayEvent(resolvedRemoteEvent);
        } else {
          return false;
        }
        break;
      case _calendarSyncOperationDelete:
        final DayEvent? existing =
            currentModel.dayEvents[resolvedRemoteEvent.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteModifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                resolvedRemoteEvent.icsMeta?.sequence ??
                _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return false;
          }
        } else {
          final DateTime? deletedAt =
              currentModel.deletedDayEventIds[resolvedRemoteEvent.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
        }
        CalendarModel baseModel = existing == null
            ? currentModel
            : currentModel.deleteDayEvent(resolvedRemoteEvent.id);
        if (existing != null) {
          baseModel = baseModel.copyWith(
            deletedDayEventIds: Map<String, DateTime>.from(
              baseModel.deletedDayEventIds,
            )..remove(resolvedRemoteEvent.id),
          );
        }
        updatedModel = _withDayEventTombstone(
          baseModel,
          resolvedRemoteEvent.id,
          remoteModifiedAt,
        );
        if (identical(updatedModel, currentModel)) {
          return false;
        }
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
    final CalendarModel currentModel = _readModel();
    final CalendarCriticalPath normalizedRemotePath = _normalizePathForSync(
      remotePath,
    );
    final DateTime remoteModifiedAt = _resolveRemoteModifiedAt(
      normalizedRemotePath.modifiedAt,
    );
    final CalendarCriticalPath resolvedRemotePath =
        _compareSyncInstants(
              normalizedRemotePath.modifiedAt,
              remoteModifiedAt,
            ) ==
            0
        ? normalizedRemotePath
        : normalizedRemotePath.copyWith(modifiedAt: remoteModifiedAt);

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final CalendarCriticalPath? localPath =
            currentModel.criticalPaths[resolvedRemotePath.id];
        if (localPath == null) {
          final DateTime? deletedAt =
              currentModel.deletedCriticalPathIds[resolvedRemotePath.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
          CalendarModel baseModel = currentModel;
          if (deletedAt != null) {
            final Map<String, DateTime> updatedDeletedCriticalPathIds =
                Map<String, DateTime>.from(currentModel.deletedCriticalPathIds)
                  ..remove(resolvedRemotePath.id);
            baseModel = currentModel.copyWith(
              deletedCriticalPathIds: updatedDeletedCriticalPathIds,
            );
          }
          updatedModel = baseModel.addCriticalPath(resolvedRemotePath);
        } else if (_isSyncInstantAfter(
          remoteModifiedAt,
          localPath.modifiedAt,
        )) {
          updatedModel = currentModel.updateCriticalPath(resolvedRemotePath);
        } else {
          return false;
        }
        break;
      case _calendarSyncOperationDelete:
        final CalendarCriticalPath? existing =
            currentModel.criticalPaths[resolvedRemotePath.id];
        if (existing != null &&
            !_isSyncInstantAfter(remoteModifiedAt, existing.modifiedAt)) {
          return false;
        }
        if (existing == null) {
          final DateTime? deletedAt =
              currentModel.deletedCriticalPathIds[resolvedRemotePath.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
        }
        CalendarModel baseModel = currentModel;
        if (existing != null) {
          final Map<String, CalendarCriticalPath> updatedPaths =
              Map<String, CalendarCriticalPath>.from(currentModel.criticalPaths)
                ..[resolvedRemotePath.id] = existing.copyWith(
                  isArchived: true,
                  modifiedAt: remoteModifiedAt,
                );
          final CalendarModel changed = currentModel.copyWith(
            criticalPaths: updatedPaths,
            lastModified: _syncNowUtc(),
          );
          baseModel = changed.copyWith(checksum: changed.calculateChecksum());
        }
        updatedModel = _withCriticalPathTombstone(
          baseModel,
          resolvedRemotePath.id,
          remoteModifiedAt,
        );
        if (identical(updatedModel, currentModel)) {
          return false;
        }
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
    final CalendarJournal normalizedRemoteJournal = _normalizeJournalForSync(
      remoteJournal,
    );
    final DateTime remoteModifiedAt = _resolveRemoteModifiedAt(
      normalizedRemoteJournal.modifiedAt,
    );
    final CalendarJournal resolvedRemoteJournal =
        _compareSyncInstants(
              normalizedRemoteJournal.modifiedAt,
              remoteModifiedAt,
            ) ==
            0
        ? normalizedRemoteJournal
        : normalizedRemoteJournal.copyWith(modifiedAt: remoteModifiedAt);

    CalendarModel updatedModel;
    switch (operation) {
      case _calendarSyncOperationAdd:
      case _calendarSyncOperationUpdate:
        final CalendarJournal? localJournal =
            currentModel.journals[resolvedRemoteJournal.id];
        if (localJournal == null) {
          final DateTime? deletedAt =
              currentModel.deletedJournalIds[resolvedRemoteJournal.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
          CalendarModel baseModel = currentModel;
          if (deletedAt != null) {
            final Map<String, DateTime> updatedDeletedJournalIds =
                Map<String, DateTime>.from(currentModel.deletedJournalIds)
                  ..remove(resolvedRemoteJournal.id);
            baseModel = currentModel.copyWith(
              deletedJournalIds: updatedDeletedJournalIds,
            );
          }
          updatedModel = baseModel.addJournal(resolvedRemoteJournal);
        } else if (_shouldPreferRemote(
          localModifiedAt: localJournal.modifiedAt,
          remoteModifiedAt: remoteModifiedAt,
          localSequence:
              localJournal.icsMeta?.sequence ?? _calendarSequenceDefault,
          remoteSequence:
              resolvedRemoteJournal.icsMeta?.sequence ??
              _calendarSequenceDefault,
        )) {
          updatedModel = currentModel.updateJournal(resolvedRemoteJournal);
        } else {
          return false;
        }
        break;
      case _calendarSyncOperationDelete:
        final CalendarJournal? existing =
            currentModel.journals[resolvedRemoteJournal.id];
        if (existing != null) {
          final bool preferRemote = _shouldPreferRemote(
            localModifiedAt: existing.modifiedAt,
            remoteModifiedAt: remoteModifiedAt,
            localSequence:
                existing.icsMeta?.sequence ?? _calendarSequenceDefault,
            remoteSequence:
                resolvedRemoteJournal.icsMeta?.sequence ??
                _calendarSequenceDefault,
          );
          if (!preferRemote) {
            return false;
          }
        } else {
          final DateTime? deletedAt =
              currentModel.deletedJournalIds[resolvedRemoteJournal.id];
          if (deletedAt != null &&
              !_isSyncInstantAfter(remoteModifiedAt, deletedAt)) {
            return false;
          }
        }
        CalendarModel baseModel = existing == null
            ? currentModel
            : currentModel.deleteJournal(resolvedRemoteJournal.id);
        if (existing != null) {
          baseModel = baseModel.copyWith(
            deletedJournalIds: Map<String, DateTime>.from(
              baseModel.deletedJournalIds,
            )..remove(resolvedRemoteJournal.id),
          );
        }
        updatedModel = _withJournalTombstone(
          baseModel,
          resolvedRemoteJournal.id,
          remoteModifiedAt,
        );
        if (identical(updatedModel, currentModel)) {
          return false;
        }
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

  Future<void> _onBatchTimerTick(Timer timer) async {
    if (_pendingEnvelopes.isEmpty) {
      _stopBatchTimer();
      return;
    }
    try {
      await _flushPendingEnvelopes();
    } catch (error, stackTrace) {
      _logBatchFlushError(error, stackTrace);
    }
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
        _pendingEnvelopes.removeFirst();
      }
    } finally {
      _pendingFlush = null;
      if (_pendingEnvelopes.isEmpty) {
        _stopBatchTimer();
      }
    }
  }
}

DateTime _syncNowUtc() => DateTime.now().toUtc();

DateTime _normalizeSyncInstant(DateTime value) => value.toUtc();

int _compareSyncInstants(DateTime first, DateTime second) {
  final int firstMicros = _normalizeSyncInstant(first).microsecondsSinceEpoch;
  final int secondMicros = _normalizeSyncInstant(second).microsecondsSinceEpoch;
  if (firstMicros > secondMicros) {
    return 1;
  }
  if (firstMicros < secondMicros) {
    return -1;
  }
  return 0;
}

bool _isSyncInstantAfter(DateTime candidate, DateTime reference) =>
    _compareSyncInstants(candidate, reference) > 0;

DateTime _boundSyncInstant(DateTime value) {
  final DateTime normalized = _normalizeSyncInstant(value);
  final DateTime now = _syncNowUtc();
  final DateTime maxFuture = now.add(_calendarSyncFutureTimestampTolerance);
  if (_isSyncInstantAfter(normalized, maxFuture)) {
    return now;
  }
  return normalized;
}

DateTime _resolveRemoteModifiedAt(DateTime entityModifiedAt) =>
    _normalizeSyncInstant(entityModifiedAt);

CalendarIcsMeta? _normalizeIcsMetaForSync(CalendarIcsMeta? meta) {
  if (meta == null) {
    return null;
  }
  return meta.copyWith(
    dtStamp: meta.dtStamp == null ? null : _normalizeSyncInstant(meta.dtStamp!),
    created: meta.created == null ? null : _normalizeSyncInstant(meta.created!),
    lastModified: meta.lastModified == null
        ? null
        : _normalizeSyncInstant(meta.lastModified!),
  );
}

CalendarTask _normalizeTaskForSync(CalendarTask task) {
  return task.copyWith(
    createdAt: _normalizeSyncInstant(task.createdAt),
    modifiedAt: _normalizeSyncInstant(task.modifiedAt),
    icsMeta: _normalizeIcsMetaForSync(task.icsMeta),
  );
}

DayEvent _normalizeDayEventForSync(DayEvent event) {
  return event.copyWith(
    createdAt: _normalizeSyncInstant(event.createdAt),
    modifiedAt: _normalizeSyncInstant(event.modifiedAt),
    icsMeta: _normalizeIcsMetaForSync(event.icsMeta),
  );
}

CalendarJournal _normalizeJournalForSync(CalendarJournal journal) {
  return journal.copyWith(
    createdAt: _normalizeSyncInstant(journal.createdAt),
    modifiedAt: _normalizeSyncInstant(journal.modifiedAt),
    icsMeta: _normalizeIcsMetaForSync(journal.icsMeta),
  );
}

CalendarCriticalPath _normalizePathForSync(CalendarCriticalPath path) {
  return path.copyWith(
    createdAt: _normalizeSyncInstant(path.createdAt),
    modifiedAt: _normalizeSyncInstant(path.modifiedAt),
  );
}

CalendarAvailability _normalizeAvailabilityForSync(CalendarAvailability value) {
  return value.copyWith(icsMeta: _normalizeIcsMetaForSync(value.icsMeta));
}

Map<String, DateTime> _normalizeTimestampMap(Map<String, DateTime> source) {
  final Map<String, DateTime> normalized = <String, DateTime>{};
  for (final MapEntry<String, DateTime> entry in source.entries) {
    normalized[entry.key] = _normalizeSyncInstant(entry.value);
  }
  return normalized;
}

CalendarModel _normalizeModelForSync(CalendarModel model) {
  final Map<String, CalendarTask> normalizedTasks = <String, CalendarTask>{};
  for (final MapEntry<String, CalendarTask> entry in model.tasks.entries) {
    normalizedTasks[entry.key] = _normalizeTaskForSync(entry.value);
  }
  final Map<String, DayEvent> normalizedDayEvents = <String, DayEvent>{};
  for (final MapEntry<String, DayEvent> entry in model.dayEvents.entries) {
    normalizedDayEvents[entry.key] = _normalizeDayEventForSync(entry.value);
  }
  final Map<String, CalendarJournal> normalizedJournals =
      <String, CalendarJournal>{};
  for (final MapEntry<String, CalendarJournal> entry
      in model.journals.entries) {
    normalizedJournals[entry.key] = _normalizeJournalForSync(entry.value);
  }
  final Map<String, CalendarCriticalPath> normalizedPaths =
      <String, CalendarCriticalPath>{};
  for (final MapEntry<String, CalendarCriticalPath> entry
      in model.criticalPaths.entries) {
    normalizedPaths[entry.key] = _normalizePathForSync(entry.value);
  }
  final Map<String, CalendarAvailability> normalizedAvailability =
      <String, CalendarAvailability>{};
  for (final MapEntry<String, CalendarAvailability> entry
      in model.availability.entries) {
    normalizedAvailability[entry.key] = _normalizeAvailabilityForSync(
      entry.value,
    );
  }

  final CalendarModel normalized = model.copyWith(
    tasks: normalizedTasks,
    dayEvents: normalizedDayEvents,
    journals: normalizedJournals,
    criticalPaths: normalizedPaths,
    availability: normalizedAvailability,
    deletedTaskIds: _normalizeTimestampMap(model.deletedTaskIds),
    deletedDayEventIds: _normalizeTimestampMap(model.deletedDayEventIds),
    deletedJournalIds: _normalizeTimestampMap(model.deletedJournalIds),
    deletedCriticalPathIds: _normalizeTimestampMap(
      model.deletedCriticalPathIds,
    ),
    lastModified: _normalizeSyncInstant(model.lastModified),
  );
  return normalized.copyWith(checksum: normalized.calculateChecksum());
}

CalendarModel _withTaskTombstone(
  CalendarModel model,
  String taskId,
  DateTime deletedAt,
) {
  final DateTime normalizedDeletedAt = _normalizeSyncInstant(deletedAt);
  final DateTime? existing = model.deletedTaskIds[taskId];
  if (existing != null && !_isSyncInstantAfter(normalizedDeletedAt, existing)) {
    return model;
  }
  final Map<String, DateTime> updatedDeletedTaskIds =
      Map<String, DateTime>.from(model.deletedTaskIds)
        ..[taskId] = normalizedDeletedAt;
  final CalendarModel updated = model.copyWith(
    deletedTaskIds: updatedDeletedTaskIds,
    lastModified: _syncNowUtc(),
  );
  return updated.copyWith(checksum: updated.calculateChecksum());
}

CalendarModel _withDayEventTombstone(
  CalendarModel model,
  String eventId,
  DateTime deletedAt,
) {
  final DateTime normalizedDeletedAt = _normalizeSyncInstant(deletedAt);
  final DateTime? existing = model.deletedDayEventIds[eventId];
  if (existing != null && !_isSyncInstantAfter(normalizedDeletedAt, existing)) {
    return model;
  }
  final Map<String, DateTime> updatedDeletedDayEventIds =
      Map<String, DateTime>.from(model.deletedDayEventIds)
        ..[eventId] = normalizedDeletedAt;
  final CalendarModel updated = model.copyWith(
    deletedDayEventIds: updatedDeletedDayEventIds,
    lastModified: _syncNowUtc(),
  );
  return updated.copyWith(checksum: updated.calculateChecksum());
}

CalendarModel _withJournalTombstone(
  CalendarModel model,
  String journalId,
  DateTime deletedAt,
) {
  final DateTime normalizedDeletedAt = _normalizeSyncInstant(deletedAt);
  final DateTime? existing = model.deletedJournalIds[journalId];
  if (existing != null && !_isSyncInstantAfter(normalizedDeletedAt, existing)) {
    return model;
  }
  final Map<String, DateTime> updatedDeletedJournalIds =
      Map<String, DateTime>.from(model.deletedJournalIds)
        ..[journalId] = normalizedDeletedAt;
  final CalendarModel updated = model.copyWith(
    deletedJournalIds: updatedDeletedJournalIds,
    lastModified: _syncNowUtc(),
  );
  return updated.copyWith(checksum: updated.calculateChecksum());
}

CalendarModel _withCriticalPathTombstone(
  CalendarModel model,
  String pathId,
  DateTime deletedAt,
) {
  final DateTime normalizedDeletedAt = _normalizeSyncInstant(deletedAt);
  final DateTime? existing = model.deletedCriticalPathIds[pathId];
  if (existing != null && !_isSyncInstantAfter(normalizedDeletedAt, existing)) {
    return model;
  }
  final Map<String, DateTime> updatedDeletedPathIds =
      Map<String, DateTime>.from(model.deletedCriticalPathIds)
        ..[pathId] = normalizedDeletedAt;
  final CalendarModel updated = model.copyWith(
    deletedCriticalPathIds: updatedDeletedPathIds,
    lastModified: _syncNowUtc(),
  );
  return updated.copyWith(checksum: updated.calculateChecksum());
}
