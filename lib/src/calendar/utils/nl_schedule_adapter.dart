// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:collection';

import 'package:timezone/timezone.dart' as tz;

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'schedule_parser.dart';

const String _rruleFrequencyYearly = 'YEARLY';

/// Context describing the device/environment used when mapping parser output
/// into app models. Keeps track of timezone metadata so downstream layers can
/// persist both UTC instants and the originating zone identifier.
class ParseContext {
  ParseContext({
    required this.location,
    required this.timezoneId,
    DateTime? reference,
    this.localeTag = 'en',
    Map<String, Object?>? metadata,
  })  : reference = (reference ?? DateTime.now()).toUtc(),
        metadata = Map.unmodifiable(metadata ?? const {});

  final tz.Location location;
  final String timezoneId;
  final DateTime reference;
  final String localeTag;
  final Map<String, Object?> metadata;
}

/// Configuration surface for the adapter + parser bridge. Values are
/// intentionally high-level so product can adjust behavior (for example how
/// strict “next Wednesday” should be interpreted) without editing source code.
class NlAdapterConfig {
  const NlAdapterConfig({
    this.defaultDuration = const Duration(hours: 1),
    this.minimumDuration = const Duration(minutes: 15),
    this.allDaySpan = const Duration(hours: 24),
    this.strictNextWeekday = true,
    this.preferDmyDates = false,
    this.endOfDayHour = 17,
    this.eveningHour = 18,
    this.urgentHorizon = const Duration(hours: 24),
    this.confidenceNoteThreshold = 0.92,
    this.policyOverride,
  });

  final Duration defaultDuration;
  final Duration minimumDuration;
  final Duration allDaySpan;
  final bool strictNextWeekday;
  final bool preferDmyDates;
  final int endOfDayHour;
  final int eveningHour;
  final Duration urgentHorizon;
  final double confidenceNoteThreshold;
  final FuzzyPolicy? policyOverride;

  FuzzyPolicy effectivePolicy() {
    if (policyOverride != null) return policyOverride!;
    return FuzzyPolicy(
      endOfDayHour: endOfDayHour,
      defaultEveningHour: eveningHour,
      strictNextWeekday: strictNextWeekday,
      preferDMY: preferDmyDates,
      urgentHorizonHours: urgentHorizon.inHours.clamp(1, 240),
    );
  }

  NlAdapterConfig copyWith({
    Duration? defaultDuration,
    Duration? minimumDuration,
    Duration? allDaySpan,
    bool? strictNextWeekday,
    bool? preferDmyDates,
    int? endOfDayHour,
    int? eveningHour,
    Duration? urgentHorizon,
    double? confidenceNoteThreshold,
    FuzzyPolicy? policyOverride,
  }) {
    return NlAdapterConfig(
      defaultDuration: defaultDuration ?? this.defaultDuration,
      minimumDuration: minimumDuration ?? this.minimumDuration,
      allDaySpan: allDaySpan ?? this.allDaySpan,
      strictNextWeekday: strictNextWeekday ?? this.strictNextWeekday,
      preferDmyDates: preferDmyDates ?? this.preferDmyDates,
      endOfDayHour: endOfDayHour ?? this.endOfDayHour,
      eveningHour: eveningHour ?? this.eveningHour,
      urgentHorizon: urgentHorizon ?? this.urgentHorizon,
      confidenceNoteThreshold:
          confidenceNoteThreshold ?? this.confidenceNoteThreshold,
      policyOverride: policyOverride ?? this.policyOverride,
    );
  }
}

/// Captures the original wall time, timezone name, and UTC instant so storage
/// can persist whichever representation it prefers.
class NlZonedDateTime {
  NlZonedDateTime._(this.utc, this.wallTime, this.timezoneId, this.location);

