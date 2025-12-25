import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'package:axichat/src/calendar/models/calendar_alarm.dart';
import 'package:axichat/src/calendar/models/calendar_attachment.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_collection.dart';
import 'package:axichat/src/calendar/models/calendar_critical_path.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_ics_raw.dart';
import 'package:axichat/src/calendar/models/calendar_journal.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_participant.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

const String _icsLineBreak = '\r\n';
const int _icsFoldLimit = 75;
const String _icsComponentRoot = 'ROOT';
const String _icsComponentVcalendar = 'VCALENDAR';
const String _icsComponentVevent = 'VEVENT';
const String _icsComponentVtodo = 'VTODO';
const String _icsComponentVjournal = 'VJOURNAL';
const String _icsComponentValarm = 'VALARM';
const String _icsComponentVtimezone = 'VTIMEZONE';
const String _icsComponentVfreebusy = 'VFREEBUSY';
const String _icsComponentVavailability = 'VAVAILABILITY';
const String _icsComponentAvailable = 'AVAILABLE';

const String _icsPropertyBegin = 'BEGIN';
const String _icsPropertyEnd = 'END';
const String _icsPropertyProdId = 'PRODID';
const String _icsPropertyVersion = 'VERSION';
const String _icsPropertyCalScale = 'CALSCALE';
const String _icsPropertyMethod = 'METHOD';
const String _icsPropertyUid = 'UID';
const String _icsPropertyDtStamp = 'DTSTAMP';
const String _icsPropertyCreated = 'CREATED';
const String _icsPropertyLastModified = 'LAST-MODIFIED';
const String _icsPropertySequence = 'SEQUENCE';
const String _icsPropertyStatus = 'STATUS';
const String _icsPropertyClass = 'CLASS';
const String _icsPropertyTransp = 'TRANSP';
const String _icsPropertySummary = 'SUMMARY';
const String _icsPropertyDescription = 'DESCRIPTION';
const String _icsPropertyLocation = 'LOCATION';
const String _icsPropertyDtStart = 'DTSTART';
const String _icsPropertyDtEnd = 'DTEND';
const String _icsPropertyDue = 'DUE';
const String _icsPropertyDuration = 'DURATION';
const String _icsPropertyCategories = 'CATEGORIES';
const String _icsPropertyUrl = 'URL';
const String _icsPropertyGeo = 'GEO';
const String _icsPropertyAttach = 'ATTACH';
const String _icsPropertyOrganizer = 'ORGANIZER';
const String _icsPropertyAttendee = 'ATTENDEE';
const String _icsPropertyPercentComplete = 'PERCENT-COMPLETE';
const String _icsPropertyCompleted = 'COMPLETED';
const String _icsPropertyRelatedTo = 'RELATED-TO';
const String _icsPropertyRrule = 'RRULE';
const String _icsPropertyRdate = 'RDATE';
const String _icsPropertyExdate = 'EXDATE';
const String _icsPropertyExrule = 'EXRULE';
const String _icsPropertyRecurrenceId = 'RECURRENCE-ID';
const String _icsPropertyFreeBusy = 'FREEBUSY';
const String _icsPropertyTzid = 'TZID';
const String _icsPropertyAction = 'ACTION';
const String _icsPropertyTrigger = 'TRIGGER';
const String _icsPropertyRepeat = 'REPEAT';
const String _icsPropertyAck = 'ACKNOWLEDGED';

const String _icsPropertyCalendarName = 'X-WR-CALNAME';
const String _icsPropertyCalendarDescription = 'X-WR-CALDESC';
const String _icsPropertyCalendarTimeZone = 'X-WR-TIMEZONE';
const String _icsPropertyCalendarColor = 'X-APPLE-CALENDAR-COLOR';
const String _icsPropertyCalendarId = 'X-AXICHAT-CALENDAR-ID';
const String _icsPropertyCalendarOwner = 'X-AXICHAT-CALENDAR-OWNER';
const String _icsPropertyCalendarSharing = 'X-AXICHAT-CALENDAR-SHARING';

const String _axiTaskIdProperty = 'X-AXICHAT-ID';
const String _axiPriorityProperty = 'X-AXICHAT-PRIORITY';
const String _axiChecklistProperty = 'X-AXICHAT-CHECKLIST';
const String _axiPathIdProperty = 'X-AXICHAT-PATH-ID';
const String _axiPathOrderProperty = 'X-AXICHAT-PATH-ORDER';
const String _axiScheduleEndProperty = 'X-AXICHAT-SCHEDULE-END';
const String _axiScheduleDurationProperty = 'X-AXICHAT-SCHEDULE-DURATION';

const String _icsParamValue = 'VALUE';
const String _icsParamValueDate = 'DATE';
const String _icsParamTzid = 'TZID';
const String _icsParamRange = 'RANGE';
const String _icsParamRelated = 'RELATED';
const String _icsParamRelType = 'RELTYPE';
const String _icsParamFbType = 'FBTYPE';
const String _icsParamCn = 'CN';
const String _icsParamRole = 'ROLE';
const String _icsParamPartStat = 'PARTSTAT';
const String _icsParamCutype = 'CUTYPE';
const String _icsParamRsvp = 'RSVP';
const String _icsParamDelegatedTo = 'DELEGATED-TO';
const String _icsParamDelegatedFrom = 'DELEGATED-FROM';
const String _icsParamMember = 'MEMBER';
const String _icsParamSentBy = 'SENT-BY';
const String _icsParamDir = 'DIR';
const String _icsParamFmtType = 'FMTTYPE';
const String _icsParamEncoding = 'ENCODING';
const String _icsParamLabel = 'LABEL';

const String _icsValueGregorian = 'GREGORIAN';
const String _icsDefaultVersion = '2.0';
const String _icsDefaultProdId = '-//Axichat//Calendar//EN';
const String _icsUidSuffix = '@axichat';
const String _icsMailtoPrefix = 'mailto:';
const String _icsValueTrue = 'TRUE';
const String _icsValueStart = 'START';
const String _icsValueEnd = 'END';
const String _icsValueSibling = 'SIBLING';
const String _icsValueZ = 'Z';
const String _icsValueT = 'T';
const String _icsValueColon = ':';
const String _icsValueSemicolon = ';';
const String _icsValueComma = ',';
const String _icsValueSpace = ' ';
const String _icsValueSlash = '/';
const String _icsValueBackslash = '\\';
const String _icsValueNewline = '\n';
const String _icsEscapeNewline = 'n';
const String _icsEscapedBackslash = r'\\';
const String _icsEscapedNewline = r'\n';
const String _icsEscapedComma = r'\,';
const String _icsEscapedSemicolon = r'\;';

const String _calendarFallbackName = 'Calendar';
const String _calendarFallbackId = 'calendar';
const String _taskFallbackTitle = 'Untitled task';
const String _eventFallbackTitle = 'Untitled event';
const String _journalFallbackTitle = 'Untitled journal';

const CalendarPrivacyClass _defaultPrivacyClass = CalendarPrivacyClass.private;
const CalendarTransparency _defaultEventTransparency =
    CalendarTransparency.opaque;
const CalendarTransparency _defaultDayEventTransparency =
    CalendarTransparency.transparent;
const CalendarIcsComponentType _defaultTaskComponentType =
    CalendarIcsComponentType.todo;

const int _icsDateLength = 8;
const int _icsDateTimeMinLength = 15;
const int _icsDateTimeShortLength = 13;
const int _icsYearStart = 0;
const int _icsYearEnd = 4;
const int _icsMonthStart = 4;
const int _icsMonthEnd = 6;
const int _icsDayStart = 6;
const int _icsDayEnd = 8;
const int _icsHourStart = 9;
const int _icsHourEnd = 11;
const int _icsMinuteStart = 11;
const int _icsMinuteEnd = 13;
const int _icsSecondStart = 13;
const int _icsSecondEnd = 15;

const int _secondsPerMinute = 60;
const int _minutesPerHour = 60;
const int _hoursPerDay = 24;
const int _daysPerWeek = 7;

const String _icsDurationPattern =
    r'^(-)?P(?:(\d+)W)?(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?)?$';
const int _icsDurationSignGroup = 1;
const int _icsDurationWeeksGroup = 2;
const int _icsDurationDaysGroup = 3;
const int _icsDurationHoursGroup = 4;
const int _icsDurationMinutesGroup = 5;
const int _icsDurationSecondsGroup = 6;

const String _icsDurationPrefix = 'P';
const String _icsDurationTimePrefix = 'T';
const String _icsDurationWeekSuffix = 'W';
const String _icsDurationDaySuffix = 'D';
const String _icsDurationHourSuffix = 'H';
const String _icsDurationMinuteSuffix = 'M';
const String _icsDurationSecondSuffix = 'S';

const String _icsChecklistIdKey = 'id';
const String _icsChecklistLabelKey = 'label';
const String _icsChecklistCompleteKey = 'isCompleted';
const String _icsChecklistOrderKey = 'order';

const int _percentScale = 100;

final RegExp _icsDurationRegExp = RegExp(_icsDurationPattern);

class CalendarIcsCodec {
  const CalendarIcsCodec();

  String encode(CalendarModel model) {
    final writer = _IcsWriter(StringBuffer());
    final CalendarCollection? collection = model.collection;
    writer.beginComponent(_icsComponentVcalendar);
    writer.writeProperty(
      _icsPropertyProdId,
      _resolveCalendarProperty(collection, _icsPropertyProdId) ??
          _icsDefaultProdId,
      escapeText: false,
    );
    writer.writeProperty(
      _icsPropertyVersion,
      collection?.version ?? _icsDefaultVersion,
      escapeText: false,
    );
    writer.writeProperty(
      _icsPropertyCalScale,
      _resolveCalendarProperty(collection, _icsPropertyCalScale) ??
          _icsValueGregorian,
      escapeText: false,
    );
    final CalendarMethod? method = collection?.method;
    if (method != null) {
      writer.writeProperty(
        _icsPropertyMethod,
        method.icsValue,
        escapeText: false,
      );
    }
    final String? calendarName = collection?.name;
    if (calendarName != null && calendarName.isNotEmpty) {
      writer.writeProperty(_icsPropertyCalendarName, calendarName);
    }
    final String? calendarDescription = collection?.description;
    if (calendarDescription != null && calendarDescription.isNotEmpty) {
      writer.writeProperty(
          _icsPropertyCalendarDescription, calendarDescription);
    }
    final String? calendarTimeZone = collection?.timeZone;
    if (calendarTimeZone != null && calendarTimeZone.isNotEmpty) {
      writer.writeProperty(
        _icsPropertyCalendarTimeZone,
        calendarTimeZone,
        escapeText: false,
      );
    }
    final String? calendarColor = collection?.color;
    if (calendarColor != null && calendarColor.isNotEmpty) {
      writer.writeProperty(
        _icsPropertyCalendarColor,
        calendarColor,
        escapeText: false,
      );
    }
    final String? calendarId = collection?.id;
    if (calendarId != null && calendarId.isNotEmpty) {
      writer.writeProperty(_icsPropertyCalendarId, calendarId);
    }
    final String? calendarOwner = collection?.owner;
    if (calendarOwner != null && calendarOwner.isNotEmpty) {
      writer.writeProperty(_icsPropertyCalendarOwner, calendarOwner);
    }
    final CalendarSharingPolicy? sharingPolicy = collection?.sharingPolicy;
    if (sharingPolicy != null && sharingPolicy.value.isNotEmpty) {
      writer.writeProperty(
        _icsPropertyCalendarSharing,
        sharingPolicy.value,
      );
    }
    if (collection != null) {
      final rawProperties = collection.rawProperties;
      for (final property in rawProperties) {
        if (_shouldWriteCollectionRawProperty(property.name)) {
          writer.writeRawProperty(property);
        }
      }
    }
    final List<CalendarTimeZoneDefinition> timeZones =
        collection?.timeZones ?? const <CalendarTimeZoneDefinition>[];
    for (final CalendarTimeZoneDefinition zone in timeZones) {
      writer.writeRawComponent(zone.component);
    }

    final Map<String, List<CalendarCriticalPathLink>> criticalPathLinks =
        _buildCriticalPathLinks(model);
    final Map<String, String> taskUids = _buildTaskUidLookup(model);

    for (final CalendarTask task in model.tasks.values) {
      _writeTaskComponent(
        writer,
        task,
        criticalPathLinks: criticalPathLinks,
        taskUids: taskUids,
      );
    }
    for (final DayEvent event in model.dayEvents.values) {
      _writeDayEventComponent(writer, event);
    }
    for (final CalendarJournal journal in model.journals.values) {
      _writeJournalComponent(writer, journal);
    }
    for (final MapEntry<String, CalendarAvailability> entry
        in model.availability.entries) {
      _writeAvailabilityComponent(writer, entry.value, entry.key);
    }
    for (final MapEntry<String, CalendarAvailabilityOverlay> entry
        in model.availabilityOverlays.entries) {
      _writeFreeBusyComponent(writer, entry.value, entry.key);
    }
    if (collection != null) {
      for (final component in collection.rawComponents) {
        if (_shouldWriteCollectionRawComponent(component.name)) {
          writer.writeRawComponent(component);
        }
      }
    }
    writer.endComponent(_icsComponentVcalendar);
    return writer.toString();
  }

  CalendarModel decode(String data) {
    final CalendarRawComponent root = _IcsParser().parse(data);
    final CalendarRawComponent? calendar =
        _findComponent(root, _icsComponentVcalendar);
    if (calendar == null) {
      throw const FormatException('Missing VCALENDAR component');
    }
    final _CalendarParseResult result = _CalendarModelParser().parse(calendar);
    final DateTime now = DateTime.now();
    final CalendarModel model = CalendarModel(
      tasks: result.tasks,
      dayEvents: result.dayEvents,
      journals: result.journals,
      criticalPaths: result.criticalPaths,
      deletedTaskIds: result.deletedTaskIds,
      deletedDayEventIds: result.deletedDayEventIds,
      deletedJournalIds: result.deletedJournalIds,
      deletedCriticalPathIds: result.deletedCriticalPathIds,
      availability: result.availability,
      availabilityOverlays: result.availabilityOverlays,
      collection: result.collection,
      lastModified: now,
      checksum: '',
    );
    return model.copyWith(checksum: model.calculateChecksum());
  }
}

class _CalendarParseResult {
  const _CalendarParseResult({
    required this.tasks,
    required this.dayEvents,
    required this.journals,
    required this.criticalPaths,
    required this.deletedTaskIds,
    required this.deletedDayEventIds,
    required this.deletedJournalIds,
    required this.deletedCriticalPathIds,
    required this.availability,
    required this.availabilityOverlays,
    required this.collection,
  });

  final Map<String, CalendarTask> tasks;
  final Map<String, DayEvent> dayEvents;
  final Map<String, CalendarJournal> journals;
  final Map<String, CalendarCriticalPath> criticalPaths;
  final Map<String, DateTime> deletedTaskIds;
  final Map<String, DateTime> deletedDayEventIds;
  final Map<String, DateTime> deletedJournalIds;
  final Map<String, DateTime> deletedCriticalPathIds;
  final Map<String, CalendarAvailability> availability;
  final Map<String, CalendarAvailabilityOverlay> availabilityOverlays;
  final CalendarCollection? collection;
}

class _CalendarModelParser {
  _CalendarParseResult parse(CalendarRawComponent calendar) {
    final collection = _parseCollection(calendar);
    final Map<String, List<CalendarRawComponent>> todoGroups = {};
    final Map<String, List<CalendarRawComponent>> eventGroups = {};
    final Map<String, List<CalendarRawComponent>> journalGroups = {};
    final Map<String, CalendarAvailability> availability = {};
    final Map<String, CalendarAvailabilityOverlay> overlays = {};
    final List<CalendarRawComponent> otherComponents = <CalendarRawComponent>[];
    for (final CalendarRawComponent component in calendar.components) {
      final String name = component.name.toUpperCase();
      if (name == _icsComponentVtodo) {
        final String uid = _componentUid(component);
        todoGroups.putIfAbsent(uid, () => <CalendarRawComponent>[]).add(
              component,
            );
        continue;
      }
      if (name == _icsComponentVevent) {
        final String uid = _componentUid(component);
        eventGroups.putIfAbsent(uid, () => <CalendarRawComponent>[]).add(
              component,
            );
        continue;
      }
      if (name == _icsComponentVjournal) {
        final String uid = _componentUid(component);
        journalGroups.putIfAbsent(uid, () => <CalendarRawComponent>[]).add(
              component,
            );
        continue;
      }
      if (name == _icsComponentVfreebusy) {
        final _FreeBusyParseResult parsed = _parseFreeBusyComponent(component);
        if (parsed.overlay != null && parsed.uid != null) {
          overlays[parsed.uid!] = parsed.overlay!;
        }
        continue;
      }
      if (name == _icsComponentVavailability) {
        final CalendarAvailability? parsed =
            _parseAvailabilityComponent(component);
        if (parsed != null) {
          availability[parsed.id] = parsed;
        }
        continue;
      }
      if (name == _icsComponentVtimezone) {
        continue;
      }
      otherComponents.add(component);
    }

    final Map<String, CalendarTask> tasks = <String, CalendarTask>{};
    final Map<String, DayEvent> dayEvents = <String, DayEvent>{};
    final Map<String, CalendarJournal> journals = <String, CalendarJournal>{};
    final Map<String, DateTime> deletedTaskIds = <String, DateTime>{};
    final Map<String, DateTime> deletedDayEventIds = <String, DateTime>{};
    final Map<String, DateTime> deletedJournalIds = <String, DateTime>{};
    final Map<String, DateTime> deletedCriticalPathIds = <String, DateTime>{};
    final Map<String, List<_CriticalPathEntry>> pathEntries =
        <String, List<_CriticalPathEntry>>{};

    final CalendarMethod? method = collection.method;
    final bool isCalendarCancel = method == CalendarMethod.cancel;

    for (final MapEntry<String, List<CalendarRawComponent>> entry
        in todoGroups.entries) {
      final _TaskGroupResult? parsed = _parseTaskGroup(
        entry.value,
        isEvent: false,
        isCalendarCancel: isCalendarCancel,
      );
      if (parsed == null) {
        continue;
      }
      if (parsed.isCancelled) {
        deletedTaskIds[parsed.taskId] = parsed.cancelledAt;
        continue;
      }
      tasks[parsed.task.id] = parsed.task;
      _recordCriticalPathLinks(
        pathEntries,
        parsed.task.id,
        parsed.pathLinks,
      );
    }

    for (final MapEntry<String, List<CalendarRawComponent>> entry
        in eventGroups.entries) {
      final _EventGroupResult? parsed = _parseEventGroup(
        entry.value,
        isCalendarCancel: isCalendarCancel,
      );
      if (parsed == null) {
        continue;
      }
      if (parsed.isCancelled) {
        if (parsed.isDayEvent) {
          deletedDayEventIds[parsed.itemId] = parsed.cancelledAt;
        } else {
          deletedTaskIds[parsed.itemId] = parsed.cancelledAt;
        }
        continue;
      }
      if (parsed.dayEvent != null) {
        dayEvents[parsed.dayEvent!.id] = parsed.dayEvent!;
      }
      if (parsed.task != null) {
        tasks[parsed.task!.id] = parsed.task!;
        _recordCriticalPathLinks(
          pathEntries,
          parsed.task!.id,
          parsed.pathLinks,
        );
      }
    }

    for (final MapEntry<String, List<CalendarRawComponent>> entry
        in journalGroups.entries) {
      final _JournalGroupResult? parsed = _parseJournalGroup(
        entry.value,
        isCalendarCancel: isCalendarCancel,
      );
      if (parsed == null) {
        otherComponents.addAll(entry.value);
        continue;
      }
      if (parsed.isCancelled) {
        deletedJournalIds[parsed.journalId] = parsed.cancelledAt;
        continue;
      }
      journals[parsed.journal.id] = parsed.journal;
      if (parsed.passthroughComponents.isNotEmpty) {
        otherComponents.addAll(parsed.passthroughComponents);
      }
    }

    final Map<String, CalendarCriticalPath> criticalPaths =
        _buildCriticalPaths(pathEntries);

    final CalendarCollection? enrichedCollection =
        _appendCollectionComponents(collection, otherComponents);

    return _CalendarParseResult(
      tasks: tasks,
      dayEvents: dayEvents,
      journals: journals,
      criticalPaths: criticalPaths,
      deletedTaskIds: deletedTaskIds,
      deletedDayEventIds: deletedDayEventIds,
      deletedJournalIds: deletedJournalIds,
      deletedCriticalPathIds: deletedCriticalPathIds,
      availability: availability,
      availabilityOverlays: overlays,
      collection: enrichedCollection,
    );
  }
}

