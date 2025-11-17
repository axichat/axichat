import 'package:axichat/src/app.dart';
import '../../common/ui/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import '../utils/task_title_validation.dart';
import '../utils/time_formatter.dart';
import 'error_display.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_field_character_hint.dart';

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
    final bool isEditing = widget.editingTask != null;
    final Widget form = _UnifiedTaskForm(
      formKey: _formKey,
      titleController: _titleController,
      descriptionController: _descriptionController,
      selectedDate: _selectedDate,
      selectedTime: _selectedTime,
      selectedDuration: _selectedDuration,
      durationOptions: _durationOptions,
      onSelectDate: _selectDate,
      onSelectTime: _selectTime,
      onDurationChanged: (duration) {
        setState(() => _selectedDuration = duration);
      },
      formatDate: _formatDate,
      formatDuration: _formatDuration,
    );
    final Widget saveButton = _UnifiedTaskSaveButton<T>(
      isSubmitting: _isSubmitting,
      onSave: _saveTask,
    );
    final Widget dialogActions = _UnifiedTaskDialogActions<T>(
      isSubmitting: _isSubmitting,
      onSave: _saveTask,
      onSubmissionReset: () => setState(() => _isSubmitting = false),
      onClearError: () => context.read<T>().add(
            const CalendarEvent.errorCleared(),
          ),
    );
    return ResponsiveHelper.layoutBuilder(
      context,
      mobile: _UnifiedTaskMobileLayout(
        isEditing: isEditing,
        saveButton: saveButton,
        form: form,
      ),
      tablet: _UnifiedTaskDialogLayout(
        width: 500,
        isEditing: isEditing,
        form: form,
        dialogActions: dialogActions,
      ),
      desktop: _UnifiedTaskDialogLayout(
        width: 600,
        isEditing: isEditing,
        form: form,
        dialogActions: dialogActions,
      ),
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

class _UnifiedTaskMobileLayout extends StatelessWidget {
  const _UnifiedTaskMobileLayout({
    required this.isEditing,
    required this.saveButton,
    required this.form,
  });

  final bool isEditing;
  final Widget saveButton;
  final Widget form;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: context.colorScheme.background,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        shape: Border(
          bottom: BorderSide(color: context.colorScheme.border),
        ),
        leadingWidth: AxiIconButton.kDefaultSize + 24,
        leading: Navigator.canPop(context)
            ? Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: AxiIconButton.kDefaultSize,
                    height: AxiIconButton.kDefaultSize,
                    child: AxiIconButton(
                      iconData: LucideIcons.arrowLeft,
                      tooltip: 'Back',
                      color: context.colorScheme.foreground,
                      borderColor: context.colorScheme.border,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ),
              )
            : null,
        title: Text(isEditing ? 'Edit Task' : 'New Task'),
        actions: [saveButton],
      ),
      body: form,
    );
  }
}

class _UnifiedTaskDialogLayout extends StatelessWidget {
  const _UnifiedTaskDialogLayout({
    required this.width,
    required this.isEditing,
    required this.form,
    required this.dialogActions,
  });

  final double width;
  final bool isEditing;
  final Widget form;
  final Widget dialogActions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _UnifiedTaskDialogHeader(isEditing: isEditing),
            Flexible(child: form),
            dialogActions,
          ],
        ),
      ),
    );
  }
}

class _UnifiedTaskDialogHeader extends StatelessWidget {
  const _UnifiedTaskDialogHeader({required this.isEditing});

  final bool isEditing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: calendarPaddingXl,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              isEditing ? 'Edit Task' : 'New Task',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}

class _UnifiedTaskForm extends StatelessWidget {
  const _UnifiedTaskForm({
    required this.formKey,
    required this.titleController,
    required this.descriptionController,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedDuration,
    required this.durationOptions,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.onDurationChanged,
    required this.formatDate,
    required this.formatDuration,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController titleController;
  final TextEditingController descriptionController;
  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final Duration? selectedDuration;
  final List<Duration> durationOptions;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final ValueChanged<Duration?> onDurationChanged;
  final String Function(DateTime?) formatDate;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: calendarPaddingXl,
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _UnifiedTaskTitleField(controller: titleController),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDescriptionField(
              controller: descriptionController,
            ),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDateTimeSection(
              selectedDate: selectedDate,
              selectedTime: selectedTime,
              onSelectDate: onSelectDate,
              onSelectTime: onSelectTime,
              formatDate: formatDate,
            ),
            const SizedBox(height: calendarGutterLg),
            _UnifiedTaskDurationField(
              selectedDuration: selectedDuration,
              durationOptions: durationOptions,
              onDurationChanged: onDurationChanged,
              formatDuration: formatDuration,
            ),
          ],
        ),
      ),
    );
  }
}

