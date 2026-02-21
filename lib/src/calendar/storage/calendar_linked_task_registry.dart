// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

const String _linkedTaskRegistryStorageKey = 'calendar_linked_tasks_v1';

enum CalendarLinkedTaskOperation { update, delete }

class CalendarLinkedTaskUpdate {
  CalendarLinkedTaskUpdate({
    required this.sourceStorageId,
    required this.targetStorageIds,
    required this.task,
    required this.operation,
  });

  final String sourceStorageId;
  final Set<String> targetStorageIds;
  final CalendarTask task;
  final CalendarLinkedTaskOperation operation;
}

class CalendarLinkedTaskRegistry {
  CalendarLinkedTaskRegistry({
    Storage? storage,
    String storageKey = _linkedTaskRegistryStorageKey,
  }) : _storage = storage ?? HydratedBloc.storage,
       _storageKey = storageKey;

  static final CalendarLinkedTaskRegistry instance =
      CalendarLinkedTaskRegistry();

  final Storage _storage;
  final String _storageKey;
  final StreamController<CalendarLinkedTaskUpdate> _updatesController =
      StreamController<CalendarLinkedTaskUpdate>.broadcast();
  final Set<String> _activeStorageIds = <String>{};

  Stream<CalendarLinkedTaskUpdate> get updates => _updatesController.stream;

  void registerActiveStorage(String storageId) {
    _activeStorageIds.add(storageId.trim());
  }

  void unregisterActiveStorage(String storageId) {
    _activeStorageIds.remove(storageId.trim());
  }

  bool isStorageActive(String storageId) {
    return _activeStorageIds.contains(storageId.trim());
  }

  void notifyLinkedTaskUpdate({
    required String sourceStorageId,
    required Iterable<String> targetStorageIds,
    required CalendarTask task,
    required CalendarLinkedTaskOperation operation,
  }) {
    final String sourceId = sourceStorageId.trim();
    final Set<String> targets = targetStorageIds
        .map((storageId) => storageId.trim())
        .where((storageId) => storageId != sourceId)
        .toSet();
    if (targets.isEmpty) {
      return;
    }
    _updatesController.add(
      CalendarLinkedTaskUpdate(
        sourceStorageId: sourceId,
        targetStorageIds: targets,
        task: task,
        operation: operation,
      ),
    );
  }

  Set<String> linkedStorageIds(String taskId) {
    final String trimmed = taskId.trim();
    if (trimmed.isEmpty) {
      return const <String>{};
    }
    final Map<String, Set<String>> mapping = _readAll();
    return mapping[trimmed] ?? const <String>{};
  }

  Future<void> addLinks({
    required String taskId,
    required Iterable<String> storageIds,
  }) async {
    final String trimmed = taskId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final Set<String> normalizedIds = storageIds.map((id) => id.trim()).toSet();
    if (normalizedIds.isEmpty) {
      return;
    }
    final Map<String, Set<String>> mapping = _readAll();
    final Set<String> existing = mapping[trimmed] ?? <String>{};
    final Set<String> merged = <String>{...existing, ...normalizedIds};
    mapping[trimmed] = merged;
    await _writeAll(mapping);
  }

  Map<String, Set<String>> _readAll() {
    final raw = _storage.read(_storageKey);
    if (raw is! Map) {
      return <String, Set<String>>{};
    }
    final Map<String, Set<String>> result = <String, Set<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      final value = entry.value;
      if (value is! List) {
        continue;
      }
      final List<String> ids = value.whereType<String>().toList();
      if (ids.isEmpty) {
        continue;
      }
      result[key] = ids.toSet();
    }
    return result;
  }

  Future<void> _writeAll(Map<String, Set<String>> mapping) async {
    final Map<String, List<String>> encoded = <String, List<String>>{};
    for (final entry in mapping.entries) {
      final String key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final List<String> values =
          entry.value
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList()
            ..sort();
      if (values.isEmpty) {
        continue;
      }
      encoded[key] = values;
    }
    await _storage.write(_storageKey, encoded);
  }
}
