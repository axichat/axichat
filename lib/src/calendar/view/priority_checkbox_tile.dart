// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

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
    final backgroundColor =
        isActive ? color.withValues(alpha: 0.08) : calendarContainerColor;
    final borderColor = isActive ? color : calendarBorderColor;
    final Color textColor = isActive ? color : calendarTitleColor;
    final Color disabledColor = calendarSubtitleColor;
    final bool showShadow = isActive && isEnabled;
    final double borderWidth = isIndeterminate ? 2 : (value ? 2 : 1);
    final bool? checkboxValue = isIndeterminate ? null : value;

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: Semantics(
        container: true,
        label: label,
        checked: checkboxValue ?? false,
        mixed: isIndeterminate,
        enabled: isEnabled,
        onTap: isEnabled ? () => onChanged!(!value) : null,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? () => onChanged!(!value) : null,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(
                horizontal: calendarGutterMd,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isEnabled ? borderColor : calendarBorderColor,
                  width: borderWidth,
                ),
                boxShadow: showShadow
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.16),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : const [],
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
                        borderColor:
                            isEnabled ? borderColor : calendarBorderColor,
                        visualSize: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: calendarFormGap),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isActive ? FontWeight.w600 : FontWeight.w500,
                        color: isEnabled ? textColor : disabledColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
