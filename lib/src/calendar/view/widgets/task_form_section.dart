// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:axichat/src/localization/localization_extensions.dart';
import 'package:axichat/src/calendar/utils/location_autocomplete.dart';
import 'package:axichat/src/calendar/view/priority_checkbox_tile.dart';
import 'recurrence_editor.dart';
import 'schedule_range_fields.dart';
import 'task_text_field.dart';

const double _taskFormActionIconSize = 16.0;

/// Standard section title used across the calendar task forms. Keeps typography
/// and spacing consistent while allowing trailing actions or custom padding.
class TaskSectionHeader extends StatelessWidget {
  const TaskSectionHeader({
    super.key,
    required this.title,
    this.padding = EdgeInsets.zero,
    this.textStyle,
    this.trailing,
    this.uppercase = true,
  });

  final String title;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;
  final Widget? trailing;
  final bool uppercase;
  static const double _headerFontSize = 10;
  static const double _headerLetterSpacing = 0.6;

  @override
  Widget build(BuildContext context) {
    final style = textStyle ??
        calendarTimeLabelTextStyle.copyWith(
          fontSize: _headerFontSize,
          fontWeight: FontWeight.w600,
          color: calendarSubtitleColor,
          letterSpacing: _headerLetterSpacing,
        );
    final String displayTitle = uppercase ? title.toUpperCase() : title;

    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              displayTitle,
              style: style,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: calendarGutterSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Expandable task form section with a toggleable header and animated body.
class TaskSectionExpander extends StatelessWidget {
  const TaskSectionExpander({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    this.badge,
    this.uppercase = true,
    this.enabled = true,
    this.collapsedHint,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Widget child;
  final Widget? badge;
  final bool uppercase;
  final bool enabled;
  final Widget? collapsedHint;

  @override
  Widget build(BuildContext context) {
    final Widget trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (badge != null) ...[
          badge!,
          const SizedBox(width: calendarInsetSm),
        ],
        Icon(
          isExpanded ? Icons.expand_less : Icons.expand_more,
          size: calendarGutterLg,
          color: calendarSubtitleColor,
        ),
      ],
    );
    final Widget header = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onToggle : null,
        borderRadius: BorderRadius.circular(calendarBorderRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: calendarInsetSm),
          child: SizedBox(
            width: double.infinity,
            child: TaskSectionHeader(
              title: title,
              uppercase: uppercase,
              trailing: trailing,
            ),
          ),
        ),
      ),
    );
    final Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isExpanded) ...[
          const SizedBox(height: calendarGutterSm),
          IgnorePointer(
            ignoring: !enabled,
            child: child,
          ),
        ] else if (collapsedHint != null) ...[
          const SizedBox(height: calendarGutterSm),
          collapsedHint!,
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
        AxiAnimatedSize(
          duration: baseAnimationDuration,
          curve: Curves.easeInOutCubic,
          alignment: Alignment.topCenter,
          child: body,
        ),
      ],
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
    this.spacing = calendarGutterMd,
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
            label: context.l10n.calendarImportant,
            value: isImportant,
            color: calendarSuccessColor,
            isIndeterminate: isImportantIndeterminate,
            onChanged: onImportantChanged,
          ),
        ),
        SizedBox(width: spacing),
        Expanded(
          child: PriorityCheckboxTile(
            label: context.l10n.calendarUrgent,
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
class TaskTextFormField extends StatefulWidget {
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
    this.errorText,
    this.errorStyle,
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
  final String? errorText;
  final TextStyle? errorStyle;

  @override
  State<TaskTextFormField> createState() => _TaskTextFormFieldState();
}

class _TaskTextFormFieldState extends State<TaskTextFormField> {
  final GlobalKey<FormFieldState<String>> _fieldKey =
      GlobalKey<FormFieldState<String>>();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant TaskTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
      _fieldKey.currentState?.didChange(widget.controller.text);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    _fieldKey.currentState?.didChange(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final double radius = widget.borderRadius ?? 8;
    final Color focusedColor = widget.focusBorderColor ?? calendarPrimaryColor;
    final Color effectiveFill = widget.fillColor ?? calendarContainerColor;

    return FormField<String>(
      key: _fieldKey,
      initialValue: widget.controller.text,
      validator: widget.validator,
      onSaved: widget.onSaved,
      autovalidateMode: widget.autovalidateMode,
      enabled: widget.enabled,
      builder: (state) {
        final String? errorText = widget.errorText ?? state.errorText;
        return AxiTextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textCapitalization: widget.textCapitalization,
          textInputAction: widget.textInputAction,
          autofocus: widget.autofocus,
          onChanged: (value) {
            state.didChange(value);
            widget.onChanged?.call(value);
          },
          onSubmitted: widget.onFieldSubmitted,
          style: widget.textStyle ??
              TextStyle(
                color: calendarTitleColor,
                fontSize: 14,
              ),
          decoration: InputDecoration(
            labelText: widget.labelText,
            labelStyle: widget.labelStyle ??
                TextStyle(
                  color: calendarSubtitleColor,
                  fontSize: 14,
                ),
            hintText: widget.hintText,
            hintStyle: widget.hintStyle ??
                TextStyle(
                  color: calendarTimeLabelColor,
                  fontSize: 14,
                ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: calendarBorderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: calendarBorderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(radius),
              borderSide: BorderSide(color: focusedColor, width: 2),
            ),
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: calendarGutterMd,
                  vertical: calendarGutterMd,
                ),
            filled: true,
            fillColor: effectiveFill,
            errorText: errorText,
            errorStyle: widget.errorStyle,
          ),
        );
      },
    );
  }
}

