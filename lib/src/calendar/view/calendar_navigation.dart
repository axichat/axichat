import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import 'widgets/task_form_section.dart';

const double _compactDateLabelCollapseWidth = 560;
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

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final double horizontalPadding = spec.gridHorizontalPadding;
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final CalendarView viewMode = state.viewMode;
    final bool showBackToWeek = !isCompact && viewMode == CalendarView.day;
    final bool hasUndoRedo = onUndo != null || onRedo != null;
    final String unitLabel = _currentUnitLabel(viewMode);
    final List<Widget> navButtons = [
      _navButton(
        label: '← Previous',
        icon: isCompact ? Icons.chevron_left : null,
        tooltip: 'Previous $unitLabel',
        compact: isCompact,
        onPressed: () => _jumpRelative(-1),
      ),
      _navButton(
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
          label: 'Back to week',
          onPressed: () => onViewChanged(CalendarView.week),
        ),
      );
    }
    const double verticalPadding = calendarInsetMd;
    final Widget undoRedoGroup = _buildUndoRedoGroup(context);

    SystemMouseCursors.basic;
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
            isCompact && availableWidth < _compactDateLabelCollapseWidth;
        final double navSpacing =
            isCompact ? calendarGutterSm : calendarGutterMd;
        final Widget navRow =
            _buildNavRow(navButtons: navButtons, spacing: navSpacing);
        final Widget trailingRow = _buildTrailingRow(
          collapseDateText: collapseDateText,
          isCompact: isCompact,
          hasUndoRedo: hasUndoRedo,
          undoRedoGroup: undoRedoGroup,
        );

        return Container(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            verticalPadding,
          ),
          color: Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              navRow,
              const Spacer(),
              trailingRow,
            ],
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
    required String label,
    required VoidCallback? onPressed,
    bool highlighted = false,
    IconData? icon,
    bool compact = false,
    String? tooltip,
    bool showLabelInCompact = false,
  }) {
    final bool useCompactIconOnly = compact && !showLabelInCompact;
    if (useCompactIconOnly) {
      return _compactNavButton(
        icon: icon ?? Icons.help_outline,
        tooltip: tooltip ?? label,
        onPressed: onPressed,
        highlighted: highlighted,
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
            foregroundColor: calendarTitleColor,
            hoverForegroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
          );
    if (!compact) {
      return button;
    }
    return Tooltip(
      message: tooltip ?? label,
      child: SizedBox(
        height: 40,
        child: button,
      ),
    );
  }

  Widget _buildUndoRedoGroup(BuildContext context) {
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final controls = <Widget>[];
    if (onUndo != null) {
      controls.add(
        _iconControl(
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
        _iconControl(
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

  Widget _iconControl({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    bool compact = false,
  }) {
    final shortcut =
        icon == Icons.undo_rounded ? 'Ctrl/Cmd+Z' : 'Ctrl/Cmd+Shift+Z';
    final String message = '$tooltip ($shortcut)';
    if (compact) {
      return _compactNavButton(
        icon: icon,
        tooltip: message,
        onPressed: onPressed,
        highlighted: false,
      );
    }
    return Tooltip(
      message: message,
      child: TaskSecondaryButton(
        label: tooltip,
        icon: icon,
        onPressed: onPressed,
        foregroundColor: calendarTitleColor,
        hoverForegroundColor: calendarPrimaryColor,
        hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _compactNavButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    required bool highlighted,
  }) {
    final Widget button = highlighted
        ? ShadButton(
            size: ShadButtonSize.sm,
            backgroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryHoverColor,
            foregroundColor: Colors.white,
            hoverForegroundColor: Colors.white,
            onPressed: onPressed,
            child: Icon(icon, size: 16),
          )
        : ShadButton.outline(
            size: ShadButtonSize.sm,
            onPressed: onPressed,
            foregroundColor: calendarTitleColor,
            hoverForegroundColor: calendarPrimaryColor,
            hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
            child: Icon(icon, size: 16),
          );
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 40,
        child: button,
      ),
    );
  }

  Widget _buildNavRow({
    required List<Widget> navButtons,
    required double spacing,
  }) {
    if (navButtons.isEmpty) {
      return const SizedBox.shrink();
    }
    final children = <Widget>[];
    for (var i = 0; i < navButtons.length; i++) {
      children.add(navButtons[i]);
      if (i < navButtons.length - 1) {
        children.add(SizedBox(width: spacing));
      }
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _buildTrailingRow({
    required bool collapseDateText,
    required bool isCompact,
    required bool hasUndoRedo,
    required Widget undoRedoGroup,
  }) {
    final double trailingGap = isCompact ? calendarGutterSm : calendarGutterMd;
    final double maxDateLabelWidth =
        isCompact ? _compactDateLabelMaxWidth : _defaultDateLabelMaxWidth;

    final children = <Widget>[
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDateLabelWidth),
        child: _DateLabel(
          state: state,
          onDateSelected: onDateSelected,
          collapseText: collapseDateText,
        ),
      ),
    ];

    if (hasUndoRedo) {
      children
        ..add(SizedBox(width: trailingGap))
        ..add(undoRedoGroup);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: children,
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
  late DateTime _visibleMonth;
  bool _isHovered = false;

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
    _removeOverlay();
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
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: _toggleOverlay,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterSm + calendarInsetSm,
                vertical: calendarInsetLg,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isHovered
                      ? calendarPrimaryColor.withValues(alpha: 0.4)
                      : calendarBorderColor,
                ),
                color: _isHovered
                    ? calendarPrimaryColor.withValues(alpha: 0.08)
                    : Colors.white,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: calendarSubtitleColor,
                  ),
                  if (!hideText) ...[
                    const SizedBox(width: calendarGutterSm),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: calendarTitleColor,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                  const SizedBox(width: calendarInsetLg),
                  Icon(
                    _overlayEntry == null
                        ? Icons.keyboard_arrow_down
                        : Icons.keyboard_arrow_up,
                    size: 18,
                    color: calendarSubtitleColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _toggleOverlay() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final overlay = Overlay.of(context);

    final renderBox = context.findRenderObject() as RenderBox?;
    final buttonWidth = renderBox?.size.width ?? 0;
    final spec = ResponsiveHelper.spec(context);
    final dropdownWidth = spec.quickAddMaxWidth ?? 340.0;
    final horizontalOffset = buttonWidth - dropdownWidth;
    final buttonHeight = renderBox?.size.height ?? 0;
    final verticalOffset = buttonHeight + spec.contentPadding.vertical / 2;

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return GestureDetector(
          onTap: _removeOverlay,
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
                      onClose: _removeOverlay,
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

    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
  });

  final DateTime month;
  final DateTime selectedWeekStart;
  final DateTime selectedDate;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final days = _buildDays(month);
    final now = DateTime.now();
    final dropdownWidth =
        spec.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;

    return Container(
      width: dropdownWidth,
      padding: spec.contentPadding,
      margin: const EdgeInsets.only(top: calendarGutterSm),
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
                border =
                    const BorderSide(color: calendarPrimaryColor, width: 1);
              }
              if (isToday && !isSelectedDay) {
                border =
                    const BorderSide(color: calendarPrimaryColor, width: 1.5);
              }
              if (isSelectedDay) {
                backgroundColor = calendarPrimaryColor;
                textColor = Colors.white;
                border = BorderSide.none;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(calendarBorderRadius / 1.5),
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

  List<DateTime> _buildDays(DateTime month) {
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
    return SizedBox(
      width: 32,
      height: 32,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: calendarBorderColor),
          foregroundColor: calendarSubtitleColor,
        ),
        child: Icon(icon, size: 18),
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
