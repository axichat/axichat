// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

part 'calendar_date_time.freezed.dart';
part 'calendar_date_time.g.dart';

const int _calendarDateTimeTypeId = 41;
const int _calendarDateTimeValueField = 0;
const int _calendarDateTimeTzidField = 1;
const int _calendarDateTimeIsAllDayField = 2;
const int _calendarDateTimeIsFloatingField = 3;
const bool _calendarDateTimeDefaultAllDay = false;
const bool _calendarDateTimeDefaultFloating = false;

const int _calendarWeekdayTypeId = 42;
const int _calendarWeekdayMondayField = 0;
const int _calendarWeekdayTuesdayField = 1;
const int _calendarWeekdayWednesdayField = 2;
const int _calendarWeekdayThursdayField = 3;
const int _calendarWeekdayFridayField = 4;
const int _calendarWeekdaySaturdayField = 5;
const int _calendarWeekdaySundayField = 6;

const String _calendarWeekdayMondayIcs = 'MO';
const String _calendarWeekdayTuesdayIcs = 'TU';
const String _calendarWeekdayWednesdayIcs = 'WE';
const String _calendarWeekdayThursdayIcs = 'TH';
const String _calendarWeekdayFridayIcs = 'FR';
const String _calendarWeekdaySaturdayIcs = 'SA';
const String _calendarWeekdaySundayIcs = 'SU';

const CalendarWeekday _calendarWeekdayFallback = CalendarWeekday.monday;

const int _recurrenceWeekdayTypeId = 43;
const int _recurrenceWeekdayDayField = 0;
const int _recurrenceWeekdayPositionField = 1;

const int _recurrenceRangeTypeId = 44;
const int _recurrenceRangeThisAndFutureField = 0;
const int _recurrenceRangeThisAndPriorField = 1;

const String _recurrenceRangeThisAndFutureIcs = 'THISANDFUTURE';
const String _recurrenceRangeThisAndPriorIcs = 'THISANDPRIOR';

const RecurrenceRange _recurrenceRangeFallback = RecurrenceRange.thisAndFuture;

@freezed
@HiveType(typeId: _calendarDateTimeTypeId)
class CalendarDateTime with _$CalendarDateTime {
  const factory CalendarDateTime({
    @HiveField(_calendarDateTimeValueField) required DateTime value,
    @HiveField(_calendarDateTimeTzidField) String? tzid,
    @HiveField(_calendarDateTimeIsAllDayField)
    @Default(_calendarDateTimeDefaultAllDay)
    bool isAllDay,
    @HiveField(_calendarDateTimeIsFloatingField)
    @Default(_calendarDateTimeDefaultFloating)
    bool isFloating,
  }) = _CalendarDateTime;

  factory CalendarDateTime.fromJson(Map<String, dynamic> json) =>
      _$CalendarDateTimeFromJson(json);
}

@HiveType(typeId: _calendarWeekdayTypeId)
enum CalendarWeekday {
  @HiveField(_calendarWeekdayMondayField)
  monday,
  @HiveField(_calendarWeekdayTuesdayField)
  tuesday,
  @HiveField(_calendarWeekdayWednesdayField)
  wednesday,
  @HiveField(_calendarWeekdayThursdayField)
  thursday,
  @HiveField(_calendarWeekdayFridayField)
  friday,
  @HiveField(_calendarWeekdaySaturdayField)
  saturday,
  @HiveField(_calendarWeekdaySundayField)
  sunday;

  bool get isMonday => this == CalendarWeekday.monday;
  bool get isTuesday => this == CalendarWeekday.tuesday;
  bool get isWednesday => this == CalendarWeekday.wednesday;
  bool get isThursday => this == CalendarWeekday.thursday;
  bool get isFriday => this == CalendarWeekday.friday;
  bool get isSaturday => this == CalendarWeekday.saturday;
  bool get isSunday => this == CalendarWeekday.sunday;

