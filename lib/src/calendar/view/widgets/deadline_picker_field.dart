import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';

typedef DeadlineChanged = void Function(DateTime? value);

const double _deadlinePickerOverlayWidth = 320.0;
const double _deadlinePickerDropdownMinWidth = 320.0;

class _AttachAwareScrollController extends ScrollController {
  _AttachAwareScrollController({
    required VoidCallback onAttach,
    super.initialScrollOffset = 0,
  }) : _onAttach = onAttach;

  final VoidCallback _onAttach;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    _onAttach();
  }
}

class DeadlinePickerField extends StatefulWidget {
  const DeadlinePickerField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = 'Set deadline (optional)',
    this.showStatusColors = true,
    this.showTimeSelectors = true,
    this.overlayWidth = _deadlinePickerOverlayWidth,
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
  bool _isBottomSheetOpen = false;
  Object? _tapRegionGroupId;

  DateTime? _currentValue;
  DateTime? _initialValue;
  late DateTime _visibleMonth;
  late final ScrollController _hourScrollController;
  late final ScrollController _minuteScrollController;
  DateTime? _pendingTimeJump;
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

  void _updateVisibleMonth(DateTime month) {
    setState(() {
      _visibleMonth = _monthStart(month);
    });
    _markOverlayNeedsBuild();
  }

