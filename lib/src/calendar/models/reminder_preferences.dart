import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';

import 'package:axichat/src/calendar/constants.dart';

part 'reminder_preferences.freezed.dart';
part 'reminder_preferences.g.dart';

@freezed
@HiveType(typeId: 39)
class ReminderPreferences with _$ReminderPreferences {
  const factory ReminderPreferences({
    @HiveField(0) @Default(true) bool enabled,
    @HiveField(1) @Default(<Duration>[]) List<Duration> startOffsets,
    @HiveField(2) @Default(<Duration>[]) List<Duration> deadlineOffsets,
  }) = _ReminderPreferences;

  const ReminderPreferences._();

  factory ReminderPreferences.defaults() => const ReminderPreferences(
        startOffsets: calendarDefaultStartReminderOffsets,
        deadlineOffsets: calendarDefaultDeadlineReminderOffsets,
      );

  ReminderPreferences normalized({bool? forceEnabled}) {
    final List<Duration> normalizedStart = _normalizeOffsets(startOffsets);
    final List<Duration> normalizedDeadline =
        _normalizeOffsets(deadlineOffsets);
    final bool hasOffsets =
        normalizedStart.isNotEmpty || normalizedDeadline.isNotEmpty;
    final bool resolvedEnabled = (forceEnabled ?? enabled) && hasOffsets;
    return copyWith(
      enabled: resolvedEnabled,
      startOffsets: normalizedStart,
      deadlineOffsets: normalizedDeadline,
    );
  }

  bool get isEnabled =>
      enabled && (startOffsets.isNotEmpty || deadlineOffsets.isNotEmpty);

  factory ReminderPreferences.fromJson(Map<String, dynamic> json) =>
      _$ReminderPreferencesFromJson(json);

  List<Duration> _normalizeOffsets(List<Duration> offsets) {
    final Set<int> seen = <int>{};
    final List<Duration> normalized = <Duration>[];
    for (final Duration offset in offsets) {
      if (offset.isNegative) {
        continue;
      }
      final int micros = offset.inMicroseconds;
      if (seen.add(micros)) {
        normalized.add(offset);
      }
    }
    normalized.sort((Duration a, Duration b) => a.compareTo(b));
    return normalized;
  }
}
