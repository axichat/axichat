import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/base_calendar_bloc.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/utils/recurrence_utils.dart';
import 'package:axichat/src/calendar/utils/task_title_validation.dart';
import 'models/task_context_action.dart';
import 'controllers/task_checklist_controller.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/critical_path_panel.dart';
import 'widgets/recurrence_editor.dart';
import 'widgets/task_field_character_hint.dart';
import 'widgets/task_form_section.dart';
import 'widgets/task_checklist.dart';
import 'widgets/task_text_field.dart';
import 'widgets/reminder_preferences_field.dart';

class EditTaskDropdown<B extends BaseCalendarBloc> extends StatefulWidget {
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
    this.inlineActionsBuilder,
    this.inlineActionsBloc,
    required this.locationHelper,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;
  final void Function(CalendarTask task)? onOccurrenceUpdated;
  final ScaffoldMessengerState? scaffoldMessenger;
  final bool isSheet;
  final List<TaskContextAction> Function(CalendarState state)?
      inlineActionsBuilder;
  final B? inlineActionsBloc;
  final LocationAutocompleteHelper locationHelper;

  @override
  State<EditTaskDropdown<B>> createState() => _EditTaskDropdownState<B>();
}

class _EditTaskDropdownState<B extends BaseCalendarBloc>
    extends State<EditTaskDropdown<B>> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _locationController;
  late final TaskChecklistController _checklistController;
  String? _titleError;

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isCompleted = false;

  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;

  RecurrenceFormValue _recurrence = const RecurrenceFormValue();
  ReminderPreferences _reminders = ReminderPreferences.defaults();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    _checklistController = TaskChecklistController()..addListener(_refresh);

    _hydrateFromTask(widget.task, rebuild: false);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _checklistController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant EditTaskDropdown<B> oldWidget) {
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

      _checklistController.setItems(task.checklist);

      _isImportant = task.isImportant || task.isCritical;
      _isUrgent = task.isUrgent || task.isCritical;
      _isCompleted = task.isCompleted;
      _startTime = task.scheduledTime;
      _endTime = task.effectiveEndDate ??
          task.scheduledTime?.add(
            task.duration ?? const Duration(hours: 1),
          );
      _deadline = task.deadline;
      _recurrence = RecurrenceFormValue.fromRule(task.recurrence)
          .resolveLinkedLimits(_startTime ?? task.scheduledTime);
      _reminders = task.effectiveReminders;
      _titleError = null;
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
        _EditTaskHeader(onClose: widget.onClose),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterLg, vertical: calendarGutterMd),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EditTaskInlineActionsSection<B>(
                  inlineActionsBloc: widget.inlineActionsBloc,
                  inlineActionsBuilder: widget.inlineActionsBuilder,
                ),
                _EditTaskTitleField(
                  controller: _titleController,
                  errorText: _titleError,
                  onChanged: _handleTitleChanged,
                ),
                const SizedBox(height: calendarFormGap),
                _EditTaskPriorityRow(
                  isImportant: _isImportant,
                  isUrgent: _isUrgent,
                  onImportantChanged: (value) =>
                      setState(() => _isImportant = value),
                  onUrgentChanged: (value) => setState(() => _isUrgent = value),
                ),
                const _EditTaskSectionDivider(),
                _EditTaskDescriptionField(controller: _descriptionController),
                const SizedBox(height: calendarFormGap),
                TaskChecklist(controller: _checklistController),
                const SizedBox(height: calendarFormGap),
                _EditTaskLocationField(
                  controller: _locationController,
                  locationHelper: widget.locationHelper,
                ),
                const _EditTaskSectionDivider(),
                _EditTaskScheduleSection(
                  start: _startTime,
                  end: _endTime,
                  onStartChanged: _handleStartChanged,
                  onEndChanged: _handleEndChanged,
                ),
                const _EditTaskSectionDivider(),
                _EditTaskReminderSection(
                  reminders: _reminders,
                  onChanged: (value) => setState(() {
                    _reminders = value;
                  }),
                ),
                const _EditTaskSectionDivider(),
                _EditTaskDeadlineField(
                  deadline: _deadline,
                  onChanged: (value) => setState(() => _deadline = value),
                ),
                const _EditTaskSectionDivider(),
                _EditTaskRecurrenceSection(
                  value: _recurrence,
                  fallbackWeekday: _recurrenceFallbackWeekday,
                  onChanged: _handleRecurrenceChanged,
                ),
                const _EditTaskSectionDivider(),
                _EditTaskCompletionToggle(
                  value: _isCompleted,
                  onChanged: (value) => setState(() => _isCompleted = value),
                ),
                const SizedBox(height: calendarFormGap),
                if (!widget.isSheet) ...[
                  TaskSecondaryButton(
                    label: 'Add to critical path',
                    icon: Icons.route,
                    onPressed: () => addTaskToCriticalPath(
                      context: context,
                      bloc: widget.inlineActionsBloc ?? context.read<B>(),
                      task: widget.task,
                    ),
                  ),
                  const SizedBox(height: calendarFormGap),
                ],
              ],
            ),
          ),
        ),
        AnimatedPadding(
          duration: baseAnimationDuration,
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            bottom: _actionBarBottomInset(context),
          ),
          child: SafeArea(
            top: false,
            child: _EditTaskActionsRow(
              task: widget.task,
              onDelete: () {
                widget.onTaskDeleted(widget.task.id);
                widget.onClose();
              },
              onCancel: widget.onClose,
              onSave: _handleSave,
            ),
          ),
        ),
      ],
    );
    Widget content = Material(
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
    if (!isSheet) {
      content = SafeArea(
        top: true,
        bottom: true,
        child: content,
      );
    }
    return content;
  }

  void _handleTitleChanged(String value) {
    final bool tooLong = TaskTitleValidation.isTooLong(value);
    final bool hasContent = value.trim().isNotEmpty;
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

  int get _recurrenceFallbackWeekday =>
      _startTime?.weekday ??
      widget.task.scheduledTime?.weekday ??
      DateTime.now().weekday;

  void _handleStartChanged(DateTime? value) {
    setState(() {
      _startTime = value;
      if (value == null) {
        _endTime = null;
        return;
      }
      if (_endTime == null || _endTime!.isBefore(value)) {
        _endTime = value.add(const Duration(hours: 1));
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleEndChanged(DateTime? value) {
    setState(() {
      _endTime = value;
      if (value == null) {
        return;
      }
      if (_startTime != null && value.isBefore(_startTime!)) {
        _endTime = _startTime!.add(const Duration(minutes: 15));
      }
      _recurrence = _normalizeRecurrence(_recurrence);
    });
  }

  void _handleRecurrenceChanged(RecurrenceFormValue next) {
    setState(() {
      _recurrence = _normalizeRecurrence(next);
    });
  }

  RecurrenceFormValue _normalizeRecurrence(RecurrenceFormValue value) {
    final DateTime? anchor = _startTime ?? widget.task.scheduledTime;
    return value.resolveLinkedLimits(anchor);
  }

  void _handleSave() {
    final validationError = TaskTitleValidation.validate(_titleController.text);
    if (validationError != null) {
      setState(() {
        _titleError = validationError;
      });
      _showSnackBar(validationError);
      return;
    }

    final title = _titleController.text.trim();

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
        ? _recurrence
            .resolveLinkedLimits(recurrenceAnchor)
            .toRule(start: recurrenceAnchor)
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
      checklist: _checklistController.items.toList(),
      reminders: _reminders,
    );

    if (widget.task.isOccurrence && widget.onOccurrenceUpdated != null) {
      widget.onOccurrenceUpdated!(updatedTask);
    } else {
      widget.onTaskUpdated(updatedTask);
    }
    widget.onClose();
  }

  double _actionBarBottomInset(BuildContext context) {
    if (widget.isSheet) {
      return 0;
    }
    final mediaQuery = MediaQuery.of(context);
    final double keyboardInset = mediaQuery.viewInsets.bottom;
    final double safePadding = mediaQuery.viewPadding.bottom;
    if (keyboardInset <= safePadding) {
      return 0;
    }
    return keyboardInset - safePadding;
  }

  void _showSnackBar(String message) {
    final messenger =
        widget.scaffoldMessenger ?? ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }
}

class _EditTaskHeader extends StatelessWidget {
  const _EditTaskHeader({
    required this.onClose,
  });

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterLg,
        vertical: calendarGutterMd,
      ),
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
          AxiIconButton(
            iconData: Icons.close,
            tooltip: 'Close',
            onPressed: onClose,
            color: calendarSubtitleColor,
            backgroundColor: colors.card,
            borderColor: colors.border,
            iconSize: 18,
            buttonSize: 34,
            tapTargetSize: 40,
            cornerRadius: 12,
          ),
        ],
      ),
    );
  }
}

