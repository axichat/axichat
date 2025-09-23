import 'package:flutter/material.dart';

import 'calendar_widget.dart';

class GuestCalendarWidget extends StatelessWidget {
  const GuestCalendarWidget({super.key});

  @override
  Widget build(BuildContext context) =>
      const CalendarScaffold(title: 'Guest Calendar');
}
