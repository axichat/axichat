import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/utils/smart_parser.dart';
import 'package:axichat/src/calendar/view/widgets/task_form_section.dart';
import 'package:axichat/src/calendar/view/widgets/task_text_field.dart';

import 'guest_calendar_bloc.dart';

/// Simple inline text field for quick task creation with smart parsing for guest mode
class GuestInlineTaskInput extends StatefulWidget {
  const GuestInlineTaskInput({super.key});

  @override
  State<GuestInlineTaskInput> createState() => _GuestInlineTaskInputState();
}

class _GuestInlineTaskInputState extends State<GuestInlineTaskInput> {
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

    // Add to guest calendar
    context.read<GuestCalendarBloc>().add(CalendarEvent.taskAdded(
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
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today, size: 16),
                  label: Text(
                    _selectedDate != null
                        ? DateFormat.yMMMd().format(_selectedDate!)
                        : 'Pick date',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _selectTime,
                  icon: const Icon(Icons.schedule, size: 16),
                  label: Text(
                    _selectedTime != null
                        ? _selectedTime!.format(context)
                        : 'Pick time',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                    _selectedDate = null;
                    _selectedTime = null;
                  });
                  _focusNode.unfocus();
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          TaskFormActionsRow(
            padding: EdgeInsets.zero,
            gap: 8,
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _handleSubmit,
                  child: const Text('Add task'),
                ),
              ),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    _controller.clear();
                    setState(() {
                      _selectedDate = null;
                      _selectedTime = null;
                      _isExpanded = false;
                    });
                    _focusNode.unfocus();
                  },
                  child: const Text('Clear'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
