abstract class CalendarConfig {
  bool get useNewCalendar;
}

class EnvCalendarConfig implements CalendarConfig {
  const EnvCalendarConfig({bool? override})
      : _override = override ?? const bool.fromEnvironment('CALENDAR2');

  final bool _override;

  @override
  bool get useNewCalendar => _override;
}

class TestCalendarConfig implements CalendarConfig {
  const TestCalendarConfig({required this.useNewCalendar});

  @override
  final bool useNewCalendar;
}
