import 'dart:async';

import 'package:axichat/src/calendar/bloc/calendar_state.dart';
import 'package:axichat/src/calendar/constants.dart';
import 'package:axichat/src/calendar/models/calendar_availability.dart';
import 'package:axichat/src/calendar/models/calendar_availability_message.dart';
import 'package:axichat/src/calendar/models/calendar_availability_share_state.dart';
import 'package:axichat/src/calendar/models/calendar_date_time.dart';
import 'package:axichat/src/calendar/models/calendar_model.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/models/day_event.dart';
import 'package:axichat/src/storage/models/chat_models.dart';
import 'package:uuid/uuid.dart';

import 'calendar_availability_share_store.dart';

typedef CalendarAvailabilityMessageSender = Future<void> Function({
  required String jid,
  required CalendarAvailabilityMessage message,
  required ChatType chatType,
});

const Duration _availabilityDaySpan = Duration(days: 1);
const bool _availabilityOverlayDefaultRedacted = true;
const Uuid _availabilityShareIdGenerator = Uuid();

class CalendarAvailabilityShareCoordinator {
  CalendarAvailabilityShareCoordinator({
    required CalendarAvailabilityShareStore store,
    required CalendarAvailabilityMessageSender sendMessage,
    DateTime Function()? now,
  })  : _store = store,
        _sendMessage = sendMessage,
        _now = now ?? DateTime.now;

  final CalendarAvailabilityShareStore _store;
  final CalendarAvailabilityMessageSender _sendMessage;
  final DateTime Function() _now;
  Map<String, CalendarAvailabilityShareRecord>? _cache;
  Future<void> _pendingUpdate = Future.value();

  Map<String, CalendarAvailabilityShareRecord> _ensureCache() {
    return _cache ??= _store.readAll();
  }

  Future<CalendarAvailabilityShareRecord?> createShare({
    required CalendarAvailabilityShareSource source,
    required CalendarModel model,
    required String ownerJid,
    required String chatJid,
    required ChatType chatType,
    required CalendarDateTime rangeStart,
    required CalendarDateTime rangeEnd,
    bool? isRedacted,
  }) async {
    if (chatType == ChatType.note) {
      return null;
    }
    if (!rangeEnd.value.isAfter(rangeStart.value)) {
      return null;
    }
    final String id = _availabilityShareIdGenerator.v4();
    final CalendarAvailabilityOverlay base = CalendarAvailabilityOverlay(
      owner: ownerJid,
      rangeStart: rangeStart,
      rangeEnd: rangeEnd,
      isRedacted: isRedacted ?? _availabilityOverlayDefaultRedacted,
    );
    final CalendarAvailabilityOverlay overlay =
        _deriveOverlay(model: model, base: base);
    final record = CalendarAvailabilityShareRecord(
      id: id,
      source: source,
      chatJid: chatJid,
      chatType: chatType,
      overlay: overlay,
      updatedAt: _now(),
    );
    final records = _ensureCache()..[id] = record;
    await _store.writeAll(records);
    final share = CalendarAvailabilityShare(id: id, overlay: overlay);
    final message = CalendarAvailabilityMessage.share(share: share);
    await _sendMessage(jid: chatJid, message: message, chatType: chatType);
    return record;
  }

  Future<void> handleModelChanged({
    required CalendarAvailabilityShareSource source,
    required CalendarModel model,
  }) {
    _pendingUpdate = _pendingUpdate.then(
      (_) => _handleModelChanged(source: source, model: model),
    );
    return _pendingUpdate;
  }

  CalendarAvailabilityShareRecord? recordFor(String shareId) {
    if (shareId.trim().isEmpty) {
      return null;
    }
    return _ensureCache()[shareId];
  }

  String? ownerJidForShare(String shareId) {
    return recordFor(shareId)?.overlay.owner;
  }

  Future<void> _handleModelChanged({
    required CalendarAvailabilityShareSource source,
    required CalendarModel model,
  }) async {
    final records = _ensureCache();
    final matches = records.values
        .where((record) => record.source == source)
        .toList(growable: false);
    if (matches.isEmpty) {
      return;
    }
    var didChange = false;
    for (final record in matches) {
      if (record.chatType == ChatType.note) {
        continue;
      }
      final CalendarAvailabilityOverlay overlay =
          _deriveOverlay(model: model, base: record.overlay);
      if (overlay == record.overlay) {
        continue;
      }
      final updated = record.copyWith(overlay: overlay, updatedAt: _now());
      records[record.id] = updated;
      didChange = true;
      final share = CalendarAvailabilityShare(id: record.id, overlay: overlay);
      final message = CalendarAvailabilityMessage.share(share: share);
      await _sendMessage(
        jid: record.chatJid,
        message: message,
        chatType: record.chatType,
      );
    }
    if (didChange) {
      await _store.writeAll(records);
    }
  }
}

