import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../priority_checkbox_tile.dart';
import 'recurrence_editor.dart';
import 'schedule_range_fields.dart';
import 'task_text_field.dart';

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
    this.onImportantChanged,
    this.onUrgentChanged,
    this.isImportantIndeterminate = false,
    this.isUrgentIndeterminate = false,
    this.spacing = calendarSpacing12,
  });

  final bool isImportant;
  final bool isUrgent;
  final bool isImportantIndeterminate;
  final bool isUrgentIndeterminate;
  final ValueChanged<bool>? onImportantChanged;
  final ValueChanged<bool>? onUrgentChanged;
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
            isIndeterminate: isImportantIndeterminate,
            onChanged: onImportantChanged,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: PriorityCheckboxTile(
            label: 'Urgent',
            value: isUrgent,
            color: calendarWarningColor,
            isIndeterminate: isUrgentIndeterminate,
            onChanged: onUrgentChanged,
          ),
        ),
      ],
    );
  }
}

/// Shared completion toggle used by all calendar task forms. Wraps the
/// primary-styled [PriorityCheckboxTile] and supports indeterminate state for
/// multi-selection scenarios.
class TaskCompletionToggle extends StatelessWidget {
  const TaskCompletionToggle({
    super.key,
    required this.value,
    this.onChanged,
    this.isIndeterminate = false,
    this.enabled = true,
    this.label = 'Mark as completed',
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool isIndeterminate;
  final bool enabled;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<bool>? effectiveOnChanged = enabled ? onChanged : null;
    return PriorityCheckboxTile(
      label: label,
      value: value,
      color: calendarPrimaryColor,
      isIndeterminate: isIndeterminate,
      onChanged: effectiveOnChanged,
    );
  }
}

/// Styled [TextFormField] counterpart to [TaskTextField] for use inside forms
/// that require validation. Mirrors the calendar styling so validators can be
/// added without reimplementing decoration logic everywhere.
class TaskTextFormField extends StatelessWidget {
  const TaskTextFormField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText,
    this.labelStyle,
    this.hintText,
    this.hintStyle,
    this.minLines = 1,
    int? maxLines,
    this.textInputAction,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
    this.enabled = true,
    this.onChanged,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
    this.contentPadding,
    this.borderRadius,
    this.focusBorderColor,
    this.fillColor,
    this.textStyle,
  }) : maxLines = maxLines ?? minLines;

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final TextStyle? labelStyle;
  final String? hintText;
  final TextStyle? hintStyle;
  final int minLines;
  final int maxLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldSetter<String>? onSaved;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final EdgeInsetsGeometry? contentPadding;
  final double? borderRadius;
  final Color? focusBorderColor;
  final Color? fillColor;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final double radius = borderRadius ?? 8;
    final Color focusedColor = focusBorderColor ?? calendarPrimaryColor;
    final Color effectiveFill = fillColor ?? Colors.white;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      minLines: minLines,
      maxLines: maxLines,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      textInputAction: textInputAction,
      autofocus: autofocus,
      autovalidateMode: autovalidateMode,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      onSaved: onSaved,
      validator: validator,
      style: textStyle ??
          const TextStyle(
            color: calendarTitleColor,
            fontSize: 14,
          ),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: labelStyle ??
            const TextStyle(
              color: calendarSubtitleColor,
              fontSize: 14,
            ),
        hintText: hintText,
        hintStyle: hintStyle ??
            const TextStyle(
              color: calendarTimeLabelColor,
              fontSize: 14,
            ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: calendarBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: calendarBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: focusedColor, width: 2),
        ),
        contentPadding: contentPadding ??
            const EdgeInsets.symmetric(
              horizontal: calendarSpacing12,
              vertical: calendarSpacing12,
            ),
        filled: true,
        fillColor: effectiveFill,
      ),
    );
  }
}

