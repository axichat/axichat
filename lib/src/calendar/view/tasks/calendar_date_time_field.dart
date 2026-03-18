// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/task/time_formatter.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';

typedef CalendarDateTimeChanged = void Function(DateTime? value);

const double _deadlinePickerOverlayWidth = 320.0;
const double _deadlinePickerDropdownMinWidth = 320.0;

class CalendarDateTimeField extends StatefulWidget {
  const CalendarDateTimeField({
    super.key,
    required this.value,
    required this.onChanged,
    this.placeholder = '',
    this.showStatusColors = true,
    this.showTimeSelectors = true,
    this.overlayWidth = _deadlinePickerOverlayWidth,
    this.minDate,
    this.maxDate,
    this.enabled = true,
  });

  final DateTime? value;
  final CalendarDateTimeChanged onChanged;
  final String placeholder;
  final bool showStatusColors;
  final bool showTimeSelectors;
  final double overlayWidth;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool enabled;

  @override
  State<CalendarDateTimeField> createState() => _CalendarDateTimeFieldState();
}

class _CalendarDateTimeFieldState extends State<CalendarDateTimeField>
    with AxiSurfaceRegistration<CalendarDateTimeField> {
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
  static const _minuteValues = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55];
  static const double _timePickerDesiredHeight = 660.0;
  static const double _datePickerExpandedHeight = 428.0;

  final GlobalKey _dropdownKey = GlobalKey();

  final OverlayPortalController _portalController = OverlayPortalController();
  bool _isOpen = false;
  bool _isBottomSheetOpen = false;
  Object? _tapRegionGroupId;

  DateTime? _currentValue;
  DateTime? _initialValue;
  late DateTime _visibleMonth;
  DateTime? _minDate;
  DateTime? _maxDate;

  @override
  bool get isAxiSurfaceOpen => _isOpen;

  @override
  VoidCallback? get onAxiSurfaceDismiss => _hideOverlay;

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
    _ensureVisibleMonthInRange();
  }

  @override
  void didUpdateWidget(covariant CalendarDateTimeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final base = widget.value ?? DateTime.now();
      _currentValue = widget.value;
      _visibleMonth = _monthStart(base);
    }
    if (widget.minDate != oldWidget.minDate) {
      _minDate = _normalizeMinDate(widget.minDate);
    }
    if (widget.maxDate != oldWidget.maxDate) {
      _maxDate = _normalizeMaxDate(widget.maxDate);
    }
    _ensureVisibleMonthInRange();
    if (!widget.enabled && _isOpen) {
      _hideOverlay();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheTapRegionGroup();
    syncAxiSurfaceRegistration(notify: false);
  }

  void _cacheTapRegionGroup() {
    final renderTapRegion = context
        .findAncestorRenderObjectOfType<RenderTapRegion>();
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
    super.dispose();
  }

  void _markOverlayNeedsBuild() {
    if (!_isOpen) return;
    setState(() {});
  }

  void _toggleOverlay(BuildContext context) {
    if (!widget.enabled) {
      return;
    }
    if (_shouldUseSheetMenus(context)) {
      if (_isOpen) {
        _hideOverlay();
      }
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
    syncAxiSurfaceRegistration();
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
      final BuildContext modalContext = context.calendarModalContext;
      await showAdaptiveBottomSheet<void>(
        context: modalContext,
        isScrollControlled: true,
        showCloseButton: true,
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
                closeSheet();
              }

              void handleClear() {
                setSheetState(() => _currentValue = null);
                widget.onChanged(null);
                closeSheet();
              }

              final previousMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month - 1,
                1,
              );
              final nextMonth = DateTime(
                _visibleMonth.year,
                _visibleMonth.month + 1,
                1,
              );
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
                  final spacing = context.spacing;
                  final EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
                    spacing.m,
                    spacing.xxs,
                    spacing.m,
                    spacing.m,
                  );
                  return Padding(
                    padding: sheetPadding,
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
    syncAxiSurfaceRegistration();
  }

  _OverlayGeometry _computeGeometry({
    required BuildContext context,
    required Rect anchorRect,
    required Size overlaySize,
  }) {
    final spacing = context.spacing;
    final double margin = spacing.m;
    final dropdownWidth = widget.overlayWidth;
    final double gap = widget.showTimeSelectors ? spacing.s : spacing.xs;
    final desiredHeight = widget.showTimeSelectors
        ? _timePickerDesiredHeight
        : _datePickerExpandedHeight;

    final availableBelow = overlaySize.height - anchorRect.bottom - margin;
    final availableAbove = anchorRect.top - margin;

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
    final double maxLeft = math.max(
      margin,
      overlaySize.width - dropdownWidth - margin,
    );
    final double left = anchorRect.left.clamp(margin, maxLeft);

    return _OverlayGeometry(
      left: left,
      top: placeBelow ? anchorRect.bottom + gap : null,
      bottom: placeBelow ? null : overlaySize.height - anchorRect.top + gap,
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
  }

  void _clearDeadline() {
    setState(() => _currentValue = null);
    widget.onChanged(null);
    _markOverlayNeedsBuild();
    _hideOverlay();
  }

  void _handleCancel() {
    final DateTime? target = _initialValue;
    setState(() => _currentValue = target);
    if (!_sameMoment(widget.value, target)) {
      widget.onChanged(target);
    }
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
    final bool enabled = widget.enabled;
    final String placeholder = widget.placeholder.isEmpty
        ? context.l10n.calendarDeadlinePlaceholder
        : widget.placeholder;
    final borderColor = _borderColor(widget.value);
    final backgroundColor = _backgroundColor(widget.value);
    final iconColor = _iconColor(widget.value);
    final DateTime? value = widget.value;
    final String? displayDate = value != null
        ? (widget.showTimeSelectors
              ? TimeFormatter.formatFriendlyDateTime(context.l10n, value)
              : TimeFormatter.formatFriendlyDate(value))
        : null;
    final String? statusLabel = value != null ? _deadlineLabel(value) : null;
    final bool showStatusLabel =
        value != null &&
        widget.showStatusColors &&
        (widget.showTimeSelectors || statusLabel != displayDate);

    final BorderSide baseBorder = context.borderSide;
    final RoundedSuperellipseBorder decoratedShape = RoundedSuperellipseBorder(
      borderRadius: context.radius,
      side: BorderSide(color: borderColor, width: baseBorder.width),
    );
    final double iconSize = context.sizing.iconButtonIconSize;
    final spacing = context.spacing;
    final trigger = AxiTapBounce(
      enabled: enabled,
      child: ShadFocusable(
        canRequestFocus: enabled,
        builder: (context, _, _) {
          return Material(
            type: MaterialType.transparency,
            shape: decoratedShape,
            clipBehavior: Clip.antiAlias,
            child: ShadGestureDetector(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onTap: enabled ? () => _toggleOverlay(context) : null,
              child: AnimatedContainer(
                duration: calendarSlotHoverAnimationDuration,
                padding: EdgeInsets.symmetric(
                  horizontal: spacing.m,
                  vertical: spacing.s,
                ),
                decoration: ShapeDecoration(
                  color: backgroundColor,
                  shape: decoratedShape,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: iconSize,
                      color: iconColor,
                    ),
                    SizedBox(width: spacing.m),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _DeadlineFieldContent(
                          placeholder: placeholder,
                          valueText: displayDate,
                          statusLabel: statusLabel,
                          showStatusLabel: showStatusLabel,
                          iconColor: iconColor,
                        ),
                      ),
                    ),
                    SizedBox(width: spacing.s),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      size: iconSize,
                      color: calendarTimeLabelColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    final Widget child = OverlayPortal.overlayChildLayoutBuilder(
      controller: _portalController,
      overlayChildBuilder: (overlayContext, info) {
        if (!_isOpen) return const SizedBox.shrink();
        final Rect anchorRect = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final geometry = _computeGeometry(
          context: overlayContext,
          anchorRect: anchorRect,
          overlaySize: info.overlaySize,
        );
        final previousMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month - 1,
          1,
        );
        final nextMonth = DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
          1,
        );
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
            Positioned(
              left: geometry.left,
              top: geometry.top,
              bottom: geometry.bottom,
              width: widget.overlayWidth,
              child: InBoundsFadeScale(
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
            ),
          ],
        );
      },
      child: trigger,
    );
    if (AxiSurfaceScope.maybeControllerOf(context) != null) {
      return child;
    }
    final canPop = !_isOpen;
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || canPop) {
          return;
        }
        _hideOverlay();
      },
      child: child,
    );
  }

  String _deadlineLabel(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDate = DateTime(date.year, date.month, date.day);

    if (deadlineDate == today) {
      return context.l10n.calendarDeadlineDueToday;
    }
    if (deadlineDate == today.add(const Duration(days: 1))) {
      return context.l10n.calendarDeadlineDueTomorrow;
    }
    return TimeFormatter.formatFriendlyDate(deadlineDate);
  }

  String _monthLabel(DateTime date) {
    return DateFormat.yMMMM().format(date);
  }

  int _roundToFive(int minute) {
    final rounded = (minute / 5).round() * 5;
    return rounded == 60 ? 0 : rounded;
  }
}