  @override
  void initState() {
    super.initState();
    final base = widget.value ?? DateTime.now();
    _currentValue = widget.value;
    _visibleMonth = _monthStart(base);
    _minDate = _normalizeMinDate(widget.minDate);
    _maxDate = _normalizeMaxDate(widget.maxDate);
    _hourScrollController = _AttachAwareScrollController(
      initialScrollOffset: _hourOffset(base.hour),
      onAttach: _handleTimeListAttached,
    );
    _minuteScrollController = _AttachAwareScrollController(
      initialScrollOffset: _minuteOffset(_roundToFive(base.minute)),
      onAttach: _handleTimeListAttached,
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
    if (_shouldUseSheetMenus(context)) {
      if (_isBottomSheetOpen) {
        return;
      }
      _showBottomSheet(context);
      return;
    }
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

  bool get _hasMouseInput =>
      RendererBinding.instance.mouseTracker.mouseIsConnected;

  bool _shouldUseSheetMenus(BuildContext context) {
    return ResponsiveHelper.isCompact(context) || !_hasMouseInput;
  }

  Future<void> _showBottomSheet(BuildContext context) async {
    if (!mounted) {
      return;
    }
    _initialValue = _currentValue;
    setState(() => _isBottomSheetOpen = true);

    try {
      await showAdaptiveBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        surfacePadding: EdgeInsets.zero,
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final MediaQueryData hostMediaQuery = MediaQuery.of(sheetContext);
              final double desiredHeight = widget.showTimeSelectors
                  ? _timePickerDesiredHeight
                  : _datePickerExpandedHeight;

              void closeSheet() => Navigator.of(sheetContext).maybePop();

              void updateVisibleMonth(DateTime month) {
                setSheetState(() {
                  _visibleMonth = _monthStart(month);
                  _ensureVisibleMonthInRange();
                });
              }

              void handleDaySelected(DateTime date) {
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
                setSheetState(() {
                  _currentValue = newValue;
                  _visibleMonth = _monthStart(date);
                });
                widget.onChanged(newValue);
              }

              void handleHourSelected(int hour) {
                if (!widget.showTimeSelectors) return;
                final value = _currentValue ?? DateTime.now();
                final updated = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  hour,
                  value.minute,
                );
                setSheetState(() => _currentValue = updated);
                widget.onChanged(updated);
                _animateHour(hour);
              }

              void handleMinuteSelected(int minute) {
                if (!widget.showTimeSelectors) return;
                final value = _currentValue ?? DateTime.now();
                final updated = DateTime(
                  value.year,
                  value.month,
                  value.day,
                  value.hour,
                  minute,
                );
                setSheetState(() => _currentValue = updated);
                widget.onChanged(updated);
                _animateMinute(minute);
              }

              void handleCancel() {
                final DateTime? target = _initialValue;
                setSheetState(() {
                  _currentValue = target;
                  _visibleMonth = _monthStart(target ?? DateTime.now());
                  _ensureVisibleMonthInRange();
                });
                if (!_sameMoment(widget.value, target)) {
                  widget.onChanged(target);
                }
                final DateTime reference = target ?? DateTime.now();
                _jumpToCurrent(reference);
                closeSheet();
              }

              void handleClear() {
                final fallback = DateTime.now();
                setSheetState(() => _currentValue = null);
                widget.onChanged(null);
                if (widget.showTimeSelectors) {
                  _animateHour(fallback.hour);
                  _animateMinute(_roundToFive(fallback.minute));
                }
                closeSheet();
              }

              final previousMonth =
                  DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
              final nextMonth =
                  DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
              final VoidCallback? handlePrevious =
                  _canNavigateToMonth(previousMonth)
                      ? () => updateVisibleMonth(previousMonth)
                      : null;
              final VoidCallback? handleNext = _canNavigateToMonth(nextMonth)
                  ? () => updateVisibleMonth(nextMonth)
                  : null;

              final header = _DeadlineMonthHeader(
                label: _monthLabel(_visibleMonth),
                onPrevious: handlePrevious,
                onNext: handleNext,
              );
              final calendarGrid = _DeadlineCalendarGrid(
                visibleMonth: _visibleMonth,
                selectedDate: _currentValue,
                isDateWithinBounds: _isDateWithinBounds,
                onDaySelected: handleDaySelected,
              );
              final DateTime selectedTime = _currentValue ?? DateTime.now();
              final timeSelectors = _DeadlineTimeSelectors(
                showTimeSelectors: widget.showTimeSelectors,
                selectedHour: selectedTime.hour,
                selectedMinute: _roundToFive(selectedTime.minute),
                hourValues: _hourValues,
                minuteValues: _minuteValues,
                hourController: _hourScrollController,
                minuteController: _minuteScrollController,
                onHourSelected: handleHourSelected,
                onMinuteSelected: handleMinuteSelected,
              );
              final actions = _DeadlinePickerActions(
                showTimeSelectors: widget.showTimeSelectors,
                hasValue: _currentValue != null,
                onCancel: handleCancel,
                onClear: _currentValue != null ? handleClear : null,
                onDone: closeSheet,
                includeBottomSafeArea: true,
              );

              return LayoutBuilder(
                builder: (context, constraints) {
                  final double availableHeight = constraints.maxHeight.isFinite
                      ? constraints.maxHeight
                      : hostMediaQuery.size.height;
                  final double maxHeight =
                      availableHeight.isFinite && availableHeight > 0
                          ? math.min(desiredHeight, availableHeight)
                          : desiredHeight;
                  return Padding(
                    padding: const EdgeInsets.all(calendarGutterLg),
                    child: _DeadlineSheetContent(
                      maxHeight: maxHeight,
                      showTimeSelectors: widget.showTimeSelectors,
                      monthHeader: header,
                      calendarGrid: calendarGrid,
                      timeSelectors: timeSelectors,
                      actions: actions,
                    ),
                  );
                },
              );
            },
          );
        },
      );
    } finally {
      if (!mounted) {
        _isBottomSheetOpen = false;
        _initialValue = null;
      } else {
        setState(() {
          _isBottomSheetOpen = false;
          _initialValue = null;
        });
      }
    }
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
    const double statusTintMix = 0.05;
    final base = calendarContainerColor;
    if (!widget.showStatusColors || value == null) {
      return base;
    }
    final border = _borderColor(value);
    return Color.lerp(base, border, statusTintMix) ?? base;
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
    final DateTime? value = widget.value;
    final String? displayDate = value != null
        ? (widget.showTimeSelectors
            ? TimeFormatter.formatFriendlyDateTime(value)
            : TimeFormatter.formatFriendlyDate(value))
        : null;
    final String? statusLabel = value != null ? _deadlineLabel(value) : null;
    final bool showStatusLabel = value != null &&
        widget.showStatusColors &&
        (widget.showTimeSelectors || statusLabel != displayDate);

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
                child: _DeadlineFieldContent(
                  placeholder: widget.placeholder,
                  valueText: displayDate,
                  statusLabel: statusLabel,
                  showStatusLabel: showStatusLabel,
                  iconColor: iconColor,
                ),
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
        final previousMonth =
            DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
        final nextMonth =
            DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
        final VoidCallback? handlePrevious = _canNavigateToMonth(previousMonth)
            ? () => _updateVisibleMonth(previousMonth)
            : null;
        final VoidCallback? handleNext = _canNavigateToMonth(nextMonth)
            ? () => _updateVisibleMonth(nextMonth)
            : null;
        final header = _DeadlineMonthHeader(
          label: _monthLabel(_visibleMonth),
          onPrevious: handlePrevious,
          onNext: handleNext,
        );
        final calendarGrid = _DeadlineCalendarGrid(
          visibleMonth: _visibleMonth,
          selectedDate: _currentValue,
          isDateWithinBounds: _isDateWithinBounds,
          onDaySelected: _onDaySelected,
        );
        final DateTime selectedTime = _currentValue ?? DateTime.now();
        final timeSelectors = _DeadlineTimeSelectors(
          showTimeSelectors: widget.showTimeSelectors,
          selectedHour: selectedTime.hour,
          selectedMinute: _roundToFive(selectedTime.minute),
          hourValues: _hourValues,
          minuteValues: _minuteValues,
          hourController: _hourScrollController,
          minuteController: _minuteScrollController,
          onHourSelected: _onHourSelected,
          onMinuteSelected: _onMinuteSelected,
        );
        final actions = _DeadlinePickerActions(
          showTimeSelectors: widget.showTimeSelectors,
          hasValue: _currentValue != null,
          onCancel: _handleCancel,
          onClear: _currentValue != null ? _clearDeadline : null,
          onDone: _hideOverlay,
        );
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
              child: _DeadlineAnchoredDropdown(
                overlayWidth: widget.overlayWidth,
                maxHeight: geometry.maxHeight,
                tapRegionGroupId: _tapRegionGroupId,
                dropdownKey: _dropdownKey,
                showTimeSelectors: widget.showTimeSelectors,
                monthHeader: header,
                calendarGrid: calendarGrid,
                timeSelectors: timeSelectors,
                actions: actions,
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
    if (_applyTimeJump(reference)) {
      _pendingTimeJump = null;
    } else {
      _pendingTimeJump = reference;
    }
  }

  void _handleTimeListAttached() {
    if (_pendingTimeJump == null) {
      return;
    }
    if (_applyTimeJump(_pendingTimeJump!)) {
      _pendingTimeJump = null;
    }
  }

  bool _applyTimeJump(DateTime reference) {
    if (!_hourScrollController.hasClients ||
        !_minuteScrollController.hasClients) {
      return false;
    }
    final double hourTarget =
        _clampedOffset(_hourScrollController, _hourOffset(reference.hour));
    if ((_hourScrollController.offset - hourTarget).abs() > 0.5) {
      _hourScrollController.jumpTo(hourTarget);
    }

    final double minuteTarget = _clampedOffset(
      _minuteScrollController,
      _minuteOffset(_roundToFive(reference.minute)),
    );
    if ((_minuteScrollController.offset - minuteTarget).abs() > 0.5) {
      _minuteScrollController.jumpTo(minuteTarget);
    }
    return true;
  }
}