class _EditTaskInlineActionsSection<B extends BaseCalendarBloc>
    extends StatelessWidget {
  const _EditTaskInlineActionsSection({
    required this.inlineActionsBloc,
    required this.inlineActionsBuilder,
  });

  final B? inlineActionsBloc;
  final List<TaskContextAction> Function(CalendarState state)?
      inlineActionsBuilder;

  @override
  Widget build(BuildContext context) {
    final builder = inlineActionsBuilder;
    final bloc = inlineActionsBloc;
    if (builder == null || bloc == null) {
      return const SizedBox.shrink();
    }
    return BlocBuilder<B, CalendarState>(
      bloc: bloc,
      builder: (context, state) {
        final actions = builder(state);
        if (actions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterLg,
                vertical: calendarGutterMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Task actions',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: calendarInsetSm),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double? width = constraints.maxWidth.isFinite
                          ? constraints.maxWidth
                          : null;
                      final chipWrap = Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: actions
                            .map(
                              (action) => _EditTaskInlineActionChip(
                                action: action,
                              ),
                            )
                            .toList(growable: false),
                      );
                      if (width == null) {
                        return chipWrap;
                      }
                      return SizedBox(width: width, child: chipWrap);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: calendarFormGap),
          ],
        );
      },
    );
  }
}

