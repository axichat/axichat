import 'package:chrono_dart/chrono_dart.dart';
import 'package:timezone/timezone.dart' as tz;

import '../models/calendar_task.dart';
import 'nl_schedule_adapter.dart';
import 'schedule_parser.dart';
import 'time_formatter.dart';

class TaskShareFormatter {
  const TaskShareFormatter._();

  static String describe(CalendarTask task) {
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

    final String? schedule = _scheduleClause(task);
    if (schedule != null && schedule.isNotEmpty) {
      buffer.write(' $schedule');
    }

    final String? recurrence = _recurrenceClause(task.effectiveRecurrence);
    if (recurrence != null && recurrence.isNotEmpty) {
      buffer.write(' $recurrence');
    }

    if (task.deadline != null) {
      buffer.write(', due by ${_formatDateTime(task.deadline!)}');
    }

    buffer.write('.');

    if (task.description?.trim().isNotEmpty == true) {
      buffer.write(' Notes: ${_clean(task.description!)}.');
    }

    final String? overrides = _overridesDescription(task);
    if (overrides != null && overrides.isNotEmpty) {
      buffer.write(' Changes: $overrides');
    }

    return buffer.toString().trim();
  }

  static String? _scheduleClause(CalendarTask task) {
    final DateTime? start = task.scheduledTime;
    final DateTime? end = task.displayEnd;
    final Duration? span = task.effectiveDuration;

    if (start == null && end == null && !task.hasDeadline) {
      return 'with no set time';
    }

    if (start != null && end != null && !end.isAtSameMomentAs(start)) {
      return 'from ${_formatDateTime(start)} to ${_formatDateTime(end)}';
    }

    if (start != null && span != null) {
      return 'at ${_formatDateTime(start)} for ${TimeFormatter.formatDuration(span)}';
    }

    if (start != null) {
      return 'at ${_formatDateTime(start)}';
    }

    if (end != null) {
      return 'ending ${_formatDateTime(end)}';
    }

    return null;
  }

  static String? _recurrenceClause(RecurrenceRule recurrence) {
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
      parts.add('until ${_formatDate(recurrence.until!)}');
    }

    if (recurrence.count != null) {
      parts.add('for ${recurrence.count} occurrences');
    }

    return parts.join(' ');
  }

  static String? _overridesDescription(CalendarTask task) {
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
        actions.add('move to ${_formatDateTime(override.scheduledTime!)}');
      }
      if (override.duration != null) {
        actions.add('for ${TimeFormatter.formatDuration(override.duration!)}');
      }
      if (override.endDate != null) {
        actions.add('end at ${_formatDateTime(override.endDate!)}');
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
      segments.add('On ${_formatDateTime(occurrenceStart)}: $actionsText');
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

  static String _formatDateTime(DateTime dt) =>
      '${_formatDate(dt)} at ${TimeFormatter.formatTime(dt)}';

  static String _formatDate(DateTime dt) =>
      TimeFormatter.formatFriendlyDate(dt);

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
    return DateTime.fromMicrosecondsSinceEpoch(micros);
  }

  static String _joinWithAnd(List<String> items) {
    if (items.length <= 1) {
      return items.join();
    }
    final String head = items.sublist(0, items.length - 1).join(', ');
    final String tail = items.last;
    return '$head and $tail';
  }
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

    final Map<String, TaskOccurrenceOverride> overrides =
        _parseOverrides(sections.changes, context);
    if (overrides.isNotEmpty) {
      task = task.copyWith(occurrenceOverrides: overrides);
    }

    return NlAdapterResult(
      task: task,
      bucket: base.bucket,
      parseNotes: base.parseNotes,
      confidence: base.confidence,
      flags: base.flags,
      assumptions: base.assumptions,
      participants: base.participants,
      approximate: base.approximate,
      source: input,
      context: context,
      start: base.start,
      end: base.end,
      deadline: base.deadline,
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
      final int colonIndex = cleaned.indexOf(':');
      if (colonIndex == -1) continue;

      final String occurrenceText = cleaned.substring(3, colonIndex).trim();
      final DateTime? occurrenceStart = _parseDateTime(occurrenceText, context);
      if (occurrenceStart == null) {
        continue;
      }

      final String actionsText = cleaned.substring(colonIndex + 1).trim();
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

      overrides[occurrenceStart.microsecondsSinceEpoch.toString()] =
          TaskOccurrenceOverride(
        scheduledTime: moveTo,
        duration: duration,
        endDate: endDate,
        isCancelled: cancelled,
        priority: priority,
        isCompleted: done,
        title: rename,
        description: notes,
        location: location,
      );
    }

    return overrides;
  }

  static DateTime? _parseDateTime(String input, ParseContext context) {
    final ParsingReference ref = ParsingReference(
      instant: context.reference,
      timezone: context.timezoneId,
    );
    final List<ParsedResult> results = Chrono.parse(' $input ',
        ref: ref, option: ParsingOption(forwardDate: true));
    if (results.isEmpty) {
      return null;
    }
    final tz.TZDateTime zoned =
        tz.TZDateTime.from(results.last.date(), context.location);
    return DateTime(
      zoned.year,
      zoned.month,
      zoned.day,
      zoned.hour,
      zoned.minute,
      zoned.second,
      zoned.millisecond,
      zoned.microsecond,
    );
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
  String toShareText() => TaskShareFormatter.describe(this);
}