class _TaskGroupResult {
  const _TaskGroupResult({
    required this.task,
    required this.taskId,
    required this.isCancelled,
    required this.cancelledAt,
    required this.pathLinks,
  });

  final CalendarTask task;
  final String taskId;
  final bool isCancelled;
  final DateTime cancelledAt;
  final List<CalendarCriticalPathLink> pathLinks;
}

class _JournalGroupResult {
  const _JournalGroupResult({
    required this.journal,
    required this.journalId,
    required this.isCancelled,
    required this.cancelledAt,
    required this.passthroughComponents,
  });

  final CalendarJournal journal;
  final String journalId;
  final bool isCancelled;
  final DateTime cancelledAt;
  final List<CalendarRawComponent> passthroughComponents;
}

class _EventGroupResult {
  const _EventGroupResult({
    required this.task,
    required this.dayEvent,
    required this.isCancelled,
    required this.cancelledAt,
    required this.itemId,
    required this.isDayEvent,
    required this.pathLinks,
  });

  final CalendarTask? task;
  final DayEvent? dayEvent;
  final bool isCancelled;
  final DateTime cancelledAt;
  final String itemId;
  final bool isDayEvent;
  final List<CalendarCriticalPathLink> pathLinks;
}

class _FreeBusyParseResult {
  const _FreeBusyParseResult({
    required this.overlay,
    required this.uid,
  });

  final CalendarAvailabilityOverlay? overlay;
  final String? uid;
}

class _CriticalPathEntry {
  const _CriticalPathEntry({
    required this.taskId,
    required this.order,
  });

  final String taskId;
  final int? order;
}

class _IcsWriter {
  _IcsWriter(this._buffer);

  final StringBuffer _buffer;

  void beginComponent(String name) {
    _writeLine('$_icsPropertyBegin$_icsValueColon$name');
  }

  void endComponent(String name) {
    _writeLine('$_icsPropertyEnd$_icsValueColon$name');
  }

  void writeProperty(
    String name,
    String value, {
    List<CalendarPropertyParameter> parameters =
        const <CalendarPropertyParameter>[],
    bool escapeText = true,
  }) {
    final String params = _encodeParameters(parameters);
    final String encodedValue = escapeText ? _escapeText(value) : value;
    _writeLine('$name$params$_icsValueColon$encodedValue');
  }

  void writeRawProperty(CalendarRawProperty property) {
    final String params = _encodeParameters(property.parameters);
    final String encodedValue = _escapeText(property.value);
    _writeLine('${property.name}$params$_icsValueColon$encodedValue');
  }

  void writeRawComponent(CalendarRawComponent component) {
    beginComponent(component.name);
    for (final CalendarRawProperty property in component.properties) {
      writeRawProperty(property);
    }
    for (final CalendarRawComponent child in component.components) {
      writeRawComponent(child);
    }
    endComponent(component.name);
  }

  @override
  String toString() => _buffer.toString();

  void _writeLine(String line) {
    final List<String> folded = _foldLine(line);
    for (final String segment in folded) {
      _buffer
        ..write(segment)
        ..write(_icsLineBreak);
    }
  }
}

class _IcsParser {
  CalendarRawComponent parse(String data) {
    final List<String> lines = _unfoldLines(data);
    final _IcsComponentBuilder rootBuilder =
        _IcsComponentBuilder(_icsComponentRoot);
    final List<_IcsComponentBuilder> stack = <_IcsComponentBuilder>[
      rootBuilder
    ];

    for (final String rawLine in lines) {
      final String line = rawLine.trim();
      if (line.isEmpty) {
        continue;
      }
      if (line.startsWith('$_icsPropertyBegin$_icsValueColon')) {
        final String name =
            line.substring(_icsPropertyBegin.length + _icsValueColon.length);
        final _IcsComponentBuilder child = _IcsComponentBuilder(
          _normalizeName(name),
        );
        stack.last.children.add(child);
        stack.add(child);
        continue;
      }
      if (line.startsWith('$_icsPropertyEnd$_icsValueColon')) {
        if (stack.length > 1) {
          stack.removeLast();
        }
        continue;
      }
      final CalendarRawProperty? property = _parsePropertyLine(line);
      if (property != null) {
        stack.last.properties.add(property);
      }
    }
    return rootBuilder.build();
  }
}

class _IcsComponentBuilder {
  _IcsComponentBuilder(this.name);

  final String name;
  final List<CalendarRawProperty> properties = <CalendarRawProperty>[];
  final List<_IcsComponentBuilder> children = <_IcsComponentBuilder>[];

  CalendarRawComponent build() => CalendarRawComponent(
        name: name,
        properties: List<CalendarRawProperty>.unmodifiable(properties),
        components:
            children.map((builder) => builder.build()).toList(growable: false),
      );
}

CalendarRawComponent? _findComponent(
  CalendarRawComponent root,
  String name,
) {
  for (final CalendarRawComponent component in root.components) {
    if (component.name == name) {
      return component;
    }
  }
  return null;
}

CalendarRawProperty? _parsePropertyLine(String line) {
  final int separatorIndex = line.indexOf(_icsValueColon);
  if (separatorIndex <= 0) {
    return null;
  }
  final String nameAndParams = line.substring(0, separatorIndex);
  final String rawValue = line.substring(separatorIndex + 1);
  final List<String> parts = _splitUnquoted(nameAndParams, _icsValueSemicolon);
  if (parts.isEmpty) {
    return null;
  }
  final String name = _normalizeName(parts.first);
  final List<CalendarPropertyParameter> parameters =
      <CalendarPropertyParameter>[];
  if (parts.length > 1) {
    for (final String param in parts.skip(1)) {
      final CalendarPropertyParameter? parsed = _parseParameter(param);
      if (parsed != null) {
        parameters.add(parsed);
      }
    }
  }
  return CalendarRawProperty(
    name: name,
    value: _unescapeText(rawValue),
    parameters: parameters,
  );
}

CalendarPropertyParameter? _parseParameter(String raw) {
  final int equalsIndex = raw.indexOf('=');
  if (equalsIndex <= 0 || equalsIndex == raw.length - 1) {
    return null;
  }
  final String name = _normalizeName(raw.substring(0, equalsIndex));
  final String rawValues = raw.substring(equalsIndex + 1);
  final List<String> values = _splitUnquoted(rawValues, _icsValueComma)
      .map(_stripQuotes)
      .map(_unescapeText)
      .toList(growable: false);
  return CalendarPropertyParameter(name: name, values: values);
}

List<String> _unfoldLines(String data) {
  final List<String> rawLines = data.split(RegExp(r'\r?\n'));
  final List<String> lines = <String>[];
  for (final String line in rawLines) {
    if (line.isEmpty) {
      continue;
    }
    if ((line.startsWith(_icsValueSpace) || line.startsWith('\t')) &&
        lines.isNotEmpty) {
      lines[lines.length - 1] =
          '${lines.last}${line.substring(_icsValueSpace.length)}';
    } else {
      lines.add(line);
    }
  }
  return lines;
}

List<String> _splitUnquoted(String input, String separator) {
  final List<String> parts = <String>[];
  final StringBuffer buffer = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < input.length; i++) {
    final String char = input[i];
    if (char == '"') {
      inQuotes = !inQuotes;
      buffer.write(char);
      continue;
    }
    if (!inQuotes && char == separator) {
      parts.add(buffer.toString());
      buffer.clear();
      continue;
    }
    buffer.write(char);
  }
  if (buffer.isNotEmpty) {
    parts.add(buffer.toString());
  }
  return parts;
}

String _stripQuotes(String input) {
  if (input.length >= 2 && input.startsWith('"') && input.endsWith('"')) {
    return input.substring(1, input.length - 1);
  }
  return input;
}

String _normalizeName(String input) => input.trim().toUpperCase();

String _escapeText(String input) {
  return input
      .replaceAll(_icsValueBackslash, _icsEscapedBackslash)
      .replaceAll(_icsValueNewline, _icsEscapedNewline)
      .replaceAll(_icsValueComma, _icsEscapedComma)
      .replaceAll(_icsValueSemicolon, _icsEscapedSemicolon);
}

String _unescapeText(String input) {
  if (!input.contains(_icsValueBackslash)) {
    return input;
  }
  final StringBuffer buffer = StringBuffer();
  int index = 0;
  while (index < input.length) {
    final String char = input[index];
    if (char != _icsValueBackslash) {
      buffer.write(char);
      index += 1;
      continue;
    }
    if (index == input.length - 1) {
      buffer.write(_icsValueBackslash);
      break;
    }
    final String next = input[index + 1];
    switch (next) {
      case _icsEscapeNewline:
        buffer.write(_icsValueNewline);
        break;
      case _icsValueComma:
        buffer.write(_icsValueComma);
        break;
      case _icsValueSemicolon:
        buffer.write(_icsValueSemicolon);
        break;
      case _icsValueBackslash:
        buffer.write(_icsValueBackslash);
        break;
      default:
        buffer.write(next);
        break;
    }
    index += 2;
  }
  return buffer.toString();
}

List<String> _foldLine(String line) {
  if (line.length <= _icsFoldLimit) {
    return <String>[line];
  }
  final List<String> segments = <String>[];
  var start = 0;
  while (start < line.length) {
    final int end = (start + _icsFoldLimit) > line.length
        ? line.length
        : start + _icsFoldLimit;
    final String part = line.substring(start, end);
    if (start == 0) {
      segments.add(part);
    } else {
      segments.add('$_icsValueSpace$part');
    }
    start = end;
  }
  return segments;
}

String _encodeParameters(List<CalendarPropertyParameter> parameters) {
  if (parameters.isEmpty) {
    return '';
  }
  final StringBuffer buffer = StringBuffer();
  for (final CalendarPropertyParameter parameter in parameters) {
    if (parameter.values.isEmpty) {
      continue;
    }
    buffer
      ..write(_icsValueSemicolon)
      ..write(parameter.name)
      ..write('=');
    final String joined = parameter.values.map(_encodeParamValue).join(
          _icsValueComma,
        );
    buffer.write(joined);
  }
  return buffer.toString();
}

String _encodeParamValue(String value) {
  if (value.contains(_icsValueSemicolon) ||
      value.contains(_icsValueColon) ||
      value.contains(_icsValueComma) ||
      value.contains(_icsValueSpace)) {
    return '"${value.replaceAll('"', r'\"')}"';
  }
  return value;
}

String? _resolveCalendarProperty(
  CalendarCollection? collection,
  String name,
) {
  if (collection == null) {
    return null;
  }
  for (final CalendarRawProperty property in collection.rawProperties) {
    if (property.name == name) {
      return property.value;
    }
  }
  return null;
}

bool _shouldWriteCollectionRawProperty(String name) {
  switch (name) {
    case _icsPropertyProdId:
    case _icsPropertyVersion:
    case _icsPropertyCalScale:
    case _icsPropertyCalendarName:
    case _icsPropertyCalendarDescription:
    case _icsPropertyCalendarTimeZone:
    case _icsPropertyCalendarColor:
    case _icsPropertyCalendarId:
    case _icsPropertyCalendarOwner:
    case _icsPropertyCalendarSharing:
      return false;
    default:
      return true;
  }
}

bool _shouldWriteCollectionRawComponent(String name) {
  switch (name) {
    case _icsComponentVtimezone:
    case _icsComponentVtodo:
    case _icsComponentVevent:
    case _icsComponentVfreebusy:
    case _icsComponentVavailability:
      return false;
    default:
      return true;
  }
}

CalendarCollection? _appendCollectionComponents(
  CalendarCollection? collection,
  List<CalendarRawComponent> components,
) {
  if (collection == null || components.isEmpty) {
    return collection;
  }
  final List<CalendarRawComponent> merged = <CalendarRawComponent>[
    ...collection.rawComponents,
    ...components,
  ];
  return collection.copyWith(rawComponents: merged);
}

CalendarCollection _parseCollection(CalendarRawComponent calendar) {
  final List<CalendarRawProperty> properties = calendar.properties;
  final String? name = _firstPropertyValue(
    properties,
    _icsPropertyCalendarName,
  );
  final String? description = _firstPropertyValue(
    properties,
    _icsPropertyCalendarDescription,
  );
  final String? color = _firstPropertyValue(
    properties,
    _icsPropertyCalendarColor,
  );
  final String? owner = _firstPropertyValue(
    properties,
    _icsPropertyCalendarOwner,
  );
  final String? timeZone = _firstPropertyValue(
    properties,
    _icsPropertyCalendarTimeZone,
  );
  final String? version = _firstPropertyValue(
    properties,
    _icsPropertyVersion,
  );
  final String? id = _firstPropertyValue(
    properties,
    _icsPropertyCalendarId,
  );
  final CalendarMethod? method = CalendarMethod.fromIcsValue(
    _firstPropertyValue(properties, _icsPropertyMethod),
  );
  final String? sharingValue = _firstPropertyValue(
    properties,
    _icsPropertyCalendarSharing,
  );
  final CalendarSharingPolicy? sharingPolicy =
      sharingValue == null ? null : CalendarSharingPolicy(value: sharingValue);
  final List<CalendarTimeZoneDefinition> timeZones = _parseTimeZones(calendar);

  final Set<String> handledProperties = <String>{
    _icsPropertyCalendarName,
    _icsPropertyCalendarDescription,
    _icsPropertyCalendarColor,
    _icsPropertyCalendarOwner,
    _icsPropertyCalendarTimeZone,
    _icsPropertyCalendarId,
    _icsPropertyCalendarSharing,
    _icsPropertyMethod,
    _icsPropertyVersion,
  };
  final List<CalendarRawProperty> rawProperties = properties
      .where(
        (property) =>
            !handledProperties.contains(property.name) ||
            property.parameters.isNotEmpty,
      )
      .toList(growable: false);

  return CalendarCollection(
    id: id ?? _calendarFallbackId,
    name: name ?? _calendarFallbackName,
    description: description,
    color: color,
    owner: owner,
    timeZone: timeZone,
    version: version,
    sharingPolicy: sharingPolicy,
    method: method,
    timeZones: timeZones,
    rawProperties: rawProperties,
    rawComponents: const <CalendarRawComponent>[],
  );
}

List<CalendarTimeZoneDefinition> _parseTimeZones(
    CalendarRawComponent calendar) {
  final List<CalendarTimeZoneDefinition> timeZones =
      <CalendarTimeZoneDefinition>[];
  for (final CalendarRawComponent component in calendar.components) {
    if (component.name != _icsComponentVtimezone) {
      continue;
    }
    final String? tzid =
        _firstPropertyValue(component.properties, _icsPropertyTzid);
    if (tzid == null || tzid.isEmpty) {
      continue;
    }
    timeZones.add(
      CalendarTimeZoneDefinition(
        tzid: tzid,
        component: component,
      ),
    );
  }
  return timeZones;
}

String _componentUid(CalendarRawComponent component) {
  final String? uid =
      _firstPropertyValue(component.properties, _icsPropertyUid);
  if (uid != null && uid.isNotEmpty) {
    return uid;
  }
  final String? fallback =
      _firstPropertyValue(component.properties, _axiTaskIdProperty);
  return fallback?.isNotEmpty == true ? fallback! : const Uuid().v4();
}

CalendarIcsComponentType? _componentTypeFromName(String name) {
  switch (name) {
    case _icsComponentVtodo:
      return CalendarIcsComponentType.todo;
    case _icsComponentVevent:
      return CalendarIcsComponentType.event;
    case _icsComponentVjournal:
      return CalendarIcsComponentType.journal;
    case _icsComponentVavailability:
      return CalendarIcsComponentType.availability;
    case _icsComponentVfreebusy:
      return CalendarIcsComponentType.freeBusy;
    default:
      return null;
  }
}

String? _firstPropertyValue(
  List<CalendarRawProperty> properties,
  String name,
) {
  for (final CalendarRawProperty property in properties) {
    if (property.name == name) {
      return property.value;
    }
  }
  return null;
}

