import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'calendar_critical_path.dart';
import 'day_event.dart';
import 'calendar_task.dart';

part 'calendar_model.freezed.dart';
part 'calendar_model.g.dart';

const _tombstoneRetentionDays = 30;

@freezed
@HiveType(typeId: 33)
class CalendarModel with _$CalendarModel {
  const factory CalendarModel({
    @HiveField(0) @Default({}) Map<String, CalendarTask> tasks,
    @HiveField(1) required DateTime lastModified,
    @HiveField(2) @Default({}) Map<String, DayEvent> dayEvents,
    @HiveField(3) required String checksum,
    @HiveField(4) @Default({}) Map<String, CalendarCriticalPath> criticalPaths,
    @HiveField(5) @Default({}) Map<String, DateTime> deletedTaskIds,
    @HiveField(6) @Default({}) Map<String, DateTime> deletedDayEventIds,
    @HiveField(7) @Default({}) Map<String, DateTime> deletedCriticalPathIds,
  }) = _CalendarModel;

  factory CalendarModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarModelFromJson(json);

  factory CalendarModel.empty() {
    final now = DateTime.now();
    final model = CalendarModel(
      lastModified: now,
      checksum: '',
      dayEvents: const {},
      criticalPaths: const {},
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }

  const CalendarModel._();

  String calculateChecksum() {
    final sortedTasks = Map.fromEntries(
      tasks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDayEvents = Map.fromEntries(
      dayEvents.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedCriticalPaths = Map.fromEntries(
      criticalPaths.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedTaskIds = Map.fromEntries(
      deletedTaskIds.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedDayEventIds = Map.fromEntries(
      deletedDayEventIds.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedCriticalPathIds = Map.fromEntries(
      deletedCriticalPathIds.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final content = jsonEncode({
      'tasks': sortedTasks.map((k, v) => MapEntry(k, v.toJson())),
      'dayEvents': sortedDayEvents.map((k, v) => MapEntry(k, v.toJson())),
      'lastModified': lastModified.toIso8601String(),
      'criticalPaths':
          sortedCriticalPaths.map((k, v) => MapEntry(k, v.toJson())),
      'deletedTaskIds':
          sortedDeletedTaskIds.map((k, v) => MapEntry(k, v.toIso8601String())),
      'deletedDayEventIds': sortedDeletedDayEventIds
          .map((k, v) => MapEntry(k, v.toIso8601String())),
      'deletedCriticalPathIds': sortedDeletedCriticalPathIds
          .map((k, v) => MapEntry(k, v.toIso8601String())),
    });
    return sha256.convert(utf8.encode(content)).toString();
  }

  CalendarModel addTask(CalendarTask task) {
    final updatedTasks = {...tasks, task.id: task};
    final now = DateTime.now();
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel updateTask(CalendarTask task) {
    if (!tasks.containsKey(task.id)) return this;
    return addTask(task);
  }

  CalendarModel deleteTask(String taskId) {
    if (!tasks.containsKey(taskId)) return this;
    final updatedTasks = Map<String, CalendarTask>.from(tasks)..remove(taskId);
    final now = DateTime.now();
    final String baseId = baseTaskIdFrom(taskId);
    final bool shouldPrunePaths = !updatedTasks.containsKey(baseId);
    final updatedDeletedTaskIds = _purgeStaleTombstones(deletedTaskIds, now);
    updatedDeletedTaskIds[taskId] = now;
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
      deletedTaskIds: updatedDeletedTaskIds,
      criticalPaths: shouldPrunePaths
          ? _removeTaskFromPaths(taskId, now: now)
          : criticalPaths,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel replaceTasks(Map<String, CalendarTask> replacements) {
    if (replacements.isEmpty) {
      return this;
    }
    final updatedTasks = {...tasks}..addAll(replacements);
    final now = DateTime.now();
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel addDayEvent(DayEvent event) {
    final updatedDayEvents = <String, DayEvent>{
      ...dayEvents,
      event.id: event,
    };
    final DateTime now = DateTime.now();
    final CalendarModel updated = copyWith(
      dayEvents: updatedDayEvents,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel updateDayEvent(DayEvent event) {
    if (!dayEvents.containsKey(event.id)) {
      return this;
    }
    return addDayEvent(event);
  }

  CalendarModel deleteDayEvent(String eventId) {
    if (!dayEvents.containsKey(eventId)) {
      return this;
    }
    final Map<String, DayEvent> updatedEvents =
        Map<String, DayEvent>.from(dayEvents)..remove(eventId);
    final DateTime now = DateTime.now();
    final updatedDeletedDayEventIds =
        _purgeStaleTombstones(deletedDayEventIds, now);
    updatedDeletedDayEventIds[eventId] = now;
    final CalendarModel updated = copyWith(
      dayEvents: updatedEvents,
      lastModified: now,
      deletedDayEventIds: updatedDeletedDayEventIds,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel replaceDayEvents(Map<String, DayEvent> replacements) {
    if (replacements.isEmpty) {
      return this;
    }
    final Map<String, DayEvent> updatedEvents = <String, DayEvent>{
      ...dayEvents,
      ...replacements,
    };
    final DateTime now = DateTime.now();
    final CalendarModel updated = copyWith(
      dayEvents: updatedEvents,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel removeTasks(Iterable<String> taskIds) {
    final updatedTasks = Map<String, CalendarTask>.from(tasks);
    final List<String> removedIds = <String>[];
    for (final id in taskIds) {
      if (updatedTasks.remove(id) != null) {
        removedIds.add(id);
      }
    }
    if (removedIds.isEmpty) {
      return this;
    }
    final now = DateTime.now();
    final updatedDeletedTaskIds = _purgeStaleTombstones(deletedTaskIds, now);
    for (final id in removedIds) {
      updatedDeletedTaskIds[id] = now;
    }
    final Set<String> missingBaseIds = taskIds
        .map(baseTaskIdFrom)
        .where((id) => !updatedTasks.containsKey(id))
        .toSet();
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
      deletedTaskIds: updatedDeletedTaskIds,
      criticalPaths: missingBaseIds.isEmpty
          ? criticalPaths
          : _removeMissingTasksFromPaths(missingBaseIds, now: now),
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel addCriticalPath(CalendarCriticalPath path) {
    final nextPaths = <String, CalendarCriticalPath>{
      ...criticalPaths,
      path.id: path,
    };
    final updated = copyWith(
      criticalPaths: nextPaths,
      lastModified: DateTime.now(),
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel updateCriticalPath(CalendarCriticalPath path) {
    if (!criticalPaths.containsKey(path.id)) {
      return this;
    }
    return addCriticalPath(path);
  }

  CalendarModel removeCriticalPath(String pathId) {
    final CalendarCriticalPath? path = criticalPaths[pathId];
    if (path == null) {
      return this;
    }
    final CalendarCriticalPath archived = path.archive();
    final nextPaths = Map<String, CalendarCriticalPath>.from(criticalPaths)
      ..[pathId] = archived;
    final updated = copyWith(
      criticalPaths: nextPaths,
      lastModified: DateTime.now(),
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel addTaskToCriticalPath({
    required String pathId,
    required String taskId,
    int? index,
  }) {
    final String normalizedTaskId = baseTaskIdFrom(taskId);
    final CalendarCriticalPath? path = criticalPaths[pathId];
    if (path == null || path.isArchived) {
      return this;
    }
    final CalendarCriticalPath updatedPath =
        path.addTask(normalizedTaskId, index: index);
    final nextPaths = Map<String, CalendarCriticalPath>.from(criticalPaths)
      ..[pathId] = updatedPath;
    final updated = copyWith(
      criticalPaths: nextPaths,
      lastModified: DateTime.now(),
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel removeTaskFromCriticalPath({
    required String pathId,
    required String taskId,
  }) {
    final String normalizedTaskId = baseTaskIdFrom(taskId);
    final CalendarCriticalPath? path = criticalPaths[pathId];
    if (path == null) {
      return this;
    }
    final CalendarCriticalPath updatedPath = path.removeTask(normalizedTaskId);
    final nextPaths = Map<String, CalendarCriticalPath>.from(criticalPaths)
      ..[pathId] = updatedPath;
    final updated = copyWith(
      criticalPaths: nextPaths,
      lastModified: DateTime.now(),
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel reorderCriticalPath({
    required String pathId,
    required List<String> orderedTaskIds,
  }) {
    final CalendarCriticalPath? path = criticalPaths[pathId];
    if (path == null || path.isArchived) {
      return this;
    }
    final now = DateTime.now();
    final Set<String> unique = <String>{};
    final List<String> normalized = <String>[];
    for (final String id in orderedTaskIds) {
      final String baseId = baseTaskIdFrom(id);
      if (!path.taskIds.contains(baseId) || !unique.add(baseId)) {
        continue;
      }
      normalized.add(baseId);
    }
    for (final String id in path.taskIds) {
      if (unique.add(id)) {
        normalized.add(id);
      }
    }
    final CalendarCriticalPath updatedPath = path.copyWith(
      taskIds: normalized,
      modifiedAt: now,
    );
    final nextPaths = Map<String, CalendarCriticalPath>.from(criticalPaths)
      ..[pathId] = updatedPath;
    final updated = copyWith(
      criticalPaths: nextPaths,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  Map<String, CalendarCriticalPath> _removeTaskFromPaths(
    String taskId, {
    required DateTime now,
  }) {
    final String baseId = baseTaskIdFrom(taskId);
    var changed = false;
    final next = <String, CalendarCriticalPath>{};
    for (final MapEntry<String, CalendarCriticalPath> entry
        in criticalPaths.entries) {
      final CalendarCriticalPath path = entry.value;
      final List<String> filtered =
          path.taskIds.where((id) => id != baseId).toList();
      if (filtered.length != path.taskIds.length) {
        changed = true;
        next[entry.key] = path.copyWith(
          taskIds: filtered,
          modifiedAt: now,
        );
      } else {
        next[entry.key] = path;
      }
    }
    return changed ? next : criticalPaths;
  }

  Map<String, CalendarCriticalPath> _removeMissingTasksFromPaths(
    Iterable<String> removedTaskIds, {
    required DateTime now,
  }) {
    final Set<String> baseIds = removedTaskIds.map(baseTaskIdFrom).toSet();
    var changed = false;
    final next = <String, CalendarCriticalPath>{};
    for (final MapEntry<String, CalendarCriticalPath> entry
        in criticalPaths.entries) {
      final CalendarCriticalPath path = entry.value;
      final List<String> filtered = path.taskIds
          .where((id) => !baseIds.contains(id))
          .toList(growable: false);
      if (filtered.length != path.taskIds.length) {
        changed = true;
        next[entry.key] = path.copyWith(
          taskIds: filtered,
          modifiedAt: now,
        );
      } else {
        next[entry.key] = path;
      }
    }
    return changed ? next : criticalPaths;
  }

  Map<String, DateTime> _purgeStaleTombstones(
    Map<String, DateTime> tombstones,
    DateTime now,
  ) {
    final cutoff = now.subtract(const Duration(days: _tombstoneRetentionDays));
    final result = <String, DateTime>{};
    for (final entry in tombstones.entries) {
      if (entry.value.isAfter(cutoff)) {
        result[entry.key] = entry.value;
      }
    }
    return result;
  }
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

extension CalendarModelMerge on CalendarModel {
  CalendarModel mergeWith(CalendarModel remote) {
    final mergedDeletedTaskIds =
        _mergeTombstones(deletedTaskIds, remote.deletedTaskIds);
    final mergedDeletedDayEventIds =
        _mergeTombstones(deletedDayEventIds, remote.deletedDayEventIds);
    final mergedDeletedCriticalPathIds = _mergeTombstones(
      deletedCriticalPathIds,
      remote.deletedCriticalPathIds,
    );

    final mergedTasks = <String, CalendarTask>{};
    final allTaskIds = <String>{...tasks.keys, ...remote.tasks.keys};

    for (final id in allTaskIds) {
      if (mergedDeletedTaskIds.containsKey(id)) {
        continue;
      }

      final localTask = tasks[id];
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

    final mergedDayEvents = <String, DayEvent>{};
    final allEventIds = <String>{...dayEvents.keys, ...remote.dayEvents.keys};

    for (final id in allEventIds) {
      if (mergedDeletedDayEventIds.containsKey(id)) {
        continue;
      }

      final localEvent = dayEvents[id];
      final remoteEvent = remote.dayEvents[id];

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
      ...criticalPaths.keys,
      ...remote.criticalPaths.keys
    };

    for (final id in allPathIds) {
      if (mergedDeletedCriticalPathIds.containsKey(id)) {
        continue;
      }

      final localPath = criticalPaths[id];
      final remotePath = remote.criticalPaths[id];

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

    final now = DateTime.now();
    final merged = CalendarModel(
      tasks: mergedTasks,
      dayEvents: mergedDayEvents,
      criticalPaths: mergedPaths,
      deletedTaskIds: mergedDeletedTaskIds,
      deletedDayEventIds: mergedDeletedDayEventIds,
      deletedCriticalPathIds: mergedDeletedCriticalPathIds,
      lastModified: now,
      checksum: '',
    );
    return merged.copyWith(checksum: merged.calculateChecksum());
  }
}

extension CalendarModelX on CalendarModel {
  bool get hasCalendarData =>
      tasks.isNotEmpty || dayEvents.isNotEmpty || criticalPaths.isNotEmpty;

  CalendarTask? resolveTaskInstance(String taskId) {
    final CalendarTask? direct = tasks[taskId];
    if (direct != null) {
      return direct;
    }
    final String baseId = baseTaskIdFrom(taskId);
    final CalendarTask? baseTask = tasks[baseId];
    if (baseTask == null) {
      return null;
    }
    if (taskId == baseId) {
      return baseTask;
    }
    return baseTask.occurrenceForId(taskId);
  }

  List<CalendarCriticalPath> get activeCriticalPaths {
    final List<CalendarCriticalPath> active = criticalPaths.values
        .where((path) => !path.isArchived)
        .toList(growable: false);
    active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return active;
  }
}