/// Outline-styled button used for auxiliary task actions (date/time pickers,
/// secondary toolbar buttons). Keeps icon/text spacing consistent across
/// inline/guest and dialog surfaces.
class TaskToolbarButton extends StatelessWidget {
  const TaskToolbarButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ShadButton.outline(
      size: ShadButtonSize.sm,
      onPressed: enabled ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: calendarSpacing4),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Small ghost icon button used for dismiss/secondary actions in toolbars.
class TaskGhostIconButton extends StatelessWidget {
  const TaskGhostIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = ShadButton.ghost(
      size: ShadButtonSize.sm,
      onPressed: onPressed,
      child: Icon(icon, size: 16),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Standard header + range picker wrapper so schedule sections render
/// consistently across sidebars, dialogs, and popovers.
class TaskScheduleSection extends StatelessWidget {
  const TaskScheduleSection({
    super.key,
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    this.title = 'Schedule',
    this.spacing = calendarSpacing8,
    this.padding = EdgeInsets.zero,
    this.headerStyle,
    this.headerTrailing,
    this.startLabel,
    this.endLabel,
    this.startPlaceholder,
    this.endPlaceholder,
    this.showTimeSelectors = true,
    this.minDate,
    this.maxDate,
    this.onClear,
  });

  final DateTime? start;
  final DateTime? end;
  final ValueChanged<DateTime?> onStartChanged;
  final ValueChanged<DateTime?> onEndChanged;
  final String title;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final TextStyle? headerStyle;
  final Widget? headerTrailing;
  final String? startLabel;
  final String? endLabel;
  final String? startPlaceholder;
  final String? endPlaceholder;
  final bool showTimeSelectors;
  final DateTime? minDate;
  final DateTime? maxDate;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = start != null || end != null;
    final VoidCallback? clearHandler = hasSelection
        ? onClear ??
            () {
              onStartChanged(null);
              onEndChanged(null);
            }
        : null;
    final trailingChildren = <Widget>[];
    if (headerTrailing != null) {
      trailingChildren.add(headerTrailing!);
    }
    if (clearHandler != null) {
      if (trailingChildren.isNotEmpty) {
        trailingChildren.add(const SizedBox(width: calendarSpacing4));
      }
      trailingChildren.add(
        TaskGhostIconButton(
          icon: Icons.close,
          tooltip: 'Clear schedule',
          onPressed: clearHandler,
        ),
      );
    }
    final Widget? effectiveTrailing = trailingChildren.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: trailingChildren,
          );

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskSectionHeader(
            title: title,
            textStyle: headerStyle,
            trailing: effectiveTrailing,
          ),
          SizedBox(height: spacing),
          ScheduleRangeFields(
            start: start,
            end: end,
            onStartChanged: onStartChanged,
            onEndChanged: onEndChanged,
            startLabel: startLabel ?? 'START',
            endLabel: endLabel ?? 'END',
            startPlaceholder: startPlaceholder ?? 'Select start',
            endPlaceholder: endPlaceholder ?? 'Select end',
            showTimeSelectors: showTimeSelectors,
            minDate: minDate,
            maxDate: maxDate,
          ),
        ],
      ),
    );
  }
}

/// Shared recurrence editor section with standardized spacing and header.
class TaskRecurrenceSection extends StatelessWidget {
  const TaskRecurrenceSection({
    super.key,
    required this.value,
    required this.onChanged,
    this.title = 'Repeat',
    this.spacing = calendarSpacing8,
    this.padding = EdgeInsets.zero,
    this.headerStyle,
    this.headerTrailing,
    this.enabled = true,
    this.fallbackWeekday,
    this.spacingConfig = const RecurrenceEditorSpacing(
      chipSpacing: 6,
      chipRunSpacing: 6,
      weekdaySpacing: 10,
      advancedSectionSpacing: 12,
      endSpacing: 14,
      fieldGap: 12,
    ),
    this.chipPadding,
    this.weekdayChipPadding,
    this.intervalSelectWidth,
  });

  final RecurrenceFormValue value;
  final ValueChanged<RecurrenceFormValue> onChanged;
  final String title;
  final double spacing;
  final EdgeInsetsGeometry padding;
  final TextStyle? headerStyle;
  final Widget? headerTrailing;
  final bool enabled;
  final int? fallbackWeekday;
  final RecurrenceEditorSpacing spacingConfig;
  final EdgeInsets? chipPadding;
  final EdgeInsets? weekdayChipPadding;
  final double? intervalSelectWidth;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TaskSectionHeader(
            title: title,
            textStyle: headerStyle,
            trailing: headerTrailing,
          ),
          SizedBox(height: spacing),
          RecurrenceEditor(
            value: value,
            onChanged: onChanged,
            enabled: enabled,
            fallbackWeekday: fallbackWeekday,
            spacing: spacingConfig,
            chipPadding: chipPadding ??
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            weekdayChipPadding: weekdayChipPadding ??
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            intervalSelectWidth: intervalSelectWidth ?? 120,
          ),
        ],
      ),
    );
  }
}

