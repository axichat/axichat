import 'package:hive_flutter/hive_flutter.dart';

import '../models/calendar_model.dart';

/// Legacy helper retained for backward compatibility with older tests.
class GuestCalendarStorage {
  GuestCalendarStorage._();

  static const String _boxName = 'guest_calendar';
  static Box<CalendarModel>? _box;

  static Future<Box<CalendarModel>> openBox() async {
    _box ??= await Hive.openBox<CalendarModel>(_boxName);
    return _box!;
  }

  static Future<void> saveCalendar(CalendarModel calendar) async {
    final box = await openBox();
    await box.put('calendar', calendar);
  }

  static Future<CalendarModel?> loadCalendar() async {
    final box = await openBox();
    return box.get('calendar');
  }

  static Future<void> clearGuestData() async {
    final box = await openBox();
    await box.clear();
  }
}
