import 'dart:convert';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:crypto/crypto.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_model.freezed.dart';
part 'calendar_model.g.dart';

@freezed
@HiveType(typeId: 31)
class CalendarModel with _$CalendarModel {
  const factory CalendarModel({
    @HiveField(0) @Default({}) Map<String, CalendarTask> tasks,
    @HiveField(1) required DateTime lastModified,
    @HiveField(2) required String deviceId,
    @HiveField(3) required String checksum,
  }) = _CalendarModel;

  factory CalendarModel.fromJson(Map<String, dynamic> json) =>
      _$CalendarModelFromJson(json);

  factory CalendarModel.empty(String deviceId) {
    final now = DateTime.now();
    final model = CalendarModel(
      lastModified: now,
      deviceId: deviceId,
      checksum: '',
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }

  const CalendarModel._();

  String calculateChecksum() {
    final sortedTasks = Map.fromEntries(
      tasks.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    );
    final content = jsonEncode({
      'tasks': sortedTasks.map((k, v) => MapEntry(k, v.toJson())),
      'lastModified': lastModified.toIso8601String(),
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
    );
    return updated.copyWith(checksum: updated.calculateChecksum());
  }
}