/// Configuration for a single date/time control rendered by
/// [TaskDateTimeToolbar]. Allows callers to customise the empty-state labels,
/// formatting, icons, and whether a time selector should be shown.
@immutable
class TaskDateTimeToolbarField {
  const TaskDateTimeToolbarField({
    required this.onSelectDate,
    required this.onSelectTime,
    this.selectedDate,
    this.selectedTime,
    this.emptyDateLabel = 'Pick date',
    this.emptyTimeLabel = 'Pick time',
    this.dateIcon = Icons.calendar_today,
    this.timeIcon = Icons.schedule,
    this.dateLabelBuilder,
    this.timeLabelBuilder,
    this.enabled = true,
    this.showTimeButton = true,
  });

  final DateTime? selectedDate;
  final TimeOfDay? selectedTime;
  final VoidCallback onSelectDate;
  final VoidCallback onSelectTime;
  final String emptyDateLabel;
  final String emptyTimeLabel;
  final IconData dateIcon;
  final IconData timeIcon;
  final String Function(BuildContext context, DateTime date)? dateLabelBuilder;
  final String Function(BuildContext context, TimeOfDay time)? timeLabelBuilder;
  final bool enabled;
  final bool showTimeButton;

  String dateLabel(BuildContext context) {
    final DateTime? date = selectedDate;
    if (date == null) {
      return emptyDateLabel;
    }
    if (dateLabelBuilder != null) {
      return dateLabelBuilder!(context, date);
    }
    final localizations = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    if (localizations != null) {
      return localizations.formatMediumDate(date);
    }
    final twoDigitMonth = date.month.toString().padLeft(2, '0');
    final twoDigitDay = date.day.toString().padLeft(2, '0');
    return '$twoDigitMonth/$twoDigitDay/${date.year}';
  }

  String timeLabel(BuildContext context) {
    final TimeOfDay? time = selectedTime;
    if (time == null) {
      return emptyTimeLabel;
    }
    if (timeLabelBuilder != null) {
      return timeLabelBuilder!(context, time);
    }
    final localizations = Localizations.of<MaterialLocalizations>(
      context,
      MaterialLocalizations,
    );
    final bool use24Hour =
        MediaQuery.maybeOf(context)?.alwaysUse24HourFormat ?? false;
    if (localizations != null) {
      return localizations.formatTimeOfDay(
        time,
        alwaysUse24HourFormat: use24Hour,
      );
    }
    return time.format(context);
  }
}

/// Standardised toolbar that renders one or two [TaskDateTimeToolbarField]
/// configurations side-by-side. Used by inline, quick add, sidebar, and dialog
/// editors to keep date/time affordances consistent across the calendar.
class TaskDateTimeToolbar extends StatelessWidget {
  const TaskDateTimeToolbar({
    super.key,
    required this.primaryField,
    this.secondaryField,
    this.onClear,
    this.padding = EdgeInsets.zero,
    this.gap = calendarSpacing8,
    this.clearIcon = Icons.close,
    this.clearTooltip,
  });

  final TaskDateTimeToolbarField primaryField;
  final TaskDateTimeToolbarField? secondaryField;
  final VoidCallback? onClear;
  final EdgeInsetsGeometry padding;
  final double gap;
  final IconData clearIcon;
  final String? clearTooltip;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      ..._buildField(context, primaryField),
      if (secondaryField != null) ..._buildField(context, secondaryField!),
      if (onClear != null)
        TaskGhostIconButton(
          icon: clearIcon,
          tooltip: clearTooltip,
          onPressed: onClear!,
        ),
    ];

    return TaskFormActionsRow(
      padding: padding,
      gap: gap,
      children: children,
    );
  }

  List<Widget> _buildField(
    BuildContext context,
    TaskDateTimeToolbarField field,
  ) {
    final widgets = <Widget>[
      Expanded(
        child: TaskToolbarButton(
          icon: field.dateIcon,
          label: field.dateLabel(context),
          onPressed: field.enabled ? field.onSelectDate : null,
          enabled: field.enabled,
        ),
      ),
    ];
    if (field.showTimeButton) {
      widgets.add(
        Expanded(
          child: TaskToolbarButton(
            icon: field.timeIcon,
            label: field.timeLabel(context),
            onPressed: field.enabled ? field.onSelectTime : null,
            enabled: field.enabled,
          ),
        ),
      );
    }
    return widgets;
  }
}