  int get isoValue => switch (this) {
        CalendarWeekday.monday => DateTime.monday,
        CalendarWeekday.tuesday => DateTime.tuesday,
        CalendarWeekday.wednesday => DateTime.wednesday,
        CalendarWeekday.thursday => DateTime.thursday,
        CalendarWeekday.friday => DateTime.friday,
        CalendarWeekday.saturday => DateTime.saturday,
        CalendarWeekday.sunday => DateTime.sunday,
      };

  String get icsValue => switch (this) {
        CalendarWeekday.monday => _calendarWeekdayMondayIcs,
        CalendarWeekday.tuesday => _calendarWeekdayTuesdayIcs,
        CalendarWeekday.wednesday => _calendarWeekdayWednesdayIcs,
        CalendarWeekday.thursday => _calendarWeekdayThursdayIcs,
        CalendarWeekday.friday => _calendarWeekdayFridayIcs,
        CalendarWeekday.saturday => _calendarWeekdaySaturdayIcs,
        CalendarWeekday.sunday => _calendarWeekdaySundayIcs,
      };

  static CalendarWeekday fromIsoValue(int value) => switch (value) {
        DateTime.monday => CalendarWeekday.monday,
        DateTime.tuesday => CalendarWeekday.tuesday,
        DateTime.wednesday => CalendarWeekday.wednesday,
        DateTime.thursday => CalendarWeekday.thursday,
        DateTime.friday => CalendarWeekday.friday,
        DateTime.saturday => CalendarWeekday.saturday,
        DateTime.sunday => CalendarWeekday.sunday,
        _ => _calendarWeekdayFallback,
      };

  static CalendarWeekday? fromIcsValue(String? value) => switch (value) {
        _calendarWeekdayMondayIcs => CalendarWeekday.monday,
        _calendarWeekdayTuesdayIcs => CalendarWeekday.tuesday,
        _calendarWeekdayWednesdayIcs => CalendarWeekday.wednesday,
        _calendarWeekdayThursdayIcs => CalendarWeekday.thursday,
        _calendarWeekdayFridayIcs => CalendarWeekday.friday,
        _calendarWeekdaySaturdayIcs => CalendarWeekday.saturday,
        _calendarWeekdaySundayIcs => CalendarWeekday.sunday,
        _ => null,
      };
}

@freezed
@HiveType(typeId: _recurrenceWeekdayTypeId)
class RecurrenceWeekday with _$RecurrenceWeekday {
  const factory RecurrenceWeekday({
    @HiveField(_recurrenceWeekdayDayField) required CalendarWeekday weekday,
    @HiveField(_recurrenceWeekdayPositionField) int? position,
  }) = _RecurrenceWeekday;

  factory RecurrenceWeekday.fromJson(Map<String, dynamic> json) =>
      _$RecurrenceWeekdayFromJson(json);
}

@HiveType(typeId: _recurrenceRangeTypeId)
enum RecurrenceRange {
  @HiveField(_recurrenceRangeThisAndFutureField)
  thisAndFuture,
  @HiveField(_recurrenceRangeThisAndPriorField)
  thisAndPrior;

  bool get isThisAndFuture => this == RecurrenceRange.thisAndFuture;
  bool get isThisAndPrior => this == RecurrenceRange.thisAndPrior;

  String get icsValue => switch (this) {
        RecurrenceRange.thisAndFuture => _recurrenceRangeThisAndFutureIcs,
        RecurrenceRange.thisAndPrior => _recurrenceRangeThisAndPriorIcs,
      };

  static RecurrenceRange fromIcsValue(String? value) => switch (value) {
        _recurrenceRangeThisAndFutureIcs => RecurrenceRange.thisAndFuture,
        _recurrenceRangeThisAndPriorIcs => RecurrenceRange.thisAndPrior,
        _ => _recurrenceRangeFallback,
      };
}
