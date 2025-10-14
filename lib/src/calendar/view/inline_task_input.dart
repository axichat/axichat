import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../utils/smart_parser.dart';
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
  bool _isExpanded = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    // Parse the input text
    final parseResult = SmartTaskParser.parse(text);

    // If user manually selected date/time, use those instead
    DateTime? scheduledTime = parseResult.scheduledTime;
    if (_selectedDate != null || _selectedTime != null) {
      final date = _selectedDate ?? DateTime.now();
      final time = _selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
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
    _selectedDate = null;
    _selectedTime = null;
    setState(() {
      _isExpanded = false;
    });
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
      });
    }
  }

  Future<void> _selectTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TaskTextField(
          controller: _controller,
          focusNode: _focusNode,
          hintText: 'Add task... (e.g., "Meeting tomorrow at 3pm")',
          textInputAction: TextInputAction.send,
          onSubmitted: (_) => _handleSubmit(),
          onChanged: (_) {
            if (!_isExpanded) {
              setState(() => _isExpanded = true);
            }
          },
        ),

        // Optional controls (shown when focused)
        if (_isExpanded) ...[
          const SizedBox(height: 8),
          TaskDateTimePickerRow(
            selectedDate: _selectedDate,
            selectedTime: _selectedTime,
            onSelectDate: _selectDate,
            onSelectTime: _selectTime,
            onClear: () {
              setState(() {
                _isExpanded = false;
                _selectedDate = null;
                _selectedTime = null;
              });
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
                    setState(() {
                      _selectedDate = null;
                      _selectedTime = null;
                      _isExpanded = false;
                    });
                    _focusNode.unfocus();
                  },
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
