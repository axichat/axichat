import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/time_formatter.dart';
import 'priority_checkbox_tile.dart';
import 'widgets/deadline_picker_field.dart';

class EditTaskDropdown extends StatefulWidget {
  const EditTaskDropdown({
    super.key,
    required this.task,
    required this.onClose,
    required this.onTaskUpdated,
    required this.onTaskDeleted,
    this.maxHeight = 520,
  });

  final CalendarTask task;
  final VoidCallback onClose;
  final void Function(CalendarTask task) onTaskUpdated;
  final void Function(String taskId) onTaskDeleted;
  final double maxHeight;

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
  bool _isScheduled = false;

  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;

  RecurrenceFrequency _recurrenceFrequency = RecurrenceFrequency.none;
  int _recurrenceInterval = 1;
  DateTime? _recurrenceUntil;
  int? _recurrenceEndAfterAmount;
  RecurrenceEndUnit _recurrenceEndAfterUnit = RecurrenceEndUnit.days;
  late final TextEditingController _recurrenceEndAfterController;
  Set<int> _selectedWeekdays = const {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  final DateFormat _timeFormatter = DateFormat('h:mm a');

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
    _isScheduled = task.scheduledTime != null;

    _startTime = task.scheduledTime;
    _endTime = task.scheduledTime == null
        ? null
        : task.scheduledTime!.add(task.duration ?? const Duration(hours: 1));
    _deadline = task.deadline;

    final recurrence = task.recurrence ?? RecurrenceRule.none;
    _recurrenceFrequency = recurrence.frequency;
    _recurrenceInterval = recurrence.interval;
    if (recurrence.byWeekdays != null && recurrence.byWeekdays!.isNotEmpty) {
      _selectedWeekdays = recurrence.byWeekdays!.toSet();
    }

    _recurrenceUntil = recurrence.until;
    final derived = deriveEndAfterFromCount(
      count: recurrence.count,
      frequency: _recurrenceFrequency,
      interval: _recurrenceInterval,
    );
    if (derived != null) {
      _recurrenceEndAfterAmount = derived.amount;
      _recurrenceEndAfterUnit = derived.unit;
    }

    final base = _recurrenceBaseDate(task.scheduledTime);
    if (_recurrenceUntil == null && _recurrenceEndAfterAmount != null) {
      _recurrenceUntil = calculateRecurrenceEndDate(
        start: base,
        frequency: _recurrenceFrequency,
        interval: _recurrenceInterval,
        byWeekdays: _recurrenceFrequency == RecurrenceFrequency.weekly
            ? (_selectedWeekdays.toList()..sort())
            : null,
        unit: _recurrenceEndAfterUnit,
        amount: _recurrenceEndAfterAmount!,
      );
    }

    _recurrenceEndAfterController = TextEditingController(
      text: _recurrenceEndAfterAmount?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _recurrenceEndAfterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 360,
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
                    _buildDescriptionField(),
                    const SizedBox(height: 10),
                    _buildLocationField(),
                    _sectionDivider(),
                    _buildScheduleToggle(),
                    if (_isScheduled) ...[
                      const SizedBox(height: 10),
                      _buildScheduleFields(),
                    ],
                    _sectionDivider(),
                    _buildDeadlineField(),
                    _sectionDivider(),
                    _buildRecurrenceSection(),
                    _sectionDivider(),
                    _buildPriorityRow(),
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
    return TextField(
      controller: _titleController,
      autofocus: true,
      textCapitalization: TextCapitalization.sentences,
      decoration: _inputDecoration('Task title'),
    );
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descriptionController,
      minLines: 2,
      maxLines: 4,
      decoration: _inputDecoration('Description (optional)'),
      textInputAction: TextInputAction.newline,
    );
  }

