import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../utils/time_formatter.dart';
import 'error_display.dart';

class UnifiedTaskInput<T extends BaseCalendarBloc> extends StatefulWidget {
  final CalendarTask? editingTask;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;

  const UnifiedTaskInput({
    super.key,
    this.editingTask,
    this.initialDate,
    this.initialTime,
  });

  @override
  State<UnifiedTaskInput<T>> createState() => _UnifiedTaskInputState<T>();
}

class _UnifiedTaskInputState<T extends BaseCalendarBloc>
    extends State<UnifiedTaskInput<T>> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  Duration? _selectedDuration;
  bool _isSubmitting = false;

  final _formKey = GlobalKey<FormState>();

  static const List<Duration> _durationOptions = [
    Duration(minutes: 15),
    Duration(minutes: 30),
    Duration(hours: 1),
    Duration(hours: 2),
    Duration(hours: 4),
    Duration(hours: 8),
  ];

  @override
  void initState() {
    super.initState();

    _titleController =
        TextEditingController(text: widget.editingTask?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.editingTask?.description ?? '');

    if (widget.editingTask != null) {
      _selectedDate = widget.editingTask!.scheduledTime != null
          ? DateTime(
              widget.editingTask!.scheduledTime!.year,
              widget.editingTask!.scheduledTime!.month,
              widget.editingTask!.scheduledTime!.day,
            )
          : null;
      _selectedTime = widget.editingTask!.scheduledTime != null
          ? TimeOfDay.fromDateTime(widget.editingTask!.scheduledTime!)
          : null;
      _selectedDuration = widget.editingTask!.duration;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      _selectedTime = widget.initialTime ?? TimeOfDay.now();
      _selectedDuration = const Duration(hours: 1);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editingTask != null ? 'Edit Task' : 'New Task'),
        actions: [_buildSaveButton()],
      ),
      body: _buildForm(),
    );
  }

  Widget _buildTabletLayout() {
    return Dialog(
      child: SizedBox(
        width: 500,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(),
            Flexible(child: _buildForm()),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Dialog(
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogHeader(),
            Flexible(child: _buildForm()),
            _buildDialogActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.editingTask != null ? 'Edit Task' : 'New Task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTitleField(),
            const SizedBox(height: 16),
            _buildDescriptionField(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildTimeField(),
            const SizedBox(height: 16),
            _buildDurationField(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitleField() {
    return ShadInputFormField(
      controller: _titleController,
      placeholder: const Text('Task title'),
      validator: (value) {
        if (value.trim().isEmpty) {
          return 'Title is required';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    return ShadInputFormField(
      controller: _descriptionController,
      placeholder: const Text('Description (optional)'),
      maxLines: 3,
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ShadButton.outline(
          onPressed: _selectDate,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_today, size: 16),
              const SizedBox(width: 8),
              Text(_formatDate(_selectedDate)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ShadButton.outline(
          onPressed: _selectTime,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 8),
              Text(_selectedTime == null
                  ? 'Select time'
                  : TimeFormatter.formatTimeOfDay(context, _selectedTime!)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: 8),
        ShadSelect<Duration>(
          placeholder: const Text('Select duration'),
          options: _durationOptions
              .map((duration) => ShadOption(
                    value: duration,
                    child: Text(_formatDuration(duration)),
                  ))
              .toList(),
          selectedOptionBuilder: (context, value) =>
              Text(_formatDuration(value)),
          onChanged: (duration) => setState(() => _selectedDuration = duration),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return TextButton(
      onPressed: _saveTask,
      child: const Text('Save'),
    );
  }

  Widget _buildDialogActions() {
    return BlocConsumer<T, CalendarState>(
      listener: (context, state) {
        if (state.error != null && _isSubmitting) {
          ErrorSnackBar.show(context, state.error!);
          setState(() => _isSubmitting = false);
        } else if (!state.isLoading && _isSubmitting) {
          // Task saved successfully
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null && _isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ErrorDisplay(
                    error: state.error!,
                    onRetry: _saveTask,
                    onDismiss: () => context.read<T>().add(
                          const CalendarEvent.errorCleared(),
                        ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ShadButton.outline(
                    onPressed: state.isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ShadButton(
                    onPressed:
                        (state.isLoading || _isSubmitting) ? null : _saveTask,
                    child: (state.isLoading || _isSubmitting)
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  void _saveTask() {
    if (!_formKey.currentState!.validate() || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;

    DateTime? scheduledTime;
    if (_selectedDate != null && _selectedTime != null) {
      scheduledTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );
    }

    // Clear any previous errors
    context.read<T>().add(const CalendarEvent.errorCleared());

    if (widget.editingTask != null) {
      final updatedTask = widget.editingTask!.copyWith(
        title: title,
        description: description,
        scheduledTime: scheduledTime,
        duration: _selectedDuration,
        modifiedAt: DateTime.now(),
      );

      context.read<T>().add(
            CalendarEvent.taskUpdated(task: updatedTask),
          );
    } else {
      context.read<T>().add(
            CalendarEvent.taskAdded(
              title: title,
              description: description,
              scheduledTime: scheduledTime,
              duration: _selectedDuration,
            ),
          );
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Select date';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatDuration(Duration duration) {
    return TimeFormatter.formatDuration(duration);
  }
}

// Generic helper function to show the unified task input
void showUnifiedTaskInput<T extends BaseCalendarBloc>(
  BuildContext context, {
  CalendarTask? editingTask,
  DateTime? initialDate,
  TimeOfDay? initialTime,
}) {
  if (ResponsiveHelper.isMobile(context)) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => UnifiedTaskInput<T>(
          editingTask: editingTask,
          initialDate: initialDate,
          initialTime: initialTime,
        ),
      ),
    );
  } else {
    showDialog<void>(
      context: context,
      builder: (context) => UnifiedTaskInput<T>(
        editingTask: editingTask,
        initialDate: initialDate,
        initialTime: initialTime,
      ),
    );
  }
}
