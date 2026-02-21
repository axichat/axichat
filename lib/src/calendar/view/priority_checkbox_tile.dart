// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'widgets/calendar_checkbox.dart';

class PriorityCheckboxTile extends StatelessWidget {
  const PriorityCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.onChanged,
    this.isIndeterminate = false,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool>? onChanged;
  final bool isIndeterminate;

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onChanged != null;
    final bool isActive = value || isIndeterminate;
    final backgroundColor = isActive
        ? color.withValues(alpha: 0.08)
        : calendarContainerColor;
    final borderColor = isActive ? color : calendarBorderColor;
    final Color textColor = isActive ? color : calendarTitleColor;
    final bool showShadow = isActive;
    final double baseBorderWidth = context.borderSide.width;
    final double borderWidth = isIndeterminate || value
        ? baseBorderWidth * 2
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
                    horizontal: context.spacing.m,
                    vertical: context.spacing.s,
                  ),
                  decoration: ShapeDecoration(
                    color: backgroundColor,
                    shape: decoratedShape,
                    shadows: showShadow ? calendarLightShadow : const [],
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: calendarCheckboxTapTarget,
                        height: calendarCheckboxTapTarget,
                        child: Center(
                          child: CalendarCheckbox(
                            value: value,
                            isIndeterminate: isIndeterminate,
                            onChanged: onChanged,
                            activeColor: color,
                            borderColor: borderColor,
                            visualSize: calendarCheckboxTapTarget / 2,
                          ),
                        ),
                      ),
                      SizedBox(width: context.spacing.s),
                      Expanded(
                        child: Text(
                          label,
                          style: context.textTheme.small
                              .strongIf(isActive)
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
