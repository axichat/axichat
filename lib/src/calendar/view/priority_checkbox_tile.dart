import 'package:flutter/material.dart';

import '../../common/ui/ui.dart';

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
        isActive ? color.withValues(alpha: 0.08) : Colors.white;
    final borderColor = isActive ? color : calendarBorderColor;
    final Color textColor = isActive ? color : calendarTitleColor;
    const Color disabledColor = calendarSubtitleColor;
    final bool showShadow = isActive && isEnabled;
    final double borderWidth = isIndeterminate ? 2 : (value ? 2 : 1);
    final bool tristate = isIndeterminate;
    final bool? checkboxValue = isIndeterminate ? null : value;

    return InkWell(
      onTap: isEnabled ? () => onChanged!(!value) : null,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
            horizontal: calendarGutterMd, vertical: 10),
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
            Checkbox(
              value: checkboxValue,
              tristate: tristate,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: color,
              checkColor: Colors.white,
              side: BorderSide(
                color: isEnabled ? borderColor : calendarBorderColor,
                width: borderWidth,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged:
                  isEnabled ? (checked) => onChanged!(checked ?? false) : null,
            ),
            const SizedBox(width: calendarFormGap),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isEnabled ? textColor : disabledColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
