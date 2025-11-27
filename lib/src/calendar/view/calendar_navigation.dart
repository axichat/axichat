import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import '../../common/ui/ui.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import 'widgets/task_form_section.dart';

const double _compactDateLabelCollapseWidth = smallScreen;
const double _compactDateLabelMaxWidth = 170;
const double _defaultDateLabelMaxWidth = 320;

class CalendarNavigation extends StatelessWidget {
  const CalendarNavigation({
    super.key,
    required this.state,
    required this.onDateSelected,
    required this.onViewChanged,
    required this.onErrorCleared,
    this.sidebarVisible = true,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.hideCompletedScheduled = false,
    this.onToggleHideCompletedScheduled,
  });

  final CalendarState state;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;
  final VoidCallback onErrorCleared;
  final bool sidebarVisible;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final bool hideCompletedScheduled;
  final ValueChanged<bool>? onToggleHideCompletedScheduled;

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final double basePadding = sidebarVisible ? spec.gridHorizontalPadding : 0;
    final double horizontalPadding = math.max(16, basePadding);
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final CalendarView viewMode = state.viewMode;
    final bool showBackToWeek = !isCompact && viewMode == CalendarView.day;
    final bool hasUndoRedo = onUndo != null || onRedo != null;
    final String unitLabel = _currentUnitLabel(viewMode);
    final List<Widget> navButtons = [
      _navButton(
        context: context,
        label: '← Previous',
        icon: isCompact ? Icons.chevron_left : null,
        tooltip: 'Previous $unitLabel',
        compact: isCompact,
        onPressed: () => _jumpRelative(-1),
      ),
      _navButton(
        context: context,
        label: 'Today',
        icon: null,
        highlighted: _isToday(state.selectedDate),
        tooltip: 'Today',
        compact: isCompact,
        showLabelInCompact: true,
        onPressed: _isToday(state.selectedDate)
            ? null
            : () => onDateSelected(DateTime.now()),
      ),
      _navButton(
        context: context,
        label: 'Next →',
        icon: isCompact ? Icons.chevron_right : null,
        tooltip: 'Next $unitLabel',
        compact: isCompact,
        onPressed: () => _jumpRelative(1),
      ),
    ];
    if (showBackToWeek) {
      navButtons.add(
        _navButton(
          context: context,
          label: 'Back to week',
          onPressed: () => onViewChanged(CalendarView.week),
        ),
      );
    }
    const double verticalPadding = calendarInsetMd;
    final Widget undoRedoGroup = _UndoRedoGroup(
      onUndo: onUndo,
      onRedo: onRedo,
      canUndo: canUndo,
      canRedo: canRedo,
      iconBuilder: _iconControl,
    );
    final colors = context.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double safeMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final double availableWidth =
            (safeMaxWidth - (horizontalPadding * 2)).clamp(
          0.0,
          double.infinity,
        );
        final bool collapseDateText =
            isCompact || availableWidth < _compactDateLabelCollapseWidth;
        final double navSpacing =
            isCompact ? calendarGutterSm : calendarGutterMd;
        final Widget navRow = _NavigationButtonRow(
          navButtons: navButtons,
          spacing: navSpacing,
        );
        final Widget trailingRow = _TrailingControls(
          state: state,
          onDateSelected: onDateSelected,
          collapseDateText: collapseDateText,
          isCompact: isCompact,
          hasUndoRedo: hasUndoRedo,
          undoRedoGroup: undoRedoGroup,
          hideCompletedScheduled: hideCompletedScheduled,
          onToggleHideCompletedScheduled: onToggleHideCompletedScheduled,
        );