  Widget _buildLocationField() {
    return TextField(
      controller: _locationController,
      decoration: _inputDecoration('Location (optional)'),
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

  Widget _buildScheduleToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: calendarBorderColor),
        borderRadius: BorderRadius.circular(6),
        color: Colors.white,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Schedule on calendar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: calendarTitleColor,
                  ),
                ),
                SizedBox(height: 2),
                Flexible(
                  child: Text(
                    'Choose when this task should appear on the timeline.',
                    style: TextStyle(
                      fontSize: 12,
                      color: calendarSubtitleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            foregroundColor: calendarPrimaryColor,
            hoverForegroundColor: calendarPrimaryHoverColor,
            hoverBackgroundColor: calendarPrimaryColor.withOpacity(0.08),
            onPressed: () {
              setState(() {
                _isScheduled = !_isScheduled;
                if (_isScheduled && _startTime == null) {
                  final now = DateTime.now();
                  final base = DateTime(now.year, now.month, now.day, now.hour);
                  _startTime = base.add(const Duration(hours: 1));
                  _endTime = _startTime!.add(const Duration(hours: 1));
                }
              });
            },
            leading: Icon(
              _isScheduled ? Icons.event_busy : Icons.event_available,
              size: 18,
              color: calendarPrimaryColor,
            ),
            child: Text(_isScheduled ? 'Remove schedule' : 'Add to schedule'),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildDateTile('Start date', _startTime, _pickStartDate),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildDateTile('End date', _endTime, _pickEndDate),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildTimeTile('Start time', _startTime, _pickStartTime),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildTimeTile('End time', _endTime, _pickEndTime),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDeadlineField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Deadline',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
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
        const Text(
          'Repeat',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 4),
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
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildRecurrenceIntervalPicker(),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _buildRecurrenceEndControls(),
          ),
        ],
      ],
    );
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
          } else if (frequency == RecurrenceFrequency.weekly &&
              _selectedWeekdays.isEmpty) {
            final defaultDay = _startTime?.weekday ?? DateTime.now().weekday;
            _selectedWeekdays = {defaultDay};
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

  Widget _buildRecurrenceIntervalPicker() {
    final options = List.generate(12, (index) => index + 1)
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
        const SizedBox(width: 12),
        SizedBox(
          width: 120,
          child: ShadSelect<int>(
            initialValue: _recurrenceInterval,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _recurrenceInterval = value);
              _recalculateRecurrenceEndFromAmount();
            },
            options: options,
            selectedOptionBuilder: (context, value) => Text('$value'),
            decoration: ShadDecoration(
              color: Colors.white,
              border: ShadBorder.all(
                color: calendarBorderColor,
                width: 1,
                radius: BorderRadius.circular(10),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            trailing: const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: calendarSubtitleColor,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          _recurrenceIntervalUnit(_recurrenceFrequency),
          style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
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
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
    final base = _recurrenceBaseDate(_startTime);
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

  DateTime _recurrenceBaseDate(DateTime? fallback) {
    return fallback ?? _startTime ?? DateTime.now();
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
      spacing: 4,
      runSpacing: 4,
      children: List.generate(values.length, (index) {
        final value = values[index];
        final isSelected = _selectedWeekdays.contains(value);

        return ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          backgroundColor: isSelected ? calendarPrimaryColor : Colors.white,
          hoverBackgroundColor: isSelected
              ? calendarPrimaryHoverColor
              : calendarPrimaryColor.withOpacity(0.08),
          foregroundColor: isSelected ? Colors.white : calendarPrimaryColor,
          hoverForegroundColor:
              isSelected ? Colors.white : calendarPrimaryHoverColor,
          onPressed: () {
            setState(() {
              if (isSelected) {
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
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        );
      }),
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

  Widget _buildPriorityRow() {
    return Row(
      children: [
        Expanded(
          child: _buildPriorityCheckbox(
            label: 'Important',
            value: _isImportant,
            color: calendarSuccessColor,
            onChanged: (value) => setState(() => _isImportant = value),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPriorityCheckbox(
            label: 'Urgent',
            value: _isUrgent,
            color: calendarWarningColor,
            onChanged: (value) => setState(() => _isUrgent = value),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedCheckbox() {
    return _buildPriorityCheckbox(
      label: 'Mark as completed',
      value: _isCompleted,
      color: calendarPrimaryColor,
      onChanged: (value) => setState(() => _isCompleted = value),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
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
            hoverBackgroundColor: calendarPrimaryColor.withOpacity(0.08),
            onPressed: widget.onClose,
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 8),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String placeholder) {
    return InputDecoration(
      hintText: placeholder,
      hintStyle: const TextStyle(
        color: calendarTimeLabelColor,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: calendarBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: calendarBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xff0969DA), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildDateTile(
      String label, DateTime? value, Future<void> Function() onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: calendarBorderColor),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.event, size: 16, color: calendarSubtitleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Select'
                        : TimeFormatter.formatFriendlyDate(value),
                    style: const TextStyle(
                      fontSize: 13,
                      color: calendarTitleColor,
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

  Widget _buildTimeTile(
      String label, DateTime? value, Future<void> Function() onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: calendarBorderColor),
              color: Colors.white,
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time,
                    size: 16, color: calendarSubtitleColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    value == null ? 'Select' : _timeFormatter.format(value),
                    style: const TextStyle(
                      fontSize: 13,
                      color: calendarTitleColor,
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

  Widget _buildPriorityCheckbox({
    required String label,
    required bool value,
    required Color color,
    required ValueChanged<bool> onChanged,
  }) {
    return PriorityCheckboxTile(
      label: label,
      value: value,
      color: color,
      onChanged: onChanged,
    );
  }

  Future<void> _pickStartDate() async {
    final base = _startTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _startTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _startTime?.hour ?? 9,
        _startTime?.minute ?? 0,
      );
      if (_endTime == null || _endTime!.isBefore(_startTime!)) {
        _endTime = _startTime!.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickStartTime() async {
    final base = _startTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _startTime = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (_endTime == null || _endTime!.isBefore(_startTime!)) {
        _endTime = _startTime!.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndDate() async {
    final base = _endTime ?? _startTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _endTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _endTime?.hour ?? (_startTime?.hour ?? 10),
        _endTime?.minute ?? (_startTime?.minute ?? 0),
      );
      if (_startTime != null && _endTime!.isBefore(_startTime!)) {
        _endTime = _startTime!.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEndTime() async {
    final base = _endTime ?? _startTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _endTime = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (_startTime != null && _endTime!.isBefore(_startTime!)) {
        _endTime = _startTime!.add(const Duration(hours: 1));
      }
    });
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
    if (_isScheduled && _startTime != null && _endTime != null) {
      duration = _endTime!.difference(_startTime!);
      if (duration.inMinutes < 15) {
        duration = const Duration(minutes: 15);
        _endTime = _startTime!.add(duration);
      }
      scheduledTime = _startTime;
    }

    RecurrenceRule? recurrence;
    if (_recurrenceFrequency != RecurrenceFrequency.none) {
      List<int>? weekdays;
      if (_recurrenceFrequency == RecurrenceFrequency.weekdays) {
        weekdays = const [
          DateTime.monday,
          DateTime.tuesday,
          DateTime.wednesday,
          DateTime.thursday,
          DateTime.friday,
        ];
      } else if (_recurrenceFrequency == RecurrenceFrequency.weekly) {
        weekdays = _selectedWeekdays.toList()..sort();
      }

      recurrence = RecurrenceRule(
        frequency: _recurrenceFrequency,
        interval: _recurrenceInterval,
        byWeekdays: weekdays,
        until: _recurrenceUntil,
        count: null,
      );
    }

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

    widget.onTaskUpdated(updatedTask);
    widget.onClose();
  }
}