class _OverlayGeometry {
  const _OverlayGeometry({required this.offset, required this.maxHeight});

  final Offset offset;
  final double maxHeight;
}

class _DeadlineAnchoredDropdown extends StatelessWidget {
  const _DeadlineAnchoredDropdown({
    required this.overlayWidth,
    required this.maxHeight,
    required this.tapRegionGroupId,
    required this.dropdownKey,
    required this.showTimeSelectors,
    required this.monthHeader,
    required this.calendarGrid,
    required this.timeSelectors,
    required this.actions,
  });

  final double overlayWidth;
  final double maxHeight;
  final Object? tapRegionGroupId;
  final GlobalKey dropdownKey;
  final bool showTimeSelectors;
  final Widget monthHeader;
  final Widget calendarGrid;
  final Widget timeSelectors;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    Widget anchored = Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: overlayWidth,
        child: _DeadlineDropdownSurface(
          maxHeight: maxHeight,
          dropdownKey: dropdownKey,
          minWidth: _deadlinePickerDropdownMinWidth,
          showTimeSelectors: showTimeSelectors,
          monthHeader: monthHeader,
          calendarGrid: calendarGrid,
          timeSelectors: timeSelectors,
          actions: actions,
        ),
      ),
    );

    final groupId = tapRegionGroupId;
    if (groupId != null) {
      anchored = TapRegion(
        groupId: groupId,
        child: anchored,
      );
    }

    return anchored;
  }
}

