import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'nl_schedule_adapter.dart';
import 'schedule_parser.dart';
import 'time_formatter.dart';

class TaskShareFormatter {
  const TaskShareFormatter._();

  static String describe(CalendarTask task, {DateTime? now}) {
    final DateTime reference = now ?? DateTime.now();
    final title =
        task.title.trim().isEmpty ? 'Untitled task' : task.title.trim();
    final qualifiers = <String>[];
    final String? priority = _priorityWord(task.effectivePriority);
    if (task.isCompleted) {
      qualifiers.add('done');
    }
    if (priority != null) {
      qualifiers.add(priority);
    }

    final buffer = StringBuffer('Task "$title"');
    if (qualifiers.isNotEmpty) {
      buffer.write(' (${qualifiers.join(', ')})');
    }

    if (task.location?.trim().isNotEmpty == true) {
      buffer.write(' at ${_clean(task.location!)}');
    }

    final String? schedule = _scheduleClause(task, reference);
    if (schedule != null && schedule.isNotEmpty) {
      buffer.write(' $schedule');
    }

    final String? recurrence =
        _recurrenceClause(task.effectiveRecurrence, reference);
    if (recurrence != null && recurrence.isNotEmpty) {
      buffer.write(' $recurrence');
    }

    if (task.deadline != null) {
      buffer.write(', due by ${_formatDateTime(task.deadline!, reference)}');
    }

    buffer.write('.');

    if (task.description?.trim().isNotEmpty == true) {
      buffer.write(' Notes: ${_clean(task.description!)}.');
    }

    final String? overrides = _overridesDescription(task, reference);
    if (overrides != null && overrides.isNotEmpty) {
      buffer.write(' Changes: $overrides');
    }

    return buffer.toString().trim();
  }

  static String? _scheduleClause(CalendarTask task, DateTime reference) {
    final DateTime? start = task.scheduledTime;
    final DateTime? end = task.displayEnd;
    final Duration? span = task.effectiveDuration;

    if (start == null && end == null && !task.hasDeadline) {
      return 'with no set time';
    }

    if (start != null && end != null && !end.isAtSameMomentAs(start)) {
      if (_isSameDay(start, end)) {
        final String dateLabel = _formatDate(start, reference);
        return 'on $dateLabel from ${TimeFormatter.formatTime(start)} to ${TimeFormatter.formatTime(end)}';
      }
      return 'from ${_formatDateTime(start, reference)} to ${_formatDateTime(end, reference)}';
    }

    if (start != null && span != null) {
      return 'on ${_formatDate(start, reference)} at ${TimeFormatter.formatTime(start)} for ${TimeFormatter.formatDuration(span)}';
    }

    if (start != null) {
      return 'on ${_formatDate(start, reference)} at ${TimeFormatter.formatTime(start)}';
    }

    if (end != null) {
      return 'ending ${_formatDateTime(end, reference)}';
    }

    return null;
  }

  static String? _recurrenceClause(
    RecurrenceRule recurrence,
    DateTime reference,
  ) {
    if (recurrence.isNone) {
      return null;
    }

    final List<String> parts = [];
    switch (recurrence.frequency) {
      case RecurrenceFrequency.daily:
        parts.add(
          recurrence.interval == 2
              ? 'every other day'
              : 'every ${recurrence.interval > 1 ? '${recurrence.interval} days' : 'day'}',
        );
        break;
      case RecurrenceFrequency.weekdays:
        parts.add(
          recurrence.interval > 1
              ? 'every ${recurrence.interval} weekdays'
              : 'every weekday',
        );
        break;
      case RecurrenceFrequency.weekly:
        final List<String> weekdayLabels = recurrence.byWeekdays
                ?.map(_weekdayLabel)
                .whereType<String>()
                .toList() ??
            const [];
        final String dayPortion =
            weekdayLabels.isEmpty ? '' : ' on ${_joinWithAnd(weekdayLabels)}';
        final String cadence =
            recurrence.interval > 1 ? '${recurrence.interval} weeks' : 'week';
        parts.add('every $cadence$dayPortion');
        break;
      case RecurrenceFrequency.monthly:
        parts.add(
          recurrence.interval > 1
              ? 'every ${recurrence.interval} months'
              : 'every month',
        );
        break;
      case RecurrenceFrequency.none:
        return null;
    }

    if (recurrence.until != null) {
      parts.add('until ${_formatDate(recurrence.until!, reference)}');
    }

    if (recurrence.count != null) {
      parts.add('for ${recurrence.count} occurrences');
    }

    return parts.join(' ');
  }