/// Primary calendar action button (e.g., Add/Save) with consistent sizing and
/// hover behaviour.
class TaskPrimaryButton extends StatelessWidget {
  const TaskPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
    this.size = ShadButtonSize.sm,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final ShadButtonSize size;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      size: size,
      onPressed: isBusy ? null : onPressed,
      backgroundColor: calendarPrimaryColor,
      hoverBackgroundColor: calendarPrimaryHoverColor,
      foregroundColor: Colors.white,
      child: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: calendarSpacing4),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Secondary outline-styled button for calendar forms. Provides consistent
/// hover colours and optional busy state handling.
class TaskSecondaryButton extends StatelessWidget {
  const TaskSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
    this.size = ShadButtonSize.sm,
    this.foregroundColor = calendarSubtitleColor,
    this.hoverForegroundColor = calendarPrimaryColor,
    this.hoverBackgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final ShadButtonSize size;
  final Color foregroundColor;
  final Color hoverForegroundColor;
  final Color? hoverBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isBusy || onPressed == null;
    return ShadButton.outline(
      size: size,
      onPressed: disabled ? null : onPressed,
      foregroundColor: foregroundColor,
      hoverForegroundColor: hoverForegroundColor,
      hoverBackgroundColor:
          hoverBackgroundColor ?? calendarPrimaryColor.withValues(alpha: 0.08),
      child: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: calendarSpacing4),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Destructive-styled button for delete flows in calendar forms.
class TaskDestructiveButton extends StatelessWidget {
  const TaskDestructiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
    this.icon,
    this.size = ShadButtonSize.sm,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final ShadButtonSize size;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isBusy || onPressed == null;
    return ShadButton.destructive(
      size: size,
      onPressed: disabled ? null : onPressed,
      child: isBusy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: calendarSpacing4),
                ],
                Text(label),
              ],
            ),
    );
  }
}

/// Shared multiline description field used across calendar task editors. Keeps
/// padding, capitalization, and sizing consistent while allowing callers to
/// tweak labels or styling when necessary.
class TaskDescriptionField extends StatelessWidget {
  const TaskDescriptionField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText,
    this.hintText = 'Description (optional)',
    this.minLines = 3,
    this.maxLines,
    this.textCapitalization = TextCapitalization.sentences,
    this.autofocus = false,
    this.onChanged,
    this.borderRadius,
    this.focusBorderColor,
    this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String hintText;
  final int minLines;
  final int? maxLines;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final double? borderRadius;
  final Color? focusBorderColor;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return TaskTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: labelText,
      hintText: hintText,
      minLines: minLines,
      maxLines: maxLines ?? minLines,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      onChanged: onChanged,
      borderRadius: borderRadius,
      focusBorderColor: focusBorderColor,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: calendarSpacing16,
            vertical: calendarSpacing12,
          ),
    );
  }
}

/// Shared single-line location field for task editors. Applies consistent
/// padding and defaults while allowing callers to override styling knobs.
class TaskLocationField extends StatelessWidget {
  const TaskLocationField({
    super.key,
    required this.controller,
    this.focusNode,
    this.labelText,
    this.hintText = 'Location (optional)',
    this.textCapitalization = TextCapitalization.words,
    this.autofocus = false,
    this.onChanged,
    this.borderRadius,
    this.focusBorderColor,
    this.contentPadding,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? labelText;
  final String hintText;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final double? borderRadius;
  final Color? focusBorderColor;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return TaskTextField(
      controller: controller,
      focusNode: focusNode,
      labelText: labelText,
      hintText: hintText,
      minLines: 1,
      maxLines: 1,
      textCapitalization: textCapitalization,
      autofocus: autofocus,
      onChanged: onChanged,
      borderRadius: borderRadius,
      focusBorderColor: focusBorderColor,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: calendarSpacing16,
            vertical: calendarSpacing12,
          ),
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
