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

    test(
      'uses message timestamp to prevent stale payload time from blocking newer updates',
      () async {
        final DateTime localModifiedAt = DateTime.utc(2024, 2, 10, 12);
        final DateTime payloadModifiedAt = localModifiedAt.subtract(
          const Duration(hours: 1),
        );
        final DateTime messageTimestamp = localModifiedAt.add(
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
          timestamp: messageTimestamp,
          taskId: taskId,
          operation: updateOperation,
          data: remoteTask.toJson(),
        );

        await manager.onCalendarMessage(CalendarSyncInbound(message: message));

        expect(currentModel.tasks[taskId]?.title, equals('Remote title'));
      },
    );
  });
}
