import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../../common/ui/ui.dart';
import '../priority_checkbox_tile.dart';
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

/// Primary calendar action button (e.g., Add/Save) with consistent sizing and
/// hover behaviour.
class TaskPrimaryButton extends StatelessWidget {
  const TaskPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isBusy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    return ShadButton(
      size: ShadButtonSize.sm,
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
          : Text(label),
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