List<String> _weekdayLabels(BuildContext context) {
  final localizations = MaterialLocalizations.of(context);
  final List<String> weekdays = localizations.narrowWeekdays;
  final int startIndex = localizations.firstDayOfWeekIndex;
  return List<String>.generate(
    weekdays.length,
    (index) => weekdays[(index + startIndex) % weekdays.length],
    growable: false,
  );
}

class _OverlayGeometry {
  const _OverlayGeometry({
    required this.left,
    required this.top,
    required this.bottom,
    required this.maxHeight,
  });

  final double left;
  final double? top;
  final double? bottom;
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
      anchored = TapRegion(groupId: groupId, child: anchored);
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
          minWidth: math.max(
            minWidth,
            (context.sizing.buttonHeightRegular * 7) + context.spacing.xl,
          ),
        ),
        child: Material(
          borderRadius: BorderRadius.circular(context.radii.container),
          color: calendarContainerColor,
          elevation: calendarZoomControlsElevation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.container),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final desiredHeight = showTimeSelectors
                    ? _CalendarDateTimeFieldState._timePickerDesiredHeight
                    : _CalendarDateTimeFieldState._datePickerExpandedHeight;
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
                            children: [calendarGrid, timeSelectors],
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
      top: false,
      bottom: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double desiredHeight = showTimeSelectors
                ? _CalendarDateTimeFieldState._timePickerDesiredHeight
                : _CalendarDateTimeFieldState._datePickerExpandedHeight;
            final bool needsScroll = constraints.maxHeight < desiredHeight;

            if (!needsScroll) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: showTimeSelectors
                    ? [monthHeader, calendarGrid, timeSelectors, actions]
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
                        children: [calendarGrid, timeSelectors],
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
          style: context.textTheme.small.copyWith(color: calendarTitleColor),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            statusLabel ?? value,
            style: context.textTheme.label.strong.copyWith(
              color: iconColor,
              letterSpacing: 0.2,
            ),
          ),
          SizedBox(height: context.spacing.xxs),
          Text(
            value,
            style: context.textTheme.small.copyWith(color: calendarTitleColor),
          ),
        ],
      );
    }

    return Text(
      placeholder,
      style: context.textTheme.small.copyWith(color: calendarTimeLabelColor),
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
    final spacing = context.spacing;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: spacing.s, vertical: spacing.s),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: calendarBorderColor,
            width: context.borderSide.width,
          ),
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
                style: context.textTheme.small.strong.copyWith(
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
    final double buttonSize = context.sizing.buttonHeightRegular;

    return AxiIconButton.outline(
      iconData: icon,
      onPressed: onPressed,
      iconSize: context.sizing.iconButtonIconSize,
      buttonSize: buttonSize,
      tapTargetSize: context.sizing.iconButtonTapTarget,
      color: iconColor,
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
    final spacing = context.spacing;

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
      padding: EdgeInsets.all(spacing.s),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : (context.sizing.buttonHeightRegular * 7) + (spacing.xs * 6);
          final double computedCellSize = ((maxWidth - (spacing.xs * 6)) / 7)
              .clamp(0.0, double.infinity);
          final double cellSize = math.min(
            context.sizing.buttonHeightRegular,
            computedCellSize,
          );
          final weekdayLabels = _weekdayLabels(context);
          final List<Widget> weekdayRow = <Widget>[];
          for (var i = 0; i < weekdayLabels.length; i++) {
            weekdayRow.add(
              SizedBox(
                width: cellSize,
                child: Center(
                  child: Text(
                    weekdayLabels[i],
                    style: context.textTheme.labelSm.strong.copyWith(
                      color: calendarTimeLabelColor,
                    ),
                  ),
                ),
              ),
            );
            if (i != weekdayLabels.length - 1) {
              weekdayRow.add(SizedBox(width: spacing.xs));
            }
          }
          return Column(
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: weekdayRow),
              SizedBox(height: spacing.s),
              Wrap(
                spacing: spacing.xs,
                runSpacing: spacing.xs,
                children: days.map((date) {
                  if (date == null) {
                    return SizedBox(width: cellSize, height: cellSize);
                  }

                  final isSelected =
                      selectedDate != null && _isSameDay(date, selectedDate!);
                  final isDisabled = !isDateWithinBounds(date);

                  return SizedBox(
                    width: cellSize,
                    height: cellSize,
                    child: AxiButton(
                      variant: isSelected
                          ? AxiButtonVariant.primary
                          : AxiButtonVariant.outline,
                      size: AxiButtonSize.sm,
                      widthBehavior: AxiButtonWidth.expand,
                      selected: isSelected,
                      onPressed: isDisabled ? null : () => onDaySelected(date),
                      child: Text('${date.day}'),
                    ),
                  );
                }).toList(),
              ),
            ],
          );
        },
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
    required this.onHourSelected,
    required this.onMinuteSelected,
  });

  final bool showTimeSelectors;
  final int selectedHour;
  final int selectedMinute;
  final List<int> hourValues;
  final List<int> minuteValues;
  final ValueChanged<int> onHourSelected;
  final ValueChanged<int> onMinuteSelected;

  @override
  Widget build(BuildContext context) {
    if (!showTimeSelectors) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.spacing.m,
        vertical: context.spacing.s,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: calendarBorderColor,
            width: context.borderSide.width,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.commonTimeLabel,
            style: context.textTheme.labelSm.strong.copyWith(
              color: calendarSubtitleColor,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: context.spacing.s),
          Row(
            children: [
              Expanded(
                child: _DeadlineTimeDropdown(
                  label: context.l10n.calendarHour,
                  values: hourValues,
                  selectedValue: selectedHour,
                  onSelected: onHourSelected,
                  formatter: (value) => value.toString().padLeft(2, '0'),
                ),
              ),
              SizedBox(width: context.spacing.s),
              Expanded(
                child: _DeadlineTimeDropdown(
                  label: context.l10n.calendarMinute,
                  values: minuteValues,
                  selectedValue: selectedMinute,
                  onSelected: onMinuteSelected,
                  formatter: (value) => value.toString().padLeft(2, '0'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeadlineTimeDropdown extends StatelessWidget {
  const _DeadlineTimeDropdown({
    required this.label,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
    required this.formatter,
  });

  final String label;
  final List<int> values;
  final int selectedValue;
  final ValueChanged<int> onSelected;
  final String Function(int value) formatter;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final TextStyle labelStyle = context.textTheme.labelSm.strong.copyWith(
      color: calendarSubtitleColor,
      letterSpacing: 0.3,
    );
    final ShadDecoration dropdownDecoration = ShadDecoration(
      color: calendarContainerColor,
      border: ShadBorder.all(
        color: calendarBorderColor,
        radius: BorderRadius.circular(calendarBorderRadius),
        width: context.borderSide.width,
      ),
    );
    final EdgeInsets dropdownPadding = EdgeInsets.symmetric(
      horizontal: spacing.m,
      vertical: spacing.s,
    );
    final Icon dropdownIcon = Icon(
      Icons.keyboard_arrow_down_rounded,
      size: context.sizing.menuItemIconSize,
      color: calendarSubtitleColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: labelStyle),
        SizedBox(height: spacing.s),
        AxiSelect<int>(
          initialValue: selectedValue,
          onChanged: (selected) {
            if (selected == null) {
              return;
            }
            onSelected(selected);
          },
          options: values
              .map(
                (value) => ShadOption<int>(
                  value: value,
                  child: Text(formatter(value)),
                ),
              )
              .toList(growable: false),
          selectedOptionBuilder: (context, value) => Text(formatter(value)),
          decoration: dropdownDecoration,
          padding: dropdownPadding,
          trailing: dropdownIcon,
        ),
      ],
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
    final spacing = context.spacing;
    final double verticalPadding = showTimeSelectors ? spacing.m : spacing.s;
    final double horizontalPadding = spacing.s;
    final Widget content = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: calendarBorderColor,
            width: context.borderSide.width,
          ),
        ),
      ),
      child: Row(
        children: [
          AxiButton.outline(
            onPressed: onCancel,
            child: Text(context.l10n.commonCancel),
          ),
          if (hasValue && onClear != null) ...[
            SizedBox(width: spacing.s),
            AxiButton.outline(
              onPressed: onClear,
              child: Text(context.l10n.commonClear),
            ),
          ],
          const Spacer(),
          AxiButton.primary(
            onPressed: onDone,
            child: Text(context.l10n.commonDone),
          ),
        ],
      ),
    );
    if (!includeBottomSafeArea) {
      return content;
    }
    return SafeArea(top: false, left: false, right: false, child: content);
  }
}