  factory NlZonedDateTime.fromTz(tz.TZDateTime value) {
    final utc = value.toUtc();
    final wall = DateTime(
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return NlZonedDateTime._(utc, wall, value.location.name, value.location);
  }

  final DateTime utc;
  final DateTime wallTime;
  final String timezoneId;
  final tz.Location location;
}

/// Result bundle returned by the adapter. In addition to the concrete
/// [CalendarTask], it surfaces metadata that UI/storage layers can inspect
/// before committing the task.
class NlAdapterResult {
  NlAdapterResult({
    required this.task,
    required this.bucket,
    required this.parseNotes,
    required this.confidence,
    required Set<AmbiguityFlag> flags,
    required List<String> assumptions,
    required List<String> participants,
    required this.approximate,
    required this.source,
    required this.context,
    this.start,
    this.end,
    this.deadline,
    this.recurrenceUntil,
  })  : participants = UnmodifiableListView(participants),
        assumptions = UnmodifiableListView(assumptions),
        flags = Set.unmodifiable(flags);

  final CalendarTask task;
  final TaskBucket bucket;
  final String? parseNotes;
  final double confidence;
  final Set<AmbiguityFlag> flags;
  final List<String> assumptions;
  final List<String> participants;
  final bool approximate;
  final String source;
  final ParseContext context;
  final NlZonedDateTime? start;
  final NlZonedDateTime? end;
  final NlZonedDateTime? deadline;
  final NlZonedDateTime? recurrenceUntil;
}

/// Adapter that maps [ScheduleItem] output from [ScheduleParser] to the
/// calendar task model used inside the app. This layer is responsible for
/// bucket classification and metadata fan-out rather than mutating core models.
///
/// ### Quick start
/// ```dart
/// import 'package:flutter_native_timezone/flutter_native_timezone.dart';
/// import 'package:timezone/data/latest.dart' as tzdata;
/// import 'package:timezone/timezone.dart' as tz;
///
/// Future<NlAdapterResult> parseInput(String input) async {
///   tzdata.initializeTimeZones();
///   final tzName = await FlutterNativeTimezone.getLocalTimezone();
///   final location = tz.getLocation(tzName);
///   final ctx = ParseContext(
///     location: location,
///     timezoneId: tzName,
///   );
///   final adapter = const NlScheduleAdapter();
///   final parser = adapter.buildParser(ctx);
///   final ScheduleItem parsed = parser.parse(input);
///   return adapter.mapToAppTypes(parsed, ctx: ctx);
/// }
/// ```
class NlScheduleAdapter {
  const NlScheduleAdapter({this.config = const NlAdapterConfig()});

  final NlAdapterConfig config;

  ScheduleParser buildParser(ParseContext ctx) {
    return ScheduleParser(
      ScheduleParseOptions(
        tzLocation: ctx.location,
        tzName: ctx.timezoneId,
        reference: ctx.reference,
        policy: config.effectivePolicy(),
      ),
    );
  }

  NlAdapterResult mapToAppTypes(
    ScheduleItem item, {
    required ParseContext ctx,
  }) {
    final bucket = mapBucket(item);
    final startZoned = _zonedOrNull(item.start);
    final endZoned = _zonedOrNull(item.end);
    final deadlineZoned = _zonedOrNull(item.deadline);
    final recurrenceUntilZoned = _zonedOrNull(item.recurrence?.until);

    final DateTime? scheduledTime = startZoned?.wallTime;
    final DateTime? endDate = endZoned?.wallTime;
    final Duration? duration = _deriveDuration(
      start: scheduledTime,
      end: endDate,
      allDay: item.allDay,
    );

    final CalendarTask task = CalendarTask.create(
      title: _normalizeTitle(item.task),
      scheduledTime: scheduledTime,
      duration: duration,
      location: _clean(item.location),
      deadline: deadlineZoned?.wallTime,
      endDate: endDate,
      priority: mapPriority(item.priority),
      recurrence: mapRecurrence(item.recurrence),
    );

    final resultNotes =
        mergeAssumptions(item.flags, item.assumptions, item.confidence);

    return NlAdapterResult(
      task: task,
      bucket: bucket,
      parseNotes: resultNotes,
      confidence: item.confidence,
      flags: item.flags,
      assumptions: item.assumptions,
      participants: _sanitizeParticipants(item.participants),
      approximate: item.approximate,
      source: item.source,
      context: ctx,
      start: startZoned,
      end: endZoned,
      deadline: deadlineZoned,
      recurrenceUntil: recurrenceUntilZoned,
    );
  }

