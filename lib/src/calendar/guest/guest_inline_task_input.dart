// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/utils/nl_parser_service.dart';
import 'package:axichat/src/calendar/utils/nl_schedule_adapter.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/view/controllers/inline_task_composer_controller.dart';
import 'package:axichat/src/calendar/view/widgets/task_field_character_hint.dart';
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
  late final InlineTaskComposerController _composerController;
  late final NlScheduleParserService _parserService;
  bool _isSubmitting = false;
  Timer? _parserDebounce;
  int _parserRequestId = 0;
  String _lastParserText = '';
  NlAdapterResult? _cachedParserResult;
  String? _titleError;
  String? _formError;
  String? _parserNote;

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
    _updateTitleValidation(value);
    if (_formError != null || _parserNote != null) {
      setState(() {
        _formError = null;
        _parserNote = null;
      });
    }
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
    if (_parserNote != null && mounted) {
      setState(() {
        _parserNote = null;
      });
    }
    if (clearSuggestions) {
      _composerController.clearParserSuggestions();
    }
  }

  void _updateTitleValidation(String raw) {
    final bool tooLong = TaskTitleValidation.isTooLong(raw);
    final bool hasContent = raw.trim().isNotEmpty;
    String? nextError = _titleError;

    if (tooLong) {
      nextError = calendarTaskTitleFriendlyError;
    } else {
      if (_titleError == calendarTaskTitleFriendlyError) {
        nextError = null;
      }
      if (_titleError == TaskTitleValidation.requiredMessage && hasContent) {
        nextError = null;
      }
    }

    if (nextError != _titleError) {
      setState(() {
        _titleError = nextError;
      });
    }
  }

  Future<void> _handleSubmit() async {
    final text = _controller.text.trim();
    if (_isSubmitting) return;

    final validationError = TaskTitleValidation.validate(_controller.text);
    if (validationError != null) {
      setState(() {
        _titleError = validationError;
        _formError = null;
      });
      return;
    }

    if (text.isEmpty) {
      return;
    }

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
      Duration? duration = task.duration;

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
        if (duration != null) {
          endDate = scheduledTime.add(duration);
        } else {
          duration = const Duration(hours: 1);
          endDate = scheduledTime.add(duration);
        }
      }

      if (!mounted) return;
      context.read<GuestCalendarBloc>().add(
            CalendarEvent.taskAdded(
              title: task.title,
              scheduledTime: scheduledTime,
              duration: duration,
              deadline: task.deadline,
              location: task.location,
              endDate: endDate,
              priority: task.priority ?? TaskPriority.none,
              recurrence: task.recurrence,
            ),
          );

      setState(() {
        _formError = null;
        _parserNote = result.parseNotes;
      });

      _controller.clear();
      setState(() {
        _titleError = null;
      });
      _composerController.resetSchedule();
      _resetParserState();
      _focusNode.requestFocus();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _formError = context.l10n.calendarAddTaskError('$error');
      });
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
      builder: (dialogContext, child) => InBoundsFadeScaleChild(child: child),
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
      builder: (dialogContext, child) => InBoundsFadeScaleChild(child: child),
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TaskTextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  hintText: context.l10n.calendarAddTaskInputHint,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSubmit(),
                  onChanged: _handleTextChanged,
                  errorText: _titleError,
                ),
                TaskFieldCharacterHint(controller: _controller),
                if (_formError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: calendarInsetMd),
                    child: Text(
                      _formError!,
                      style: context.textTheme.small.copyWith(
                        color: calendarDangerColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (_parserNote != null && _formError == null)
                  Padding(
                    padding: const EdgeInsets.only(top: calendarInsetMd),
                    child: Text(
                      _parserNote!,
                      style: context.textTheme.small.copyWith(
                        color: context.colorScheme.mutedForeground,
                      ),
                    ),
                  ),
              ],
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
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _controller,
                builder: (context, value, _) {
                  final bool canSubmit = !_isSubmitting &&
                      _titleError == null &&
                      value.text.trim().isNotEmpty;
                  return TaskFormActionsRow(
                    padding: EdgeInsets.zero,
                    gap: calendarGutterSm,
                    children: [
                      Expanded(
                        child: TaskPrimaryButton(
                          label: 'Add task',
                          onPressed: canSubmit ? _handleSubmit : null,
                        ),
                      ),
                      Expanded(
                        child: TaskToolbarButton(
                          label: context.l10n.commonClear,
                          onPressed: () {
                            _controller.clear();
                            _composerController.resetSchedule();
                            _resetParserState(clearSuggestions: true);
                            setState(() {
                              _formError = null;
                              _titleError = null;
                            });
                            _focusNode.unfocus();
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }
}
