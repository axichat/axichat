// schedule_parser.dart
import 'package:chrono_dart/chrono_dart.dart'
    show Chrono, ParsingOption, ParsingReference, Component, ParsedResult;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

const String _timeSnippetPattern =
    r'(?:\d{1,2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?|am|pm)?'
    r'|\d{1,2}\s*h\d{0,2}|noon|midnight)';

const String _weekdayWordPattern =
    r'mon(?:day|days)?|tue(?:s|sday|sdays)?|wed(?:nesday|nesdays)?|'
    r'thu(?:r|rs|rsday|rsdays)?|fri(?:day|days)?|sat(?:urday|urdays)?|'
    r'sun(?:day|days)?';

const String _streetSuffixGroup =
    '(?:st|street|ave|avenue|rd|road|dr|drive|blvd|boulevard|ln|lane|way|'
    'pkwy|parkway|hwy|highway|trl|trail|ct|court|sq|square|pl|place|plz|plaza|'
    'terrace|ter)';
const String _locationConnectorWordsPattern =
    '(?:with|on|for|by|at|in|to|via|and)';

final RegExp _streetSuffixPattern = RegExp(
  '\\b$_streetSuffixGroup\\b',
  caseSensitive: false,
);

final RegExp _addressLeadingNumberPattern =
    RegExp(r'^\d{1,6}(?:[-/]\d{1,4})?\b');

final RegExp _addressTailPattern = RegExp(
  '\\s*,\\s*(?!$_locationConnectorWordsPattern\\b)([A-Za-z0-9.\\- ]{2,})',
  caseSensitive: false,
);

final RegExp _locationConnectorMatcher = RegExp(
  '\\b$_locationConnectorWordsPattern\\b',
  caseSensitive: false,
);

const Set<String> _metadataConnectorWords = {
  'on',
  'at',
  'in',
  'this',
  'next',
  'coming',
  'around',
  'about',
};

class _AddressTailCapture {
  const _AddressTailCapture({required this.appendedText, required this.newEnd});

  final String appendedText;
  final int newEnd;
}

_AddressTailCapture? _captureAddressTail(String source, int startIndex) {
  var index = startIndex;
  final buffer = StringBuffer();
  while (index < source.length) {
    final match = _addressTailPattern.matchAsPrefix(source, index);
    if (match == null) {
      break;
    }
    final fullMatch = match.group(0);
    if (fullMatch == null || fullMatch.trim().isEmpty) {
      break;
    }
    buffer.write(fullMatch);
    index = match.end;
  }
  if (buffer.isEmpty) {
    return null;
  }
  return _AddressTailCapture(
    appendedText: buffer.toString(),
    newEnd: index,
  );
}

bool _looksLikeExactPostalAddress(String candidate) {
  final normalized = candidate.trim();
  if (normalized.isEmpty) return false;

  final numberMatch = _addressLeadingNumberPattern.matchAsPrefix(normalized);
  if (numberMatch == null) return false;

  final remainder = normalized.substring(numberMatch.end).trimLeft();
  if (remainder.isEmpty) return false;

  final firstComma = remainder.indexOf(',');
  final streetSegment =
      firstComma == -1 ? remainder : remainder.substring(0, firstComma);

  RegExpMatch? suffixMatch;
  for (final match in _streetSuffixPattern.allMatches(streetSegment)) {
    suffixMatch = match;
  }
  if (suffixMatch == null) {
    return false;
  }

  final beforeSuffix = streetSegment.substring(0, suffixMatch.start);
  if (!RegExp(r'[A-Za-z]').hasMatch(beforeSuffix)) {
    return false;
  }

  final afterSuffix = remainder.substring(suffixMatch.end);
  if (afterSuffix.isNotEmpty &&
      !RegExp(r'^[,A-Za-z0-9.\- ]+$').hasMatch(afterSuffix)) {
    return false;
  }

  if (_locationConnectorMatcher.hasMatch(afterSuffix)) {
    return false;
  }

  return true;
}

/// ---------------------------------------------------------------------------
/// Public enums & models
/// ---------------------------------------------------------------------------

enum AmbiguityFlag {
  noDateFound,
  noTimeGiven,
  vaguePartOfDay,
  relativeDate,
  nextModifier,
  approximateTime,
  eoxShortcut,
  numericDateAmbiguous,
  rangeParsed,
  deadline,
  typosCorrected,
  locationGuessed,
}

enum PriorityQuadrant {
  notImportantNotUrgent, // Q4
  notImportantUrgent, // Q3
  importantNotUrgent, // Q2
  importantUrgent, // Q1
}

enum TaskBucket { unscheduled, reminder, scheduled }

/// Minimal iCalendar RRULE wrapper so you can store/sync recurrence.
/// Example: FREQ=WEEKLY;BYDAY=FR;INTERVAL=2;UNTIL=20251231T235959Z
class Recurrence {
  final String rrule;
  final String text;
  final tz.TZDateTime? until;
  final int? count;
  const Recurrence(
      {required this.rrule, required this.text, this.until, this.count});
}

class ScheduleItem {
  final String task;
  final tz.TZDateTime? start;
  final tz.TZDateTime? end;
  final bool allDay;
  final String? location;
  final List<String> participants;
  final String source;

  // Fuzzy/explanatory bits
  final double confidence;
  final Set<AmbiguityFlag> flags;
  final List<String> assumptions;
  final bool approximate;

  // Priority & recurrence
  final PriorityQuadrant priority;
  final Recurrence? recurrence;

  // Separate deadline (distinct from start/end)
  final tz.TZDateTime? deadline;

  const ScheduleItem({
    required this.task,
    required this.start,
    required this.end,
    required this.allDay,
    required this.location,
    required this.participants,
    required this.source,
    required this.confidence,
    required this.flags,
    required this.assumptions,
    required this.approximate,
    required this.priority,
    required this.recurrence,
    required this.deadline,
  });

  TaskBucket get bucket {
    if (start != null || recurrence != null) return TaskBucket.scheduled;
    if (deadline != null) return TaskBucket.reminder;
    return TaskBucket.unscheduled;
  }

  @override
  String toString() {
    String dt(tz.TZDateTime? d) => d == null ? "null" : d.toIso8601String();
    return [
      "task: $task",
      "start: ${dt(start)}",
      "end:   ${dt(end)}",
      "deadline: ${dt(deadline)}",
      "allDay: $allDay",
      "location: ${location ?? 'null'}",
      "participants: $participants",
      "priority: ${priority.toString().split('.').last}",
      "recurrence: ${recurrence?.rrule ?? 'none'}",
      "bucket: ${bucket.toString().split('.').last}",
      "confidence: ${confidence.toStringAsFixed(2)}",
      "flags: ${flags.map((f) => f.toString().split('.').last).toList()}",
      "assumptions: $assumptions",
      'source: "$source"',
    ].join("\n");
  }
}

/// Parser configuration knobs.
class FuzzyPolicy {
  final int defaultMorningHour;
  final int defaultAfternoonHour;
  final int defaultEveningHour;
  final int defaultNightHour;
  final int endOfDayHour;
  final bool strictNextWeekday;
  final bool preferFuture;
  final bool preferDMY;
  final bool allowAtSignLocation;
  final Duration approxTolerance;
  final int weekendDefaultDay; // DateTime.saturday or DateTime.sunday
  final int lunchHour;
  final int afterWorkHour;

  // Priority heuristics
  final int urgentHorizonHours;
  final List<String> importantWords;
  final List<String> urgentWords;
  final List<String> notImportantWords;
  final List<String> notUrgentWords;

  const FuzzyPolicy({
    this.defaultMorningHour = 9,
    this.defaultAfternoonHour = 15,
    this.defaultEveningHour = 19,
    this.defaultNightHour = 21,
    this.endOfDayHour = 17,
    this.strictNextWeekday = true,
    this.preferFuture = true,
    this.preferDMY = false,
    this.allowAtSignLocation = true,
    this.approxTolerance = const Duration(minutes: 15),
    this.weekendDefaultDay = DateTime.saturday,
    this.lunchHour = 12,
    this.afterWorkHour = 18,
    this.urgentHorizonHours = 24,
    this.importantWords = const [
      'important',
      'critical',
      'must',
      'p0',
      'p1',
      'high priority',
      'key',
      'blocker'
    ],
    this.urgentWords = const [
      'urgent',
      'asap',
      'now',
      'immediately',
      'right away',
      'stat',
      '!!!'
    ],
    this.notImportantWords = const [
      'optional',
      'nice to have',
      'someday',
      'maybe'
    ],
    this.notUrgentWords = const [
      'no rush',
      'not urgent',
      'whenever',
      'when you can',
      'later'
    ],
  });
}

const int _maxWordsBetweenToLeadInAndLocation = 2;

final RegExp _toLocationLeadInPattern = RegExp(
  r'\b(?:go|going|head|heading|drive|driving|travel|traveling|walk|walking|'
  r'commute|commuting|fly|flying|ride|riding|return|returning|arrive|arriving|'
  r'trip|flight|visit|visiting|tour|touring|meet|meeting|journey|vacation|'
  r'holiday|retreat|move|moving)\b',
  caseSensitive: false,
);

bool _looksLikeToLocationPhrase(String source, int prepositionStart) {
  if (prepositionStart <= 0 || prepositionStart > source.length) {
    return false;
  }
  final prefix = source.substring(0, prepositionStart).trimRight();
  if (prefix.isEmpty) return false;

  Match? lastMatch;
  for (final match in _toLocationLeadInPattern.allMatches(prefix)) {
    lastMatch = match;
  }
  if (lastMatch == null) {
    return false;
  }

  final trailingSegment = prefix.substring(lastMatch.end).trim();
  if (trailingSegment.isEmpty) {
    return true;
  }

  final words = trailingSegment
      .split(RegExp(r'\s+'))
      .where((word) => word.trim().isNotEmpty)
      .toList();

  return words.length <= _maxWordsBetweenToLeadInAndLocation;
}

class ScheduleParseOptions {
  final tz.Location tzLocation; // tz.getLocation('America/Los_Angeles')
  final String tzName; // 'America/Los_Angeles'
  final DateTime? reference; // anchor
  final FuzzyPolicy policy;
  const ScheduleParseOptions({
    required this.tzLocation,
    required this.tzName,
    required this.policy,
    this.reference,
  });
}

/// ---------------------------------------------------------------------------
/// Parser
/// ---------------------------------------------------------------------------
class ScheduleParser {
  final ScheduleParseOptions opts;
  ScheduleParser(this.opts);

