import 'package:flutter/material.dart';

import '../../../common/ui/ui.dart';
import '../priority_checkbox_tile.dart';

/// Standard section title used across the calendar task forms. Keeps typography
/// and spacing consistent while allowing trailing actions or custom padding.
class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.textStyle,
    this.trailing,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: calendarSubtitleColor,
          letterSpacing: 0.2,
        );

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              title,
              style: style,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Divider that matches the legacy calendar form styling (subtle grey line with
/// pill radius). Used between logical sections in sidebars and modals.
class TaskSectionDivider extends StatelessWidget {
  const TaskSectionDivider({
    super.key,
    this.verticalPadding = 12,
    this.color,
  });

  final double verticalPadding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: verticalPadding),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          color: (color ?? calendarBorderColor).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

/// Shared priority toggle row used by quick add, edit popovers, and the task
/// sidebar to keep layout identical.
class TaskPriorityToggles extends StatelessWidget {
  const TaskPriorityToggles({
    super.key,
    required this.isImportant,
    required this.isUrgent,
    required this.onImportantChanged,
    required this.onUrgentChanged,
    this.spacing = 12,
  });

  final bool isImportant;
  final bool isUrgent;
  final ValueChanged<bool> onImportantChanged;
  final ValueChanged<bool> onUrgentChanged;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Important',
            value: isImportant,
            color: calendarSuccessColor,
            onChanged: onImportantChanged,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Urgent',
            value: isUrgent,
            color: calendarWarningColor,
            onChanged: onUrgentChanged,
          ),
        ),
      ],
    );
  }
}

/// Shared row wrapper for task form actions (cancel/save/delete). Allows each
/// surface to supply its own buttons while keeping spacing and optional top
/// border consistent.
class TaskFormActionsRow extends StatelessWidget {
  const TaskFormActionsRow({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.all(12),
    this.includeTopBorder = false,
    this.borderColor = calendarBorderColor,
    this.backgroundColor = Colors.transparent,
    this.gap,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool includeTopBorder;
  final Color borderColor;
  final Color backgroundColor;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final decoration = includeTopBorder
        ? BoxDecoration(
            color: backgroundColor,
            border: Border(
              top: BorderSide(color: borderColor, width: 1),
            ),
          )
        : BoxDecoration(color: backgroundColor);

    return Container(
      padding: padding,
      decoration: decoration,
      child: Row(
        children: gap == null ? children : _withGap(children, gap!),
      ),
    );
  }

  List<Widget> _withGap(List<Widget> source, double gap) {
    if (source.length <= 1) return source;
    final entries = <Widget>[];
    for (var i = 0; i < source.length; i++) {
      if (i != 0) {
        entries.add(SizedBox(width: gap));
      }
      entries.add(source[i]);
    }
    return entries;
  }
}
