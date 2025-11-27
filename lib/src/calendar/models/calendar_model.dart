import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import '../utils/recurrence_utils.dart';
import 'calendar_critical_path.dart';
import 'calendar_task.dart';

part 'calendar_model.freezed.dart';
part 'calendar_model.g.dart';

@freezed
@HiveType(typeId: 33)
class CalendarModel with _$CalendarModel {
  const factory CalendarModel({
    @HiveField(0) @Default({}) Map<String, CalendarTask> tasks,
    @HiveField(1) required DateTime lastModified,
    @HiveField(3) required String checksum,
    @HiveField(4) @Default({}) Map<String, CalendarCriticalPath> criticalPaths,
  }) = _CalendarModel;

  factory CalendarModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarModelFromJson(json);

  factory CalendarModel.empty() {
    final now = DateTime.now();
    final model = CalendarModel(
      lastModified: now,
      checksum: '',
      criticalPaths: const {},
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }

  const CalendarModel._();

  String calculateChecksum() {
    final sortedTasks = Map.fromEntries(
      tasks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedCriticalPaths = Map.fromEntries(
      criticalPaths.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final content = jsonEncode({
      'tasks': sortedTasks.map((k, v) => MapEntry(k, v.toJson())),
      'lastModified': lastModified.toIso8601String(),
      'criticalPaths':
          sortedCriticalPaths.map((k, v) => MapEntry(k, v.toJson())),
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
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
      criticalPaths: _removeTaskFromPaths(taskId, now: now),
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

  CalendarModel removeTasks(Iterable<String> taskIds) {
    final updatedTasks = Map<String, CalendarTask>.from(tasks);
    var modified = false;
    for (final id in taskIds) {
      if (updatedTasks.remove(id) != null) {
        modified = true;
      }
    }
    if (!modified) {
      return this;
    }
    final now = DateTime.now();
    final updated = copyWith(
      tasks: updatedTasks,
      lastModified: now,
      criticalPaths: _removeMissingTasksFromPaths(taskIds, now: now),
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
}

extension CalendarModelX on CalendarModel {
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
