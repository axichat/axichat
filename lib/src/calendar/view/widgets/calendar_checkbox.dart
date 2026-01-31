// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/app.dart';
import 'package:axichat/src/common/ui/ui.dart';
import 'package:flutter/material.dart';

/// Shared checkbox used by calendar controls to keep a compact visual while
/// still providing a comfortable tap target inside the surrounding tile.
class CalendarCheckbox extends StatelessWidget {
  const CalendarCheckbox({
    super.key,
    required this.value,
    required this.activeColor,
    required this.borderColor,
    this.isIndeterminate = false,
    this.onChanged,
    this.visualSize = 18,
  });

  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;
  final Color borderColor;
  final double visualSize;

  @override
  Widget build(BuildContext context) {
    final colors = context.colorScheme;
    final bool? checkboxValue = isIndeterminate ? null : value;
    final bool isEnabled = onChanged != null;
    const double baseSize = 20;
    final double clampedVisualSize = visualSize.clamp(16, 22);
    final double visualScale = (clampedVisualSize / baseSize) - 1;
    final double borderWidth = isIndeterminate ? 2 : (value ? 2 : 1.5);
    final Brightness activeBrightness =
        ThemeData.estimateBrightnessForColor(activeColor);
    final Color checkColor = activeBrightness == Brightness.dark
        ? colors.background
        : colors.foreground;
    final fillColor = WidgetStateProperty.resolveWith<Color?>(
      (states) => states.contains(WidgetState.selected)
          ? activeColor
          : Colors.transparent,
    );

    return SizedBox(
      width: calendarCheckboxTapTarget,
      height: calendarCheckboxTapTarget,
      child: Checkbox(
        value: checkboxValue,
        tristate: isIndeterminate,
        onChanged: isEnabled ? (checked) => onChanged!(checked ?? false) : null,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity(
          horizontal: visualScale,
          vertical: visualScale,
        ),
        activeColor: activeColor,
        fillColor: fillColor,
        checkColor: checkColor,
        mouseCursor:
            isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
    );
  }
}