class _UnifiedTaskTitleField extends StatelessWidget {
  const _UnifiedTaskTitleField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTextFormField(
          controller: controller,
          hintText: 'Task title',
          textCapitalization: TextCapitalization.sentences,
          focusBorderColor: calendarPrimaryColor,
          borderRadius: calendarBorderRadius,
          validator: (value) => TaskTitleValidation.validate(value ?? ''),
          autovalidateMode: AutovalidateMode.onUserInteraction,
        ),
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _UnifiedTaskDescriptionField extends StatelessWidget {
  const _UnifiedTaskDescriptionField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TaskDescriptionField(
      controller: controller,
      hintText: 'Description (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      minLines: 3,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
    );
  }
}

class _UnifiedTaskDateTimeSection extends StatelessWidget {
  const _UnifiedTaskDateTimeSection({
    required this.selectedDate,
    required this.selectedTime,
    required this.onSelectDate,
    required this.onSelectTime,
    required this.formatDate,
  });

  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date & Time',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: calendarGutterSm),
        TaskDateTimeToolbar(
          primaryField: TaskDateTimeToolbarField(
            selectedDate: selectedDate,
            selectedTime: selectedTime,
            onSelectDate: onSelectDate,
            onSelectTime: onSelectTime,
            emptyDateLabel: 'Select date',
            emptyTimeLabel: 'Select time',
            dateLabelBuilder: (context, date) => formatDate(date),
            timeLabelBuilder: (context, time) =>
                TimeFormatter.formatTimeOfDay(context, time),
          ),
        ),
      ],
    );
  }
}

class _UnifiedTaskDurationField extends StatelessWidget {
  const _UnifiedTaskDurationField({
    required this.selectedDuration,
    required this.durationOptions,
    required this.onDurationChanged,
    required this.formatDuration,
  });

  final Duration? selectedDuration;
  final List<Duration> durationOptions;
  final ValueChanged<Duration?> onDurationChanged;
  final String Function(Duration) formatDuration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Duration',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: calendarGutterSm),
        ShadSelect<Duration>(
          placeholder: const Text('Select duration'),
          options: durationOptions
              .map(
                (duration) => ShadOption(
                  value: duration,
                  child: Text(formatDuration(duration)),
                ),
              )
              .toList(),
          selectedOptionBuilder: (context, value) =>
              Text(formatDuration(value)),
          onChanged: onDurationChanged,
        ),
      ],
    );
  }
}

class _UnifiedTaskSaveButton<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _UnifiedTaskSaveButton({
    required this.isSubmitting,
    required this.onSave,
  });

  final bool isSubmitting;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<T, CalendarState>(
      builder: (context, state) {
        final bool disabled = state.isLoading || isSubmitting;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: calendarGutterSm),
          child: TaskPrimaryButton(
            label: 'Save',
            onPressed: disabled ? null : onSave,
            isBusy: disabled,
          ),
        );
      },
    );
  }
}

class _UnifiedTaskDialogActions<T extends BaseCalendarBloc>
    extends StatelessWidget {
  const _UnifiedTaskDialogActions({
    required this.isSubmitting,
    required this.onSave,
    required this.onSubmissionReset,
    required this.onClearError,
  });

  final bool isSubmitting;
  final VoidCallback onSave;
  final VoidCallback onSubmissionReset;
  final VoidCallback onClearError;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<T, CalendarState>(
      listener: (context, state) {
        if (state.error != null && isSubmitting) {
          ErrorSnackBar.show(context, state.error!);
          onSubmissionReset();
        } else if (!state.isLoading && isSubmitting) {
          Navigator.of(context).maybePop();
        }
      },
      builder: (context, state) {
        return Container(
          padding: calendarPaddingXl,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: Theme.of(context).dividerColor),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.error != null && isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(bottom: calendarGutterLg),
                  child: ErrorDisplay(
                    error: state.error!,
                    onRetry: onSave,
                    onDismiss: onClearError,
                  ),
                ),
              TaskFormActionsRow(
                padding: EdgeInsets.zero,
                gap: calendarGutterMd,
                children: [
                  const Spacer(),
                  TaskSecondaryButton(
                    label: 'Cancel',
                    onPressed: (state.isLoading || isSubmitting)
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                  TaskPrimaryButton(
                    label: 'Save',
                    onPressed:
                        (state.isLoading || isSubmitting) ? null : onSave,
                    isBusy: state.isLoading || isSubmitting,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// Generic helper function to show the unified task input
void showUnifiedTaskInput<T extends BaseCalendarBloc>(
  BuildContext context, {
  CalendarTask? editingTask,
  DateTime? initialDate,
  TimeOfDay? initialTime,
}) {
  if (ResponsiveHelper.isCompact(context)) {
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