        const Border? border = null;
        const List<BoxShadow> navShadows = [];
        final brightness = ShadTheme.of(context).brightness;
        final Color navBackground = brightness == Brightness.dark
            ? colors.card
            : calendarSidebarBackgroundColor;
        return ColoredBox(
          color: navBackground,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              verticalPadding,
              horizontalPadding,
              verticalPadding,
            ),
            decoration: BoxDecoration(
              color: navBackground,
              border: border,
              boxShadow: navShadows,
            ),
            child: DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: 12,
                color: colors.mutedForeground,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: navRow,
                    ),
                  ),
                  SizedBox(width: navSpacing),
                  Flexible(
                    flex: 0,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: trailingRow,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _jumpRelative(int steps) {
    onDateSelected(_shiftedDate(steps));
  }

  DateTime _shiftedDate(int steps) {
    final DateTime base = state.selectedDate;
    switch (state.viewMode) {
      case CalendarView.day:
        return base.add(Duration(days: steps));
      case CalendarView.week:
        return base.add(Duration(days: 7 * steps));
      case CalendarView.month:
        final DateTime candidateMonth =
            DateTime(base.year, base.month + steps, 1);
        final int maxDay = DateTime(
          candidateMonth.year,
          candidateMonth.month + 1,
          0,
        ).day;
        final int clampedDay = base.day.clamp(1, maxDay).toInt();
        return DateTime(
          candidateMonth.year,
          candidateMonth.month,
          clampedDay,
        );
    }
  }

  String _currentUnitLabel(CalendarView viewMode) {
    switch (viewMode) {
      case CalendarView.day:
        return 'day';
      case CalendarView.week:
        return 'week';
      case CalendarView.month:
        return 'month';
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }

  Widget _navButton({
    required BuildContext context,
    required String label,
    required VoidCallback? onPressed,
    bool highlighted = false,
    IconData? icon,
    bool compact = false,
    String? tooltip,
    bool showLabelInCompact = false,
  }) {
    final colors = context.colorScheme;
    final bool useCompactIconOnly = compact && !showLabelInCompact;
    if (useCompactIconOnly) {
      return _compactNavButton(
        context: context,
        icon: icon ?? Icons.help_outline,
        tooltip: tooltip ?? label,
        onPressed: onPressed,
        highlighted: highlighted,
        enabled: onPressed != null,
      );
    }
    final Widget button = highlighted
        ? TaskPrimaryButton(
            label: label,
            onPressed: onPressed,
            isBusy: false,
            icon: icon,
          )
        : TaskSecondaryButton(
            label: label,
            onPressed: onPressed,
            icon: icon,
            foregroundColor: colors.primary,
            hoverForegroundColor: colors.primary,
            hoverBackgroundColor: colors.primary.withValues(alpha: 0.08),
          );
    if (!compact) {
      return _wrapWithCursor(button, onPressed != null);
    }
    return _wrapWithCursor(
      Tooltip(
        message: tooltip ?? label,
        child: SizedBox(
          height: 40,
          child: button,
        ),
      ),
      onPressed != null,
    );
  }

  Widget _wrapWithCursor(Widget child, bool enabled) {
    return MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: child,
    );
  }

  Widget _iconControl({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool compact,
  }) {
    final shortcut =
        icon == Icons.undo_rounded ? 'Ctrl/Cmd+Z' : 'Ctrl/Cmd+Shift+Z';
    final String message = '$tooltip ($shortcut)';
    final bool enabled = onPressed != null;
    if (compact) {
      return _compactNavButton(
        context: context,
        icon: icon,
        tooltip: message,
        onPressed: onPressed,
        highlighted: false,
        enabled: enabled,
      );
    }
    final colors = context.colorScheme;
    Widget control = Tooltip(
      message: message,
      child: TaskSecondaryButton(
        label: tooltip,
        icon: icon,
        onPressed: onPressed,
        foregroundColor: colors.primary,
        hoverForegroundColor: colors.primary,
        hoverBackgroundColor: colors.primary.withValues(alpha: 0.08),
      ),
    );
    if (!enabled) {
      control = Opacity(
        opacity: 0.4,
        child: control,
      );
    }
    return _wrapWithCursor(control, enabled);
  }

  Widget _compactNavButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool highlighted,
    bool enabled = true,
  }) {
    final colors = context.colorScheme;
    final Widget button = highlighted
        ? ShadButton(
            size: ShadButtonSize.sm,
            backgroundColor: colors.primary,
            hoverBackgroundColor: colors.primary.withValues(alpha: 0.85),
            foregroundColor: Colors.white,
            hoverForegroundColor: Colors.white,
            onPressed: onPressed,
            child: Icon(icon, size: 16),
          )
        : ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onPressed,
            foregroundColor: colors.primary,
            hoverForegroundColor: colors.primary,
            hoverBackgroundColor: colors.primary.withValues(alpha: 0.08),
            child: Icon(icon, size: 16),
          );
    Widget control = Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 40,
        child: button,
      ),
    );
    if (!enabled) {
      control = Opacity(
        opacity: 0.4,
        child: control,
      );
    }
    return _wrapWithCursor(control, enabled);
  }
}

typedef _IconControlBuilder = Widget Function({
  required BuildContext context,
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
  required bool compact,
});

