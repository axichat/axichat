// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/calendar/view/tasks/calendar_checkbox.dart';
import 'package:axichat/src/common/ui/ui.dart';

class PriorityCheckboxTile extends StatelessWidget {
  const PriorityCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.onChanged,
    this.isIndeterminate = false,
    this.highlightWhenActive = true,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;
  final bool isIndeterminate;
  final bool highlightWhenActive;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onChanged != null;
    final bool isActive = value || isIndeterminate;
    final bool showActiveChrome = highlightWhenActive && isActive;
    final Color backgroundColor = highlightWhenActive
        ? showActiveChrome
              ? color.withValues(alpha: context.motion.tapHoverAlpha)
              : calendarContainerColor
        : Colors.transparent;
    final Color borderColor = showActiveChrome ? color : calendarBorderColor;
    final Color checkboxBorderColor = isActive ? color : calendarBorderColor;
    final Color textColor = showActiveChrome ? color : calendarTitleColor;
    final bool showShadow = showActiveChrome;
    final double baseBorderWidth = context.borderSide.width;
    final double borderWidth = showActiveChrome
        ? baseBorderWidth + baseBorderWidth
        : baseBorderWidth;
    final bool? checkboxValue = isIndeterminate ? null : value;
    final RoundedSuperellipseBorder decoratedShape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.circular(context.radii.squircle),
      side: BorderSide(color: borderColor, width: borderWidth),
    );

    return Semantics(
      container: true,
      label: label,
      checked: checkboxValue ?? false,
      mixed: isIndeterminate,
      enabled: isEnabled,
      onTap: isEnabled ? () => onChanged!(!value) : null,
      child: AxiTapBounce(
        enabled: isEnabled,
        child: ShadFocusable(
          canRequestFocus: isEnabled,
          builder: (context, _, _) {
            return Material(
              type: MaterialType.transparency,
              shape: decoratedShape,
              clipBehavior: Clip.antiAlias,
              child: ShadGestureDetector(
                cursor: isEnabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                onTap: isEnabled ? () => onChanged!(!value) : null,
                child: AnimatedContainer(
                  duration: calendarSidebarToggleDuration,
                  curve: Curves.easeOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: context.spacing.s,
                    vertical: context.spacing.xs,
                  ),
                  decoration: ShapeDecoration(
                    color: backgroundColor,
                    shape: decoratedShape,
                    shadows: showShadow ? calendarLightShadow : const [],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: context.sizing.inputSuffixButtonSize,
                        height: context.sizing.inputSuffixButtonSize,
                        child: Center(
                          child: CalendarCheckbox(
                            value: value,
                            isIndeterminate: isIndeterminate,
                            onChanged: onChanged,
                            activeColor: color,
                            borderColor: checkboxBorderColor,
                            visualSize: context.sizing.inputSuffixIconSize,
                            tapTargetSize: context.sizing.inputSuffixButtonSize,
                          ),
                        ),
                      ),
                      SizedBox(width: context.spacing.xs),
                      Expanded(
                        child: Text(
                          label,
                          style: context.textTheme.small
                              .strongIf(showActiveChrome)
                              .copyWith(color: textColor),
                        ),
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
  }
}
