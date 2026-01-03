// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'calendar_date_time.dart';
import 'calendar_ics_meta.dart';

part 'calendar_availability.freezed.dart';
part 'calendar_availability.g.dart';

const int _calendarFreeBusyTypeTypeId = 72;
const int _calendarFreeBusyTypeFreeField = 0;
const int _calendarFreeBusyTypeBusyField = 1;
const int _calendarFreeBusyTypeBusyUnavailableField = 2;
const int _calendarFreeBusyTypeBusyTentativeField = 3;

const int _calendarFreeBusyIntervalTypeId = 73;
const int _calendarFreeBusyIntervalStartField = 0;
const int _calendarFreeBusyIntervalEndField = 1;
const int _calendarFreeBusyIntervalTypeField = 2;

const int _calendarAvailabilityWindowTypeId = 74;
const int _calendarAvailabilityWindowStartField = 0;
const int _calendarAvailabilityWindowEndField = 1;
const int _calendarAvailabilityWindowSummaryField = 2;
const int _calendarAvailabilityWindowDescriptionField = 3;

const int _calendarAvailabilityTypeId = 75;
const int _calendarAvailabilityIdField = 0;
const int _calendarAvailabilityStartField = 1;
const int _calendarAvailabilityEndField = 2;
const int _calendarAvailabilitySummaryField = 3;
const int _calendarAvailabilityDescriptionField = 4;
const int _calendarAvailabilityWindowsField = 5;
const int _calendarAvailabilityIcsMetaField = 6;

const int _calendarAvailabilityOverlayTypeId = 76;
const int _calendarAvailabilityOverlayOwnerField = 0;
const int _calendarAvailabilityOverlayRangeStartField = 1;
const int _calendarAvailabilityOverlayRangeEndField = 2;
const int _calendarAvailabilityOverlayIntervalsField = 3;
const int _calendarAvailabilityOverlayIsRedactedField = 4;

const List<CalendarAvailabilityWindow> _emptyAvailabilityWindows =
    <CalendarAvailabilityWindow>[];
const List<CalendarFreeBusyInterval> _emptyFreeBusyIntervals =
    <CalendarFreeBusyInterval>[];
const bool _calendarAvailabilityOverlayDefaultRedacted = true;

const String _calendarFreeBusyTypeFreeIcs = 'FREE';
const String _calendarFreeBusyTypeBusyIcs = 'BUSY';
const String _calendarFreeBusyTypeBusyUnavailableIcs = 'BUSY-UNAVAILABLE';
const String _calendarFreeBusyTypeBusyTentativeIcs = 'BUSY-TENTATIVE';

@HiveType(typeId: _calendarFreeBusyTypeTypeId)
enum CalendarFreeBusyType {
  @HiveField(_calendarFreeBusyTypeFreeField)
  free,
  @HiveField(_calendarFreeBusyTypeBusyField)
  busy,
  @HiveField(_calendarFreeBusyTypeBusyUnavailableField)
  busyUnavailable,
  @HiveField(_calendarFreeBusyTypeBusyTentativeField)
  busyTentative;

  bool get isFree => this == CalendarFreeBusyType.free;
  bool get isBusy => this == CalendarFreeBusyType.busy;
  bool get isBusyUnavailable => this == CalendarFreeBusyType.busyUnavailable;
  bool get isBusyTentative => this == CalendarFreeBusyType.busyTentative;

  String get icsValue => switch (this) {
        CalendarFreeBusyType.free => _calendarFreeBusyTypeFreeIcs,
        CalendarFreeBusyType.busy => _calendarFreeBusyTypeBusyIcs,
        CalendarFreeBusyType.busyUnavailable =>
          _calendarFreeBusyTypeBusyUnavailableIcs,
        CalendarFreeBusyType.busyTentative =>
          _calendarFreeBusyTypeBusyTentativeIcs,
      };

  static CalendarFreeBusyType? fromIcsValue(String? value) => switch (value) {
        _calendarFreeBusyTypeFreeIcs => CalendarFreeBusyType.free,
        _calendarFreeBusyTypeBusyIcs => CalendarFreeBusyType.busy,
        _calendarFreeBusyTypeBusyUnavailableIcs =>
          CalendarFreeBusyType.busyUnavailable,
        _calendarFreeBusyTypeBusyTentativeIcs =>
          CalendarFreeBusyType.busyTentative,
        _ => null,
      };
}

@freezed
@HiveType(typeId: _calendarFreeBusyIntervalTypeId)
class CalendarFreeBusyInterval with _$CalendarFreeBusyInterval {
  const factory CalendarFreeBusyInterval({
    @HiveField(_calendarFreeBusyIntervalStartField)
    required CalendarDateTime start,
    @HiveField(_calendarFreeBusyIntervalEndField) required CalendarDateTime end,
    @HiveField(_calendarFreeBusyIntervalTypeField)
    required CalendarFreeBusyType type,
  }) = _CalendarFreeBusyInterval;

  factory CalendarFreeBusyInterval.fromJson(Map<String, dynamic> json) =>
      _$CalendarFreeBusyIntervalFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAvailabilityWindowTypeId)
class CalendarAvailabilityWindow with _$CalendarAvailabilityWindow {
  const factory CalendarAvailabilityWindow({
    @HiveField(_calendarAvailabilityWindowStartField)
    required CalendarDateTime start,
    @HiveField(_calendarAvailabilityWindowEndField)
    required CalendarDateTime end,
    @HiveField(_calendarAvailabilityWindowSummaryField) String? summary,
    @HiveField(_calendarAvailabilityWindowDescriptionField) String? description,
  }) = _CalendarAvailabilityWindow;

  factory CalendarAvailabilityWindow.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityWindowFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAvailabilityTypeId)
class CalendarAvailability with _$CalendarAvailability {
  const factory CalendarAvailability({
    @HiveField(_calendarAvailabilityIdField) required String id,
    @HiveField(_calendarAvailabilityStartField) required CalendarDateTime start,
    @HiveField(_calendarAvailabilityEndField) required CalendarDateTime end,
    @HiveField(_calendarAvailabilitySummaryField) String? summary,
    @HiveField(_calendarAvailabilityDescriptionField) String? description,
    @HiveField(_calendarAvailabilityWindowsField)
    @Default(_emptyAvailabilityWindows)
    List<CalendarAvailabilityWindow> windows,
    @HiveField(_calendarAvailabilityIcsMetaField) CalendarIcsMeta? icsMeta,
  }) = _CalendarAvailability;

  factory CalendarAvailability.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityFromJson(json);
}

@freezed
@HiveType(typeId: _calendarAvailabilityOverlayTypeId)
class CalendarAvailabilityOverlay with _$CalendarAvailabilityOverlay {
  const factory CalendarAvailabilityOverlay({
    @HiveField(_calendarAvailabilityOverlayOwnerField) required String owner,
    @HiveField(_calendarAvailabilityOverlayRangeStartField)
    required CalendarDateTime rangeStart,
    @HiveField(_calendarAvailabilityOverlayRangeEndField)
    required CalendarDateTime rangeEnd,
    @HiveField(_calendarAvailabilityOverlayIntervalsField)
    @Default(_emptyFreeBusyIntervals)
    List<CalendarFreeBusyInterval> intervals,
    @HiveField(_calendarAvailabilityOverlayIsRedactedField)
    @Default(_calendarAvailabilityOverlayDefaultRedacted)
    bool isRedacted,
  }) = _CalendarAvailabilityOverlay;

  factory CalendarAvailabilityOverlay.fromJson(Map<String, dynamic> json) =>
      _$CalendarAvailabilityOverlayFromJson(json);
}