List<CalendarRawProperty> _propertiesByName(
  List<CalendarRawProperty> properties,
  String name,
) {
  return properties
      .where((property) => property.name == name)
      .toList(growable: false);
}

_TaskGroupResult? _parseTaskGroup(
  List<CalendarRawComponent> components, {
  required bool isEvent,
  required bool isCalendarCancel,
}) {
  if (components.isEmpty) {
    return null;
  }
  final CalendarRawComponent base = _findBaseComponent(components);
  final bool hasBase =
      _firstPropertyValue(base.properties, _icsPropertyRecurrenceId) == null;
  final bool hasOverrides = components.any(
    (component) =>
        _firstPropertyValue(component.properties, _icsPropertyRecurrenceId) !=
        null,
  );
  final _ParsedComponent parsedBase = _parseTaskComponent(
    base,
    isEvent: isEvent,
  );
  final bool isCancelled = (isCalendarCancel && hasBase && !hasOverrides) ||
      parsedBase.meta.status?.isCancelled == true;
  final DateTime cancelledAt =
      parsedBase.meta.lastModified ?? parsedBase.meta.dtStamp ?? DateTime.now();
  if (isCancelled) {
    return _TaskGroupResult(
      task: parsedBase.task,
      taskId: parsedBase.task.id,
      isCancelled: true,
      cancelledAt: cancelledAt,
      pathLinks: parsedBase.pathLinks,
    );
  }

  final Map<String, TaskOccurrenceOverride> overrides =
      <String, TaskOccurrenceOverride>{};
  for (final CalendarRawComponent component in components) {
    if (component == base) {
      continue;
    }
    final TaskOccurrenceOverride? override = _parseTaskOverride(
      component,
      isEvent: isEvent,
      isCalendarCancel: isCalendarCancel,
    );
    if (override == null || override.recurrenceId == null) {
      continue;
    }
    final String key =
        override.recurrenceId!.value.microsecondsSinceEpoch.toString();
    overrides[key] = override;
  }

  final CalendarTask mergedTask =
      parsedBase.task.copyWith(occurrenceOverrides: overrides);
  return _TaskGroupResult(
    task: mergedTask,
    taskId: mergedTask.id,
    isCancelled: false,
    cancelledAt: cancelledAt,
    pathLinks: parsedBase.pathLinks,
  );
}

_EventGroupResult? _parseEventGroup(
  List<CalendarRawComponent> components, {
  required bool isCalendarCancel,
}) {
  if (components.isEmpty) {
    return null;
  }
  final CalendarRawComponent base = _findBaseComponent(components);
  final bool hasBase =
      _firstPropertyValue(base.properties, _icsPropertyRecurrenceId) == null;
  final bool hasOverrides = components.any(
    (component) =>
        _firstPropertyValue(component.properties, _icsPropertyRecurrenceId) !=
        null,
  );
  final bool isAllDay = _isAllDayComponent(base);
  final bool hasRecurrence = _hasRecurrence(base);
  final bool useDayEvent = isAllDay && !hasRecurrence;

  if (useDayEvent) {
    final _ParsedDayEvent parsed = _parseDayEventComponent(base);
    final bool isCancelled = (isCalendarCancel && hasBase && !hasOverrides) ||
        parsed.meta.status?.isCancelled == true;
    final DateTime cancelledAt =
        parsed.meta.lastModified ?? parsed.meta.dtStamp ?? DateTime.now();
    return _EventGroupResult(
      task: null,
      dayEvent: parsed.event,
      isCancelled: isCancelled,
      cancelledAt: cancelledAt,
      itemId: parsed.event.id,
      isDayEvent: true,
      pathLinks: const <CalendarCriticalPathLink>[],
    );
  }

  final _ParsedComponent parsedTask = _parseTaskComponent(
    base,
    isEvent: true,
  );
  final bool isCancelled = (isCalendarCancel && hasBase && !hasOverrides) ||
      parsedTask.meta.status?.isCancelled == true;
  final DateTime cancelledAt =
      parsedTask.meta.lastModified ?? parsedTask.meta.dtStamp ?? DateTime.now();
  if (isCancelled) {
    return _EventGroupResult(
      task: null,
      dayEvent: null,
      isCancelled: true,
      cancelledAt: cancelledAt,
      itemId: parsedTask.task.id,
      isDayEvent: false,
      pathLinks: parsedTask.pathLinks,
    );
  }
  final Map<String, TaskOccurrenceOverride> overrides =
      <String, TaskOccurrenceOverride>{};
  for (final CalendarRawComponent component in components) {
    if (component == base) {
      continue;
    }
    final TaskOccurrenceOverride? override = _parseTaskOverride(
      component,
      isEvent: true,
      isCalendarCancel: isCalendarCancel,
    );
    if (override == null || override.recurrenceId == null) {
      continue;
    }
    final String key =
        override.recurrenceId!.value.microsecondsSinceEpoch.toString();
    overrides[key] = override;
  }

  final CalendarTask mergedTask =
      parsedTask.task.copyWith(occurrenceOverrides: overrides);
  return _EventGroupResult(
    task: mergedTask,
    dayEvent: null,
    isCancelled: false,
    cancelledAt: cancelledAt,
    itemId: mergedTask.id,
    isDayEvent: false,
    pathLinks: parsedTask.pathLinks,
  );
}

_JournalGroupResult? _parseJournalGroup(
  List<CalendarRawComponent> components, {
  required bool isCalendarCancel,
}) {
  if (components.isEmpty) {
    return null;
  }
  final CalendarRawComponent base = _findBaseComponent(components);
  final bool hasBase = _firstPropertyValue(
        base.properties,
        _icsPropertyRecurrenceId,
      ) ==
      null;
  if (!hasBase) {
    return null;
  }
  final _ParsedJournal parsedBase = _parseJournalComponent(base);
  final bool isCancelled =
      isCalendarCancel || parsedBase.meta.status?.isCancelled == true;
  final DateTime cancelledAt =
      parsedBase.meta.lastModified ?? parsedBase.meta.dtStamp ?? DateTime.now();
  final List<CalendarRawComponent> passthroughComponents =
      <CalendarRawComponent>[];
  for (final CalendarRawComponent component in components) {
    if (component == base) {
      continue;
    }
    if (_firstPropertyValue(component.properties, _icsPropertyRecurrenceId) !=
        null) {
      passthroughComponents.add(component);
    }
  }
  return _JournalGroupResult(
    journal: parsedBase.journal,
    journalId: parsedBase.journal.id,
    isCancelled: isCancelled,
    cancelledAt: cancelledAt,
    passthroughComponents: passthroughComponents,
  );
}

CalendarRawComponent _findBaseComponent(List<CalendarRawComponent> components) {
  for (final CalendarRawComponent component in components) {
    if (_firstPropertyValue(component.properties, _icsPropertyRecurrenceId) ==
        null) {
      return component;
    }
  }
  return components.first;
}

bool _isAllDayComponent(CalendarRawComponent component) {
  final CalendarRawProperty? dtStart =
      _firstProperty(component.properties, _icsPropertyDtStart);
  if (dtStart == null) {
    return false;
  }
  final String value = dtStart.parameters.firstValue(_icsParamValue) ?? '';
  if (value == _icsParamValueDate) {
    return true;
  }
  return dtStart.value.length == _icsDateLength;
}

bool _hasRecurrence(CalendarRawComponent component) {
  return _firstProperty(component.properties, _icsPropertyRrule) != null ||
      _propertiesByName(component.properties, _icsPropertyRdate).isNotEmpty ||
      _propertiesByName(component.properties, _icsPropertyExdate).isNotEmpty;
}

_ParsedComponent _parseTaskComponent(
  CalendarRawComponent component, {
  required bool isEvent,
}) {
  final CalendarIcsMeta meta = _parseMeta(component);
  final List<CalendarRawProperty> properties = component.properties;
  final String id = _firstPropertyValue(properties, _axiTaskIdProperty) ??
      meta.uid ??
      const Uuid().v4();
  final String title = _firstPropertyValue(properties, _icsPropertySummary) ??
      _taskFallbackTitle;
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final String? location =
      _firstPropertyValue(properties, _icsPropertyLocation);
  final TaskPriority? priority = _parsePriority(properties);
  final DateTime createdAt = meta.created ?? meta.dtStamp ?? DateTime.now();
  final DateTime modifiedAt = meta.lastModified ?? meta.dtStamp ?? createdAt;

  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final DateTime? scheduledTime =
      dtStartProp == null ? null : _parseDateTime(dtStartProp)?.value;

  final CalendarRawProperty? dueProp =
      _firstProperty(properties, _icsPropertyDue);
  final DateTime? deadline =
      dueProp == null ? null : _parseDateTime(dueProp)?.value;

  final _ScheduleSpan span = _parseScheduleSpan(
    properties,
    scheduledTime,
    isEvent: isEvent,
  );

  final List<CalendarCriticalPathLink> pathLinks =
      _parseCriticalPathLinks(properties);
  final TaskChecklistResult checklistResult =
      _parseChecklist(properties, meta.axi);

  final List<CalendarAlarm> alarms = _parseAlarms(component.components);
  final ReminderPreferences reminders =
      _remindersFromAlarms(alarms).normalized();

  final RecurrenceRule? recurrence = _parseRecurrence(properties);
  final bool hasRecurrenceData = recurrence != null &&
      (!recurrence.isNone ||
          recurrence.rDates.isNotEmpty ||
          recurrence.exDates.isNotEmpty ||
          recurrence.rawProperties.isNotEmpty);

  final bool isCompleted = _isCompleted(properties, meta.status);
  final CalendarAxiExtensions? axi = _mergeAxi(checklistResult, pathLinks);
  final CalendarIcsMeta mergedMeta = meta.copyWith(
    alarms: alarms,
    axi: axi,
  );

  final CalendarTask task = CalendarTask(
    id: id,
    title: title,
    description: description?.isEmpty == true ? null : description,
    scheduledTime: scheduledTime,
    duration: span.duration,
    endDate: span.endDate,
    deadline: isEvent ? null : deadline,
    isCompleted: isCompleted,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    location: location?.isEmpty == true ? null : location,
    priority: priority == TaskPriority.none ? null : priority,
    startHour: null,
    recurrence: hasRecurrenceData ? recurrence : null,
    occurrenceOverrides: const <String, TaskOccurrenceOverride>{},
    reminders: reminders,
    checklist: checklistResult.items,
    icsMeta: mergedMeta,
  );

  return _ParsedComponent(
    task: task,
    meta: mergedMeta,
    pathLinks: pathLinks,
  );
}

class _ParsedComponent {
  const _ParsedComponent({
    required this.task,
    required this.meta,
    required this.pathLinks,
  });

  final CalendarTask task;
  final CalendarIcsMeta meta;
  final List<CalendarCriticalPathLink> pathLinks;
}

class _ParsedJournal {
  const _ParsedJournal({
    required this.journal,
    required this.meta,
  });

  final CalendarJournal journal;
  final CalendarIcsMeta meta;
}

class _ParsedDayEvent {
  const _ParsedDayEvent({
    required this.event,
    required this.meta,
  });

  final DayEvent event;
  final CalendarIcsMeta meta;
}

_ParsedJournal _parseJournalComponent(CalendarRawComponent component) {
  final CalendarIcsMeta meta = _parseMeta(component);
  final List<CalendarRawProperty> properties = component.properties;
  final String id = _firstPropertyValue(properties, _axiTaskIdProperty) ??
      meta.uid ??
      const Uuid().v4();
  final String title = _firstPropertyValue(properties, _icsPropertySummary) ??
      _journalFallbackTitle;
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final CalendarDateTime? parsedEntry =
      dtStartProp == null ? null : _parseDateTime(dtStartProp);
  final CalendarDateTime entryDate =
      parsedEntry ?? _fallbackJournalEntryDate(meta);
  final List<CalendarAlarm> alarms = _parseAlarms(component.components);
  final CalendarIcsMeta mergedMeta = meta.copyWith(alarms: alarms);
  final DateTime createdAt = meta.created ?? meta.dtStamp ?? DateTime.now();
  final DateTime modifiedAt = meta.lastModified ?? meta.dtStamp ?? createdAt;
  final CalendarJournal journal = CalendarJournal(
    id: id,
    title: title,
    entryDate: entryDate,
    description: description?.isEmpty == true ? null : description,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    icsMeta: mergedMeta,
  );
  return _ParsedJournal(
    journal: journal,
    meta: mergedMeta,
  );
}

CalendarDateTime _fallbackJournalEntryDate(CalendarIcsMeta meta) {
  final DateTime fallbackDate = meta.created ?? meta.dtStamp ?? DateTime.now();
  final bool isUtc = fallbackDate.isUtc;
  return CalendarDateTime(
    value: fallbackDate,
    tzid: null,
    isAllDay: false,
    isFloating: !isUtc,
  );
}

_ParsedDayEvent _parseDayEventComponent(CalendarRawComponent component) {
  final CalendarIcsMeta meta = _parseMeta(component);
  final List<CalendarRawProperty> properties = component.properties;
  final String id = _firstPropertyValue(properties, _axiTaskIdProperty) ??
      meta.uid ??
      const Uuid().v4();
  final String title = _firstPropertyValue(properties, _icsPropertySummary) ??
      _eventFallbackTitle;
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final CalendarDateTime? startDateTime =
      dtStartProp == null ? null : _parseDateTime(dtStartProp);
  final DateTime startDate = startDateTime?.value ?? DateTime.now().toLocal();
  final DateTime? endDate = _parseEventEndDate(
    properties,
    startDate,
  );

  final List<CalendarAlarm> alarms = _parseAlarms(component.components);
  final ReminderPreferences reminders =
      _remindersFromAlarms(alarms).normalized();

  final DateTime createdAt = meta.created ?? meta.dtStamp ?? DateTime.now();
  final DateTime modifiedAt = meta.lastModified ?? meta.dtStamp ?? createdAt;
  final CalendarIcsMeta mergedMeta = meta.copyWith(alarms: alarms);

  final DayEvent event = DayEvent(
    id: id,
    title: title,
    description: description?.isEmpty == true ? null : description,
    startDate: startDate,
    endDate: endDate,
    reminders: reminders,
    createdAt: createdAt,
    modifiedAt: modifiedAt,
    icsMeta: mergedMeta,
  );
  return _ParsedDayEvent(event: event, meta: mergedMeta);
}

TaskOccurrenceOverride? _parseTaskOverride(
  CalendarRawComponent component, {
  required bool isEvent,
  required bool isCalendarCancel,
}) {
  final CalendarRawProperty? recurrenceProp =
      _firstProperty(component.properties, _icsPropertyRecurrenceId);
  if (recurrenceProp == null) {
    return null;
  }
  final CalendarDateTime? recurrenceId = _parseDateTime(recurrenceProp);
  if (recurrenceId == null) {
    return null;
  }
  final CalendarIcsMeta meta = _parseMeta(component);
  final List<CalendarRawProperty> properties = component.properties;
  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final DateTime? scheduledTime =
      dtStartProp == null ? null : _parseDateTime(dtStartProp)?.value;

  final _ScheduleSpan span = _parseScheduleSpan(
    properties,
    scheduledTime,
    isEvent: isEvent,
  );

  final String? summary = _firstPropertyValue(properties, _icsPropertySummary);
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final String? location =
      _firstPropertyValue(properties, _icsPropertyLocation);
  final TaskPriority? priority = _parsePriority(properties);
  final bool isCompleted = _isCompleted(properties, meta.status);
  final bool isCancelled = meta.status?.isCancelled == true || isCalendarCancel;
  final TaskChecklistResult checklistResult =
      _parseChecklist(properties, meta.axi);
  final String? rangeValue =
      recurrenceProp.parameters.firstValue(_icsParamRange);
  final RecurrenceRange? range =
      rangeValue == null ? null : RecurrenceRange.fromIcsValue(rangeValue);
  final List<CalendarRawProperty> rawProperties = meta.rawProperties;
  final List<CalendarRawComponent> rawComponents = meta.rawComponents;

  return TaskOccurrenceOverride(
    scheduledTime: scheduledTime,
    duration: span.duration,
    endDate: span.endDate,
    isCancelled: isCancelled ? true : null,
    priority: priority,
    isCompleted: isCompleted ? true : null,
    title: summary,
    description: description,
    location: location,
    checklist: checklistResult.items.isEmpty ? null : checklistResult.items,
    recurrenceId: recurrenceId,
    range: range,
    rawProperties: rawProperties,
    rawComponents: rawComponents,
  );
}

class _ScheduleSpan {
  const _ScheduleSpan({
    required this.duration,
    required this.endDate,
  });

  final Duration? duration;
  final DateTime? endDate;
}

_ScheduleSpan _parseScheduleSpan(
  List<CalendarRawProperty> properties,
  DateTime? start, {
  required bool isEvent,
}) {
  final CalendarRawProperty? scheduleEnd =
      _firstProperty(properties, _axiScheduleEndProperty);
  final CalendarRawProperty? scheduleDuration =
      _firstProperty(properties, _axiScheduleDurationProperty);
  if (scheduleEnd != null) {
    final DateTime? end = _parseDateTime(scheduleEnd)?.value;
    return _ScheduleSpan(
      duration: start != null && end != null ? end.difference(start) : null,
      endDate: end,
    );
  }
  if (scheduleDuration != null) {
    final Duration? duration = _parseDuration(scheduleDuration.value);
    return _ScheduleSpan(
      duration: duration,
      endDate: start != null && duration != null ? start.add(duration) : null,
    );
  }
  final CalendarRawProperty? durationProp =
      _firstProperty(properties, _icsPropertyDuration);
  if (durationProp != null) {
    final Duration? duration = _parseDuration(durationProp.value);
    return _ScheduleSpan(
      duration: duration,
      endDate: start != null && duration != null ? start.add(duration) : null,
    );
  }
  if (isEvent) {
    final CalendarRawProperty? dtEndProp =
        _firstProperty(properties, _icsPropertyDtEnd);
    final DateTime? end =
        dtEndProp == null ? null : _parseDateTime(dtEndProp)?.value;
    return _ScheduleSpan(
      duration: start != null && end != null ? end.difference(start) : null,
      endDate: end,
    );
  }
  return const _ScheduleSpan(duration: null, endDate: null);
}

