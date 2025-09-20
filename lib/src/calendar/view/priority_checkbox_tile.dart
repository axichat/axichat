import 'package:flutter/material.dart';

import '../../common/ui/ui.dart';

class PriorityCheckboxTile extends StatelessWidget {
  const PriorityCheckboxTile({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color color;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final backgroundColor =
        value ? color.withValues(alpha: 0.08) : Colors.white;
    final borderColor = value ? color : calendarBorderColor;

    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: value ? 2 : 1),
          boxShadow: value
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
              value: value,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
              activeColor: color,
              checkColor: Colors.white,
              side: BorderSide(
                color: borderColor,
                width: value ? 2 : 1,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              onChanged: (checked) => onChanged(checked ?? false),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: value ? FontWeight.w600 : FontWeight.w500,
                  color: value ? color : calendarTitleColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