class _UndoRedoGroup extends StatelessWidget {
  const _UndoRedoGroup({
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
    required this.iconBuilder,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final _IconControlBuilder iconBuilder;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final controls = <Widget>[];
    if (onUndo != null) {
      controls.add(
        iconBuilder(
          context: context,
          icon: Icons.undo_rounded,
          tooltip: 'Undo',
          onPressed: canUndo ? onUndo : null,
          compact: isCompact,
        ),
      );
    }
    if (onRedo != null) {
      if (controls.isNotEmpty) {
        controls.add(const SizedBox(width: calendarGutterSm));
      }
      controls.add(
        iconBuilder(
          context: context,
          icon: Icons.redo_rounded,
          tooltip: 'Redo',
          onPressed: canRedo ? onRedo : null,
          compact: isCompact,
        ),
      );
    }
    if (controls.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(mainAxisSize: MainAxisSize.min, children: controls);
  }
}

class _NavigationButtonRow extends StatelessWidget {
  const _NavigationButtonRow({
    required this.navButtons,
    required this.spacing,
  });

  final List<Widget> navButtons;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (navButtons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: spacing,
      runSpacing: calendarGutterSm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: navButtons,
    );
  }
}

class _TrailingControls extends StatelessWidget {
  const _TrailingControls({
    required this.state,
    required this.onDateSelected,
    required this.collapseDateText,
    required this.isCompact,
    required this.hasUndoRedo,
    required this.undoRedoGroup,
    required this.hideCompletedScheduled,
    required this.onToggleHideCompletedScheduled,
  });

  final CalendarState state;
  final void Function(DateTime) onDateSelected;
  final bool collapseDateText;
  final bool isCompact;
  final bool hasUndoRedo;
  final Widget undoRedoGroup;
  final bool hideCompletedScheduled;
  final ValueChanged<bool>? onToggleHideCompletedScheduled;

  @override
  Widget build(BuildContext context) {
    final double trailingGap = isCompact ? calendarGutterSm : calendarGutterMd;
    final double maxDateLabelWidth =
        isCompact ? _compactDateLabelMaxWidth : _defaultDateLabelMaxWidth;

    final Widget? hideToggle = onToggleHideCompletedScheduled == null
        ? null
        : ShadSwitch(
            value: hideCompletedScheduled,
            onChanged: onToggleHideCompletedScheduled,
            label: const Text('Hide completed'),
          );

    final trailingChildren = <Widget>[
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDateLabelWidth),
        child: _DateLabel(
          state: state,
          onDateSelected: onDateSelected,
          collapseText: collapseDateText,
        ),
      ),
      if (hideToggle != null) hideToggle,
      if (hasUndoRedo) undoRedoGroup,
    ];

    return Wrap(
      spacing: trailingGap,
      runSpacing: calendarGutterSm,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: trailingChildren,
    );
  }
}

class _DateLabel extends StatefulWidget {
  const _DateLabel({
    required this.state,
    required this.onDateSelected,
    this.collapseText = false,
  });

  final CalendarState state;
  final void Function(DateTime date) onDateSelected;
  final bool collapseText;

  @override
  State<_DateLabel> createState() => _DateLabelState();
}

