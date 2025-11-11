import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';

import '../bloc/calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../models/calendar_task.dart';
import '../utils/nl_parser_service.dart';
import '../utils/nl_schedule_adapter.dart';
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
  late final NlScheduleParserService _parserService;
  bool _isSubmitting = false;
  Timer? _parserDebounce;
  int _parserRequestId = 0;
  String _lastParserText = '';
  NlAdapterResult? _cachedParserResult;

  @override
  void initState() {
    super.initState();
    _composerController = InlineTaskComposerController();
    _parserService = NlScheduleParserService();
  }

  @override
  void dispose() {
    _parserDebounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _composerController.dispose();
    super.dispose();
  }

  void _handleTextChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      _resetParserState(clearSuggestions: true);
      return;
    }
    _composerController.expand();
    if (trimmed == _lastParserText) {
      return;
    }
    _parserDebounce?.cancel();
    _parserDebounce = Timer(const Duration(milliseconds: 350), () {
      _runParser(trimmed);
    });
  }

  Future<void> _runParser(String text) async {
    final requestId = ++_parserRequestId;
    try {
      final result = await _parserService.parse(text);
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _cachedParserResult = result;
      _lastParserText = text;
      _composerController.applyParserSchedule(result.task.scheduledTime);
    } catch (_) {
      if (!mounted || requestId != _parserRequestId) {
        return;
      }
      _cachedParserResult = null;
      _lastParserText = '';
      _composerController.clearParserSuggestions();
    }
  }

  void _resetParserState({bool clearSuggestions = false}) {
    _parserDebounce?.cancel();
    _parserRequestId++;
    _cachedParserResult = null;
    _lastParserText = '';
    if (clearSuggestions) {
      _composerController.clearParserSuggestions();
    }
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final bool reuseParser =
          _cachedParserResult != null && text == _lastParserText;
      final NlAdapterResult result =
          reuseParser ? _cachedParserResult! : await _parserService.parse(text);

      if (!reuseParser) {
        _cachedParserResult = result;
        _lastParserText = text;
      }

      final task = result.task;
      DateTime? scheduledTime = task.scheduledTime;
      DateTime? endDate = task.endDate;
      final Duration? durationFromParser = task.duration;
      Duration? duration = durationFromParser;
      double? startHour = task.startHour;

      final DateTime? selectedDate = _composerController.selectedDate;
      final TimeOfDay? selectedTime = _composerController.selectedTime;
      if (selectedDate != null || selectedTime != null) {
        final date = selectedDate ?? DateTime.now();
        final time = selectedTime ?? const TimeOfDay(hour: 9, minute: 0);
        final localManual = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        scheduledTime = localManual;
        startHour = time.hour + (time.minute / 60.0);
        if (duration != null) {
          endDate = scheduledTime.add(duration);
        } else {
          duration = const Duration(hours: 1);
          endDate = scheduledTime.add(duration);
        }
      }

      if (!mounted) return;
      context.read<CalendarBloc>().add(
            CalendarEvent.taskAdded(
              title: task.title,
              scheduledTime: scheduledTime,
              duration: duration,
              deadline: task.deadline,
              location: task.location,
              endDate: endDate,
              priority: task.priority ?? TaskPriority.none,
              startHour: startHour,
              recurrence: task.recurrence,
            ),
          );

      if (result.parseNotes != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.parseNotes!)),
        );
      }

      _controller.clear();
      _composerController.resetSchedule();
      _resetParserState();
      _focusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add task: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
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
        ..setDate(date, fromUser: true)
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
        ..setTime(time, fromUser: true)
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
              onChanged: _handleTextChanged,
            ),
            if (_composerController.isExpanded) ...[
              const SizedBox(height: calendarGutterSm),
              TaskDateTimeToolbar(
                padding: EdgeInsets.zero,
                gap: calendarGutterSm,
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
              const SizedBox(height: calendarGutterSm),
              TaskFormActionsRow(
                padding: EdgeInsets.zero,
                gap: calendarGutterSm,
                children: [
                  Expanded(
                    child: TaskPrimaryButton(
                      label: 'Add task',
                      onPressed: _isSubmitting ? null : () => _handleSubmit(),
                    ),
                  ),
                  Expanded(
                    child: TaskToolbarButton(
                      label: 'Clear',
                      onPressed: () {
                        _controller.clear();
                        _composerController.resetSchedule();
                        _resetParserState(clearSuggestions: true);
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
