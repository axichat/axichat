import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_snapshot_codec.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this.temporaryPath);

  final String temporaryPath;

  @override
  Future<String?> getTemporaryPath() async => temporaryPath;
}

Map<String, dynamic> _decodeEnvelope(CalendarSyncOutbound outbound) {
  final decoded = jsonDecode(outbound.envelope) as Map<String, dynamic>;
  return decoded['calendar_sync'] as Map<String, dynamic>;
}

Future<void> _useTemporaryPathProvider(String name) async {
  final directory = await Directory.systemTemp.createTemp(name);
  final previous = PathProviderPlatform.instance;
  PathProviderPlatform.instance = _FakePathProviderPlatform(directory.path);
  addTearDown(() async {
    PathProviderPlatform.instance = previous;
    await directory.delete(recursive: true);
  });
}

String _largeCalendarPayloadText() {
  var value = 0x12345678;
  final codeUnits = List<int>.generate(CalendarSyncMessage.maxEnvelopeLength, (
    _,
  ) {
    value = (value * 1103515245 + 12345) & 0x7fffffff;
    return 33 + value % 90;
  });
  return String.fromCharCodes(codeUnits);
}

void main() {
  CalendarSyncManager buildManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
    Future<void> Function(ChatPrimaryView primaryView)? applyRoomPrimaryView,
  }) {
    return CalendarSyncManager(
      readModel: readModel,
      applyModel: applyModel,
      sendCalendarMessage: (_) async {},
      applyRoomPrimaryView: applyRoomPrimaryView,
      readSyncState: () => const CalendarSyncState(),
      writeSyncState: (_) async {},
    );
  }

  group('CalendarSyncManager tombstone handling', () {
    const String taskId = 'remote-task';
    const String taskTitle = 'Remote Task';
    const String dayEventId = 'remote-day-event';
    const String dayEventTitle = 'Remote Day Event';
    const String journalId = 'remote-journal';
    const String journalTitle = 'Remote Journal';
    const String criticalPathId = 'remote-critical-path';
    const String criticalPathName = 'Remote Critical Path';
    const String addOperation = 'add';
    const String updateOperation = 'update';
    const String dayEventEntity = 'day_event';
    const String criticalPathEntity = 'critical_path';
    const String journalEntity = 'journal';
    const Duration tombstoneOffset = Duration(hours: 1);
    const Duration newerOffset = Duration(hours: 2);
    final DateTime deletedAt = DateTime.utc(2024, 2, 10, 12);

    test('ignores add when tombstone is newer than remote update', () async {
      final DateTime remoteModifiedAt = deletedAt.subtract(tombstoneOffset);
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: taskTitle,
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty().copyWith(
        deletedTaskIds: {taskId: deletedAt},
      );
      CalendarModel? appliedModel;
      int applyCalls = 0;

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          applyCalls += 1;
          appliedModel = next;
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: taskId,
        operation: addOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(applyCalls, equals(0));
      expect(appliedModel, isNull);
      expect(currentModel.tasks, isEmpty);
      expect(currentModel.deletedTaskIds, contains(taskId));
    });

    test(
      'applies room primary view updates without mutating calendar data',
      () async {
        CalendarModel currentModel = CalendarModel.empty();
        ChatPrimaryView? appliedPrimaryView;
        var applyModelCalls = 0;

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            applyModelCalls += 1;
            currentModel = next;
          },
          applyRoomPrimaryView: (ChatPrimaryView primaryView) async {
            appliedPrimaryView = primaryView;
          },
        );

        final bool applied = await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage.roomPrimaryViewUpdate(
              primaryView: ChatPrimaryView.calendar,
            ),
            receivedAt: DateTime.utc(2024, 2, 10, 13),
          ),
        );

        expect(applied, isTrue);
        expect(appliedPrimaryView, ChatPrimaryView.calendar);
        expect(applyModelCalls, equals(0));
        expect(currentModel.tasks, isEmpty);
        expect(currentModel.dayEvents, isEmpty);
        expect(currentModel.journals, isEmpty);
        expect(currentModel.criticalPaths, isEmpty);
      },
    );

    test('accepts add when remote update is newer than tombstone', () async {
      final DateTime remoteModifiedAt = deletedAt.add(newerOffset);
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: taskTitle,
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty().copyWith(
        deletedTaskIds: {taskId: deletedAt},
      );
      CalendarModel? appliedModel;
      int applyCalls = 0;

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          applyCalls += 1;
          appliedModel = next;
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: taskId,
        operation: addOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(applyCalls, equals(1));
      expect(appliedModel, isNotNull);
      expect(currentModel.tasks[taskId]?.title, equals(taskTitle));
      expect(currentModel.deletedTaskIds.containsKey(taskId), isFalse);
    });

    test('accepts task add when no tombstone exists', () async {
      final DateTime remoteModifiedAt = DateTime.utc(2024, 2, 10, 13);
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: taskTitle,
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty();

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: taskId,
        operation: addOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(currentModel.tasks[taskId]?.title, equals(taskTitle));
      expect(currentModel.deletedTaskIds, isEmpty);
    });

    test(
      'ignores day event add when day event tombstone is newer than remote update',
      () async {
        final DateTime remoteModifiedAt = deletedAt.subtract(tombstoneOffset);
        final DayEvent remoteEvent = DayEvent(
          id: dayEventId,
          title: dayEventTitle,
          startDate: remoteModifiedAt,
          endDate: remoteModifiedAt,
          createdAt: remoteModifiedAt,
          modifiedAt: remoteModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().copyWith(
          deletedDayEventIds: {dayEventId: deletedAt},
        );
        int applyCalls = 0;

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            applyCalls += 1;
            currentModel = next;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: remoteModifiedAt,
          taskId: dayEventId,
          operation: addOperation,
          entity: dayEventEntity,
          data: remoteEvent.toJson(),
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
        );

        expect(applyCalls, equals(0));
        expect(currentModel.dayEvents, isEmpty);
        expect(currentModel.deletedDayEventIds, contains(dayEventId));
      },
    );

    test('accepts day event add when no tombstone exists', () async {
      final DateTime remoteModifiedAt = DateTime.utc(2024, 2, 10, 13);
      final DayEvent remoteEvent = DayEvent(
        id: dayEventId,
        title: dayEventTitle,
        startDate: remoteModifiedAt,
        endDate: remoteModifiedAt,
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty();

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: dayEventId,
        operation: addOperation,
        entity: dayEventEntity,
        data: remoteEvent.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(currentModel.dayEvents[dayEventId]?.title, equals(dayEventTitle));
      expect(currentModel.deletedDayEventIds, isEmpty);
    });

    test('accepts critical path add when no tombstone exists', () async {
      final DateTime remoteModifiedAt = DateTime.utc(2024, 2, 10, 13);
      final CalendarCriticalPath remotePath = CalendarCriticalPath(
        id: criticalPathId,
        name: criticalPathName,
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty();

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: criticalPathId,
        operation: addOperation,
        entity: criticalPathEntity,
        data: remotePath.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(
        currentModel.criticalPaths[criticalPathId]?.name,
        equals(criticalPathName),
      );
      expect(currentModel.deletedCriticalPathIds, isEmpty);
    });

    test(
      'ignores journal add when journal tombstone is newer than remote update',
      () async {
        final DateTime remoteModifiedAt = deletedAt.subtract(tombstoneOffset);
        final CalendarJournal remoteJournal = CalendarJournal(
          id: journalId,
          title: journalTitle,
          entryDate: CalendarDateTime(value: remoteModifiedAt),
          createdAt: remoteModifiedAt,
          modifiedAt: remoteModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().copyWith(
          deletedJournalIds: {journalId: deletedAt},
        );
        int applyCalls = 0;

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            applyCalls += 1;
            currentModel = next;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: remoteModifiedAt,
          taskId: journalId,
          operation: addOperation,
          entity: journalEntity,
          data: remoteJournal.toJson(),
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
        );

        expect(applyCalls, equals(0));
        expect(currentModel.journals, isEmpty);
        expect(currentModel.deletedJournalIds, contains(journalId));
      },
    );

    test('accepts journal add when no tombstone exists', () async {
      final DateTime remoteModifiedAt = DateTime.utc(2024, 2, 10, 13);
      final CalendarJournal remoteJournal = CalendarJournal(
        id: journalId,
        title: journalTitle,
        entryDate: CalendarDateTime(value: remoteModifiedAt),
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty();

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: journalId,
        operation: addOperation,
        entity: journalEntity,
        data: remoteJournal.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(message: message, receivedAt: remoteModifiedAt),
      );

      expect(currentModel.journals[journalId]?.title, equals(journalTitle));
      expect(currentModel.deletedJournalIds, isEmpty);
    });

    test('ignores sender message timestamp when payload is stale', () async {
      final DateTime localModifiedAt = DateTime.utc(2024, 2, 10, 12);
      final DateTime payloadModifiedAt = localModifiedAt.subtract(
        const Duration(hours: 1),
      );
      final DateTime senderTimestamp = localModifiedAt.add(
        const Duration(minutes: 30),
      );
      final CalendarTask localTask = CalendarTask(
        id: taskId,
        title: 'Local title',
        createdAt: localModifiedAt,
        modifiedAt: localModifiedAt,
      );
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: 'Remote title',
        createdAt: payloadModifiedAt,
        modifiedAt: payloadModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty().addTask(localTask);

      final CalendarSyncManager manager = buildManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: senderTimestamp,
        taskId: taskId,
        operation: updateOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(CalendarSyncInbound(message: message));

      expect(currentModel.tasks[taskId]?.title, equals('Local title'));
    });
  });

  group('CalendarSyncManager timestamp safety', () {
    const String taskId = 'sync-task';
    const String updateOperation = 'update';

    test(
      'full sync does not delete local task when remote model omits it',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 3, 1, 12);
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
        );

        final CalendarModel remoteModel = CalendarModel.empty();
        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.full,
          timestamp: localModifiedAt.add(const Duration(minutes: 1)),
          data: remoteModel.toJson(),
          checksum: remoteModel.calculateChecksum(),
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));

        expect(currentModel.tasks[taskId]?.title, equals('Local title'));
        expect(currentModel.deletedTaskIds.containsKey(taskId), isFalse);
      },
    );

    test(
      'snapshot sync does not delete local task when remote model omits it',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 3, 1, 12);
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
        );

        final CalendarModel remoteModel = CalendarModel.empty();
        final String checksum = remoteModel.calculateChecksum();
        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.snapshot,
          timestamp: localModifiedAt.add(const Duration(minutes: 1)),
          data: remoteModel.toJson(),
          checksum: checksum,
          isSnapshot: true,
          snapshotChecksum: checksum,
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));

        expect(currentModel.tasks[taskId]?.title, equals('Local title'));
        expect(currentModel.deletedTaskIds.containsKey(taskId), isFalse);
      },
    );

    test('does not advance sync cursor when update was not applied', () async {
      final DateTime localModifiedAt = DateTime.utc(2024, 3, 1, 12);
      final DateTime remoteModifiedAt = localModifiedAt.subtract(
        const Duration(minutes: 10),
      );
      final CalendarTask localTask = CalendarTask(
        id: taskId,
        title: 'Local title',
        createdAt: localModifiedAt,
        modifiedAt: localModifiedAt,
      );
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: 'Remote stale title',
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty().addTask(localTask);
      CalendarSyncState syncState = CalendarSyncState(
        lastAppliedTimestamp: localModifiedAt.add(const Duration(minutes: 1)),
        lastAppliedStanzaId: 'newer-stanza',
      );

      final CalendarSyncManager manager = CalendarSyncManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.update,
        timestamp: remoteModifiedAt,
        taskId: taskId,
        operation: updateOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: message,
          receivedAt: remoteModifiedAt,
          isFromMam: true,
          stanzaId: 'older-stanza',
        ),
      );

      expect(currentModel.tasks[taskId]?.title, equals('Local title'));
      expect(
        syncState.lastAppliedTimestamp,
        equals(localModifiedAt.add(const Duration(minutes: 1))),
      );
      expect(syncState.lastAppliedStanzaId, equals('newer-stanza'));
    });

    test(
      'does not increment snapshot counter when update was not applied',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 3, 1, 12);
        final DateTime remoteModifiedAt = localModifiedAt.subtract(
          const Duration(minutes: 10),
        );
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );
        final CalendarTask remoteTask = CalendarTask(
          id: taskId,
          title: 'Remote stale title',
          createdAt: remoteModifiedAt,
          modifiedAt: remoteModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);
        CalendarSyncState syncState = const CalendarSyncState(
          updatesSinceSnapshot: 5,
        );

        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: remoteModifiedAt.add(const Duration(days: 365)),
          taskId: taskId,
          operation: updateOperation,
          data: remoteTask.toJson(),
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));

        expect(syncState.updatesSinceSnapshot, equals(5));
      },
    );

    test('keeps sync cursor monotonic when applying older message', () async {
      final DateTime currentCursor = DateTime.utc(2024, 3, 1, 12, 30);
      final DateTime remoteModifiedAt = DateTime.utc(2024, 3, 1, 12);
      final CalendarTask remoteTask = CalendarTask(
        id: taskId,
        title: 'Remote task',
        createdAt: remoteModifiedAt,
        modifiedAt: remoteModifiedAt,
      );

      CalendarModel currentModel = CalendarModel.empty();
      CalendarSyncState syncState = CalendarSyncState(
        lastAppliedTimestamp: currentCursor,
        lastAppliedStanzaId: 'latest',
      );

      final CalendarSyncManager manager = CalendarSyncManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      final CalendarModel remoteModel = CalendarModel.empty().addTask(
        remoteTask,
      );
      final CalendarSyncMessage message = CalendarSyncMessage(
        type: CalendarSyncType.full,
        timestamp: remoteModifiedAt,
        data: remoteModel.toJson(),
        checksum: remoteModel.calculateChecksum(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: message,
          receivedAt: remoteModifiedAt,
          isFromMam: true,
          stanzaId: 'older',
        ),
      );

      expect(currentModel.tasks[taskId]?.title, equals('Remote task'));
      expect(syncState.lastAppliedTimestamp, equals(currentCursor));
      expect(syncState.lastAppliedStanzaId, equals('latest'));
    });

    test(
      'ignores sender timestamp and keeps local when payload is older',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 3, 1, 12);
        final DateTime payloadModifiedAt = localModifiedAt.subtract(
          const Duration(hours: 1),
        );
        final DateTime senderTimestamp = localModifiedAt.add(
          const Duration(days: 365),
        );
        final DateTime receivedAt = localModifiedAt.subtract(
          const Duration(minutes: 1),
        );
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );
        final CalendarTask remoteTask = CalendarTask(
          id: taskId,
          title: 'Remote title',
          createdAt: payloadModifiedAt,
          modifiedAt: payloadModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: senderTimestamp,
          taskId: taskId,
          operation: updateOperation,
          data: remoteTask.toJson(),
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(message: message, receivedAt: receivedAt),
        );

        expect(currentModel.tasks[taskId]?.title, equals('Local title'));
      },
    );

    test(
      'ignores far-future sender timestamp when delayed timestamp is absent',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 1, 2, 12);
        final DateTime payloadModifiedAt = DateTime.utc(2024, 1, 1, 12);
        final DateTime senderTimestamp = DateTime.utc(2100, 1, 1, 12);
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );
        final CalendarTask remoteTask = CalendarTask(
          id: taskId,
          title: 'Remote title',
          createdAt: payloadModifiedAt,
          modifiedAt: payloadModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);

        final CalendarSyncManager manager = buildManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: senderTimestamp,
          taskId: taskId,
          operation: updateOperation,
          data: remoteTask.toJson(),
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));

        expect(currentModel.tasks[taskId]?.title, equals('Local title'));
      },
    );

    test(
      'does not advance cursor from sender timestamp when no delayed timestamp exists',
      () async {
        final DateTime nowBefore = DateTime.now().toUtc();
        final DateTime priorCursor = nowBefore.subtract(
          const Duration(hours: 1),
        );
        final DateTime localModifiedAt = nowBefore.subtract(
          const Duration(hours: 2),
        );
        final DateTime remoteModifiedAt = nowBefore.subtract(
          const Duration(minutes: 30),
        );
        final DateTime senderTimestamp = nowBefore.add(
          const Duration(seconds: 90),
        );
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local task',
          createdAt: localModifiedAt,
          modifiedAt: localModifiedAt,
        );
        final CalendarTask remoteTask = CalendarTask(
          id: taskId,
          title: 'Remote task',
          createdAt: remoteModifiedAt,
          modifiedAt: remoteModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);
        CalendarSyncState syncState = CalendarSyncState(
          lastAppliedTimestamp: priorCursor,
          lastAppliedStanzaId: 'prior',
        );

        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        final CalendarSyncMessage message = CalendarSyncMessage(
          type: CalendarSyncType.update,
          timestamp: senderTimestamp,
          taskId: taskId,
          operation: updateOperation,
          data: remoteTask.toJson(),
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));
        final DateTime nowAfter = DateTime.now().toUtc();

        expect(currentModel.tasks[taskId]?.title, equals('Remote task'));
        expect(syncState.lastAppliedTimestamp, isNotNull);
        expect(
          syncState.lastAppliedTimestamp!.isAfter(
            nowAfter.add(const Duration(seconds: 1)),
          ),
          isFalse,
        );
      },
    );
  });

  group('CalendarSyncManager out-of-order replay', () {
    const String taskId = 'out-of-order-task';
    const String addOperation = 'add';
    const String updateOperation = 'update';
    const String deleteOperation = 'delete';

    test(
      'keeps newer task update when an older envelope arrives later',
      () async {
        final DateTime olderModifiedAt = DateTime.utc(2024, 4, 1, 12);
        final DateTime newerModifiedAt = olderModifiedAt.add(
          const Duration(minutes: 10),
        );
        final CalendarTask olderTask = CalendarTask(
          id: taskId,
          title: 'Older title',
          createdAt: olderModifiedAt,
          modifiedAt: olderModifiedAt,
        );
        final CalendarTask newerTask = CalendarTask(
          id: taskId,
          title: 'Newer title',
          createdAt: olderModifiedAt,
          modifiedAt: newerModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: newerModifiedAt,
              taskId: taskId,
              operation: updateOperation,
              data: newerTask.toJson(),
            ),
            receivedAt: newerModifiedAt,
            isFromMam: true,
            stanzaId: 'newer-envelope',
          ),
        );
        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: olderModifiedAt,
              taskId: taskId,
              operation: updateOperation,
              data: olderTask.toJson(),
            ),
            receivedAt: olderModifiedAt,
            isFromMam: true,
            stanzaId: 'older-envelope',
          ),
        );

        expect(currentModel.tasks[taskId]?.title, equals('Newer title'));
        expect(syncState.lastHandledTimestamp, equals(newerModifiedAt));
        expect(syncState.lastHandledStanzaId, equals('newer-envelope'));
      },
    );

    test(
      'keeps newer tombstone when an older add arrives for a missing task',
      () async {
        final DateTime olderModifiedAt = DateTime.utc(2024, 4, 1, 12);
        final DateTime newerModifiedAt = olderModifiedAt.add(
          const Duration(minutes: 10),
        );
        final CalendarTask olderTask = CalendarTask(
          id: taskId,
          title: 'Older resurrected task',
          createdAt: olderModifiedAt,
          modifiedAt: olderModifiedAt,
        );
        final CalendarTask newerDeletedTask = CalendarTask(
          id: taskId,
          title: 'Deleted task',
          createdAt: olderModifiedAt,
          modifiedAt: newerModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: newerModifiedAt,
              taskId: taskId,
              operation: deleteOperation,
              data: newerDeletedTask.toJson(),
            ),
            receivedAt: newerModifiedAt,
            isFromMam: true,
            stanzaId: 'newer-delete',
          ),
        );
        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: olderModifiedAt,
              taskId: taskId,
              operation: addOperation,
              data: olderTask.toJson(),
            ),
            receivedAt: olderModifiedAt,
            isFromMam: true,
            stanzaId: 'older-add',
          ),
        );

        expect(currentModel.tasks.containsKey(taskId), isFalse);
        expect(currentModel.deletedTaskIds, contains(taskId));
        expect(syncState.lastHandledTimestamp, equals(newerModifiedAt));
        expect(syncState.lastHandledStanzaId, equals('newer-delete'));
      },
    );

    test(
      'keeps newer snapshot task when an older envelope arrives later',
      () async {
        final DateTime olderModifiedAt = DateTime.utc(2024, 4, 1, 12);
        final DateTime newerModifiedAt = olderModifiedAt.add(
          const Duration(minutes: 10),
        );
        final CalendarTask olderTask = CalendarTask(
          id: taskId,
          title: 'Older title',
          createdAt: olderModifiedAt,
          modifiedAt: olderModifiedAt,
        );
        final CalendarTask newerTask = CalendarTask(
          id: taskId,
          title: 'Newer snapshot title',
          createdAt: olderModifiedAt,
          modifiedAt: newerModifiedAt,
        );
        final CalendarModel snapshotModel = CalendarModel.empty().addTask(
          newerTask,
        );
        final String snapshotChecksum = snapshotModel.calculateChecksum();

        CalendarModel currentModel = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.snapshot,
              timestamp: newerModifiedAt,
              data: snapshotModel.toJson(),
              checksum: snapshotChecksum,
              isSnapshot: true,
              snapshotChecksum: snapshotChecksum,
            ),
            receivedAt: newerModifiedAt,
            isFromMam: true,
            stanzaId: 'newer-snapshot',
          ),
        );
        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: olderModifiedAt,
              taskId: taskId,
              operation: updateOperation,
              data: olderTask.toJson(),
            ),
            receivedAt: olderModifiedAt,
            isFromMam: true,
            stanzaId: 'older-envelope',
          ),
        );

        expect(
          currentModel.tasks[taskId]?.title,
          equals('Newer snapshot title'),
        );
        expect(syncState.lastHandledTimestamp, equals(newerModifiedAt));
        expect(syncState.lastHandledStanzaId, equals('newer-snapshot'));
      },
    );

    test('older snapshot cannot remove a newer task missing from it', () async {
      final DateTime olderModifiedAt = DateTime.utc(2024, 4, 1, 12);
      final DateTime newerModifiedAt = olderModifiedAt.add(
        const Duration(minutes: 10),
      );
      final CalendarTask newerTask = CalendarTask(
        id: taskId,
        title: 'Newer envelope title',
        createdAt: olderModifiedAt,
        modifiedAt: newerModifiedAt,
      );
      final CalendarModel olderSnapshotModel = CalendarModel.empty();
      final String snapshotChecksum = olderSnapshotModel.calculateChecksum();

      CalendarModel currentModel = CalendarModel.empty();
      CalendarSyncState syncState = const CalendarSyncState();
      final CalendarSyncManager manager = CalendarSyncManager(
        readModel: () => currentModel,
        applyModel: (CalendarModel next) async {
          currentModel = next;
        },
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: newerModifiedAt,
            taskId: taskId,
            operation: updateOperation,
            data: newerTask.toJson(),
          ),
          receivedAt: newerModifiedAt,
          isFromMam: true,
          stanzaId: 'newer-envelope',
        ),
      );
      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.snapshot,
            timestamp: olderModifiedAt,
            data: olderSnapshotModel.toJson(),
            checksum: snapshotChecksum,
            isSnapshot: true,
            snapshotChecksum: snapshotChecksum,
          ),
          receivedAt: olderModifiedAt,
          isFromMam: true,
          stanzaId: 'older-snapshot',
        ),
      );

      expect(currentModel.tasks[taskId]?.title, equals('Newer envelope title'));
      expect(syncState.lastHandledTimestamp, equals(newerModifiedAt));
      expect(syncState.lastHandledStanzaId, equals('newer-envelope'));
    });

    test(
      'records handled coverage for stale envelopes that do not mutate current data',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 4, 1, 12, 10);
        final DateTime remoteModifiedAt = DateTime.utc(2024, 4, 1, 12);
        final CalendarTask localTask = CalendarTask(
          id: taskId,
          title: 'Local title',
          createdAt: remoteModifiedAt,
          modifiedAt: localModifiedAt,
        );
        final CalendarTask remoteTask = CalendarTask(
          id: taskId,
          title: 'Remote stale title',
          createdAt: remoteModifiedAt,
          modifiedAt: remoteModifiedAt,
        );

        CalendarModel currentModel = CalendarModel.empty().addTask(localTask);
        CalendarSyncState syncState = const CalendarSyncState();
        final CalendarSyncManager manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: remoteModifiedAt,
              taskId: taskId,
              operation: updateOperation,
              data: remoteTask.toJson(),
            ),
            receivedAt: remoteModifiedAt,
            isFromMam: true,
            stanzaId: 'stale-envelope',
          ),
        );

        expect(currentModel.tasks[taskId]?.title, equals('Local title'));
        expect(syncState.lastHandledTimestamp, equals(remoteModifiedAt));
        expect(syncState.lastHandledStanzaId, equals('stale-envelope'));
        expect(
          syncState.coverageStatus,
          CalendarArchiveCoverageStatus.incomplete,
        );
      },
    );
  });

  group('Calendar sync cursor and retry safety', () {
    test('markHandled bounds far-future archive timestamps', () {
      final DateTime now = DateTime.now().toUtc();
      final DateTime farFuture = now.add(const Duration(days: 365));
      final state = const CalendarSyncState().markHandled(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.request,
            timestamp: farFuture,
          ),
          receivedAt: farFuture,
          stanzaId: 'future-envelope',
        ),
      );

      expect(state.lastHandledStanzaId, equals('future-envelope'));
      expect(state.lastHandledTimestamp, isNotNull);
      expect(
        state.lastHandledTimestamp!.isBefore(
          farFuture.subtract(const Duration(days: 1)),
        ),
        isTrue,
      );
    });

    test('markHandled clears stale stanza ids for idless envelopes', () {
      final DateTime olderTimestamp = DateTime.utc(2024, 5, 1, 12);
      final DateTime newerTimestamp = olderTimestamp.add(
        const Duration(minutes: 1),
      );
      final state =
          CalendarSyncState(
            lastAppliedTimestamp: olderTimestamp,
            lastAppliedStanzaId: 'older-envelope',
            lastHandledTimestamp: olderTimestamp,
            lastHandledStanzaId: 'older-envelope',
          ).markHandled(
            CalendarSyncInbound(
              message: CalendarSyncMessage(
                type: CalendarSyncType.request,
                timestamp: newerTimestamp,
              ),
              receivedAt: newerTimestamp,
              isFromMam: true,
            ),
          );

      expect(state.lastAppliedTimestamp, newerTimestamp);
      expect(state.lastAppliedStanzaId, isNull);
      expect(state.lastHandledTimestamp, newerTimestamp);
      expect(state.lastHandledStanzaId, isNull);
    });

    test(
      'advances stanza cursor for envelopes with the same timestamp',
      () async {
        final DateTime archiveTimestamp = DateTime.utc(2024, 5, 1, 12);
        CalendarModel currentModel = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final manager = CalendarSyncManager(
          readModel: () => currentModel,
          applyModel: (CalendarModel next) async {
            currentModel = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (CalendarSyncState state) async {
            syncState = state;
          },
        );

        CalendarSyncInbound inboundFor(String taskId, String stanzaId) {
          final task = CalendarTask(
            id: taskId,
            title: taskId,
            createdAt: archiveTimestamp,
            modifiedAt: archiveTimestamp,
          );
          return CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.update,
              timestamp: archiveTimestamp,
              taskId: taskId,
              operation: 'add',
              data: task.toJson(),
            ),
            receivedAt: archiveTimestamp,
            isFromMam: true,
            stanzaId: stanzaId,
          );
        }

        await manager.onCalendarMessage(inboundFor('first-task', 'first-id'));
        await manager.onCalendarMessage(inboundFor('second-task', 'second-id'));

        expect(syncState.lastHandledTimestamp, archiveTimestamp);
        expect(syncState.lastHandledStanzaId, 'second-id');
      },
    );

    test('records handled cursor for invalid update envelopes', () async {
      final DateTime archiveTimestamp = DateTime.utc(2024, 5, 1, 13);
      CalendarSyncState syncState = const CalendarSyncState();
      final manager = CalendarSyncManager(
        readModel: CalendarModel.empty,
        applyModel: (_) async {},
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      final applied = await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: archiveTimestamp,
            taskId: 'invalid-operation-task',
            operation: 'rename',
            data: const <String, dynamic>{'id': 'invalid-operation-task'},
          ),
          receivedAt: archiveTimestamp,
          isFromMam: true,
          stanzaId: 'invalid-update',
        ),
      );

      expect(applied, isFalse);
      expect(syncState.lastHandledTimestamp, archiveTimestamp);
      expect(syncState.lastHandledStanzaId, 'invalid-update');
    });

    test('records handled cursor for invalid update payloads', () async {
      final DateTime archiveTimestamp = DateTime.utc(2024, 5, 1, 13, 30);
      CalendarSyncState syncState = const CalendarSyncState();
      final manager = CalendarSyncManager(
        readModel: CalendarModel.empty,
        applyModel: (_) async {},
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      final applied = await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.update,
            timestamp: archiveTimestamp,
            taskId: 'invalid-payload-task',
            operation: 'update',
            data: const <String, dynamic>{'id': 'invalid-payload-task'},
          ),
          receivedAt: archiveTimestamp,
          isFromMam: true,
          stanzaId: 'invalid-update-payload',
        ),
      );

      expect(applied, isFalse);
      expect(syncState.lastHandledTimestamp, archiveTimestamp);
      expect(syncState.lastHandledStanzaId, 'invalid-update-payload');
    });

    test('records handled cursor for unsupported snapshots', () async {
      final DateTime archiveTimestamp = DateTime.utc(2024, 5, 1, 14);
      CalendarSyncState syncState = const CalendarSyncState();
      final manager = CalendarSyncManager(
        readModel: CalendarModel.empty,
        applyModel: (_) async {},
        sendCalendarMessage: (_) async {},
        readSyncState: () => syncState,
        writeSyncState: (CalendarSyncState state) async {
          syncState = state;
        },
      );

      final applied = await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: CalendarSyncMessage(
            type: CalendarSyncType.snapshot,
            timestamp: archiveTimestamp,
            data: CalendarModel.empty().toJson(),
            isSnapshot: true,
            snapshotVersion: 999,
          ),
          receivedAt: archiveTimestamp,
          isFromMam: true,
          stanzaId: 'unsupported-snapshot',
        ),
      );

      expect(applied, isFalse);
      expect(syncState.lastHandledTimestamp, archiveTimestamp);
      expect(syncState.lastHandledStanzaId, 'unsupported-snapshot');
    });

    group('outbound sync', () {
      test('sendTaskUpdate sends a calendar update envelope', () async {
        final modifiedAt = DateTime.utc(2024, 6, 1, 12);
        final task = CalendarTask(
          id: 'outbound-task',
          title: 'Outbound task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: CalendarModel.empty,
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
        );

        await manager.sendTaskUpdate(task, 'add');

        expect(sent, hasLength(1));
        final payload = _decodeEnvelope(sent.single);
        expect(payload['type'], CalendarSyncType.update);
        expect(payload['entity'], 'task');
        expect(payload['operation'], 'add');
        expect(payload['task_id'], task.id);
        expect(payload['data'], isA<Map<String, dynamic>>());
      });

      test('snapshot threshold sends after 50 outbound mutations', () async {
        final modifiedAt = DateTime.utc(2024, 6, 1, 13);
        final task = CalendarTask(
          id: 'threshold-task',
          title: 'Threshold task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        CalendarSyncState syncState = const CalendarSyncState();
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => CalendarModel.empty().addTask(task),
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
          readSyncState: () => syncState,
          writeSyncState: (state) async {
            syncState = state;
          },
        );

        for (var index = 0; index < 49; index += 1) {
          await manager.sendTaskUpdate(task, 'update');
        }

        expect(sent, hasLength(49));
        expect(
          sent
              .map(_decodeEnvelope)
              .where((payload) => payload['type'] == CalendarSyncType.snapshot),
          isEmpty,
        );
        expect(syncState.updatesSinceSnapshot, 49);

        await manager.sendTaskUpdate(task, 'update');

        expect(sent, hasLength(51));
        expect(_decodeEnvelope(sent[49])['type'], CalendarSyncType.update);
        final snapshotPayload = _decodeEnvelope(sent[50]);
        expect(snapshotPayload['type'], CalendarSyncType.snapshot);
        expect(snapshotPayload['data'], isA<Map<String, dynamic>>());
        expect(syncState.updatesSinceSnapshot, 0);
        expect(syncState.lastSnapshotChecksum, isNotNull);
        expect(
          syncState.snapshotCoverageStatus,
          CalendarSnapshotCoverageStatus.unknown,
        );
        expect(syncState.lastVerifiedSnapshotChecksum, isNull);
      });

      test('MAM replay does not echo updates or trigger snapshots', () async {
        CalendarModel model = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => model,
          applyModel: (next) async {
            model = next;
          },
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
          readSyncState: () => syncState,
          writeSyncState: (state) async {
            syncState = state;
          },
        );
        final baseTime = DateTime.utc(2024, 6, 1, 14);

        for (var index = 0; index < 50; index += 1) {
          final timestamp = baseTime.add(Duration(minutes: index));
          final task = CalendarTask(
            id: 'mam-replay-task-$index',
            title: 'MAM replay task $index',
            createdAt: timestamp,
            modifiedAt: timestamp,
          );
          await manager.onCalendarMessage(
            CalendarSyncInbound(
              message: CalendarSyncMessage(
                type: CalendarSyncType.update,
                timestamp: timestamp,
                taskId: task.id,
                operation: 'add',
                data: task.toJson(),
              ),
              receivedAt: timestamp,
              isFromMam: true,
              stanzaId: 'mam-replay-$index',
            ),
          );
        }

        expect(model.tasks, hasLength(50));
        expect(sent, isEmpty);
        expect(syncState.updatesSinceSnapshot, 0);
      });

      test('pushFullSync sends a snapshot immediately', () async {
        final modifiedAt = DateTime.utc(2024, 6, 1, 15);
        final task = CalendarTask(
          id: 'push-full-sync-task',
          title: 'Push full sync task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => CalendarModel.empty().addTask(task),
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
        );

        await manager.pushFullSync();

        expect(sent, hasLength(1));
        final payload = _decodeEnvelope(sent.single);
        expect(payload['type'], CalendarSyncType.snapshot);
        expect(payload['data'], isA<Map<String, dynamic>>());
      });

      test('MAM snapshot marks recovery boundary verified', () async {
        final modifiedAt = DateTime.utc(2024, 6, 1, 15, 30);
        final task = CalendarTask(
          id: 'mam-verified-snapshot-task',
          title: 'MAM verified snapshot task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        CalendarModel model = CalendarModel.empty();
        CalendarSyncState syncState = const CalendarSyncState();
        final manager = CalendarSyncManager(
          readModel: () => model,
          applyModel: (next) async {
            model = next;
          },
          sendCalendarMessage: (_) async {},
          readSyncState: () => syncState,
          writeSyncState: (state) async {
            syncState = state;
          },
        );
        final snapshotModel = CalendarModel.empty().addTask(task);
        final checksum = snapshotModel.calculateChecksum();

        await manager.onCalendarMessage(
          CalendarSyncInbound(
            message: CalendarSyncMessage(
              type: CalendarSyncType.snapshot,
              timestamp: modifiedAt,
              data: snapshotModel.toJson(),
              checksum: checksum,
              isSnapshot: true,
              snapshotChecksum: checksum,
              snapshotVersion: CalendarSnapshotCodec.currentVersion,
            ),
            receivedAt: modifiedAt,
            isFromMam: true,
            stanzaId: 'mam-verified-snapshot',
          ),
        );

        expect(model.tasks[task.id]?.title, task.title);
        expect(
          syncState.snapshotCoverageStatus,
          CalendarSnapshotCoverageStatus.verified,
        );
        expect(syncState.lastSnapshotChecksum, checksum);
        expect(syncState.lastVerifiedSnapshotChecksum, checksum);
        expect(syncState.lastVerifiedSnapshotStanzaId, 'mam-verified-snapshot');
        expect(syncState.lastVerifiedSnapshotAt, modifiedAt);
      });

      test('pushFullSync skips empty calendars', () async {
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: CalendarModel.empty,
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
        );

        await manager.pushFullSync();

        expect(sent, isEmpty);
      });

      test('small snapshots stay inline when upload is available', () async {
        final modifiedAt = DateTime.utc(2024, 6, 1, 15, 45);
        final task = CalendarTask(
          id: 'small-inline-snapshot-task',
          title: 'Small inline snapshot task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        var uploadCalled = false;
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => CalendarModel.empty().addTask(task),
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
          sendSnapshotFile: (_) async {
            uploadCalled = true;
            return const CalendarSnapshotUploadResult(
              url: 'https://files.example.com/unused.snapshot',
              checksum: 'unused-checksum',
              version: CalendarSnapshotCodec.currentVersion,
            );
          },
        );

        await manager.pushFullSync();

        expect(uploadCalled, isFalse);
        expect(sent, hasLength(1));
        final payload = _decodeEnvelope(sent.single);
        expect(payload['type'], CalendarSyncType.snapshot);
        expect(payload['data'], isA<Map<String, dynamic>>());
        expect(payload['snapshot_url'], isNull);
        expect(sent.single.attachment, isNull);
      });

      test(
        'attachment snapshot path sends snapshot metadata and attachment',
        () async {
          await _useTemporaryPathProvider('axichat_snapshot_attachment');
          final modifiedAt = DateTime.utc(2024, 6, 1, 16);
          final oversizedDescription = _largeCalendarPayloadText();
          final task = CalendarTask(
            id: 'attachment-snapshot-task',
            title: 'Attachment snapshot task',
            description: oversizedDescription,
            createdAt: modifiedAt,
            modifiedAt: modifiedAt,
          );
          final model = CalendarModel.empty().addTask(task);
          CalendarSnapshotResult? uploadedSnapshot;
          bool uploadFileExisted = false;
          final sent = <CalendarSyncOutbound>[];
          final manager = CalendarSyncManager(
            readModel: () => model,
            applyModel: (_) async {},
            sendCalendarMessage: (outbound) async {
              sent.add(outbound);
            },
            sendSnapshotFile: (file) async {
              uploadFileExisted = await file.exists();
              uploadedSnapshot = await CalendarSnapshotCodec.decodeFile(file);
              return const CalendarSnapshotUploadResult(
                url: 'https://files.example.com/calendar.snapshot',
                checksum: 'snapshot-checksum',
                version: CalendarSnapshotCodec.currentVersion,
              );
            },
          );

          await manager.pushFullSync();

          expect(sent, hasLength(1));
          expect(uploadFileExisted, isTrue);
          expect(uploadedSnapshot, isNotNull);
          expect(
            CalendarSnapshotCodec.verifyChecksum(uploadedSnapshot!),
            isTrue,
          );
          expect(uploadedSnapshot!.model.tasks[task.id]?.title, task.title);
          expect(
            uploadedSnapshot!.model.tasks[task.id]?.description,
            oversizedDescription,
          );
          final outbound = sent.single;
          final payload = _decodeEnvelope(outbound);
          expect(payload['type'], CalendarSyncType.snapshot);
          expect(
            payload['snapshot_url'],
            'https://files.example.com/calendar.snapshot',
          );
          expect(payload['snapshot_checksum'], 'snapshot-checksum');
          expect(
            payload['snapshot_version'],
            CalendarSnapshotCodec.currentVersion,
          );
          expect(payload['data'], isNull);
          expect(
            outbound.attachment?.url,
            'https://files.example.com/calendar.snapshot',
          );
          expect(outbound.attachment?.mimeType, CalendarSnapshotCodec.mimeType);
        },
      );

      test(
        'inline snapshot fallback sends data when upload is absent',
        () async {
          final modifiedAt = DateTime.utc(2024, 6, 1, 17);
          final task = CalendarTask(
            id: 'inline-snapshot-task',
            title: 'Inline snapshot task',
            createdAt: modifiedAt,
            modifiedAt: modifiedAt,
          );
          final model = CalendarModel.empty().addTask(task);
          final sent = <CalendarSyncOutbound>[];
          final manager = CalendarSyncManager(
            readModel: () => model,
            applyModel: (_) async {},
            sendCalendarMessage: (outbound) async {
              sent.add(outbound);
            },
          );

          await manager.pushFullSync();

          expect(sent, hasLength(1));
          final payload = _decodeEnvelope(sent.single);
          final snapshotModel = CalendarModel.fromJson(
            payload['data'] as Map<String, dynamic>,
          );
          expect(payload['type'], CalendarSyncType.snapshot);
          expect(payload['data'], isA<Map<String, dynamic>>());
          expect(snapshotModel.tasks[task.id]?.title, task.title);
          expect(
            payload['snapshot_checksum'],
            snapshotModel.calculateChecksum(),
          );
          expect(payload['checksum'], snapshotModel.calculateChecksum());
          expect(
            payload['snapshot_version'],
            CalendarSnapshotCodec.currentVersion,
          );
          expect(sent.single.attachment, isNull);
        },
      );

      test('inline snapshot fallback sends data when upload fails', () async {
        await _useTemporaryPathProvider('axichat_snapshot_upload_failure');
        final modifiedAt = DateTime.utc(2024, 6, 1, 18);
        final oversizedDescription = _largeCalendarPayloadText();
        final task = CalendarTask(
          id: 'upload-fallback-task',
          title: 'Upload fallback task',
          description: oversizedDescription,
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => CalendarModel.empty().addTask(task),
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            sent.add(outbound);
          },
          sendSnapshotFile: (_) async {
            throw Exception('upload failed');
          },
        );

        await manager.pushFullSync();

        expect(sent, hasLength(1));
        final payload = _decodeEnvelope(sent.single);
        expect(payload['type'], CalendarSyncType.snapshot);
        expect(payload['data'], isA<Map<String, dynamic>>());
        expect(sent.single.attachment, isNull);
      });

      test('queued attachment snapshot preserves metadata on flush', () async {
        await _useTemporaryPathProvider('axichat_snapshot_queue');
        final modifiedAt = DateTime.utc(2024, 6, 1, 19);
        final oversizedDescription = _largeCalendarPayloadText();
        final task = CalendarTask(
          id: 'queued-attachment-task',
          title: 'Queued attachment task',
          description: oversizedDescription,
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        var attempts = 0;
        final sent = <CalendarSyncOutbound>[];
        final manager = CalendarSyncManager(
          readModel: () => CalendarModel.empty().addTask(task),
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            attempts += 1;
            if (attempts == 1) {
              throw Exception('offline');
            }
            sent.add(outbound);
          },
          sendSnapshotFile: (_) async {
            return const CalendarSnapshotUploadResult(
              url: 'https://files.example.com/queued.snapshot',
              checksum: 'queued-checksum',
              version: CalendarSnapshotCodec.currentVersion,
            );
          },
        );

        await manager.pushFullSync();
        expect(attempts, 1);
        expect(sent, isEmpty);

        await manager.flushPending();

        expect(attempts, 2);
        expect(sent, hasLength(1));
        final outbound = sent.single;
        final payload = _decodeEnvelope(outbound);
        expect(
          payload['snapshot_url'],
          'https://files.example.com/queued.snapshot',
        );
        expect(payload['snapshot_checksum'], 'queued-checksum');
        expect(
          outbound.attachment?.url,
          'https://files.example.com/queued.snapshot',
        );
        expect(outbound.attachment?.mimeType, CalendarSnapshotCodec.mimeType);
      });
    });

    test(
      'failed immediate sends remain queued for an explicit flush',
      () async {
        final DateTime modifiedAt = DateTime.utc(2024, 5, 1, 12);
        final task = CalendarTask(
          id: 'retry-task',
          title: 'Retry task',
          createdAt: modifiedAt,
          modifiedAt: modifiedAt,
        );
        var attempts = 0;
        final sentEnvelopes = <String>[];
        final manager = CalendarSyncManager(
          readModel: CalendarModel.empty,
          applyModel: (_) async {},
          sendCalendarMessage: (outbound) async {
            attempts += 1;
            if (attempts == 1) {
              throw Exception('offline');
            }
            sentEnvelopes.add(outbound.envelope);
          },
        );

        await expectLater(
          manager.sendTaskUpdate(task, 'update'),
          throwsA(isA<Exception>()),
        );
        expect(attempts, equals(1));
        expect(sentEnvelopes, isEmpty);

        await manager.flushPending();

        expect(attempts, equals(2));
        expect(sentEnvelopes, hasLength(1));
        expect(sentEnvelopes.single, contains('Retry task'));
      },
    );

    test('archive resume cursor does not overwrite handled watermark', () {
      final handledAt = DateTime.utc(2024, 5, 1, 12);
      final state =
          CalendarSyncState(
            lastHandledTimestamp: handledAt,
            lastHandledStanzaId: 'handled-envelope',
          ).markArchivePageHandled(
            resumeId: 'mam-page-last',
            calendarJid: 'me@example.com',
            archiveJid: 'me@example.com',
          );

      expect(state.lastHandledTimestamp, handledAt);
      expect(state.lastHandledStanzaId, 'handled-envelope');
      expect(state.lastArchiveResumeId, 'mam-page-last');
      expect(state.coverageStatus, CalendarArchiveCoverageStatus.incomplete);
    });
  });
}