/// Shared task title field that matches the sidebar styling and supports
/// validation for modal forms.
class TaskTitleField extends StatelessWidget {
  const TaskTitleField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText = 'Task title',
    this.labelText,
    this.textInputAction,
    this.autofocus = false,
    this.enabled = true,
    this.validator,
    this.autovalidateMode,
    this.onChanged,
    this.onSubmitted,
    this.errorText,
    this.errorStyle,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String hintText;
  final String? labelText;
  final TextInputAction? textInputAction;
  final bool autofocus;
  final bool enabled;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final String? errorText;
  final TextStyle? errorStyle;

  @override
  Widget build(BuildContext context) {
    return TaskTextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      labelText: labelText,
      hintText: hintText,
      textCapitalization: TextCapitalization.sentences,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      enabled: enabled,
      validator: validator,
      autovalidateMode: autovalidateMode,
      borderRadius: calendarBorderRadius,
      focusBorderColor: calendarPrimaryColor,
      contentPadding: calendarFieldPadding,
      errorText: errorText,
      errorStyle: errorStyle,
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
    final bool allowPress = enabled && onPressed != null;
    final button = ShadButton.outline(
      size: ShadButtonSize.sm,
      onPressed: allowPress ? onPressed : null,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16),
            const SizedBox(width: calendarInsetMd),
          ],
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ).withTapBounce(enabled: allowPress);
    return button;
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
    ).withTapBounce();
    return tooltip == null
        ? button
        : AxiTooltip(
            builder: (_) => Text(tooltip!),
            child: button,
          );
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
    this.spacing = calendarGutterSm,
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
    this.enabled = true,
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
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool hasSelection = start != null || end != null;
    final bool allowClear = enabled && hasSelection;
    final VoidCallback? clearHandler = allowClear
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
        trailingChildren.add(const SizedBox(width: calendarInsetMd));
      }
      trailingChildren.add(
        TaskGhostIconButton(
          icon: Icons.close,
          tooltip: context.l10n.calendarClearSchedule,
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
            enabled: enabled,
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
    this.spacing = calendarGutterSm,
    this.padding = EdgeInsets.zero,
    this.headerStyle,
    this.headerTrailing,
    this.enabled = true,
    this.fallbackWeekday,
    this.referenceStart,
    this.spacingConfig = const RecurrenceEditorSpacing(
      chipSpacing: 6,
      chipRunSpacing: 6,
      weekdaySpacing: 10,
      advancedSectionSpacing: 12,
      endSpacing: 14,
      fieldGap: 12,
    ),
    this.showAdvancedToggle = true,
    this.forceAdvanced = false,
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
  final DateTime? referenceStart;
  final RecurrenceEditorSpacing spacingConfig;
  final bool showAdvancedToggle;
  final bool forceAdvanced;
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
            referenceStart: referenceStart,
            spacing: spacingConfig,
            showAdvancedToggle: showAdvancedToggle,
            forceAdvanced: forceAdvanced,
            chipPadding: chipPadding ??
                const EdgeInsets.symmetric(
                    horizontal: calendarGutterMd, vertical: calendarGutterSm),
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
    this.gap = calendarGutterSm,
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
      Expanded(
        child: _TaskDateTimeToolbarFields(
          primaryField: primaryField,
          secondaryField: secondaryField,
          buttonGap: gap,
        ),
      ),
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
}

class _TaskDateTimeToolbarFields extends StatelessWidget {
  const _TaskDateTimeToolbarFields({
    required this.primaryField,
    required this.buttonGap,
    this.secondaryField,
  });

  final TaskDateTimeToolbarField primaryField;
  final TaskDateTimeToolbarField? secondaryField;
  final double buttonGap;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      ..._buttonsForField(primaryField),
      if (secondaryField != null) ..._buttonsForField(secondaryField!),
    ];

    return Row(children: _withGap(buttons));
  }

  List<Widget> _buttonsForField(TaskDateTimeToolbarField field) {
    final widgets = <Widget>[
      _TaskDateTimeToolbarButton(
          field: field, type: _TaskDateTimeButtonType.date),
    ];
    if (field.showTimeButton) {
      widgets.add(
        _TaskDateTimeToolbarButton(
            field: field, type: _TaskDateTimeButtonType.time),
      );
    }
    return widgets;
  }

  List<Widget> _withGap(List<Widget> source) {
    if (source.length <= 1 || buttonGap <= 0) {
      return source;
    }
    final spaced = <Widget>[];
    for (var i = 0; i < source.length; i++) {
      if (i != 0) {
        spaced.add(SizedBox(width: buttonGap));
      }
      spaced.add(source[i]);
    }
    return spaced;
  }
}

