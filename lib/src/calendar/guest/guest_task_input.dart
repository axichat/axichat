import 'package:flutter/material.dart';

import '../models/calendar_task.dart';
import '../view/unified_task_input.dart';
import 'guest_calendar_bloc.dart';

// Legacy wrapper - use UnifiedTaskInput<GuestCalendarBloc> instead
@Deprecated('Use UnifiedTaskInput<GuestCalendarBloc> directly')
class GuestTaskInput extends UnifiedTaskInput<GuestCalendarBloc> {
  const GuestTaskInput({
    super.key,
    super.editingTask,
    super.initialDate,
    super.initialTime,
  });
}

// Helper function to show the guest task input
void showGuestTaskInput(
  BuildContext context, {
  CalendarTask? editingTask,
  DateTime? initialDate,
  TimeOfDay? initialTime,
}) {
  showUnifiedTaskInput<GuestCalendarBloc>(
    context,
    editingTask: editingTask,
    initialDate: initialDate,
    initialTime: initialTime,
  );
}