DateTime? _parseEventEndDate(
  List<CalendarRawProperty> properties,
  DateTime start,
) {
  final CalendarRawProperty? dtEndProp =
      _firstProperty(properties, _icsPropertyDtEnd);
  if (dtEndProp != null) {
    final CalendarDateTime? endDateTime = _parseDateTime(dtEndProp);
    if (endDateTime != null) {
      return _subtractDays(endDateTime.value, 1);
    }
  }
  final CalendarRawProperty? durationProp =
      _firstProperty(properties, _icsPropertyDuration);
  if (durationProp != null) {
    final Duration? duration = _parseDuration(durationProp.value);
    if (duration != null) {
      final DateTime endDate = start.add(duration);
      return _subtractDays(endDate, 1);
    }
  }
  return null;
}

DateTime _subtractDays(DateTime date, int days) {
  final Duration duration = Duration(days: days);
  return date.subtract(duration);
}

CalendarIcsMeta _parseMeta(CalendarRawComponent component) {
  final List<CalendarRawProperty> properties = component.properties;
  final String? uid = _firstPropertyValue(properties, _icsPropertyUid);
  final DateTime? dtStamp = _parsePropertyDate(properties, _icsPropertyDtStamp);
  final DateTime? created = _parsePropertyDate(properties, _icsPropertyCreated);
  final DateTime? lastModified =
      _parsePropertyDate(properties, _icsPropertyLastModified);
  final int? sequence =
      int.tryParse(_firstPropertyValue(properties, _icsPropertySequence) ?? '');
  final CalendarIcsStatus? status = CalendarIcsStatus.fromIcsValue(
    _firstPropertyValue(properties, _icsPropertyStatus),
  );
  final CalendarPrivacyClass? privacyClass = CalendarPrivacyClass.fromIcsValue(
    _firstPropertyValue(properties, _icsPropertyClass),
  );
  final CalendarTransparency? transparency = CalendarTransparency.fromIcsValue(
    _firstPropertyValue(properties, _icsPropertyTransp),
  );
  final List<String> categories =
      _parseCategories(_firstPropertyValue(properties, _icsPropertyCategories));
  final String? url = _firstPropertyValue(properties, _icsPropertyUrl);
  final CalendarGeo? geo =
      _parseGeo(_firstPropertyValue(properties, _icsPropertyGeo));
  final List<CalendarAttachment> attachments =
      _parseAttachments(_propertiesByName(properties, _icsPropertyAttach));
  final CalendarOrganizer? organizer =
      _parseOrganizer(_firstProperty(properties, _icsPropertyOrganizer));
  final List<CalendarAttendee> attendees =
      _parseAttendees(_propertiesByName(properties, _icsPropertyAttendee));
  final CalendarIcsComponentType? componentType =
      _componentTypeFromName(component.name);

  final List<CalendarRawComponent> rawComponents = component.components
      .where((child) => child.name != _icsComponentValarm)
      .toList(growable: false);
  final List<CalendarRawProperty> rawProperties =
      properties.toList(growable: false);
  return CalendarIcsMeta(
    uid: uid,
    dtStamp: dtStamp,
    created: created,
    lastModified: lastModified,
    sequence: sequence,
    status: status,
    privacyClass: privacyClass,
    transparency: transparency,
    categories: categories,
    url: url,
    geo: geo,
    attachments: attachments,
    organizer: organizer,
    attendees: attendees,
    alarms: const <CalendarAlarm>[],
    axi: null,
    rawProperties: rawProperties,
    rawComponents: rawComponents,
    componentType: componentType,
  );
}

CalendarRawProperty? _firstProperty(
  List<CalendarRawProperty> properties,
  String name,
) {
  for (final CalendarRawProperty property in properties) {
    if (property.name == name) {
      return property;
    }
  }
  return null;
}

DateTime? _parsePropertyDate(
  List<CalendarRawProperty> properties,
  String name,
) {
  final CalendarRawProperty? property = _firstProperty(properties, name);
  if (property == null) {
    return null;
  }
  return _parseDateTime(property)?.value;
}

CalendarDateTime? _parseDateTime(CalendarRawProperty property) {
  final String value = property.value;
  if (value.isEmpty) {
    return null;
  }
  final bool isDateOnly =
      property.parameters.firstValue(_icsParamValue) == _icsParamValueDate ||
          value.length == _icsDateLength;
  if (isDateOnly) {
    final DateTime? date = _parseDate(value);
    if (date == null) {
      return null;
    }
    return CalendarDateTime(
      value: date,
      tzid: null,
      isAllDay: true,
      isFloating: false,
    );
  }
  final bool isUtc = value.endsWith(_icsValueZ);
  final String cleaned = isUtc ? value.substring(0, value.length - 1) : value;
  final DateTime? dateTime = _parseDateTimeValue(cleaned, isUtc: isUtc);
  if (dateTime == null) {
    return null;
  }
  final String? tzid = property.parameters.firstValue(_icsParamTzid);
  final bool isFloating = tzid == null && !isUtc;
  return CalendarDateTime(
    value: dateTime,
    tzid: tzid,
    isAllDay: false,
    isFloating: isFloating,
  );
}

DateTime? _parseDateTimeValue(String value, {required bool isUtc}) {
  if (value.length < _icsDateTimeShortLength) {
    return null;
  }
  final int? year = int.tryParse(value.substring(_icsYearStart, _icsYearEnd));
  final int? month =
      int.tryParse(value.substring(_icsMonthStart, _icsMonthEnd));
  final int? day = int.tryParse(value.substring(_icsDayStart, _icsDayEnd));
  final int? hour = int.tryParse(value.substring(_icsHourStart, _icsHourEnd));
  final int? minute =
      int.tryParse(value.substring(_icsMinuteStart, _icsMinuteEnd));
  final int? second = value.length >= _icsDateTimeMinLength
      ? int.tryParse(value.substring(_icsSecondStart, _icsSecondEnd))
      : 0;
  if ([year, month, day, hour, minute].any((part) => part == null)) {
    return null;
  }
  if (isUtc) {
    return DateTime.utc(
      year!,
      month!,
      day!,
      hour!,
      minute!,
      second ?? 0,
    );
  }
  return DateTime(
    year!,
    month!,
    day!,
    hour!,
    minute!,
    second ?? 0,
  );
}

DateTime? _parseDate(String value) {
  if (value.length != _icsDateLength) {
    return null;
  }
  final int? year = int.tryParse(value.substring(_icsYearStart, _icsYearEnd));
  final int? month =
      int.tryParse(value.substring(_icsMonthStart, _icsMonthEnd));
  final int? day = int.tryParse(value.substring(_icsDayStart, _icsDayEnd));
  if ([year, month, day].any((part) => part == null)) {
    return null;
  }
  return DateTime(year!, month!, day!);
}

String _formatDate(DateTime value) {
  return '${_pad(value.year, 4)}${_pad(value.month, 2)}${_pad(value.day, 2)}';
}

String _formatDateTime(DateTime value, {required bool isUtc}) {
  final DateTime resolved = isUtc ? value.toUtc() : value;
  return '${_pad(resolved.year, 4)}${_pad(resolved.month, 2)}'
      '${_pad(resolved.day, 2)}$_icsValueT${_pad(resolved.hour, 2)}'
      '${_pad(resolved.minute, 2)}${_pad(resolved.second, 2)}'
      '${isUtc ? _icsValueZ : ''}';
}

String _pad(int value, int width) => value.toString().padLeft(width, '0');

Duration? _parseDuration(String value) {
  final RegExpMatch? match = _icsDurationRegExp.firstMatch(value);
  if (match == null) {
    return null;
  }
  final bool isNegative = match.group(_icsDurationSignGroup) != null;
  final int weeks =
      int.tryParse(match.group(_icsDurationWeeksGroup) ?? '') ?? 0;
  final int days = int.tryParse(match.group(_icsDurationDaysGroup) ?? '') ?? 0;
  final int hours =
      int.tryParse(match.group(_icsDurationHoursGroup) ?? '') ?? 0;
  final int minutes =
      int.tryParse(match.group(_icsDurationMinutesGroup) ?? '') ?? 0;
  final int seconds =
      int.tryParse(match.group(_icsDurationSecondsGroup) ?? '') ?? 0;
  final int totalDays = days + (weeks * _daysPerWeek);
  final Duration duration = Duration(
    days: totalDays,
    hours: hours,
    minutes: minutes,
    seconds: seconds,
  );
  if (!isNegative) {
    return duration;
  }
  return Duration(microseconds: duration.inMicroseconds * -1);
}

String _formatDuration(Duration duration) {
  final bool isNegative = duration.isNegative;
  var remainingSeconds = duration.inSeconds.abs();
  const int secondsPerHour = _minutesPerHour * _secondsPerMinute;
  const int secondsPerDay = _hoursPerDay * secondsPerHour;
  const int secondsPerWeek = _daysPerWeek * secondsPerDay;
  final int weeks = remainingSeconds ~/ secondsPerWeek;
  remainingSeconds -= weeks * secondsPerWeek;
  final int days = remainingSeconds ~/ secondsPerDay;
  remainingSeconds -= days * secondsPerDay;
  final int hours = remainingSeconds ~/ secondsPerHour;
  remainingSeconds -= hours * secondsPerHour;
  final int minutes = remainingSeconds ~/ _secondsPerMinute;
  remainingSeconds -= minutes * _secondsPerMinute;
  final int seconds = remainingSeconds;

  final StringBuffer buffer = StringBuffer();
  if (isNegative) {
    buffer.write('-');
  }
  buffer.write(_icsDurationPrefix);
  if (weeks > 0) {
    buffer
      ..write(weeks)
      ..write(_icsDurationWeekSuffix);
  }
  if (days > 0) {
    buffer
      ..write(days)
      ..write(_icsDurationDaySuffix);
  }
  if (hours > 0 || minutes > 0 || seconds > 0) {
    buffer.write(_icsDurationTimePrefix);
  }
  if (hours > 0) {
    buffer
      ..write(hours)
      ..write(_icsDurationHourSuffix);
  }
  if (minutes > 0) {
    buffer
      ..write(minutes)
      ..write(_icsDurationMinuteSuffix);
  }
  if (seconds > 0 || buffer.toString().endsWith(_icsDurationTimePrefix)) {
    buffer
      ..write(seconds)
      ..write(_icsDurationSecondSuffix);
  }
  return buffer.toString();
}

CalendarGeo? _parseGeo(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final List<String> parts = value.split(_icsValueSemicolon);
  if (parts.length != 2) {
    return null;
  }
  final double? lat = double.tryParse(parts.first);
  final double? lon = double.tryParse(parts.last);
  if (lat == null || lon == null) {
    return null;
  }
  return CalendarGeo(latitude: lat, longitude: lon);
}

