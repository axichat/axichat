import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';

class CalendarCompletionCheckbox extends StatelessWidget {
  const CalendarCompletionCheckbox({
    super.key,
    required this.value,
    this.isIndeterminate = false,
    this.onChanged,
    this.size = 20,
  });

  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool? checkboxValue = isIndeterminate ? null : value;
    final bool isEnabled = onChanged != null;
    final Color activeColor = calendarPrimaryColor;
    final Color borderColor =
        isEnabled ? activeColor : calendarBorderColor.withValues(alpha: 0.6);
    final double borderWidth = value ? 2 : 1.5;
    final double effectiveBorderWidth = isIndeterminate ? 2 : borderWidth;

    const double tapPadding = 24;
    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isEnabled ? () => onChanged!(!value) : null,
        child: SizedBox(
          width: size + tapPadding,
          height: size + tapPadding,
          child: Center(
            child: SizedBox(
              width: size,
              height: size,
              child: Checkbox(
                value: checkboxValue,
                tristate: isIndeterminate,
                onChanged: isEnabled
                    ? (checked) => onChanged!(checked ?? false)
                    : null,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                activeColor: activeColor,
                checkColor: Colors.white,
                mouseCursor: isEnabled
                    ? SystemMouseCursors.click
                    : SystemMouseCursors.basic,
                side: BorderSide(
                  color: borderColor,
                  width: effectiveBorderWidth,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