  static String? _overridesDescription(
    CalendarTask task,
    DateTime reference,
  ) {
    if (task.occurrenceOverrides.isEmpty) {
      return null;
    }

    final List<MapEntry<String, TaskOccurrenceOverride>> sortedOverrides =
        task.occurrenceOverrides.entries.toList()
          ..sort(
            (a, b) {
              final DateTime? aDate = _dateFromOccurrenceKey(a.key);
              final DateTime? bDate = _dateFromOccurrenceKey(b.key);
              if (aDate != null && bDate != null) {
                return aDate.compareTo(bDate);
              }
              if (aDate != null) return -1;
              if (bDate != null) return 1;
              return a.key.compareTo(b.key);
            },
          );

    final List<String> segments = [];
    for (final MapEntry<String, TaskOccurrenceOverride> entry
        in sortedOverrides) {
      final DateTime? occurrenceStart = _dateFromOccurrenceKey(entry.key);
      if (occurrenceStart == null) {
        continue;
      }
      final TaskOccurrenceOverride override = entry.value;
      final List<String> actions = [];

      if (override.scheduledTime != null) {
        actions.add(
          'move to ${_formatDateTime(override.scheduledTime!, reference)}',
        );
      }
      if (override.duration != null) {
        actions.add('for ${TimeFormatter.formatDuration(override.duration!)}');
      }
      if (override.endDate != null) {
        actions.add(
          'end at ${_formatDateTime(override.endDate!, reference)}',
        );
      }
      if (override.priority != null) {
        final String? label = _priorityWord(override.priority!);
        if (label != null) {
          actions.add('priority $label');
        }
      }
      if (override.isCancelled == true) {
        actions.add('cancelled');
      }
      if (override.isCompleted == true) {
        actions.add('done');
      }
      if (override.title?.trim().isNotEmpty == true) {
        actions.add('rename to "${_clean(override.title!)}"');
      }
      if (override.description?.trim().isNotEmpty == true) {
        actions.add('notes "${_clean(override.description!)}"');
      }
      if (override.location?.trim().isNotEmpty == true) {
        actions.add('location "${_clean(override.location!)}"');
      }

      final String actionsText =
          actions.isEmpty ? 'no changes' : actions.join('; ');
      segments.add(
        'On ${_formatDateTime(occurrenceStart, reference)}: $actionsText',
      );
    }

    if (segments.isEmpty) {
      return null;
    }

    return '${segments.join('. ')}.';
  }

  static String? _priorityWord(TaskPriority priority) {
    switch (priority) {
      case TaskPriority.none:
        return null;
      case TaskPriority.important:
        return 'important';
      case TaskPriority.urgent:
        return 'urgent';
      case TaskPriority.critical:
        return 'critical';
    }
  }

  static String _formatDateTime(DateTime dt, DateTime reference) =>
      '${_formatDate(dt, reference)} at ${TimeFormatter.formatTime(dt)}';

  static String _formatDate(DateTime dt, DateTime reference) =>
      dt.year == reference.year
          ? TimeFormatter.formatShortDate(dt)
          : TimeFormatter.formatFriendlyDate(dt);

  static String _clean(String input) =>
      input.replaceAll(RegExp(r'\s+'), ' ').trim();

  static String? _weekdayLabel(int value) {
    switch (value) {
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
    }
    return null;
  }

  static DateTime? _dateFromOccurrenceKey(String key) {
    final int? micros = int.tryParse(key);
    if (micros == null) {
      return null;
    }
    return DateTime.fromMicrosecondsSinceEpoch(micros, isUtc: true);
  }

