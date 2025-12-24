import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_sync_message.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_manager.dart';
import 'package:axichat/src/calendar/sync/calendar_sync_state.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarSyncManager tombstone handling', () {
    const String taskId = 'remote-task';
    const String taskTitle = 'Remote Task';
    const String addOperation = 'add';
    const Duration tombstoneOffset = Duration(hours: 1);
    const Duration newerOffset = Duration(hours: 2);
    final DateTime deletedAt = DateTime(2024, 2, 10, 12);

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

      final CalendarSyncMessage message = CalendarSyncMessage.update(
        taskId: taskId,
        operation: addOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: message,
          receivedAt: remoteModifiedAt,
        ),
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

      final CalendarSyncMessage message = CalendarSyncMessage.update(
        taskId: taskId,
        operation: addOperation,
        data: remoteTask.toJson(),
      );

      await manager.onCalendarMessage(
        CalendarSyncInbound(
          message: message,
          receivedAt: remoteModifiedAt,
        ),
      );

      expect(applyCalls, equals(1));
      expect(appliedModel, isNotNull);
      expect(currentModel.tasks[taskId]?.title, equals(taskTitle));
      expect(currentModel.deletedTaskIds.containsKey(taskId), isFalse);
    });
  });
}