class _DeadlineDropdownSurface extends StatelessWidget {
  const _DeadlineDropdownSurface({
    required this.maxHeight,
    required this.dropdownKey,
    required this.minWidth,
    required this.showTimeSelectors,
    required this.monthHeader,
    required this.calendarGrid,
    required this.timeSelectors,
    required this.actions,
  });

  final double maxHeight;
  final GlobalKey dropdownKey;
  final double minWidth;
  final bool showTimeSelectors;
  final Widget monthHeader;
  final Widget calendarGrid;
  final Widget timeSelectors;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: dropdownKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxHeight,
          minWidth: minWidth,
        ),
        child: Material(
          borderRadius: BorderRadius.circular(12),
          color: calendarContainerColor,
          elevation: 12,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desiredHeight = showTimeSelectors
                    ? _DeadlinePickerFieldState._timePickerDesiredHeight
                    : _DeadlinePickerFieldState._datePickerExpandedHeight;
                final needsScroll = constraints.maxHeight < desiredHeight;

                if (showTimeSelectors) {
                  if (!needsScroll) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        monthHeader,
                        calendarGrid,
                        timeSelectors,
                        actions,
                      ],
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      monthHeader,
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.zero,
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              calendarGrid,
                              timeSelectors,
                            ],
                          ),
                        ),
                      ),
                      actions,
                    ],
                  );
                }

                if (!needsScroll) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [monthHeader, calendarGrid, actions],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    monthHeader,
                    Expanded(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.zero,
                        physics: const ClampingScrollPhysics(),
                        child: calendarGrid,
                      ),
                    ),
                    actions,
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DeadlineSheetContent extends StatelessWidget {
  const _DeadlineSheetContent({
    required this.maxHeight,
    required this.showTimeSelectors,
    required this.monthHeader,
    required this.calendarGrid,
    required this.timeSelectors,
    required this.actions,
  });

  final double maxHeight;
  final bool showTimeSelectors;
  final Widget monthHeader;
  final Widget calendarGrid;
  final Widget timeSelectors;
  final Widget actions;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double desiredHeight = showTimeSelectors
                ? _DeadlinePickerFieldState._timePickerDesiredHeight
                : _DeadlinePickerFieldState._datePickerExpandedHeight;
            final bool needsScroll = constraints.maxHeight < desiredHeight;

            if (!needsScroll) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: showTimeSelectors
                    ? [
                        monthHeader,
                        calendarGrid,
                        timeSelectors,
                        actions,
                      ]
                    : [monthHeader, calendarGrid, actions],
              );
            }

            if (showTimeSelectors) {
              return Column(
                mainAxisSize: MainAxisSize.max,
                children: [
                  monthHeader,
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      physics: const ClampingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          calendarGrid,
                          timeSelectors,
                        ],
                      ),
                    ),
                  ),
                  actions,
                ],
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                monthHeader,
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.zero,
                    physics: const ClampingScrollPhysics(),
                    child: calendarGrid,
                  ),
                ),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DeadlineFieldContent extends StatelessWidget {
  const _DeadlineFieldContent({
    required this.placeholder,
    required this.valueText,
    required this.statusLabel,
    required this.showStatusLabel,
    required this.iconColor,
  });

  final String placeholder;
  final String? valueText;
  final String? statusLabel;
  final bool showStatusLabel;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final String? value = valueText;
    if (value != null) {
      if (!showStatusLabel) {
        return Text(
          value,
          style: TextStyle(
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
            statusLabel ?? value,
            style: TextStyle(
              fontSize: 12,
              color: iconColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: calendarInsetSm),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: calendarTitleColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Text(
      placeholder,
      style: TextStyle(
        fontSize: 14,
        color: calendarTimeLabelColor,
        fontWeight: FontWeight.w400,
      ),
    );
  }
}

class _DeadlineMonthHeader extends StatelessWidget {
  const _DeadlineMonthHeader({
    required this.label,
    this.onPrevious,
    this.onNext,
  });

  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: calendarGutterSm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          _DeadlineNavigationButton(
            icon: Icons.chevron_left,
            onPressed: onPrevious,
          ),
          Expanded(
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: calendarTitleColor,
                ),
              ),
            ),
          ),
          _DeadlineNavigationButton(
            icon: Icons.chevron_right,
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

class _DeadlineNavigationButton extends StatelessWidget {
  const _DeadlineNavigationButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final iconColor = enabled
        ? calendarTitleColor
        : calendarSubtitleColor.withValues(alpha: 0.4);

    return ShadButton.outline(
      size: ShadButtonSize.sm,
      foregroundColor: iconColor,
      hoverForegroundColor: enabled ? calendarPrimaryColor : iconColor,
      onPressed: onPressed,
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterSm,
        vertical: calendarInsetLg,
      ),
      child: Icon(icon, size: 16, color: iconColor),
    );
  }
}