List<String> _parseCategories(String? value) {
  if (value == null || value.isEmpty) {
    return const <String>[];
  }
  return value
      .split(_icsValueComma)
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

List<CalendarAttachment> _parseAttachments(
  List<CalendarRawProperty> properties,
) {
  final List<CalendarAttachment> attachments = <CalendarAttachment>[];
  for (final CalendarRawProperty property in properties) {
    attachments.add(
      CalendarAttachment(
        value: property.value,
        formatType: property.parameters.firstValue(_icsParamFmtType),
        encoding: property.parameters.firstValue(_icsParamEncoding),
        label: property.parameters.firstValue(_icsParamLabel),
      ),
    );
  }
  return attachments;
}

CalendarOrganizer? _parseOrganizer(CalendarRawProperty? property) {
  if (property == null) {
    return null;
  }
  return CalendarOrganizer(
    address: _normalizeAddress(property.value),
    commonName: property.parameters.firstValue(_icsParamCn),
    directory: property.parameters.firstValue(_icsParamDir),
    sentBy: property.parameters.firstValue(_icsParamSentBy),
    role: CalendarParticipantRole.fromIcsValue(
      property.parameters.firstValue(_icsParamRole),
    ),
    status: CalendarParticipantStatus.fromIcsValue(
      property.parameters.firstValue(_icsParamPartStat),
    ),
    type: CalendarParticipantType.fromIcsValue(
      property.parameters.firstValue(_icsParamCutype),
    ),
    rsvp: _parseBoolean(property.parameters.firstValue(_icsParamRsvp)),
    delegatedTo: _parseAddresses(
      property.parameters.values(_icsParamDelegatedTo),
    ),
    delegatedFrom: _parseAddresses(
      property.parameters.values(_icsParamDelegatedFrom),
    ),
    members: _parseAddresses(
      property.parameters.values(_icsParamMember),
    ),
  );
}

List<CalendarAttendee> _parseAttendees(
  List<CalendarRawProperty> properties,
) {
  final List<CalendarAttendee> attendees = <CalendarAttendee>[];
  for (final CalendarRawProperty property in properties) {
    attendees.add(
      CalendarAttendee(
        address: _normalizeAddress(property.value),
        commonName: property.parameters.firstValue(_icsParamCn),
        directory: property.parameters.firstValue(_icsParamDir),
        sentBy: property.parameters.firstValue(_icsParamSentBy),
        role: CalendarParticipantRole.fromIcsValue(
          property.parameters.firstValue(_icsParamRole),
        ),
        status: CalendarParticipantStatus.fromIcsValue(
          property.parameters.firstValue(_icsParamPartStat),
        ),
        type: CalendarParticipantType.fromIcsValue(
          property.parameters.firstValue(_icsParamCutype),
        ),
        rsvp: _parseBoolean(property.parameters.firstValue(_icsParamRsvp)),
        delegatedTo: _parseAddresses(
          property.parameters.values(_icsParamDelegatedTo),
        ),
        delegatedFrom: _parseAddresses(
          property.parameters.values(_icsParamDelegatedFrom),
        ),
        members: _parseAddresses(property.parameters.values(_icsParamMember)),
      ),
    );
  }
  return attendees;
}

String _normalizeAddress(String value) {
  final String trimmed = value.trim();
  if (trimmed.toLowerCase().startsWith(_icsMailtoPrefix)) {
    return trimmed.substring(_icsMailtoPrefix.length);
  }
  return trimmed;
}

List<String> _parseAddresses(List<String> values) {
  final List<String> addresses = <String>[];
  for (final String value in values) {
    final List<String> split = value.split(_icsValueComma);
    for (final String part in split) {
      final String normalized = _normalizeAddress(part);
      if (normalized.isNotEmpty) {
        addresses.add(normalized);
      }
    }
  }
  return addresses;
}

bool _parseBoolean(String? value) =>
    value != null && value.toUpperCase() == _icsValueTrue;

TaskPriority? _parsePriority(List<CalendarRawProperty> properties) {
  final String? priorityName =
      _firstPropertyValue(properties, _axiPriorityProperty);
  if (priorityName == null) {
    return null;
  }
  for (final TaskPriority value in TaskPriority.values) {
    if (value.name == priorityName) {
      return value;
    }
  }
  return null;
}

bool _isCompleted(
  List<CalendarRawProperty> properties,
  CalendarIcsStatus? status,
) {
  if (status?.isCompleted == true) {
    return true;
  }
  final String? completed =
      _firstPropertyValue(properties, _icsPropertyCompleted);
  return completed != null && completed.isNotEmpty;
}

class TaskChecklistResult {
  const TaskChecklistResult({
    required this.items,
    required this.axi,
  });

  final List<TaskChecklistItem> items;
  final CalendarAxiExtensions? axi;
}

CalendarAxiExtensions? _mergeAxi(
  TaskChecklistResult checklist,
  List<CalendarCriticalPathLink> pathLinks,
) {
  final bool hasChecklist = checklist.items.isNotEmpty;
  final bool hasPaths = pathLinks.isNotEmpty;
  if (!hasChecklist && !hasPaths && checklist.axi == null) {
    return null;
  }
  final CalendarAxiExtensions base =
      checklist.axi ?? const CalendarAxiExtensions();
  return base.copyWith(
    checklist: hasChecklist ? checklist.items : base.checklist,
    criticalPaths: hasPaths ? pathLinks : base.criticalPaths,
  );
}

TaskChecklistResult _parseChecklist(
  List<CalendarRawProperty> properties,
  CalendarAxiExtensions? existingAxi,
) {
  final String? raw = _firstPropertyValue(properties, _axiChecklistProperty);
  if (raw == null || raw.isEmpty) {
    return TaskChecklistResult(
        items: const <TaskChecklistItem>[], axi: existingAxi);
  }
  final List<TaskChecklistItem> items = <TaskChecklistItem>[];
  try {
    final dynamic decoded = jsonDecode(raw);
    if (decoded is List) {
      final List<_ChecklistEntry> entries = <_ChecklistEntry>[];
      for (final dynamic item in decoded) {
        if (item is Map<String, dynamic>) {
          final String? id = item[_icsChecklistIdKey] as String?;
          final String? label = item[_icsChecklistLabelKey] as String?;
          final bool isCompleted =
              (item[_icsChecklistCompleteKey] as bool?) ?? false;
          final int? order = item[_icsChecklistOrderKey] as int?;
          if (id == null || label == null) {
            continue;
          }
          entries.add(
            _ChecklistEntry(
              item: TaskChecklistItem(
                id: id,
                label: label,
                isCompleted: isCompleted,
              ),
              order: order,
            ),
          );
        }
      }
      entries.sort((a, b) {
        final int? left = a.order;
        final int? right = b.order;
        if (left == null && right == null) {
          return 0;
        }
        if (left == null) {
          return 1;
        }
        if (right == null) {
          return -1;
        }
        return left.compareTo(right);
      });
      items.addAll(entries.map((entry) => entry.item));
    }
  } catch (_) {
    return TaskChecklistResult(
        items: const <TaskChecklistItem>[], axi: existingAxi);
  }
  final CalendarAxiExtensions axi =
      (existingAxi ?? const CalendarAxiExtensions()).copyWith(checklist: items);
  return TaskChecklistResult(items: items, axi: axi);
}

class _ChecklistEntry {
  const _ChecklistEntry({
    required this.item,
    required this.order,
  });

  final TaskChecklistItem item;
  final int? order;
}

List<CalendarAlarm> _parseAlarms(List<CalendarRawComponent> components) {
  final List<CalendarAlarm> alarms = <CalendarAlarm>[];
  for (final CalendarRawComponent component in components) {
    if (component.name != _icsComponentValarm) {
      continue;
    }
    final CalendarAlarm? alarm = _parseAlarm(component);
    if (alarm != null) {
      alarms.add(alarm);
    }
  }
  return alarms;
}

CalendarAlarm? _parseAlarm(CalendarRawComponent component) {
  final List<CalendarRawProperty> properties = component.properties;
  final String? actionValue =
      _firstPropertyValue(properties, _icsPropertyAction);
  final CalendarAlarmAction? action =
      CalendarAlarmAction.fromIcsValue(actionValue);
  if (action == null) {
    return null;
  }
  final CalendarRawProperty? triggerProp =
      _firstProperty(properties, _icsPropertyTrigger);
  if (triggerProp == null) {
    return null;
  }
  final CalendarAlarmTrigger? trigger = _parseAlarmTrigger(triggerProp);
  if (trigger == null) {
    return null;
  }
  final int? repeat =
      int.tryParse(_firstPropertyValue(properties, _icsPropertyRepeat) ?? '');
  final Duration? duration = _parseDuration(
    _firstPropertyValue(properties, _icsPropertyDuration) ?? '',
  );
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final String? summary = _firstPropertyValue(properties, _icsPropertySummary);
  final List<CalendarAttachment> attachments =
      _parseAttachments(_propertiesByName(properties, _icsPropertyAttach));
  final DateTime? acknowledged =
      _parsePropertyDate(properties, _icsPropertyAck);
  final List<CalendarAlarmRecipient> recipients = _parseAlarmRecipients(
      _propertiesByName(properties, _icsPropertyAttendee));
  return CalendarAlarm(
    action: action,
    trigger: trigger,
    repeat: repeat,
    duration: duration,
    description: description,
    summary: summary,
    attachments: attachments,
    acknowledged: acknowledged,
    recipients: recipients,
  );
}

CalendarAlarmTrigger? _parseAlarmTrigger(CalendarRawProperty triggerProp) {
  final String value = triggerProp.value;
  if (value.startsWith(_icsDurationPrefix) || value.startsWith('-')) {
    final Duration? duration = _parseDuration(value);
    if (duration == null) {
      return null;
    }
    final bool isNegative = duration.isNegative;
    final CalendarAlarmOffsetDirection direction = isNegative
        ? CalendarAlarmOffsetDirection.before
        : CalendarAlarmOffsetDirection.after;
    final CalendarAlarmRelativeTo relativeTo =
        triggerProp.parameters.firstValue(_icsParamRelated) == _icsValueEnd
            ? CalendarAlarmRelativeTo.end
            : CalendarAlarmRelativeTo.start;
    return CalendarAlarmTrigger(
      type: CalendarAlarmTriggerType.relative,
      absolute: null,
      offset: Duration(microseconds: duration.inMicroseconds.abs()),
      relativeTo: relativeTo,
      offsetDirection: direction,
    );
  }
  final CalendarDateTime? absolute = _parseDateTime(triggerProp);
  if (absolute == null) {
    return null;
  }
  return CalendarAlarmTrigger(
    type: CalendarAlarmTriggerType.absolute,
    absolute: absolute,
    offset: null,
    relativeTo: null,
    offsetDirection: null,
  );
}

List<CalendarAlarmRecipient> _parseAlarmRecipients(
  List<CalendarRawProperty> properties,
) {
  final List<CalendarAlarmRecipient> recipients = <CalendarAlarmRecipient>[];
  for (final CalendarRawProperty property in properties) {
    recipients.add(
      CalendarAlarmRecipient(
        address: _normalizeAddress(property.value),
        commonName: property.parameters.firstValue(_icsParamCn),
      ),
    );
  }
  return recipients;
}

ReminderPreferences _remindersFromAlarms(List<CalendarAlarm> alarms) {
  final List<Duration> startOffsets = <Duration>[];
  final List<Duration> deadlineOffsets = <Duration>[];
  for (final CalendarAlarm alarm in alarms) {
    if (alarm.trigger.type != CalendarAlarmTriggerType.relative ||
        alarm.trigger.offset == null) {
      continue;
    }
    if (alarm.trigger.offsetDirection == CalendarAlarmOffsetDirection.after) {
      continue;
    }
    final Duration offset = alarm.trigger.offset!;
    final CalendarAlarmRelativeTo relativeTo =
        alarm.trigger.relativeTo ?? CalendarAlarmRelativeTo.start;
    final Duration normalized = Duration(
      microseconds: offset.inMicroseconds.abs(),
    );
    if (relativeTo == CalendarAlarmRelativeTo.end) {
      deadlineOffsets.add(normalized);
    } else {
      startOffsets.add(normalized);
    }
  }
  final ReminderPreferences preferences = ReminderPreferences(
    enabled: startOffsets.isNotEmpty || deadlineOffsets.isNotEmpty,
    startOffsets: startOffsets,
    deadlineOffsets: deadlineOffsets,
  );
  return preferences.normalized();
}

RecurrenceRule? _parseRecurrence(List<CalendarRawProperty> properties) {
  final CalendarRawProperty? rrule =
      _firstProperty(properties, _icsPropertyRrule);
  final List<CalendarRawProperty> rdates =
      _propertiesByName(properties, _icsPropertyRdate);
  final List<CalendarRawProperty> exdates =
      _propertiesByName(properties, _icsPropertyExdate);
  final List<CalendarRawProperty> exrules =
      _propertiesByName(properties, _icsPropertyExrule);
  final List<CalendarRawProperty> rawProps = <CalendarRawProperty>[];

  if (rrule == null && rdates.isEmpty && exdates.isEmpty && exrules.isEmpty) {
    return null;
  }
  RecurrenceFrequency frequency = RecurrenceFrequency.none;
  var interval = 1;
  DateTime? until;
  bool untilIsDate = false;
  int? count;
  List<int>? byWeekdays;
  List<int>? bySeconds;
  List<int>? byMinutes;
  List<int>? byHours;
  List<RecurrenceWeekday>? byDays;
  List<int>? byMonthDays;
  List<int>? byYearDays;
  List<int>? byWeekNumbers;
  List<int>? byMonths;
  List<int>? bySetPositions;
  CalendarWeekday? weekStart;

  if (rrule != null) {
    final Map<String, String> parts = _parseRruleParts(rrule.value);
    final String? freq = parts['FREQ'];
    frequency = _parseFrequency(freq, parts);
    interval = int.tryParse(parts['INTERVAL'] ?? '') ?? interval;
    count = int.tryParse(parts['COUNT'] ?? '');
    final String? untilRaw = parts['UNTIL'];
    if (untilRaw != null) {
      final CalendarRawProperty untilProp = CalendarRawProperty(
        name: _icsPropertyRrule,
        value: untilRaw,
        parameters: rrule.parameters,
      );
      final CalendarDateTime? untilValue = _parseDateTime(untilProp);
      if (untilValue != null) {
        until = untilValue.value;
        untilIsDate = untilValue.isAllDay;
      }
    }
    final String? byDayValue = parts['BYDAY'];
    byDays = _parseRecurrenceWeekdays(byDayValue);
    byWeekdays = _deriveWeekdaysFromByDays(byDays);
    byWeekdays ??= _parseIntList(byDayValue);
    bySeconds = _parseNumericList(parts['BYSECOND']);
    byMinutes = _parseNumericList(parts['BYMINUTE']);
    byHours = _parseNumericList(parts['BYHOUR']);
    byMonthDays = _parseNumericList(parts['BYMONTHDAY']);
    byYearDays = _parseNumericList(parts['BYYEARDAY']);
    byWeekNumbers = _parseNumericList(parts['BYWEEKNO']);
    byMonths = _parseNumericList(parts['BYMONTH']);
    bySetPositions = _parseNumericList(parts['BYSETPOS']);
    weekStart = CalendarWeekday.fromIcsValue(parts['WKST']);
    if (frequency == RecurrenceFrequency.none) {
      rawProps.add(rrule);
    }
  }
  if (exrules.isNotEmpty) {
    rawProps.addAll(exrules);
  }

  final List<CalendarDateTime> rDates = _parseDateList(rdates);
  final List<CalendarDateTime> exDates = _parseDateList(exdates);

  final RecurrenceRule rule = RecurrenceRule(
    frequency: frequency,
    interval: interval,
    byWeekdays: byWeekdays,
    until: until,
    count: count,
    bySeconds: bySeconds,
    byMinutes: byMinutes,
    byHours: byHours,
    byDays: byDays,
    byMonthDays: byMonthDays,
    byYearDays: byYearDays,
    byWeekNumbers: byWeekNumbers,
    byMonths: byMonths,
    bySetPositions: bySetPositions,
    weekStart: weekStart,
    untilIsDate: untilIsDate,
    rDates: rDates,
    exDates: exDates,
    rawProperties: rawProps,
  );
  return rule;
}

Map<String, String> _parseRruleParts(String value) {
  final Map<String, String> parts = <String, String>{};
  final List<String> segments = value.split(_icsValueSemicolon);
  for (final String segment in segments) {
    final int equalsIndex = segment.indexOf('=');
    if (equalsIndex <= 0 || equalsIndex == segment.length - 1) {
      continue;
    }
    final String key = segment.substring(0, equalsIndex).toUpperCase();
    final String partValue = segment.substring(equalsIndex + 1);
    parts[key] = partValue;
  }
  return parts;
}

RecurrenceFrequency _parseFrequency(
  String? freq,
  Map<String, String> parts,
) {
  if (freq == null) {
    return RecurrenceFrequency.none;
  }
  switch (freq) {
    case 'DAILY':
      final String? byday = parts['BYDAY'];
      final List<CalendarWeekday>? days = _parseWeekdays(byday);
      if (_isWeekdaySet(days)) {
        return RecurrenceFrequency.weekdays;
      }
      return RecurrenceFrequency.daily;
    case 'WEEKLY':
      return RecurrenceFrequency.weekly;
    case 'MONTHLY':
      return RecurrenceFrequency.monthly;
    default:
      return RecurrenceFrequency.none;
  }
}

List<CalendarWeekday>? _parseWeekdays(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final List<CalendarWeekday> days = <CalendarWeekday>[];
  final List<String> parts = value.split(_icsValueComma);
  for (final String part in parts) {
    final String trimmed = part.trim().toUpperCase();
    final String day = trimmed.replaceAll(RegExp(r'[^A-Z]'), '');
    final CalendarWeekday? weekday = CalendarWeekday.fromIcsValue(day);
    if (weekday != null) {
      days.add(weekday);
    }
  }
  return days.isEmpty ? null : days;
}

bool _isWeekdaySet(List<CalendarWeekday>? days) {
  if (days == null || days.length != 5) {
    return false;
  }
  final Set<CalendarWeekday> set = days.toSet();
  return set.contains(CalendarWeekday.monday) &&
      set.contains(CalendarWeekday.tuesday) &&
      set.contains(CalendarWeekday.wednesday) &&
      set.contains(CalendarWeekday.thursday) &&
      set.contains(CalendarWeekday.friday);
}

List<RecurrenceWeekday>? _parseRecurrenceWeekdays(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final List<RecurrenceWeekday> days = <RecurrenceWeekday>[];
  final List<String> parts = value.split(_icsValueComma);
  for (final String part in parts) {
    final String trimmed = part.trim();
    final RegExpMatch? match =
        RegExp(r'^([+-]?\d+)?([A-Z]{2})$').firstMatch(trimmed.toUpperCase());
    if (match == null) {
      continue;
    }
    final int? position =
        match.group(1) == null ? null : int.tryParse(match.group(1)!);
    final CalendarWeekday? weekday =
        CalendarWeekday.fromIcsValue(match.group(2));
    if (weekday == null) {
      continue;
    }
    days.add(
      RecurrenceWeekday(
        weekday: weekday,
        position: position,
      ),
    );
  }
  return days.isEmpty ? null : days;
}

List<int>? _deriveWeekdaysFromByDays(List<RecurrenceWeekday>? byDays) {
  if (byDays == null || byDays.isEmpty) {
    return null;
  }
  final List<int> weekdays = <int>[];
  for (final RecurrenceWeekday day in byDays) {
    if (day.position != null) {
      continue;
    }
    weekdays.add(day.weekday.isoValue);
  }
  return weekdays.isEmpty ? null : weekdays;
}

List<int>? _parseNumericList(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final List<int> numbers = <int>[];
  final List<String> parts = value.split(_icsValueComma);
  for (final String part in parts) {
    final int? parsed = int.tryParse(part.trim());
    if (parsed != null) {
      numbers.add(parsed);
    }
  }
  return numbers.isEmpty ? null : numbers;
}

List<int>? _parseIntList(String? value) {
  if (value == null) {
    return null;
  }
  final List<CalendarWeekday>? weekdays = _parseWeekdays(value);
  if (weekdays == null) {
    return null;
  }
  return weekdays.map((weekday) => weekday.isoValue).toList(growable: false);
}

List<CalendarDateTime> _parseDateList(List<CalendarRawProperty> properties) {
  final List<CalendarDateTime> results = <CalendarDateTime>[];
  for (final CalendarRawProperty property in properties) {
    final List<String> parts = property.value.split(_icsValueComma);
    for (final String part in parts) {
      final CalendarRawProperty entry = CalendarRawProperty(
        name: property.name,
        value: part,
        parameters: property.parameters,
      );
      final CalendarDateTime? parsed = _parseDateTime(entry);
      if (parsed != null) {
        results.add(parsed);
      }
    }
  }
  return results;
}

List<CalendarCriticalPathLink> _parseCriticalPathLinks(
  List<CalendarRawProperty> properties,
) {
  final List<String> pathIds = _propertiesByName(
    properties,
    _axiPathIdProperty,
  ).map((property) => property.value).toList(growable: false);
  final List<int?> pathOrders = _propertiesByName(
    properties,
    _axiPathOrderProperty,
  ).map((property) => int.tryParse(property.value)).toList(growable: false);
  final List<CalendarCriticalPathLink> links = <CalendarCriticalPathLink>[];
  for (var i = 0; i < pathIds.length; i++) {
    final int? order = i < pathOrders.length ? pathOrders[i] : null;
    links.add(
      CalendarCriticalPathLink(
        pathId: pathIds[i],
        order: order,
      ),
    );
  }
  return links;
}

void _recordCriticalPathLinks(
  Map<String, List<_CriticalPathEntry>> entries,
  String taskId,
  List<CalendarCriticalPathLink> links,
) {
  for (final CalendarCriticalPathLink link in links) {
    entries.putIfAbsent(link.pathId, () => <_CriticalPathEntry>[]).add(
          _CriticalPathEntry(taskId: taskId, order: link.order),
        );
  }
}

Map<String, CalendarCriticalPath> _buildCriticalPaths(
  Map<String, List<_CriticalPathEntry>> entries,
) {
  final Map<String, CalendarCriticalPath> paths =
      <String, CalendarCriticalPath>{};
  final DateTime now = DateTime.now();
  for (final MapEntry<String, List<_CriticalPathEntry>> entry
      in entries.entries) {
    final List<_CriticalPathEntry> items = entry.value;
    items.sort((a, b) {
      final int? left = a.order;
      final int? right = b.order;
      if (left == null && right == null) {
        return 0;
      }
      if (left == null) {
        return 1;
      }
      if (right == null) {
        return -1;
      }
      return left.compareTo(right);
    });
    final List<String> taskIds =
        items.map((item) => item.taskId).toList(growable: false);
    paths[entry.key] = CalendarCriticalPath(
      id: entry.key,
      name: entry.key,
      taskIds: taskIds,
      isArchived: false,
      createdAt: now,
      modifiedAt: now,
    );
  }
  return paths;
}

_FreeBusyParseResult _parseFreeBusyComponent(CalendarRawComponent component) {
  final List<CalendarRawProperty> properties = component.properties;
  final String? uid = _firstPropertyValue(properties, _icsPropertyUid);
  final String resolvedUid = uid ?? const Uuid().v4();
  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final CalendarRawProperty? dtEndProp =
      _firstProperty(properties, _icsPropertyDtEnd);
  final CalendarDateTime? start =
      dtStartProp == null ? null : _parseDateTime(dtStartProp);
  final CalendarDateTime? end =
      dtEndProp == null ? null : _parseDateTime(dtEndProp);
  final List<CalendarFreeBusyInterval> intervals = _parseFreeBusyIntervals(
      _propertiesByName(properties, _icsPropertyFreeBusy));
  final CalendarDateTime? resolvedStart = start ?? _earliestInterval(intervals);
  final CalendarDateTime? resolvedEnd = end ?? _latestInterval(intervals);
  if (resolvedStart == null || resolvedEnd == null) {
    return const _FreeBusyParseResult(overlay: null, uid: null);
  }
  final CalendarAvailabilityOverlay overlay = CalendarAvailabilityOverlay(
    owner: resolvedUid,
    rangeStart: resolvedStart,
    rangeEnd: resolvedEnd,
    intervals: intervals,
    isRedacted: true,
  );
  return _FreeBusyParseResult(overlay: overlay, uid: resolvedUid);
}

List<CalendarFreeBusyInterval> _parseFreeBusyIntervals(
  List<CalendarRawProperty> properties,
) {
  final List<CalendarFreeBusyInterval> intervals = <CalendarFreeBusyInterval>[];
  for (final CalendarRawProperty property in properties) {
    final CalendarFreeBusyType type = CalendarFreeBusyType.fromIcsValue(
          property.parameters.firstValue(_icsParamFbType),
        ) ??
        CalendarFreeBusyType.busy;
    final List<String> periods = property.value.split(_icsValueComma);
    for (final String period in periods) {
      final List<String> parts = period.split(_icsValueSlash);
      if (parts.length != 2) {
        continue;
      }
      final CalendarDateTime? start = _parseDateTime(
        CalendarRawProperty(
          name: _icsPropertyFreeBusy,
          value: parts.first,
          parameters: property.parameters,
        ),
      );
      if (start == null) {
        continue;
      }
      final Duration? duration = _parseDuration(parts.last);
      CalendarDateTime? end;
      if (duration != null) {
        end = start.copyWith(value: start.value.add(duration));
      } else {
        end = _parseDateTime(
          CalendarRawProperty(
            name: _icsPropertyFreeBusy,
            value: parts.last,
            parameters: property.parameters,
          ),
        );
      }
      if (end == null) {
        continue;
      }
      intervals.add(
        CalendarFreeBusyInterval(
          start: start,
          end: end,
          type: type,
        ),
      );
    }
  }
  return intervals;
}

CalendarDateTime? _earliestInterval(List<CalendarFreeBusyInterval> intervals) {
  CalendarDateTime? earliest;
  for (final CalendarFreeBusyInterval interval in intervals) {
    if (earliest == null || interval.start.value.isBefore(earliest.value)) {
      earliest = interval.start;
    }
  }
  return earliest;
}

CalendarDateTime? _latestInterval(List<CalendarFreeBusyInterval> intervals) {
  CalendarDateTime? latest;
  for (final CalendarFreeBusyInterval interval in intervals) {
    if (latest == null || interval.end.value.isAfter(latest.value)) {
      latest = interval.end;
    }
  }
  return latest;
}

CalendarAvailability? _parseAvailabilityComponent(
  CalendarRawComponent component,
) {
  final CalendarIcsMeta baseMeta = _parseMeta(component);
  final CalendarIcsMeta meta = baseMeta.copyWith(
    rawComponents: baseMeta.rawComponents
        .where((child) => child.name != _icsComponentAvailable)
        .toList(growable: false),
  );
  final List<CalendarRawProperty> properties = component.properties;
  final String id =
      _firstPropertyValue(properties, _icsPropertyUid) ?? const Uuid().v4();
  final CalendarRawProperty? dtStartProp =
      _firstProperty(properties, _icsPropertyDtStart);
  final CalendarRawProperty? dtEndProp =
      _firstProperty(properties, _icsPropertyDtEnd);
  final CalendarDateTime? start =
      dtStartProp == null ? null : _parseDateTime(dtStartProp);
  final CalendarDateTime? end =
      dtEndProp == null ? null : _parseDateTime(dtEndProp);
  if (start == null || end == null) {
    return null;
  }
  final String? summary = _firstPropertyValue(properties, _icsPropertySummary);
  final String? description =
      _firstPropertyValue(properties, _icsPropertyDescription);
  final List<CalendarAvailabilityWindow> windows =
      _parseAvailabilityWindows(component.components);
  return CalendarAvailability(
    id: id,
    start: start,
    end: end,
    summary: summary,
    description: description,
    windows: windows,
    icsMeta: meta,
  );
}

List<CalendarAvailabilityWindow> _parseAvailabilityWindows(
  List<CalendarRawComponent> components,
) {
  final List<CalendarAvailabilityWindow> windows =
      <CalendarAvailabilityWindow>[];
  for (final CalendarRawComponent component in components) {
    if (component.name != _icsComponentAvailable) {
      continue;
    }
    final CalendarRawProperty? dtStartProp =
        _firstProperty(component.properties, _icsPropertyDtStart);
    final CalendarRawProperty? dtEndProp =
        _firstProperty(component.properties, _icsPropertyDtEnd);
    final CalendarDateTime? start =
        dtStartProp == null ? null : _parseDateTime(dtStartProp);
    final CalendarDateTime? end =
        dtEndProp == null ? null : _parseDateTime(dtEndProp);
    if (start == null || end == null) {
      continue;
    }
    final String? summary =
        _firstPropertyValue(component.properties, _icsPropertySummary);
    final String? description =
        _firstPropertyValue(component.properties, _icsPropertyDescription);
    windows.add(
      CalendarAvailabilityWindow(
        start: start,
        end: end,
        summary: summary,
        description: description,
      ),
    );
  }
  return windows;
}

Map<String, List<CalendarCriticalPathLink>> _buildCriticalPathLinks(
  CalendarModel model,
) {
  final Map<String, List<CalendarCriticalPathLink>> links =
      <String, List<CalendarCriticalPathLink>>{};
  for (final CalendarCriticalPath path in model.criticalPaths.values) {
    for (var index = 0; index < path.taskIds.length; index++) {
      final String taskId = path.taskIds[index];
      links.putIfAbsent(taskId, () => <CalendarCriticalPathLink>[]).add(
            CalendarCriticalPathLink(pathId: path.id, order: index),
          );
    }
  }
  return links;
}

Map<String, String> _buildTaskUidLookup(CalendarModel model) {
  final Map<String, String> lookup = <String, String>{};
  for (final CalendarTask task in model.tasks.values) {
    final String uid = task.icsMeta?.uid ?? '${task.id}$_icsUidSuffix';
    lookup[task.id] = uid;
  }
  return lookup;
}

CalendarIcsComponentType _resolveTaskComponentType(
  CalendarTask task,
  CalendarIcsMeta? meta,
) {
  final CalendarIcsComponentType? componentType = meta?.componentType;
  final bool hasSchedule = task.scheduledTime != null;
  final bool hasDeadline = task.deadline != null;
  if (componentType?.isEvent == true && hasSchedule && !hasDeadline) {
    return componentType!;
  }
  return _defaultTaskComponentType;
}

void _writeTaskComponent(
  _IcsWriter writer,
  CalendarTask task, {
  required Map<String, List<CalendarCriticalPathLink>> criticalPathLinks,
  required Map<String, String> taskUids,
}) {
  final CalendarIcsMeta? meta = task.icsMeta;
  final CalendarIcsComponentType componentType =
      _resolveTaskComponentType(task, meta);
  final bool isEventComponent = componentType.isEvent;
  final String componentName =
      isEventComponent ? _icsComponentVevent : _icsComponentVtodo;
  final String uid = meta?.uid ?? '${task.id}$_icsUidSuffix';
  writer.beginComponent(componentName);
  writer.writeProperty(_icsPropertyUid, uid, escapeText: false);
  writer.writeProperty(_axiTaskIdProperty, task.id, escapeText: false);
  _writeMeta(
    writer,
    task.modifiedAt,
    meta,
    defaultPrivacyClass: _defaultPrivacyClass,
    defaultTransparency: isEventComponent ? _defaultEventTransparency : null,
  );

  writer.writeProperty(_icsPropertySummary, task.title);
  if (task.description != null && task.description!.isNotEmpty) {
    writer.writeProperty(_icsPropertyDescription, task.description!);
  }
  if (task.location != null && task.location!.isNotEmpty) {
    writer.writeProperty(_icsPropertyLocation, task.location!);
  }

  final CalendarRawProperty? rawDtStart =
      _rawProperty(meta, _icsPropertyDtStart);
  if (task.scheduledTime != null) {
    _writeDateTimeProperty(
      writer,
      _icsPropertyDtStart,
      task.scheduledTime!,
      rawProperty: rawDtStart,
      isAllDay: false,
    );
  }

  if (!isEventComponent) {
    final CalendarRawProperty? rawDue = _rawProperty(meta, _icsPropertyDue);
    if (task.deadline != null) {
      _writeDateTimeProperty(
        writer,
        _icsPropertyDue,
        task.deadline!,
        rawProperty: rawDue,
        isAllDay: false,
      );
    }
  }

  if (task.scheduledTime != null) {
    if (isEventComponent) {
      if (task.endDate != null) {
        final CalendarRawProperty? rawDtEnd =
            _rawProperty(meta, _icsPropertyDtEnd);
        _writeDateTimeProperty(
          writer,
          _icsPropertyDtEnd,
          task.endDate!,
          rawProperty: rawDtEnd,
          isAllDay: false,
        );
      } else if (task.duration != null) {
        final String durationValue = _formatDuration(task.duration!);
        writer.writeProperty(
          _icsPropertyDuration,
          durationValue,
          escapeText: false,
        );
      }
    } else {
      final bool hasDeadline = task.deadline != null;
      if (task.endDate != null) {
        final CalendarRawProperty? rawScheduleEnd =
            _rawProperty(meta, _axiScheduleEndProperty);
        _writeDateTimeProperty(
          writer,
          _axiScheduleEndProperty,
          task.endDate!,
          rawProperty: rawScheduleEnd,
          isAllDay: false,
        );
      } else if (task.duration != null) {
        final String durationValue = _formatDuration(task.duration!);
        final String propertyName =
            hasDeadline ? _axiScheduleDurationProperty : _icsPropertyDuration;
        writer.writeProperty(propertyName, durationValue, escapeText: false);
      }
    }
  }

  if (task.priority != null) {
    writer.writeProperty(
      _axiPriorityProperty,
      task.priority!.name,
      escapeText: false,
    );
  }

  if (isEventComponent) {
    final CalendarIcsStatus? status = meta?.status;
    if (status != null) {
      writer.writeProperty(
        _icsPropertyStatus,
        status.icsValue,
        escapeText: false,
      );
    }
  } else {
    final String statusValue = task.isCompleted
        ? CalendarIcsStatus.completed.icsValue
        : (meta?.status?.icsValue ?? CalendarIcsStatus.needsAction.icsValue);
    writer.writeProperty(_icsPropertyStatus, statusValue, escapeText: false);

    if (task.checklist.isNotEmpty) {
      final int checklistPercent = _percentComplete(task.checklist);
      writer.writeProperty(
        _icsPropertyPercentComplete,
        checklistPercent.toString(),
        escapeText: false,
      );
    }
  }

  final String checklistPayload = _encodeChecklist(task.checklist);
  if (checklistPayload.isNotEmpty) {
    writer.writeProperty(_axiChecklistProperty, checklistPayload);
  }

  final RecurrenceRule recurrence = task.effectiveRecurrence;
  final bool hasRecurrenceData = !recurrence.isNone ||
      recurrence.rDates.isNotEmpty ||
      recurrence.exDates.isNotEmpty ||
      recurrence.rawProperties.isNotEmpty;
  if (hasRecurrenceData) {
    final bool wroteRrule = !recurrence.isNone;
    if (wroteRrule) {
      final String rruleValue = _formatRrule(recurrence);
      writer.writeProperty(_icsPropertyRrule, rruleValue, escapeText: false);
    }
    _writeDateList(writer, _icsPropertyRdate, recurrence.rDates);
    final List<CalendarDateTime> exDates = _mergeExDates(
      recurrence.exDates,
      task.occurrenceOverrides,
      task,
    );
    _writeDateList(writer, _icsPropertyExdate, exDates);
    for (final CalendarRawProperty raw in recurrence.rawProperties) {
      if (wroteRrule && raw.name == _icsPropertyRrule) {
        continue;
      }
      writer.writeRawProperty(raw);
    }
  }

  final List<CalendarAlarm> alarms =
      _mergeAlarms(meta?.alarms ?? const <CalendarAlarm>[], task.reminders);
  for (final CalendarAlarm alarm in alarms) {
    _writeAlarm(writer, alarm);
  }

  final List<CalendarCriticalPathLink> links =
      criticalPathLinks[task.id] ?? const <CalendarCriticalPathLink>[];
  for (final CalendarCriticalPathLink link in links) {
    writer.writeProperty(_axiPathIdProperty, link.pathId, escapeText: false);
    if (link.order != null) {
      writer.writeProperty(
        _axiPathOrderProperty,
        link.order!.toString(),
        escapeText: false,
      );
    }
    final String? related = _relatedTaskId(
      link,
      criticalPathLinks,
      taskUids,
    );
    if (related != null) {
      writer.writeProperty(
        _icsPropertyRelatedTo,
        related,
        parameters: const <CalendarPropertyParameter>[
          CalendarPropertyParameter(
            name: _icsParamRelType,
            values: <String>[_icsValueSibling],
          ),
        ],
        escapeText: false,
      );
    }
  }

  _writeParticipants(writer, meta);
  final Set<String> rawPropertySkips =
      isEventComponent ? _eventTaskRawPropertySkips : _taskRawPropertySkips;
  _writeMetaRawProperties(writer, meta, rawPropertySkips);
  _writeMetaRawComponents(writer, meta);
  writer.endComponent(componentName);

  _writeOverrides(
    writer,
    task,
    uid,
    componentType: componentType,
  );
}

String? _relatedTaskId(
  CalendarCriticalPathLink link,
  Map<String, List<CalendarCriticalPathLink>> links,
  Map<String, String> taskUids,
) {
  if (link.order == null || link.order == 0) {
    return null;
  }
  final int targetOrder = link.order! - 1;
  for (final MapEntry<String, List<CalendarCriticalPathLink>> entry
      in links.entries) {
    final CalendarCriticalPathLink? match = entry.value.firstWhereOrNull(
      (item) => item.pathId == link.pathId && item.order == targetOrder,
    );
    if (match != null) {
      final String prevTaskId = entry.key;
      return taskUids[prevTaskId] ?? prevTaskId;
    }
  }
  return null;
}

void _writeOverrides(
  _IcsWriter writer,
  CalendarTask task,
  String uid, {
  required CalendarIcsComponentType componentType,
}) {
  final RecurrenceRule recurrence = task.effectiveRecurrence;
  if (recurrence.isNone || task.occurrenceOverrides.isEmpty) {
    return;
  }
  final bool isEventComponent = componentType.isEvent;
  final String componentName =
      isEventComponent ? _icsComponentVevent : _icsComponentVtodo;
  for (final MapEntry<String, TaskOccurrenceOverride> entry
      in task.occurrenceOverrides.entries) {
    final TaskOccurrenceOverride override = entry.value;
    final CalendarDateTime? recurrenceId =
        override.recurrenceId ?? _recurrenceIdFromOverrideKey(entry.key, task);
    if (recurrenceId == null) {
      continue;
    }
    if (override.isCancelled == true) {
      continue;
    }
    final Set<String> skip = <String>{}
      ..add(_icsPropertyUid)
      ..add(_icsPropertyRecurrenceId);
    writer.beginComponent(componentName);
    writer.writeProperty(_icsPropertyUid, uid, escapeText: false);
    _writeDateTimeProperty(
      writer,
      _icsPropertyRecurrenceId,
      recurrenceId.value,
      rawProperty: null,
      isAllDay: recurrenceId.isAllDay,
      tzidOverride: recurrenceId.tzid,
      isFloatingOverride: recurrenceId.isFloating,
      rangeOverride: override.range,
    );
    if (override.title != null) {
      writer.writeProperty(_icsPropertySummary, override.title!);
      skip.add(_icsPropertySummary);
    }
    if (override.description != null) {
      writer.writeProperty(_icsPropertyDescription, override.description!);
      skip.add(_icsPropertyDescription);
    }
    if (override.location != null) {
      writer.writeProperty(_icsPropertyLocation, override.location!);
      skip.add(_icsPropertyLocation);
    }
    if (override.scheduledTime != null) {
      _writeDateTimeProperty(
        writer,
        _icsPropertyDtStart,
        override.scheduledTime!,
        rawProperty: null,
        isAllDay: false,
      );
      skip.add(_icsPropertyDtStart);
    }
    if (isEventComponent) {
      if (override.endDate != null) {
        _writeDateTimeProperty(
          writer,
          _icsPropertyDtEnd,
          override.endDate!,
          rawProperty: null,
          isAllDay: false,
        );
        skip.add(_icsPropertyDtEnd);
      } else if (override.duration != null) {
        writer.writeProperty(
          _icsPropertyDuration,
          _formatDuration(override.duration!),
          escapeText: false,
        );
        skip.add(_icsPropertyDuration);
      }
    } else {
      if (override.endDate != null) {
        _writeDateTimeProperty(
          writer,
          _axiScheduleEndProperty,
          override.endDate!,
          rawProperty: null,
          isAllDay: false,
        );
        skip.add(_axiScheduleEndProperty);
      } else if (override.duration != null) {
        writer.writeProperty(
          _axiScheduleDurationProperty,
          _formatDuration(override.duration!),
          escapeText: false,
        );
        skip.add(_axiScheduleDurationProperty);
      }
    }
    if (override.priority != null) {
      writer.writeProperty(
        _axiPriorityProperty,
        override.priority!.name,
        escapeText: false,
      );
      skip.add(_axiPriorityProperty);
    }
    if (!isEventComponent && override.isCompleted == true) {
      writer.writeProperty(
        _icsPropertyStatus,
        CalendarIcsStatus.completed.icsValue,
        escapeText: false,
      );
      skip.add(_icsPropertyStatus);
    }
    if (override.checklist != null && override.checklist!.isNotEmpty) {
      writer.writeProperty(
        _axiChecklistProperty,
        _encodeChecklist(override.checklist!),
      );
      skip.add(_axiChecklistProperty);
    }
    _writeRawProperties(writer, override.rawProperties, skip);
    _writeRawComponents(writer, override.rawComponents);
    writer.endComponent(componentName);
  }
}

void _writeDayEventComponent(_IcsWriter writer, DayEvent event) {
  final CalendarIcsMeta? meta = event.icsMeta;
  final String uid = meta?.uid ?? '${event.id}$_icsUidSuffix';
  writer.beginComponent(_icsComponentVevent);
  writer.writeProperty(_icsPropertyUid, uid, escapeText: false);
  writer.writeProperty(_axiTaskIdProperty, event.id, escapeText: false);
  _writeMeta(
    writer,
    event.modifiedAt,
    meta,
    defaultPrivacyClass: _defaultPrivacyClass,
    defaultTransparency: _defaultDayEventTransparency,
  );
  writer.writeProperty(_icsPropertySummary, event.title);
  if (event.description != null && event.description!.isNotEmpty) {
    writer.writeProperty(_icsPropertyDescription, event.description!);
  }

  _writeDateTimeProperty(
    writer,
    _icsPropertyDtStart,
    event.normalizedStart,
    rawProperty: _rawProperty(meta, _icsPropertyDtStart),
    isAllDay: true,
  );

  if (event.normalizedEnd.isAfter(event.normalizedStart)) {
    final DateTime dtEnd = event.normalizedEnd.add(const Duration(days: 1));
    _writeDateTimeProperty(
      writer,
      _icsPropertyDtEnd,
      dtEnd,
      rawProperty: _rawProperty(meta, _icsPropertyDtEnd),
      isAllDay: true,
    );
  }

  final List<CalendarAlarm> alarms =
      _mergeAlarms(meta?.alarms ?? const <CalendarAlarm>[], event.reminders);
  for (final CalendarAlarm alarm in alarms) {
    _writeAlarm(writer, alarm);
  }
  _writeParticipants(writer, meta);
  _writeMetaRawProperties(writer, meta, _eventRawPropertySkips);
  _writeMetaRawComponents(writer, meta);
  writer.endComponent(_icsComponentVevent);
}

void _writeJournalComponent(_IcsWriter writer, CalendarJournal journal) {
  final CalendarIcsMeta? meta = journal.icsMeta;
  final String uid = meta?.uid ?? '${journal.id}$_icsUidSuffix';
  writer
    ..beginComponent(_icsComponentVjournal)
    ..writeProperty(_icsPropertyUid, uid, escapeText: false)
    ..writeProperty(_axiTaskIdProperty, journal.id, escapeText: false);
  _writeMeta(
    writer,
    journal.modifiedAt,
    meta,
    defaultPrivacyClass: _defaultPrivacyClass,
  );
  _writeJournalStatus(writer, meta);
  writer.writeProperty(_icsPropertySummary, journal.title);
  if (journal.description != null && journal.description!.isNotEmpty) {
    writer.writeProperty(_icsPropertyDescription, journal.description!);
  }
  _writeDateTimeProperty(
    writer,
    _icsPropertyDtStart,
    journal.entryDate.value,
    rawProperty: _rawProperty(meta, _icsPropertyDtStart),
    isAllDay: journal.entryDate.isAllDay,
    tzidOverride: journal.entryDate.tzid,
    isFloatingOverride: journal.entryDate.isFloating,
  );
  final List<CalendarAlarm> alarms = meta?.alarms ?? const <CalendarAlarm>[];
  for (final CalendarAlarm alarm in alarms) {
    _writeAlarm(writer, alarm);
  }
  _writeParticipants(writer, meta);
  _writeMetaRawProperties(writer, meta, _journalRawPropertySkips);
  _writeMetaRawComponents(writer, meta);
  writer.endComponent(_icsComponentVjournal);
}

void _writeJournalStatus(_IcsWriter writer, CalendarIcsMeta? meta) {
  final CalendarRawProperty? rawStatus = _rawProperty(meta, _icsPropertyStatus);
  if (rawStatus != null) {
    writer.writeRawProperty(rawStatus);
    return;
  }
  if (meta?.status != null) {
    writer.writeProperty(
      _icsPropertyStatus,
      meta!.status!.icsValue,
      escapeText: false,
    );
  }
}

void _writeAvailabilityComponent(
  _IcsWriter writer,
  CalendarAvailability availability,
  String key,
) {
  final CalendarIcsMeta? meta = availability.icsMeta;
  final String uid = meta?.uid ?? key;
  writer.beginComponent(_icsComponentVavailability);
  writer.writeProperty(_icsPropertyUid, uid, escapeText: false);
  _writeMetaFieldsOnly(writer, meta);
  if (availability.summary != null && availability.summary!.isNotEmpty) {
    writer.writeProperty(_icsPropertySummary, availability.summary!);
  }
  if (availability.description != null &&
      availability.description!.isNotEmpty) {
    writer.writeProperty(_icsPropertyDescription, availability.description!);
  }
  _writeCalendarDateTime(
    writer,
    _icsPropertyDtStart,
    availability.start,
  );
  _writeCalendarDateTime(
    writer,
    _icsPropertyDtEnd,
    availability.end,
  );
  for (final CalendarAvailabilityWindow window in availability.windows) {
    writer.beginComponent(_icsComponentAvailable);
    _writeCalendarDateTime(
      writer,
      _icsPropertyDtStart,
      window.start,
    );
    _writeCalendarDateTime(
      writer,
      _icsPropertyDtEnd,
      window.end,
    );
    if (window.summary != null && window.summary!.isNotEmpty) {
      writer.writeProperty(_icsPropertySummary, window.summary!);
    }
    if (window.description != null && window.description!.isNotEmpty) {
      writer.writeProperty(_icsPropertyDescription, window.description!);
    }
    writer.endComponent(_icsComponentAvailable);
  }
  _writeMetaRawProperties(writer, meta, _availabilityRawPropertySkips);
  _writeMetaRawComponents(writer, meta);
  writer.endComponent(_icsComponentVavailability);
}

void _writeFreeBusyComponent(
  _IcsWriter writer,
  CalendarAvailabilityOverlay overlay,
  String uid,
) {
  writer.beginComponent(_icsComponentVfreebusy);
  writer.writeProperty(_icsPropertyUid, uid, escapeText: false);
  _writeCalendarDateTime(
    writer,
    _icsPropertyDtStart,
    overlay.rangeStart,
  );
  _writeCalendarDateTime(
    writer,
    _icsPropertyDtEnd,
    overlay.rangeEnd,
  );
  final Map<CalendarFreeBusyType, Map<String?, List<CalendarFreeBusyInterval>>>
      grouped =
      <CalendarFreeBusyType, Map<String?, List<CalendarFreeBusyInterval>>>{};
  for (final CalendarFreeBusyInterval interval in overlay.intervals) {
    final String? tzid = _freeBusyGroupTzid(interval);
    grouped
        .putIfAbsent(
          interval.type,
          () => <String?, List<CalendarFreeBusyInterval>>{},
        )
        .putIfAbsent(tzid, () => <CalendarFreeBusyInterval>[])
        .add(interval);
  }
  for (final MapEntry<CalendarFreeBusyType,
      Map<String?, List<CalendarFreeBusyInterval>>> entry in grouped.entries) {
    final CalendarFreeBusyType type = entry.key;
    final Map<String?, List<CalendarFreeBusyInterval>> intervalsByTzid =
        entry.value;
    for (final MapEntry<String?, List<CalendarFreeBusyInterval>> tzidEntry
        in intervalsByTzid.entries) {
      final String? tzid = tzidEntry.key;
      final List<CalendarFreeBusyInterval> intervals = tzidEntry.value;
      final List<String> ranges = intervals
          .map(
            (interval) => '${_formatCalendarDateTime(
              _normalizeFreeBusyDateTime(interval.start, tzid),
            )}/${_formatCalendarDateTime(
              _normalizeFreeBusyDateTime(interval.end, tzid),
            )}',
          )
          .toList(growable: false);
      final List<CalendarPropertyParameter> parameters =
          <CalendarPropertyParameter>[
        CalendarPropertyParameter(
          name: _icsParamFbType,
          values: <String>[type.icsValue],
        ),
        if (tzid != null && tzid.isNotEmpty)
          CalendarPropertyParameter(
            name: _icsParamTzid,
            values: <String>[tzid],
          ),
      ];
      writer.writeProperty(
        _icsPropertyFreeBusy,
        ranges.join(_icsValueComma),
        parameters: parameters,
        escapeText: false,
      );
    }
  }
  writer.endComponent(_icsComponentVfreebusy);
}

