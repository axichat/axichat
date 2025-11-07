// schedule_parser.dart
import 'package:chrono_dart/chrono_dart.dart'
    show Chrono, ParsingOption, ParsingReference, Component, ParsedResult;
import 'package:timezone/timezone.dart' as tz;
import 'package:intl/intl.dart';

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
  final List<String> trailingLocationHints;

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
    this.trailingLocationHints = const [
      'office',
      'home',
      'cafe',
      'coffee',
      'restaurant',
      'diner',
      'gym',
      'airport',
      'station',
      'park',
      'campus',
      'library',
      'clinic',
      'bank',
      'mall',
      'court',
      'hotel',
      'zoom',
      'teams',
      'meet'
    ],
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
      'today',
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
    var s = ' ${normal.text} '; // working text buffer
    final flags = <AmbiguityFlag>{...normal.flags};
    final assumptions = <String>[...normal.assumptions];
    var confidence = 1.0;

    // DEADLINE: extract and strip from sentence
    final _DeadlineParse dl = _extractDeadline(s, base);
    s = ' ${dl.cleaned} ';
    tz.TZDateTime? deadline = dl.deadline;
    flags.addAll(dl.flags);
    assumptions.addAll(dl.assumptions);

    // RECURRENCE: strip triggers but keep anchor words like "Friday 10"
    final _RecurrenceParse rec = _parseRecurrence(s, base);
    s = ' ${rec.cleaned} ';
    if (rec.recurrence != null) {
      assumptions.add('Recurrence: ${rec.recurrence!.rrule}');
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
      s = _removeSpanByIndex(
        s,
        best.index?.toInt() ?? 0,
        best.text.length,
      );
    } else {
      // Use relative fallback from normalization ("in N days/hours")
      if (normal.relativeFallback != null) {
        start = normal.relativeFallback;
        allDay = false;
        flags.add(AmbiguityFlag.relativeDate);
        assumptions.add(
            'Interpreted relative duration "${normal.relativeFallbackLabel}".');
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
    }

    // Weekend shorthand
    if (RegExp(r'\b(this|next)?\s*weekend\b', caseSensitive: false)
        .hasMatch(original)) {
      flags.add(AmbiguityFlag.relativeDate);
      final addAWeek =
          RegExp(r'\bnext weekend\b', caseSensitive: false).hasMatch(original);
      final sat =
          _startOfWeekend(base, opts.policy.weekendDefaultDay, addAWeek);
      start ??= sat;
      if (allDay) allDay = false;
      assumptions.add(
          'Interpreted "weekend" as ${DateFormat('EEE HH:mm').format(start)}.');
      confidence -= 0.1;
    }

    // Approximate "ish"/"around"
    bool approximate = false;
    if (RegExp(r'\bish\b|\baround\b', caseSensitive: false)
            .hasMatch(original) &&
        start != null) {
      approximate = true;
      flags.add(AmbiguityFlag.approximateTime);
      assumptions.add('Time marked approximate ("ish"/"around").');
      confidence -= 0.05;
    }

    // Location: at/in/to …, @ …, or trailing hint
    String? location;
    final atInTo = RegExp(
      r'\b(?:at|in|to)\s+(?:the\s+)?(?<loc>(?!\d{1,2}(:\d{2})?\s*(?:am|pm)\b)[^,.;]+?)'
      r'(?=(?:\s+(?:with|on|for|by|at|in|to)\b|[,.;]|$))',
      caseSensitive: false,
    ).firstMatch(s);
    if (atInTo != null) {
      location = _clean(atInTo.namedGroup('loc')!);
      s = s.replaceRange(atInTo.start, atInTo.end, ' ');
    } else if (opts.policy.allowAtSignLocation) {
      final atSig = RegExp(r"\B@\s*([A-Za-z0-9#&+\-' ]{2,})").firstMatch(s);
      if (atSig != null) {
        location = _clean(atSig.group(1)!);
        flags.add(AmbiguityFlag.locationGuessed);
        assumptions.add('Used "@ …" as location.');
        s = s.replaceRange(atSig.start, atSig.end, ' ');
      }
    }
    if (location == null) {
      final trailing = RegExp(r"([A-Za-z][A-Za-z0-9'&+\- ]{2,})\s*$")
          .firstMatch(s.trimRight());
      if (trailing != null) {
        final word = trailing.group(1)!.trim().toLowerCase();
        if (opts.policy.trailingLocationHints.contains(word)) {
          location = _clean(word);
          flags.add(AmbiguityFlag.locationGuessed);
          assumptions.add('Guessed trailing word as location.');
          s = s.replaceRange(trailing.start, trailing.end, ' ');
        }
      }
    }

    // Participants
    final participants = <String>[];
    for (final pat in [
      RegExp(r'\bwith\s+([^,.;]+)', caseSensitive: false),
      RegExp(r'\binvite\s+([^,.;]+)', caseSensitive: false),
      RegExp(r'\bw\/\s*([^,.;]+)', caseSensitive: false),
    ]) {
      final m = pat.firstMatch(s);
      if (m != null) {
        participants.addAll(_splitNames(_clean(m.group(1)!)));
      }
    }

    // Time range 3-4, 3–4pm, etc.
    tz.TZDateTime? end;
    if (start != null) {
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

    // Title cleanup
    var title = s
        .replaceAll(RegExp(r'\b(on|at|in|to)\b', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (title.isEmpty) title = original;

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

    // Priority (Eisenhower)
    final _PriorityResult pr = _parsePriority(
      original: original,
      base: base,
      start: start,
      policy: opts.policy,
    );

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
      recurrence: rec.recurrence,
      deadline: deadline,
    );
  }

  /// ------------------- Helpers -------------------

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
            r'\bin\s+(\d+)\s+(minute|minutes|hour|hours|day|days|week|weeks)\b',
            caseSensitive: false)
        .firstMatch(s);
    if (rel != null) {
      final n = int.parse(rel.group(1)!);
      final unit = rel.group(2)!.toLowerCase();
      if (unit.startsWith('minute')) {
        relative = base.add(Duration(minutes: n));
      } else if (unit.startsWith('hour')) {
        relative = base.add(Duration(hours: n));
      } else if (unit.startsWith('day')) {
        relative = base.add(Duration(days: n));
      } else {
        relative = base.add(Duration(days: n * 7));
      }
      relativeLabel = rel.group(0)!;
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

    tz.TZDateTime _eod(tz.TZDateTime d) => tz.TZDateTime(
        opts.tzLocation, d.year, d.month, d.day, opts.policy.endOfDayHour);

    // Explicit phrases: by/before/no later than/due
    final m = RegExp(
      r'\b(?:by|before|no\s+later\s+than|not\s+later\s+than|due(?:\s+(?:on|by))?|deadline(?:\s*(?:is|:))?)\s+([^,.;]+)',
      caseSensitive: false,
    ).firstMatch(text);

    if (m != null) {
      final st = m.start, en = m.end;
      final target = m.group(1)!.trim();

      final ref =
          ParsingReference(instant: base.toUtc(), timezone: opts.tzName);
      final rs = Chrono.parse(' $target ',
          ref: ref, option: ParsingOption(forwardDate: true));
      if (rs.isNotEmpty) {
        var dt = tz.TZDateTime.from(rs.last.date(), opts.tzLocation);
        final hadTime = rs.last.start.isCertain(Component.hour);
        if (!hadTime) dt = _eod(dt);
        deadline = dt;
        flags.add(AmbiguityFlag.deadline);
        assumptions.add(
            'Interpreted "${m.group(0)}" as deadline ${dt.toIso8601String()}.');
      }

      text = (text.substring(0, st) + ' ' + text.substring(en))
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
        text = (text.substring(0, st) + ' ' + text.substring(en))
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }
    }

    return _DeadlineParse(text, deadline, flags, assumptions);
  }

  _RecurrenceParse _parseRecurrence(String s, tz.TZDateTime base) {
    String lower = s.toLowerCase();

    final hasTrigger = RegExp(
            r'\b(every|each|daily|weekly|monthly|yearly|annually|biweekly|weekdays|weekends|mwf|tth)\b')
        .hasMatch(lower);
    if (!hasTrigger) return _RecurrenceParse(s, null);

    final span = RegExp(
      r'\b(?:every|each|daily|weekly|monthly|yearly|annually|biweekly|weekdays|weekends|mwf|tth)\b[^,.;]*',
      caseSensitive: false,
    ).firstMatch(s);
    if (span == null) return _RecurrenceParse(s, null);

    final phrase = s.substring(span.start, span.end).trim();

    String freq = '';
    int interval = 1;
    List<String> byday = [];
    int? bymonthday;
    int? bysetpos;
    tz.TZDateTime? until;
    int? count;

    String _dowToIcs(String w) {
      final w0 = w.toLowerCase();
      if (w0.startsWith('mo')) return 'MO';
      if (w0.startsWith('tu')) return 'TU';
      if (w0.startsWith('we')) return 'WE';
      if (w0.startsWith('th')) return 'TH';
      if (w0.startsWith('fr')) return 'FR';
      if (w0.startsWith('sa')) return 'SA';
      return 'SU';
    }

    void _ensureWeekly() {
      if (freq.isEmpty) freq = 'WEEKLY';
    }

    if (RegExp(r'\bdaily\b').hasMatch(phrase)) freq = 'DAILY';
    if (RegExp(r'\bweekly\b').hasMatch(phrase)) freq = 'WEEKLY';
    if (RegExp(r'\bbiweekly\b').hasMatch(phrase)) {
      freq = 'WEEKLY';
      interval = 2;
    }
    if (RegExp(r'\bmonthly\b').hasMatch(phrase)) freq = 'MONTHLY';
    if (RegExp(r'\byearly\b|\bannually\b').hasMatch(phrase)) freq = 'YEARLY';

    final mEveryN =
        RegExp(r'\b(?:every|each)\s+(other|\d+)\b').firstMatch(phrase);
    if (mEveryN != null) {
      if (mEveryN.group(1)!.toLowerCase() == 'other')
        interval = 2;
      else
        interval = int.tryParse(mEveryN.group(1)!) ?? 1;
    }
    final mEveryNUnits = RegExp(
            r'\b(?:every|each)\s+(\d+)\s+(day|days|week|weeks|month|months|year|years)\b')
        .firstMatch(phrase);
    if (mEveryNUnits != null) {
      final n = int.parse(mEveryNUnits.group(1)!);
      final unit = mEveryNUnits.group(2)!.toLowerCase();
      interval = n;
      if (unit.startsWith('day'))
        freq = 'DAILY';
      else if (unit.startsWith('week'))
        freq = 'WEEKLY';
      else if (unit.startsWith('month'))
        freq = 'MONTHLY';
      else
        freq = 'YEARLY';
    }

    if (RegExp(r'\bweekdays\b').hasMatch(phrase)) {
      _ensureWeekly();
      byday = ['MO', 'TU', 'WE', 'TH', 'FR'];
    }
    if (RegExp(r'\bweekends\b').hasMatch(phrase)) {
      _ensureWeekly();
      byday = ['SA', 'SU'];
    }
    if (RegExp(r'\bmwf\b').hasMatch(phrase)) {
      _ensureWeekly();
      byday = ['MO', 'WE', 'FR'];
    }
    if (RegExp(r'\btth\b').hasMatch(phrase)) {
      _ensureWeekly();
      byday = ['TU', 'TH'];
    }

    final dayMatches = RegExp(
      r'\b(mon(day)?|tue(s|sday)?|wed(nesday)?|thu(r|rs|rsday)?|fri(day)?|sat(urday)?|sun(day)?)\b',
      caseSensitive: false,
    ).allMatches(phrase).toList();
    if (dayMatches.isNotEmpty) {
      _ensureWeekly();
      final seen = <String>{};
      for (final m in dayMatches) {
        final code = _dowToIcs(m.group(0)!);
        if (seen.add(code)) byday.add(code);
      }
    }

    final mOrd = RegExp(
      r'\b(first|second|third|fourth|last)\s+(mon|tue|tues|wed|thu|thur|thurs|fri|sat|sun|monday|tuesday|wednesday|thursday|friday|saturday|sunday)\s+of\s+(the\s+)?month\b',
      caseSensitive: false,
    ).firstMatch(phrase);
    if (mOrd != null) {
      freq = 'MONTHLY';
      final ord = mOrd.group(1)!.toLowerCase();
      final day = mOrd.group(2)!;
      byday = [_dowToIcs(day)];
      bysetpos = switch (ord) {
        'first' => 1,
        'second' => 2,
        'third' => 3,
        'fourth' => 4,
        _ => -1
      };
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
        }
      }
    }

    final mCount =
        RegExp(r'\bfor\s+(\d+)\s+(times|occurrences)\b', caseSensitive: false)
            .firstMatch(phrase);
    if (mCount != null) {
      count = int.parse(mCount.group(1)!);
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

    final anchorText = (byday.isNotEmpty ||
            bymonthday != null ||
            bysetpos != null)
        ? phrase
            .replaceAll(
                RegExp(
                    r'\b(every|each|weekly|monthly|yearly|annually|biweekly|weekdays|weekends|mwf|tth)\b',
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

    final cleaned = (s.substring(0, span.start) +
            ' ' +
            (anchorText.isEmpty ? '' : anchorText) +
            ' ' +
            s.substring(span.end))
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

  _PriorityResult _parsePriority({
    required String original,
    required tz.TZDateTime base,
    required tz.TZDateTime? start,
    required FuzzyPolicy policy,
  }) {
    final s = original.toLowerCase();
    bool important = false, urgent = false;
    final notes = <String>[];

    bool containsAny(List<String> words) => words.any((w) => s.contains(w));

    if (containsAny(policy.importantWords)) {
      important = true;
      notes.add('Marked important from text.');
    }
    if (containsAny(policy.notImportantWords)) {
      important = false;
      notes.add('Marked not‑important from text.');
    }

    if (containsAny(policy.urgentWords)) {
      urgent = true;
      notes.add('Marked urgent from text.');
    }
    if (containsAny(policy.notUrgentWords)) {
      urgent = false;
      notes.add('Marked not‑urgent from text.');
    }

    if (!containsAny(policy.urgentWords) && start != null) {
      final hours = start.difference(base).inMinutes / 60.0;
      if (hours >= 0 && hours <= policy.urgentHorizonHours) {
        urgent = true;
        notes.add('Due in ≤ ${policy.urgentHorizonHours}h → urgent.');
      }
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
    return _PriorityResult(quadrant, notes);
  }

  _Vague? _resolveVaguePartOfDay(String original) {
    final lower = original.toLowerCase();
    if (lower.contains('tonight'))
      return _Vague('tonight', opts.policy.defaultEveningHour, isTonight: true);
    if (lower.contains('morning'))
      return _Vague('morning', opts.policy.defaultMorningHour);
    if (lower.contains('afternoon'))
      return _Vague('afternoon', opts.policy.defaultAfternoonHour);
    if (lower.contains('evening'))
      return _Vague('evening', opts.policy.defaultEveningHour);
    if (lower.contains('lunchtime') ||
        lower.contains('lunch time') ||
        lower.contains('lunch')) {
      return _Vague('lunch', opts.policy.lunchHour);
    }
    if (lower.contains('after work'))
      return _Vague('after work', opts.policy.afterWorkHour);
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

  String _clean(String s) => s
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp(r'[ ,.;]+$'), '');

  String _removeSpanByIndex(String s, int index, int length) {
    if (index < 0 || index + length > s.length) return s;
    return s.replaceRange(index, index + length, ' ');
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

  _PriorityResult(this.quadrant, this.assumptions);
}
