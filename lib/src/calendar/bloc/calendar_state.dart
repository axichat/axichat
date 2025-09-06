import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';
import 'calendar_event.dart';

part 'calendar_state.freezed.dart';

@freezed
class CalendarState with _$CalendarState {
  const factory CalendarState({
    required CalendarModel model,
    @Default(false) bool isSyncing,
    @Default(false) bool isLoading,
    DateTime? lastSyncTime,
    String? syncError,
    String? error,
    @Default(CalendarView.week) CalendarView viewMode,
    required DateTime selectedDate,
    List<CalendarTask>? dueReminders,
    CalendarTask? nextTask,
  }) = _CalendarState;

  factory CalendarState.initial(String deviceId) => CalendarState(
        model: CalendarModel.empty(deviceId),
        selectedDate: DateTime.now(),
      );
}
