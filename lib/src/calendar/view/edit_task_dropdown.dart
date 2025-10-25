import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../common/ui/ui.dart';
import '../bloc/base_calendar_bloc.dart';
import '../models/calendar_task.dart';
import '../utils/location_autocomplete.dart';
import '../utils/recurrence_utils.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';

class EditTaskDropdown extends StatefulWidget {
  const EditTaskDropdown({
    super.key,
    required this.task,
    required this.onClose,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.maxHeight = 520,
    this.onOccurrenceUpdated,
    this.scaffoldMessenger,
    this.isSheet = false,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;
  final void Function(CalendarTask task)? onOccurrenceUpdated;
  final ScaffoldMessengerState? scaffoldMessenger;
  final bool isSheet;

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
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();

    _hydrateFromTask(widget.task, rebuild: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditTaskDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task.id != widget.task.id ||
        oldWidget.task.modifiedAt != widget.task.modifiedAt) {
      _hydrateFromTask(widget.task, rebuild: true);
    }
  }

  void _hydrateFromTask(
    CalendarTask task, {
    required bool rebuild,
  }) {
    void apply() {
      if (_titleController.text != task.title) {
        _titleController.value = TextEditingValue(
          text: task.title,
          selection: TextSelection.collapsed(offset: task.title.length),
        );
      }

      final String descriptionText = task.description ?? '';
      if (_descriptionController.text != descriptionText) {
        _descriptionController.value = TextEditingValue(
          text: descriptionText,
          selection: TextSelection.collapsed(offset: descriptionText.length),
        );
      }

      final String locationText = task.location ?? '';
      if (_locationController.text != locationText) {
        _locationController.value = TextEditingValue(
          text: locationText,
          selection: TextSelection.collapsed(offset: locationText.length),
        );
      }

      _isImportant = task.isImportant || task.isCritical;
      _isUrgent = task.isUrgent || task.isCritical;
      _isCompleted = task.isCompleted;
      _startTime = task.scheduledTime;
      _endTime = task.effectiveEndDate ??
          task.scheduledTime?.add(
            task.duration ?? const Duration(hours: 1),
          );
      _deadline = task.deadline;
      _recurrence = RecurrenceFormValue.fromRule(task.recurrence);
    }

    if (rebuild && mounted) {
      setState(apply);
    } else {
      apply();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isSheet = widget.isSheet;
    final BorderRadius radius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(24))
        : BorderRadius.circular(8);
    final Color background =
        isSheet ? Theme.of(context).colorScheme.surface : Colors.white;
    final List<BoxShadow>? boxShadow = isSheet
        ? null
        : const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ];
    final Widget body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildHeader(),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterLg, vertical: calendarGutterMd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitleField(),
                const SizedBox(height: calendarFormGap),
                _buildPriorityRow(),
                _sectionDivider(),
                _buildDescriptionField(),
                const SizedBox(height: calendarFormGap),
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
    );
    return Material(
      color: Colors.transparent,
      child: ClipRRect(
        borderRadius: radius,
        child: Container(
          width: isSheet ? double.infinity : calendarTaskPopoverWidth,
          constraints: BoxConstraints(
            maxHeight: widget.maxHeight,
            minWidth: 320,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: radius,
            border: isSheet ? null : Border.all(color: calendarBorderColor),
            boxShadow: boxShadow,
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterLg, vertical: calendarGutterMd),
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
      contentPadding: calendarMenuItemPadding,
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
      contentPadding: calendarMenuItemPadding,
    );
  }

  Widget _buildLocationField() {
    final helper = _resolveLocationHelper(context);
    return TaskLocationField(
      controller: _locationController,
      hintText: 'Location (optional)',
      textCapitalization: TextCapitalization.words,
      contentPadding: calendarMenuItemPadding,
      autocomplete: helper,
    );
  }

  LocationAutocompleteHelper _resolveLocationHelper(BuildContext context) {
    final bloc = context.read<BaseCalendarBloc?>();
    if (bloc == null) {
      return LocationAutocompleteHelper.fromSeeds(const <String>[]);
    }
    return LocationAutocompleteHelper.fromState(bloc.state);
  }

  Widget _sectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: calendarGutterMd),
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
    return TaskScheduleSection(
      spacing: calendarInsetLg,
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
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Deadline'),
        const SizedBox(height: calendarInsetMd),
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

    return TaskRecurrenceSection(
      spacing: calendarInsetMd,
      value: _recurrence,
      fallbackWeekday: fallbackWeekday,
      spacingConfig: const RecurrenceEditorSpacing(
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
      padding: calendarPaddingLg,
      gap: 8,
      children: [
        TaskDestructiveButton(
          label: 'Delete',
          onPressed: () {
            widget.onTaskDeleted(widget.task.id);
            widget.onClose();
          },
        ),
        const Spacer(),
        TaskSecondaryButton(
          label: 'Cancel',
          onPressed: widget.onClose,
          foregroundColor: calendarPrimaryColor,
          hoverForegroundColor: calendarPrimaryHoverColor,
          hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        ),
        TaskPrimaryButton(
          label: 'Save',
          onPressed: _handleSave,
        ),
      ],
    );
  }

  void _handleSave() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      _showSnackBar('Title cannot be blank.');
      return;
    }

    final priority = () {
      if (_isImportant && _isUrgent) return TaskPriority.critical;
      if (_isImportant) return TaskPriority.important;
      if (_isUrgent) return TaskPriority.urgent;
      return TaskPriority.none;
    }();

    DateTime? scheduledTime;
    Duration? duration;
    DateTime? endDate;
    double? startHour;
    if (_startTime != null && _endTime != null) {
      final DateTime start = _startTime!;
      DateTime end = _endTime!;
      Duration computed = end.difference(start);
      if (computed.inMinutes < 15) {
        computed = const Duration(minutes: 15);
        end = start.add(computed);
        _endTime = end;
      }
      scheduledTime = start;
      duration = computed;
      endDate = end;
      startHour = start.hour + (start.minute / 60.0);
    }

    if (scheduledTime == null) {
      duration = null;
      endDate = null;
      startHour = null;
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
      duration: duration,
      endDate: endDate,
      startHour: startHour,
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

  void _showSnackBar(String message) {
    final messenger =
        widget.scaffoldMessenger ?? ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}
