import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../../utils/time_formatter.dart';

typedef DeadlineChanged = void Function(DateTime? value);

class DeadlinePickerField extends StatefulWidget {
  const DeadlinePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Set deadline (optional)',
    this.showStatusColors = true,
  });

  final DateTime? value;
  final DeadlineChanged onChanged;
  final String placeholder;
  final bool showStatusColors;

  @override
  State<DeadlinePickerField> createState() => _DeadlinePickerFieldState();
}

class _DeadlinePickerFieldState extends State<DeadlinePickerField> {
  static const _hourValues = [
    0,
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10,
    11,
    12,
    13,
    14,
    15,
    16,
    17,
    18,
    19,
    20,
    21,
    22,
    23,
  ];
  static const _minuteValues = [
    0,
    5,
    10,
    15,
    20,
    25,
    30,
    35,
    40,
    45,
    50,
    55,
  ];
  static const double _timeItemHeight = 40;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _dropdownKey = GlobalKey();
  final GlobalKey _triggerKey = GlobalKey();

  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  bool _pointerRouteAttached = false;

  DateTime? _currentValue;
  late DateTime _visibleMonth;
  late ScrollController _hourScrollController;
  late ScrollController _minuteScrollController;

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    _currentValue = widget.value;
    _visibleMonth = base;
    _hourScrollController = ScrollController(
      initialScrollOffset: _hourOffset(base.hour),
    );
    _minuteScrollController = ScrollController(
      initialScrollOffset: _minuteOffset(_roundToFive(base.minute)),
    );
  }

  @override
  void didUpdateWidget(covariant DeadlinePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final base = widget.value ?? DateTime.now();
      _currentValue = widget.value;
      _visibleMonth = base;
      _jumpToCurrent(base);
    }
  }

  @override
  void dispose() {
    _detachPointerRoute();
    _removeOverlay();
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    super.dispose();
  }

  void _attachPointerRoute() {
    if (_pointerRouteAttached) return;
    WidgetsBinding.instance.pointerRouter.addGlobalRoute(_handlePointerEvent);
    _pointerRouteAttached = true;
  }

  void _detachPointerRoute() {
    if (!_pointerRouteAttached) return;
    WidgetsBinding.instance.pointerRouter
        .removeGlobalRoute(_handlePointerEvent);
    _pointerRouteAttached = false;
  }

  void _markOverlayNeedsBuild() {
    _overlayEntry?.markNeedsBuild();
  }

  void _handlePointerEvent(PointerEvent event) {
    if (!_isOpen || event is! PointerDownEvent) return;

    final dropdownBox =
        _dropdownKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;

    bool insideDropdown = false;
    bool insideTrigger = false;

    if (dropdownBox != null) {
      final dropdownOrigin = dropdownBox.localToGlobal(Offset.zero);
      final rect = dropdownOrigin & dropdownBox.size;
      insideDropdown = rect.contains(event.position);
    }

    if (triggerBox != null && !insideDropdown) {
      final triggerOrigin = triggerBox.localToGlobal(Offset.zero);
      final rect = triggerOrigin & triggerBox.size;
      insideTrigger = rect.contains(event.position);
    }

    if (!insideDropdown && !insideTrigger) {
      _hideOverlay();
    }
  }

  void _toggleOverlay() {
    if (_isOpen) {
      _hideOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    if (_isOpen) return;

    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerSize = triggerBox?.size ?? Size.zero;
    final triggerOrigin =
        triggerBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    final screenSize = MediaQuery.of(context).size;
    const dropdownWidth = 320.0;
    const dropdownMaxHeight = 440.0;
    const margin = 16.0;

    final availableBelow = screenSize.height -
        (triggerOrigin.dy + triggerSize.height) -
        margin;
    final availableAbove = triggerOrigin.dy - margin;

    final normalizedBelow = math.max(0.0, availableBelow);
    final normalizedAbove = math.max(0.0, availableAbove);

    double effectiveMaxHeight;
    double verticalOffset;

    if (normalizedBelow >= dropdownMaxHeight) {
      verticalOffset = triggerSize.height + 8;
      effectiveMaxHeight = dropdownMaxHeight;
    } else if (normalizedAbove >= dropdownMaxHeight) {
      verticalOffset = -(dropdownMaxHeight + 8);
      effectiveMaxHeight = dropdownMaxHeight;
    } else if (normalizedBelow >= normalizedAbove) {
      effectiveMaxHeight = math.min(
        dropdownMaxHeight,
        math.max(240.0, normalizedBelow),
      );
      verticalOffset = triggerSize.height + 8;
    } else {
      effectiveMaxHeight = math.min(
        dropdownMaxHeight,
        math.max(240.0, normalizedAbove),
      );
      verticalOffset = -(effectiveMaxHeight + 8);
    }

    double horizontalOffset = 0;
    final rightEdge = triggerOrigin.dx + dropdownWidth;
    final maxRight = screenSize.width - margin;
    if (rightEdge > maxRight) {
      horizontalOffset = maxRight - rightEdge;
    }
    final adjustedLeft = triggerOrigin.dx + horizontalOffset;
    if (adjustedLeft < margin) {
      horizontalOffset += margin - adjustedLeft;
    }

    final overlayEntry = OverlayEntry(
      builder: (context) {
        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(horizontalOffset, verticalOffset),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: dropdownWidth,
              child: _buildDropdownContent(effectiveMaxHeight),
            ),
          ),
        );
      },
    );

    final overlayState = Overlay.of(context, rootOverlay: false);
    (overlayState ?? Overlay.of(context))?.insert(overlayEntry);
    _overlayEntry = overlayEntry;

    _attachPointerRoute();
    setState(() {
      _isOpen = true;
    });
  }

  void _hideOverlay() {
    if (!_isOpen) return;
    _removeOverlay();
    _detachPointerRoute();
    setState(() {
      _isOpen = false;
    });
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _onDaySelected(DateTime date) {
    final baseTime = _currentValue ?? DateTime.now();
    final newValue = DateTime(
      date.year,
      date.month,
      date.day,
      baseTime.hour,
      baseTime.minute,
    );
    setState(() {
      _currentValue = newValue;
      _visibleMonth = date;
    });
    widget.onChanged(newValue);
    _markOverlayNeedsBuild();
  }

  void _onHourSelected(int hour) {
    final value = _currentValue ?? DateTime.now();
    final updated = DateTime(
      value.year,
      value.month,
      value.day,
      hour,
      value.minute,
    );
    setState(() => _currentValue = updated);
    widget.onChanged(updated);
    _markOverlayNeedsBuild();
    _animateHour(hour);
  }

  void _onMinuteSelected(int minute) {
    final value = _currentValue ?? DateTime.now();
    final updated = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      minute,
    );
    setState(() => _currentValue = updated);
    widget.onChanged(updated);
    _markOverlayNeedsBuild();
    _animateMinute(minute);
  }

  void _clearDeadline() {
    final fallback = DateTime.now();
    setState(() => _currentValue = null);
    widget.onChanged(null);
    _markOverlayNeedsBuild();
    _animateHour(fallback.hour);
    _animateMinute(_roundToFive(fallback.minute));
  }

  Color _borderColor(DateTime? value) {
    if (!widget.showStatusColors || value == null) {
      return calendarBorderColor;
    }
    final now = DateTime.now();
    if (value.isBefore(now)) {
      return calendarDangerColor;
    }
    if (value.isBefore(now.add(const Duration(days: 1)))) {
      return calendarWarningColor;
    }
    return calendarPrimaryColor;
  }

  Color _backgroundColor(DateTime? value) {
    if (!widget.showStatusColors || value == null) {
      return Colors.white;
    }
    final border = _borderColor(value);
    return border.withOpacity(0.05);
  }

  Color _iconColor(DateTime? value) {
    if (!widget.showStatusColors || value == null) {
      return calendarTimeLabelColor;
    }
    if (value.isBefore(DateTime.now())) {
      return calendarDangerColor;
    }
    if (value.isBefore(DateTime.now().add(const Duration(days: 1)))) {
      return calendarWarningColor;
    }
    return calendarPrimaryColor;
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _borderColor(widget.value);
    final backgroundColor = _backgroundColor(widget.value);
    final iconColor = _iconColor(widget.value);

    return CompositedTransformTarget(
      link: _layerLink,
      child: InkWell(
        key: _triggerKey,
        onTap: _toggleOverlay,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: borderColor,
              width: widget.value != null ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: backgroundColor,
          ),
          child: Row(
            children: [
              Icon(
                widget.value == null ? Icons.event_outlined : Icons.event,
                size: 20,
                color: iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.value != null) ...[
                      Text(
                        _deadlineLabel(widget.value!),
                        style: TextStyle(
                          fontSize: 12,
                          color: iconColor,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        TimeFormatter.formatFriendlyDateTime(widget.value!),
                        style: const TextStyle(
                          fontSize: 14,
                          color: calendarTitleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ] else
                      Text(
                        widget.placeholder,
                        style: const TextStyle(
                          fontSize: 14,
                          color: calendarTimeLabelColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                _isOpen
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                size: 20,
                color: calendarTimeLabelColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _deadlineLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(date.year, date.month, date.day);

    if (deadlineDate == today) {
      return 'Due Today';
    }
    if (deadlineDate == today.add(const Duration(days: 1))) {
      return 'Due Tomorrow';
    }
    return TimeFormatter.formatFriendlyDate(deadlineDate);
  }

  Widget _buildDropdownContent(double maxHeight) {
    return KeyedSubtree(
      key: _dropdownKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          minWidth: 320,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          elevation: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.zero,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMonthHeader(),
                        _buildCalendarGrid(),
                        _buildTimeSelectors(),
                        _buildActions(),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () {
              setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month - 1,
                );
              });
              _markOverlayNeedsBuild();
            },
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Icon(
              Icons.chevron_left,
              size: 16,
              color: calendarTitleColor,
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                _monthLabel(_visibleMonth),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: calendarTitleColor,
                ),
              ),
            ),
          ),
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: () {
              setState(() {
                _visibleMonth = DateTime(
                  _visibleMonth.year,
                  _visibleMonth.month + 1,
                );
              });
              _markOverlayNeedsBuild();
            },
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: const Icon(
              Icons.chevron_right,
              size: 16,
              color: calendarTitleColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday % 7; // Sunday = 0
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final days = <DateTime?>[];
    for (int i = 0; i < firstWeekday; i++) {
      days.add(null);
    }
    for (int day = 1; day <= daysInMonth; day++) {
      days.add(DateTime(year, month, day));
    }
    while (days.length % 7 != 0) {
      days.add(null);
    }

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S']
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: calendarTimeLabelColor,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: days.map((date) {
              if (date == null) {
                return const SizedBox(width: 36, height: 36);
              }
              final isToday = _isSameDay(date, DateTime.now());
              final isSelected =
                  _currentValue != null && _isSameDay(date, _currentValue!);

              return SizedBox(
                width: 36,
                height: 36,
                child: ShadButton.raw(
                  variant: isSelected
                      ? ShadButtonVariant.primary
                      : ShadButtonVariant.outline,
                  size: ShadButtonSize.sm,
                  onPressed: () => _onDaySelected(date),
                  backgroundColor:
                      isSelected ? calendarPrimaryColor : Colors.white,
                  foregroundColor:
                      isSelected ? Colors.white : calendarTitleColor,
                  padding: EdgeInsets.zero,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? calendarPrimaryColor
                              : calendarTitleColor,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSelectors() {
    final selected = _currentValue ?? DateTime.now();
    final selectedHour = selected.hour;
    final selectedMinute = _roundToFive(selected.minute);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Time',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: calendarSubtitleColor,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 210,
            child: Row(
              children: [
                Expanded(
                  child: _buildTimeColumn(
                    label: 'Hour',
                    values: _hourValues,
                    selectedValue: selectedHour,
                    controller: _hourScrollController,
                    onSelected: _onHourSelected,
                    formatter: (value) => value.toString().padLeft(2, '0'),
                    showRightDivider: true,
                  ),
                ),
                Expanded(
                  child: _buildTimeColumn(
                    label: 'Minute',
                    values: _minuteValues,
                    selectedValue: selectedMinute,
                    controller: _minuteScrollController,
                    onSelected: _onMinuteSelected,
                    formatter: (value) => value.toString().padLeft(2, '0'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn({
    required String label,
    required List<int> values,
    required int selectedValue,
    required ScrollController controller,
    required void Function(int value) onSelected,
    required String Function(int value) formatter,
    bool showRightDivider = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: calendarSubtitleColor,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: DecoratedBox(
            decoration: showRightDivider
                ? const BoxDecoration(
                    border: Border(
                      right: BorderSide(color: calendarBorderColor, width: 1),
                    ),
                  )
                : const BoxDecoration(),
            child: Scrollbar(
              controller: controller,
              child: ListView.separated(
                controller: controller,
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                itemCount: values.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  thickness: 1,
                  color: calendarBorderColor,
                ),
                itemBuilder: (_, index) {
                  final value = values[index];
                  final isSelected = value == selectedValue;
                  return _buildTimeButton(
                    label: formatter(value),
                    selected: isSelected,
                    onTap: () => onSelected(value),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: _timeItemHeight,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.zero,
          onTap: onTap,
          splashColor: calendarPrimaryColor.withOpacity(0.12),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? calendarPrimaryColor.withOpacity(0.12)
                  : Colors.transparent,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? calendarPrimaryColor : calendarTitleColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_currentValue != null)
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: _clearDeadline,
              child: const Text('Clear'),
            )
          else
            const SizedBox(width: 0),
          const Spacer(),
          ShadButton(
            size: ShadButtonSize.sm,
            backgroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryHoverColor,
            foregroundColor: Colors.white,
            hoverForegroundColor: Colors.white,
            onPressed: _hideOverlay,
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _monthLabel(DateTime date) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month]} ${date.year}';
  }

  int _roundToFive(int minute) {
    final rounded = (minute / 5).round() * 5;
    return rounded == 60 ? 0 : rounded;
  }

  double _hourOffset(int hour) {
    final index = _hourValues.indexOf(hour);
    if (index <= 0) return 0;
    return index * (_timeItemHeight + 1);
  }

  double _minuteOffset(int minute) {
    final rounded = _roundToFive(minute);
    final index = _minuteValues.indexOf(rounded);
    if (index <= 0) return 0;
    return index * (_timeItemHeight + 1);
  }

  void _animateHour(int hour) {
    if (!_hourScrollController.hasClients) return;
    final target = _hourOffset(hour);
    _hourScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _animateMinute(int minute) {
    if (!_minuteScrollController.hasClients) return;
    final target = _minuteOffset(minute);
    _minuteScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  void _jumpToCurrent(DateTime reference) {
    if (_hourScrollController.hasClients) {
      _hourScrollController.jumpTo(_hourOffset(reference.hour));
    }
    if (_minuteScrollController.hasClients) {
      _minuteScrollController.jumpTo(
        _minuteOffset(_roundToFive(reference.minute)),
      );
    }
  }
}