String? _freeBusyGroupTzid(CalendarFreeBusyInterval interval) {
  final CalendarDateTime start = interval.start;
  final CalendarDateTime end = interval.end;
  final String? tzid = start.tzid ?? end.tzid;
  if (tzid == null || tzid.isEmpty) {
    return null;
  }
  if (start.tzid != tzid || end.tzid != tzid) {
    return null;
  }
  if (start.isFloating || end.isFloating || start.isAllDay || end.isAllDay) {
    return null;
  }
  return tzid;
}

CalendarDateTime _normalizeFreeBusyDateTime(
  CalendarDateTime value,
  String? tzid,
) {
  if (tzid == null || tzid.isEmpty) {
    return value.copyWith(tzid: null);
  }
  return value;
}

void _writeMeta(
  _IcsWriter writer,
  DateTime modifiedAt,
  CalendarIcsMeta? meta, {
  CalendarPrivacyClass? defaultPrivacyClass,
  CalendarTransparency? defaultTransparency,
}) {
  final DateTime dtStamp = meta?.dtStamp ?? meta?.lastModified ?? modifiedAt;
  writer.writeProperty(
    _icsPropertyDtStamp,
    _formatDateTime(dtStamp, isUtc: true),
    escapeText: false,
  );
  if (meta?.created != null) {
    writer.writeProperty(
      _icsPropertyCreated,
      _formatDateTime(meta!.created!, isUtc: true),
      escapeText: false,
    );
  }
  if (meta?.lastModified != null) {
    writer.writeProperty(
      _icsPropertyLastModified,
      _formatDateTime(meta!.lastModified!, isUtc: true),
      escapeText: false,
    );
  }
  if (meta?.sequence != null) {
    writer.writeProperty(
      _icsPropertySequence,
      meta!.sequence!.toString(),
      escapeText: false,
    );
  }
  final CalendarPrivacyClass? privacyClass =
      meta?.privacyClass ?? defaultPrivacyClass;
  if (privacyClass != null) {
    writer.writeProperty(
      _icsPropertyClass,
      privacyClass.icsValue,
      escapeText: false,
    );
  }
  final CalendarTransparency? transparency =
      meta?.transparency ?? defaultTransparency;
  if (transparency != null) {
    writer.writeProperty(
      _icsPropertyTransp,
      transparency.icsValue,
      escapeText: false,
    );
  }
  if (meta?.categories.isNotEmpty == true) {
    final String categoriesValue =
        meta!.categories.map(_escapeText).join(_icsValueComma);
    writer.writeProperty(
      _icsPropertyCategories,
      categoriesValue,
      escapeText: false,
    );
  }
  if (meta?.url != null) {
    writer.writeProperty(_icsPropertyUrl, meta!.url!, escapeText: false);
  }
  if (meta?.geo != null) {
    writer.writeProperty(
      _icsPropertyGeo,
      '${meta!.geo!.latitude}$_icsValueSemicolon${meta.geo!.longitude}',
      escapeText: false,
    );
  }
  if (meta?.attachments.isNotEmpty == true) {
    for (final CalendarAttachment attachment in meta!.attachments) {
      writer.writeProperty(
        _icsPropertyAttach,
        attachment.value,
        parameters: _attachmentParameters(attachment),
        escapeText: false,
      );
    }
  }
}