CalendarAvailabilityOverlay _deriveOverlay({
  required CalendarModel model,
  required CalendarAvailabilityOverlay base,
}) {
  final DateTime rangeStart = base.rangeStart.value;
  final DateTime rangeEnd = base.rangeEnd.value;
  if (!rangeEnd.isAfter(rangeStart)) {
    return base.copyWith(intervals: const <CalendarFreeBusyInterval>[]);
  }
  final busyRanges = _mergeRanges(
    [
      ..._taskBusyRanges(model, rangeStart, rangeEnd),
      ..._dayEventBusyRanges(model, rangeStart, rangeEnd),
    ],
  );
  final availabilityRanges = _availabilityWindows(model, rangeStart, rangeEnd);
  final typedRanges = _buildTypedRanges(
    rangeStart: rangeStart,
    rangeEnd: rangeEnd,
    busyRanges: busyRanges,
    availabilityRanges: availabilityRanges,
  );
  final intervals = typedRanges
      .map((range) => _toInterval(range, base.rangeStart))
      .toList(growable: false);
  return base.copyWith(intervals: intervals);
}

List<_TimeRange> _taskBusyRanges(
  CalendarModel model,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final CalendarState state = CalendarState.initial().copyWith(model: model);
  final tasks = state.tasksInRange(rangeStart, rangeEnd);
  final ranges = <_TimeRange>[];
  for (final CalendarTask task in tasks) {
    final DateTime? start = task.scheduledTime;
    if (start == null) {
      continue;
    }
    final DateTime end = _resolveTaskEnd(task, start);
    final clipped = _clipRange(
      _TimeRange(start: start, end: end),
      rangeStart,
      rangeEnd,
    );
    if (clipped != null) {
      ranges.add(clipped);
    }
  }
  return ranges;
}

DateTime _resolveTaskEnd(CalendarTask task, DateTime start) {
  final DateTime? effectiveEnd = task.effectiveEndDate;
  if (effectiveEnd == null || !effectiveEnd.isAfter(start)) {
    return start.add(calendarDefaultTaskDuration);
  }
  return effectiveEnd;
}

List<_TimeRange> _dayEventBusyRanges(
  CalendarModel model,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final ranges = <_TimeRange>[];
  for (final DayEvent event in model.dayEvents.values) {
    final DateTime start = event.normalizedStart;
    final DateTime end = event.normalizedEnd.add(_availabilityDaySpan);
    final clipped = _clipRange(
      _TimeRange(start: start, end: end),
      rangeStart,
      rangeEnd,
    );
    if (clipped != null) {
      ranges.add(clipped);
    }
  }
  return ranges;
}

List<_TimeRange> _availabilityWindows(
  CalendarModel model,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final ranges = <_TimeRange>[];
  for (final availability in model.availability.values) {
    final availabilityRange = _TimeRange(
      start: availability.start.value,
      end: availability.end.value,
    );
    final windows = availability.windows.isEmpty
        ? <CalendarAvailabilityWindow>[
            CalendarAvailabilityWindow(
              start: availability.start,
              end: availability.end,
            ),
          ]
        : availability.windows;
    for (final CalendarAvailabilityWindow window in windows) {
      final windowRange = _TimeRange(
        start: window.start.value,
        end: window.end.value,
      );
      final constrained = _intersectRange(windowRange, availabilityRange);
      if (constrained == null) {
        continue;
      }
      final clipped = _clipRange(constrained, rangeStart, rangeEnd);
      if (clipped != null) {
        ranges.add(clipped);
      }
    }
  }
  return _mergeRanges(ranges);
}

List<_TypedRange> _buildTypedRanges({
  required DateTime rangeStart,
  required DateTime rangeEnd,
  required List<_TimeRange> busyRanges,
  required List<_TimeRange> availabilityRanges,
}) {
  final hasAvailability = availabilityRanges.isNotEmpty;
  final base = <_TypedRange>[];
  if (hasAvailability) {
    final unavailable = _invertRanges(rangeStart, rangeEnd, availabilityRanges);
    base
      ..addAll(
        unavailable.map(
          (range) => _TypedRange(
              range: range, type: CalendarFreeBusyType.busyUnavailable),
        ),
      )
      ..addAll(
        availabilityRanges.map(
          (range) => _TypedRange(range: range, type: CalendarFreeBusyType.free),
        ),
      );
  } else {
    base.add(
      _TypedRange(
        range: _TimeRange(start: rangeStart, end: rangeEnd),
        type: CalendarFreeBusyType.free,
      ),
    );
  }
  var typedRanges = _mergeTypedRanges(base);
  for (final busy in busyRanges) {
    typedRanges = _applyBusyRange(typedRanges, busy);
  }
  return typedRanges;
}

