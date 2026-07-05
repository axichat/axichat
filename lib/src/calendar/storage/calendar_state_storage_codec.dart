// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';

const String _calendarStateModelKey = 'model';
const String _calendarStateSelectedDateKey = 'selectedDate';
const String _calendarStateViewModeKey = 'viewMode';
const String _calendarStateSelectedDayIndexKey = 'selectedDayIndex';
const String _calendarStateAcknowledgedAlertKeysKey =
    'acknowledgedCalendarAlertKeys';

class CalendarStateStorageCodec {
  const CalendarStateStorageCodec._();

  static CalendarState? decode(Map<String, dynamic>? json) {
    if (json == null) {
      return null;
    }
    final modelJson = json[_calendarStateModelKey];
    final selectedDate = json[_calendarStateSelectedDateKey] as String?;
    final view = json[_calendarStateViewModeKey] as String?;
    final selectedDayIndex = json[_calendarStateSelectedDayIndexKey] as int?;
    final acknowledgedAlertKeys = _decodeStringSet(
      json[_calendarStateAcknowledgedAlertKeysKey],
    );

    if (modelJson is! Map<String, dynamic> ||
        selectedDate == null ||
        view == null) {
      return null;
    }

    final model = CalendarModel.fromJson(modelJson);
    final parsedDate = DateTime.parse(selectedDate);
    final viewMode = CalendarView.values.firstWhere(
      (element) => element.name == view,
      orElse: () => CalendarView.week,
    );

    return CalendarState(
      model: model,
      selectedDate: parsedDate,
      viewMode: viewMode,
      selectedDayIndex: selectedDayIndex,
      acknowledgedCalendarAlertKeys: acknowledgedAlertKeys,
    );
  }

  static Map<String, dynamic>? encode(CalendarState state) {
    return {
      _calendarStateModelKey: state.model.toJson(),
      _calendarStateSelectedDateKey: state.selectedDate.toIso8601String(),
      _calendarStateViewModeKey: state.viewMode.name,
      if (state.selectedDayIndex != null)
        _calendarStateSelectedDayIndexKey: state.selectedDayIndex,
      if (state.acknowledgedCalendarAlertKeys.isNotEmpty)
        _calendarStateAcknowledgedAlertKeysKey:
            state.acknowledgedCalendarAlertKeys.toList()..sort(),
    };
  }

  static Set<String> _decodeStringSet(Object? raw) {
    if (raw is! List) {
      return const <String>{};
    }
    final values = <String>{};
    for (final Object? value in raw) {
      if (value is! String || value.trim().isEmpty) {
        continue;
      }
      values.add(value);
    }
    return values;
  }
}
