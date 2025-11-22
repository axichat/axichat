import 'package:flutter/material.dart';

import 'package:axichat/src/common/ui/ui.dart';
import 'calendar_checkbox.dart';

class CalendarCompletionCheckbox extends StatelessWidget {
  const CalendarCompletionCheckbox({
    super.key,
    required this.value,
    this.isIndeterminate = false,
    this.onChanged,
    this.size = 18,
  });

  final bool value;
  final bool isIndeterminate;
  final ValueChanged<bool>? onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CalendarCheckbox(
      value: value,
      isIndeterminate: isIndeterminate,
      onChanged: onChanged,
      activeColor: calendarPrimaryColor,
      borderColor: calendarPrimaryColor,
      visualSize: size,
    );
  }
}