  RecurrenceRule? mapRecurrence(Recurrence? recurrence) {
    if (recurrence == null) return null;
    final tokens = recurrence.rrule.split(';');
    final Map<String, String> fields = {};
    for (final token in tokens) {
      final idx = token.indexOf('=');
      if (idx <= 0) continue;
      fields[token.substring(0, idx).toUpperCase()] = token.substring(idx + 1);
    }

    RecurrenceFrequency frequency;
    switch (fields['FREQ']) {
      case 'DAILY':
        frequency = RecurrenceFrequency.daily;
      case 'WEEKLY':
        frequency = RecurrenceFrequency.weekly;
      case 'MONTHLY':
        frequency = RecurrenceFrequency.monthly;
      case _rruleFrequencyYearly:
        frequency = RecurrenceFrequency.yearly;
      case 'WEEKDAYS':
        frequency = RecurrenceFrequency.weekdays;
      default:
        return null;
    }

    final interval = int.tryParse(fields['INTERVAL'] ?? '') ?? 1;
    final byDaysRaw = fields['BYDAY'];
    List<int>? byWeekdays;
    if (byDaysRaw != null && byDaysRaw.isNotEmpty) {
      final seen = <int>{};
      byWeekdays = [];
      for (final token in byDaysRaw.split(',')) {
        final day = _weekdayFromIcs(token.trim());
        if (day != null && seen.add(day)) {
          byWeekdays.add(day);
        }
      }
      if (frequency == RecurrenceFrequency.weekly &&
          _isWeekdaysSet(byWeekdays)) {
        frequency = RecurrenceFrequency.weekdays;
      }
    }

    final DateTime? untilLocal = recurrence.until != null
        ? _zonedOrNull(recurrence.until!)?.wallTime
        : _parseIcsDate(fields['UNTIL']);
    final count = recurrence.count ?? int.tryParse(fields['COUNT'] ?? '');

    return RecurrenceRule(
      frequency: frequency,
      interval: interval <= 0 ? 1 : interval,
      byWeekdays: byWeekdays?.isEmpty == true ? null : byWeekdays,
      until: untilLocal,
      count: count,
    );
  }

  TaskPriority mapPriority(PriorityQuadrant quadrant) {
    switch (quadrant) {
      case PriorityQuadrant.importantUrgent:
        return TaskPriority.critical;
      case PriorityQuadrant.importantNotUrgent:
        return TaskPriority.important;
      case PriorityQuadrant.notImportantUrgent:
        return TaskPriority.urgent;
      case PriorityQuadrant.notImportantNotUrgent:
        return TaskPriority.none;
    }
  }

  TaskBucket mapBucket(ScheduleItem item) {
    if (item.start != null) {
      return TaskBucket.scheduled;
    }
    if (item.deadline != null) {
      return TaskBucket.reminder;
    }
    return TaskBucket.unscheduled;
  }

  String? mergeAssumptions(
    Set<AmbiguityFlag> flags,
    List<String> assumptions,
    double confidence,
  ) {
    final lines = <String>[];
    if (flags.isNotEmpty) {
      final friendly = flags.map(_labelForFlag).join(', ');
      lines.add('Flags: $friendly');
    }
    if (assumptions.isNotEmpty) {
      lines.add('Assumptions:');
      for (final assumption in assumptions) {
        lines.add('- $assumption');
      }
    }
    if (lines.isNotEmpty || confidence < config.confidenceNoteThreshold) {
      lines.add('Confidence: ${(confidence * 100).toStringAsFixed(0)}%');
    }
    if (lines.isEmpty) {
      return null;
    }
    return lines.join('\n');
  }

  /// Returns the mapped [CalendarTask]. The app shares a single model for
  /// tasks and events, so this is equivalent to [mapToAppTypes].
  CalendarTask? toTask(
    ScheduleItem item, {
    required ParseContext ctx,
  }) {
    return mapToAppTypes(item, ctx: ctx).task;
  }

  /// Returns a [CalendarTask] only when the parser produced a scheduled bucket,
  /// allowing callers to gate event-specific UI.
  CalendarTask? toEvent(
    ScheduleItem item, {
    required ParseContext ctx,
  }) {
    final result = mapToAppTypes(item, ctx: ctx);
    return result.bucket == TaskBucket.scheduled ? result.task : null;
  }

