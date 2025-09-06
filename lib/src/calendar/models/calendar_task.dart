import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'calendar_task.freezed.dart';
part 'calendar_task.g.dart';

@freezed
@HiveType(typeId: 30)
class CalendarTask with _$CalendarTask {
  const factory CalendarTask({
    @HiveField(0) required String id,
    @HiveField(1) required String title,
    @HiveField(2) String? description,
    @HiveField(3) DateTime? scheduledTime,
    @HiveField(4) Duration? duration,
    @HiveField(5) @Default(false) bool isCompleted,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) required DateTime modifiedAt,
    @HiveField(8) required String deviceId,
  }) = _CalendarTask;

  factory CalendarTask.fromJson(Map<String, dynamic> json) =>
      _$CalendarTaskFromJson(json);

  factory CalendarTask.create({
    required String title,
    String? description,
    DateTime? scheduledTime,
    Duration? duration,
    required String deviceId,
  }) {
    final now = DateTime.now();
    return CalendarTask(
      id: const Uuid().v4(),
      title: title,
      description: description,
      scheduledTime: scheduledTime,
      duration: duration,
      createdAt: now,
      modifiedAt: now,
      deviceId: deviceId,
    );
  }
}