void _writeMetaFieldsOnly(_IcsWriter writer, CalendarIcsMeta? meta) {
  if (meta == null) {
    return;
  }
  if (meta.dtStamp != null) {
    writer.writeProperty(
      _icsPropertyDtStamp,
      _formatDateTime(meta.dtStamp!, isUtc: true),
      escapeText: false,
    );
  }
  if (meta.created != null) {
    writer.writeProperty(
      _icsPropertyCreated,
      _formatDateTime(meta.created!, isUtc: true),
      escapeText: false,
    );
  }
  if (meta.lastModified != null) {
    writer.writeProperty(
      _icsPropertyLastModified,
      _formatDateTime(meta.lastModified!, isUtc: true),
      escapeText: false,
    );
  }
  if (meta.sequence != null) {
    writer.writeProperty(
      _icsPropertySequence,
      meta.sequence!.toString(),
      escapeText: false,
    );
  }
}

List<CalendarPropertyParameter> _attachmentParameters(
  CalendarAttachment attachment,
) {
  final List<CalendarPropertyParameter> parameters =
      <CalendarPropertyParameter>[];
  if (attachment.formatType != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamFmtType,
        values: <String>[attachment.formatType!],
      ),
    );
  }
  if (attachment.encoding != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamEncoding,
        values: <String>[attachment.encoding!],
      ),
    );
  }
  if (attachment.label != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamLabel,
        values: <String>[attachment.label!],
      ),
    );
  }
  return parameters;
}

void _writeParticipants(_IcsWriter writer, CalendarIcsMeta? meta) {
  final CalendarOrganizer? organizer = meta?.organizer;
  if (organizer != null) {
    writer.writeProperty(
      _icsPropertyOrganizer,
      _formatAddress(organizer.address),
      parameters: _participantParameters(
        commonName: organizer.commonName,
        directory: organizer.directory,
        sentBy: organizer.sentBy,
        role: organizer.role,
        status: organizer.status,
        type: organizer.type,
        rsvp: organizer.rsvp,
        delegatedTo: organizer.delegatedTo,
        delegatedFrom: organizer.delegatedFrom,
        members: organizer.members,
      ),
      escapeText: false,
    );
  }
  if (meta?.attendees.isNotEmpty == true) {
    for (final CalendarAttendee attendee in meta!.attendees) {
      writer.writeProperty(
        _icsPropertyAttendee,
        _formatAddress(attendee.address),
        parameters: _participantParameters(
          commonName: attendee.commonName,
          directory: attendee.directory,
          sentBy: attendee.sentBy,
          role: attendee.role,
          status: attendee.status,
          type: attendee.type,
          rsvp: attendee.rsvp,
          delegatedTo: attendee.delegatedTo,
          delegatedFrom: attendee.delegatedFrom,
          members: attendee.members,
        ),
        escapeText: false,
      );
    }
  }
}

String _formatAddress(String address) {
  if (address.contains(':')) {
    return address;
  }
  return '$_icsMailtoPrefix$address';
}

List<CalendarPropertyParameter> _participantParameters({
  String? commonName,
  String? directory,
  String? sentBy,
  CalendarParticipantRole? role,
  CalendarParticipantStatus? status,
  CalendarParticipantType? type,
  bool? rsvp,
  List<String>? delegatedTo,
  List<String>? delegatedFrom,
  List<String>? members,
}) {
  final List<CalendarPropertyParameter> parameters =
      <CalendarPropertyParameter>[];
  if (commonName != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamCn,
        values: <String>[commonName],
      ),
    );
  }
  if (directory != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamDir,
        values: <String>[directory],
      ),
    );
  }
  if (sentBy != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamSentBy,
        values: <String>[sentBy],
      ),
    );
  }
  if (role != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamRole,
        values: <String>[role.icsValue],
      ),
    );
  }
  if (status != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamPartStat,
        values: <String>[status.icsValue],
      ),
    );
  }
  if (type != null) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamCutype,
        values: <String>[type.icsValue],
      ),
    );
  }
  if (rsvp == true) {
    parameters.add(
      const CalendarPropertyParameter(
        name: _icsParamRsvp,
        values: <String>[_icsValueTrue],
      ),
    );
  }
  if (delegatedTo != null && delegatedTo.isNotEmpty) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamDelegatedTo,
        values: delegatedTo,
      ),
    );
  }
  if (delegatedFrom != null && delegatedFrom.isNotEmpty) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamDelegatedFrom,
        values: delegatedFrom,
      ),
    );
  }
  if (members != null && members.isNotEmpty) {
    parameters.add(
      CalendarPropertyParameter(
        name: _icsParamMember,
        values: members,
      ),
    );
  }
  return parameters;
}

void _writeMetaRawProperties(
  _IcsWriter writer,
  CalendarIcsMeta? meta,
  Set<String> skip,
) {
  if (meta == null) {
    return;
  }
  for (final CalendarRawProperty property in meta.rawProperties) {
    if (!skip.contains(property.name)) {
      writer.writeRawProperty(property);
    }
  }
}

void _writeRawProperties(
  _IcsWriter writer,
  List<CalendarRawProperty> properties,
  Set<String> skip,
) {
  for (final CalendarRawProperty property in properties) {
    if (!skip.contains(property.name)) {
      writer.writeRawProperty(property);
    }
  }
}

void _writeMetaRawComponents(
  _IcsWriter writer,
  CalendarIcsMeta? meta,
) {
  if (meta == null) {
    return;
  }
  for (final CalendarRawComponent component in meta.rawComponents) {
    writer.writeRawComponent(component);
  }
}

void _writeRawComponents(
  _IcsWriter writer,
  List<CalendarRawComponent> components,
) {
  for (final CalendarRawComponent component in components) {
    writer.writeRawComponent(component);
  }
}

CalendarRawProperty? _rawProperty(CalendarIcsMeta? meta, String name) {
  if (meta == null) {
    return null;
  }
  for (final CalendarRawProperty property in meta.rawProperties) {
    if (property.name == name) {
      return property;
    }
  }
  return null;
}

void _writeDateTimeProperty(
  _IcsWriter writer,
  String name,
  DateTime value, {
  required CalendarRawProperty? rawProperty,
  required bool isAllDay,
  String? tzidOverride,
  bool? isFloatingOverride,
  RecurrenceRange? rangeOverride,
}) {
  final List<CalendarPropertyParameter> parameters =
      rawProperty?.parameters ?? const <CalendarPropertyParameter>[];
  final List<CalendarPropertyParameter> merged = _mergeDateTimeParameters(
    parameters,
    isAllDay: isAllDay,
    tzidOverride: tzidOverride,
    isFloatingOverride: isFloatingOverride,
    rangeOverride: rangeOverride,
  );
  final bool isUtc = tzidOverride == null &&
      (isFloatingOverride == null || isFloatingOverride == false) &&
      value.isUtc;
  final String formatted =
      isAllDay ? _formatDate(value) : _formatDateTime(value, isUtc: isUtc);
  writer.writeProperty(
    name,
    formatted,
    parameters: merged,
    escapeText: false,
  );
}

void _writeCalendarDateTime(
  _IcsWriter writer,
  String name,
  CalendarDateTime value,
) {
  final List<CalendarPropertyParameter> parameters = _mergeDateTimeParameters(
    const <CalendarPropertyParameter>[],
    isAllDay: value.isAllDay,
    tzidOverride: value.tzid,
    isFloatingOverride: value.isFloating,
    rangeOverride: null,
  );
  final String formatted = _formatCalendarDateTime(value);
  writer.writeProperty(
    name,
    formatted,
    parameters: parameters,
    escapeText: false,
  );
}

String _formatCalendarDateTime(CalendarDateTime value) {
  if (value.isAllDay) {
    return _formatDate(value.value);
  }
  final bool isUtc =
      value.tzid == null && !value.isFloating && value.value.isUtc;
  return _formatDateTime(value.value, isUtc: isUtc);
}

List<CalendarPropertyParameter> _mergeDateTimeParameters(
  List<CalendarPropertyParameter> base, {
  required bool isAllDay,
  String? tzidOverride,
  bool? isFloatingOverride,
  RecurrenceRange? rangeOverride,
}) {
  final List<CalendarPropertyParameter> merged =
      base.map((param) => param).toList();
  if (isAllDay) {
    merged.removeWhere((param) => param.name == _icsParamValue);
    merged.add(
      const CalendarPropertyParameter(
        name: _icsParamValue,
        values: <String>[_icsParamValueDate],
      ),
    );
  } else {
    merged.removeWhere((param) => param.name == _icsParamValue);
  }
  if (tzidOverride != null && tzidOverride.isNotEmpty) {
    merged.removeWhere((param) => param.name == _icsParamTzid);
    merged.add(
      CalendarPropertyParameter(
        name: _icsParamTzid,
        values: <String>[tzidOverride],
      ),
    );
  } else if (isFloatingOverride == true) {
    merged.removeWhere((param) => param.name == _icsParamTzid);
  }
  if (rangeOverride != null) {
    merged.add(
      CalendarPropertyParameter(
        name: _icsParamRange,
        values: <String>[rangeOverride.icsValue],
      ),
    );
  }
  return merged;
}