  Duration? _deriveDuration({
    required DateTime? start,
    required DateTime? end,
    required bool allDay,
  }) {
    if (start != null && end != null) {
      final diff = end.difference(start);
      if (diff >= config.minimumDuration) {
        return diff;
      }
    }
    if (allDay && start != null) {
      return config.allDaySpan;
    }
    if (start != null) {
      return config.defaultDuration;
    }
    return null;
  }

  NlZonedDateTime? _zonedOrNull(tz.TZDateTime? value) {
    if (value == null) return null;
    return NlZonedDateTime.fromTz(value);
  }

  String _normalizeTitle(String raw) {
    final trimmed = raw.trim();
    return trimmed.isEmpty ? 'Untitled' : trimmed;
  }

  String? _clean(String? raw) {
    if (raw == null) return null;
    final trimmed = raw.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  List<String> _sanitizeParticipants(List<String> raw) {
    if (raw.isEmpty) return const [];
    final seen = <String>{};
    final result = <String>[];
    for (final entry in raw) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) continue;
      final key = trimmed.toLowerCase();
      if (seen.add(key)) {
        result.add(trimmed);
      }
    }
    return result;
  }

  DateTime? _parseIcsDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.contains('-')) {
      return DateTime.tryParse(raw)?.toLocal();
    }
    // Expect YYYYMMDD or YYYYMMDDThhmmssZ.
    final buffer = StringBuffer()
      ..write(raw.substring(0, 4))
      ..write('-')
      ..write(raw.substring(4, 6))
      ..write('-')
      ..write(raw.substring(6, 8));

    final tIndex = raw.indexOf('T');
    if (tIndex != -1 && raw.length >= tIndex + 7) {
      final timePortion = raw.substring(tIndex + 1, tIndex + 7);
      buffer
        ..write('T')
        ..write(timePortion.substring(0, 2))
        ..write(':')
        ..write(timePortion.substring(2, 4))
        ..write(':')
        ..write(timePortion.substring(4, 6))
        ..write('Z');
    }
    return DateTime.tryParse(buffer.toString())?.toLocal();
  }

  bool _isWeekdaysSet(List<int>? days) {
    if (days == null || days.length != 5) return false;
    const weekdays = {
      DateTime.monday,
      DateTime.tuesday,
      DateTime.wednesday,
      DateTime.thursday,
      DateTime.friday,
    };
    return weekdays.difference(Set<int>.from(days)).isEmpty;
  }

  int? _weekdayFromIcs(String token) {
    switch (token.toUpperCase()) {
      case 'MO':
        return DateTime.monday;
      case 'TU':
        return DateTime.tuesday;
      case 'WE':
        return DateTime.wednesday;
      case 'TH':
        return DateTime.thursday;
      case 'FR':
        return DateTime.friday;
      case 'SA':
        return DateTime.saturday;
      case 'SU':
        return DateTime.sunday;
    }
    return null;
  }

  String _labelForFlag(AmbiguityFlag flag) {
    switch (flag) {
      case AmbiguityFlag.noDateFound:
        return 'no date';
      case AmbiguityFlag.noTimeGiven:
        return 'no time';
      case AmbiguityFlag.vaguePartOfDay:
        return 'vague part of day';
      case AmbiguityFlag.relativeDate:
        return 'relative date';
      case AmbiguityFlag.nextModifier:
        return '"next" qualifier';
      case AmbiguityFlag.approximateTime:
        return 'approximate time';
      case AmbiguityFlag.eoxShortcut:
        return 'end-of-period shortcut';
      case AmbiguityFlag.numericDateAmbiguous:
        return 'ambiguous numeric date';
      case AmbiguityFlag.rangeParsed:
        return 'time range interpreted';
      case AmbiguityFlag.deadline:
        return 'deadline detected';
      case AmbiguityFlag.typosCorrected:
        return 'spelling normalized';
      case AmbiguityFlag.locationGuessed:
        return 'location guessed';
    }
  }
}
