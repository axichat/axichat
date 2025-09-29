import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import 'priority_checkbox_tile.dart';
import 'widgets/deadline_picker_field.dart';
import 'widgets/schedule_range_fields.dart';

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
  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.none;
  int _recurrenceInterval = 1;
  late Set<int> _selectedWeekdays;
  DateTime? _recurrenceUntil;
  int? _recurrenceCount;
  final TextEditingController _recurrenceCountController =
      TextEditingController();

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

    final defaultWeekday =
        (defaultStart ?? DateTime.now()).weekday;
    _selectedWeekdays = {defaultWeekday};

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
    _recurrenceCountController.dispose();
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
    return Container(
      margin: calendarPadding16,
      constraints: const BoxConstraints(
        maxWidth: 400,
        maxHeight: 540,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: calendarSpacing16,
                  vertical: calendarSpacing12,
                ),
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
                    _modalDivider(),
                    _buildScheduleSection(),
                    const SizedBox(height: calendarSpacing12),
                    _buildDeadlineField(),
                    _modalDivider(),
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
      child: TextField(
        controller: _taskNameController,
        focusNode: _taskNameFocusNode,
        decoration: InputDecoration(
          labelText: 'Task name *',
          labelStyle: const TextStyle(
            color: calendarSubtitleColor,
            fontSize: 14,
          ),
          hintText: 'Enter task name...',
          hintStyle: const TextStyle(
            color: calendarTimeLabelColor,
            fontSize: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(calendarBorderRadius),
            borderSide: const BorderSide(color: calendarBorderColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(calendarBorderRadius),
            borderSide: const BorderSide(color: Color(0xff007AFF), width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: calendarSpacing12,
            vertical: calendarSpacing12,
          ),
        ),
        style: const TextStyle(
          color: calendarTitleColor,
          fontSize: 14,
        ),
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildDescriptionInput() {
    return TextField(
      controller: _descriptionController,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: 'Description (optional)',
        labelStyle: const TextStyle(
          color: calendarSubtitleColor,
          fontSize: 14,
        ),
        hintText: 'Add details...',
        hintStyle: const TextStyle(
          color: calendarTimeLabelColor,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          borderSide: const BorderSide(color: calendarBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          borderSide: const BorderSide(color: Color(0xff007AFF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: calendarSpacing12,
          vertical: calendarSpacing12,
        ),
      ),
      style: const TextStyle(
        color: calendarTitleColor,
        fontSize: 14,
      ),
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildPriorityToggles() {
    return Row(
      children: [
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Important',
            value: _isImportant,
            color: calendarSuccessColor,
            onChanged: (value) => setState(() => _isImportant = value),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Urgent',
            value: _isUrgent,
            color: calendarWarningColor,
            onChanged: (value) => setState(() => _isUrgent = value),
          ),
        ),
      ],
    );
  }

  Widget _modalDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: calendarSpacing12),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: calendarBorderColor.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildLocationField() {
    return TextField(
      controller: _locationController,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        labelText: 'Location (optional)',
        labelStyle: const TextStyle(
          color: calendarSubtitleColor,
          fontSize: 14,
        ),
        hintText: 'Add a location...',
        hintStyle: const TextStyle(
          color: calendarTimeLabelColor,
          fontSize: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          borderSide: const BorderSide(color: calendarBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(calendarBorderRadius),
          borderSide: const BorderSide(color: Color(0xff007AFF), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: calendarSpacing12,
          vertical: calendarSpacing12,
        ),
      ),
      style: const TextStyle(
        color: calendarTitleColor,
        fontSize: 14,
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Schedule',
          style: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: calendarSpacing8),
        ScheduleRangeFields(
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
                if (_recurrenceFrequency == RecurrenceFrequency.weekly &&
                    (_selectedWeekdays.isEmpty || _selectedWeekdays.length == 1)) {
                  _selectedWeekdays = {value.weekday};
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
        ),
      ],
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Deadline',
          style: calendarSubtitleTextStyle.copyWith(
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: calendarSubtitleTextStyle.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: calendarSpacing8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: RecurrenceFrequency.values
              .map(_buildRecurrenceFrequencyButton)
              .toList(),
        ),
        if (_recurrenceFrequency == RecurrenceFrequency.weekly) ...[
          const SizedBox(height: 10),
          _buildWeekdaySelector(),
        ],
        if (_recurrenceFrequency != RecurrenceFrequency.none) ...[
          const SizedBox(height: 12),
          _buildRecurrenceIntervalControls(),
          const SizedBox(height: 14),
          _buildRecurrenceEndControls(),
        ],
      ],
    );
  }

  Widget _buildRecurrenceIntervalControls() {
    final intervalOptions = List<int>.generate(12, (index) => index + 1)
        .map(
          (value) => ShadOption<int>(
            value: value,
            child: Text('$value'),
          ),
        )
        .toList();

    return Row(
      children: [
        const Text(
          'Repeat every',
          style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
        const SizedBox(width: 14),
        SizedBox(
          width: 120,
          child: ShadSelect<int>(
            initialValue: _recurrenceInterval,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _recurrenceInterval = value);
            },
            options: intervalOptions,
            selectedOptionBuilder: (context, value) => Text('$value'),
            decoration: ShadDecoration(
              color: Colors.white,
              border: ShadBorder.all(
                color: calendarBorderColor,
                width: 1,
                radius: BorderRadius.circular(calendarBorderRadius + 2),
              ),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: calendarSpacing12,
              vertical: calendarSpacing8,
            ),
            trailing: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        const SizedBox(width: calendarSpacing12),
        Text(
          _recurrenceIntervalUnit(_recurrenceFrequency),
          style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const values = [
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
      DateTime.saturday,
      DateTime.sunday,
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(values.length, (index) {
        final value = values[index];
        final selected = _selectedWeekdays.contains(value);
        return ShadButton.raw(
          variant:
              selected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          backgroundColor: selected ? calendarPrimaryColor : Colors.white,
          hoverBackgroundColor: selected
              ? calendarPrimaryHoverColor
              : calendarPrimaryColor.withValues(alpha: 0.08),
          foregroundColor: selected ? Colors.white : calendarPrimaryColor,
          hoverForegroundColor:
              selected ? Colors.white : calendarPrimaryHoverColor,
          onPressed: () {
            setState(() {
              if (selected) {
                final updated = {..._selectedWeekdays}..remove(value);
                _selectedWeekdays = updated.isEmpty ? {value} : updated;
              } else {
                _selectedWeekdays = {..._selectedWeekdays, value};
              }
            });
          },
          child: Text(
            labels[index],
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        );
      }),
    );
  }

  String _recurrenceIntervalUnit(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.monthly:
        return 'month(s)';
      case RecurrenceFrequency.weekly:
      case RecurrenceFrequency.weekdays:
        return 'week(s)';
      case RecurrenceFrequency.daily:
        return 'day(s)';
      case RecurrenceFrequency.none:
        return 'time(s)';
    }
  }

  Widget _buildRecurrenceFrequencyButton(RecurrenceFrequency frequency) {
    final isSelected = _recurrenceFrequency == frequency;

    return ShadButton.raw(
      variant:
          isSelected ? ShadButtonVariant.primary : ShadButtonVariant.outline,
      size: ShadButtonSize.sm,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
      hoverBackgroundColor: isSelected
          ? calendarPrimaryHoverColor
          : calendarPrimaryColor.withValues(alpha: 0.08),
      foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
      hoverForegroundColor:
          isSelected ? Colors.white : calendarPrimaryHoverColor,
      onPressed: () {
        setState(() {
          _recurrenceFrequency = frequency;
          _recurrenceInterval = 1;
          if (frequency == RecurrenceFrequency.none) {
            _recurrenceUntil = null;
            _recurrenceCount = null;
            _recurrenceCountController.clear();
          }
          if (frequency == RecurrenceFrequency.weekly) {
            if (_selectedWeekdays.isEmpty) {
              final fallbackDay = _startTime?.weekday ??
                  widget.prefilledDateTime?.weekday ??
                  DateTime.now().weekday;
              _selectedWeekdays = {fallbackDay};
            }
          }
        });
      },
      child: Text(
        _recurrenceLabel(frequency),
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRecurrenceEndControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'END DATE',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        DeadlinePickerField(
          value: _recurrenceUntil,
          placeholder: 'End',
          showStatusColors: false,
          showTimeSelectors: false,
          onChanged: (value) {
            setState(() {
              _recurrenceUntil = value == null
                  ? null
                  : DateTime(value.year, value.month, value.day);
              if (_recurrenceUntil != null) {
                _recurrenceCount = null;
                _recurrenceCountController.clear();
              }
            });
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'COUNT',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: _recurrenceCountController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Repeat times',
            hintStyle: TextStyle(
              color: calendarSubtitleColor.withValues(alpha: 0.55),
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide: const BorderSide(color: calendarBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(calendarBorderRadius),
              borderSide:
                  const BorderSide(color: calendarPrimaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          onChanged: (value) {
            final parsed = int.tryParse(value);
            setState(() {
              if (parsed == null || parsed <= 0) {
                _recurrenceCount = null;
              } else {
                _recurrenceCount = parsed;
                _recurrenceUntil = null;
              }
            });
          },
        ),
      ],
    );
  }

  String _recurrenceLabel(RecurrenceFrequency frequency) {
    switch (frequency) {
      case RecurrenceFrequency.none:
        return 'Never';
      case RecurrenceFrequency.daily:
        return 'Daily';
      case RecurrenceFrequency.weekdays:
        return 'Weekdays';
      case RecurrenceFrequency.weekly:
        return 'Weekly';
      case RecurrenceFrequency.monthly:
        return 'Monthly';
    }
  }

  Widget _buildActions() {
    return Container(
      padding: calendarPadding16,
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Cancel button
          Expanded(
            child: TextButton(
              onPressed: _isSubmitting ? null : _dismissModal,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(vertical: calendarSpacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(calendarBorderRadius),
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: calendarSubtitleColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),

          const SizedBox(width: calendarSpacing12),

          // Add button
          Expanded(
            child: ElevatedButton(
              onPressed: _canSubmit && !_isSubmitting ? _submitTask : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: calendarPrimaryColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    calendarPrimaryColor.withValues(alpha: 0.4),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                padding:
                    const EdgeInsets.symmetric(vertical: calendarSpacing12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(calendarBorderRadius),
                ),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Add Task',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
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

    RecurrenceRule? recurrence;
    if (scheduledTime != null &&
        _recurrenceFrequency != RecurrenceFrequency.none) {
      final defaultWeekday = scheduledTime.weekday;
      final normalizedWeekdays = (_selectedWeekdays.isEmpty
              ? {defaultWeekday}
              : _selectedWeekdays)
          .toList()
        ..sort();

      switch (_recurrenceFrequency) {
        case RecurrenceFrequency.none:
          break;
        case RecurrenceFrequency.daily:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.daily,
            interval: _recurrenceInterval,
            until: _recurrenceCount != null ? null : _recurrenceUntil,
            count: _recurrenceCount,
          );
          break;
        case RecurrenceFrequency.weekdays:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.weekdays,
            interval: _recurrenceInterval,
            byWeekdays: const [
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            ],
            until: _recurrenceCount != null ? null : _recurrenceUntil,
            count: _recurrenceCount,
          );
          break;
        case RecurrenceFrequency.weekly:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            interval: _recurrenceInterval,
            byWeekdays: normalizedWeekdays,
            until: _recurrenceCount != null ? null : _recurrenceUntil,
            count: _recurrenceCount,
          );
          break;
        case RecurrenceFrequency.monthly:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            interval: _recurrenceInterval,
            until: _recurrenceCount != null ? null : _recurrenceUntil,
            count: _recurrenceCount,
          );
          break;
      }
    }

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