String _encodeChecklist(List<TaskChecklistItem> items) {
  if (items.isEmpty) {
    return '';
  }
  final List<Map<String, dynamic>> payload = <Map<String, dynamic>>[];
  for (var i = 0; i < items.length; i++) {
    final TaskChecklistItem item = items[i];
    payload.add({
      _icsChecklistIdKey: item.id,
      _icsChecklistLabelKey: item.label,
      _icsChecklistCompleteKey: item.isCompleted,
      _icsChecklistOrderKey: i,
    });
  }
  return jsonEncode(payload);
}

int _percentComplete(List<TaskChecklistItem> items) {
  if (items.isEmpty) {
    return 0;
  }
  final int total = items.length;
  final int completed = items.where((item) => item.isCompleted).length;
  return ((completed / total) * _percentScale).floor();
}

String _formatRrule(RecurrenceRule rule) {
  final Map<String, String> parts = <String, String>{};
  parts['FREQ'] = _frequencyValue(rule);
  if (rule.interval != 1) {
    parts['INTERVAL'] = rule.interval.toString();
  }
  if (rule.count != null) {
    parts['COUNT'] = rule.count.toString();
  }
  if (rule.until != null) {
    final DateTime until = rule.until!;
    parts['UNTIL'] = rule.untilIsDate
        ? _formatDate(until)
        : _formatDateTime(until, isUtc: until.isUtc);
  }
  final String? byDay = _formatByDay(rule);
  if (byDay != null && byDay.isNotEmpty) {
    parts['BYDAY'] = byDay;
  }
  _appendNumericPart(parts, 'BYSECOND', rule.bySeconds);
  _appendNumericPart(parts, 'BYMINUTE', rule.byMinutes);
  _appendNumericPart(parts, 'BYHOUR', rule.byHours);
  _appendNumericPart(parts, 'BYMONTHDAY', rule.byMonthDays);
  _appendNumericPart(parts, 'BYYEARDAY', rule.byYearDays);
  _appendNumericPart(parts, 'BYWEEKNO', rule.byWeekNumbers);
  _appendNumericPart(parts, 'BYMONTH', rule.byMonths);
  _appendNumericPart(parts, 'BYSETPOS', rule.bySetPositions);
  if (rule.weekStart != null) {
    parts['WKST'] = rule.weekStart!.icsValue;
  }
  return parts.entries
      .map((entry) => '${entry.key}=${entry.value}')
      .join(_icsValueSemicolon);
}

String _frequencyValue(RecurrenceRule rule) {
  switch (rule.frequency) {
    case RecurrenceFrequency.daily:
      return 'DAILY';
    case RecurrenceFrequency.weekdays:
      return 'DAILY';
    case RecurrenceFrequency.weekly:
      return 'WEEKLY';
    case RecurrenceFrequency.monthly:
      return 'MONTHLY';
    case RecurrenceFrequency.none:
      return 'DAILY';
  }
}

String? _formatByDay(RecurrenceRule rule) {
  if (rule.byDays != null && rule.byDays!.isNotEmpty) {
    return rule.byDays!
        .map((day) => '${day.position ?? ''}${day.weekday.icsValue}')
        .join(_icsValueComma);
  }
  if (rule.byWeekdays != null && rule.byWeekdays!.isNotEmpty) {
    return rule.byWeekdays!
        .map((weekday) => CalendarWeekday.fromIsoValue(weekday).icsValue)
        .join(_icsValueComma);
  }
  if (rule.frequency == RecurrenceFrequency.weekdays) {
    return <String>[
      CalendarWeekday.monday.icsValue,
      CalendarWeekday.tuesday.icsValue,
      CalendarWeekday.wednesday.icsValue,
      CalendarWeekday.thursday.icsValue,
      CalendarWeekday.friday.icsValue,
    ].join(_icsValueComma);
  }
  return null;
}

void _appendNumericPart(
  Map<String, String> parts,
  String key,
  List<int>? values,
) {
  if (values == null || values.isEmpty) {
    return;
  }
  parts[key] = values.join(_icsValueComma);
}

class _DateListKey {
  const _DateListKey({
    required this.isAllDay,
    required this.isFloating,
    required this.tzid,
    required this.isUtc,
  });

  final bool isAllDay;
  final bool isFloating;
  final String? tzid;
  final bool isUtc;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _DateListKey &&
        other.isAllDay == isAllDay &&
        other.isFloating == isFloating &&
        other.tzid == tzid &&
        other.isUtc == isUtc;
  }

  @override
  int get hashCode => Object.hash(isAllDay, isFloating, tzid, isUtc);
}

void _writeDateList(
  _IcsWriter writer,
  String name,
  List<CalendarDateTime> dates,
) {
  if (dates.isEmpty) {
    return;
  }
  final Map<_DateListKey, List<CalendarDateTime>> grouped =
      <_DateListKey, List<CalendarDateTime>>{};
  for (final CalendarDateTime date in dates) {
    final bool isUtc =
        date.tzid == null && !date.isFloating && date.value.isUtc;
    final _DateListKey key = _DateListKey(
      isAllDay: date.isAllDay,
      isFloating: date.isFloating,
      tzid: date.tzid,
      isUtc: isUtc,
    );
    grouped.putIfAbsent(key, () => <CalendarDateTime>[]).add(date);
  }
  for (final MapEntry<_DateListKey, List<CalendarDateTime>> entry
      in grouped.entries) {
    final _DateListKey key = entry.key;
    final List<CalendarDateTime> values = entry.value;
    final List<CalendarPropertyParameter> parameters = _mergeDateTimeParameters(
      const <CalendarPropertyParameter>[],
      isAllDay: key.isAllDay,
      tzidOverride: key.tzid,
      isFloatingOverride: key.isFloating,
      rangeOverride: null,
    );
    final String joined =
        values.map(_formatCalendarDateTime).join(_icsValueComma);
    writer.writeProperty(
      name,
      joined,
      parameters: parameters,
      escapeText: false,
    );
  }
}

List<CalendarDateTime> _mergeExDates(
  List<CalendarDateTime> base,
  Map<String, TaskOccurrenceOverride> overrides,
  CalendarTask task,
) {
  final List<CalendarDateTime> merged = <CalendarDateTime>[...base];
  for (final MapEntry<String, TaskOccurrenceOverride> entry
      in overrides.entries) {
    final TaskOccurrenceOverride override = entry.value;
    if (override.isCancelled != true) {
      continue;
    }
    final CalendarDateTime? recurrenceId =
        override.recurrenceId ?? _recurrenceIdFromOverrideKey(entry.key, task);
    if (recurrenceId == null) {
      continue;
    }
    if (!_containsDateTime(merged, recurrenceId)) {
      merged.add(recurrenceId);
    }
  }
  return merged;
}

const bool _recurrenceIdDefaultAllDay = false;
const bool _recurrenceIdDefaultUtc = false;

CalendarDateTime? _recurrenceIdTemplate(CalendarTask task) {
  final CalendarIcsMeta? meta = task.icsMeta;
  if (meta == null) {
    return null;
  }
  final CalendarRawProperty? rawStart = _rawProperty(meta, _icsPropertyDtStart);
  if (rawStart == null) {
    return null;
  }
  return _parseDateTime(rawStart);
}

CalendarDateTime? _recurrenceIdFromOverrideKey(
  String key,
  CalendarTask task,
) {
  final int? micros = int.tryParse(key);
  if (micros == null) {
    return null;
  }
  final CalendarDateTime? template = _recurrenceIdTemplate(task);
  final bool isUtc = template?.value.isUtc ??
      task.scheduledTime?.isUtc ??
      _recurrenceIdDefaultUtc;
  final DateTime value = DateTime.fromMicrosecondsSinceEpoch(
    micros,
    isUtc: isUtc,
  );
  final bool isAllDay = template?.isAllDay ?? _recurrenceIdDefaultAllDay;
  final String? tzid = template?.tzid;
  final bool isFloating = template?.isFloating ?? (!isUtc && tzid == null);
  return CalendarDateTime(
    value: value,
    tzid: tzid,
    isAllDay: isAllDay,
    isFloating: isFloating,
  );
}

bool _containsDateTime(List<CalendarDateTime> list, CalendarDateTime value) {
  for (final CalendarDateTime item in list) {
    if (item.value == value.value &&
        item.tzid == value.tzid &&
        item.isAllDay == value.isAllDay &&
        item.isFloating == value.isFloating) {
      return true;
    }
  }
  return false;
}

List<CalendarAlarm> _mergeAlarms(
  List<CalendarAlarm> alarms,
  ReminderPreferences? reminders,
) {
  final List<CalendarAlarm> merged = <CalendarAlarm>[
    ...alarms,
  ];
  final List<CalendarAlarm> reminderAlarms = _alarmsFromReminders(reminders);
  for (final CalendarAlarm alarm in reminderAlarms) {
    if (!merged.contains(alarm)) {
      merged.add(alarm);
    }
  }
  return merged;
}

List<CalendarAlarm> _alarmsFromReminders(
  ReminderPreferences? reminders,
) {
  final ReminderPreferences resolved =
      (reminders ?? ReminderPreferences.defaults()).normalized();
  if (!resolved.isEnabled) {
    return const <CalendarAlarm>[];
  }
  final List<CalendarAlarm> alarms = <CalendarAlarm>[];
  for (final Duration offset in resolved.startOffsets) {
    alarms.add(_buildRelativeAlarm(offset, CalendarAlarmRelativeTo.start));
  }
  for (final Duration offset in resolved.deadlineOffsets) {
    alarms.add(_buildRelativeAlarm(offset, CalendarAlarmRelativeTo.end));
  }
  return alarms;
}

CalendarAlarm _buildRelativeAlarm(
  Duration offset,
  CalendarAlarmRelativeTo anchor,
) {
  return CalendarAlarm(
    action: CalendarAlarmAction.display,
    trigger: CalendarAlarmTrigger(
      type: CalendarAlarmTriggerType.relative,
      absolute: null,
      offset: offset,
      relativeTo: anchor,
      offsetDirection: CalendarAlarmOffsetDirection.before,
    ),
    repeat: null,
    duration: null,
    description: null,
    summary: null,
    attachments: const <CalendarAttachment>[],
    acknowledged: null,
    recipients: const <CalendarAlarmRecipient>[],
  );
}

void _writeAlarm(_IcsWriter writer, CalendarAlarm alarm) {
  writer.beginComponent(_icsComponentValarm);
  writer.writeProperty(
    _icsPropertyAction,
    alarm.action.icsValue,
    escapeText: false,
  );
  _writeAlarmTrigger(writer, alarm.trigger);
  if (alarm.repeat != null) {
    writer.writeProperty(
      _icsPropertyRepeat,
      alarm.repeat!.toString(),
      escapeText: false,
    );
  }
  if (alarm.duration != null) {
    writer.writeProperty(
      _icsPropertyDuration,
      _formatDuration(alarm.duration!),
      escapeText: false,
    );
  }
  if (alarm.description != null) {
    writer.writeProperty(_icsPropertyDescription, alarm.description!);
  }
  if (alarm.summary != null) {
    writer.writeProperty(_icsPropertySummary, alarm.summary!);
  }
  if (alarm.attachments.isNotEmpty) {
    for (final CalendarAttachment attachment in alarm.attachments) {
      writer.writeProperty(
        _icsPropertyAttach,
        attachment.value,
        parameters: _attachmentParameters(attachment),
        escapeText: false,
      );
    }
  }
  if (alarm.acknowledged != null) {
    writer.writeProperty(
      _icsPropertyAck,
      _formatDateTime(alarm.acknowledged!, isUtc: true),
      escapeText: false,
    );
  }
  if (alarm.recipients.isNotEmpty) {
    for (final CalendarAlarmRecipient recipient in alarm.recipients) {
      final List<CalendarPropertyParameter> parameters =
          recipient.commonName == null
              ? const <CalendarPropertyParameter>[]
              : <CalendarPropertyParameter>[
                  CalendarPropertyParameter(
                    name: _icsParamCn,
                    values: <String>[recipient.commonName!],
                  ),
                ];
      writer.writeProperty(
        _icsPropertyAttendee,
        _formatAddress(recipient.address),
        parameters: parameters,
        escapeText: false,
      );
    }
  }
  writer.endComponent(_icsComponentValarm);
}

void _writeAlarmTrigger(_IcsWriter writer, CalendarAlarmTrigger trigger) {
  if (trigger.type == CalendarAlarmTriggerType.absolute &&
      trigger.absolute != null) {
    _writeCalendarDateTime(writer, _icsPropertyTrigger, trigger.absolute!);
    return;
  }
  if (trigger.offset == null) {
    return;
  }
  final Duration baseOffset = trigger.offset!;
  final Duration resolvedOffset =
      trigger.offsetDirection == CalendarAlarmOffsetDirection.before
          ? Duration(microseconds: baseOffset.inMicroseconds * -1)
          : baseOffset;
  final String durationValue = _formatDuration(resolvedOffset);
  final CalendarAlarmRelativeTo relativeTo =
      trigger.relativeTo ?? CalendarAlarmRelativeTo.start;
  writer.writeProperty(
    _icsPropertyTrigger,
    durationValue,
    parameters: <CalendarPropertyParameter>[
      CalendarPropertyParameter(
        name: _icsParamRelated,
        values: <String>[
          relativeTo == CalendarAlarmRelativeTo.end
              ? _icsValueEnd
              : _icsValueStart,
        ],
      ),
    ],
    escapeText: false,
  );
}

extension _CalendarPropertyParameterLookup on List<CalendarPropertyParameter> {
  String? firstValue(String name) {
    for (final CalendarPropertyParameter parameter in this) {
      if (parameter.name == name && parameter.values.isNotEmpty) {
        return parameter.values.first;
      }
    }
    return null;
  }

  List<String> values(String name) {
    for (final CalendarPropertyParameter parameter in this) {
      if (parameter.name == name) {
        return parameter.values;
      }
    }
    return const <String>[];
  }
}

extension _IterableFirstOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T value) predicate) {
    for (final T value in this) {
      if (predicate(value)) {
        return value;
      }
    }
    return null;
  }
}

const Set<String> _taskRawPropertySkips = <String>{
  _icsPropertyUid,
  _icsPropertyDtStamp,
  _icsPropertyCreated,
  _icsPropertyLastModified,
  _icsPropertySequence,
  _icsPropertyStatus,
  _icsPropertyClass,
  _icsPropertyTransp,
  _icsPropertyCategories,
  _icsPropertyUrl,
  _icsPropertyGeo,
  _icsPropertyAttach,
  _icsPropertyOrganizer,
  _icsPropertyAttendee,
  _icsPropertySummary,
  _icsPropertyDescription,
  _icsPropertyLocation,
  _icsPropertyDtStart,
  _icsPropertyDue,
  _icsPropertyDuration,
  _icsPropertyRrule,
  _icsPropertyRdate,
  _icsPropertyExdate,
  _icsPropertyExrule,
  _icsPropertyRecurrenceId,
  _icsPropertyPercentComplete,
  _axiChecklistProperty,
  _axiPriorityProperty,
  _axiPathIdProperty,
  _axiPathOrderProperty,
  _axiTaskIdProperty,
  _axiScheduleEndProperty,
  _axiScheduleDurationProperty,
};

const Set<String> _eventTaskRawPropertySkips = <String>{
  _icsPropertyUid,
  _icsPropertyDtStamp,
  _icsPropertyCreated,
  _icsPropertyLastModified,
  _icsPropertySequence,
  _icsPropertyStatus,
  _icsPropertyClass,
  _icsPropertyTransp,
  _icsPropertyCategories,
  _icsPropertyUrl,
  _icsPropertyGeo,
  _icsPropertyAttach,
  _icsPropertyOrganizer,
  _icsPropertyAttendee,
  _icsPropertySummary,
  _icsPropertyDescription,
  _icsPropertyLocation,
  _icsPropertyDtStart,
  _icsPropertyDtEnd,
  _icsPropertyDuration,
  _icsPropertyRrule,
  _icsPropertyRdate,
  _icsPropertyExdate,
  _icsPropertyExrule,
  _icsPropertyRecurrenceId,
  _axiChecklistProperty,
  _axiPriorityProperty,
  _axiPathIdProperty,
  _axiPathOrderProperty,
  _axiTaskIdProperty,
};

const Set<String> _eventRawPropertySkips = <String>{
  _icsPropertyUid,
  _icsPropertyDtStamp,
  _icsPropertyCreated,
  _icsPropertyLastModified,
  _icsPropertySequence,
  _icsPropertyStatus,
  _icsPropertyClass,
  _icsPropertyTransp,
  _icsPropertyCategories,
  _icsPropertyUrl,
  _icsPropertyGeo,
  _icsPropertyAttach,
  _icsPropertyOrganizer,
  _icsPropertyAttendee,
  _icsPropertySummary,
  _icsPropertyDescription,
  _icsPropertyDtStart,
  _icsPropertyDtEnd,
  _icsPropertyRecurrenceId,
  _axiTaskIdProperty,
};

const Set<String> _journalRawPropertySkips = <String>{
  _icsPropertyUid,
  _icsPropertyDtStamp,
  _icsPropertyCreated,
  _icsPropertyLastModified,
  _icsPropertySequence,
  _icsPropertyStatus,
  _icsPropertyClass,
  _icsPropertyTransp,
  _icsPropertyCategories,
  _icsPropertyUrl,
  _icsPropertyGeo,
  _icsPropertyAttach,
  _icsPropertyOrganizer,
  _icsPropertyAttendee,
  _icsPropertySummary,
  _icsPropertyDescription,
  _icsPropertyDtStart,
  _axiTaskIdProperty,
};

const Set<String> _availabilityRawPropertySkips = <String>{
  _icsPropertyUid,
  _icsPropertyDtStamp,
  _icsPropertyCreated,
  _icsPropertyLastModified,
  _icsPropertySequence,
  _icsPropertySummary,
  _icsPropertyDescription,
  _icsPropertyDtStart,
  _icsPropertyDtEnd,
};
