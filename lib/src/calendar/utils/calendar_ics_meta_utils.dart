// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';

const List<String> _emptyCategories = <String>[];
const List<CalendarAlarm> _emptyAlarms = <CalendarAlarm>[];
const List<CalendarAttendee> _emptyAttendees = <CalendarAttendee>[];

CalendarIcsMeta? applyIcsMetaOverrides({
  required CalendarIcsMeta? base,
  CalendarIcsStatus? status,
  CalendarTransparency? transparency,
  List<String>? categories,
  String? url,
  CalendarGeo? geo,
  CalendarOrganizer? organizer,
  List<CalendarAttendee>? attendees,
  List<CalendarAlarm>? alarms,
}) {
  if (base == null) {
    if (status == null &&
        transparency == null &&
        categories == null &&
        url == null &&
        geo == null &&
        organizer == null &&
        attendees == null &&
        alarms == null) {
      return null;
    }
    return CalendarIcsMeta(
      status: status,
      transparency: transparency,
      categories: categories ?? _emptyCategories,
      url: url,
      geo: geo,
      organizer: organizer,
      attendees: attendees ?? _emptyAttendees,
      alarms: alarms ?? _emptyAlarms,
    );
  }
  return base.copyWith(
    status: status,
    transparency: transparency,
    categories: categories ?? base.categories,
    url: url,
    geo: geo,
    organizer: organizer,
    attendees: attendees ?? base.attendees,
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

CalendarOrganizer? resolveOrganizerOverride({
  required CalendarIcsMeta? base,
  required CalendarOrganizer? organizer,
}) {
  if (base == null && organizer == null) {
    return null;
  }
  return organizer;
}

List<CalendarAttendee>? resolveAttendeeOverride({
  required CalendarIcsMeta? base,
  required List<CalendarAttendee> attendees,
}) {
  if (base == null && attendees.isEmpty) {
    return null;
  }
  return attendees;
}