class _DateLabelState extends State<_DateLabel> {
  final LayerLink _link = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isBottomSheetOpen = false;
  late DateTime _visibleMonth;
  bool get _isPickerOpen => _overlayEntry != null || _isBottomSheetOpen;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
        widget.state.selectedDate.year, widget.state.selectedDate.month);
  }

  @override
  void didUpdateWidget(covariant _DateLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedDate.year != oldWidget.state.selectedDate.year ||
        widget.state.selectedDate.month != oldWidget.state.selectedDate.month) {
      _visibleMonth = DateTime(
          widget.state.selectedDate.year, widget.state.selectedDate.month);
    }
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
    }
  }

  @override
  void dispose() {
    _removeOverlay(requestRebuild: false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.state.viewMode) {
      CalendarView.day => _formatDay(widget.state.selectedDate),
      CalendarView.week =>
        '${_formatDay(widget.state.weekStart)} – ${_formatDay(widget.state.weekEnd)}',
      CalendarView.month =>
        DateFormat.yMMMM().format(widget.state.selectedDate),
    };
    final bool hideText =
        widget.collapseText || MediaQuery.of(context).size.width < 420;
    final bool isOpen = _isPickerOpen;
    final Color iconColor =
        isOpen ? calendarPrimaryColor : calendarSubtitleColor;
    final Color textColor = isOpen ? calendarPrimaryColor : calendarTitleColor;

    return CompositedTransformTarget(
      link: _link,
      child: SizedBox(
        height: 40,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: _toggleOverlay,
            foregroundColor: textColor,
            hoverForegroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: iconColor,
                ),
                if (!hideText) ...[
                  const SizedBox(width: calendarGutterSm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 260),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: calendarInsetLg),
                Icon(
                  isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: 18,
                  color: iconColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }
    if (_isBottomSheetOpen) {
      return;
    }
    _showOverlay();
  }

  void _showOverlay() {
    if (ResponsiveHelper.isCompact(context)) {
      _showBottomSheet();
      return;
    }
    final overlay = Overlay.of(context);

    final renderBox = context.findRenderObject() as RenderBox?;
    final buttonWidth = renderBox?.size.width ?? 0;
    final spec = ResponsiveHelper.spec(context);
    final dropdownWidth = spec.quickAddMaxWidth ?? 340.0;
    final horizontalOffset = buttonWidth - dropdownWidth;
    final buttonHeight = renderBox?.size.height ?? 0;
    final verticalOffset = buttonHeight + spec.contentPadding.vertical / 2;

    final entry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: () => _removeOverlay(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(child: Container()),
              CompositedTransformFollower(
                link: _link,
                offset: Offset(horizontalOffset, verticalOffset),
                showWhenUnlinked: false,
                child: GestureDetector(
                  onTap: () {},
                  behavior: HitTestBehavior.opaque,
                  child: Material(
                    color: Colors.transparent,
                    child: _CalendarDropdown(
                      month: _visibleMonth,
                      selectedWeekStart: widget.state.weekStart,
                      selectedDate: widget.state.selectedDate,
                      onClose: () => _removeOverlay(),
                      onMonthChanged: (month) {
                        setState(() => _visibleMonth = month);
                        _overlayEntry?.markNeedsBuild();
                      },
                      onDateSelected: (date) {
                        widget.onDateSelected(date);
                        _removeOverlay();
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );

    setState(() => _overlayEntry = entry);
    overlay.insert(entry);
  }

  Future<void> _showBottomSheet() async {
    if (!mounted) {
      return;
    }
    setState(() => _isBottomSheetOpen = true);
    await showAdaptiveBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var sheetMonth = _visibleMonth;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final spec = ResponsiveHelper.spec(sheetContext);
            final media = MediaQuery.of(sheetContext);
            final EdgeInsets modalMargin = spec.modalMargin;
            final double topPadding = modalMargin.top > media.viewPadding.top
                ? modalMargin.top
                : media.viewPadding.top;
            final double leftPadding = modalMargin.left > media.viewPadding.left
                ? modalMargin.left
                : media.viewPadding.left;
            final double rightPadding =
                modalMargin.right > media.viewPadding.right
                    ? modalMargin.right
                    : media.viewPadding.right;
            final double safeBottom = media.viewPadding.bottom;
            final double keyboardInset = media.viewInsets.bottom;
            final double bottomInset =
                keyboardInset > safeBottom ? keyboardInset : safeBottom;
            final double fixedBottomPadding =
                math.max(12.0, modalMargin.bottom * 0.6);
            final double bottomPadding = fixedBottomPadding + bottomInset;
            return AnimatedPadding(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                left: leftPadding,
                right: rightPadding,
                top: topPadding,
                bottom: bottomPadding,
              ),
              child: _CalendarDropdown(
                margin: EdgeInsets.zero,
                month: sheetMonth,
                selectedWeekStart: widget.state.weekStart,
                selectedDate: widget.state.selectedDate,
                onClose: () {
                  _handleBottomSheetClosed();
                  Navigator.of(sheetContext).maybePop();
                },
                onMonthChanged: (month) {
                  setSheetState(() => sheetMonth = month);
                  if (mounted) {
                    setState(() => _visibleMonth = month);
                  }
                },
                onDateSelected: (date) {
                  widget.onDateSelected(date);
                  _handleBottomSheetClosed();
                  Navigator.of(sheetContext).maybePop();
                },
              ),
            );
          },
        );
      },
    );
    _handleBottomSheetClosed();
  }

  void _handleBottomSheetClosed() {
    if (!mounted) {
      _isBottomSheetOpen = false;
      return;
    }
    if (_isBottomSheetOpen) {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  void _removeOverlay({bool requestRebuild = true}) {
    final entry = _overlayEntry;
    if (entry == null) {
      return;
    }
    entry.remove();
    if (requestRebuild && mounted) {
      setState(() => _overlayEntry = null);
    } else {
      _overlayEntry = null;
    }
  }

  String _formatDay(DateTime date) => DateFormat.yMMMd().format(date);
}

class _CalendarDropdown extends StatelessWidget {
  const _CalendarDropdown({
    required this.month,
    required this.selectedWeekStart,
    required this.selectedDate,
    required this.onClose,
    required this.onMonthChanged,
    required this.onDateSelected,
    this.margin = const EdgeInsets.only(top: calendarGutterSm),
  });

  final DateTime month;
  final DateTime selectedWeekStart;
  final DateTime selectedDate;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final days = _monthDays(month);
    final now = DateTime.now();
    final bool fillWidth = ResponsiveHelper.isCompact(context);
    final double dropdownWidth =
        spec.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;
    final double width = fillWidth ? double.infinity : dropdownWidth;

    return Container(
      width: width,
      padding: spec.contentPadding,
      margin: margin,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
        boxShadow: calendarMediumShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat.yMMMM().format(month),
                  style: calendarTitleTextStyle,
                ),
              ),
              _navIconButton(
                icon: Icons.chevron_left,
                onPressed: () => onMonthChanged(_addMonths(month, -1)),
              ),
              const SizedBox(width: calendarGutterSm),
              _navIconButton(
                icon: Icons.chevron_right,
                onPressed: () => onMonthChanged(_addMonths(month, 1)),
              ),
            ],
          ),
          const SizedBox(height: calendarGutterMd),
          const _DayHeaders(),
          const SizedBox(height: calendarInsetLg),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: calendarInsetMd,
              crossAxisSpacing: calendarInsetMd,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final isOtherMonth = date.month != month.month;
              final isToday = _isSameDay(date, now);
              final isSelectedWeek = _weekStart(date)
                  .isAtSameMomentAs(_weekStart(selectedWeekStart));
              final isSelectedDay = _isSameDay(date, selectedDate);

              Color textColor = calendarTitleColor;
              Color backgroundColor = Colors.white;
              BorderSide border = BorderSide.none;

              if (isOtherMonth) {
                textColor = calendarSubtitleColor;
              }
              if (isSelectedWeek) {
                backgroundColor = calendarPrimaryColor.withValues(alpha: 0.12);
                border = BorderSide(color: calendarPrimaryColor, width: 1);
              }
              if (isToday && !isSelectedDay) {
                border = BorderSide(color: calendarPrimaryColor, width: 1.5);
              }
              if (isSelectedDay) {
                backgroundColor = calendarPrimaryColor;
                textColor = Colors.white;
                border = BorderSide.none;
              }

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  borderRadius:
                      BorderRadius.circular(calendarBorderRadius / 1.5),
                  mouseCursor: SystemMouseCursors.click,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  splashColor: Colors.transparent,
                  onTap: () => onDateSelected(date),
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius:
                          BorderRadius.circular(calendarBorderRadius / 1.5),
                      border: border == BorderSide.none
                          ? null
                          : Border.fromBorderSide(border),
                    ),
                    alignment: Alignment.center,
                    padding:
                        const EdgeInsets.symmetric(vertical: calendarInsetLg),
                    child: Text(
                      '${date.day}',
                      style: calendarBodyTextStyle.copyWith(
                        fontWeight: isToday ? FontWeight.w600 : FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: calendarGutterMd),
          SizedBox(
            width: double.infinity,
            child: TaskSecondaryButton(
              label: 'Close',
              onPressed: onClose,
              foregroundColor: calendarSubtitleColor,
              hoverForegroundColor: calendarPrimaryColor,
              hoverBackgroundColor:
                  calendarPrimaryColor.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  List<DateTime> _monthDays(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final leading = firstDay.weekday % DateTime.daysPerWeek;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final totalCells = leading + daysInMonth;
    final trailing = (totalCells % 7 == 0) ? 0 : 7 - (totalCells % 7);

    final dates = <DateTime>[];

    for (var i = 0; i < leading; i++) {
      dates.add(firstDay.subtract(Duration(days: leading - i)));
    }
    for (var day = 0; day < daysInMonth; day++) {
      dates.add(DateTime(month.year, month.month, day + 1));
    }
    for (var i = 0; i < trailing; i++) {
      dates.add(DateTime(month.year, month.month, daysInMonth + i + 1));
    }

    // Ensure six rows for layout stability
    while (dates.length < 42) {
      final last = dates.last;
      dates.add(last.add(const Duration(days: 1)));
    }

    return dates;
  }

  Widget _navIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox(
        width: 32,
        height: 32,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: calendarBorderColor),
            foregroundColor: calendarSubtitleColor,
          ),
          child: Icon(icon, size: 18),
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _addMonths(DateTime month, int offset) {
    final newMonth = DateTime(month.year, month.month + offset, 1);
    return DateTime(newMonth.year, newMonth.month);
  }

  DateTime _weekStart(DateTime date) {
    final weekday = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - weekday);
  }
}

class _DayHeaders extends StatelessWidget {
  const _DayHeaders();

  static const _days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _days
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: calendarSubtitleTextStyle.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