  static String _joinWithAnd(List<String> items) {
    if (items.length <= 1) {
      return items.join();
    }
    final String head = items.sublist(0, items.length - 1).join(', ');
    final String tail = items.last;
    return '$head and $tail';
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class TaskShareDecoder {
  const TaskShareDecoder._();

  static NlAdapterResult? tryDecode({
    required String input,
    required NlScheduleAdapter adapter,
    required ParseContext context,
  }) {
    final RegExpMatch? match = _titlePattern.firstMatch(input);
    if (match == null) {
      return null;
    }

    final String extractedTitle = match.group(1)?.trim() ?? 'Untitled task';
    final _ShareSections sections = _splitSections(input);

    final ScheduleParser parser = adapter.buildParser(context);
    final ScheduleItem parsed = parser.parse(sections.baseText);
    final NlAdapterResult base = adapter.mapToAppTypes(parsed, ctx: context);

    CalendarTask task = base.task.copyWith(title: extractedTitle);
    if (_looksDone(sections.baseText)) {
      task = task.copyWith(isCompleted: true);
    }

    if (sections.notes != null && sections.notes!.isNotEmpty) {
      task = task.copyWith(description: sections.notes);
    }

    final _ShareSchedule? schedule =
        _ShareSchedule.tryParse(sections.baseText, context);
    final DateTime? scheduledTime = schedule?.start ?? task.scheduledTime;
    final DateTime? endDate = schedule?.end ?? task.endDate;
    final DateTime? deadline =
        _extractDeadline(sections.baseText, context) ?? task.deadline;
    final String? location =
        _extractLocation(sections.baseText) ?? task.location;
    final Duration? duration = schedule?.duration ??
        task.duration ??
        (scheduledTime != null && endDate != null
            ? endDate.difference(scheduledTime)
            : null);

    task = task.copyWith(
      scheduledTime: scheduledTime,
      endDate: endDate,
      duration: duration,
      deadline: deadline,
      location: location,
    );

    final Map<String, TaskOccurrenceOverride> overrides =
        _parseOverrides(sections.changes, context);
    if (overrides.isNotEmpty &&
        (sections.changes?.toLowerCase().contains('cancel') ?? false)) {
      overrides.updateAll(
        (String key, TaskOccurrenceOverride value) =>
            value.copyWith(isCancelled: true),
      );
    }
    if (overrides.isNotEmpty) {
      task = task.copyWith(occurrenceOverrides: overrides);
    }

    final RecurrenceRule? recurrence =
        _extractRecurrence(sections.baseText, context) ?? task.recurrence;
    if (recurrence != null) {
      task = task.copyWith(recurrence: recurrence);
    }

    final NlZonedDateTime? startZoned = scheduledTime != null
        ? _toZonedDateTime(scheduledTime, context)
        : base.start;
    final NlZonedDateTime? endZoned =
        endDate != null ? _toZonedDateTime(endDate, context) : base.end;
    final NlZonedDateTime? deadlineZoned =
        deadline != null ? _toZonedDateTime(deadline, context) : base.deadline;
    final TaskBucket bucket =
        (scheduledTime != null || !task.effectiveRecurrence.isNone)
            ? TaskBucket.scheduled
            : (task.deadline != null
                ? TaskBucket.reminder
                : TaskBucket.unscheduled);

    return NlAdapterResult(
      task: task,
      bucket: bucket,
      parseNotes: base.parseNotes,
      confidence: base.confidence,
      flags: base.flags,
      assumptions: base.assumptions,
      participants: base.participants,
      approximate: base.approximate,
      source: input,
      context: context,
      start: startZoned ?? base.start,
      end: endZoned ?? base.end,
      deadline: deadlineZoned ?? base.deadline,
      recurrenceUntil: base.recurrenceUntil,
    );
  }

  static final RegExp _titlePattern =
      RegExp(r'Task\s+"([^"]+)"', caseSensitive: false);

  static bool _looksDone(String text) => RegExp(
        r'\b(done|completed|finished)\b',
        caseSensitive: false,
      ).hasMatch(text);

  static _ShareSections _splitSections(String input) {
    final String lower = input.toLowerCase();
    final int notesIndex = lower.indexOf('notes:');
    final int changesIndex = lower.indexOf('changes:');

    final int firstMarker = [
      notesIndex == -1 ? null : notesIndex,
      changesIndex == -1 ? null : changesIndex,
    ].whereType<int>().fold(input.length, (value, element) {
      return element < value ? element : value;
    });

    final String baseText = input.substring(0, firstMarker).trim();

    String? notes;
    if (notesIndex != -1) {
      final int start = notesIndex + 'notes:'.length;
      final int end = changesIndex != -1 && changesIndex > notesIndex
          ? changesIndex
          : input.length;
      notes =
          input.substring(start, end).trim().replaceAll(RegExp(r'\s+'), ' ');
      notes = _trimTrailingPunctuation(notes);
    }

    String? changes;
    if (changesIndex != -1) {
      final int start = changesIndex + 'changes:'.length;
      changes = _trimTrailingPunctuation(
        input.substring(start).trim(),
      );
    }

    return _ShareSections(
      baseText: baseText.isEmpty ? input.trim() : baseText,
      notes: notes,
      changes: changes,
    );
  }

  static Map<String, TaskOccurrenceOverride> _parseOverrides(
    String? raw,
    ParseContext context,
  ) {
    if (raw == null || raw.trim().isEmpty) {
      return const {};
    }

    final bool containsCancelWord = raw.toLowerCase().contains('cancel') ||
        raw.toLowerCase().contains('cancelled');
    final overrides = <String, TaskOccurrenceOverride>{};
    final RegExp segmentPattern = RegExp(
      r'\bOn\s+[^:]+:.*?(?=(?:\bOn\s+[^:]+:)|$)',
      caseSensitive: false,
      dotAll: true,
    );
    final Iterable<RegExpMatch> matches = segmentPattern.allMatches(raw);
    final List<String> segments =
        matches.map((m) => m.group(0)).whereType<String>().toList();
    if (segments.isEmpty) {
      final String? fallback = _trimTrailingPunctuation(raw.trim());
      if (fallback != null) {
        segments.add(fallback);
      }
    }

    for (final String segment in segments) {
      final String? cleaned = _trimTrailingPunctuation(segment.trim());
      if (cleaned == null || cleaned.isEmpty) continue;
      final String lower = cleaned.toLowerCase();
      if (!lower.startsWith('on ')) continue;
      final int colonIndex = cleaned.indexOf(': ');
      if (colonIndex == -1) continue;

      final String occurrenceText = cleaned.substring(3, colonIndex).trim();
      final DateTime? occurrenceStart = _parseDateTime(occurrenceText, context);
      if (occurrenceStart == null) {
        continue;
      }

      final String actionsText = cleaned.substring(colonIndex + 1).trim();
      final String actionsTextLower = actionsText.toLowerCase();
      final Iterable<String> actions = actionsText
          .split(RegExp(r';\s*'))
          .where((action) => action.trim().isNotEmpty);

      DateTime? moveTo;
      Duration? duration;
      DateTime? endDate;
      TaskPriority? priority;
      bool? cancelled;
      bool? done;
      String? rename;
      String? notes;
      String? location;

      for (final String action in actions) {
        final String lowerAction = action.toLowerCase().trim();
        if (lowerAction.startsWith('move to')) {
          final String value = action
              .substring(action.toLowerCase().indexOf('move to') + 7)
              .trim();
          moveTo = _parseDateTime(value, context);
          continue;
        }
        if (lowerAction.startsWith('for ')) {
          duration ??= _parseDuration(action);
          continue;
        }
        if (lowerAction.startsWith('end at')) {
          final String value = action
              .substring(action.toLowerCase().indexOf('end at') + 6)
              .trim();
          endDate = _parseDateTime(value, context);
          continue;
        }
        if (lowerAction.contains('cancel')) {
          cancelled = true;
          continue;
        }
        if (lowerAction.contains('done') || lowerAction.contains('complete')) {
          done = true;
          continue;
        }
        if (lowerAction.contains('priority')) {
          priority ??= _priorityFromAction(lowerAction);
          continue;
        }
        if (lowerAction.startsWith('rename to')) {
          rename ??= _extractValue(action, 'rename to');
          continue;
        }
        if (lowerAction.startsWith('notes')) {
          notes ??= _extractValue(action, 'notes');
          continue;
        }
        if (lowerAction.startsWith('location')) {
          location ??= _extractValue(action, 'location');
          continue;
        }
      }

      final TaskOccurrenceOverride payload = TaskOccurrenceOverride(
        scheduledTime: moveTo,
        duration: duration,
        endDate: endDate,
        isCancelled: cancelled == true ||
            actionsTextLower.contains('cancel') ||
            containsCancelWord,
        priority: priority,
        isCompleted: done,
        title: rename,
        description: notes,
        location: location,
      );
      final String utcKey =
          occurrenceStart.toUtc().microsecondsSinceEpoch.toString();
      overrides[utcKey] = payload;
      final String localKey =
          occurrenceStart.toLocal().microsecondsSinceEpoch.toString();
      if (localKey != utcKey) {
        overrides.putIfAbsent(localKey, () => payload);
      }
    }

    return overrides;
  }

  static DateTime? _parseDateTime(String input, ParseContext context) {
    final RegExp window = RegExp(
      r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+\d{1,2}(?:,\s*\d{4})?(?:\s+(?:at\s+|from\s+)?\d{1,2}:\d{2}\s*[AaPp][Mm])?',
      caseSensitive: false,
    );
    final RegExpMatch? windowMatch = window.firstMatch(input);
    if (windowMatch == null) {
      return null;
    }
    final String snippet = windowMatch.group(0)!;
    String cleaned =
        snippet.replaceAll('·', ' ').replaceAll(RegExp(r','), '').trim();
    cleaned = cleaned
        .replaceAll(RegExp(r'\bfrom\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\bat\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final bool hasTime = cleaned.contains(RegExp(r'\d:\d'));
    final bool hasYear = cleaned.contains(RegExp(r'\b\d{4}\b'));
    final String withYear =
        hasYear ? cleaned : '$cleaned ${context.reference.year}';
    try {
      if (hasTime) {
        final DateFormat fmt = DateFormat('MMM d h:mm a yyyy');
        return fmt.parseUtc(withYear);
      }
      final DateFormat fmt = DateFormat('MMM d yyyy');
      return fmt.parseUtc(withYear);
    } catch (_) {
      return null;
    }
  }

  static _ShareSchedule? _shareScheduleFromRange(
    RegExpMatch match,
    ParseContext context,
  ) {
    final String date = match.group(1)?.trim() ?? '';
    final String startText = match.group(2)?.trim() ?? '';
    final String endText = match.group(3)?.trim() ?? '';
    final DateTime? start = _parseDateTime('$date $startText', context);
    final DateTime? end = _parseDateTime('$date $endText', context);
    if (start == null) return null;
    final Duration? span =
        end != null && end.isAfter(start) ? end.difference(start) : null;
    return _ShareSchedule(
      start: start,
      end: end,
      duration: span,
    );
  }

  static NlZonedDateTime _toZonedDateTime(
    DateTime value,
    ParseContext context,
  ) {
    final tz.TZDateTime zoned = tz.TZDateTime(
      context.location,
      value.year,
      value.month,
      value.day,
      value.hour,
      value.minute,
      value.second,
      value.millisecond,
      value.microsecond,
    );
    return NlZonedDateTime.fromTz(zoned);
  }

  static Duration? _parseDuration(String action) {
    final String lower = action.toLowerCase();
    final RegExpMatch? hourMatch =
        RegExp(r'(\d+)\s*(hour|hours|hr|hrs|h)\b').firstMatch(lower);
    final RegExpMatch? minuteMatch =
        RegExp(r'(\d+)\s*(minute|minutes|min|mins|m)\b').firstMatch(lower);

    int minutes = 0;
    if (hourMatch != null) {
      minutes += int.tryParse(hourMatch.group(1) ?? '') != null
          ? int.parse(hourMatch.group(1)!) * 60
          : 0;
    }
    if (minuteMatch != null) {
      minutes += int.tryParse(minuteMatch.group(1) ?? '') ?? 0;
    }

    if (minutes <= 0) {
      return null;
    }
    return Duration(minutes: minutes);
  }

  static TaskPriority? _priorityFromAction(String action) {
    if (action.contains('critical')) {
      return TaskPriority.critical;
    }
    if (action.contains('urgent')) {
      return TaskPriority.urgent;
    }
    if (action.contains('important')) {
      return TaskPriority.important;
    }
    return null;
  }

  static String? _extractValue(String action, String keyword) {
    final int keywordIndex = action.toLowerCase().indexOf(keyword);
    if (keywordIndex == -1) {
      return null;
    }
    final String trailing =
        action.substring(keywordIndex + keyword.length).trim();
    final Match? quoted = RegExp(r'"([^"]+)"').firstMatch(trailing);
    if (quoted != null) {
      return quoted.group(1)?.trim();
    }
    return trailing.isEmpty ? null : trailing.trim();
  }

  static String? _trimTrailingPunctuation(String? value) {
    if (value == null) {
      return null;
    }
    final String cleaned = value.replaceAll(RegExp(r'[.;\s]+$'), '').trim();
    if (cleaned.isEmpty) {
      return null;
    }
    return cleaned;
  }

  static DateTime? _extractDeadline(
    String baseText,
    ParseContext context,
  ) {
    final RegExpMatch? match = RegExp(
      r'due by\s+([^.]+)',
      caseSensitive: false,
    ).firstMatch(baseText);
    if (match == null) return null;
    final String? raw = match.group(1);
    if (raw == null || raw.trim().isEmpty) return null;
    return _parseDateTime(raw.trim(), context);
  }

  static RecurrenceRule? _extractRecurrence(
    String baseText,
    ParseContext context,
  ) {
    final String lower = baseText.toLowerCase();
    int interval = 1;
    RecurrenceFrequency frequency = RecurrenceFrequency.none;
    List<int>? weekdays;

    if (lower.contains('every weekday')) {
      frequency = RecurrenceFrequency.weekdays;
      final RegExpMatch? intervalMatch =
          RegExp(r'every\s+(\d+)\s+weekdays').firstMatch(lower);
      if (intervalMatch != null) {
        interval = int.tryParse(intervalMatch.group(1) ?? '') ?? 1;
      }
    } else if (lower.contains('every other day')) {
      frequency = RecurrenceFrequency.daily;
      interval = 2;
    } else if (lower.contains('every day')) {
      frequency = RecurrenceFrequency.daily;
      final RegExpMatch? intervalMatch =
          RegExp(r'every\s+(\d+)\s+days').firstMatch(lower);
      if (intervalMatch != null) {
        interval = int.tryParse(intervalMatch.group(1) ?? '') ?? 1;
      }
    } else if (lower.contains('every week')) {
      frequency = RecurrenceFrequency.weekly;
      final RegExpMatch? intervalMatch =
          RegExp(r'every\s+(\d+)\s+weeks').firstMatch(lower);
      if (intervalMatch != null) {
        interval = int.tryParse(intervalMatch.group(1) ?? '') ?? 1;
      }
      final RegExpMatch? daysMatch = RegExp(
        r'on\s+([a-z\s,]+?)(?:\s+until\b|\s+for\b|,|\.|$)',
        caseSensitive: false,
      ).firstMatch(baseText);
      if (daysMatch != null) {
        final String raw = daysMatch.group(1)?.toLowerCase() ?? '';
        final Iterable<String> tokens = raw
            .replaceAll('and', ',')
            .split(',')
            .map((token) => token.trim())
            .where((token) => token.isNotEmpty);
        final Map<String, int> weekdayMap = <String, int>{
          'monday': DateTime.monday,
          'tuesday': DateTime.tuesday,
          'wednesday': DateTime.wednesday,
          'thursday': DateTime.thursday,
          'friday': DateTime.friday,
          'saturday': DateTime.saturday,
          'sunday': DateTime.sunday,
        };
        final List<int> parsedDays = <int>[];
        for (final String token in tokens) {
          final int? mapped = weekdayMap[token];
          if (mapped != null) {
            parsedDays.add(mapped);
          }
        }
        if (parsedDays.isNotEmpty) {
          weekdays = parsedDays;
        }
      }
    } else if (lower.contains('every month')) {
      frequency = RecurrenceFrequency.monthly;
      final RegExpMatch? intervalMatch =
          RegExp(r'every\s+(\d+)\s+months').firstMatch(lower);
      if (intervalMatch != null) {
        interval = int.tryParse(intervalMatch.group(1) ?? '') ?? 1;
      }
    } else {
      return null;
    }

    final RegExpMatch? countMatch =
        RegExp(r'for\s+(\d+)\s+occurrences', caseSensitive: false)
            .firstMatch(baseText);
    final int? count =
        countMatch != null ? int.tryParse(countMatch.group(1) ?? '') : null;

    final RegExpMatch? untilMatch = RegExp(
      r'until\s+([^\.,]+?)(?:\s+for\b|,|\.|$)',
      caseSensitive: false,
    ).firstMatch(baseText);
    final DateTime? untilRaw = untilMatch != null
        ? _parseDateTime(untilMatch.group(1)!.trim(), context)
        : null;
    final DateTime? until = untilRaw == null
        ? null
        : DateTime.utc(untilRaw.year, untilRaw.month, untilRaw.day);

    return RecurrenceRule(
      frequency: frequency,
      interval: interval,
      byWeekdays: weekdays,
      until: until,
      count: count,
    );
  }

  static String? _extractLocation(String baseText) {
    final RegExpMatch? match = RegExp(
      r'\bat\s+(.+?)(?:\s+on\b|,|\.)',
      caseSensitive: false,
    ).firstMatch(baseText);
    if (match == null) return null;
    final String? raw = match.group(1);
    if (raw == null) return null;
    final String cleaned = raw.trim();
    return cleaned.isEmpty ? null : cleaned;
  }
}

class _ShareSchedule {
  const _ShareSchedule({this.start, this.end, this.duration});

  static final RegExp _sameDayRangePattern = RegExp(
    r'\bon\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+from\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])\s+to\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])',
    caseSensitive: false,
  );

  static final RegExp _crossDayRangePattern = RegExp(
    r'\bfrom\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+at\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])\s+to\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+at\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])',
    caseSensitive: false,
  );

  static final RegExp _startWithDurationPattern = RegExp(
    r'\bon\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+at\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])\s+for\s+([^,.;]+)',
    caseSensitive: false,
  );

  static final RegExp _startOnlyPattern = RegExp(
    r'\bon\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+at\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])',
    caseSensitive: false,
  );

  static final RegExp _endOnlyPattern = RegExp(
    r'\bending\s+([A-Za-z]{3}\s+\d{1,2}(?:,\s*\d{4})?)\s+at\s+(\d{1,2}:\d{2}\s*[AaPp][Mm])',
    caseSensitive: false,
  );

  static _ShareSchedule? tryParse(String text, ParseContext context) {
    final RegExpMatch? sameDayRange = _sameDayRangePattern.firstMatch(text);
    if (sameDayRange != null) {
      return TaskShareDecoder._shareScheduleFromRange(
        sameDayRange,
        context,
      );
    }

    final RegExpMatch? crossDayRange = _crossDayRangePattern.firstMatch(text);
    if (crossDayRange != null) {
      final String startDate = crossDayRange.group(1)?.trim() ?? '';
      final String startTime = crossDayRange.group(2)?.trim() ?? '';
      final String endDate = crossDayRange.group(3)?.trim() ?? '';
      final String endTime = crossDayRange.group(4)?.trim() ?? '';

      final DateTime? start =
          TaskShareDecoder._parseDateTime('$startDate $startTime', context);
      final DateTime? end =
          TaskShareDecoder._parseDateTime('$endDate $endTime', context);
      if (start != null) {
        final Duration? span =
            end != null && end.isAfter(start) ? end.difference(start) : null;
        return _ShareSchedule(
          start: start,
          end: end,
          duration: span,
        );
      }
    }

    final RegExpMatch? startWithDuration =
        _startWithDurationPattern.firstMatch(text);
    if (startWithDuration != null) {
      final String date = startWithDuration.group(1)?.trim() ?? '';
      final String time = startWithDuration.group(2)?.trim() ?? '';
      final DateTime? start =
          TaskShareDecoder._parseDateTime('$date $time', context);
      final Duration? duration = TaskShareDecoder._parseDuration(
        startWithDuration.group(3)?.trim() ?? '',
      );
      if (start != null) {
        return _ShareSchedule(
          start: start,
          end: duration != null ? start.add(duration) : null,
          duration: duration,
        );
      }
    }

    final RegExpMatch? startOnly = _startOnlyPattern.firstMatch(text);
    if (startOnly != null) {
      final String date = startOnly.group(1)?.trim() ?? '';
      final String time = startOnly.group(2)?.trim() ?? '';
      final DateTime? start =
          TaskShareDecoder._parseDateTime('$date $time', context);
      if (start != null) {
        return _ShareSchedule(start: start);
      }
    }

    final RegExpMatch? endOnly = _endOnlyPattern.firstMatch(text);
    if (endOnly != null) {
      final String date = endOnly.group(1)?.trim() ?? '';
      final String time = endOnly.group(2)?.trim() ?? '';
      final DateTime? end =
          TaskShareDecoder._parseDateTime('$date $time', context);
      if (end != null) {
        return _ShareSchedule(end: end);
      }
    }

    return null;
  }

  final DateTime? start;
  final DateTime? end;
  final Duration? duration;
}

class _ShareSections {
  const _ShareSections({
    required this.baseText,
    this.notes,
    this.changes,
  });

  final String baseText;
  final String? notes;
  final String? changes;
}

extension CalendarTaskShareX on CalendarTask {
  String toShareText({DateTime? now}) =>
      TaskShareFormatter.describe(this, now: now);
}