List<_TypedRange> _applyBusyRange(
  List<_TypedRange> current,
  _TimeRange busy,
) {
  final next = <_TypedRange>[];
  for (final segment in current) {
    if (!segment.range.overlaps(busy)) {
      next.add(segment);
      continue;
    }
    if (!segment.type.isFree) {
      next.add(segment);
      continue;
    }
    final DateTime overlapStart = _maxDateTime(segment.range.start, busy.start);
    final DateTime overlapEnd = _minDateTime(segment.range.end, busy.end);
    if (segment.range.start.isBefore(overlapStart)) {
      next.add(
        segment.copyWith(
          range: _TimeRange(start: segment.range.start, end: overlapStart),
        ),
      );
    }
    if (overlapEnd.isAfter(overlapStart)) {
      next.add(
        _TypedRange(
          range: _TimeRange(start: overlapStart, end: overlapEnd),
          type: CalendarFreeBusyType.busy,
        ),
      );
    }
    if (segment.range.end.isAfter(overlapEnd)) {
      next.add(
        segment.copyWith(
          range: _TimeRange(start: overlapEnd, end: segment.range.end),
        ),
      );
    }
  }
  return _mergeTypedRanges(next);
}

List<_TypedRange> _mergeTypedRanges(List<_TypedRange> ranges) {
  if (ranges.isEmpty) {
    return ranges;
  }
  final sorted = ranges.toList()
    ..sort((a, b) => a.range.start.compareTo(b.range.start));
  final merged = <_TypedRange>[];
  var current = sorted.first;
  for (final range in sorted.skip(1)) {
    if (current.type != range.type ||
        range.range.start.isAfter(current.range.end)) {
      merged.add(current);
      current = range;
      continue;
    }
    final DateTime end = range.range.end.isAfter(current.range.end)
        ? range.range.end
        : current.range.end;
    current = current.copyWith(
      range: _TimeRange(start: current.range.start, end: end),
    );
  }
  merged.add(current);
  return merged;
}

CalendarFreeBusyInterval _toInterval(
  _TypedRange range,
  CalendarDateTime base,
) {
  return CalendarFreeBusyInterval(
    start: _dateTimeWithRangeMeta(base, range.range.start),
    end: _dateTimeWithRangeMeta(base, range.range.end),
    type: range.type,
  );
}

CalendarDateTime _dateTimeWithRangeMeta(
  CalendarDateTime base,
  DateTime value,
) {
  return CalendarDateTime(
    value: value,
    tzid: base.tzid,
    isAllDay: base.isAllDay,
    isFloating: base.isFloating,
  );
}

List<_TimeRange> _invertRanges(
  DateTime rangeStart,
  DateTime rangeEnd,
  List<_TimeRange> ranges,
) {
  if (ranges.isEmpty) {
    return <_TimeRange>[_TimeRange(start: rangeStart, end: rangeEnd)];
  }
  final merged = _mergeRanges(ranges);
  final gaps = <_TimeRange>[];
  var cursor = rangeStart;
  for (final range in merged) {
    final DateTime start = _maxDateTime(range.start, rangeStart);
    final DateTime end = _minDateTime(range.end, rangeEnd);
    if (end.isBefore(rangeStart)) {
      continue;
    }
    if (start.isAfter(rangeEnd)) {
      break;
    }
    if (cursor.isBefore(start)) {
      gaps.add(_TimeRange(start: cursor, end: start));
    }
    if (end.isAfter(cursor)) {
      cursor = end;
    }
  }
  if (cursor.isBefore(rangeEnd)) {
    gaps.add(_TimeRange(start: cursor, end: rangeEnd));
  }
  return gaps;
}

List<_TimeRange> _mergeRanges(List<_TimeRange> ranges) {
  if (ranges.isEmpty) {
    return ranges;
  }
  final sorted = ranges.toList()..sort((a, b) => a.start.compareTo(b.start));
  final merged = <_TimeRange>[];
  var current = sorted.first;
  for (final range in sorted.skip(1)) {
    if (range.start.isAfter(current.end)) {
      merged.add(current);
      current = range;
      continue;
    }
    final DateTime end =
        range.end.isAfter(current.end) ? range.end : current.end;
    current = _TimeRange(start: current.start, end: end);
  }
  merged.add(current);
  return merged;
}

_TimeRange? _clipRange(
  _TimeRange range,
  DateTime rangeStart,
  DateTime rangeEnd,
) {
  final DateTime start = _maxDateTime(range.start, rangeStart);
  final DateTime end = _minDateTime(range.end, rangeEnd);
  if (!end.isAfter(start)) {
    return null;
  }
  return _TimeRange(start: start, end: end);
}

_TimeRange? _intersectRange(
  _TimeRange first,
  _TimeRange second,
) {
  final DateTime start = _maxDateTime(first.start, second.start);
  final DateTime end = _minDateTime(first.end, second.end);
  if (!end.isAfter(start)) {
    return null;
  }
  return _TimeRange(start: start, end: end);
}

DateTime _maxDateTime(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

DateTime _minDateTime(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

class _TimeRange {
  const _TimeRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  bool overlaps(_TimeRange other) =>
      start.isBefore(other.end) && end.isAfter(other.start);
}

class _TypedRange {
  const _TypedRange({
    required this.range,
    required this.type,
  });

  final _TimeRange range;
  final CalendarFreeBusyType type;

  _TypedRange copyWith({
    _TimeRange? range,
    CalendarFreeBusyType? type,
  }) =>
      _TypedRange(
        range: range ?? this.range,
        type: type ?? this.type,
      );
}
