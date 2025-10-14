import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_text_field.dart';

class QuickAddModal extends StatefulWidget {
  final DateTime? prefilledDateTime;
  final VoidCallback? onDismiss;
  final void Function(CalendarTask task) onTaskAdded;

  const QuickAddModal({
    super.key,
    this.prefilledDateTime,
    this.onDismiss,
    required this.onTaskAdded,
  });

  @override
  State<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends State<QuickAddModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  final _taskNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _taskNameFocusNode = FocusNode();

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isSubmitting = false;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;
  RecurrenceFormValue _recurrence = const RecurrenceFormValue();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: baseAnimationDuration,
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _animationController.forward();

    final prefilled = widget.prefilledDateTime;
    final defaultStart = prefilled;
    _startTime = defaultStart;
    _endTime = defaultStart?.add(const Duration(hours: 1));

    // Auto-focus the task name input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _taskNameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _taskNameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _taskNameFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fadeAnimation,
      builder: (context, child) {
        return Stack(
          children: [
            // Semi-transparent backdrop
            GestureDetector(
              onTap: _dismissModal,
              child: Container(
                color:
                    Colors.black.withValues(alpha: 0.4 * _fadeAnimation.value),
                width: double.infinity,
                height: double.infinity,
              ),
            ),

            // Modal content
            Center(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _scaleAnimation.value,
                    child: _buildModalContent(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildModalContent() {
    final responsive = ResponsiveHelper.spec(context);
    final double maxWidth =
        responsive.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;
    final double maxHeight = responsive.quickAddMaxHeight;
    return Container(
      margin: responsive.modalMargin,
      constraints: BoxConstraints(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        boxShadow: calendarMediumShadow,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Form content
            Flexible(
              child: SingleChildScrollView(
                padding: responsive.contentPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildTaskNameInput(),
                    const SizedBox(height: calendarSpacing12),
                    _buildDescriptionInput(),
                    const SizedBox(height: calendarSpacing12),
                    _buildLocationField(),
                    const SizedBox(height: calendarSpacing12),
                    _buildPriorityToggles(),
                    const TaskSectionDivider(
                      verticalPadding: calendarSpacing12,
                    ),
                    _buildScheduleSection(),
                    const SizedBox(height: calendarSpacing12),
                    _buildDeadlineField(),
                    const TaskSectionDivider(
                      verticalPadding: calendarSpacing12,
                    ),
                    _buildRecurrenceSection(),
                  ],
                ),
              ),
            ),

            // Actions
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarSpacing16,
        vertical: calendarSpacing12,
      ),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_task,
            color: calendarTitleColor,
            size: 20,
          ),
          const SizedBox(width: calendarSpacing8),
          Text(
            'Add Task',
            style: calendarTitleTextStyle.copyWith(fontSize: 18),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _dismissModal,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  color: calendarSubtitleColor,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskNameInput() {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.enter) {
          if (_taskNameController.text.trim().isNotEmpty) {
            _submitTask();
          }
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: TaskTextField(
        controller: _taskNameController,
        focusNode: _taskNameFocusNode,
        hintText: 'Task name',
        borderRadius: calendarBorderRadius,
        focusBorderColor: calendarPrimaryColor,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TaskDescriptionField(
      controller: _descriptionController,
      hintText: 'Description (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPriorityToggles() {
    return TaskPriorityToggles(
      isImportant: _isImportant,
      isUrgent: _isUrgent,
      spacing: 10,
      onImportantChanged: (value) => setState(() => _isImportant = value),
      onUrgentChanged: (value) => setState(() => _isUrgent = value),
    );
  }

  Widget _buildLocationField() {
    return TaskLocationField(
      controller: _locationController,
      hintText: 'Location (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.words,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildScheduleSection() {
    return TaskScheduleSection(
      title: 'Schedule',
      headerStyle: calendarSubtitleTextStyle.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      spacing: calendarSpacing8,
      start: _startTime,
      end: _endTime,
      onStartChanged: (value) {
        setState(() {
          _startTime = value;
          if (value == null) {
            _endTime = null;
          } else {
            if (_endTime == null || !_endTime!.isAfter(value)) {
              _endTime = value.add(const Duration(hours: 1));
            }
            if (_recurrence.frequency == RecurrenceFrequency.weekly &&
                (_recurrence.weekdays.isEmpty ||
                    _recurrence.weekdays.length == 1)) {
              _recurrence = _recurrence.copyWith(weekdays: {value.weekday});
            }
          }
        });
      },
      onEndChanged: (value) {
        setState(() {
          if (value == null) {
            _endTime = null;
            return;
          }
          if (_startTime != null && !value.isAfter(_startTime!)) {
            _endTime = _startTime!.add(const Duration(minutes: 15));
          } else {
            _endTime = value;
          }
        });
      },
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskSectionHeader(
          title: 'Deadline',
          textStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: calendarSpacing8),
        DeadlinePickerField(
          value: _deadline,
          onChanged: (value) => setState(() => _deadline = value),
        ),
      ],
    );
  }

  Widget _buildRecurrenceSection() {
    final fallbackWeekday = _startTime?.weekday ??
        widget.prefilledDateTime?.weekday ??
        DateTime.now().weekday;

    return TaskRecurrenceSection(
      title: 'Repeat',
      headerStyle: calendarSubtitleTextStyle.copyWith(
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      spacing: calendarSpacing8,
      value: _recurrence,
      fallbackWeekday: fallbackWeekday,
      spacingConfig: const RecurrenceEditorSpacing(
        chipSpacing: 6,
        chipRunSpacing: 6,
        weekdaySpacing: 10,
        advancedSectionSpacing: 12,
        endSpacing: 14,
        fieldGap: 14,
      ),
      onChanged: (next) {
        setState(() => _recurrence = next);
      },
    );
  }

  Widget _buildActions() {
    return TaskFormActionsRow(
      includeTopBorder: true,
      padding: calendarPadding16,
      gap: calendarSpacing12,
      children: [
        Expanded(
          child: TaskSecondaryButton(
            label: 'Cancel',
            onPressed: _isSubmitting ? null : _dismissModal,
            foregroundColor: calendarSubtitleColor,
            hoverForegroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.06),
          ),
        ),
        Expanded(
          child: TaskPrimaryButton(
            label: 'Add Task',
            onPressed: _canSubmit && !_isSubmitting ? _submitTask : null,
            isBusy: _isSubmitting,
          ),
        ),
      ],
    );
  }

  bool get _canSubmit => _taskNameController.text.trim().isNotEmpty;

  TaskPriority get _selectedPriority {
    if (_isImportant && _isUrgent) {
      return TaskPriority.critical;
    } else if (_isImportant) {
      return TaskPriority.important;
    } else if (_isUrgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  void _submitTask() {
    if (!_canSubmit || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final taskName = _taskNameController.text.trim();
    final description = _descriptionController.text.trim();
    final scheduledTime = _startTime;

    final recurrence =
        scheduledTime != null ? _recurrence.toRule(start: scheduledTime) : null;

    // Create the task
    final task = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: taskName,
      description: description.isNotEmpty ? description : null,
      scheduledTime: scheduledTime,
      duration: scheduledTime != null
          ? (_endTime != null && _endTime!.isAfter(scheduledTime)
              ? _endTime!.difference(scheduledTime)
              : const Duration(hours: 1))
          : null,
      priority: _selectedPriority,
      isCompleted: false,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      deadline: _deadline,
      recurrence: recurrence,
      startHour: scheduledTime != null
          ? scheduledTime.hour + (scheduledTime.minute / 60.0)
          : null,
    );

    widget.onTaskAdded(task);

    _dismissModal();
  }

  Future<void> _dismissModal() async {
    await _animationController.reverse();
    if (mounted) {
      widget.onDismiss?.call();
      Navigator.of(context).pop();
    }
  }
}

// Helper function to show the modal
Future<void> showQuickAddModal({
  required BuildContext context,
  DateTime? prefilledDateTime,
  required void Function(CalendarTask task) onTaskAdded,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.transparent,
    builder: (context) => QuickAddModal(
      prefilledDateTime: prefilledDateTime,
      onTaskAdded: onTaskAdded,
      onDismiss: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
    ),
  );
}