  ScheduleItem parse(String input) {
    assert(input.trim().isNotEmpty);
    final original = input.trim();

    // Reference instant
    final base = opts.reference != null
        ? tz.TZDateTime.from(opts.reference!, opts.tzLocation)
        : tz.TZDateTime.now(opts.tzLocation);

    // Normalize sloppy input
    final normal = _normalize(original, base);
    final rawRelativeLabel = normal.relativeFallbackLabel;
    final String? relativeLabel = rawRelativeLabel == null
        ? null
        : rawRelativeLabel.trim().isEmpty
            ? null
            : rawRelativeLabel.trim();
    var s = ' ${normal.text} '; // working text buffer
    final flags = <AmbiguityFlag>{...normal.flags};
    final assumptions = <String>[...normal.assumptions];
    var confidence = 1.0;
    final _ConsumedPhraseTracker consumed = _ConsumedPhraseTracker();

    // DEADLINE: extract and strip from sentence
    final _DeadlineParse dl = _extractDeadline(s, base);
    s = ' ${dl.cleaned} ';
    tz.TZDateTime? deadline = dl.deadline;
    flags.addAll(dl.flags);
    assumptions.addAll(dl.assumptions);

    // RECURRENCE: strip triggers but keep anchor words like "Friday 10"
    final _RecurrenceParse rec = _parseRecurrence(s, base);
    s = ' ${rec.cleaned} ';
    Recurrence? recurrence = rec.recurrence;
    if (recurrence != null) {
      assumptions.add('Recurrence: ${recurrence.rrule}');
    }

    // Date/time via chrono
    final ref = ParsingReference(instant: base.toUtc(), timezone: opts.tzName);
    final option = ParsingOption(forwardDate: opts.policy.preferFuture);
    final results = Chrono.parse(s, ref: ref, option: option);

    ParsedResult? best;
    if (results.isNotEmpty) {
      final withTime =
          results.where((r) => r.start.isCertain(Component.hour)).toList();
      best = withTime.isNotEmpty ? withTime.last : results.last;
    }

    tz.TZDateTime? start;
    bool allDay = false;

    if (best != null) {
      final parsed = best.date(); // UTC
      var local = tz.TZDateTime.from(parsed, opts.tzLocation);
      final hasTime = best.start.isCertain(Component.hour);
      allDay = !hasTime;

      // Strict "next <weekday>"
      if (opts.policy.strictNextWeekday &&
          RegExp(r'\bnext\s+(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b',
                  caseSensitive: false)
              .hasMatch(s)) {
        final baseDay =
            tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day);
        final diff = local.difference(baseDay).inDays;
        if (diff > 0 && diff <= 7) {
          local = local.add(const Duration(days: 7));
          flags.add(AmbiguityFlag.nextModifier);
          assumptions.add('Interpreted "next <weekday>" as next week.');
        }
      }

      start = local;
      final matchIndex = best.index.toInt();
      s = _removeSpanByIndex(
        s,
        matchIndex,
        best.text.length,
      );
      consumed.add(best.text);
    } else {
      // Use relative fallback from normalization ("in N days/hours")
      if (normal.relativeFallback != null) {
        start = normal.relativeFallback;
        allDay = false;
        flags.add(AmbiguityFlag.relativeDate);
        assumptions.add(
            'Interpreted relative duration "${normal.relativeFallbackLabel}".');
        if (relativeLabel != null && relativeLabel.isNotEmpty) {
          final pattern =
              RegExp(RegExp.escape(relativeLabel), caseSensitive: false);
          s = s.replaceFirst(pattern, ' ');
          consumed.add(relativeLabel);
        }
      }
    }

    if (start == null) {
      final fallback = _manualTimeFallback(original, s, base);
      if (fallback != null) {
        start = fallback.start;
        allDay = fallback.allDay;
        s = fallback.cleanedText;
        flags.addAll(fallback.flags);
        assumptions.addAll(fallback.assumptions);
        confidence -= 0.15;
      }
    }

    if (recurrence != null && start != null) {
      final _RecurrenceSpec? snapSpec =
          _RecurrenceMath.tryParse(recurrence, start.location);
      if (snapSpec != null) {
        final tz.TZDateTime aligned =
            _RecurrenceMath.alignStart(start, snapSpec);
        if (!aligned.isAtSameMomentAs(start)) {
          start = aligned;
          assumptions.add('Aligned start to recurrence cadence.');
        }
      }
    }

    // Vague parts of day
    final vague = _resolveVaguePartOfDay(original);
    if (vague != null) {
      flags.add(AmbiguityFlag.vaguePartOfDay);
      if (start != null && !vague.overrideDateOnly) {
        start = tz.TZDateTime(
            opts.tzLocation, start.year, start.month, start.day, vague.hour);
        allDay = false;
        assumptions.add('Mapped "${vague.hit}" to ${_hhmm(vague.hour)}.');
      } else if (start == null) {
        final day = base;
        start = tz.TZDateTime(
            opts.tzLocation, day.year, day.month, day.day, vague.hour);
        allDay = false;
        assumptions.add(
            'No explicit date; used ${DateFormat('y-MM-dd').format(start)} for "${vague.hit}".');
      }
      confidence -= 0.1;
      final vaguePattern =
          RegExp(RegExp.escape(vague.hit), caseSensitive: false);
      if (vaguePattern.hasMatch(s)) {
        s = s.replaceFirst(vaguePattern, ' ');
      }
      consumed.add(vague.hit);
    }

    // Weekend shorthand
    final weekendPattern =
        RegExp(r'\b(?:(this|next)\s+)?weekend\b', caseSensitive: false);
    final weekendMatch = weekendPattern.firstMatch(s);
    if (weekendMatch != null) {
      flags.add(AmbiguityFlag.relativeDate);
      final addAWeek = (weekendMatch.group(1)?.toLowerCase() == 'next');
      final sat =
          _startOfWeekend(base, opts.policy.weekendDefaultDay, addAWeek);
      final weekendStart = start ?? sat;
      start = weekendStart;
      if (allDay) allDay = false;
      assumptions.add('Interpreted "${weekendMatch.group(0)}" as '
          '${DateFormat('EEE HH:mm').format(weekendStart)}.');
      confidence -= 0.1;
      s = s.replaceRange(weekendMatch.start, weekendMatch.end, ' ');
      consumed.add(weekendMatch.group(0));
    }

    // Approximate "ish"/"around"
    bool approximate = false;
    final approxPattern = RegExp(r'\b(?:ish|around)\b', caseSensitive: false);
    Match? approxMatchInWorking;
    Match? approxMatchInOriginal;
    if (start != null) {
      approxMatchInWorking = approxPattern.firstMatch(s);
      approxMatchInOriginal =
          approxMatchInWorking ?? approxPattern.firstMatch(original);
    }
    if (start != null && approxMatchInOriginal != null) {
      approximate = true;
      flags.add(AmbiguityFlag.approximateTime);
      assumptions.add('Time marked approximate ("ish"/"around").');
      confidence -= 0.05;
      if (approxMatchInWorking != null) {
        s = s.replaceRange(
          approxMatchInWorking.start,
          approxMatchInWorking.end,
          ' ',
        );
      }
      consumed.add(approxMatchInOriginal.group(0));
    }

    // Location: at/in/to …, @ …, or trailing hint
    String? location;
    final atInToRegex = RegExp(
      r'\b(?<prep>at|in|to)\s+(?:the\s+)?(?<loc>[^,.;]+?)'
      r'(?=(?:\s+(?:with|on|for|by|at|in|to)\b|[,.;]|$))',
      caseSensitive: false,
    );
    final atInToMatches = atInToRegex.allMatches(s).toList();
    for (final match in atInToMatches) {
      final preposition = match.namedGroup('prep')?.toLowerCase();
      final locGroup = match.namedGroup('loc');
      if (locGroup == null) continue;

      final tail = _captureAddressTail(s, match.end);
      final rawCandidate =
          tail == null ? locGroup : '$locGroup${tail.appendedText}';
      final candidate = _pruneTemporalSuffix(
        _normalizeLocation(_clean(rawCandidate)),
      );
      if (candidate == null ||
          _looksTemporalPhrase(candidate) ||
          consumed.overlaps(candidate) ||
          !_looksLikeExactPostalAddress(candidate)) {
        continue;
      }
      if (preposition == 'to' && !_looksLikeToLocationPhrase(s, match.start)) {
        continue;
      }
      final removalEnd = tail?.newEnd ?? match.end;
      location = candidate;
      consumed.add(candidate);
      s = s.replaceRange(match.start, removalEnd, ' ');
      break;
    }
    if (location == null && opts.policy.allowAtSignLocation) {
      final atSig = RegExp(r"\B@\s*([A-Za-z0-9#&+\-' ]{2,})").firstMatch(s);
      if (atSig != null) {
        final candidate =
            _pruneTemporalSuffix(_normalizeLocation(_clean(atSig.group(1)!)));
        if (candidate != null &&
            !_looksLikeHandle(candidate) &&
            !consumed.overlaps(candidate) &&
            _looksLikeExactPostalAddress(candidate)) {
          location = candidate;
          flags.add(AmbiguityFlag.locationGuessed);
          assumptions.add('Used "@ …" as location.');
          consumed.add(candidate);
          s = s.replaceRange(atSig.start, atSig.end, ' ');
        }
      }
    }

    // Participants
    final participants = <String>[];
    final participantSeen = <String>{};
    for (final pat in [
      RegExp(r'\bwith\s+([^,.;]+)', caseSensitive: false),
      RegExp(r'\binvite\s+([^,.;]+)', caseSensitive: false),
      RegExp(r'\bw\/\s*([^,.;]+)', caseSensitive: false),
    ]) {
      for (final match in pat.allMatches(s)) {
        final names = _splitNames(_clean(match.group(1)!));
        for (final name in names) {
          final key = name.toLowerCase();
          if (participantSeen.add(key)) {
            participants.add(name);
          }
        }
      }
    }

    // Time range 3-4, “from 2pm to 4pm”, etc.
    tz.TZDateTime? end;
    final _ExplicitRange? explicitRange = _extractExplicitRange(original);
    if (explicitRange != null) {
      final tz.TZDateTime anchorDay = tz.TZDateTime(
        opts.tzLocation,
        start?.year ?? base.year,
        start?.month ?? base.month,
        start?.day ?? base.day,
      );
      if (explicitRange.start != null && start == null) {
        start = _materializeClockToken(
          explicitRange.start!,
          anchorDay,
          reference: base,
        );
        allDay = false;
      }
      if (start != null && explicitRange.end != null) {
        var candidate = _materializeClockToken(
          explicitRange.end!,
          tz.TZDateTime(
            opts.tzLocation,
            start.year,
            start.month,
            start.day,
          ),
          reference: start,
        );
        if (!candidate.isAfter(start)) {
          candidate = candidate.add(const Duration(hours: 1));
        }
        end = candidate;
        flags.add(AmbiguityFlag.rangeParsed);
        if (explicitRange.start != null) {
          allDay = false;
        }
      }
    }

    if (start != null && end == null) {
      final range = RegExp(
        r'\b(?:(\d{1,2})(?::(\d{2}))?\s*(?:a\.?m\.?|p\.?m\.?|am|pm)?)\s*[-–—]\s*'
        r'(?:(\d{1,2})(?::(\d{2}))?\s*(?:a\.?m\.?|p\.?m\.?|am|pm)?)\b',
        caseSensitive: false,
      ).firstMatch(original);
      if (range != null) {
        final sH = int.parse(range.group(1)!);
        final sM = range.group(2) == null ? 0 : int.parse(range.group(2)!);
        final eH = int.parse(range.group(3)!);
        final eM = range.group(4) == null ? 0 : int.parse(range.group(4)!);
        var sh = sH, eh = eH;
        final hasAmPm =
            RegExp(r'(am|pm)', caseSensitive: false).hasMatch(range.group(0)!);
        if (!hasAmPm) {
          if (sh <= 12 && eh <= 12) {
            if (start.hour >= 12) {
              sh = sh % 12 + 12;
              eh = eh % 12 + 12;
            }
            if (eh <= sh) eh += 1;
          }
        }
        end = tz.TZDateTime(
            opts.tzLocation, start.year, start.month, start.day, eh, eM);
        if (allDay && sh != 0) {
          start = tz.TZDateTime(
              opts.tzLocation, start.year, start.month, start.day, sh, sM);
          allDay = false;
        }
        flags.add(AmbiguityFlag.rangeParsed);
      }
    }

    // Explicit duration phrases ("for 3 hours", "lasting 90 minutes", etc.)
    _DurationExtraction? durationExtraction;
    final _DurationExtraction? workingDuration = _extractDurationPhrase(s);
    if (workingDuration != null) {
      s = workingDuration.cleaned;
      durationExtraction = workingDuration;
    }
    durationExtraction ??= _extractDurationPhrase(original);
    if (durationExtraction != null &&
        consumed.overlaps(durationExtraction.phrase)) {
      durationExtraction = null;
    }

    if (start != null &&
        end == null &&
        durationExtraction != null &&
        durationExtraction.duration.inMinutes > 0) {
      end = start.add(durationExtraction.duration);
      consumed.add(durationExtraction.phrase);
      assumptions.add(
        'Applied duration "${durationExtraction.phrase}" '
        '(${_formatDuration(durationExtraction.duration)}).',
      );
    }

    // Priority (Eisenhower)
    final _PriorityResult pr = _parsePriority(
      original: original,
      base: base,
      start: start,
      policy: opts.policy,
    );

