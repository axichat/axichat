import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../utils/smart_parser.dart';
import 'controllers/inline_task_composer_controller.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';

/// Simple inline text field for quick task creation with smart parsing
class InlineTaskInput extends StatefulWidget {
  const InlineTaskInput({super.key});

  @override
  State<InlineTaskInput> createState() => _InlineTaskInputState();
}

class _InlineTaskInputState extends State<InlineTaskInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late final InlineTaskComposerController _composerController;

  @override
  void initState() {
    super.initState();
    _composerController = InlineTaskComposerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Parse the input text
    final parseResult = SmartTaskParser.parse(text);

    // If user manually selected date/time, use those instead
    DateTime? scheduledTime = parseResult.scheduledTime;
    final DateTime? selectedDate = _composerController.selectedDate;
    final TimeOfDay? selectedTime = _composerController.selectedTime;
    if (selectedDate != null || selectedTime != null) {
      final date = selectedDate ?? DateTime.now();
      final time = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
      scheduledTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    }

    // Add to calendar
    context.read<CalendarBloc>().add(CalendarEvent.taskAdded(
          title: parseResult.title,
          scheduledTime: scheduledTime,
        ));

    // Clear input
    _controller.clear();
    _composerController.resetSchedule();
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _composerController.selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      _composerController
        ..setDate(date)
        ..expand();
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _composerController.selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      _composerController
        ..setTime(time)
        ..expand();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _composerController,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TaskTextField(
              controller: _controller,
              focusNode: _focusNode,
              hintText: 'Add task... (e.g., "Meeting tomorrow at 3pm")',
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSubmit(),
              onChanged: (_) => _composerController.expand(),
            ),
            if (_composerController.isExpanded) ...[
              const SizedBox(height: 8),
              TaskDateTimeToolbar(
                padding: EdgeInsets.zero,
                gap: calendarSpacing8,
                primaryField: TaskDateTimeToolbarField(
                  selectedDate: _composerController.selectedDate,
                  selectedTime: _composerController.selectedTime,
                  onSelectDate: _selectDate,
                  onSelectTime: _selectTime,
                  emptyDateLabel: 'Pick date',
                  emptyTimeLabel: 'Pick time',
                ),
                onClear: () {
                  _composerController.resetSchedule();
                  _focusNode.unfocus();
                },
              ),
              const SizedBox(height: calendarSpacing8),
              TaskFormActionsRow(
                padding: EdgeInsets.zero,
                gap: calendarSpacing8,
                children: [
                  Expanded(
                    child: TaskPrimaryButton(
                      label: 'Add task',
                      onPressed: _handleSubmit,
                    ),
                  ),
                  Expanded(
                    child: TaskToolbarButton(
                      label: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        _composerController.resetSchedule();
                        _focusNode.unfocus();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
