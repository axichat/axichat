import 'package:flutter/material.dart';

/// Shared checkbox used by calendar controls to keep a smaller visual while
/// maintaining the full 48x48 accessible tap target.
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
    final bool? checkboxValue = isIndeterminate ? null : value;
    final bool isEnabled = onChanged != null;
    const double baseSize = 20;
    final double clampedVisualSize = visualSize.clamp(16, 22);
    final double visualScale = (clampedVisualSize / baseSize) - 1;
    final double borderWidth = isIndeterminate ? 2 : (value ? 2 : 1.5);

    return MouseRegion(
      cursor: isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: SizedBox(
        width: kMinInteractiveDimension,
        height: kMinInteractiveDimension,
        child: Checkbox(
          value: checkboxValue,
          tristate: isIndeterminate,
          onChanged:
              isEnabled ? (checked) => onChanged!(checked ?? false) : null,
          materialTapTargetSize: MaterialTapTargetSize.padded,
          visualDensity: VisualDensity(
            horizontal: visualScale,
            vertical: visualScale,
          ),
          activeColor: activeColor,
          checkColor: Colors.white,
          mouseCursor:
              isEnabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          side: BorderSide(
            color: isEnabled ? borderColor : borderColor.withValues(alpha: 0.6),
            width: borderWidth,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