enum _TaskDateTimeButtonType { date, time }

class _TaskDateTimeToolbarButton extends StatelessWidget {
  const _TaskDateTimeToolbarButton({
    required this.field,
    required this.type,
  });

  final TaskDateTimeToolbarField field;
  final _TaskDateTimeButtonType type;

  @override
  Widget build(BuildContext context) {
    final bool isTime = type == _TaskDateTimeButtonType.time;
    final String label =
        isTime ? field.timeLabel(context) : field.dateLabel(context);
    final IconData icon = isTime ? field.timeIcon : field.dateIcon;
    final VoidCallback onPressed =
        isTime ? field.onSelectTime : field.onSelectDate;

    return Expanded(
      child: TaskToolbarButton(
        icon: icon,
        label: label,
        onPressed: field.enabled ? onPressed : null,
        enabled: field.enabled,
      ),
    );
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
    final bool disabled = isBusy || onPressed == null;
    final colors = context.colorScheme;
    final foreground = colors.primaryForeground;
    final spinner = SizedBox.square(
      dimension: _taskFormActionIconSize,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation<Color>(foreground),
      ),
    );
    return ShadButton(
      size: size,
      backgroundColor: calendarPrimaryColor,
      hoverBackgroundColor: calendarPrimaryHoverColor,
      foregroundColor: foreground,
      hoverForegroundColor: foreground,
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ButtonSpinnerSlot(
            isVisible: isBusy,
            spinner: spinner,
            slotSize: _taskFormActionIconSize,
            gap: calendarInsetMd,
            duration: baseAnimationDuration,
          ),
          if (!isBusy && icon != null) ...[
            Icon(icon, size: _taskFormActionIconSize),
            const SizedBox(width: calendarInsetMd),
          ],
          Text(label),
        ],
      ),
    ).withTapBounce(enabled: !disabled);
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
    this.foregroundColor,
    this.hoverForegroundColor,
    this.hoverBackgroundColor,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;
  final IconData? icon;
  final ShadButtonSize size;
  final Color? foregroundColor;
  final Color? hoverForegroundColor;
  final Color? hoverBackgroundColor;

  @override
  Widget build(BuildContext context) {
    final bool disabled = isBusy || onPressed == null;
    final Color resolvedForeground = foregroundColor ?? calendarSubtitleColor;
    const spinner = SizedBox.square(
      dimension: _taskFormActionIconSize,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    return ShadButton.outline(
      size: size,
      onPressed: disabled ? null : onPressed,
      foregroundColor: resolvedForeground,
      hoverForegroundColor: hoverForegroundColor ?? calendarPrimaryColor,
      hoverBackgroundColor:
          hoverBackgroundColor ?? calendarPrimaryColor.withValues(alpha: 0.08),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButtonSpinnerSlot(
            isVisible: isBusy,
            spinner: spinner,
            slotSize: _taskFormActionIconSize,
            gap: calendarInsetMd,
            duration: baseAnimationDuration,
          ),
          if (!isBusy && icon != null) ...[
            Icon(icon, size: _taskFormActionIconSize),
            const SizedBox(width: calendarInsetMd),
          ],
          Text(label),
        ],
      ),
    ).withTapBounce(enabled: !disabled);
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
    const spinner = SizedBox.square(
      dimension: _taskFormActionIconSize,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
    return ShadButton.destructive(
      size: size,
      onPressed: disabled ? null : onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ButtonSpinnerSlot(
            isVisible: isBusy,
            spinner: spinner,
            slotSize: _taskFormActionIconSize,
            gap: calendarInsetMd,
            duration: baseAnimationDuration,
          ),
          if (!isBusy && icon != null) ...[
            Icon(icon, size: _taskFormActionIconSize),
            const SizedBox(width: calendarInsetMd),
          ],
          Text(label),
        ],
      ),
    ).withTapBounce(enabled: !disabled);
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
    this.enabled = true,
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
  final bool enabled;
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
      enabled: enabled,
      borderRadius: borderRadius,
      focusBorderColor: focusBorderColor,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: calendarGutterLg,
            vertical: calendarGutterMd,
          ),
    );
  }
}

