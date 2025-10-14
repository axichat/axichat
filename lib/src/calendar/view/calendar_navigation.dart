import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../common/ui/ui.dart';
import '../bloc/calendar_event.dart';
import '../bloc/calendar_state.dart';
import '../utils/responsive_helper.dart';
import 'widgets/task_form_section.dart';

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
    final Widget navButtonStrip = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _navButton(
            label: '← Previous',
            onPressed: () => _jumpBy(const Duration(days: -7)),
          ),
          const SizedBox(width: calendarSpacing12),
          _navButton(
            label: 'Today',
            highlighted: _isToday(state.selectedDate),
            onPressed: _isToday(state.selectedDate)
                ? null
                : () => onDateSelected(DateTime.now()),
          ),
          const SizedBox(width: calendarSpacing12),
          _navButton(
            label: 'Next →',
            onPressed: () => _jumpBy(const Duration(days: 7)),
          ),
          if (state.viewMode == CalendarView.day) ...[
            const SizedBox(width: calendarSpacing12),
            _navButton(
              label: 'Back to week',
              onPressed: () => onViewChanged(CalendarView.week),
            ),
          ],
        ],
      ),
    );

    return Container(
      padding: EdgeInsets.fromLTRB(
        spec.contentPadding.left,
        spec.contentPadding.top,
        spec.contentPadding.right,
        spec.contentPadding.top,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: calendarBorderColor, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Flexible(child: navButtonStrip),
          Expanded(
            child: Align(
              alignment: Alignment.center,
              child: _DateLabel(
                state: state,
                onDateSelected: onDateSelected,
              ),
            ),
          ),
          if (onUndo != null || onRedo != null) ...[
            const SizedBox(width: calendarSpacing16),
            _buildUndoRedoGroup(),
          ],
        ],
      ),
    );
  }

  void _jumpBy(Duration offset) {
    onDateSelected(state.selectedDate.add(offset));
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
  }) {
    if (highlighted) {
      return TaskPrimaryButton(
        label: label,
        onPressed: onPressed,
        isBusy: false,
      );
    }
    return TaskSecondaryButton(
      label: label,
      onPressed: onPressed,
      foregroundColor: calendarTitleColor,
      hoverForegroundColor: calendarPrimaryColor,
      hoverBackgroundColor: calendarPrimaryColor.withValues(alpha: 0.08),
    );
  }

  Widget _buildUndoRedoGroup() {
    final controls = <Widget>[];
    if (onUndo != null) {
      controls.add(
        _iconControl(
          icon: Icons.undo_rounded,
          tooltip: 'Undo',
          onPressed: canUndo ? onUndo : null,
        ),
      );
    }
    if (onRedo != null) {
      if (controls.isNotEmpty) {
        controls.add(const SizedBox(width: 8));
      }
      controls.add(
        _iconControl(
          icon: Icons.redo_rounded,
          tooltip: 'Redo',
          onPressed: canRedo ? onRedo : null,
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
  }) {
    final shortcut =
        icon == Icons.undo_rounded ? 'Ctrl/Cmd+Z' : 'Ctrl/Cmd+Shift+Z';
    return Tooltip(
      message: '$tooltip ($shortcut)',
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
}

class _DateLabel extends StatefulWidget {
  const _DateLabel({
    required this.state,
    required this.onDateSelected,
  });

  final CalendarState state;
  final void Function(DateTime date) onDateSelected;

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
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                horizontal: calendarSpacing8 + calendarSpacing2,
                vertical: calendarSpacing6,
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
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: calendarTitleColor,
                      letterSpacing: 0.1,
                    ),
                  ),
                  const SizedBox(width: 6),
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
      margin: const EdgeInsets.only(top: calendarSpacing8),
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
              const SizedBox(width: calendarSpacing8),
              _navIconButton(
                icon: Icons.chevron_right,
                onPressed: () => onMonthChanged(_addMonths(month, 1)),
              ),
            ],
          ),
          const SizedBox(height: calendarSpacing12),
          const _DayHeaders(),
          const SizedBox(height: calendarSpacing6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: calendarSpacing4,
              crossAxisSpacing: calendarSpacing4,
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
                      const EdgeInsets.symmetric(vertical: calendarSpacing6),
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
          const SizedBox(height: calendarSpacing12),
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
