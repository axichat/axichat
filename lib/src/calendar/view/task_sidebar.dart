import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';

import 'priority_checkbox_tile.dart';

import '../bloc/base_calendar_bloc.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../models/calendar_task.dart';
import '../utils/recurrence_utils.dart';
import '../utils/time_formatter.dart';
import 'edit_task_dropdown.dart';
import 'widgets/deadline_picker_field.dart';

enum _SidebarSection { unscheduled, reminders }

class TaskSidebar extends StatefulWidget {
  const TaskSidebar({super.key});

  @override
  State<TaskSidebar> createState() => _TaskSidebarState();
}

class _TaskSidebarState extends State<TaskSidebar>
    with TickerProviderStateMixin {
  late double _width;
  bool _widthInitialized = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  DateTime? _selectedDeadline;
  bool _isImportant = false;
  bool _isUrgent = false;
  bool _isResizing = false;

  _SidebarSection? _expandedSection = _SidebarSection.unscheduled;
  bool _showAdvancedOptions = false;
  bool _scheduleEnabled = false;
  DateTime? _advancedStartTime;
  DateTime? _advancedEndTime;
  RecurrenceFrequency _advancedRecurrenceFrequency = RecurrenceFrequency.none;
  int _advancedRecurrenceInterval = 1;
  DateTime? _advancedRecurrenceUntil;
  int? _advancedRecurrenceEndAfterAmount;
  RecurrenceEndUnit _advancedRecurrenceEndAfterUnit = RecurrenceEndUnit.days;
  final TextEditingController _advancedRecurrenceEndAfterController =
      TextEditingController();
  Set<int> _advancedSelectedWeekdays = const {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  final Map<String, ShadPopoverController> _taskPopoverControllers = {};
  String? _activePopoverTaskId;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _advancedRecurrenceEndAfterController.dispose();
    _scrollController.dispose();
    for (final controller in _taskPopoverControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final minWidth = (screenWidth * 0.25).clamp(220.0, screenWidth);
    final maxWidth = (screenWidth * 0.5).clamp(minWidth, screenWidth);
    final defaultWidth = (screenWidth * 0.33).clamp(minWidth, maxWidth);

    if (!_widthInitialized) {
      _width = defaultWidth.toDouble();
      _widthInitialized = true;
    }
    _width = _width.clamp(minWidth, maxWidth).toDouble();

    return Container(
      width: _width,
      decoration: const BoxDecoration(
        color: sidebarBackgroundColor,
        border: Border(
          right: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: BlocBuilder<BaseCalendarBloc, CalendarState>(
              builder: (context, state) {
                final unscheduledTasks = _sortTasksByDeadline(
                  state.unscheduledTasks
                      .where((task) => task.deadline == null)
                      .toList(),
                );
                final reminderTasks = _sortTasksByDeadline(
                  state.unscheduledTasks
                      .where((task) => task.deadline != null)
                      .toList(),
                );

                return Scrollbar(
                  controller: _scrollController,
                  radius: const Radius.circular(8),
                  thickness: 6,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(bottom: 24),
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAddTaskSection(),
                        _buildTaskSections(
                          unscheduledTasks,
                          reminderTasks,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          _buildResizeHandle(
            minWidth: minWidth.toDouble(),
            maxWidth: maxWidth.toDouble(),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildAddTaskSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ADD TASK',
            style: calendarHeaderTextStyle.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: calendarTimeLabelColor,
            ),
          ),
          const SizedBox(height: 16),
          _buildQuickTaskInput(),
          const SizedBox(height: 16),
          _buildPriorityToggles(),
          const SizedBox(height: 12),
          _buildAdvancedToggle(),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, animation) {
              final fade = CurvedAnimation(
                parent: animation,
                curve: Curves.easeOut,
              );
              return FadeTransition(
                opacity: fade,
                child: SizeTransition(
                  sizeFactor: fade,
                  axisAlignment: -1,
                  child: child,
                ),
              );
            },
            child: _showAdvancedOptions
                ? _buildAdvancedOptions(key: const ValueKey('advanced'))
                : const SizedBox.shrink(key: ValueKey('advanced-hidden')),
          ),
          const SizedBox(height: 16),
          _buildAddButton(),
        ],
      ),
    );
  }

  Widget _buildQuickTaskInput() {
    return TextField(
      controller: _titleController,
      decoration:
          _fieldDecoration('Quick task (e.g., "Meeting at 2pm in Room 101")'),
      style: const TextStyle(
        fontSize: 14,
        color: calendarTitleColor,
      ),
      onSubmitted: (_) => _addTask(),
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
        const SizedBox(width: 12),
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

  Widget _buildAdvancedToggle() {
    return Align(
      alignment: Alignment.centerLeft,
      child: ShadButton.ghost(
        size: ShadButtonSize.sm,
        foregroundColor: calendarPrimaryColor,
        hoverForegroundColor: calendarPrimaryHoverColor,
        hoverBackgroundColor: calendarPrimaryColor.withOpacity(0.08),
        onPressed: () => setState(() {
          _showAdvancedOptions = !_showAdvancedOptions;
        }),
        leading: Icon(
          _showAdvancedOptions ? Icons.expand_less : Icons.expand_more,
          size: 18,
          color: calendarPrimaryColor,
        ),
        child: Text(
          _showAdvancedOptions
              ? 'Hide advanced options'
              : 'Show advanced options',
        ),
      ),
    );
  }

  Widget _buildAdvancedOptions({Key? key}) {
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: calendarBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLinedTextField(
            controller: _descriptionController,
            hint: 'Description (optional)',
            minLines: 2,
            maxLines: 4,
          ),
          const SizedBox(height: 10),
          _buildLinedTextField(
            controller: _locationController,
            hint: 'Location (optional)',
          ),
          const SizedBox(height: 12),
          const Text(
            'Deadline',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: calendarSubtitleColor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          DeadlinePickerField(
            value: _selectedDeadline,
            onChanged: (value) => setState(() => _selectedDeadline = value),
          ),
          _advancedDivider(),
          _buildAdvancedScheduleToggle(),
          if (_scheduleEnabled) ...[
            const SizedBox(height: 10),
            _buildAdvancedScheduleFields(),
          ],
          _advancedDivider(),
          _buildAdvancedRecurrenceSection(),
        ],
      ),
    );
  }

  Widget _buildLinedTextField({
    required TextEditingController controller,
    required String hint,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: _fieldDecoration(hint),
      textInputAction:
          maxLines == 1 ? TextInputAction.done : TextInputAction.newline,
    );
  }

  Widget _buildAdvancedScheduleToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
          const SizedBox(width: 12),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            foregroundColor: calendarPrimaryColor,
            hoverForegroundColor: calendarPrimaryHoverColor,
            hoverBackgroundColor: calendarPrimaryColor.withOpacity(0.08),
            onPressed: () {
              setState(() {
                _scheduleEnabled = !_scheduleEnabled;
                if (_scheduleEnabled && _advancedStartTime == null) {
                  final now = DateTime.now();
                  final base = DateTime(
                    now.year,
                    now.month,
                    now.day,
                    now.hour,
                  );
                  _advancedStartTime = base.add(const Duration(hours: 1));
                  _advancedEndTime =
                      _advancedStartTime!.add(const Duration(hours: 1));
                }
              });
            },
            leading: Icon(
              _scheduleEnabled ? Icons.event_busy : Icons.event_available,
              size: 18,
              color: calendarPrimaryColor,
            ),
            child: Text(
              _scheduleEnabled ? 'Remove schedule' : 'Add to schedule',
            ),
          ),
        ],
      ),
    );
  }

  Widget _advancedDivider() {
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

  Widget _buildAdvancedScheduleFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAdvancedDateTile(
                label: 'Start date',
                value: _advancedStartTime,
                onTap: _pickAdvancedStartDate,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdvancedDateTile(
                label: 'End date',
                value: _advancedEndTime,
                onTap: _pickAdvancedEndDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildAdvancedTimeTile(
                label: 'Start time',
                value: _advancedStartTime,
                onTap: _pickAdvancedStartTime,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildAdvancedTimeTile(
                label: 'End time',
                value: _advancedEndTime,
                onTap: _pickAdvancedEndTime,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedDateTile({
    required String label,
    required DateTime? value,
    required Future<void> Function() onTap,
  }) {
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

  Widget _buildAdvancedTimeTile({
    required String label,
    required DateTime? value,
    required Future<void> Function() onTap,
  }) {
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
                    value == null ? 'Select' : TimeFormatter.formatTime(value),
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

  Future<void> _pickAdvancedStartDate() async {
    final base = _advancedStartTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _advancedStartTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _advancedStartTime?.hour ?? 9,
        _advancedStartTime?.minute ?? 0,
      );
      if (_advancedEndTime == null ||
          _advancedEndTime!.isBefore(_advancedStartTime!)) {
        _advancedEndTime = _advancedStartTime!.add(const Duration(hours: 1));
      }
    });
    _recalculateAdvancedRecurrenceEndFromAmount();
  }

  Future<void> _pickAdvancedEndDate() async {
    final base = _advancedEndTime ?? _advancedStartTime ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return;
    setState(() {
      _advancedEndTime = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _advancedEndTime?.hour ?? 10,
        _advancedEndTime?.minute ?? 0,
      );
      if (_advancedStartTime != null &&
          _advancedEndTime!.isBefore(_advancedStartTime!)) {
        _advancedEndTime = _advancedStartTime!.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickAdvancedStartTime() async {
    final base = _advancedStartTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _advancedStartTime = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (_advancedEndTime == null ||
          _advancedEndTime!.isBefore(_advancedStartTime!)) {
        _advancedEndTime = _advancedStartTime!.add(const Duration(hours: 1));
      }
    });
    _recalculateAdvancedRecurrenceEndFromAmount();
  }

  Future<void> _pickAdvancedEndTime() async {
    final base = _advancedEndTime ?? _advancedStartTime ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked == null) return;
    setState(() {
      _advancedEndTime = DateTime(
        base.year,
        base.month,
        base.day,
        picked.hour,
        picked.minute,
      );
      if (_advancedStartTime != null &&
          _advancedEndTime!.isBefore(_advancedStartTime!)) {
        _advancedEndTime = _advancedStartTime!.add(const Duration(hours: 1));
      }
    });
  }

  Widget _buildAdvancedRecurrenceSection() {
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
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: RecurrenceFrequency.values
              .map(_buildRecurrenceFrequencyButton)
              .toList(),
        ),
        if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekly ||
            _advancedRecurrenceFrequency == RecurrenceFrequency.weekdays) ...[
          const SizedBox(height: 12),
          _buildAdvancedWeekdaySelector(),
        ],
        if (_advancedRecurrenceFrequency != RecurrenceFrequency.none) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _buildAdvancedRecurrenceInterval(),
          ),
          const SizedBox(height: 14),
          _buildAdvancedRecurrenceEndControls(),
        ],
      ],
    );
  }

  Widget _buildRecurrenceFrequencyButton(RecurrenceFrequency frequency) {
    final isSelected = _advancedRecurrenceFrequency == frequency;

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
          _advancedRecurrenceFrequency = frequency;
          _advancedRecurrenceInterval = 1;
          if (frequency == RecurrenceFrequency.none) {
            _advancedRecurrenceUntil = null;
            _advancedRecurrenceEndAfterAmount = null;
            _advancedRecurrenceEndAfterController.clear();
            _advancedRecurrenceEndAfterUnit = RecurrenceEndUnit.days;
          }
          if (frequency == RecurrenceFrequency.weekdays) {
            _advancedSelectedWeekdays = const {
              DateTime.monday,
              DateTime.tuesday,
              DateTime.wednesday,
              DateTime.thursday,
              DateTime.friday,
            };
          } else if (frequency == RecurrenceFrequency.weekly &&
              _advancedSelectedWeekdays.isEmpty) {
            final defaultDay =
                _advancedStartTime?.weekday ?? DateTime.now().weekday;
            _advancedSelectedWeekdays = {defaultDay};
          }
        });
        if (frequency != RecurrenceFrequency.none) {
          _recalculateAdvancedRecurrenceEndFromAmount();
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

  Widget _buildAdvancedRecurrenceInterval() {
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
          width: 118,
          child: ShadSelect<int>(
            initialValue: _advancedRecurrenceInterval,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _advancedRecurrenceInterval = value);
              _recalculateAdvancedRecurrenceEndFromAmount();
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
          _recurrenceIntervalUnit(_advancedRecurrenceFrequency),
          style: const TextStyle(fontSize: 12, color: calendarSubtitleColor),
        ),
      ],
    );
  }

  Widget _buildAdvancedRecurrenceEndControls() {
    const units = RecurrenceEndUnit.values;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: DeadlinePickerField(
            value: _advancedRecurrenceUntil,
            placeholder: 'End',
            showStatusColors: false,
            showTimeSelectors: false,
            onChanged: (value) {
              setState(() {
                _advancedRecurrenceUntil = value == null
                    ? null
                    : DateTime(value.year, value.month, value.day);
                if (_advancedRecurrenceUntil != null) {
                  _advancedRecurrenceEndAfterAmount = null;
                  _advancedRecurrenceEndAfterController.clear();
                }
              });
            },
          ),
        ),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: calendarBorderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _advancedRecurrenceEndAfterController,
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
                          _advancedRecurrenceEndAfterAmount = null;
                          _advancedRecurrenceUntil = null;
                        });
                        return;
                      }
                      _setAdvancedRecurrenceEndAfterAmount(parsed);
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
                    initialValue: _advancedRecurrenceEndAfterUnit,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _advancedRecurrenceEndAfterUnit = value);
                      _recalculateAdvancedRecurrenceEndFromAmount();
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

  void _setAdvancedRecurrenceEndAfterAmount(int amount) {
    final base = _advancedRecurrenceBaseDate();
    final weekdays = _advancedRecurrenceFrequency == RecurrenceFrequency.weekly
        ? (_advancedSelectedWeekdays.toList()..sort())
        : null;
    final until = calculateRecurrenceEndDate(
      start: base,
      frequency: _advancedRecurrenceFrequency,
      interval: _advancedRecurrenceInterval,
      byWeekdays: weekdays,
      unit: _advancedRecurrenceEndAfterUnit,
      amount: amount,
    );

    setState(() {
      _advancedRecurrenceEndAfterAmount = amount;
      _advancedRecurrenceUntil = until;
    });
  }

  void _recalculateAdvancedRecurrenceEndFromAmount() {
    final amount = _advancedRecurrenceEndAfterAmount;
    if (amount == null || amount <= 0) {
      return;
    }
    _setAdvancedRecurrenceEndAfterAmount(amount);
  }

  DateTime _advancedRecurrenceBaseDate() {
    return _advancedStartTime ?? DateTime.now();
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

  Widget _buildAdvancedWeekdaySelector() {
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
        final isSelected = _advancedSelectedWeekdays.contains(value);

        return ShadButton.raw(
          variant: isSelected
              ? ShadButtonVariant.primary
              : ShadButtonVariant.outline,
          size: ShadButtonSize.sm,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                final updated = {..._advancedSelectedWeekdays}..remove(value);
                _advancedSelectedWeekdays = updated.isEmpty ? {value} : updated;
              } else {
                _advancedSelectedWeekdays = {
                  ..._advancedSelectedWeekdays,
                  value,
                };
              }
            });
            _recalculateAdvancedRecurrenceEndFromAmount();
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

  Widget _buildAddButton() {
    final isDisabled = _titleController.text.trim().isEmpty;
    return SizedBox(
      width: double.infinity,
      child: ShadButton(
        size: ShadButtonSize.sm,
        onPressed: isDisabled ? null : _addTask,
        backgroundColor: isDisabled
            ? calendarPrimaryColor.withOpacity(0.5)
            : calendarPrimaryColor,
        hoverBackgroundColor: calendarPrimaryHoverColor,
        foregroundColor: Colors.white,
        child: const Text('Add Task'),
      ),
    );
  }

  Widget _buildTaskSections(
    List<CalendarTask> unscheduledTasks,
    List<CalendarTask> reminderTasks,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildAccordionSection(
          title: 'UNSCHEDULED TASKS',
          section: _SidebarSection.unscheduled,
          itemCount: unscheduledTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildTaskList(
              unscheduledTasks,
              emptyLabel: 'No unscheduled tasks',
              emptyHint: 'Tasks you add will appear here',
            ),
          ),
          collapsedChild: _buildCollapsedPreview(unscheduledTasks),
        ),
        const SizedBox(height: 4),
        _buildAccordionSection(
          title: 'REMINDERS',
          section: _SidebarSection.reminders,
          itemCount: reminderTasks.length,
          expandedChild: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: _buildReminderList(reminderTasks),
          ),
          collapsedChild: _buildCollapsedPreview(reminderTasks),
        ),
      ],
    );
  }

  Widget _buildAccordionSection({
    required String title,
    required _SidebarSection section,
    required int itemCount,
    required Widget expandedChild,
    required Widget collapsedChild,
  }) {
    final isExpanded = _expandedSection == section;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(
            color: sidebarBackgroundColor,
            border: Border(
              bottom: section == _SidebarSection.unscheduled
                  ? const BorderSide(color: calendarBorderColor, width: 1)
                  : BorderSide.none,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedSection = section == _SidebarSection.unscheduled
                        ? _SidebarSection.reminders
                        : _SidebarSection.unscheduled;
                  } else {
                    _expandedSection = section;
                  }
                }),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: calendarSubtitleColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      _buildCountBadge(itemCount, isExpanded),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 18,
                        color: calendarSubtitleColor,
                      ),
                    ],
                  ),
                ),
              ),
              ClipRect(
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  firstChild: const SizedBox.shrink(),
                  secondChild: Container(
                    padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
                    child: expandedChild,
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  sizeCurve: Curves.easeInOutCubic,
                  alignment: Alignment.topCenter,
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 160),
                firstChild: Container(
                  key: ValueKey('${section.name}-collapsed'),
                  padding: const EdgeInsets.fromLTRB(14, 6, 14, 6),
                  constraints: const BoxConstraints(minHeight: 40),
                  child: collapsedChild,
                ),
                secondChild: const SizedBox.shrink(),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedPreview(List<CalendarTask> tasks) {
    if (tasks.isEmpty) {
      return const Text(
        'Nothing here yet',
        style: TextStyle(fontSize: 12, color: calendarSubtitleColor),
      );
    }

    final previewTitles = tasks.take(2).map((task) => task.title).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: previewTitles
          .map(
            (title) => Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                '• $title',
                style:
                    const TextStyle(fontSize: 12, color: calendarSubtitleColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildTaskList(
    List<CalendarTask> tasks, {
    required String emptyLabel,
    String? emptyHint,
  }) {
    return DragTarget<CalendarTask>(
      onAcceptWithDetails: (details) {
        context.read<BaseCalendarBloc>().add(
              CalendarEvent.taskUpdated(
                task: details.data.copyWith(scheduledTime: null),
              ),
            );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isHovering
                ? calendarPrimaryColor.withOpacity(0.08)
                : sidebarBackgroundColor,
            border: isHovering
                ? Border.all(color: calendarPrimaryColor, width: 2)
                : null,
          ),
          child: tasks.isEmpty
              ? _buildEmptyState(
                  label: emptyLabel,
                  hint: emptyHint,
                  isHovering: isHovering,
                )
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    return _buildDraggableTaskTile(task);
                  },
                ),
        );
      },
    );
  }

  Widget _buildReminderList(List<CalendarTask> tasks) {
    return _buildTaskList(
      tasks,
      emptyLabel: 'No reminders yet',
      emptyHint: 'Add a deadline to create a reminder',
    );
  }

  Widget _buildEmptyState({
    required String label,
    String? hint,
    required bool isHovering,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isHovering ? Icons.add_task : Icons.inbox_outlined,
              size: 48,
              color: isHovering ? calendarPrimaryColor : calendarTimeLabelColor,
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                color:
                    isHovering ? calendarPrimaryColor : calendarTimeLabelColor,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint,
                style: const TextStyle(
                  color: calendarTimeLabelColor,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCountBadge(int count, bool isExpanded) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isExpanded
            ? calendarPrimaryColor
            : calendarPrimaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isExpanded ? Colors.white : calendarPrimaryColor,
        ),
      ),
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 52),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: badge,
      ),
    );
  }

  Widget _buildDraggableTaskTile(CalendarTask task) {
    return Draggable<CalendarTask>(
      data: task,
      feedback: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: 0.7,
          child: SizedBox(
            width: _width - 32,
            child: _buildTaskTile(
              task,
              enableInteraction: false,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _buildTaskTile(
          task,
          enableInteraction: false,
        ),
      ),
      child: _buildTaskTile(task),
    );
  }

  Widget _buildTaskTile(
    CalendarTask task, {
    bool enableInteraction = true,
  }) {
    final borderColor = task.priorityColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              left: BorderSide(color: borderColor, width: 3),
              top: const BorderSide(color: calendarBorderColor),
              right: const BorderSide(color: calendarBorderColor),
              bottom: const BorderSide(color: calendarBorderColor),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            child: enableInteraction
                ? Builder(
                    builder: (tileContext) {
                      final controller = _popoverControllerFor(task.id);
                      final renderBox =
                          tileContext.findRenderObject() as RenderBox?;
                      final tileSize = renderBox?.size ?? Size.zero;
                      final tileOrigin =
                          renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
                      final screenSize = MediaQuery.of(tileContext).size;

                      const double margin = 16.0;
                      const double dropdownMaxHeight =
                          644.0; // Increased by 40% from 460

                      final availableBelow = screenSize.height -
                          (tileOrigin.dy + tileSize.height) -
                          margin;
                      final availableAbove = tileOrigin.dy - margin;

                      bool showAbove =
                          availableAbove > availableBelow && availableAbove > 0;
                      if (!showAbove &&
                          availableBelow <= 0 &&
                          availableAbove > 0) {
                        showAbove = true;
                      }

                      double availableSpace =
                          showAbove ? availableAbove : availableBelow;

                      if (availableSpace <= 0) {
                        availableSpace = dropdownMaxHeight;
                      }

                      double effectiveMaxHeight =
                          availableSpace >= dropdownMaxHeight
                              ? dropdownMaxHeight
                              : availableSpace;
                      if (effectiveMaxHeight > dropdownMaxHeight) {
                        effectiveMaxHeight = dropdownMaxHeight;
                      }
                      if (effectiveMaxHeight < 220 && availableSpace > 220) {
                        effectiveMaxHeight =
                            math.min(availableSpace, dropdownMaxHeight);
                      }
                      if (effectiveMaxHeight < 160) {
                        effectiveMaxHeight = availableSpace <= 0
                            ? math.min(160.0, dropdownMaxHeight)
                            : math.min(availableSpace, 160.0);
                      }

                      final anchor = showAbove
                          ? ShadAnchorAuto(
                              followerAnchor: Alignment.bottomLeft,
                              targetAnchor: Alignment.topRight,
                              offset: const Offset(12, -8),
                            )
                          : ShadAnchorAuto(
                              followerAnchor: Alignment.topLeft,
                              targetAnchor: Alignment.bottomRight,
                              offset: const Offset(12, 8),
                            );

                      return ShadPopover(
                        controller: controller,
                        closeOnTapOutside: true,
                        anchor: anchor,
                        padding: EdgeInsets.zero,
                        popover: (context) {
                          return BlocBuilder<BaseCalendarBloc, CalendarState>(
                            builder: (context, state) {
                              final baseId = task.baseId;
                              final latestTask =
                                  state.model.tasks[baseId] ?? task;

                              return EditTaskDropdown(
                                task: latestTask,
                                maxHeight: effectiveMaxHeight,
                                onClose: () => _closeTaskPopover(task.id),
                                onTaskUpdated: (updatedTask) {
                                  context.read<BaseCalendarBloc>().add(
                                        CalendarEvent.taskUpdated(
                                          task: updatedTask,
                                        ),
                                      );
                                },
                                onTaskDeleted: (taskId) {
                                  context.read<BaseCalendarBloc>().add(
                                        CalendarEvent.taskDeleted(
                                          taskId: taskId,
                                        ),
                                      );
                                  _closeTaskPopover(task.id);
                                  _taskPopoverControllers
                                      .remove(task.id)
                                      ?.dispose();
                                },
                              );
                            },
                          );
                        },
                        child: InkWell(
                          borderRadius: BorderRadius.circular(6),
                          hoverColor:
                              calendarSidebarBackgroundColor.withOpacity(0.5),
                          onTap: () => _toggleTaskPopover(task.id),
                          child: _buildTaskTileBody(task),
                        ),
                      );
                    },
                  )
                : _buildTaskTileBody(task),
          ),
        ),
      ),
    );
  }

  Widget _buildTaskTileBody(CalendarTask task) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            task.title,
            style: const TextStyle(fontSize: 13, color: calendarTitleColor),
          ),
          if (task.description?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(
              task.description!.length > 50
                  ? '${task.description!.substring(0, 50)}...'
                  : task.description!,
              style: const TextStyle(
                fontSize: 11,
                color: calendarSubtitleColor,
              ),
            ),
          ],
          if (task.deadline != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getDeadlineBackgroundColor(task.deadline!),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.event,
                    size: 12,
                    color: _getDeadlineColor(task.deadline!),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getFullDeadlineText(task.deadline!),
                    style: TextStyle(
                      fontSize: 11,
                      color: _getDeadlineColor(task.deadline!),
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (task.location?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('📍 ', style: TextStyle(fontSize: 11)),
                Expanded(
                  child: Text(
                    task.location!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: calendarSubtitleColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResizeHandle(
      {required double minWidth, required double maxWidth}) {
    return Positioned(
      right: 0,
      top: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        onEnter: (_) => setState(() {}),
        onExit: (_) => setState(() {}),
        child: GestureDetector(
          onPanStart: (details) => setState(() => _isResizing = true),
          onPanUpdate: (details) {
            setState(() {
              final newWidth = _width + details.delta.dx;
              _width = newWidth.clamp(minWidth, maxWidth);
            });
          },
          onPanEnd: (details) => setState(() => _isResizing = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 8,
            color: _isResizing
                ? calendarPrimaryColor.withOpacity(0.2)
                : Colors.transparent,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: _isResizing ? 3 : 2,
                height: _isResizing ? 60 : 50,
                decoration: BoxDecoration(
                  color:
                      _isResizing ? calendarPrimaryColor : calendarBorderColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<CalendarTask> _sortTasksByDeadline(List<CalendarTask> tasks) {
    final List<CalendarTask> tasksCopy = List.from(tasks);
    tasksCopy.sort((a, b) {
      final now = DateTime.now();

      int getDeadlineCategory(DateTime? deadline) {
        if (deadline == null) return 4; // No deadline
        if (deadline.isBefore(now)) return 1; // Overdue
        if (deadline.isBefore(now.add(const Duration(hours: 24)))) return 2;
        return 3; // Future
      }

      final categoryA = getDeadlineCategory(a.deadline);
      final categoryB = getDeadlineCategory(b.deadline);

      if (categoryA != categoryB) {
        return categoryA.compareTo(categoryB);
      }

      if (a.deadline != null && b.deadline != null) {
        return a.deadline!.compareTo(b.deadline!);
      }

      return b.createdAt.compareTo(a.createdAt);
    });

    return tasksCopy;
  }

  String _getFullDeadlineText(DateTime deadline) {
    return TimeFormatter.formatFriendlyDateTime(deadline);
  }

  Color _getDeadlineColor(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return calendarDangerColor;
    } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
      return calendarWarningColor;
    }
    return calendarPrimaryColor;
  }

  Color _getDeadlineBackgroundColor(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return calendarDangerColor.withOpacity(0.1);
    } else if (deadline.isBefore(now.add(const Duration(days: 1)))) {
      return calendarWarningColor.withOpacity(0.1);
    }
    return calendarPrimaryColor.withOpacity(0.08);
  }

  TaskPriority _getPriority() {
    if (_isImportant && _isUrgent) {
      return TaskPriority.critical;
    } else if (_isImportant) {
      return TaskPriority.important;
    } else if (_isUrgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  void _addTask() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final priority = _getPriority();
    final hasLocation = _locationController.text.trim().isNotEmpty;
    final hasSchedule = _scheduleEnabled &&
        _advancedStartTime != null &&
        _advancedEndTime != null;
    final hasRecurrence =
        _advancedRecurrenceFrequency != RecurrenceFrequency.none;

    if (hasSchedule &&
        (_advancedStartTime == null || _advancedEndTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose start and end times.')),
      );
      return;
    }

    if (!hasLocation && !hasSchedule && !hasRecurrence) {
      context.read<BaseCalendarBloc>().add(
            CalendarEvent.quickTaskAdded(
              text: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              deadline: _selectedDeadline,
              priority: priority,
            ),
          );
    } else {
      Duration? duration;
      DateTime? scheduledTime;
      if (hasSchedule) {
        duration = _advancedEndTime!.difference(_advancedStartTime!);
        if (duration.inMinutes < 15) {
          duration = const Duration(minutes: 15);
          _advancedEndTime = _advancedStartTime!.add(duration);
        }
        scheduledTime = _advancedStartTime;
      }

      RecurrenceRule? recurrence;
      if (hasRecurrence) {
        List<int>? weekdays;
        if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekdays) {
          weekdays = const [
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          ];
        } else if (_advancedRecurrenceFrequency == RecurrenceFrequency.weekly) {
          weekdays = _advancedSelectedWeekdays.toList()..sort();
        }

        recurrence = RecurrenceRule(
          frequency: _advancedRecurrenceFrequency,
          interval: _advancedRecurrenceInterval,
          byWeekdays: weekdays,
          until: _advancedRecurrenceUntil,
          count: null,
        );
      }

      context.read<BaseCalendarBloc>().add(
            CalendarEvent.taskAdded(
              title: title,
              description: _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
              scheduledTime: scheduledTime,
              duration: duration,
              deadline: _selectedDeadline,
              location: hasLocation ? _locationController.text.trim() : null,
              priority: priority,
              recurrence: recurrence,
            ),
          );
    }

    _resetForm();
  }

  void _resetForm() {
    _titleController.clear();
    _descriptionController.clear();
    _locationController.clear();
    setState(() {
      _selectedDeadline = null;
      _isImportant = false;
      _isUrgent = false;
      _showAdvancedOptions = false;
      _scheduleEnabled = false;
      _advancedStartTime = null;
      _advancedEndTime = null;
      _advancedRecurrenceFrequency = RecurrenceFrequency.none;
      _advancedRecurrenceInterval = 1;
      _advancedRecurrenceUntil = null;
      _advancedRecurrenceEndAfterAmount = null;
      _advancedRecurrenceEndAfterController.clear();
      _advancedRecurrenceEndAfterUnit = RecurrenceEndUnit.days;
      _advancedSelectedWeekdays = const {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
      };
    });
  }

  ShadPopoverController _popoverControllerFor(String taskId) {
    if (_taskPopoverControllers.containsKey(taskId)) {
      return _taskPopoverControllers[taskId]!;
    }
    final controller = ShadPopoverController();
    controller.addListener(() {
      if (!mounted) return;
      if (!controller.isOpen && _activePopoverTaskId == taskId) {
        setState(() => _activePopoverTaskId = null);
      }
    });
    _taskPopoverControllers[taskId] = controller;
    return controller;
  }

  void _toggleTaskPopover(String taskId) {
    final controller = _popoverControllerFor(taskId);
    if (controller.isOpen) {
      _closeTaskPopover(taskId);
    } else {
      _openTaskPopover(taskId);
    }
  }

  void _openTaskPopover(String taskId) {
    final controller = _popoverControllerFor(taskId);
    if (_activePopoverTaskId != null && _activePopoverTaskId != taskId) {
      final activeController = _taskPopoverControllers[_activePopoverTaskId!];
      activeController?.hide();
    }
    controller.show();
    if (_activePopoverTaskId != taskId) {
      setState(() => _activePopoverTaskId = taskId);
    }
  }

  void _closeTaskPopover([String? taskId]) {
    final id = taskId ?? _activePopoverTaskId;
    if (id == null) {
      return;
    }
    final controller = _taskPopoverControllers[id];
    controller?.hide();
    if (_activePopoverTaskId == id && mounted) {
      setState(() => _activePopoverTaskId = null);
    }
  }
}