/// Shared single-line location field for task editors. Applies consistent
/// padding and defaults while allowing callers to override styling knobs.
class TaskLocationField extends StatefulWidget {
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
    this.autocomplete,
    this.autocompleteLimit = 6,
    this.enabled = true,
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
  final LocationAutocompleteHelper? autocomplete;
  final int autocompleteLimit;
  final bool enabled;

  @override
  State<TaskLocationField> createState() => _TaskLocationFieldState();
}

class _TaskLocationFieldState extends State<TaskLocationField> {
  FocusNode? _focusNode;

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _focusNode!;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _focusNode = FocusNode();
    }
  }

  @override
  void dispose() {
    _focusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final helper = widget.autocomplete;
    if (helper == null || !widget.enabled) {
      return _TaskLocationTextInput(
        controller: widget.controller,
        focusNode: _effectiveFocusNode,
        labelText: widget.labelText,
        hintText: widget.hintText,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
        borderRadius: widget.borderRadius,
        focusBorderColor: widget.focusBorderColor,
        contentPadding: widget.contentPadding,
      );
    }

    return RawAutocomplete<LocationSuggestion>(
      focusNode: _effectiveFocusNode,
      textEditingController: widget.controller,
      displayStringForOption: (option) => option.label,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trimLeft();
        if (query.length < 2) {
          return const Iterable<LocationSuggestion>.empty();
        }
        return helper.search(query, limit: widget.autocompleteLimit);
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return _TaskLocationTextInput(
          controller: textController,
          focusNode: focusNode,
          labelText: widget.labelText,
          hintText: widget.hintText,
          textCapitalization: widget.textCapitalization,
          autofocus: widget.autofocus,
          onChanged: widget.onChanged,
          onSubmitted: (_) => onFieldSubmitted(),
          enabled: widget.enabled,
          borderRadius: widget.borderRadius,
          focusBorderColor: widget.focusBorderColor,
          contentPadding: widget.contentPadding,
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240, minWidth: 220),
              child: ListView.separated(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemBuilder: (context, index) {
                  final suggestion = list[index];
                  return ListTile(
                    dense: true,
                    horizontalTitleGap: 8,
                    onTap: () {
                      onSelected(suggestion);
                      widget.onChanged?.call(suggestion.label);
                    },
                    title: Text(
                      suggestion.label,
                      style: TextStyle(
                        fontSize: 13,
                        color: calendarTitleColor,
                      ),
                    ),
                    subtitle: Text(
                      suggestion.isHistory ? 'From your tasks' : 'Suggested',
                      style: TextStyle(
                        fontSize: 11,
                        color: calendarSubtitleColor,
                      ),
                    ),
                  );
                },
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: calendarBorderColor,
                ),
                itemCount: list.length,
              ),
            ),
          ),
        );
      },
      onSelected: (selection) {
        widget.onChanged?.call(selection.label);
      },
    );
  }
}