class _DeadlineCalendarGrid extends StatelessWidget {
  const _DeadlineCalendarGrid({
    required this.visibleMonth,
    required this.selectedDate,
    required this.isDateWithinBounds,
    required this.onDaySelected,
  });

  final DateTime visibleMonth;
  final DateTime? selectedDate;
  final bool Function(DateTime date) isDateWithinBounds;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final year = visibleMonth.year;
    final month = visibleMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final firstWeekday = firstOfMonth.weekday % 7;
    final daysInMonth = DateTime(year, month + 1, 0).day;

    final days = <DateTime?>[];
    for (var i = 0; i < firstWeekday; i++) {
      days.add(null);
    }
    for (var day = 1; day <= daysInMonth; day++) {
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
                        style: TextStyle(
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
                  selectedDate != null && _isSameDay(date, selectedDate!);
              final isDisabled = !isDateWithinBounds(date);

              return SizedBox(
                width: 36,
                height: 36,
                child: ShadButton.raw(
                  variant: isSelected
                      ? ShadButtonVariant.primary
                      : ShadButtonVariant.outline,
                  size: ShadButtonSize.sm,
                  onPressed: isDisabled ? null : () => onDaySelected(date),
                  backgroundColor: isSelected
                      ? calendarPrimaryColor
                      : isDisabled
                          ? calendarBorderColor.withValues(alpha: 0.2)
                          : calendarContainerColor,
                  hoverBackgroundColor: isSelected
                      ? calendarPrimaryHoverColor
                      : isDisabled
                          ? calendarBorderColor.withValues(alpha: 0.2)
                          : calendarPrimaryColor.withValues(alpha: 0.12),
                  foregroundColor: isSelected
                      ? context.colorScheme.primaryForeground
                      : isDisabled
                          ? calendarSubtitleColor.withValues(alpha: 0.6)
                          : calendarTitleColor,
                  hoverForegroundColor: isSelected
                      ? context.colorScheme.primaryForeground
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
                          ? context.colorScheme.primaryForeground
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _DeadlineTimeSelectors extends StatelessWidget {
  const _DeadlineTimeSelectors({
    required this.showTimeSelectors,
    required this.selectedHour,
    required this.selectedMinute,
    required this.hourValues,
    required this.minuteValues,
    required this.hourController,
    required this.minuteController,
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  final bool showTimeSelectors;
  final int selectedHour;
  final int selectedMinute;
  final List<int> hourValues;
  final List<int> minuteValues;
  final ScrollController hourController;
  final ScrollController minuteController;
  final ValueChanged<int> onHourSelected;
  final ValueChanged<int> onMinuteSelected;

  @override
  Widget build(BuildContext context) {
    if (!showTimeSelectors) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
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
                  child: _DeadlineTimeColumn(
                    label: 'Hour',
                    values: hourValues,
                    selectedValue: selectedHour,
                    controller: hourController,
                    onSelected: onHourSelected,
                    formatter: (value) => value.toString().padLeft(2, '0'),
                    showRightDivider: true,
                  ),
                ),
                Expanded(
                  child: _DeadlineTimeColumn(
                    label: 'Minute',
                    values: minuteValues,
                    selectedValue: selectedMinute,
                    controller: minuteController,
                    onSelected: onMinuteSelected,
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
}

class _DeadlineTimeColumn extends StatelessWidget {
  const _DeadlineTimeColumn({
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.controller,
    required this.onSelected,
    required this.formatter,
    this.showRightDivider = false,
  });

  final String label;
  final List<int> values;
  final int selectedValue;
  final ScrollController controller;
  final ValueChanged<int> onSelected;
  final String Function(int value) formatter;
  final bool showRightDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
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
                ? BoxDecoration(
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
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  thickness: 1,
                  color: calendarBorderColor,
                ),
                itemBuilder: (_, index) {
                  final value = values[index];
                  final isSelected = value == selectedValue;
                  return _DeadlineTimeButton(
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
}

class _DeadlineTimeButton extends StatelessWidget {
  const _DeadlineTimeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _DeadlinePickerFieldState._timeItemHeight,
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
}

class _DeadlinePickerActions extends StatelessWidget {
  const _DeadlinePickerActions({
    required this.showTimeSelectors,
    required this.hasValue,
    required this.onCancel,
    this.onClear,
    required this.onDone,
    this.includeBottomSafeArea = false,
  });

  final bool showTimeSelectors;
  final bool hasValue;
  final VoidCallback onCancel;
  final VoidCallback? onClear;
  final VoidCallback onDone;
  final bool includeBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final verticalPadding = showTimeSelectors ? 10.0 : 8.0;
    final horizontalPadding = showTimeSelectors ? 12.0 : 16.0;
    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        children: [
          ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onCancel,
            child: Text(context.l10n.commonCancel),
          ),
          if (hasValue && onClear != null) ...[
            const SizedBox(width: calendarGutterSm),
            ShadButton.outline(
              size: ShadButtonSize.sm,
              onPressed: onClear,
              child: Text(context.l10n.commonClear),
            ),
          ],
          const Spacer(),
          ShadButton(
            size: ShadButtonSize.sm,
            backgroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryHoverColor,
            foregroundColor: colors.primaryForeground,
            hoverForegroundColor: colors.primaryForeground,
            onPressed: onDone,
            child: const Text('Done'),
          ),
        ],
      ),
    );
    if (!includeBottomSafeArea) {
      return content;
    }
    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: content,
    );
  }
}
