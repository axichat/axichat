// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/utils/responsive_helper.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/utils/time_formatter.dart';
import 'package:axichat/src/calendar/view/widgets/calendar_modal_scope.dart';

typedef DeadlineChanged = void Function(DateTime? value);

const double _deadlinePickerOverlayWidth = 320.0;
const double _deadlinePickerDropdownMinWidth = 320.0;

class DeadlinePickerField extends StatefulWidget {
  const DeadlinePickerField({
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
  final DeadlineChanged onChanged;
  final String placeholder;
  final bool showStatusColors;
  final bool showTimeSelectors;
  final double overlayWidth;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool enabled;

  @override
  State<DeadlinePickerField> createState() => _DeadlinePickerFieldState();
}

class _DeadlinePickerFieldState extends State<DeadlinePickerField> {
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
    _ensureVisibleMonthInRange();
  }

  @override
  void didUpdateWidget(covariant DeadlinePickerField oldWidget) {
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
                onTimeSelected: (time) {
                  handleHourSelected(time.hour);
                  handleMinuteSelected(time.minute);
                },
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
                  const EdgeInsets sheetPadding = EdgeInsets.fromLTRB(
                    calendarGutterLg,
                    calendarInsetSm,
                    calendarGutterLg,
                    calendarGutterLg,
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
    final bool showStatusLabel = value != null &&
        widget.showStatusColors &&
        (widget.showTimeSelectors || statusLabel != displayDate);

    final BorderSide baseBorder = context.borderSide;
    final RoundedSuperellipseBorder decoratedShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: BorderSide(
        color: borderColor,
        width: baseBorder.width,
      ),
    );
    final double iconSize = context.sizing.iconButtonIconSize;
    final trigger = KeyedSubtree(
      key: _triggerKey,
      child: AxiTapBounce(
        enabled: enabled,
        child: ShadFocusable(
          canRequestFocus: enabled,
          builder: (context, _, __) {
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
                  padding: calendarFieldPadding,
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
                      const SizedBox(width: calendarGutterMd),
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
                      const SizedBox(width: calendarGutterSm),
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
      ),
    );

    return OverlayPortal(
      controller: _portalController,
      overlayLocation: OverlayChildLocation.rootOverlay,
      overlayChildBuilder: (overlayContext) {
        if (!_isOpen) return const SizedBox.shrink();
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
          onTimeSelected: (time) {
            _onHourSelected(time.hour);
            _onMinuteSelected(time.minute);
          },
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
              offset: _computeGeometry(overlayContext).offset,
              child: InBoundsFadeScale(
                child: _DeadlineAnchoredDropdown(
                  overlayWidth: widget.overlayWidth,
                  maxHeight: _computeGeometry(overlayContext).maxHeight,
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
      child: CompositedTransformTarget(link: _layerLink, child: trigger),
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
            (context.sizing.buttonHeightRegular * 7) +
                (context.spacing.xs * 6) +
                calendarPaddingLg.horizontal,
          ),
        ),
        child: Material(
          borderRadius: BorderRadius.circular(
            context.radii.container,
          ),
          color: calendarContainerColor,
          elevation: calendarZoomControlsElevation,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              context.radii.container,
            ),
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
                ? _DeadlinePickerFieldState._timePickerDesiredHeight
                : _DeadlinePickerFieldState._datePickerExpandedHeight;
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
          const SizedBox(height: calendarInsetSm),
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
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: calendarGutterMd,
        vertical: calendarGutterSm,
      ),
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
                style: context.textTheme.small.strong
                    .copyWith(color: calendarTitleColor),
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
    final localizations = MaterialLocalizations.of(context);
    final int weekStartsOn = localizations.firstDayOfWeekIndex == 0
        ? DateTime.sunday
        : localizations.firstDayOfWeekIndex;
    final DateTime? normalizedSelected = selectedDate == null
        ? null
        : DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
          );

    return Padding(
      padding: calendarPaddingLg,
      child: ShadCalendar(
        selected: normalizedSelected,
        onChanged: (date) {
          if (date == null || !isDateWithinBounds(date)) {
            return;
          }
          onDaySelected(date);
        },
        showOutsideDays: true,
        fixedWeeks: true,
        initialMonth: visibleMonth,
        weekStartsOn: weekStartsOn,
        formatWeekday: (date) {
          final labels = localizations.narrowWeekdays;
          return labels[date.weekday % DateTime.daysPerWeek];
        },
        selectableDayPredicate: isDateWithinBounds,
        hideNavigation: true,
        headerHeight: 0,
        headerPadding: EdgeInsets.zero,
        captionLayoutGap: 0,
        weekdaysPadding: const EdgeInsets.symmetric(
          horizontal: calendarGutterMd,
          vertical: calendarGutterSm,
        ),
        weekdaysTextStyle: context.textTheme.labelSm.strong.copyWith(
          color: calendarTimeLabelColor,
        ),
        gridMainAxisSpacing: context.spacing.xs,
        gridCrossAxisSpacing: context.spacing.xs,
        dayButtonPadding: const EdgeInsets.symmetric(vertical: calendarInsetLg),
        dayButtonTextStyle: context.textTheme.small.copyWith(
          color: calendarTitleColor,
        ),
        dayButtonOutsideMonthTextStyle: context.textTheme.small.copyWith(
          color: calendarSubtitleColor,
        ),
        selectedDayButtonTextStyle: context.textTheme.small.copyWith(
          color: context.colorScheme.primaryForeground,
        ),
        dayButtonVariant: ShadButtonVariant.ghost,
        dayButtonOutsideMonthVariant: ShadButtonVariant.ghost,
        todayButtonVariant: ShadButtonVariant.outline,
        selectedDayButtonVariant: ShadButtonVariant.primary,
        dayButtonDecoration: ShadDecoration(
          color: calendarContainerColor,
          border: ShadBorder.all(
            color: calendarBorderColor,
            width: context.borderSide.width,
            radius: BorderRadius.circular(context.radii.squircle),
          ),
        ),
        dayButtonOutsideMonthOpacity: 1,
      ),
    );
  }
}

class _DeadlineTimeSelectors extends StatelessWidget {
  const _DeadlineTimeSelectors({
    required this.showTimeSelectors,
    required this.selectedHour,
    required this.selectedMinute,
    required this.onTimeSelected,
  });

  final bool showTimeSelectors;
  final int selectedHour;
  final int selectedMinute;
  final ValueChanged<ShadTimeOfDay> onTimeSelected;

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
          const SizedBox(height: calendarFormGap),
          ShadTimePicker(
            initialValue: ShadTimeOfDay(
              hour: selectedHour,
              minute: selectedMinute,
              second: 0,
            ),
            showSeconds: false,
            showMinutes: true,
            showHours: true,
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            crossAxisAlignment: WrapCrossAlignment.start,
            gap: context.spacing.xs,
            spacing: context.spacing.xs,
            runSpacing: context.spacing.xs,
            hourLabel: Text(context.l10n.calendarHour),
            minuteLabel: Text(context.l10n.calendarMinute),
            hourPlaceholder: const Text('00'),
            minutePlaceholder: const Text('00'),
            labelStyle: context.textTheme.labelSm.strong.copyWith(
              color: calendarSubtitleColor,
              letterSpacing: 0.3,
            ),
            style: context.textTheme.label,
            fieldDecoration: ShadDecoration(
              color: calendarContainerColor,
              border: ShadBorder.all(
                color: calendarBorderColor,
                width: context.borderSide.width,
                radius: BorderRadius.circular(context.radii.squircle),
              ),
            ),
            onChanged: (value) {
              onTimeSelected(value);
            },
          ),
        ],
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
    final verticalPadding =
        showTimeSelectors ? calendarGutterMd : calendarGutterSm;
    final horizontalPadding =
        showTimeSelectors ? calendarGutterMd : calendarGutterLg;
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
            const SizedBox(width: calendarGutterSm),
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