    // Title cleanup
    var title = s.trim();
    title = _stripPriorityMarkers(title, pr.triggerTokens);
    title = _stripAppliedMetadata(
      title,
      hasStart: start != null || recurrence != null,
      hasDeadline: deadline != null,
      hasRecurrence: recurrence != null,
      location: location,
      consumedPhrases: consumed.phrases,
    );
    title = title.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (title.isEmpty) {
      title = _stripAppliedMetadata(
        original,
        hasStart: start != null || recurrence != null,
        hasDeadline: deadline != null,
        hasRecurrence: recurrence != null,
        location: location,
        consumedPhrases: consumed.phrases,
      ).trim();
    }
    if (title.isEmpty) title = 'Untitled';

    // Confidence & ambiguity
    if (start == null) {
      flags.add(AmbiguityFlag.noDateFound);
      confidence -= 0.5;
    } else if (allDay) {
      flags.add(AmbiguityFlag.noTimeGiven);
      confidence -= 0.1;
    }
    if (normal.correctedTypos) {
      flags.add(AmbiguityFlag.typosCorrected);
      confidence -= 0.05;
    }
    if (_looksLikeNumericAmbiguity(original, opts.policy.preferDMY)) {
      flags.add(AmbiguityFlag.numericDateAmbiguous);
      confidence -= 0.1;
      assumptions.add('Encountered ambiguous numeric date (DMY vs MDY).');
    }
    if (deadline != null &&
        !RegExp(r'\b\d{1,2}(:\d{2})?\s*(am|pm)\b', caseSensitive: false)
            .hasMatch(original)) {
      confidence -= 0.05; // we assumed EOD for a date-only deadline
    }
    if (confidence < 0.2) confidence = 0.2;
    if (confidence > 1.0) confidence = 1.0;

    recurrence = _finalizeRecurrence(recurrence, start);

