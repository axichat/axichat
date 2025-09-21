import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import 'priority_checkbox_tile.dart';
import 'widgets/deadline_picker_field.dart';

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
  final _taskNameFocusNode = FocusNode();

  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isSubmitting = false;
  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.none;
  int _recurrenceInterval = 1;
  late Set<int> _selectedWeekdays;
  DateTime? _recurrenceUntil;
  int? _recurrenceEndAfterAmount;
  RecurrenceEndUnit _recurrenceEndAfterUnit = RecurrenceEndUnit.days;
  final TextEditingController _recurrenceEndAfterController =
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

    final defaultWeekday = widget.prefilledDateTime?.weekday ?? DateTime.monday;
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
    _taskNameFocusNode.dispose();
    _recurrenceEndAfterController.dispose();
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
                    _buildPriorityToggles(),
                    if (widget.prefilledDateTime != null) ...[
                      _modalDivider(),
                      _buildRecurrenceSection(),
                      _modalDivider(),
                      _buildTimeInfo(),
                    ],
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
        if (_recurrenceFrequency == RecurrenceFrequency.weekly ||
            _recurrenceFrequency == RecurrenceFrequency.weekdays) ...[
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
              _recalculateRecurrenceEndFromAmount();
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
              : calendarPrimaryColor.withOpacity(0.08),
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
            _recalculateRecurrenceEndFromAmount();
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
          : calendarPrimaryColor.withOpacity(0.08),
      foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
      hoverForegroundColor:
          isSelected ? Colors.white : calendarPrimaryHoverColor,
      onPressed: () {
        setState(() {
          _recurrenceFrequency = frequency;
          _recurrenceInterval = 1;
          if (frequency == RecurrenceFrequency.none) {
            _recurrenceUntil = null;
            _recurrenceEndAfterAmount = null;
            _recurrenceEndAfterController.clear();
            _recurrenceEndAfterUnit = RecurrenceEndUnit.days;
          }
          if (frequency == RecurrenceFrequency.weekdays) {
            _selectedWeekdays = const {
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            };
          } else if (frequency == RecurrenceFrequency.weekly) {
            if (_selectedWeekdays.isEmpty) {
              final defaultDay =
                  widget.prefilledDateTime?.weekday ?? DateTime.monday;
              _selectedWeekdays = {defaultDay};
            }
          }
        });
        if (frequency != RecurrenceFrequency.none) {
          _recalculateRecurrenceEndFromAmount();
        }
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
    const units = RecurrenceEndUnit.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: DeadlinePickerField(
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
                  _recurrenceEndAfterAmount = null;
                  _recurrenceEndAfterController.clear();
                }
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(calendarBorderRadius),
            border: Border.all(color: calendarBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recurrenceEndAfterController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Count',
                      hintStyle: TextStyle(
                        color: calendarSubtitleColor.withValues(alpha: 0.55),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      final parsed = int.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        setState(() {
                          _recurrenceEndAfterAmount = null;
                          _recurrenceUntil = null;
                        });
                        return;
                      }
                      _setRecurrenceEndAfterAmount(parsed);
                    },
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: calendarBorderColor.withValues(alpha: 0.5),
                ),
                SizedBox(
                  width: 132,
                  child: ShadSelect<RecurrenceEndUnit>(
                    initialValue: _recurrenceEndAfterUnit,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _recurrenceEndAfterUnit = value);
                      _recalculateRecurrenceEndFromAmount();
                    },
                    options: units
                        .map(
                          (unit) => ShadOption<RecurrenceEndUnit>(
                            value: unit,
                            child: Text(unit.label),
                          ),
                        )
                        .toList(),
                    selectedOptionBuilder: (context, value) =>
                        Text(value.label),
                    decoration: ShadDecoration(
                      color: Colors.white,
                      border: ShadBorder.all(
                        color: Colors.transparent,
                        radius: BorderRadius.circular(6),
                      ),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    trailing: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: calendarSubtitleColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _setRecurrenceEndAfterAmount(int amount) {
    final base = _recurrenceBaseDate();
    final weekdays = _recurrenceFrequency == RecurrenceFrequency.weekly
        ? (_selectedWeekdays.toList()..sort())
        : null;
    final until = calculateRecurrenceEndDate(
      start: base,
      frequency: _recurrenceFrequency,
      interval: _recurrenceInterval,
      byWeekdays: weekdays,
      unit: _recurrenceEndAfterUnit,
      amount: amount,
    );

    setState(() {
      _recurrenceEndAfterAmount = amount;
      _recurrenceUntil = until;
    });
  }

  void _recalculateRecurrenceEndFromAmount() {
    final amount = _recurrenceEndAfterAmount;
    if (amount == null || amount <= 0) {
      return;
    }
    _setRecurrenceEndAfterAmount(amount);
  }

  DateTime _recurrenceBaseDate() {
    return widget.prefilledDateTime ?? DateTime.now();
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

  Widget _buildTimeInfo() {
    final dateTime = widget.prefilledDateTime!;
    final timeFormat = TimeOfDay.fromDateTime(dateTime).format(context);
    final dateFormat =
        '${_getDayName(dateTime.weekday)}, ${_getMonthName(dateTime.month)} ${dateTime.day}';

    return Container(
      padding: calendarPadding12,
      decoration: BoxDecoration(
        color: calendarSelectedDayColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule,
            color: calendarSubtitleColor,
            size: 16,
          ),
          const SizedBox(width: calendarSpacing8),
          Text(
            '$dateFormat at $timeFormat',
            style: calendarSubtitleTextStyle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
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
                disabledBackgroundColor: calendarPrimaryColor.withOpacity(0.4),
                disabledForegroundColor: Colors.white.withOpacity(0.7),
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
    final scheduledTime = widget.prefilledDateTime;

    RecurrenceRule? recurrence;
    if (_recurrenceFrequency != RecurrenceFrequency.none) {
      final defaultWeekday =
          widget.prefilledDateTime?.weekday ?? DateTime.monday;
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
            until: _recurrenceUntil,
            count: null,
          );
          break;
        case RecurrenceFrequency.weekdays:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.weekdays,
            interval: _recurrenceInterval,
            byWeekdays: normalizedWeekdays,
            until: _recurrenceUntil,
            count: null,
          );
          break;
        case RecurrenceFrequency.weekly:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.weekly,
            interval: _recurrenceInterval,
            byWeekdays: normalizedWeekdays,
            until: _recurrenceUntil,
            count: null,
          );
          break;
        case RecurrenceFrequency.monthly:
          recurrence = RecurrenceRule(
            frequency: RecurrenceFrequency.monthly,
            interval: _recurrenceInterval,
            until: _recurrenceUntil,
            count: null,
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
      duration: scheduledTime != null ? const Duration(hours: 1) : null,
      priority: _selectedPriority,
      isCompleted: false,
      createdAt: DateTime.now(),
      modifiedAt: DateTime.now(),
      recurrence: recurrence,
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

  String _getMonthName(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  String _getDayName(int weekday) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday];
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
