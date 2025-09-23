import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/calendar_model.dart';
import '../models/calendar_task.dart';

part 'calendar_state.freezed.dart';

@freezed
class CalendarState with _$CalendarState {
  const CalendarState._();

  const factory CalendarState({
    required CalendarModel model,
    @Default(false) bool isLoading,
    String? error,
  }) = _CalendarState;

  factory CalendarState.initial() => CalendarState(
        model: CalendarModel.empty(),
      );

  CalendarView get viewMode => model.view;
  DateTime get selectedDate => model.selectedDate;

  List<CalendarTask> get unscheduledTasks => model.unscheduledTasks;
  List<CalendarTask> get scheduledTasks => model.scheduledTasks;
  List<CalendarTask> get tasksForSelectedDay => model.tasksForSelectedDay;
  List<CalendarTask> get tasksForSelectedWeek => model.tasksForSelectedWeek;
  DateTime get weekStart => model.weekStart;
  DateTime get weekEnd => model.weekEnd;
}