    return ScheduleItem(
      task: title,
      start: start,
      end: end,
      allDay: allDay,
      location: location,
      participants: participants,
      source: original,
      confidence: double.parse(confidence.toStringAsFixed(2)),
      flags: flags,
      assumptions: [...assumptions, ...pr.assumptions],
      approximate: approximate,
      priority: pr.quadrant,
      recurrence: recurrence,
      deadline: deadline,
    );
  }

  _Normalized _normalize(String text, tz.TZDateTime base) {
    String s = ' $text ';
    final flags = <AmbiguityFlag>{};
    final assumptions = <String>[];
    bool corrected = false;

    final replacements = <RegExp, String>{
      RegExp(
          r'\btmrw\b|\btmw\b|\btmo\b|\btom\b|\b2moro\b|\b2morrow\b|\btomm?or?ow\b',
          caseSensitive: false): ' tomorrow ',
      RegExp(r'\btonite\b', caseSensitive: false): ' tonight ',
      RegExp(r'\bw\/\b', caseSensitive: false): ' with ',
      RegExp(r'\bnoon-ish\b|\bnoonish\b', caseSensitive: false): ' noon ',
      RegExp(r'\bmid-day\b|\bmidday\b', caseSensitive: false): ' noon ',
      RegExp(r'\bhrs?\b', caseSensitive: false): ' hours ',
      RegExp(r'\bmins?\b', caseSensitive: false): ' minutes ',
      RegExp(r'\baftr\b', caseSensitive: false): ' after ',
      RegExp(r'\bnite\b', caseSensitive: false): ' night ',
    };
    replacements.forEach((re, rep) {
      final before = s;
      s = s.replaceAll(re, rep);
      if (s != before) corrected = true;
    });

    tz.TZDateTime? relative;
    String? relativeLabel;
    final rel = RegExp(
            r'\bin\s+(\d+(?:\.\d+)?)\s+(minute|minutes|hour|hours|day|days|week|weeks)\b',
            caseSensitive: false)
        .firstMatch(s);
    if (rel != null) {
      final double amount = double.parse(rel.group(1)!);
      final unit = rel.group(2)!.toLowerCase();
      final Duration? delta = _durationFromUnitAmount(amount, unit);
      if (delta != null) {
        relative = base.add(delta);
        relativeLabel = rel.group(0)!;
      }
    } else {
      final relWord = RegExp(
        r'\bin\s+(?:a|an)?\s*(half|quarter|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen)\s+'
        r'(minute|minutes|hour|hours|day|days|week|weeks)\b',
        caseSensitive: false,
      ).firstMatch(s);
      if (relWord != null) {
        final double? amount = _parseDurationValue(relWord.group(1)!);
        final String unit = relWord.group(2)!.toLowerCase();
        final Duration? delta =
            amount != null ? _durationFromUnitAmount(amount, unit) : null;
        if (delta != null) {
          relative = base.add(delta);
          relativeLabel = relWord.group(0)!;
        }
      }
    }

    if (relative == null) {
      final fromNow = RegExp(
        r'\b(half|quarter|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen|\d+(?:\.\d+)?)\s+'
        r'(minute|minutes|hour|hours|day|days|week|weeks)\s+from\s+now\b',
        caseSensitive: false,
      ).firstMatch(s);
      if (fromNow != null) {
        final double? amount = _parseDurationValue(fromNow.group(1)!);
        final String unit = fromNow.group(2)!.toLowerCase();
        final Duration? delta =
            amount != null ? _durationFromUnitAmount(amount, unit) : null;
        if (delta != null) {
          relative = base.add(delta);
          relativeLabel = fromNow.group(0)!;
        }
      }
    }

    if (relative == null) {
      final afterMatch = RegExp(
        r'\bafter\s+(?:a|an)?\s*(half|quarter|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen|\d+(?:\.\d+)?)\s+'
        r'(minute|minutes|hour|hours|day|days|week|weeks)\b',
        caseSensitive: false,
      ).firstMatch(s);
      if (afterMatch != null) {
        final double? amount = _parseDurationValue(afterMatch.group(1)!);
        final String unit = afterMatch.group(2)!.toLowerCase();
        final Duration? delta =
            amount != null ? _durationFromUnitAmount(amount, unit) : null;
        if (delta != null) {
          relative = base.add(delta);
          relativeLabel = afterMatch.group(0)!;
        }
      }
    }

    if (relative == null) {
      final laterMatch = RegExp(
        r'\b(half|quarter|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen|\d+(?:\.\d+)?)\s+'
        r'(minute|minutes|hour|hours|day|days|week|weeks)\s+later\b',
        caseSensitive: false,
      ).firstMatch(s);
      if (laterMatch != null) {
        final double? amount = _parseDurationValue(laterMatch.group(1)!);
        final String unit = laterMatch.group(2)!.toLowerCase();
        final Duration? delta =
            amount != null ? _durationFromUnitAmount(amount, unit) : null;
        if (delta != null) {
          relative = base.add(delta);
          relativeLabel = laterMatch.group(0)!;
        }
      }
    }

    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (corrected) flags.add(AmbiguityFlag.typosCorrected);

    return _Normalized(
      text: s,
      flags: flags,
      assumptions: assumptions,
      correctedTypos: corrected,
      relativeFallback: relative,
      relativeFallbackLabel: relativeLabel,
    );
  }

  _DeadlineParse _extractDeadline(String s, tz.TZDateTime base) {
    String text = s;
    tz.TZDateTime? deadline;
    final flags = <AmbiguityFlag>{};
    final assumptions = <String>[];

    tz.TZDateTime endOfDayFor(tz.TZDateTime d) => tz.TZDateTime(
        opts.tzLocation, d.year, d.month, d.day, opts.policy.endOfDayHour);

    // Explicit phrases: by/before/no later than/due
    final m = RegExp(
      r'\b(?:by|before|no\s+later\s+than|not\s+later\s+than|due(?:\s+(?:on|by))?|deadline(?:\s*(?:is|:))?)\s+([^,.;]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (m != null) {
      final st = m.start, en = m.end;
      final target = m.group(1)!.trim();
      final normalizedTarget =
          target.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
      bool interpretedDeadline = false;

      if (_isBareNextWeekPhrase(normalizedTarget)) {
        final tz.TZDateTime nextWeekMonday = _nextWeekMondayDeadline(base);
        deadline = nextWeekMonday;
        flags.add(AmbiguityFlag.deadline);
        assumptions.add(
          'Interpreted "${m.group(0)}" as deadline '
          '${nextWeekMonday.toIso8601String()}.',
        );
        interpretedDeadline = true;
      }

      if (!interpretedDeadline) {
        final ref =
            ParsingReference(instant: base.toUtc(), timezone: opts.tzName);
        final rs = Chrono.parse(' $target ',
            ref: ref, option: ParsingOption(forwardDate: true));
        if (rs.isNotEmpty) {
          var dt = tz.TZDateTime.from(rs.last.date(), opts.tzLocation);
          final hadTime = rs.last.start.isCertain(Component.hour);
          if (!hadTime) dt = endOfDayFor(dt);
          deadline = dt;
          flags.add(AmbiguityFlag.deadline);
          assumptions.add(
            'Interpreted "${m.group(0)}" as deadline ${dt.toIso8601String()}.',
          );
        }
      }

      text = ('${text.substring(0, st)} ${text.substring(en)}')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
    } else {
      // EOD/EOW/EOM/EOY tokens as deadlines when not part of recurrence
      final looksRecurring = RegExp(
        r'\b(every|each|weekly|monthly|yearly|annually|biweekly|weekdays|weekends|mwf|tth|until|through)\b',
        caseSensitive: false,
      ).hasMatch(text);

      final eox = RegExp(
        r'\b(EOD|COB|end of day|EOW|end of week|EOM|end of month|EOY|end of year)\b',
        caseSensitive: false,
      ).firstMatch(text);

      if (eox != null && !looksRecurring) {
        tz.TZDateTime d;
        final tag = eox.group(0)!.toLowerCase();

        if (tag.contains('eod') ||
            tag.contains('cob') ||
            tag.contains('end of day')) {
          d = tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day,
              opts.policy.endOfDayHour);
          assumptions.add(
              'EOD/COB → today ${opts.policy.endOfDayHour.toString().padLeft(2, '0')}:00 deadline.');
        } else if (tag.contains('eow') || tag.contains('end of week')) {
          final friDelta = (DateTime.friday - base.weekday + 7) % 7;
          final fri =
              tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day)
                  .add(Duration(days: friDelta));
          d = tz.TZDateTime(opts.tzLocation, fri.year, fri.month, fri.day,
              opts.policy.endOfDayHour);
          assumptions.add(
              'EOW → Friday ${opts.policy.endOfDayHour.toString().padLeft(2, '0')}:00 deadline.');
        } else if (tag.contains('eom') || tag.contains('end of month')) {
          final firstNext = (base.month == 12)
              ? tz.TZDateTime(opts.tzLocation, base.year + 1, 1, 1)
              : tz.TZDateTime(opts.tzLocation, base.year, base.month + 1, 1);
          final lastDay = firstNext.subtract(const Duration(seconds: 1));
          d = tz.TZDateTime(opts.tzLocation, lastDay.year, lastDay.month,
              lastDay.day, opts.policy.endOfDayHour);
          assumptions.add(
              'EOM → last day ${opts.policy.endOfDayHour.toString().padLeft(2, '0')}:00 deadline.');
        } else {
          d = tz.TZDateTime(
              opts.tzLocation, base.year, 12, 31, opts.policy.endOfDayHour);
          assumptions.add(
              'EOY → Dec 31 ${opts.policy.endOfDayHour.toString().padLeft(2, '0')}:00 deadline.');
        }

        deadline = d;
        flags.add(AmbiguityFlag.deadline);
        flags.add(AmbiguityFlag.eoxShortcut);
        final st = eox.start, en = eox.end;
        text = ('${text.substring(0, st)} ${text.substring(en)}')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }

    return _DeadlineParse(text, deadline, flags, assumptions);
  }

  bool _isBareNextWeekPhrase(String target) {
    if (target.isEmpty) return false;
    return RegExp(r'^(?:the\s+)?next\s+(?:week|wk)$').hasMatch(target);
  }

  tz.TZDateTime _nextWeekMondayDeadline(tz.TZDateTime base) {
    final tz.TZDateTime anchor =
        tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day);
    var daysUntilMonday = (DateTime.monday - anchor.weekday + 7) % 7;
    if (daysUntilMonday == 0) {
      daysUntilMonday = 7;
    }
    final tz.TZDateTime nextMonday =
        anchor.add(Duration(days: daysUntilMonday));
    return tz.TZDateTime(
      opts.tzLocation,
      nextMonday.year,
      nextMonday.month,
      nextMonday.day,
      opts.policy.endOfDayHour,
    );
  }

  _RecurrenceParse _parseRecurrence(String s, tz.TZDateTime base) {
    final weekdayMatcher = RegExp(
      '\\b(?:$_weekdayWordPattern)\\b',
      caseSensitive: false,
    );

    int extendToBoundary(int index) {
      var cursor = index;
      while (cursor < s.length) {
        final ch = s[cursor];
        if (ch == ',' || ch == ';' || ch == '.') {
          break;
        }
        cursor++;
      }
      return cursor;
    }

    int? spanStart;
    int? spanEnd;
    final ordinalSpan = RegExp(
      '\\b(?:the\\s+)?(?:first|second|third|fourth|last|\\d{1,2}(?:st|nd|rd|th))\\s+($_weekdayWordPattern)\\s+of\\s+(?:the\\s+)?(?:each\\s+|every\\s+)?month\\b',
      caseSensitive: false,
    ).firstMatch(s);
    if (ordinalSpan != null) {
      spanStart = ordinalSpan.start;
      spanEnd = extendToBoundary(ordinalSpan.end);
    }

    if (spanStart == null) {
      final spanMatch = RegExp(
        r'\b(?:every|each|everyday|daily|weekly|monthly|yearly|annually|biweekly|weekday|weekdays|weekend|weekends|mwf|tth)\b[^,.;]*',
        caseSensitive: false,
      ).firstMatch(s);
      if (spanMatch != null) {
        spanStart = spanMatch.start;
        spanEnd = spanMatch.end;
      }
    }

    if (spanStart == null) {
      final looseMatches = weekdayMatcher.allMatches(s).toList();
      if (looseMatches.length >= 2) {
        spanStart = looseMatches.first.start;
        spanEnd = extendToBoundary(looseMatches.last.end);
      }
    }

    if (spanStart == null || spanEnd == null) {
      return _RecurrenceParse(s, null);
    }

    final phrase = s.substring(spanStart, spanEnd).trim();

    String freq = '';
    int interval = 1;
    List<String> byday = [];
    int? bymonthday;
    int? bysetpos;
    int? count;

    String dowToIcs(String w) {
      final w0 = w.toLowerCase();
      if (w0.startsWith('mo')) return 'MO';
      if (w0.startsWith('tu')) return 'TU';
      if (w0.startsWith('we')) return 'WE';
      if (w0.startsWith('th')) return 'TH';
      if (w0.startsWith('fr')) return 'FR';
      if (w0.startsWith('sa')) return 'SA';
      return 'SU';
    }

    void ensureWeekly() {
      if (freq.isEmpty) freq = 'WEEKLY';
    }

    if (RegExp(r'\bdaily\b').hasMatch(phrase)) freq = 'DAILY';
    if (RegExp(r'\bweekly\b').hasMatch(phrase)) freq = 'WEEKLY';
    if (RegExp(r'\bbiweekly\b').hasMatch(phrase)) {
      freq = 'WEEKLY';
      interval = 2;
    }
    if (RegExp(r'\bmonthly\b').hasMatch(phrase)) {
      freq = 'MONTHLY';
    }
    if (RegExp(r'\byearly\b|\bannually\b').hasMatch(phrase)) {
      freq = 'YEARLY';
    }

    final mEveryN =
        RegExp(r'\b(?:every|each)\s+(other|\d+)\b').firstMatch(phrase);
    if (mEveryN != null) {
      if (mEveryN.group(1)!.toLowerCase() == 'other') {
        interval = 2;
      } else {
        interval = int.tryParse(mEveryN.group(1)!) ?? 1;
      }
    }
    final mEveryNUnits = RegExp(
            r'\b(?:every|each)\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b')
        .firstMatch(phrase);
    if (mEveryNUnits != null) {
      final n = int.parse(mEveryNUnits.group(1)!);
      final unit = mEveryNUnits.group(2)!.toLowerCase();
      interval = n;
      if (unit.startsWith('day')) {
        freq = 'DAILY';
      } else if (unit.startsWith('week')) {
        freq = 'WEEKLY';
      } else if (unit.startsWith('month')) {
        freq = 'MONTHLY';
      } else {
        freq = 'YEARLY';
      }
    }

    final bool mentionsDailyUnit = RegExp(
      r'\b(?:everyday|(?:every|each)(?:\s+other)?\s+day(?:s)?)\b',
      caseSensitive: false,
    ).hasMatch(phrase);
    final bool mentionsWeeklyUnit = RegExp(
      r'\b(?:every|each)(?:\s+other)?\s+week(?:s)?\b',
      caseSensitive: false,
    ).hasMatch(phrase);
    final bool mentionsMonthlyUnit = RegExp(
      r'\b(?:every|each)(?:\s+other)?\s+month(?:s)?\b',
      caseSensitive: false,
    ).hasMatch(phrase);
    final bool mentionsYearlyUnit = RegExp(
      r'\b(?:every|each)(?:\s+other)?\s+year(?:s)?\b',
      caseSensitive: false,
    ).hasMatch(phrase);

    if (freq.isEmpty && mentionsDailyUnit) {
      freq = 'DAILY';
    } else if (freq.isEmpty && mentionsWeeklyUnit) {
      freq = 'WEEKLY';
    } else if (freq.isEmpty && mentionsMonthlyUnit) {
      freq = 'MONTHLY';
    } else if (freq.isEmpty && mentionsYearlyUnit) {
      freq = 'YEARLY';
    }

    if (RegExp(r'\bweekday(s)?\b', caseSensitive: false).hasMatch(phrase)) {
      ensureWeekly();
      byday = ['MO', 'TU', 'WE', 'TH', 'FR'];
    }
    if (RegExp(r'\bweekend(s)?\b', caseSensitive: false).hasMatch(phrase)) {
      ensureWeekly();
      byday = ['SA', 'SU'];
    }
    if (RegExp(r'\bmwf\b', caseSensitive: false).hasMatch(phrase)) {
      ensureWeekly();
      byday = ['MO', 'WE', 'FR'];
    }
    if (RegExp(r'\btth\b', caseSensitive: false).hasMatch(phrase)) {
      ensureWeekly();
      byday = ['TU', 'TH'];
    }

    final dayMatches = weekdayMatcher.allMatches(phrase).toList();
    if (dayMatches.isNotEmpty) {
      ensureWeekly();
      final seen = <String>{};
      for (final m in dayMatches) {
        final code = dowToIcs(m.group(0)!);
        if (seen.add(code)) byday.add(code);
      }
    }

    final mOrd = RegExp(
      '\\b(first|second|third|fourth|last)\\s+($_weekdayWordPattern)\\s+of\\s+(?:the\\s+)?(?:each\\s+|every\\s+)?month\\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (mOrd != null) {
      freq = 'MONTHLY';
      final ord = mOrd.group(1)!.toLowerCase();
      final day = mOrd.group(2)!;
      byday = [dowToIcs(day)];
      bysetpos = switch (ord) {
        'first' => 1,
        'second' => 2,
        'third' => 3,
        'fourth' => 4,
        _ => -1
      };
    }

    final mNumericOrd = RegExp(
      '\\b(?:the\\s+)?(\\d{1,2})(st|nd|rd|th)\\s+($_weekdayWordPattern)\\s+of\\s+(?:the\\s+)?(?:each\\s+|every\\s+)?month\\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (mNumericOrd != null) {
      freq = 'MONTHLY';
      final ordValue = int.tryParse(mNumericOrd.group(1)!);
      final day = mNumericOrd.group(3)!;
      if (ordValue != null && ordValue > 0) {
        byday = [dowToIcs(day)];
        final capped = ordValue > 4 ? 4 : ordValue;
        bysetpos = capped;
      }
    }

    final mMonthDay = RegExp(
      r'\b(on\s+)?the\s+(\d{1,2})(st|nd|rd|th)?\s+(of\s+)?(each|every)?\s*month\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (mMonthDay != null) {
      freq = 'MONTHLY';
      bymonthday = int.parse(mMonthDay.group(2)!);
    }

    tz.TZDateTime? untilLocal;
    final mUntil =
        RegExp(r'\b(until|till|til|through)\s+([^,.;]+)', caseSensitive: false)
            .firstMatch(phrase);
    if (mUntil != null) {
      final untilText = mUntil.group(2)!.trim();
      if (RegExp(r'\bEOY\b|\bend of (the )?year\b', caseSensitive: false)
          .hasMatch(untilText)) {
        untilLocal =
            tz.TZDateTime(opts.tzLocation, base.year, 12, 31, 23, 59, 59);
      } else if (RegExp(r'\bEOM\b|\bend of (the )?month\b',
              caseSensitive: false)
          .hasMatch(untilText)) {
        final firstNext = (base.month == 12)
            ? tz.TZDateTime(opts.tzLocation, base.year + 1, 1, 1)
            : tz.TZDateTime(opts.tzLocation, base.year, base.month + 1, 1);
        final lastDay = firstNext.subtract(const Duration(seconds: 1));
        untilLocal = lastDay;
      } else {
        final ref =
            ParsingReference(instant: base.toUtc(), timezone: opts.tzName);
        final rs = Chrono.parse(' $untilText ',
            ref: ref, option: ParsingOption(forwardDate: true));
        if (rs.isNotEmpty) {
          var dt = tz.TZDateTime.from(rs.last.date(), opts.tzLocation);
          final hadTime = rs.last.start.isCertain(Component.hour);
          if (!hadTime) {
            dt = tz.TZDateTime(
                opts.tzLocation, dt.year, dt.month, dt.day, 23, 59, 59);
            if (RegExp(r'\bnext year\b', caseSensitive: false)
                    .hasMatch(untilText) &&
                dt.month == 1 &&
                dt.day == 1) {
              dt = tz.TZDateTime(
                  opts.tzLocation, dt.year - 1, 12, 31, 23, 59, 59);
            }
          }
          untilLocal = dt;
        } else {
          untilLocal = _parseLooseDateFallback(untilText, base);
        }
      }
    }

    final mCount = RegExp(
      r'\bfor\s+(\d+)\s+(times|occurrences)\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (mCount != null) {
      count = int.parse(mCount.group(1)!);
    }

    final mDurationLimit = RegExp(
      r'\bfor\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    int? limitCount;
    if (mDurationLimit != null) {
      limitCount = int.tryParse(mDurationLimit.group(1)!);
      final limitUnit = mDurationLimit.group(2)!.toLowerCase();
      if (freq.isEmpty) {
        freq = switch (limitUnit) {
          'day' || 'days' => 'DAILY',
          'week' || 'weeks' => 'WEEKLY',
          'month' || 'months' => 'MONTHLY',
          'year' || 'years' => 'YEARLY',
          _ => freq,
        };
      }
    }
    if (count == null && limitCount != null) {
      count = limitCount;
    }

    if (freq.isEmpty &&
        byday.isEmpty &&
        bymonthday == null &&
        bysetpos == null) {
      return _RecurrenceParse(s, null);
    }
    if (freq.isEmpty) freq = 'WEEKLY';

    String rrule = 'FREQ=$freq';
    if (interval > 1) rrule += ';INTERVAL=$interval';
    if (byday.isNotEmpty) rrule += ';BYDAY=${byday.join(',')}';
    if (bymonthday != null) rrule += ';BYMONTHDAY=$bymonthday';
    if (bysetpos != null) rrule += ';BYSETPOS=$bysetpos';
    if (untilLocal != null) rrule += ';UNTIL=${_formatIcsUtc(untilLocal)}';
    if (count != null) rrule += ';COUNT=$count';

    final anchorTextBase = (byday.isNotEmpty ||
            bymonthday != null ||
            bysetpos != null)
        ? phrase
            .replaceAll(
                RegExp(
                    r'\b(every|each|everyday|weekly|monthly|yearly|annually|biweekly|weekday|weekdays|weekend|weekends|mwf|tth)\b',
                    caseSensitive: false),
                '')
            .replaceAll(
                RegExp(r'\b(until|through)\s+[^,.;]+', caseSensitive: false),
                '')
            .replaceAll(
                RegExp(r'\bfor\s+\d+\s+(times|occurrences)\b',
                    caseSensitive: false),
                '')
            .trim()
        : '';
    String anchorText = anchorTextBase;
    final timeAnchorMatch = RegExp(
      '\\b(?:at|@|around)\\s+$_timeSnippetPattern',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (timeAnchorMatch != null) {
      final snippet =
          phrase.substring(timeAnchorMatch.start, timeAnchorMatch.end).trim();
      if (!anchorText.contains(snippet)) {
        anchorText = [anchorText, snippet]
            .where((part) => part.trim().isNotEmpty)
            .join(' ');
      }
    }

    final cleaned = ('${s.substring(0, spanStart)} '
            '${anchorText.isEmpty ? '' : anchorText} ${s.substring(spanEnd)}')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    return _RecurrenceParse(
        cleaned,
        Recurrence(
            rrule: rrule, text: phrase, until: untilLocal, count: count));
  }

  String _formatIcsUtc(tz.TZDateTime local) {
    final utc = local.toUtc();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${utc.year}${two(utc.month)}${two(utc.day)}T${two(utc.hour)}${two(utc.minute)}${two(utc.second)}Z';
  }

  tz.TZDateTime? _parseLooseDateFallback(String text, tz.TZDateTime base) {
    var working = text.trim();
    if (working.isEmpty) return null;
    working = working.replaceAll(
        RegExp(r'(\d)(st|nd|rd|th)\b', caseSensitive: false), r'$1');
    final patterns = [
      DateFormat('MMMM d'),
      DateFormat('MMM d'),
      DateFormat('d MMMM'),
      DateFormat('d MMM'),
    ];
    for (final format in patterns) {
      try {
        final parsed = format.parseLoose(working);
        var candidate = tz.TZDateTime(
          opts.tzLocation,
          base.year,
          parsed.month,
          parsed.day,
          opts.policy.endOfDayHour,
          59,
          59,
        );
        if (candidate.isBefore(base)) {
          candidate = tz.TZDateTime(
            opts.tzLocation,
            base.year + 1,
            parsed.month,
            parsed.day,
            opts.policy.endOfDayHour,
            59,
            59,
          );
        }
        return candidate;
      } catch (_) {
        continue;
      }
    }
    return null;
  }

  Recurrence? _finalizeRecurrence(
    Recurrence? recurrence,
    tz.TZDateTime? start,
  ) {
    if (recurrence == null || start == null) {
      return recurrence;
    }
    final _RecurrenceSpec? spec =
        _RecurrenceMath.tryParse(recurrence, start.location);
    if (spec == null) {
      return recurrence;
    }

    tz.TZDateTime? until = recurrence.until;
    int? count = recurrence.count;

    if (until == null && count != null && count > 0) {
      until = _RecurrenceMath.computeUntilFromCount(start, spec, count);
    }
    if (count == null && until != null) {
      count = _RecurrenceMath.computeCountFromUntil(start, spec, until);
    }

    if (until == recurrence.until && count == recurrence.count) {
      return recurrence;
    }

    final String updatedRrule = _rewriteRrule(
      recurrence.rrule,
      until: until,
      count: count,
    );

    return Recurrence(
      rrule: updatedRrule,
      text: recurrence.text,
      until: until,
      count: count,
    );
  }

  String _rewriteRrule(
    String rrule, {
    tz.TZDateTime? until,
    int? count,
  }) {
    final Map<String, String> fields = {};
    for (final token in rrule.split(';')) {
      final idx = token.indexOf('=');
      if (idx <= 0) continue;
      final key = token.substring(0, idx).toUpperCase();
      final value = token.substring(idx + 1);
      fields[key] = value;
    }
    if (until != null) {
      fields['UNTIL'] = _formatIcsUtc(until);
    }
    if (count != null) {
      fields['COUNT'] = count.toString();
    }
    const orderedKeys = <String>[
      'FREQ',
      'INTERVAL',
      'BYDAY',
      'BYMONTHDAY',
      'BYSETPOS',
      'UNTIL',
      'COUNT',
    ];
    final buffer = <String>[];
    for (final key in orderedKeys) {
      final value = fields.remove(key);
      if (value != null && value.isNotEmpty) {
        buffer.add('$key=$value');
      }
    }
    fields.forEach((key, value) {
      if (value.isNotEmpty) {
        buffer.add('$key=$value');
      }
    });
    return buffer.join(';');
  }

  _ManualFallbackResult? _manualTimeFallback(
    String original,
    String working,
    tz.TZDateTime base,
  ) {
    var text = working;
    final assumptions = <String>[];
    final flags = <AmbiguityFlag>{};
    final dayStart =
        tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day);
    var anchor = dayStart;
    var anchorExplicit = false;
    var useReferenceTime = false;
    final lowerOriginal = original.toLowerCase();
    final bool hasMorningCue =
        RegExp(r'\b(morning|sunrise|dawn)\b').hasMatch(lowerOriginal);
    final bool hasEveningCue = RegExp(r'\b(tonight|evening|night|afternoon)\b')
        .hasMatch(lowerOriginal);

    Match? match = RegExp(r'\bthis time tomorrow\b', caseSensitive: false)
        .firstMatch(text);
    if (match != null) {
      anchor = anchor.add(const Duration(days: 1));
      anchorExplicit = true;
      useReferenceTime = true;
      text = text.replaceRange(match.start, match.end, ' ');
      flags.add(AmbiguityFlag.relativeDate);
      assumptions.add(
          'Mapped "${match.group(0)}" to ${_fmtDate(anchor)} at ${_hhmm(base.hour)}.');
    } else {
      match = RegExp(r'\bday after tomorrow\b', caseSensitive: false)
          .firstMatch(text);
      if (match != null) {
        anchor = anchor.add(const Duration(days: 2));
        anchorExplicit = true;
        text = text.replaceRange(match.start, match.end, ' ');
        flags.add(AmbiguityFlag.relativeDate);
        assumptions
            .add('Interpreted "${match.group(0)}" as ${_fmtDate(anchor)}.');
      } else {
        match = RegExp(r'\btomorrow\b', caseSensitive: false).firstMatch(text);
        if (match != null) {
          anchor = anchor.add(const Duration(days: 1));
          anchorExplicit = true;
          text = text.replaceRange(match.start, match.end, ' ');
          flags.add(AmbiguityFlag.relativeDate);
          assumptions
              .add('Interpreted "${match.group(0)}" as ${_fmtDate(anchor)}.');
        }
      }
    }

    match = RegExp(
      r'\bnext\s+(monday|tuesday|wednesday|thursday|friday|saturday|sunday|mon|tue|wed|thu|fri|sat|sun)\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (match != null) {
      final weekday = _weekdayFromToken(match.group(1)!);
      if (weekday != null) {
        anchor = _nextWeekday(anchor, weekday);
        anchorExplicit = true;
        text = text.replaceRange(match.start, match.end, ' ');
        flags.add(AmbiguityFlag.relativeDate);
        assumptions
            .add('Interpreted "${match.group(0)}" as ${_fmtDate(anchor)}.');
      }
    }

    void consumeAnchor(RegExp pattern) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        anchorExplicit = true;
        text = text.replaceRange(m.start, m.end, ' ');
      }
    }

    consumeAnchor(RegExp(r'\btoday\b', caseSensitive: false));
    consumeAnchor(RegExp(r'\btonight\b', caseSensitive: false));
    consumeAnchor(
      RegExp(r'\bthis\s+(morning|afternoon|evening|night)\b',
          caseSensitive: false),
    );

    Match? timeMatch = RegExp(
      r'\b(?:at|@)\s*(\d{1,2})(?::(\d{2}))?\s*((?:a\.?m\.?|p\.?m\.?|am|pm))\b',
      caseSensitive: false,
    ).firstMatch(text);

    var explicit24h = false;
    timeMatch ??= RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*((?:a\.?m\.?|p\.?m\.?|am|pm))\b',
      caseSensitive: false,
    ).firstMatch(text);
    if (timeMatch == null) {
      timeMatch = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(text);
      explicit24h = timeMatch != null;
    }
    int? hour;
    int? minute;
    bool ambiguousNoMeridiem = false;
    Match? compactMatch;
    if (timeMatch == null) {
      compactMatch = RegExp(
        r'\b(?:at|@|around|from|by)\s*(\d{3,4})\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (compactMatch != null) {
        final digits = compactMatch.group(1)!;
        final int value = int.parse(digits);
        final int hours = value ~/ 100;
        final int minutes = value % 100;
        if (hours <= 23 && minutes < 60) {
          hour = hours;
          minute = minutes;
          explicit24h = true;
          text = text.replaceRange(compactMatch.start, compactMatch.end, ' ');
          assumptions.add('Interpreted "${compactMatch.group(0)}" '
              'as ${_hhmm(hour)}.');
        }
      }
    }
    Match? simpleHourMatch;
    if (timeMatch == null && hour == null) {
      simpleHourMatch = RegExp(
        r'\b(?:at|@|around|from|by)\s*(\d{1,2})(?![:\d])\b',
        caseSensitive: false,
      ).firstMatch(text);
      if (simpleHourMatch != null) {
        final value = int.parse(simpleHourMatch.group(1)!);
        if (value <= 23) {
          hour = value;
          minute = 0;
          ambiguousNoMeridiem = true;
          text = text.replaceRange(
              simpleHourMatch.start, simpleHourMatch.end, ' ');
          assumptions.add(
              'Interpreted "${simpleHourMatch.group(0)}" as ${_hhmm(value)}.');
        }
      }
    }

    if (timeMatch != null) {
      hour = int.parse(timeMatch.group(1)!);
      minute = timeMatch.group(2) != null ? int.parse(timeMatch.group(2)!) : 0;
      final meridiem = timeMatch.groupCount >= 3
          ? timeMatch.group(3)?.replaceAll('.', '').toLowerCase()
          : null;
      if (meridiem != null) {
        if (meridiem.contains('p') && hour < 12) hour += 12;
        if (meridiem.contains('a') && hour == 12) hour = 0;
      } else if (!explicit24h) {
        ambiguousNoMeridiem = true;
      }
      text = text.replaceRange(timeMatch.start, timeMatch.end, ' ');
      assumptions.add('Interpreted "${timeMatch.group(0)}" as ${_hhmm(hour)}.');
    }

    if (hour == null &&
        RegExp(r'\bnoon\b', caseSensitive: false).hasMatch(text)) {
      hour = 12;
      minute = 0;
      text = text.replaceFirst(RegExp(r'\bnoon\b', caseSensitive: false), ' ');
      assumptions.add('Mapped "noon" to 12:00.');
    } else if (hour == null &&
        RegExp(r'\bmidnight\b', caseSensitive: false).hasMatch(text)) {
      hour = 0;
      minute = 0;
      text =
          text.replaceFirst(RegExp(r'\bmidnight\b', caseSensitive: false), ' ');
      assumptions.add('Mapped "midnight" to 00:00.');
    } else if (hour == null && useReferenceTime) {
      hour = base.hour;
      minute = base.minute;
    }

    if (ambiguousNoMeridiem && hour != null) {
      final int resolvedHour = hour;
      final int minutes = minute ?? 0;
      final tz.TZDateTime sameDayCandidate = tz.TZDateTime(
        opts.tzLocation,
        anchor.year,
        anchor.month,
        anchor.day,
        resolvedHour,
        minutes,
      );
      final bool shouldShiftToPm = resolvedHour < 12 &&
          !hasMorningCue &&
          (hasEveningCue ||
              (!anchorExplicit && sameDayCandidate.isBefore(base)));
      if (shouldShiftToPm) {
        hour = (resolvedHour + 12) % 24;
      }
    }

    if (hour == null) return null;
    minute ??= 0;

    var candidate = tz.TZDateTime(
        opts.tzLocation, anchor.year, anchor.month, anchor.day, hour, minute);
    if (!anchorExplicit && candidate.isBefore(base)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    return _ManualFallbackResult(
      start: candidate,
      allDay: false,
      cleanedText: text,
      assumptions: assumptions,
      flags: flags,
    );
  }

  tz.TZDateTime _nextWeekday(tz.TZDateTime start, int weekday) {
    var delta = (weekday - start.weekday + 7) % 7;
    if (delta <= 0) delta += 7;
    return start.add(Duration(days: delta));
  }

  int? _weekdayFromToken(String token) {
    final normalized = token.toLowerCase();
    if (normalized.startsWith('mon')) return DateTime.monday;
    if (normalized.startsWith('tue')) return DateTime.tuesday;
    if (normalized.startsWith('wed')) return DateTime.wednesday;
    if (normalized.startsWith('thu')) return DateTime.thursday;
    if (normalized.startsWith('fri')) return DateTime.friday;
    if (normalized.startsWith('sat')) return DateTime.saturday;
    if (normalized.startsWith('sun')) return DateTime.sunday;
    return null;
  }

  String _fmtDate(tz.TZDateTime dt) => DateFormat('y-MM-dd').format(dt);

  _PriorityResult _parsePriority({
    required String original,
    required tz.TZDateTime base,
    required tz.TZDateTime? start,
    required FuzzyPolicy policy,
  }) {
    bool important = false, urgent = false;
    final notes = <String>[];
    final tokensUsed = <String>{};

    String? matchToken(List<String> words) {
      for (final word in words) {
        final regex = _priorityTokenRegex(word);
        if (regex == null) continue;
        final match = regex.firstMatch(original);
        if (match != null) {
          return match.group(2);
        }
      }
      return null;
    }

    final importantToken = matchToken(policy.importantWords);
    if (importantToken != null) {
      important = true;
      tokensUsed.add(importantToken);
      notes.add('Marked important from text.');
    }
    final notImportantToken = matchToken(policy.notImportantWords);
    if (notImportantToken != null) {
      important = false;
      tokensUsed.add(notImportantToken);
      notes.add('Marked not‑important from text.');
    }

    final urgentToken = matchToken(policy.urgentWords);
    if (urgentToken != null) {
      urgent = true;
      tokensUsed.add(urgentToken);
      notes.add('Marked urgent from text.');
    }
    final notUrgentToken = matchToken(policy.notUrgentWords);
    if (notUrgentToken != null) {
      urgent = false;
      tokensUsed.add(notUrgentToken);
      notes.add('Marked not‑urgent from text.');
    }

    PriorityQuadrant quadrant;
    if (important && urgent) {
      quadrant = PriorityQuadrant.importantUrgent;
    } else if (important && !urgent) {
      quadrant = PriorityQuadrant.importantNotUrgent;
    } else if (!important && urgent) {
      quadrant = PriorityQuadrant.notImportantUrgent;
    } else {
      quadrant = PriorityQuadrant.notImportantNotUrgent;
    }
    return _PriorityResult(quadrant, notes, tokensUsed);
  }

  _Vague? _resolveVaguePartOfDay(String original) {
    final lower = original.toLowerCase();
    if (lower.contains('tonight')) {
      return _Vague('tonight', opts.policy.defaultEveningHour, isTonight: true);
    }
    if (lower.contains('morning')) {
      return _Vague('morning', opts.policy.defaultMorningHour);
    }
    if (lower.contains('afternoon')) {
      return _Vague('afternoon', opts.policy.defaultAfternoonHour);
    }
    if (lower.contains('evening')) {
      return _Vague('evening', opts.policy.defaultEveningHour);
    }
    if (lower.contains('lunchtime') ||
        lower.contains('lunch time') ||
        lower.contains('lunch')) {
      return _Vague('lunch', opts.policy.lunchHour);
    }
    if (lower.contains('after work')) {
      return _Vague('after work', opts.policy.afterWorkHour);
    }
    return null;
  }

  bool _looksLikeNumericAmbiguity(String s, bool preferDMY) {
    final m = RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})(?!\d)').firstMatch(s);
    if (m == null) {
      final y =
          RegExp(r'\b(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{2,4})\b').firstMatch(s);
      if (y == null) return false;
      final aa = int.parse(y.group(1)!);
      final bb = int.parse(y.group(2)!);
      return aa <= 12 && bb <= 12;
    }
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    return a <= 12 && b <= 12;
  }

  List<String> _splitNames(String s) => s
      .split(RegExp(r'\s*(?:,|&| and )\s*', caseSensitive: false))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList(growable: false);

  String _stripPriorityMarkers(String text, Set<String> tokens) {
    if (text.isEmpty) return text.trim();
    if (tokens.isEmpty) return text.trim();
    var cleaned = text;
    for (final token in tokens) {
      final regex = _priorityTokenRegex(token);
      if (regex == null) continue;
      cleaned = cleaned.replaceAllMapped(regex, (match) {
        final prefix = match.group(1) ?? '';
        return prefix.isEmpty ? ' ' : prefix;
      });
    }
    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripAppliedMetadata(
    String text, {
    required bool hasStart,
    required bool hasDeadline,
    required bool hasRecurrence,
    String? location,
    Iterable<String> consumedPhrases = const [],
  }) {
    if (text.isEmpty) return text;
    var cleaned = text;

    if (location != null && location.isNotEmpty) {
      final escaped = RegExp.escape(location);
      cleaned = cleaned.replaceAll(
        RegExp(r'\b(?:at|in|to)\s+(?:the\s+)?' + escaped + r'\b',
            caseSensitive: false),
        ' ',
      );
      cleaned = cleaned.replaceAll(
        RegExp(r'\b' + escaped + r'\b', caseSensitive: false),
        ' ',
      );
    }

    for (final phrase in consumedPhrases) {
      final normalized = phrase.trim();
      if (normalized.isEmpty) continue;
      final pattern = RegExp(
        '(^|[\\s,:;!\\-\\/])${RegExp.escape(normalized)}(?=\$|[\\s,:;!\\-\\/])',
        caseSensitive: false,
      );
      cleaned = cleaned.replaceAll(pattern, ' ');
    }

    return cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  RegExp? _priorityTokenRegex(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final pattern = trimmed
        .split(RegExp(r'\s+'))
        .map((segment) => RegExp.escape(segment))
        .join(r'\s+');
    if (pattern.isEmpty) return null;
    return RegExp(
      '(^|[\\s,:;!\\-\\/])($pattern)(?=\$|[\\s,:;!\\-\\/])',
      caseSensitive: false,
    );
  }

  String? _normalizeLocation(String? raw) {
    if (raw == null) return null;
    var value = raw.trim();
    if (value.isEmpty) return null;
    value = value.replaceFirst(
        RegExp(r'^(?:at|in|to)\s+', caseSensitive: false), '');
    value = value.trim();
    return value.isEmpty ? null : value;
  }

  String? _pruneTemporalSuffix(String? raw) {
    if (raw == null) return null;
    var working = raw.trim();
    if (working.isEmpty) return null;
    bool trimmedTemporal = false;
    while (working.isNotEmpty && _looksTemporalPhrase(working)) {
      trimmedTemporal = true;
      final lastSpace = working.lastIndexOf(' ');
      if (lastSpace == -1) {
        return null;
      }
      working = working.substring(0, lastSpace).trim();
    }
    if (working.isEmpty) return null;
    if (trimmedTemporal &&
        RegExp(r'^\d{1,3}(?:st|nd|rd|th)?$').hasMatch(working.toLowerCase())) {
      return null;
    }
    return working;
  }

  bool _looksTemporalPhrase(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('today') ||
        lower.contains('tonight') ||
        lower.contains('tomorrow') ||
        lower.contains('yesterday')) {
      return true;
    }
    if (lower.contains('this time ')) {
      return true;
    }
    if (RegExp(
            r'\bthis\s+(time|morning|afternoon|evening|night|week|weekend|month|year)\b')
        .hasMatch(lower)) {
      return true;
    }
    if (RegExp(
            r'\bnext\s+(week|weekend|month|year|mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun'
            r'|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\b')
        .hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\b\d{1,2}(:\d{2})?\s*(?:a\.?m\.?|p\.?m\.?|am|pm)\b')
        .hasMatch(lower)) {
      return true;
    }
    if (RegExp(r'\b\d+\s+(minute|hour|day|week|month|year)s?\b')
        .hasMatch(lower)) {
      return true;
    }
    return false;
  }

  bool _looksLikeHandle(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (trimmed.contains(' ')) return false;
    if (trimmed.contains('.')) return true;
    if (trimmed.contains('@')) return true;
    if (trimmed.startsWith('#')) return true;
    if (trimmed.length <= 2) return true;
    final hasDigits = RegExp(r'\d').hasMatch(trimmed);
    final isAlphaNum =
        RegExp(r'^[a-z0-9_\-]+$', caseSensitive: false).hasMatch(trimmed);
    if (!hasDigits && isAlphaNum && trimmed.length <= 20) {
      return true;
    }
    return false;
  }

  String _clean(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[ ,.;]+$'), '');

  String _removeSpanByIndex(String s, int index, int length) {
    if (index < 0 || index + length > s.length) return s;

    bool isLetter(int codeUnit) {
      return (codeUnit >= 65 && codeUnit <= 90) ||
          (codeUnit >= 97 && codeUnit <= 122);
    }

    bool isWhitespace(int codeUnit) => codeUnit <= 32;

    var start = index;
    var end = index + length;

    // Consume trailing whitespace to avoid leaving double spaces.
    while (end < s.length && isWhitespace(s.codeUnitAt(end))) {
      end++;
    }

    // Step back to include whitespace between the matched phrase and
    // any connector words we may choose to remove below.
    while (start > 0 && isWhitespace(s.codeUnitAt(start - 1))) {
      start--;
    }

    var cursor = start;
    while (cursor > 0) {
      var wordEnd = cursor;
      // Skip whitespace directly before the current cursor.
      while (wordEnd > 0 && isWhitespace(s.codeUnitAt(wordEnd - 1))) {
        wordEnd--;
      }
      if (wordEnd == 0) break;

      var wordStart = wordEnd;
      while (wordStart > 0 && isLetter(s.codeUnitAt(wordStart - 1))) {
        wordStart--;
      }
      if (wordStart == wordEnd) {
        break;
      }

      final word = s.substring(wordStart, wordEnd).toLowerCase();
      if (!_metadataConnectorWords.contains(word)) {
        break;
      }

      start = wordStart;
      cursor = wordStart;
    }

    return s.replaceRange(start, end, ' ');
  }

  String _hhmm(int hour) =>
      DateFormat('HH:mm').format(DateTime(2000, 1, 1, hour));

  tz.TZDateTime _startOfWeekend(
      tz.TZDateTime base, int weekendDefaultDay, bool addAWeek) {
    final startOfDay =
        tz.TZDateTime(opts.tzLocation, base.year, base.month, base.day);
    int goal = weekendDefaultDay;
    int delta = (goal - startOfDay.weekday + 7) % 7;
    if (addAWeek || delta == 0) delta += 7;
    return tz.TZDateTime(opts.tzLocation, startOfDay.year, startOfDay.month,
        startOfDay.day + delta, opts.policy.defaultMorningHour);
  }
}

class _ExplicitRange {
  const _ExplicitRange({this.start, this.end, required this.raw});

  final _ClockToken? start;
  final _ClockToken? end;
  final String raw;
}

_ExplicitRange? _extractExplicitRange(String text) {
  final patterns = <RegExp>[
    RegExp(
      '\\bfrom\\s+(?<start>$_timeSnippetPattern)\\s+(?:to|till|til|until|through)\\s+(?<end>$_timeSnippetPattern)',
      caseSensitive: false,
    ),
    RegExp(
      '\\b(?<start>$_timeSnippetPattern)\\s+(?:to|till|til|until|through)\\s+(?<end>$_timeSnippetPattern)',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final startRaw = match.namedGroup('start');
    final endRaw = match.namedGroup('end');
    final _ClockToken? startToken =
        startRaw != null ? _parseClockToken(startRaw) : null;
    final _ClockToken? endToken =
        endRaw != null ? _parseClockToken(endRaw) : null;
    if (startToken == null && endToken == null) continue;
    return _ExplicitRange(
        start: startToken, end: endToken, raw: match.group(0)!);
  }
  return null;
}

class _ClockToken {
  const _ClockToken({
    required this.hour,
    required this.minute,
    required this.hasMeridiem,
    required this.isPm,
    required this.isAm,
    required this.was24Hour,
  });

  final int hour;
  final int minute;
  final bool hasMeridiem;
  final bool isPm;
  final bool isAm;
  final bool was24Hour;
}

_ClockToken? _parseClockToken(String raw) {
  var value = raw.trim().toLowerCase();
  if (value.isEmpty) return null;
  if (value.contains('noon')) {
    return const _ClockToken(
      hour: 12,
      minute: 0,
      hasMeridiem: true,
      isPm: true,
      isAm: false,
      was24Hour: false,
    );
  }
  if (value.contains('midnight')) {
    return const _ClockToken(
      hour: 0,
      minute: 0,
      hasMeridiem: true,
      isPm: false,
      isAm: true,
      was24Hour: false,
    );
  }

  final bool isPm =
      RegExp(r'p\.?m\.?|\bpm\b', caseSensitive: false).hasMatch(value);
  final bool isAm =
      RegExp(r'a\.?m\.?|\bam\b', caseSensitive: false).hasMatch(value);
  final bool hasMeridiem = isPm || isAm;
  value =
      value.replaceAll(RegExp(r'p\.?m\.?|a\.?m\.?|\bpm\b|\bam\b'), ' ').trim();
  value = value.replaceFirst(RegExp(r'^(at|around)\s+'), '');

  int? hour;
  int minute = 0;
  bool was24Hour = false;

  final colon = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(value);
  if (colon != null) {
    hour = int.tryParse(colon.group(1)!);
    minute = int.tryParse(colon.group(2)!) ?? 0;
  } else {
    final hNotation = RegExp(r'(\d{1,2})\s*h\s*(\d{1,2})?').firstMatch(value);
    if (hNotation != null) {
      hour = int.tryParse(hNotation.group(1)!);
      minute = int.tryParse(hNotation.group(2) ?? '0') ?? 0;
      was24Hour = true;
    } else {
      final tight = RegExp(r'(\d{1,2})h(\d{1,2})?').firstMatch(value);
      if (tight != null) {
        hour = int.tryParse(tight.group(1)!);
        minute = int.tryParse(tight.group(2) ?? '0') ?? 0;
        was24Hour = true;
      } else {
        final lone = RegExp(r'\b(\d{1,2})\b').firstMatch(value);
        if (lone != null) {
          hour = int.tryParse(lone.group(1)!);
        }
      }
    }
  }

  if (hour == null || hour > 23) return null;
  if (minute < 0 || minute > 59) return null;
  if (!hasMeridiem && hour >= 13) {
    was24Hour = true;
  }
  return _ClockToken(
    hour: hour,
    minute: minute,
    hasMeridiem: hasMeridiem,
    isPm: isPm,
    isAm: isAm,
    was24Hour: was24Hour,
  );
}

tz.TZDateTime _materializeClockToken(
  _ClockToken token,
  tz.TZDateTime anchor, {
  tz.TZDateTime? reference,
  tz.Location? location,
}) {
  final tz.Location loc = location ?? anchor.location;
  int hour = token.hour;
  if (token.hasMeridiem) {
    if (token.isPm && hour < 12) hour += 12;
    if (token.isAm && hour == 12) hour = 0;
  }
  var candidate = tz.TZDateTime(
      loc, anchor.year, anchor.month, anchor.day, hour, token.minute);
  if (reference != null) {
    if (!token.hasMeridiem &&
        !token.was24Hour &&
        candidate.isBefore(reference)) {
      if (reference.hour >= 12 && candidate.hour < 12) {
        candidate = candidate.add(const Duration(hours: 12));
      }
      if (candidate.isBefore(reference)) {
        candidate = candidate.add(const Duration(days: 1));
      }
    } else if (candidate.isBefore(reference)) {
      candidate = candidate.add(const Duration(days: 1));
    }
  }
  return candidate;
}

/// ------------------- Duration helpers (top-level) -------------------

class _DurationExtraction {
  const _DurationExtraction({
    required this.duration,
    required this.cleaned,
    required this.phrase,
  });

  final Duration duration;
  final String cleaned;
  final String phrase;
}

_DurationExtraction? _extractDurationPhrase(String text) {
  final List<RegExp> patterns = [
    RegExp(
      r'\b(?:for|lasting|lasts?|runs?|running|going)(?:\s+for)?\s+'
      r'(?<value>half|quarter|an|a|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen|\d+(?:\.\d+)?)\s*'
      r'(?<unit>hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec|days?|day|weeks?|week)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?<value>half|quarter|an|a|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|couple|few|several|dozen|\d+(?:\.\d+)?)\s*'
      r'(?<unit>hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec|days?|day|weeks?|week)\s+'
      r'(?:long|duration|straight)\b',
      caseSensitive: false,
    ),
    RegExp(
      r'\b(?<value>\d+(?:\.\d+)?)\s*'
      r'(?<unit>hours?|hrs?|hr|minutes?|mins?|min|seconds?|secs?|sec|days?|day|weeks?|week)\s*'
      r'(?:session|meeting|event)\b',
      caseSensitive: false,
    ),
  ];

  for (final pattern in patterns) {
    final match = pattern.firstMatch(text);
    if (match == null) continue;
    final Duration? duration = _durationFromCapture(
      match.namedGroup('value'),
      match.namedGroup('unit'),
    );
    if (duration == null) continue;
    final String cleaned = text.replaceRange(match.start, match.end, ' ');
    final String phrase = text.substring(match.start, match.end).trim();
    return _DurationExtraction(
      duration: duration,
      cleaned: cleaned,
      phrase: phrase,
    );
  }

  final RegExp composite = RegExp(
    r'\b(?<hours>\d+(?:\.\d+)?)\s*h(?:ours?|rs?)?'
    r'(?:\s*(?<minutes>\d+(?:\.\d+)?)\s*m(?:in(?:utes?)?)?)?\b',
    caseSensitive: false,
  );
  final compositeMatch = composite.firstMatch(text);
  if (compositeMatch != null) {
    final double hours =
        double.parse(compositeMatch.namedGroup('hours') ?? '0');
    final double minutes =
        double.parse(compositeMatch.namedGroup('minutes') ?? '0');
    final Duration duration =
        Duration(minutes: ((hours * 60) + minutes).round());
    if (duration.inMinutes > 0) {
      final cleaned =
          text.replaceRange(compositeMatch.start, compositeMatch.end, ' ');
      final phrase =
          text.substring(compositeMatch.start, compositeMatch.end).trim();
      return _DurationExtraction(
        duration: duration,
        cleaned: cleaned,
        phrase: phrase,
      );
    }
  }

  final RegExp tightComposite = RegExp(
    r'\b(?<hours>\d+)h(?<minutes>\d{1,2})m?\b',
    caseSensitive: false,
  );
  final tightMatch = tightComposite.firstMatch(text);
  if (tightMatch != null) {
    final int hours = int.parse(tightMatch.namedGroup('hours')!);
    final int minutes = int.parse(tightMatch.namedGroup('minutes')!);
    final Duration duration = Duration(minutes: hours * 60 + minutes);
    if (duration.inMinutes > 0) {
      final cleaned = text.replaceRange(tightMatch.start, tightMatch.end, ' ');
      final phrase = text.substring(tightMatch.start, tightMatch.end).trim();
      return _DurationExtraction(
        duration: duration,
        cleaned: cleaned,
        phrase: phrase,
      );
    }
  }

  final RegExp bare = RegExp(
    r'\b(?<value>half|quarter|an|a|one|two|three|four|five|six|seven|eight|nine|ten|eleven|twelve|\d+(?:\.\d+)?)\s*'
    r'(?<unit>h|hr|hrs|hour|hours|m|min|mins|minute|minutes|day|days|week|weeks)\b',
    caseSensitive: false,
  );
  final bareMatch = bare.firstMatch(text);
  if (bareMatch != null) {
    final prefix = text.substring(0, bareMatch.start);
    if (!RegExp(r'\bin\s*$', caseSensitive: false).hasMatch(prefix)) {
      final Duration? duration = _durationFromCapture(
        bareMatch.namedGroup('value'),
        bareMatch.namedGroup('unit'),
      );
      if (duration != null) {
        final cleaned = text.replaceRange(bareMatch.start, bareMatch.end, ' ');
        final phrase = text.substring(bareMatch.start, bareMatch.end).trim();
        return _DurationExtraction(
          duration: duration,
          cleaned: cleaned,
          phrase: phrase,
        );
      }
    }
  }

  return null;
}

Duration? _durationFromCapture(String? rawValue, String? rawUnit) {
  if (rawValue == null || rawUnit == null) return null;
  final double? numericValue = _parseDurationValue(rawValue);
  if (numericValue == null) return null;
  return _durationFromUnitAmount(numericValue, rawUnit);
}

Duration? _durationFromUnitAmount(double amount, String unit) {
  final String normalized = unit.toLowerCase();
  double minutes;
  if (normalized.startsWith('hour') ||
      normalized.startsWith('hr') ||
      normalized == 'h') {
    minutes = amount * 60;
  } else if (normalized.startsWith('min') || normalized == 'm') {
    minutes = amount;
  } else if (normalized.startsWith('sec')) {
    minutes = amount / 60;
  } else if (normalized.startsWith('day')) {
    minutes = amount * 1440;
  } else if (normalized.startsWith('week')) {
    minutes = amount * 10080;
  } else {
    return null;
  }
  final int rounded = minutes.round();
  if (rounded <= 0) return null;
  return Duration(minutes: rounded);
}

double? _parseDurationValue(String raw) {
  final String value = raw.toLowerCase().trim();
  if (value == 'half') return 0.5;
  if (value == 'quarter') return 0.25;
  if (value == 'an' || value == 'a' || value == 'one') return 1;
  const Map<String, double> words = {
    'two': 2,
    'three': 3,
    'four': 4,
    'five': 5,
    'six': 6,
    'seven': 7,
    'eight': 8,
    'nine': 9,
    'ten': 10,
    'eleven': 11,
    'twelve': 12,
    'couple': 2,
    'few': 3,
    'several': 4,
    'dozen': 12,
  };
  if (words.containsKey(value)) {
    return words[value];
  }
  return double.tryParse(value);
}

String _formatDuration(Duration duration) {
  final int totalMinutes = duration.inMinutes;
  final int hours = totalMinutes ~/ 60;
  final int minutes = totalMinutes % 60;
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  if (minutes > 0) {
    return '${minutes}m';
  }
  final int seconds = duration.inSeconds;
  return '${seconds}s';
}

class _ManualFallbackResult {
  const _ManualFallbackResult({
    required this.start,
    required this.allDay,
    required this.cleanedText,
    required this.assumptions,
    required this.flags,
  });

  final tz.TZDateTime start;
  final bool allDay;
  final String cleanedText;
  final List<String> assumptions;
  final Set<AmbiguityFlag> flags;
}

class _ConsumedPhraseTracker {
  final Set<String> _phrases = <String>{};

  bool add(String? raw) {
    final normalized = _normalize(raw);
    if (normalized == null) return false;
    return _phrases.add(normalized);
  }

  bool overlaps(String? raw) {
    final normalized = _normalize(raw);
    if (normalized == null) return false;
    for (final phrase in _phrases) {
      if (phrase.contains(normalized) || normalized.contains(phrase)) {
        return true;
      }
    }
    return false;
  }

  Iterable<String> get phrases => _phrases;

  String? _normalize(String? raw) {
    if (raw == null) return null;
    var value = raw.trim().toLowerCase();
    if (value.isEmpty) return null;
    value = value.replaceAll(RegExp(r'\s+'), ' ');
    value = value.replaceAll(RegExp(r'[,.:;!\/\\-]+$'), '').trim();
    return value.isEmpty ? null : value;
  }
}

class _Normalized {
  final String text;
  final Set<AmbiguityFlag> flags;
  final List<String> assumptions;
  final bool correctedTypos;
  final tz.TZDateTime? relativeFallback;
  final String? relativeFallbackLabel;

  _Normalized({
    required this.text,
    required this.flags,
    required this.assumptions,
    required this.correctedTypos,
    required this.relativeFallback,
    required this.relativeFallbackLabel,
  });
}

class _Vague {
  final String hit;
  final int hour;
  final bool isTonight;
  final bool overrideDateOnly = false;
  _Vague(this.hit, this.hour, {this.isTonight = false});
}

class _DeadlineParse {
  final String cleaned;
  final tz.TZDateTime? deadline;
  final Set<AmbiguityFlag> flags;
  final List<String> assumptions;

  _DeadlineParse(this.cleaned, this.deadline, this.flags, this.assumptions);
}

class _RecurrenceParse {
  final String cleaned;
  final Recurrence? recurrence;

  _RecurrenceParse(this.cleaned, this.recurrence);
}

class _PriorityResult {
  final PriorityQuadrant quadrant;
  final List<String> assumptions;
  final Set<String> triggerTokens;

  _PriorityResult(this.quadrant, this.assumptions, this.triggerTokens);
}

class _RecurrenceSpec {
  const _RecurrenceSpec({
    required this.frequency,
    required this.interval,
    required this.byWeekdays,
    required this.byMonthDay,
    required this.bySetPos,
    required this.location,
  });

  final _RecurrenceFrequency frequency;
  final int interval;
  final List<int> byWeekdays;
  final int? byMonthDay;
  final int? bySetPos;
  final tz.Location location;
}

enum _RecurrenceFrequency { daily, weekly, monthly, yearly }

class _RecurrenceMath {
  static const int _maxIterations = 5000;

  static _RecurrenceSpec? tryParse(
      Recurrence recurrence, tz.Location location) {
    final Map<String, String> fields = {};
    for (final token in recurrence.rrule.split(';')) {
      final idx = token.indexOf('=');
      if (idx <= 0) continue;
      fields[token.substring(0, idx).toUpperCase()] = token.substring(idx + 1);
    }
    final freqRaw = fields['FREQ'];
    if (freqRaw == null) return null;
    final _RecurrenceFrequency? frequency = switch (freqRaw.toUpperCase()) {
      'DAILY' => _RecurrenceFrequency.daily,
      'WEEKLY' => _RecurrenceFrequency.weekly,
      'MONTHLY' => _RecurrenceFrequency.monthly,
      'YEARLY' => _RecurrenceFrequency.yearly,
      _ => null,
    };
    if (frequency == null) return null;
    final interval =
        (int.tryParse(fields['INTERVAL'] ?? '1') ?? 1).clamp(1, 1000);
    final List<int> byWeekdays = [];
    final byDayRaw = fields['BYDAY'];
    if (byDayRaw != null && byDayRaw.isNotEmpty) {
      for (final token in byDayRaw.split(',')) {
        final weekday = _weekdayFromIcs(token.trim());
        if (weekday != null && !byWeekdays.contains(weekday)) {
          byWeekdays.add(weekday);
        }
      }
    }
    final int? byMonthDay = int.tryParse(fields['BYMONTHDAY'] ?? '');
    final int? bySetPos = int.tryParse(fields['BYSETPOS'] ?? '');

    return _RecurrenceSpec(
      frequency: frequency,
      interval: interval,
      byWeekdays: byWeekdays,
      byMonthDay: byMonthDay,
      bySetPos: bySetPos,
      location: location,
    );
  }

  static tz.TZDateTime? computeUntilFromCount(
    tz.TZDateTime start,
    _RecurrenceSpec spec,
    int count,
  ) {
    if (count <= 1) return start;
    var current = start;
    var produced = 1;
    while (produced < count && produced < _maxIterations) {
      final next = _nextOccurrence(current, spec);
      if (next == null) return current;
      current = next;
      produced++;
    }
    return current;
  }

  static int? computeCountFromUntil(
    tz.TZDateTime start,
    _RecurrenceSpec spec,
    tz.TZDateTime until,
  ) {
    if (until.isBefore(start)) return 1;
    var current = start;
    var count = 1;
    while (count < _maxIterations) {
      final next = _nextOccurrence(current, spec);
      if (next == null) break;
      if (next.isAfter(until)) {
        break;
      }
      count++;
      current = next;
      if (!next.isBefore(until)) {
        break;
      }
    }
    return count;
  }

  static tz.TZDateTime? _nextOccurrence(
    tz.TZDateTime current,
    _RecurrenceSpec spec,
  ) {
    switch (spec.frequency) {
      case _RecurrenceFrequency.daily:
        return current.add(Duration(days: spec.interval));
      case _RecurrenceFrequency.weekly:
        return _advanceWeekly(current, spec);
      case _RecurrenceFrequency.monthly:
        return _advanceMonthly(current, spec);
      case _RecurrenceFrequency.yearly:
        return _advanceYearly(current, spec);
    }
  }

  static tz.TZDateTime alignStart(
    tz.TZDateTime candidate,
    _RecurrenceSpec spec,
  ) {
    if (_matchesSpec(candidate, spec)) return candidate;
    var probe = candidate;
    for (var i = 0; i < _maxIterations; i++) {
      final next = _nextOccurrence(probe, spec);
      if (next == null) break;
      if (_matchesSpec(next, spec)) return next;
      probe = next;
    }
    return candidate;
  }

  static bool _matchesSpec(tz.TZDateTime dt, _RecurrenceSpec spec) {
    switch (spec.frequency) {
      case _RecurrenceFrequency.daily:
        return true;
      case _RecurrenceFrequency.weekly:
        if (spec.byWeekdays.isEmpty) return true;
        return spec.byWeekdays.contains(dt.weekday);
      case _RecurrenceFrequency.monthly:
        if (spec.byMonthDay != null) {
          return dt.day == spec.byMonthDay;
        }
        if (spec.bySetPos != null && spec.byWeekdays.isNotEmpty) {
          final tz.TZDateTime target = _nthWeekdayOfMonth(
            dt.location,
            dt.year,
            dt.month,
            spec.byWeekdays.first,
            spec.bySetPos!,
          );
          return dt.year == target.year &&
              dt.month == target.month &&
              dt.day == target.day;
        }
        return true;
      case _RecurrenceFrequency.yearly:
        if (spec.byMonthDay != null) {
          return dt.day == spec.byMonthDay;
        }
        if (spec.bySetPos != null && spec.byWeekdays.isNotEmpty) {
          final tz.TZDateTime target = _nthWeekdayOfMonth(
            dt.location,
            dt.year,
            dt.month,
            spec.byWeekdays.first,
            spec.bySetPos!,
          );
          return dt.year == target.year &&
              dt.month == target.month &&
              dt.day == target.day;
        }
        return true;
    }
  }

  static tz.TZDateTime _advanceWeekly(
    tz.TZDateTime current,
    _RecurrenceSpec spec,
  ) {
    final List<int> targets = List<int>.from(
        spec.byWeekdays.isEmpty ? [current.weekday] : spec.byWeekdays)
      ..sort();
    for (final day in targets) {
      if (day > current.weekday) {
        final delta = day - current.weekday;
        return current.add(Duration(days: delta));
      }
    }
    final int loopStart = targets.isEmpty ? current.weekday : targets.first;
    final int daysUntilNextCycle =
        spec.interval * 7 - (current.weekday - loopStart);
    return current.add(Duration(days: daysUntilNextCycle));
  }

  static tz.TZDateTime _advanceMonthly(
    tz.TZDateTime current,
    _RecurrenceSpec spec,
  ) {
    final tz.TZDateTime monthAnchor = tz.TZDateTime(
      current.location,
      current.year,
      current.month + spec.interval,
      1,
      current.hour,
      current.minute,
      current.second,
    );
    if (spec.byMonthDay != null) {
      final int day = spec.byMonthDay!.clamp(
        1,
        _daysInMonth(monthAnchor.year, monthAnchor.month),
      );
      return tz.TZDateTime(
        current.location,
        monthAnchor.year,
        monthAnchor.month,
        day,
        current.hour,
        current.minute,
        current.second,
      );
    }
    if (spec.bySetPos != null && spec.byWeekdays.isNotEmpty) {
      final tz.TZDateTime target = _nthWeekdayOfMonth(
        current.location,
        monthAnchor.year,
        monthAnchor.month,
        spec.byWeekdays.first,
        spec.bySetPos!,
      );
      return tz.TZDateTime(
        current.location,
        target.year,
        target.month,
        target.day,
        current.hour,
        current.minute,
        current.second,
      );
    }
    final int day = current.day.clamp(
      1,
      _daysInMonth(monthAnchor.year, monthAnchor.month),
    );
    return tz.TZDateTime(
      current.location,
      monthAnchor.year,
      monthAnchor.month,
      day,
      current.hour,
      current.minute,
      current.second,
    );
  }

  static tz.TZDateTime _advanceYearly(
    tz.TZDateTime current,
    _RecurrenceSpec spec,
  ) {
    final tz.TZDateTime yearAnchor = tz.TZDateTime(
      current.location,
      current.year + spec.interval,
      current.month,
      1,
      current.hour,
      current.minute,
      current.second,
    );
    if (spec.byMonthDay != null) {
      final int day = spec.byMonthDay!.clamp(
        1,
        _daysInMonth(yearAnchor.year, current.month),
      );
      return tz.TZDateTime(
        current.location,
        yearAnchor.year,
        current.month,
        day,
        current.hour,
        current.minute,
        current.second,
      );
    }
    if (spec.bySetPos != null && spec.byWeekdays.isNotEmpty) {
      final tz.TZDateTime target = _nthWeekdayOfMonth(
        current.location,
        yearAnchor.year,
        current.month,
        spec.byWeekdays.first,
        spec.bySetPos!,
      );
      return tz.TZDateTime(
        current.location,
        target.year,
        target.month,
        target.day,
        current.hour,
        current.minute,
        current.second,
      );
    }
    final int day = current.day.clamp(
      1,
      _daysInMonth(yearAnchor.year, current.month),
    );
    return tz.TZDateTime(
      current.location,
      yearAnchor.year,
      current.month,
      day,
      current.hour,
      current.minute,
      current.second,
    );
  }

  static tz.TZDateTime _nthWeekdayOfMonth(
    tz.Location location,
    int year,
    int month,
    int weekday,
    int setpos,
  ) {
    final int daysInMonth = _daysInMonth(year, month);
    if (setpos >= 1) {
      var count = 0;
      for (int day = 1; day <= daysInMonth; day++) {
        final candidate = tz.TZDateTime(location, year, month, day);
        if (candidate.weekday == weekday) {
          count++;
          if (count == setpos) return candidate;
        }
      }
      return tz.TZDateTime(location, year, month, daysInMonth);
    } else {
      var count = 0;
      for (int day = daysInMonth; day >= 1; day--) {
        final candidate = tz.TZDateTime(location, year, month, day);
        if (candidate.weekday == weekday) {
          count++;
          if (count == -setpos) return candidate;
        }
      }
      return tz.TZDateTime(location, year, month, daysInMonth);
    }
  }

  static int _daysInMonth(int year, int month) {
    final nextMonth =
        month == 12 ? DateTime(year + 1, 1, 1) : DateTime(year, month + 1, 1);
    final lastDay = nextMonth.subtract(const Duration(days: 1));
    return lastDay.day;
  }

  static int? _weekdayFromIcs(String token) {
    final match = RegExp(r'(MO|TU|WE|TH|FR|SA|SU)', caseSensitive: false)
        .firstMatch(token.toUpperCase());
    if (match == null) return null;
    return switch (match.group(1)) {
      'MO' => DateTime.monday,
      'TU' => DateTime.tuesday,
      'WE' => DateTime.wednesday,
      'TH' => DateTime.thursday,
      'FR' => DateTime.friday,
      'SA' => DateTime.saturday,
      'SU' => DateTime.sunday,
      _ => null,
    };
  }
}
