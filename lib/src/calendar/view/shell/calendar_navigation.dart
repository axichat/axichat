// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:math' as math;

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/axi_surface_scope.dart';
import 'package:axichat/src/settings/bloc/settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/calendar/bloc/calendar_event.dart';
import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/models/calendar_acl.dart';
import 'package:axichat/src/calendar/view/shell/responsive_helper.dart';
import 'package:axichat/src/calendar/view/shell/calendar_modal_scope.dart';
import 'package:axichat/src/calendar/view/shell/sync_controls.dart';
import 'package:axichat/src/localization/app_localizations.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/view/shell/calendar_sheet_header.dart';
import 'package:axichat/src/calendar/view/tasks/task_form_section.dart';

DateTime shiftedCalendarDate(CalendarState state, int steps) {
  final DateTime base = state.selectedDate;
  switch (state.viewMode) {
    case CalendarView.day:
      return base.add(Duration(days: steps));
    case CalendarView.week:
      return base.add(Duration(days: 7 * steps));
    case CalendarView.month:
      final DateTime targetMonth = DateTime(base.year, base.month + steps, 1);
      final int maxDay = DateTime(
        targetMonth.year,
        targetMonth.month + 1,
        0,
      ).day;
      final int clampedDay = base.day.clamp(1, maxDay).toInt();
      return DateTime(targetMonth.year, targetMonth.month, clampedDay);
  }
}

String calendarUnitLabel(CalendarView viewMode, AppLocalizations l10n) {
  switch (viewMode) {
    case CalendarView.day:
      return l10n.calendarViewDay.toLowerCase();
    case CalendarView.week:
      return l10n.calendarViewWeek.toLowerCase();
    case CalendarView.month:
      return l10n.calendarViewMonth.toLowerCase();
  }
}

const double _compactDateLabelCollapseWidth = smallScreen;
const double _compactDateLabelMaxWidth = 170;
const double _defaultDateLabelMaxWidth = 320;
const List<CalendarView> _viewOrder = <CalendarView>[
  CalendarView.day,
  CalendarView.week,
  CalendarView.month,
];

class CalendarNavigation extends StatelessWidget {
  const CalendarNavigation({
    super.key,
    required this.state,
    required this.onDateSelected,
    required this.onViewChanged,
    required this.onErrorCleared,
    this.sidebarVisible = true,
    this.leadingActions,
    this.trailingActions,
    this.onUndo,
    this.onRedo,
    this.canUndo = false,
    this.canRedo = false,
    this.onSearchRequested,
    this.chatAcl,
    this.chatTitle,
  });