class _TaskLocationTextInput extends StatelessWidget {
  const _TaskLocationTextInput({
    required this.controller,
    required this.focusNode,
    required this.labelText,
    required this.hintText,
    required this.textCapitalization,
    required this.autofocus,
    required this.onChanged,
    required this.enabled,
    required this.borderRadius,
    required this.focusBorderColor,
    required this.contentPadding,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? labelText;
  final String hintText;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final double? borderRadius;
  final Color? focusBorderColor;
  final EdgeInsetsGeometry? contentPadding;
  final ValueChanged<String>? onSubmitted;

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
      onSubmitted: onSubmitted,
      enabled: enabled,
      borderRadius: borderRadius,
      focusBorderColor: focusBorderColor,
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: calendarGutterLg,
            vertical: calendarGutterMd,
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
    this.padding = calendarPaddingLg,
    this.includeTopBorder = false,
    this.borderColor,
    this.backgroundColor = Colors.transparent,
    this.gap,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final bool includeTopBorder;
  final Color? borderColor;
  final Color backgroundColor;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final Color resolvedBorderColor = borderColor ?? calendarBorderColor;
    final decoration = includeTopBorder
        ? BoxDecoration(
            color: backgroundColor,
            border: Border(
              top: BorderSide(color: resolvedBorderColor, width: 1),
            ),
          )
        : BoxDecoration(color: backgroundColor);

    return Container(
      padding: padding,
      decoration: decoration,
      child: _TaskFormActionsLayout(
        gap: gap,
        children: children,
      ),
    );
  }
}

class _TaskFormActionsLayout extends StatelessWidget {
  const _TaskFormActionsLayout({
    required this.children,
    required this.gap,
  });

  final List<Widget> children;
  final double? gap;

  @override
  Widget build(BuildContext context) {
    final bool usesFlex = children.any(
      (widget) => widget is Expanded || widget is Flexible || widget is Spacer,
    );
    final double spacing = gap ?? 0;
    if (usesFlex) {
      return Row(
        mainAxisSize: MainAxisSize.max,
        children: gap == null ? children : _withGap(children, spacing),
      );
    }
    return Wrap(
      spacing: spacing,
      runSpacing: spacing > 0 ? spacing / 2 : 0,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: children,
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
