import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import 'calendar_ics_meta.dart';
import 'calendar_item.dart';
import 'reminder_preferences.dart';

part 'day_event.freezed.dart';
part 'day_event.g.dart';

const int _dayEventIcsMetaField = 8;

@freezed
@HiveType(typeId: 40)
class DayEvent with _$DayEvent implements CalendarItemBase {
  const factory DayEvent({
    @HiveField(0) required String id,
    @HiveField(1) required String title,
    @HiveField(2) required DateTime startDate,
    @HiveField(3) DateTime? endDate,
    @HiveField(4) String? description,
    @HiveField(5) ReminderPreferences? reminders,
    @HiveField(6) required DateTime createdAt,
    @HiveField(7) required DateTime modifiedAt,
    @HiveField(_dayEventIcsMetaField) CalendarIcsMeta? icsMeta,
  }) = _DayEvent;

  const DayEvent._();

  @override
  CalendarItemType get itemType => CalendarItemType.event;

  factory DayEvent.fromJson(Map<String, dynamic> json) =>
      _$DayEventFromJson(json);

  factory DayEvent.create({
    required String title,
    required DateTime startDate,
    DateTime? endDate,
    String? description,
    ReminderPreferences? reminders,
  }) {
    final DateTime normalizedStart = _midnight(startDate);
    final DateTime normalizedEnd =
        _midnight(endDate ?? startDate).isBefore(normalizedStart)
            ? normalizedStart
            : _midnight(endDate ?? startDate);
    final DateTime now = DateTime.now();
    return DayEvent(
      id: const Uuid().v4(),
      title: title,
      startDate: normalizedStart,
      endDate: normalizedEnd,
      description: description,
      reminders: reminders?.normalized() ?? ReminderPreferences.defaults(),
      createdAt: now,
      modifiedAt: now,
    );
  }

  ReminderPreferences get effectiveReminders =>
      (reminders ?? ReminderPreferences.defaults()).normalized();

  DateTime get normalizedStart => _midnight(startDate);

  DateTime get normalizedEnd {
    final DateTime resolvedEnd = endDate ?? startDate;
    if (resolvedEnd.isBefore(normalizedStart)) {
      return normalizedStart;
    }
    return _midnight(resolvedEnd);
  }

  bool occursOn(DateTime date) {
    final DateTime target = _midnight(date);
    return !target.isBefore(normalizedStart) && !target.isAfter(normalizedEnd);
  }

  DayEvent normalizedCopy({
    DateTime? startDate,
    DateTime? endDate,
    String? title,
    String? description,
    ReminderPreferences? reminders,
    DateTime? modifiedAt,
  }) {
    final DateTime resolvedStart = _midnight(startDate ?? this.startDate);
    final DateTime resolvedEnd = _midnight(
      endDate ?? this.endDate ?? startDate ?? this.startDate,
    );
    final DateTime normalizedEnd =
        resolvedEnd.isBefore(resolvedStart) ? resolvedStart : resolvedEnd;

    final ReminderPreferences effectiveReminders =
        (reminders ?? this.reminders)?.normalized() ??
            ReminderPreferences.defaults();

    return copyWith(
      title: title ?? this.title,
      description: description ?? this.description,
      startDate: resolvedStart,
      endDate: normalizedEnd,
      reminders: effectiveReminders,
      modifiedAt: modifiedAt ?? this.modifiedAt,
    );
  }

  static DateTime _midnight(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
