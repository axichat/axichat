import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/schedule_range_fields.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';
import '../utils/recurrence_utils.dart';

class EditTaskDropdown extends StatefulWidget {
  const EditTaskDropdown({
    super.key,
    required this.task,
    required this.onClose,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.maxHeight = 520,
    this.onOccurrenceUpdated,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;
  final void Function(CalendarTask task)? onOccurrenceUpdated;

  @override
  State<EditTaskDropdown> createState() => _EditTaskDropdownState();
}

class _EditTaskDropdownState extends State<EditTaskDropdown> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isCompleted = false;

  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;

  RecurrenceFormValue _recurrence = const RecurrenceFormValue();

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task.title);
    _descriptionController =
        TextEditingController(text: task.description ?? '');
    _locationController = TextEditingController(text: task.location ?? '');

    _isImportant = task.isImportant || task.isCritical;
    _isUrgent = task.isUrgent || task.isCritical;
    _isCompleted = task.isCompleted;
    _startTime = task.scheduledTime;
    _endTime =
        task.scheduledTime?.add(task.duration ?? const Duration(hours: 1));
    _deadline = task.deadline;

    _recurrence = RecurrenceFormValue.fromRule(task.recurrence);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: calendarTaskPopoverWidth,
        constraints: BoxConstraints(
          maxHeight: widget.maxHeight,
          minWidth: 320,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: calendarBorderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTitleField(),
                    const SizedBox(height: 10),
                    _buildPriorityRow(),
                    _sectionDivider(),
                    _buildDescriptionField(),
                    const SizedBox(height: 10),
                    _buildLocationField(),
                    _sectionDivider(),
                    _buildScheduleSection(),
                    _sectionDivider(),
                    _buildDeadlineField(),
                    _sectionDivider(),
                    _buildRecurrenceSection(),
                    _sectionDivider(),
                    _buildCompletedCheckbox(),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Text(
            'Edit Task',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: calendarTitleColor,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: calendarSubtitleColor,
            tooltip: 'Close',
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return TaskTextField(
      controller: _titleController,
      autofocus: true,
      hintText: 'Task title',
      textCapitalization: TextCapitalization.sentences,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildDescriptionField() {
    return TaskTextField(
      controller: _descriptionController,
      hintText: 'Description (optional)',
      minLines: 2,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _buildLocationField() {
    return TaskTextField(
      controller: _locationController,
      hintText: 'Location (optional)',
      textCapitalization: TextCapitalization.words,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    );
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: calendarBorderColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Schedule'),
        const SizedBox(height: 6),
        ScheduleRangeFields(
          start: _startTime,
          end: _endTime,
          onStartChanged: (value) {
            setState(() {
              _startTime = value;
              if (value == null) {
                _endTime = null;
                return;
              }
              if (_endTime == null || _endTime!.isBefore(value)) {
                _endTime = value.add(const Duration(hours: 1));
              }
            });
          },
          onEndChanged: (value) {
            setState(() {
              _endTime = value;
              if (value == null) {
                return;
              }
              if (_startTime != null && value.isBefore(_startTime!)) {
                _endTime = _startTime!.add(const Duration(minutes: 15));
              }
            });
          },
        ),
      ],
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Deadline'),
        const SizedBox(height: 4),
        DeadlinePickerField(
          value: _deadline,
          onChanged: (value) => setState(() => _deadline = value),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    final fallbackWeekday = _startTime?.weekday ??
        widget.task.scheduledTime?.weekday ??
        DateTime.now().weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Repeat'),
        const SizedBox(height: 4),
        RecurrenceEditor(
          value: _recurrence,
          fallbackWeekday: fallbackWeekday,
          spacing: const RecurrenceEditorSpacing(
            chipSpacing: 6,
            chipRunSpacing: 6,
            weekdaySpacing: 10,
            advancedSectionSpacing: 12,
            endSpacing: 14,
            fieldGap: 12,
          ),
          onChanged: (next) {
            setState(() {
              _recurrence = next;
            });
          },
        ),
      ],
    );
  }

  Widget _buildPriorityRow() {
    return TaskPriorityToggles(
      isImportant: _isImportant,
      isUrgent: _isUrgent,
      onImportantChanged: (value) => setState(() => _isImportant = value),
      onUrgentChanged: (value) => setState(() => _isUrgent = value),
    );
  }

  Widget _buildCompletedCheckbox() {
    return TaskCompletionToggle(
      value: _isCompleted,
      onChanged: (value) => setState(() => _isCompleted = value),
    );
  }

  Widget _buildActions() {
    return TaskFormActionsRow(
      padding: const EdgeInsets.all(12),
      gap: 8,
      children: [
        ShadButton.destructive(
          size: ShadButtonSize.sm,
          onPressed: () {
            widget.onTaskDeleted(widget.task.id);
            widget.onClose();
          },
          child: const Text('Delete'),
        ),
        const Spacer(),
        ShadButton.outline(
          size: ShadButtonSize.sm,
          foregroundColor: calendarPrimaryColor,
          hoverForegroundColor: calendarPrimaryHoverColor,
          hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
          onPressed: widget.onClose,
          child: const Text('Cancel'),
        ),
        ShadButton(
          size: ShadButtonSize.sm,
          backgroundColor: calendarPrimaryColor,
          hoverBackgroundColor: calendarPrimaryHoverColor,
          foregroundColor: Colors.white,
          hoverForegroundColor: Colors.white,
          onPressed: _handleSave,
          child: const Text('Save'),
        ),
      ],
    );
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title cannot be blank.')),
      );
      return;
    }

    final priority = () {
      if (_isImportant && _isUrgent) return TaskPriority.critical;
      if (_isImportant) return TaskPriority.important;
      if (_isUrgent) return TaskPriority.urgent;
      return TaskPriority.none;
    }();

    Duration? duration;
    DateTime? scheduledTime;
    if (_startTime != null && _endTime != null) {
      duration = _endTime!.difference(_startTime!);
      if (duration.inMinutes < 15) {
        duration = const Duration(minutes: 15);
        _endTime = _startTime!.add(duration);
      }
      scheduledTime = _startTime;
    }

    final recurrenceAnchor =
        scheduledTime ?? widget.task.scheduledTime ?? DateTime.now();
    final recurrence = _recurrence.isActive
        ? _recurrence.toRule(start: recurrenceAnchor)
        : null;

    final updatedTask = widget.task.copyWith(
      title: title,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      scheduledTime: scheduledTime,
      duration: scheduledTime == null ? null : duration,
      deadline: _deadline,
      priority: priority == TaskPriority.none ? null : priority,
      isCompleted: _isCompleted,
      recurrence: recurrence?.isNone == true ? null : recurrence,
    );

    if (widget.task.isOccurrence && widget.onOccurrenceUpdated != null) {
      widget.onOccurrenceUpdated!(updatedTask);
    } else {
      widget.onTaskUpdated(updatedTask);
    }
    widget.onClose();
  }
}
