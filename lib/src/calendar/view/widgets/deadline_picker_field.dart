import 'dart:math' as math;

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
    this.showTimeSelectors = true,
    this.overlayWidth = 320.0,
    this.minDate,
    this.maxDate,
  });

  final DateTime? value;
  final DeadlineChanged onChanged;
  final String placeholder;
  final bool showStatusColors;
  final bool showTimeSelectors;
  final double overlayWidth;
  final DateTime? minDate;
  final DateTime? maxDate;

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
  static const double _timePickerDesiredHeight = 660.0;
  static const double _datePickerExpandedHeight = 428.0;

  final LayerLink _layerLink = LayerLink();
  final GlobalKey _dropdownKey = GlobalKey();
  final GlobalKey _triggerKey = GlobalKey();

  final OverlayPortalController _portalController = OverlayPortalController();
  bool _isOpen = false;
  Object? _tapRegionGroupId;

  DateTime? _currentValue;
  DateTime? _initialValue;
  late DateTime _visibleMonth;
  late ScrollController _hourScrollController;
  late ScrollController _minuteScrollController;
  DateTime? _minDate;
  DateTime? _maxDate;

  DateTime? _normalizeMinDate(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day);
  }

  DateTime? _normalizeMaxDate(DateTime? value) {
    if (value == null) return null;
    return DateTime(value.year, value.month, value.day, 23, 59, 59, 999, 999);
  }

  DateTime _monthStart(DateTime date) => DateTime(date.year, date.month);

  DateTime _monthEnd(DateTime date) => DateTime(date.year, date.month + 1, 0);

  void _ensureVisibleMonthInRange() {
    final minMonth = _minDate != null ? _monthStart(_minDate!) : null;
    final maxMonth = _maxDate != null ? _monthStart(_maxDate!) : null;
    var visible = _monthStart(_visibleMonth);
    if (minMonth != null && visible.isBefore(minMonth)) {
      visible = minMonth;
    }
    if (maxMonth != null && visible.isAfter(maxMonth)) {
      visible = maxMonth;
    }
    _visibleMonth = visible;
  }

  bool _canNavigateToMonth(DateTime month) {
    final monthStart = _monthStart(month);
    final monthEnd = _monthEnd(month);
    if (_minDate != null && monthEnd.isBefore(_minDate!)) {
      return false;
    }
    if (_maxDate != null && monthStart.isAfter(_maxDate!)) {
      return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    _currentValue = widget.value;
    _visibleMonth = _monthStart(base);
    _minDate = _normalizeMinDate(widget.minDate);
    _maxDate = _normalizeMaxDate(widget.maxDate);
    _hourScrollController = ScrollController(
      initialScrollOffset: _hourOffset(base.hour),
    );
    _minuteScrollController = ScrollController(
      initialScrollOffset: _minuteOffset(_roundToFive(base.minute)),
    );
    _ensureVisibleMonthInRange();
  }

  @override
  void didUpdateWidget(covariant DeadlinePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final base = widget.value ?? DateTime.now();
      _currentValue = widget.value;
      _visibleMonth = _monthStart(base);
      _jumpToCurrent(base);
    }
    if (widget.minDate != oldWidget.minDate) {
      _minDate = _normalizeMinDate(widget.minDate);
    }
    if (widget.maxDate != oldWidget.maxDate) {
      _maxDate = _normalizeMaxDate(widget.maxDate);
    }
    _ensureVisibleMonthInRange();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheTapRegionGroup();
  }

  void _cacheTapRegionGroup() {
    final renderTapRegion =
        context.findAncestorRenderObjectOfType<RenderTapRegion>();
    final groupId = renderTapRegion?.groupId;
    if (!identical(_tapRegionGroupId, groupId)) {
      _tapRegionGroupId = groupId;
    }
  }

  @override
  void dispose() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _isOpen = false;
    _hourScrollController.dispose();
    _minuteScrollController.dispose();
    super.dispose();
  }

  void _markOverlayNeedsBuild() {
    if (!_isOpen) return;
    setState(() {});
  }

  void _toggleOverlay(BuildContext context) {
    if (_isOpen) {
      _hideOverlay();
    } else {
      _showOverlay(context);
    }
  }

  void _showOverlay(BuildContext context) {
    if (_isOpen) return;
    _initialValue = _currentValue;
    setState(() {
      _isOpen = true;
    });
    _portalController.show();
  }

  void _hideOverlay() {
    if (!_isOpen) return;
    _portalController.hide();
    setState(() {
      _isOpen = false;
      _initialValue = null;
    });
  }

  _OverlayGeometry _computeGeometry(BuildContext context) {
    final triggerBox =
        _triggerKey.currentContext?.findRenderObject() as RenderBox?;
    final triggerSize = triggerBox?.size ?? Size.zero;
    final triggerOrigin = triggerBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    final screenSize = MediaQuery.of(context).size;
    const margin = 16.0;
    final dropdownWidth = widget.overlayWidth;
    final gap = widget.showTimeSelectors ? 8.0 : 4.0;
    final desiredHeight = widget.showTimeSelectors
        ? _timePickerDesiredHeight
        : _datePickerExpandedHeight;

    final availableBelow =
        screenSize.height - (triggerOrigin.dy + triggerSize.height) - margin;
    final availableAbove = triggerOrigin.dy - margin;

    final normalizedBelow = math.max(0.0, availableBelow);
    final normalizedAbove = math.max(0.0, availableAbove);

    bool placeBelow;
    if (normalizedBelow <= 0 && normalizedAbove <= 0) {
      placeBelow = true;
    } else if (normalizedBelow <= 0) {
      placeBelow = false;
    } else if (normalizedAbove <= 0) {
      placeBelow = true;
    } else {
      placeBelow = normalizedBelow >= normalizedAbove;
    }
    final availableSpace = placeBelow ? normalizedBelow : normalizedAbove;
    final maxHeight = availableSpace > 0
        ? math.min(desiredHeight, availableSpace)
        : desiredHeight;

    final verticalOffset =
        placeBelow ? triggerSize.height + gap : -(maxHeight + gap);

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

    return _OverlayGeometry(
      offset: Offset(horizontalOffset, verticalOffset),
      maxHeight: maxHeight,
    );
  }

  bool _isDateWithinBounds(DateTime date) {
    final candidate = DateTime(date.year, date.month, date.day);
    if (_minDate != null && candidate.isBefore(_minDate!)) {
      return false;
    }
    if (_maxDate != null && candidate.isAfter(_maxDate!)) {
      return false;
    }
    return true;
  }

  void _onDaySelected(DateTime date) {
    if (!_isDateWithinBounds(date)) return;
    final baseTime = _currentValue ?? DateTime.now();
    final newValue = widget.showTimeSelectors
        ? DateTime(
            date.year,
            date.month,
            date.day,
            baseTime.hour,
            baseTime.minute,
          )
        : DateTime(date.year, date.month, date.day);
    setState(() {
      _currentValue = newValue;
      _visibleMonth = _monthStart(date);
    });
    widget.onChanged(newValue);
    _markOverlayNeedsBuild();
  }

  void _onHourSelected(int hour) {
    if (!widget.showTimeSelectors) return;
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
    if (!widget.showTimeSelectors) return;
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
    if (widget.showTimeSelectors) {
      _animateHour(fallback.hour);
      _animateMinute(_roundToFive(fallback.minute));
    }
    _hideOverlay();
  }

  void _handleCancel() {
    final DateTime? target = _initialValue;
    setState(() => _currentValue = target);
    if (!_sameMoment(widget.value, target)) {
      widget.onChanged(target);
    }
    final DateTime reference = target ?? DateTime.now();
    _jumpToCurrent(reference);
    _markOverlayNeedsBuild();
    _hideOverlay();
  }

  bool _sameMoment(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return a == b;
    }
    return a.isAtSameMomentAs(b);
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
    return Color.lerp(Colors.white, border, 0.05) ?? Colors.white;
  }

  Color _iconColor(DateTime? value) {
    if (!widget.showStatusColors) {
      return calendarSubtitleColor;
    }
    if (value == null) {
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

    final trigger = InkWell(
      key: _triggerKey,
      onTap: () => _toggleOverlay(context),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterLg, vertical: 14),
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
              Icons.calendar_today_outlined,
              size: 20,
              color: iconColor,
            ),
            const SizedBox(width: calendarGutterMd),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _buildFieldContent(iconColor),
              ),
            ),
            const SizedBox(width: calendarGutterSm),
            Icon(
              _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: calendarTimeLabelColor,
            ),
          ],
        ),
      ),
    );

    return OverlayPortal(
      controller: _portalController,
      overlayChildBuilder: (overlayContext) {
        if (!_isOpen) return const SizedBox.shrink();
        final geometry = _computeGeometry(overlayContext);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _hideOverlay,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: geometry.offset,
              child: _buildAnchoredDropdown(
                maxHeight: geometry.maxHeight,
              ),
            ),
          ],
        );
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: trigger,
      ),
    );
  }

  Widget _buildAnchoredDropdown({required double maxHeight}) {
    Widget anchored = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: widget.overlayWidth,
        child: _buildDropdownContent(maxHeight),
      ),
    );

    final groupId = _tapRegionGroupId;
    if (groupId != null) {
      anchored = TapRegion(
        groupId: groupId,
        child: anchored,
      );
    }

    return anchored;
  }

  Widget _buildFieldContent(Color iconColor) {
    if (widget.value != null) {
      final displayDate = widget.showTimeSelectors
          ? TimeFormatter.formatFriendlyDateTime(widget.value!)
          : TimeFormatter.formatFriendlyDate(widget.value!);
      final label = _deadlineLabel(widget.value!);
      final showLabel = widget.showStatusColors;

      if (!showLabel || (!widget.showTimeSelectors && label == displayDate)) {
        return Text(
          displayDate,
          style: const TextStyle(
            fontSize: 14,
            color: calendarTitleColor,
            fontWeight: FontWeight.w500,
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: iconColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: calendarInsetSm),
          Text(
            displayDate,
            style: const TextStyle(
              fontSize: 14,
              color: calendarTitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      widget.placeholder,
      style: const TextStyle(
        fontSize: 14,
        color: calendarTimeLabelColor,
        fontWeight: FontWeight.w400,
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
    Widget buildContent(BoxConstraints constraints) {
      final desiredHeight = widget.showTimeSelectors
          ? _timePickerDesiredHeight
          : _datePickerExpandedHeight;
      final needsScroll = constraints.maxHeight < desiredHeight;

      if (widget.showTimeSelectors) {
        final header = _buildMonthHeader();
        final grid = _buildCalendarGrid();
        final timeSelectors = _buildTimeSelectors();
        final actions = _buildActions();

        if (!needsScroll) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              header,
              grid,
              timeSelectors,
              actions,
            ],
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            header,
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    grid,
                    timeSelectors,
                  ],
                ),
              ),
            ),
            actions,
          ],
        );
      }

      final header = _buildMonthHeader();
      final grid = _buildCalendarGrid();
      final actions = _buildActions();

      if (!needsScroll) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [header, grid, actions],
        );
      }

      return Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          header,
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              child: grid,
            ),
          ),
          actions,
        ],
      );
    }

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
            child: LayoutBuilder(builder: (context, constraints) {
              return buildContent(constraints);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterMd, vertical: calendarGutterSm),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          Builder(
            builder: (context) {
              final previousMonth =
                  DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
              final canGoPrev = _canNavigateToMonth(previousMonth);
              final iconColor = canGoPrev
                  ? calendarTitleColor
                  : calendarSubtitleColor.withValues(alpha: 0.4);
              return ShadButton.outline(
                size: ShadButtonSize.sm,
                foregroundColor: iconColor,
                hoverForegroundColor:
                    canGoPrev ? calendarPrimaryColor : iconColor,
                onPressed: canGoPrev
                    ? () {
                        setState(() {
                          _visibleMonth = _monthStart(previousMonth);
                        });
                        _markOverlayNeedsBuild();
                      }
                    : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: calendarGutterSm, vertical: calendarInsetLg),
                child: Icon(
                  Icons.chevron_left,
                  size: 16,
                  color: iconColor,
                ),
              );
            },
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
          Builder(
            builder: (context) {
              final nextMonth =
                  DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
              final canGoNext = _canNavigateToMonth(nextMonth);
              final iconColor = canGoNext
                  ? calendarTitleColor
                  : calendarSubtitleColor.withValues(alpha: 0.4);
              return ShadButton.outline(
                size: ShadButtonSize.sm,
                foregroundColor: iconColor,
                hoverForegroundColor:
                    canGoNext ? calendarPrimaryColor : iconColor,
                onPressed: canGoNext
                    ? () {
                        setState(() {
                          _visibleMonth = _monthStart(nextMonth);
                        });
                        _markOverlayNeedsBuild();
                      }
                    : null,
                padding: const EdgeInsets.symmetric(
                    horizontal: calendarGutterSm, vertical: calendarInsetLg),
                child: Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: iconColor,
                ),
              );
            },
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
      padding: calendarPaddingLg,
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
          const SizedBox(height: calendarGutterSm),
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
              final isDisabled = !_isDateWithinBounds(date);

              return SizedBox(
                width: 36,
                height: 36,
                child: ShadButton.raw(
                  variant: isSelected
                      ? ShadButtonVariant.primary
                      : ShadButtonVariant.outline,
                  size: ShadButtonSize.sm,
                  onPressed: isDisabled ? null : () => _onDaySelected(date),
                  backgroundColor: isSelected
                      ? calendarPrimaryColor
                      : isDisabled
                          ? calendarBorderColor.withValues(alpha: 0.2)
                          : Colors.white,
                  hoverBackgroundColor: isSelected
                      ? calendarPrimaryHoverColor
                      : isDisabled
                          ? calendarBorderColor.withValues(alpha: 0.2)
                          : calendarPrimaryColor.withValues(alpha: 0.12),
                  foregroundColor: isSelected
                      ? Colors.white
                      : isDisabled
                          ? calendarSubtitleColor.withValues(alpha: 0.6)
                          : calendarTitleColor,
                  hoverForegroundColor: isSelected
                      ? Colors.white
                      : isDisabled
                          ? calendarSubtitleColor.withValues(alpha: 0.6)
                          : calendarPrimaryColor,
                  padding: EdgeInsets.zero,
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : isDisabled
                              ? FontWeight.w400
                              : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : isToday
                              ? calendarPrimaryColor
                              : isDisabled
                                  ? calendarSubtitleColor.withValues(alpha: 0.6)
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
    if (!widget.showTimeSelectors) {
      return const SizedBox.shrink();
    }

    final selected = _currentValue ?? DateTime.now();
    final selectedHour = selected.hour;
    final selectedMinute = _roundToFive(selected.minute);

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: calendarGutterMd, vertical: 10),
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
          const SizedBox(height: calendarFormGap),
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
        const SizedBox(height: calendarInsetLg),
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
          borderRadius: BorderRadius.circular(4),
          onTap: onTap,
          hoverColor: calendarPrimaryColor.withValues(alpha: 0.08),
          splashColor: calendarPrimaryColor.withValues(alpha: 0.12),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? calendarPrimaryColor.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
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
    final verticalPadding = widget.showTimeSelectors ? 10.0 : 8.0;
    final horizontalPadding = widget.showTimeSelectors ? 12.0 : 16.0;

    final actionChildren = <Widget>[
      ShadButton.outline(
        size: ShadButtonSize.sm,
        onPressed: _handleCancel,
        child: const Text('Cancel'),
      ),
    ];

    if (_currentValue != null) {
      actionChildren.add(const SizedBox(width: calendarGutterSm));
      actionChildren.add(
        ShadButton.outline(
          size: ShadButtonSize.sm,
          onPressed: _clearDeadline,
          child: const Text('Clear'),
        ),
      );
    }

    actionChildren.add(const Spacer());
    actionChildren.add(
      ShadButton(
        size: ShadButtonSize.sm,
        backgroundColor: calendarPrimaryColor,
        hoverBackgroundColor: calendarPrimaryHoverColor,
        foregroundColor: Colors.white,
        hoverForegroundColor: Colors.white,
        onPressed: _hideOverlay,
        child: const Text('Done'),
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(children: actionChildren),
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

  double _clampedOffset(ScrollController controller, double target) {
    if (!controller.hasClients) return target;
    final maxExtent = controller.position.maxScrollExtent;
    return target.clamp(0.0, maxExtent);
  }

  void _jumpToCurrent(DateTime reference) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hourScrollController.hasClients) {
        final target =
            _clampedOffset(_hourScrollController, _hourOffset(reference.hour));
        if ((_hourScrollController.offset - target).abs() > 0.5) {
          _hourScrollController.jumpTo(target);
        }
      }
      if (_minuteScrollController.hasClients) {
        final target = _clampedOffset(
          _minuteScrollController,
          _minuteOffset(_roundToFive(reference.minute)),
        );
        if ((_minuteScrollController.offset - target).abs() > 0.5) {
          _minuteScrollController.jumpTo(target);
        }
      }
    });
  }
}

class _OverlayGeometry {
  const _OverlayGeometry({required this.offset, required this.maxHeight});

  final Offset offset;
  final double maxHeight;
}
