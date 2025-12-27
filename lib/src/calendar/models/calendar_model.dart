import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'calendar_availability.dart';
import 'calendar_collection.dart';
import 'calendar_critical_path.dart';
import 'calendar_ics_meta.dart';
import 'calendar_journal.dart';
import 'day_event.dart';
import 'calendar_task.dart';

part 'calendar_model.freezed.dart';
part 'calendar_model.g.dart';

const _tombstoneRetentionDays = 30;
const int _calendarModelCollectionField = 8;
const int _calendarModelAvailabilityField = 9;
const int _calendarModelAvailabilityOverlayField = 10;
const int _calendarModelJournalsField = 11;
const int _calendarModelDeletedJournalIdsField = 12;
const int _calendarSequenceDefault = 0;

@freezed
@HiveType(typeId: 33)
class CalendarModel with _$CalendarModel {
  const factory CalendarModel({
    @HiveField(0) @Default({}) Map<String, CalendarTask> tasks,
    @HiveField(1) required DateTime lastModified,
    @HiveField(2) @Default({}) Map<String, DayEvent> dayEvents,
    @HiveField(3) required String checksum,
    @HiveField(_calendarModelJournalsField)
    @Default({})
    Map<String, CalendarJournal> journals,
    @HiveField(4) @Default({}) Map<String, CalendarCriticalPath> criticalPaths,
    @HiveField(5) @Default({}) Map<String, DateTime> deletedTaskIds,
    @HiveField(6) @Default({}) Map<String, DateTime> deletedDayEventIds,
    @HiveField(_calendarModelDeletedJournalIdsField)
    @Default({})
    Map<String, DateTime> deletedJournalIds,
    @HiveField(7) @Default({}) Map<String, DateTime> deletedCriticalPathIds,
    @HiveField(_calendarModelCollectionField) CalendarCollection? collection,
    @HiveField(_calendarModelAvailabilityField)
    @Default({})
    Map<String, CalendarAvailability> availability,
    @HiveField(_calendarModelAvailabilityOverlayField)
    @Default({})
    Map<String, CalendarAvailabilityOverlay> availabilityOverlays,
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
    final sortedJournals = Map.fromEntries(
      journals.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedCriticalPaths = Map.fromEntries(
      criticalPaths.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedAvailability = Map.fromEntries(
      availability.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedAvailabilityOverlays = Map.fromEntries(
      availabilityOverlays.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedTaskIds = Map.fromEntries(
      deletedTaskIds.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedDayEventIds = Map.fromEntries(
      deletedDayEventIds.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedJournalIds = Map.fromEntries(
      deletedJournalIds.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final sortedDeletedCriticalPathIds = Map.fromEntries(
      deletedCriticalPathIds.entries.toList()
        ..sort((a, b) => a.key.compareTo(b.key)),
    );
    final collectionJson = collection?.toJson();
    final content = jsonEncode({
      'tasks': sortedTasks.map((k, v) => MapEntry(k, v.toJson())),
      'dayEvents': sortedDayEvents.map((k, v) => MapEntry(k, v.toJson())),
      'journals': sortedJournals.map((k, v) => MapEntry(k, v.toJson())),
      'lastModified': lastModified.toIso8601String(),
      'criticalPaths':
          sortedCriticalPaths.map((k, v) => MapEntry(k, v.toJson())),
      'availability': sortedAvailability.map((k, v) => MapEntry(k, v.toJson())),
      'availabilityOverlays':
          sortedAvailabilityOverlays.map((k, v) => MapEntry(k, v.toJson())),
      'collection': collectionJson,
      'deletedTaskIds':
          sortedDeletedTaskIds.map((k, v) => MapEntry(k, v.toIso8601String())),
      'deletedDayEventIds': sortedDeletedDayEventIds
          .map((k, v) => MapEntry(k, v.toIso8601String())),
      'deletedJournalIds': sortedDeletedJournalIds
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

  CalendarModel upsertAvailability(CalendarAvailability availability) {
    final String id = availability.id.trim();
    if (id.isEmpty) {
      return this;
    }
    final Map<String, CalendarAvailability> updatedAvailability =
        Map<String, CalendarAvailability>.from(this.availability)
          ..[id] = availability;
    final DateTime now = DateTime.now();
    final CalendarModel updated = copyWith(
      availability: updatedAvailability,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel addJournal(CalendarJournal journal) {
    final updatedJournals = <String, CalendarJournal>{
      ...journals,
      journal.id: journal,
    };
    final DateTime now = DateTime.now();
    final CalendarModel updated = copyWith(
      journals: updatedJournals,
      lastModified: now,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel updateJournal(CalendarJournal journal) {
    if (!journals.containsKey(journal.id)) {
      return this;
    }
    return addJournal(journal);
  }

  CalendarModel deleteJournal(String journalId) {
    if (!journals.containsKey(journalId)) {
      return this;
    }
    final Map<String, CalendarJournal> updatedJournals =
        Map<String, CalendarJournal>.from(journals)..remove(journalId);
    final DateTime now = DateTime.now();
    final updatedDeletedJournalIds =
        _purgeStaleTombstones(deletedJournalIds, now);
    updatedDeletedJournalIds[journalId] = now;
    final CalendarModel updated = copyWith(
      journals: updatedJournals,
      lastModified: now,
      deletedJournalIds: updatedDeletedJournalIds,
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }

  CalendarModel replaceJournals(Map<String, CalendarJournal> replacements) {
    if (replacements.isEmpty) {
      return this;
    }
    final Map<String, CalendarJournal> updatedJournals =
        <String, CalendarJournal>{
      ...journals,
      ...replacements,
    };
    final DateTime now = DateTime.now();
    final CalendarModel updated = copyWith(
      journals: updatedJournals,
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

DateTime? _latestTimestamp(DateTime? localTime, DateTime? remoteTime) {
  if (localTime == null) {
    return remoteTime;
  }
  if (remoteTime == null) {
    return localTime;
  }
  return remoteTime.isAfter(localTime) ? remoteTime : localTime;
}

CalendarCollection? _mergeCollections(
  CalendarCollection? local,
  CalendarCollection? remote,
) {
  if (remote == null) {
    return local;
  }
  if (local == null) {
    return remote;
  }
  return remote;
}

DateTime? _availabilityTimestamp(CalendarAvailability availability) {
  final CalendarIcsMeta? meta = availability.icsMeta;
  return meta?.lastModified ?? meta?.dtStamp ?? meta?.created;
}

Map<String, CalendarAvailability> _mergeAvailability(
  Map<String, CalendarAvailability> local,
  Map<String, CalendarAvailability> remote,
) {
  final merged = <String, CalendarAvailability>{};
  final allIds = <String>{...local.keys, ...remote.keys};
  for (final id in allIds) {
    final localAvailability = local[id];
    final remoteAvailability = remote[id];
    if (localAvailability == null && remoteAvailability != null) {
      merged[id] = remoteAvailability;
      continue;
    }
    if (localAvailability != null && remoteAvailability == null) {
      merged[id] = localAvailability;
      continue;
    }
    if (localAvailability != null && remoteAvailability != null) {
      final localStamp = _availabilityTimestamp(localAvailability);
      final remoteStamp = _availabilityTimestamp(remoteAvailability);
      if (localStamp == null && remoteStamp == null) {
        merged[id] = remoteAvailability;
        continue;
      }
      if (localStamp == null && remoteStamp != null) {
        merged[id] = remoteAvailability;
        continue;
      }
      if (localStamp != null && remoteStamp == null) {
        merged[id] = localAvailability;
        continue;
      }
      merged[id] = remoteStamp!.isAfter(localStamp!)
          ? remoteAvailability
          : localAvailability;
    }
  }
  return merged;
}

Map<String, CalendarAvailabilityOverlay> _mergeAvailabilityOverlays(
  Map<String, CalendarAvailabilityOverlay> local,
  Map<String, CalendarAvailabilityOverlay> remote,
) {
  final merged = <String, CalendarAvailabilityOverlay>{};
  final allIds = <String>{...local.keys, ...remote.keys};
  for (final id in allIds) {
    final localOverlay = local[id];
    final remoteOverlay = remote[id];
    if (localOverlay == null && remoteOverlay != null) {
      merged[id] = remoteOverlay;
      continue;
    }
    if (localOverlay != null && remoteOverlay == null) {
      merged[id] = localOverlay;
      continue;
    }
    if (localOverlay != null && remoteOverlay != null) {
      merged[id] = remoteOverlay;
    }
  }
  return merged;
}

bool _shouldPreferRemote({
  required DateTime localModifiedAt,
  required DateTime remoteModifiedAt,
  required CalendarIcsMeta? localMeta,
  required CalendarIcsMeta? remoteMeta,
}) {
  if (remoteModifiedAt.isAfter(localModifiedAt)) {
    return true;
  }
  if (localModifiedAt.isAfter(remoteModifiedAt)) {
    return false;
  }
  final int localSequence = localMeta?.sequence ?? _calendarSequenceDefault;
  final int remoteSequence = remoteMeta?.sequence ?? _calendarSequenceDefault;
  return remoteSequence > localSequence;
}

extension CalendarModelMerge on CalendarModel {
  CalendarModel mergeWith(CalendarModel remote) {
    final mergedTasks = <String, CalendarTask>{};
    final mergedDeletedTaskIds = <String, DateTime>{};
    final allTaskIds = <String>{
      ...tasks.keys,
      ...remote.tasks.keys,
      ...deletedTaskIds.keys,
      ...remote.deletedTaskIds.keys,
    };

    for (final id in allTaskIds) {
      final CalendarTask? localTask = tasks[id];
      final CalendarTask? remoteTask = remote.tasks[id];
      final DateTime? localDeletedAt = deletedTaskIds[id];
      final DateTime? remoteDeletedAt = remote.deletedTaskIds[id];
      final DateTime? deletedAt =
          _latestTimestamp(localDeletedAt, remoteDeletedAt);

      CalendarTask? selectedTask;
      if (localTask == null) {
        selectedTask = remoteTask;
      } else if (remoteTask == null) {
        selectedTask = localTask;
      } else {
        final bool preferRemote = _shouldPreferRemote(
          localModifiedAt: localTask.modifiedAt,
          remoteModifiedAt: remoteTask.modifiedAt,
          localMeta: localTask.icsMeta,
          remoteMeta: remoteTask.icsMeta,
        );
        selectedTask = preferRemote ? remoteTask : localTask;
      }

      if (selectedTask == null) {
        if (deletedAt != null) {
          mergedDeletedTaskIds[id] = deletedAt;
        }
        continue;
      }

      if (deletedAt != null && !selectedTask.modifiedAt.isAfter(deletedAt)) {
        mergedDeletedTaskIds[id] = deletedAt;
        continue;
      }

      mergedTasks[id] = selectedTask;
    }

    final mergedDayEvents = <String, DayEvent>{};
    final mergedDeletedDayEventIds = <String, DateTime>{};
    final allEventIds = <String>{
      ...dayEvents.keys,
      ...remote.dayEvents.keys,
      ...deletedDayEventIds.keys,
      ...remote.deletedDayEventIds.keys,
    };

    for (final id in allEventIds) {
      final DayEvent? localEvent = dayEvents[id];
      final DayEvent? remoteEvent = remote.dayEvents[id];
      final DateTime? localDeletedAt = deletedDayEventIds[id];
      final DateTime? remoteDeletedAt = remote.deletedDayEventIds[id];
      final DateTime? deletedAt =
          _latestTimestamp(localDeletedAt, remoteDeletedAt);

      DayEvent? selectedEvent;
      if (localEvent == null) {
        selectedEvent = remoteEvent;
      } else if (remoteEvent == null) {
        selectedEvent = localEvent;
      } else {
        final bool preferRemote = _shouldPreferRemote(
          localModifiedAt: localEvent.modifiedAt,
          remoteModifiedAt: remoteEvent.modifiedAt,
          localMeta: localEvent.icsMeta,
          remoteMeta: remoteEvent.icsMeta,
        );
        selectedEvent = preferRemote ? remoteEvent : localEvent;
      }

      if (selectedEvent == null) {
        if (deletedAt != null) {
          mergedDeletedDayEventIds[id] = deletedAt;
        }
        continue;
      }

      if (deletedAt != null && !selectedEvent.modifiedAt.isAfter(deletedAt)) {
        mergedDeletedDayEventIds[id] = deletedAt;
        continue;
      }

      mergedDayEvents[id] = selectedEvent;
    }

    final mergedJournals = <String, CalendarJournal>{};
    final mergedDeletedJournalIds = <String, DateTime>{};
    final allJournalIds = <String>{
      ...journals.keys,
      ...remote.journals.keys,
      ...deletedJournalIds.keys,
      ...remote.deletedJournalIds.keys,
    };

    for (final id in allJournalIds) {
      final CalendarJournal? localJournal = journals[id];
      final CalendarJournal? remoteJournal = remote.journals[id];
      final DateTime? localDeletedAt = deletedJournalIds[id];
      final DateTime? remoteDeletedAt = remote.deletedJournalIds[id];
      final DateTime? deletedAt =
          _latestTimestamp(localDeletedAt, remoteDeletedAt);

      CalendarJournal? selectedJournal;
      if (localJournal == null) {
        selectedJournal = remoteJournal;
      } else if (remoteJournal == null) {
        selectedJournal = localJournal;
      } else {
        final bool preferRemote = _shouldPreferRemote(
          localModifiedAt: localJournal.modifiedAt,
          remoteModifiedAt: remoteJournal.modifiedAt,
          localMeta: localJournal.icsMeta,
          remoteMeta: remoteJournal.icsMeta,
        );
        selectedJournal = preferRemote ? remoteJournal : localJournal;
      }

      if (selectedJournal == null) {
        if (deletedAt != null) {
          mergedDeletedJournalIds[id] = deletedAt;
        }
        continue;
      }

      if (deletedAt != null && !selectedJournal.modifiedAt.isAfter(deletedAt)) {
        mergedDeletedJournalIds[id] = deletedAt;
        continue;
      }

      mergedJournals[id] = selectedJournal;
    }

    final mergedPaths = <String, CalendarCriticalPath>{};
    final mergedDeletedCriticalPathIds = <String, DateTime>{};
    final allPathIds = <String>{
      ...criticalPaths.keys,
      ...remote.criticalPaths.keys,
      ...deletedCriticalPathIds.keys,
      ...remote.deletedCriticalPathIds.keys,
    };

    for (final id in allPathIds) {
      final CalendarCriticalPath? localPath = criticalPaths[id];
      final CalendarCriticalPath? remotePath = remote.criticalPaths[id];
      final DateTime? localDeletedAt = deletedCriticalPathIds[id];
      final DateTime? remoteDeletedAt = remote.deletedCriticalPathIds[id];
      final DateTime? deletedAt =
          _latestTimestamp(localDeletedAt, remoteDeletedAt);

      CalendarCriticalPath? selectedPath;
      if (localPath == null) {
        selectedPath = remotePath;
      } else if (remotePath == null) {
        selectedPath = localPath;
      } else {
        selectedPath = remotePath.modifiedAt.isAfter(localPath.modifiedAt)
            ? remotePath
            : localPath;
      }

      if (selectedPath == null) {
        if (deletedAt != null) {
          mergedDeletedCriticalPathIds[id] = deletedAt;
        }
        continue;
      }

      if (deletedAt != null && !selectedPath.modifiedAt.isAfter(deletedAt)) {
        mergedDeletedCriticalPathIds[id] = deletedAt;
        continue;
      }

      mergedPaths[id] = selectedPath;
    }

    final mergedAvailability =
        _mergeAvailability(availability, remote.availability);
    final mergedAvailabilityOverlays = _mergeAvailabilityOverlays(
      availabilityOverlays,
      remote.availabilityOverlays,
    );
    final mergedCollection = _mergeCollections(collection, remote.collection);
    final now = DateTime.now();
    final merged = CalendarModel(
      tasks: mergedTasks,
      dayEvents: mergedDayEvents,
      journals: mergedJournals,
      criticalPaths: mergedPaths,
      availability: mergedAvailability,
      availabilityOverlays: mergedAvailabilityOverlays,
      collection: mergedCollection,
      deletedTaskIds: mergedDeletedTaskIds,
      deletedDayEventIds: mergedDeletedDayEventIds,
      deletedJournalIds: mergedDeletedJournalIds,
      deletedCriticalPathIds: mergedDeletedCriticalPathIds,
      lastModified: now,
      checksum: '',
    );
    return merged.copyWith(checksum: merged.calculateChecksum());
  }
}

extension CalendarModelX on CalendarModel {
  bool get hasCalendarData =>
      tasks.isNotEmpty ||
      dayEvents.isNotEmpty ||
      journals.isNotEmpty ||
      criticalPaths.isNotEmpty ||
      availability.isNotEmpty ||
      availabilityOverlays.isNotEmpty;

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
