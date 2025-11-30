import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/bloc/calendar_bloc.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'unified_task_input.dart';

// Legacy wrapper - use UnifiedTaskInput<CalendarBloc> instead
@Deprecated('Use UnifiedTaskInput<CalendarBloc> directly')
class TaskInput extends UnifiedTaskInput<CalendarBloc> {
  const TaskInput({
    super.key,
    super.editingTask,
    super.initialDate,
    super.initialTime,
  });
}

// Helper function to show the task input
void showTaskInput(
  BuildContext context, {
  CalendarTask? editingTask,
  DateTime? initialDate,
  TimeOfDay? initialTime,
}) {
  showUnifiedTaskInput<CalendarBloc>(
    context,
    editingTask: editingTask,
    initialDate: initialDate,
    initialTime: initialTime,
  );
}
