// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'calendar_critical_path.freezed.dart';
part 'calendar_critical_path.g.dart';

@freezed
@HiveType(typeId: 37)
class CalendarCriticalPath with _$CalendarCriticalPath {
  const factory CalendarCriticalPath({
    @HiveField(0) required String id,
    @HiveField(1) required String name,
    @HiveField(2) @Default(<String>[]) List<String> taskIds,
    @HiveField(3) @Default(false) bool isArchived,
    @HiveField(4) required DateTime createdAt,
    @HiveField(5) required DateTime modifiedAt,
  }) = _CalendarCriticalPath;

  factory CalendarCriticalPath.fromJson(Map<String, dynamic> json) =>
      _$CalendarCriticalPathFromJson(json);

  factory CalendarCriticalPath.create({
    required String name,
  }) {
    final now = DateTime.now();
    return CalendarCriticalPath(
      id: const Uuid().v4(),
      name: name,
      taskIds: const <String>[],
      isArchived: false,
      createdAt: now,
      modifiedAt: now,
    );
  }
}

extension CalendarCriticalPathX on CalendarCriticalPath {
  CalendarCriticalPath addTask(String taskId, {int? index}) {
    final sanitizedId = taskId.trim();
    if (sanitizedId.isEmpty) {
      return this;
    }
    final existing =
        List<String>.from(taskIds.where((id) => id != sanitizedId));
    final insertionIndex =
        index != null ? index.clamp(0, existing.length) : existing.length;
    existing.insert(insertionIndex, sanitizedId);
    return copyWith(
      taskIds: existing,
      modifiedAt: DateTime.now(),
      isArchived: false,
    );
  }

  CalendarCriticalPath removeTask(String taskId) {
    final sanitizedId = taskId.trim();
    final filtered = taskIds.where((id) => id != sanitizedId).toList();
    if (filtered.length == taskIds.length) {
      return this;
    }
    return copyWith(
      taskIds: filtered,
      modifiedAt: DateTime.now(),
    );
  }

  CalendarCriticalPath rename(String nextName) {
    final trimmed = nextName.trim();
    if (trimmed.isEmpty || trimmed == name) {
      return this;
    }
    return copyWith(
      name: trimmed,
      modifiedAt: DateTime.now(),
    );
  }

  CalendarCriticalPath archive() => copyWith(
        isArchived: true,
        modifiedAt: DateTime.now(),
      );
}