class _EditTaskInlineActionChip extends StatelessWidget {
  const _EditTaskInlineActionChip({
    required this.action,
  });

  final TaskContextAction action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color baseColor =
        action.destructive ? scheme.error : calendarPrimaryColor;
    final Color background = baseColor.withValues(alpha: 0.12);
    return TextButton.icon(
      onPressed: action.onSelected,
      style: TextButton.styleFrom(
        foregroundColor: baseColor,
        backgroundColor: background,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        visualDensity: VisualDensity.compact,
      ),
      icon: Icon(action.icon, size: 16),
      label: Text(
        action.label,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _EditTaskTitleField extends StatelessWidget {
  const _EditTaskTitleField({
    required this.controller,
    required this.errorText,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TaskTextField(
          controller: controller,
          autofocus: true,
          hintText: 'Task title',
          textCapitalization: TextCapitalization.sentences,
          contentPadding: calendarMenuItemPadding,
          onChanged: onChanged,
          errorText: errorText,
        ),
        TaskFieldCharacterHint(controller: controller),
      ],
    );
  }
}

class _EditTaskDescriptionField extends StatelessWidget {
  const _EditTaskDescriptionField({
    required this.controller,
  });

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TaskTextField(
      controller: controller,
      hintText: 'Description (optional)',
      minLines: 2,
      maxLines: 4,
      textInputAction: TextInputAction.newline,
      textCapitalization: TextCapitalization.sentences,
      contentPadding: calendarMenuItemPadding,
    );
  }
}

class _EditTaskLocationField extends StatelessWidget {
  const _EditTaskLocationField({
    required this.controller,
    required this.locationHelper,
  });

