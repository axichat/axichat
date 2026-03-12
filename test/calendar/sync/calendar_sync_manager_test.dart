import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CalendarSyncManager buildManager({
    required CalendarModel Function() readModel,
    required Future<void> Function(CalendarModel) applyModel,
  }) {
    return CalendarSyncManager(
      readModel: readModel,
      applyModel: applyModel,
      sendCalendarMessage: (_) async {},
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
    const String addOperation = 'add';
    const String updateOperation = 'update';
    const String dayEventEntity = 'day_event';
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
}
