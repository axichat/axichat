import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAlarm> _emptyAlarms = <CalendarAlarm>[];

CalendarIcsMeta? applyIcsMetaOverrides({
  required CalendarIcsMeta? base,
  CalendarIcsStatus? status,
  CalendarTransparency? transparency,
  List<String>? categories,
  String? url,
  CalendarGeo? geo,
  List<CalendarAlarm>? alarms,
}) {
  if (base == null) {
    if (status == null &&
        transparency == null &&
        categories == null &&
        url == null &&
        geo == null &&
        alarms == null) {
      return null;
    }
    return CalendarIcsMeta(
      status: status,
      transparency: transparency,
      categories: categories ?? _emptyCategories,
      url: url,
      geo: geo,
      alarms: alarms ?? _emptyAlarms,
    );
  }
  return base.copyWith(
    status: status,
    transparency: transparency,
    categories: categories ?? base.categories,
    url: url,
    geo: geo,
    alarms: alarms ?? base.alarms,
  );
}

List<String>? resolveCategoryOverride({
  required CalendarIcsMeta? base,
  required List<String> categories,
}) {
  if (base == null && categories.isEmpty) {
    return null;
  }
  return categories;
}

List<CalendarAlarm>? resolveAlarmOverride({
  required CalendarIcsMeta? base,
  required List<CalendarAlarm> alarms,
}) {
  if (base == null && alarms.isEmpty) {
    return null;
  }
  return alarms;
}
