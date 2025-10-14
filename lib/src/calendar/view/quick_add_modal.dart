import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import '../utils/responsive_helper.dart';
import 'controllers/quick_add_controller.dart';
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

  late final QuickAddController _formController;

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

    _formController = QuickAddController(
      initialStart: prefilled,
      initialEnd: prefilled?.add(const Duration(hours: 1)),
    );

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
    _formController.dispose();
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
        labelText: 'Task name *',
        hintText: 'Task name',
        borderRadius: calendarBorderRadius,
        focusBorderColor: calendarPrimaryColor,
        textCapitalization: TextCapitalization.sentences,
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
    );
  }

  Widget _buildPriorityToggles() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return TaskPriorityToggles(
          isImportant: _formController.isImportant,
          isUrgent: _formController.isUrgent,
          spacing: 10,
          onImportantChanged: (value) => _formController.setImportant(value),
          onUrgentChanged: (value) => _formController.setUrgent(value),
        );
      },
    );
  }

  Widget _buildLocationField() {
    return TaskLocationField(
      controller: _locationController,
      hintText: 'Location (optional)',
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      textCapitalization: TextCapitalization.words,
    );
  }

  Widget _buildScheduleSection() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return TaskScheduleSection(
          title: 'Schedule',
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarSpacing8,
          start: _formController.startTime,
          end: _formController.endTime,
          onStartChanged: _formController.updateStart,
          onEndChanged: _formController.updateEnd,
          onClear: _formController.clearSchedule,
        );
      },
    );
  }

  Widget _buildDeadlineField() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
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
              value: _formController.deadline,
              onChanged: _formController.setDeadline,
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecurrenceSection() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        final fallbackWeekday = _formController.startTime?.weekday ??
            widget.prefilledDateTime?.weekday ??
            DateTime.now().weekday;
        return TaskRecurrenceSection(
          title: 'Repeat',
          headerStyle: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
          spacing: calendarSpacing8,
          value: _formController.recurrence,
          fallbackWeekday: fallbackWeekday,
          spacingConfig: const RecurrenceEditorSpacing(
            chipSpacing: 6,
            chipRunSpacing: 6,
            weekdaySpacing: 10,
            advancedSectionSpacing: 12,
            endSpacing: 14,
            fieldGap: 14,
          ),
          onChanged: _formController.setRecurrence,
        );
      },
    );
  }

  Widget _buildActions() {
    return AnimatedBuilder(
      animation: _formController,
      builder: (context, _) {
        return ValueListenableBuilder<TextEditingValue>(
          valueListenable: _taskNameController,
          builder: (context, value, __) {
            final bool canSubmit = value.text.trim().isNotEmpty;
            return TaskFormActionsRow(
              includeTopBorder: true,
              padding: calendarPadding16,
              gap: calendarSpacing12,
              children: [
                Expanded(
                  child: TaskSecondaryButton(
                    label: 'Cancel',
                    onPressed:
                        _formController.isSubmitting ? null : _dismissModal,
                    foregroundColor: calendarSubtitleColor,
                    hoverForegroundColor: calendarPrimaryColor,
                    hoverBackgroundColor:
                        calendarPrimaryColor.withValues(alpha: 0.06),
                  ),
                ),
                Expanded(
                  child: TaskPrimaryButton(
                    label: 'Add Task',
                    onPressed: canSubmit && !_formController.isSubmitting
                        ? _submitTask
                        : null,
                    isBusy: _formController.isSubmitting,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _submitTask() {
    if (_formController.isSubmitting ||
        _taskNameController.text.trim().isEmpty) {
      return;
    }

    _formController.setSubmitting(true);

    final taskName = _taskNameController.text.trim();
    final description = _descriptionController.text.trim();
    final scheduledTime = _formController.startTime;

    final recurrence =
        scheduledTime != null ? _formController.buildRecurrence() : null;

    final duration = _formController.effectiveDuration ??
        (scheduledTime != null ? const Duration(hours: 1) : null);

    // Create the task
    final task = CalendarTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: taskName,
      description: description.isNotEmpty ? description : null,
      scheduledTime: scheduledTime,
      duration: duration,
      priority: _formController.selectedPriority,
      isCompleted: false,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      location: _locationController.text.trim().isEmpty
          ? null
          : _locationController.text.trim(),
      deadline: _formController.deadline,
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