  final CalendarState state;
  final void Function(DateTime date) onDateSelected;
  final void Function(CalendarView view) onViewChanged;
  final VoidCallback onErrorCleared;
  final bool sidebarVisible;
  final Widget? leadingActions;
  final Widget? trailingActions;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;
  final VoidCallback? onSearchRequested;
  final CalendarChatAcl? chatAcl;
  final String? chatTitle;

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final double basePadding = sidebarVisible ? spec.gridHorizontalPadding : 0;
    final spacing = context.spacing;
    final double horizontalPadding = math.max(spacing.m, basePadding);
    final CalendarView viewMode = state.viewMode;
    final bool hasUndoRedo = onUndo != null || onRedo != null;
    final l10n = context.l10n;
    final String unitLabel = calendarUnitLabel(viewMode, l10n);
    final bool placeChevronsInHeader =
        spec.sizeClass != CalendarSizeClass.expanded;
    final double verticalPadding = spacing.xxs;
    final Widget undoRedoGroup = _UndoRedoGroup(
      onUndo: onUndo,
      onRedo: onRedo,
      canUndo: canUndo,
      canRedo: canRedo,
    );
    final colors = context.colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final double safeMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width;
        final double availableWidth = (safeMaxWidth - (horizontalPadding * 2))
            .clamp(0.0, double.infinity);
        final bool isCompact = availableWidth < smallScreen;
        final List<Widget> navButtons = [
          if (!placeChevronsInHeader)
            _IconNavButton(
              icon: Icons.chevron_left,
              tooltip: l10n.calendarPreviousUnit(unitLabel),
              compact: isCompact,
              onPressed: () => _jumpRelative(-1),
            ),
          _NavigationButton(
            label: l10n.calendarToday,
            icon: null,
            highlighted: !_isToday(state.selectedDate),
            tooltip: l10n.calendarToday,
            compact: isCompact,
            showLabelInCompact: true,
            onPressed: _isToday(state.selectedDate)
                ? null
                : () => onDateSelected(DateTime.now()),
          ),
          if (!placeChevronsInHeader)
            _IconNavButton(
              icon: Icons.chevron_right,
              tooltip: l10n.calendarNextUnit(unitLabel),
              compact: isCompact,
              onPressed: () => _jumpRelative(1),
            ),
        ];
        final bool collapseDateText =
            isCompact || availableWidth < _compactDateLabelCollapseWidth;
        final double navSpacing = isCompact ? spacing.s : spacing.m;
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
          onSearchRequested: onSearchRequested,
          onViewChanged: onViewChanged,
          availableWidth: availableWidth,
        );

        final Border border = Border(bottom: BorderSide(color: colors.border));
        const List<BoxShadow> navShadows = [];
        final brightness = context.brightness;
        final Color navBackground = brightness == Brightness.dark
            ? colors.card
            : calendarSidebarBackgroundColor;
        return SizedBox(
          height: context.sizing.appBarHeight,
          child: ColoredBox(
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
                style: context.textTheme.label.copyWith(
                  color: colors.mutedForeground,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (leadingActions != null) ...[
                      leadingActions!,
                      SizedBox(width: navSpacing),
                    ],
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
                    if (trailingActions != null) ...[
                      SizedBox(width: navSpacing),
                      trailingActions!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _jumpRelative(int steps) {
    onDateSelected(shiftedCalendarDate(state, steps));
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return now.year == date.year &&
        now.month == date.month &&
        now.day == date.day;
  }
}

class _NavigationButton extends StatelessWidget {
  const _NavigationButton({
    required this.label,
    required this.onPressed,
    this.highlighted = false,
    this.icon,
    this.compact = false,
    this.tooltip,
    this.showLabelInCompact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool highlighted;
  final IconData? icon;
  final bool compact;
  final String? tooltip;
  final bool showLabelInCompact;

  @override
  Widget build(BuildContext context) {
    final bool useCompactIconOnly = compact && !showLabelInCompact;
    if (useCompactIconOnly) {
      return _CompactNavButton(
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
        : TaskSecondaryButton(label: label, onPressed: onPressed, icon: icon);
    return button;
  }
}

class _IconNavButton extends StatelessWidget {
  const _IconNavButton({
    required this.icon,
    required this.tooltip,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _CompactNavButton(
      icon: icon,
      tooltip: tooltip,
      onPressed: onPressed,
      highlighted: false,
      enabled: onPressed != null,
      dense: compact,
    );
  }
}

class _IconControlButton extends StatelessWidget {
  const _IconControlButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final shortcut = icon == Icons.undo_rounded
        ? context.l10n.calendarShortcutUndo
        : context.l10n.calendarShortcutRedo;
    final String message = context.l10n.commonShortcutTooltip(
      tooltip,
      shortcut,
    );
    return _CompactNavButton(
      icon: icon,
      tooltip: message,
      onPressed: onPressed,
      highlighted: false,
      enabled: onPressed != null,
      dense: compact,
    );
  }
}

class _CompactNavButton extends StatelessWidget {
  const _CompactNavButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.highlighted,
    this.enabled = true,
    this.dense = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool highlighted;
  final bool enabled;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool active = enabled && onPressed != null;
    final Color foreground = active
        ? highlighted
              ? colors.primaryForeground
              : colors.primary
        : colors.mutedForeground;
    final Color background = highlighted ? colors.primary : colors.card;
    final Color border = highlighted ? colors.primary : colors.border;
    final double buttonSize = dense
        ? context.sizing.menuItemHeight
        : context.sizing.iconButtonSize;
    final double tapTarget = dense
        ? context.sizing.menuItemHeight
        : context.sizing.iconButtonTapTarget;
    return AxiIconButton(
      iconData: icon,
      onPressed: active ? onPressed : null,
      tooltip: tooltip,
      color: foreground,
      backgroundColor: background,
      borderColor: border,
      iconSize: context.sizing.menuItemIconSize,
      buttonSize: buttonSize,
      tapTargetSize: tapTarget,
    );
  }
}

class _CalendarDropdownNavButton extends StatelessWidget {
  const _CalendarDropdownNavButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return AxiIconButton.outline(
      iconData: icon,
      onPressed: onPressed,
      color: calendarSubtitleColor,
    );
  }
}

class CalendarNavigationLeadingActions extends StatelessWidget {
  const CalendarNavigationLeadingActions({
    super.key,
    required this.state,
    required this.backTooltip,
    this.onBackPressed,
    this.showBackButton = true,
  });

  final CalendarState state;
  final String backTooltip;
  final VoidCallback? onBackPressed;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showBackButton)
          AxiIconButton.ghost(
            iconData: LucideIcons.arrowLeft,
            tooltip: backTooltip,
            onPressed: onBackPressed,
          ),
        if (showBackButton) SizedBox(width: context.spacing.s),
        SyncControls(state: state, compact: true, showTransferMenu: false),
      ],
    );
  }
}

class _UndoRedoGroup extends StatelessWidget {
  const _UndoRedoGroup({
    required this.onUndo,
    required this.onRedo,
    required this.canUndo,
    required this.canRedo,
  });

  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  @override
  Widget build(BuildContext context) {
    final bool isCompact = ResponsiveHelper.isCompact(context);
    final controls = <Widget>[];
    if (onUndo != null) {
      controls.add(
        _IconControlButton(
          icon: Icons.undo_rounded,
          tooltip: context.l10n.calendarUndo,
          onPressed: canUndo ? onUndo : null,
          compact: isCompact,
        ),
      );
    }
    if (onRedo != null) {
      if (controls.isNotEmpty) {
        controls.add(SizedBox(width: context.spacing.s));
      }
      controls.add(
        _IconControlButton(
          icon: Icons.redo_rounded,
          tooltip: context.l10n.calendarRedo,
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
  const _NavigationButtonRow({required this.navButtons, required this.spacing});

  final List<Widget> navButtons;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    if (navButtons.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: spacing,
      runSpacing: context.spacing.s,
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
    required this.onViewChanged,
    required this.availableWidth,
    this.onSearchRequested,
  });

  final CalendarState state;
  final void Function(DateTime) onDateSelected;
  final bool collapseDateText;
  final bool isCompact;
  final bool hasUndoRedo;
  final Widget undoRedoGroup;
  final ValueChanged<CalendarView> onViewChanged;
  final double availableWidth;
  final VoidCallback? onSearchRequested;

  @override
  Widget build(BuildContext context) {
    final double trailingGap = isCompact
        ? context.spacing.s
        : context.spacing.m;
    final double maxDateLabelWidth = isCompact
        ? _compactDateLabelMaxWidth
        : _defaultDateLabelMaxWidth;

    final bool showViewToggle = !isCompact;

    final trailingChildren = <Widget>[
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxDateLabelWidth),
        child: _DateLabel(
          state: state,
          onDateSelected: onDateSelected,
          collapseText: collapseDateText,
        ),
      ),
      if (showViewToggle)
        CalendarViewModeToggle(
          selectedView: state.viewMode,
          onChanged: onViewChanged,
          compact: isCompact,
          availableWidth: availableWidth,
        ),
      if (onSearchRequested != null)
        _SearchButton(onPressed: onSearchRequested!, compact: isCompact),
      if (hasUndoRedo) undoRedoGroup,
    ];

    return Wrap(
      spacing: trailingGap,
      runSpacing: context.spacing.s,
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: trailingChildren,
    );
  }
}

class CalendarSegmentedOption<T> {
  const CalendarSegmentedOption({required this.value, required this.label});

  final T value;
  final Widget label;
}

class CalendarViewModeToggle extends StatelessWidget {
  const CalendarViewModeToggle({
    super.key,
    required this.selectedView,
    required this.onChanged,
    required this.compact,
    required this.availableWidth,
  });

  final CalendarView selectedView;
  final ValueChanged<CalendarView> onChanged;
  final bool compact;
  final double availableWidth;

  static const double _minWidthExpanded = 180;
  static const double _preferredWidthExpanded = 204;
  static const double _minWidthRegular = 120;
  static const double _preferredWidthRegular = 144;
  static const double _widthScaleExpanded = 0.42;
  static const double _widthScaleRegular = 0.38;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.spacing;
    final shadTheme = ShadTheme.of(context);
    final Duration animationDuration = context
        .watch<SettingsCubit>()
        .animationDuration;
    final CalendarResponsiveSpec spec = ResponsiveHelper.spec(context);
    final bool isExpandedSize = spec.sizeClass == CalendarSizeClass.expanded;
    final EdgeInsets padding = EdgeInsets.symmetric(
      horizontal: compact ? spacing.xs : spacing.s,
    );
    const tabDecoration = ShadDecoration(
      color: Colors.transparent,
      border: ShadBorder.none,
      secondaryBorder: ShadBorder.none,
      secondaryFocusedBorder: ShadBorder.none,
      focusedBorder: ShadBorder.none,
      errorBorder: ShadBorder.none,
      secondaryErrorBorder: ShadBorder.none,
      disableSecondaryBorder: true,
    );
    final double minHeight = context.sizing.buttonHeightRegular;
    final TextStyle tabStyle = context.textTheme.label;
    final double minWidth = isExpandedSize
        ? _minWidthExpanded
        : _minWidthRegular;
    final double preferredWidth = isExpandedSize
        ? _preferredWidthExpanded
        : _preferredWidthRegular;
    final double widthScale = isExpandedSize
        ? _widthScaleExpanded
        : _widthScaleRegular;
    final double controlWidth = math.min(
      preferredWidth,
      math.max(minWidth, availableWidth * widthScale),
    );
    final bool useShortLabels = !isExpandedSize;
    final int tabCount = _viewOrder.length;
    final int safeSelectedIndex = _viewOrder
        .indexOf(selectedView)
        .clamp(0, _viewOrder.length - 1)
        .toInt();
    final horizontalIndicatorInset = spacing.xs;
    final verticalIndicatorInset = spacing.xs;
    final List<ShadTab<CalendarView>> tabs = <ShadTab<CalendarView>>[
      for (int index = 0; index < _viewOrder.length; index++)
        _CalendarTab(
          view: _viewOrder[index],
          label: useShortLabels
              ? _shortLabel(_viewOrder[index], l10n)
              : _viewLabel(_viewOrder[index], l10n),
          padding: padding,
          minHeight: minHeight,
          textStyle: tabStyle,
          decoration: tabDecoration,
          backgroundColor: Colors.transparent,
          selectedBackgroundColor: Colors.transparent,
          foregroundColor: context.colorScheme.mutedForeground,
          selectedForegroundColor: context.colorScheme.foreground,
        ),
    ];

    return SizedBox(
      width: controlWidth,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colorScheme.card,
            border: Border.all(
              color: context.colorScheme.border,
              width: context.borderSide.width,
            ),
            borderRadius: BorderRadius.circular(context.radii.container),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(context.radii.container),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final tabWidth = tabCount == 0
                    ? 0.0
                    : constraints.maxWidth / tabCount;
                final indicatorWidth = math.max(
                  0.0,
                  tabWidth - (horizontalIndicatorInset * 2),
                );
                return Stack(
                  children: [
                    AnimatedPositionedDirectional(
                      duration: animationDuration,
                      curve: Curves.easeInOutCubic,
                      start:
                          (tabWidth * safeSelectedIndex) +
                          horizontalIndicatorInset,
                      top: verticalIndicatorInset,
                      bottom: verticalIndicatorInset,
                      width: indicatorWidth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colorScheme.primary.withValues(
                            alpha: context.motion.tapSplashAlpha,
                          ),
                          borderRadius: BorderRadius.circular(
                            context.radii.container,
                          ),
                        ),
                      ),
                    ),
                    ShadTheme(
                      data: shadTheme.copyWith(
                        tabsTheme: shadTheme.tabsTheme.copyWith(
                          tabDecoration: tabDecoration,
                          tabSelectedDecoration: tabDecoration,
                          tabBackgroundColor: Colors.transparent,
                          tabSelectedBackgroundColor: Colors.transparent,
                          tabHoverBackgroundColor: Colors.transparent,
                          tabSelectedHoverBackgroundColor: Colors.transparent,
                          tabShadows: const <BoxShadow>[],
                          tabSelectedShadows: const <BoxShadow>[],
                        ),
                      ),
                      child: ShadTabs<CalendarView>(
                        value: selectedView,
                        onChanged: onChanged,
                        tabs: tabs,
                        padding: EdgeInsets.zero,
                        gap: 0,
                        tabsGap: 0,
                        contentConstraints: const BoxConstraints.tightFor(
                          height: 0,
                        ),
                        decoration: tabDecoration,
                      ),
                    ),
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

class _CalendarTab extends ShadTab<CalendarView> {
  _CalendarTab({
    required CalendarView view,
    required String label,
    required EdgeInsets padding,
    required double minHeight,
    required TextStyle textStyle,
    required ShadDecoration decoration,
    required Color backgroundColor,
    required Color selectedBackgroundColor,
    required Color foregroundColor,
    required Color selectedForegroundColor,
  }) : super(
         value: view,
         flex: 1,
         height: minHeight,
         padding: padding,
         backgroundColor: backgroundColor,
         selectedBackgroundColor: selectedBackgroundColor,
         hoverBackgroundColor: Colors.transparent,
         selectedHoverBackgroundColor: Colors.transparent,
         pressedBackgroundColor: Colors.transparent,
         shadows: const <BoxShadow>[],
         selectedShadows: const <BoxShadow>[],
         foregroundColor: foregroundColor,
         selectedForegroundColor: selectedForegroundColor,
         decoration: decoration,
         child: Text(
           label,
           style: textStyle,
           maxLines: 1,
           softWrap: false,
           overflow: TextOverflow.ellipsis,
         ),
         content: const SizedBox.shrink(),
       );
}

class CalendarSegmentedToggle<T> extends StatelessWidget {
  const CalendarSegmentedToggle({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.minHeight,
    required this.controlWidth,
    required this.padding,
    required this.outerDecoration,
    required this.activeBackground,
    required this.hoverBackground,
    required this.dividerColor,
  });

  final List<CalendarSegmentedOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final double minHeight;
  final double controlWidth;
  final EdgeInsets padding;
  final ShadDecoration outerDecoration;
  final Color activeBackground;
  final Color hoverBackground;
  final Color dividerColor;

  @override
  Widget build(BuildContext context) {
    final double cornerRadius = context.radius.topLeft.x;
    final ShadColorScheme colors = context.colorScheme;
    final ShapeBorder outerShape = SquircleBorder(borderRadius: context.radius);
    return Material(
      color: outerDecoration.color ?? colors.secondary,
      shape: outerShape,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: minHeight,
        width: controlWidth,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int index = 0; index < options.length; index++) ...[
              if (index > 0)
                Container(
                  width: context.borderSide.width,
                  height: double.infinity,
                  color: dividerColor,
                ),
              Expanded(
                child: _SegmentedToggleItem(
                  isFirst: index == 0,
                  isLast: index == options.length - 1,
                  selected: options[index].value == selected,
                  cornerRadius: cornerRadius,
                  padding: padding,
                  minHeight: minHeight,
                  activeBackground: activeBackground,
                  hoverBackground: hoverBackground,
                  onSelected: () => onChanged(options[index].value),
                  activeTextColor: colors.primary,
                  inactiveTextColor: colors.mutedForeground,
                  child: options[index].label,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SegmentedToggleItem extends StatefulWidget {
  const _SegmentedToggleItem({
    required this.isFirst,
    required this.isLast,
    required this.selected,
    required this.cornerRadius,
    required this.padding,
    required this.minHeight,
    required this.activeBackground,
    required this.hoverBackground,
    required this.onSelected,
    required this.child,
    required this.activeTextColor,
    required this.inactiveTextColor,
  });

  final bool isFirst;
  final bool isLast;
  final bool selected;
  final double cornerRadius;
  final EdgeInsets padding;
  final double minHeight;
  final Color activeBackground;
  final Color hoverBackground;
  final VoidCallback onSelected;
  final Widget child;
  final Color activeTextColor;
  final Color inactiveTextColor;

  @override
  State<_SegmentedToggleItem> createState() => _SegmentedToggleItemState();
}

class _SegmentedToggleItemState extends State<_SegmentedToggleItem> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHovered(bool value) {
    if (_hovered == value) return;
    setState(() {
      _hovered = value;
    });
  }

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() {
      _pressed = value;
    });
  }

  Color _resolveBackground({required bool focused}) {
    if (widget.selected) {
      return widget.activeBackground;
    }
    if (_pressed || focused) {
      return widget.activeBackground;
    }
    if (_hovered) {
      return widget.hoverBackground;
    }
    return Colors.transparent;
  }

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.horizontal(
      left: widget.isFirst ? Radius.circular(widget.cornerRadius) : Radius.zero,
      right: widget.isLast ? Radius.circular(widget.cornerRadius) : Radius.zero,
    );
    final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
      borderRadius: radius,
    );
    final bool enabled = !widget.selected;
    final Widget styledChild = IconTheme.merge(
      data: IconThemeData(
        color: widget.selected
            ? widget.activeTextColor
            : widget.inactiveTextColor,
      ),
      child: DefaultTextStyle.merge(
        style: context.textTheme.label.copyWith(
          color: widget.selected
              ? widget.activeTextColor
              : widget.inactiveTextColor,
        ),
        child: widget.child,
      ),
    );
    return AxiTapBounce(
      enabled: enabled,
      child: ShadFocusable(
        canRequestFocus: enabled,
        builder: (context, focused, _) {
          final Color background = _resolveBackground(focused: focused);
          return Material(
            type: MaterialType.transparency,
            shape: shape,
            clipBehavior: Clip.antiAlias,
            child: ShadGestureDetector(
              cursor: enabled
                  ? SystemMouseCursors.click
                  : SystemMouseCursors.basic,
              onHoverChange: enabled ? _setHovered : null,
              onTapDown: enabled ? (_) => _setPressed(true) : null,
              onTapUp: enabled ? (_) => _setPressed(false) : null,
              onTapCancel: enabled ? () => _setPressed(false) : null,
              onTap: enabled ? widget.onSelected : null,
              child: AnimatedContainer(
                duration: calendarSlotHoverAnimationDuration,
                curve: Curves.easeOutCubic,
                padding: widget.padding,
                constraints: BoxConstraints(minHeight: widget.minHeight),
                alignment: Alignment.center,
                decoration: ShapeDecoration(color: background, shape: shape),
                child: styledChild,
              ),
            ),
          );
        },
      ),
    );
  }
}

String _viewLabel(CalendarView view, AppLocalizations l10n) {
  switch (view) {
    case CalendarView.day:
      return l10n.calendarViewDay;
    case CalendarView.week:
      return l10n.calendarViewWeek;
    case CalendarView.month:
      return l10n.calendarViewMonth;
  }
}

String _shortLabel(CalendarView view, AppLocalizations l10n) {
  switch (view) {
    case CalendarView.day:
      return l10n.calendarViewDayShort;
    case CalendarView.week:
      return l10n.calendarViewWeekShort;
    case CalendarView.month:
      return l10n.calendarViewMonthShort;
  }
}

class _SearchButton extends StatelessWidget {
  const _SearchButton({required this.onPressed, required this.compact});

  final VoidCallback onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final double iconSize = context.sizing.menuItemIconSize;
    if (compact) {
      return AxiIconButton.ghost(
        iconData: Icons.search,
        onPressed: onPressed,
        iconSize: iconSize,
        buttonSize: context.sizing.iconButtonSize,
        tapTargetSize: context.sizing.iconButtonTapTarget,
        color: colors.primary,
      );
    }
    return AxiButton.secondary(
      onPressed: onPressed,
      leading: Icon(Icons.search, size: iconSize, color: colors.primary),
      child: Text(context.l10n.commonSearch),
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

class _DateLabelState extends State<_DateLabel>
    with AxiSurfaceRegistration<_DateLabel> {
  final OverlayPortalController _portalController = OverlayPortalController();
  bool _isBottomSheetOpen = false;
  late DateTime _visibleMonth;
  late DateFormat _dayFormat;
  late DateFormat _monthFormat;
  bool get _isPickerOpen => _portalController.isShowing || _isBottomSheetOpen;

  @override
  bool get isAxiSurfaceOpen => _portalController.isShowing;

  @override
  VoidCallback? get onAxiSurfaceDismiss => _removeOverlay;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.state.selectedDate.year,
      widget.state.selectedDate.month,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context).toString();
    _dayFormat = DateFormat.yMMMd(locale);
    _monthFormat = DateFormat.yMMMM(locale);
    syncAxiSurfaceRegistration(notify: false);
  }

  @override
  void didUpdateWidget(covariant _DateLabel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.selectedDate.year != oldWidget.state.selectedDate.year ||
        widget.state.selectedDate.month != oldWidget.state.selectedDate.month) {
      _visibleMonth = DateTime(
        widget.state.selectedDate.year,
        widget.state.selectedDate.month,
      );
    }
  }

  @override
  void dispose() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final label = switch (widget.state.viewMode) {
      CalendarView.day => _formatDay(widget.state.selectedDate),
      CalendarView.week => context.l10n.commonRangeLabel(
        _formatDay(widget.state.weekStart),
        _formatDay(widget.state.weekEnd),
      ),
      CalendarView.month => _monthFormat.format(widget.state.selectedDate),
    };
    final bool hideText =
        widget.collapseText || MediaQuery.of(context).size.width < 420;
    final bool isOpen = _isPickerOpen;
    final Color iconColor = isOpen
        ? calendarPrimaryColor
        : calendarSubtitleColor;

    final Widget trigger = SizedBox(
      height: context.sizing.buttonHeightRegular,
      child: AxiButton.outline(
        onPressed: _toggleOverlay,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: context.sizing.menuItemIconSize,
              color: iconColor,
            ),
            if (!hideText) ...[
              SizedBox(width: context.spacing.s),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.sizing.menuMaxWidth,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            SizedBox(width: context.spacing.s),
            Icon(
              isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: context.sizing.iconButtonIconSize,
              color: iconColor,
            ),
          ],
        ),
      ),
    );
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portalController,
      overlayChildBuilder: (overlayContext, info) {
        if (!_portalController.isShowing) {
          return const SizedBox.shrink();
        }
        final Rect anchorRect = MatrixUtils.transformRect(
          info.childPaintTransform,
          Offset.zero & info.childSize,
        );
        final spec = ResponsiveHelper.spec(overlayContext);
        final double dropdownWidth = spec.quickAddMaxWidth ?? 340.0;
        final double gap = spec.contentPadding.vertical / 2;
        final double overlayPadding = overlayContext.spacing.m;
        final double maxLeft = math.max(
          overlayPadding,
          info.overlaySize.width - dropdownWidth - overlayPadding,
        );
        final double left = (anchorRect.right - dropdownWidth).clamp(
          overlayPadding,
          maxLeft,
        );
        final double belowSpace =
            info.overlaySize.height - anchorRect.bottom - gap - overlayPadding;
        final double aboveSpace = anchorRect.top - gap - overlayPadding;
        final bool placeBelow = belowSpace >= aboveSpace;
        final double maxHeight = math.max(
          0,
          placeBelow ? belowSpace : aboveSpace,
        );
        if (maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        final double? top = placeBelow ? anchorRect.bottom + gap : null;
        final double? bottom = placeBelow
            ? null
            : math.max(
                overlayPadding,
                info.overlaySize.height - anchorRect.top + gap,
              );
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
              ),
            ),
            Positioned(
              left: left,
              top: top,
              bottom: bottom,
              width: dropdownWidth,
              child: GestureDetector(
                onTap: () {},
                behavior: HitTestBehavior.opaque,
                child: Material(
                  color: Colors.transparent,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxHeight),
                    child: InBoundsFadeScale(
                      child: _CalendarDropdown(
                        monthFormat: _monthFormat,
                        month: _visibleMonth,
                        selectedWeekStart: widget.state.weekStart,
                        selectedDate: widget.state.selectedDate,
                        onClose: _removeOverlay,
                        onMonthChanged: (month) {
                          setState(() => _visibleMonth = month);
                        },
                        onDateSelected: (date) {
                          widget.onDateSelected(date);
                          _removeOverlay();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: trigger,
    );
  }

  void _toggleOverlay() {
    if (_portalController.isShowing) {
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
    _portalController.show();
    syncAxiSurfaceRegistration();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _showBottomSheet() async {
    if (!mounted) {
      return;
    }
    setState(() => _isBottomSheetOpen = true);
    final BuildContext modalContext = context.calendarModalContext;
    await showAdaptiveBottomSheet<void>(
      context: modalContext,
      isScrollControlled: true,
      surfacePadding: EdgeInsets.zero,
      builder: (sheetContext) {
        var sheetMonth = _visibleMonth;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              bottom: false,
              child: _CalendarDropdown(
                monthFormat: _monthFormat,
                useSurface: false,
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

  void _removeOverlay() {
    if (!_portalController.isShowing) {
      return;
    }
    _portalController.hide();
    syncAxiSurfaceRegistration();
    if (mounted) {
      setState(() {});
    }
  }

  String _formatDay(DateTime date) => _dayFormat.format(date);
}

class _CalendarDropdown extends StatelessWidget {
  const _CalendarDropdown({
    required this.monthFormat,
    required this.month,
    required this.selectedWeekStart,
    required this.selectedDate,
    required this.onClose,
    required this.onMonthChanged,
    required this.onDateSelected,
    this.margin,
    this.useSurface = true,
  });

  final DateFormat monthFormat;
  final DateTime month;
  final DateTime selectedWeekStart;
  final DateTime selectedDate;
  final VoidCallback onClose;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;
  final EdgeInsetsGeometry? margin;
  final bool useSurface;

  @override
  Widget build(BuildContext context) {
    final spec = ResponsiveHelper.spec(context);
    final spacing = context.spacing;
    final days = _monthDays(month);
    final now = DateTime.now();
    final bool fillWidth = ResponsiveHelper.isCompact(context);
    final double dropdownWidth =
        spec.quickAddMaxWidth ?? calendarQuickAddModalMaxWidth;
    final double width = fillWidth ? double.infinity : dropdownWidth;

    final Widget content = Padding(
      padding: spec.contentPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  monthFormat.format(month),
                  style: context.textTheme.h4.copyWith(
                    color: calendarTitleColor,
                  ),
                ),
              ),
              _CalendarDropdownNavButton(
                icon: Icons.chevron_left,
                onPressed: () => onMonthChanged(_addMonths(month, -1)),
              ),
              SizedBox(width: spacing.s),
              _CalendarDropdownNavButton(
                icon: Icons.chevron_right,
                onPressed: () => onMonthChanged(_addMonths(month, 1)),
              ),
              SizedBox(width: spacing.s),
              CalendarSheetCloseButton(
                tooltip: context.l10n.commonClose,
                color: calendarSubtitleColor,
                onClose: onClose,
              ),
            ],
          ),
          SizedBox(height: spacing.m),
          const _DayHeaders(),
          SizedBox(height: spacing.s),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: spacing.xs,
              crossAxisSpacing: spacing.xs,
            ),
            itemCount: days.length,
            itemBuilder: (context, index) {
              final date = days[index];
              final isOtherMonth = date.month != month.month;
              final isToday = _isSameDay(date, now);
              final isSelectedWeek = _weekStart(
                date,
              ).isAtSameMomentAs(_weekStart(selectedWeekStart));
              final isSelectedDay = _isSameDay(date, selectedDate);

              final BorderSide baseBorder = context.borderSide;
              Color textColor = calendarTitleColor;
              Color backgroundColor = calendarContainerColor;
              BorderSide border = BorderSide.none;

              if (isOtherMonth) {
                textColor = calendarSubtitleColor;
              }
              if (isSelectedWeek) {
                backgroundColor = calendarPrimaryColor.withValues(alpha: 0.12);
                border = baseBorder.copyWith(color: calendarPrimaryColor);
              }
              if (isToday && !isSelectedDay) {
                border = baseBorder.copyWith(
                  color: calendarPrimaryColor,
                  width: baseBorder.width * 2,
                );
              }
              if (isSelectedDay) {
                backgroundColor = calendarPrimaryColor;
                textColor = context.colorScheme.primaryForeground;
                border = BorderSide.none;
              }

              final RoundedSuperellipseBorder shape = RoundedSuperellipseBorder(
                borderRadius: context.radius,
                side: border,
              );
              return AxiTapBounce(
                child: ShadFocusable(
                  canRequestFocus: true,
                  builder: (context, _, _) {
                    return Material(
                      type: MaterialType.transparency,
                      shape: shape,
                      clipBehavior: Clip.antiAlias,
                      child: ShadGestureDetector(
                        cursor: SystemMouseCursors.click,
                        onTap: () => onDateSelected(date),
                        child: DecoratedBox(
                          decoration: ShapeDecoration(
                            color: backgroundColor,
                            shape: shape,
                          ),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: context.spacing.s,
                            ),
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                date.day.toString(),
                                style: context.textTheme.small
                                    .strongIf(isToday)
                                    .copyWith(color: textColor),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );

    if (!useSurface) {
      return SizedBox(width: width, child: content);
    }

    return Container(
      width: width,
      margin: margin ?? EdgeInsets.only(top: spacing.s),
      decoration: BoxDecoration(
        color: calendarContainerColor,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        border: Border.all(color: calendarBorderColor),
        boxShadow: calendarMediumShadow,
      ),
      child: content,
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

  @override
  Widget build(BuildContext context) {
    final labels = MaterialLocalizations.of(context).narrowWeekdays;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: labels
          .map(
            (label) => Expanded(
              child: Center(
                child: Text(
                  label,
                  style: context.textTheme.label.strong.copyWith(
                    color: calendarSubtitleColor,
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