  final TextEditingController controller;
  final LocationAutocompleteHelper locationHelper;

  @override
  Widget build(BuildContext context) {
    return TaskLocationField(
      controller: controller,
      hintText: 'Location (optional)',
      textCapitalization: TextCapitalization.words,
      contentPadding: calendarMenuItemPadding,
      autocomplete: locationHelper,
    );
  }
}

class _EditTaskSectionDivider extends StatelessWidget {
  const _EditTaskSectionDivider();

  @override
  Widget build(BuildContext context) {
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
}

class _EditTaskScheduleSection extends StatelessWidget {
  const _EditTaskScheduleSection({
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;

  @override
  Widget build(BuildContext context) {
    return TaskScheduleSection(
      spacing: calendarInsetLg,
      start: start,
      end: end,
      onStartChanged: onStartChanged,
      onEndChanged: onEndChanged,
    );
  }
}

class _EditTaskDeadlineField extends StatelessWidget {
  const _EditTaskDeadlineField({
    required this.deadline,
    required this.onChanged,
  });

  final DateTime? deadline;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskSectionHeader(title: 'Deadline'),
        const SizedBox(height: calendarInsetMd),
        DeadlinePickerField(
          value: deadline,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _EditTaskReminderSection extends StatelessWidget {
  const _EditTaskReminderSection({
    required this.reminders,
    required this.onChanged,
  });

  final ReminderPreferences reminders;
  final ValueChanged<ReminderPreferences> onChanged;

  @override
  Widget build(BuildContext context) {
    return ReminderPreferencesField(
      value: reminders,
      onChanged: onChanged,
    );
  }
}

class _EditTaskRecurrenceSection extends StatelessWidget {
  const _EditTaskRecurrenceSection({
    required this.value,
    required this.fallbackWeekday,
    required this.onChanged,
  });

  final RecurrenceFormValue value;
  final int fallbackWeekday;
  final ValueChanged<RecurrenceFormValue> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskRecurrenceSection(
      spacing: calendarInsetMd,
      value: value,
      fallbackWeekday: fallbackWeekday,
      spacingConfig: const RecurrenceEditorSpacing(
        chipSpacing: 6,
        chipRunSpacing: 6,
        weekdaySpacing: 10,
        advancedSectionSpacing: 12,
        endSpacing: 14,
        fieldGap: 12,
      ),
      onChanged: onChanged,
    );
  }
}

class _EditTaskPriorityRow extends StatelessWidget {
  const _EditTaskPriorityRow({
    required this.isImportant,
    required this.isUrgent,
    required this.onImportantChanged,
    required this.onUrgentChanged,
  });

  final bool isImportant;
  final bool isUrgent;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;

  @override
  Widget build(BuildContext context) {
    return TaskPriorityToggles(
      isImportant: isImportant,
      isUrgent: isUrgent,
      onImportantChanged: onImportantChanged,
      onUrgentChanged: onUrgentChanged,
    );
  }
}

class _EditTaskCompletionToggle extends StatelessWidget {
  const _EditTaskCompletionToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return TaskCompletionToggle(
      value: value,
      onChanged: onChanged,
    );
  }
}

class _EditTaskActionsRow extends StatelessWidget {
  const _EditTaskActionsRow({
    required this.task,
    required this.onDelete,
    required this.onCancel,
    required this.onSave,
  });

  final CalendarTask task;
  final VoidCallback onDelete;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return TaskFormActionsRow(
      includeTopBorder: true,
      padding: calendarPaddingLg,
      gap: 8,
      children: [
        TaskDestructiveButton(
          label: 'Delete',
          onPressed: onDelete,
        ),
        const Spacer(),
        TaskSecondaryButton(
          label: 'Cancel',
          onPressed: onCancel,
          foregroundColor: calendarPrimaryColor,
          hoverForegroundColor: calendarPrimaryHoverColor,
          hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
        ),
        TaskPrimaryButton(
          label: 'Save',
          onPressed: onSave,
        ),
      ],
    );
  }
}
