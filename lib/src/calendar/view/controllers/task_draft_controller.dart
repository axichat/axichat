import 'package:flutter/foundation.dart';

import 'package:axichat/src/calendar/models/calendar_ics_meta.dart';
import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';
import 'package:axichat/src/calendar/utils/schedule_range_utils.dart';

/// Reusable controller that owns the mutable state for composing a task draft.
/// Widgets can listen to this controller to rebuild when priority, schedule,
/// deadline, or recurrence inputs change.
class TaskDraftController extends ChangeNotifier {
  static const List<String> _emptyCategories = <String>[];

  TaskDraftController({
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? initialDeadline,
    RecurrenceFormValue initialRecurrence = const RecurrenceFormValue(),
    bool initialImportant = false,
    bool initialUrgent = false,
    ReminderPreferences? initialReminders,
    CalendarIcsStatus? initialStatus,
    CalendarTransparency? initialTransparency,
    List<String> initialCategories = _emptyCategories,
    String? initialUrl,
    CalendarGeo? initialGeo,
  })  : _startTime = initialStart,
        _endTime = initialEnd,
        _deadline = initialDeadline,
        _recurrence = initialRecurrence,
        _isImportant = initialImportant,
        _isUrgent = initialUrgent,
        _reminders =
            (initialReminders ?? ReminderPreferences.defaults()).normalized(),
        _status = initialStatus,
        _transparency = initialTransparency,
        _categories = _normalizeCategories(initialCategories),
        _url = _normalizeUrl(initialUrl),
        _geo = initialGeo;

  bool _isImportant;
  bool _isUrgent;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;
  RecurrenceFormValue _recurrence;
  ReminderPreferences _reminders;
  CalendarIcsStatus? _status;
  CalendarTransparency? _transparency;
  List<String> _categories;
  String? _url;
  CalendarGeo? _geo;

  bool get isImportant => _isImportant;
  bool get isUrgent => _isUrgent;
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;
  DateTime? get deadline => _deadline;
  RecurrenceFormValue get recurrence => _recurrence;
  ReminderPreferences get reminders => _reminders;
  CalendarIcsStatus? get status => _status;
  CalendarTransparency? get transparency => _transparency;
  List<String> get categories => List<String>.unmodifiable(_categories);
  String? get url => _url;
  CalendarGeo? get geo => _geo;

  void setImportant(bool value) {
    if (_isImportant == value) return;
    _isImportant = value;
    notifyListeners();
  }

  void setUrgent(bool value) {
    if (_isUrgent == value) return;
    _isUrgent = value;
    notifyListeners();
  }

  void updateStart(DateTime? value) {
    if (value == _startTime) {
      return;
    }

    final DateTime? previousStart = _startTime;
    final DateTime? previousEnd = _endTime;
    _startTime = value;
    _endTime = shiftEndTimeWithStart(
      previousStart: previousStart,
      previousEnd: previousEnd,
      nextStart: value,
    );

    if (value == null) {
      notifyListeners();
      return;
    }

    if (_recurrence.frequency == RecurrenceFrequency.weekly &&
        (_recurrence.weekdays.isEmpty || _recurrence.weekdays.length == 1)) {
      _recurrence = _recurrence.copyWith(weekdays: {value.weekday});
    }

    if (_recurrence.isActive) {
      _recurrence = _recurrence.resolveLinkedLimits(_startTime);
    }

    notifyListeners();
  }

  void updateEnd(DateTime? value) {
    final DateTime? clamped = clampEndTime(start: _startTime, end: value);
    if (clamped == _endTime) {
      return;
    }
    _endTime = clamped;
    notifyListeners();
  }

  void clearSchedule() {
    if (_startTime == null && _endTime == null) {
      return;
    }
    _startTime = null;
    _endTime = null;
    notifyListeners();
  }

  void setDeadline(DateTime? value) {
    if (_deadline == value) return;
    _deadline = value;
    notifyListeners();
  }

  void setRecurrence(RecurrenceFormValue value) {
    final RecurrenceFormValue normalized =
        value.resolveLinkedLimits(_startTime);
    if (_recurrence == normalized) return;
    _recurrence = normalized;
    notifyListeners();
  }

  void setReminders(ReminderPreferences value) {
    final ReminderPreferences normalized = value.normalized();
    if (_reminders == normalized) {
      return;
    }
    _reminders = normalized;
    notifyListeners();
  }

  void setStatus(CalendarIcsStatus? value) {
    if (_status == value) {
      return;
    }
    _status = value;
    notifyListeners();
  }

  void setTransparency(CalendarTransparency? value) {
    if (_transparency == value) {
      return;
    }
    _transparency = value;
    notifyListeners();
  }

  void setCategories(List<String> value) {
    final List<String> normalized = _normalizeCategories(value);
    if (listEquals(_categories, normalized)) {
      return;
    }
    _categories = normalized;
    notifyListeners();
  }

  void setUrl(String? value) {
    final String? normalized = _normalizeUrl(value);
    if (_url == normalized) {
      return;
    }
    _url = normalized;
    notifyListeners();
  }

  void setGeo(CalendarGeo? value) {
    if (_geo == value) {
      return;
    }
    _geo = value;
    notifyListeners();
  }

  TaskPriority get selectedPriority {
    if (_isImportant && _isUrgent) {
      return TaskPriority.critical;
    }
    if (_isImportant) {
      return TaskPriority.important;
    }
    if (_isUrgent) {
      return TaskPriority.urgent;
    }
    return TaskPriority.none;
  }

  Duration? get effectiveDuration {
    if (_startTime == null || _endTime == null) {
      return null;
    }
    return _endTime!.difference(_startTime!);
  }

  RecurrenceRule? buildRecurrence({DateTime? start}) {
    final DateTime? reference = start ?? _startTime;
    if (reference == null) {
      return null;
    }
    final RecurrenceFormValue normalized =
        _recurrence.resolveLinkedLimits(reference);
    return normalized.toRule(start: reference);
  }

  /// Resets the draft back to an empty state. Returns `true` if listeners were
  /// notified because at least one field changed.
  bool reset() {
    final bool didChange = _isImportant ||
        _isUrgent ||
        _startTime != null ||
        _endTime != null ||
        _deadline != null ||
        _recurrence.isActive ||
        _reminders != ReminderPreferences.defaults() ||
        _status != null ||
        _transparency != null ||
        _categories.isNotEmpty ||
        _url != null ||
        _geo != null;

    _isImportant = false;
    _isUrgent = false;
    _startTime = null;
    _endTime = null;
    _deadline = null;
    _recurrence = const RecurrenceFormValue();
    _reminders = ReminderPreferences.defaults();
    _status = null;
    _transparency = null;
    _categories = _emptyCategories;
    _url = null;
    _geo = null;

    if (didChange) {
      notifyListeners();
    }
    return didChange;
  }

  static List<String> _normalizeCategories(List<String> categories) {
    if (categories.isEmpty) {
      return _emptyCategories;
    }
    final List<String> normalized = <String>[];
    final Set<String> seen = <String>{};
    for (final String category in categories) {
      final String trimmed = category.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final String key = trimmed.toLowerCase();
      if (!seen.add(key)) {
        continue;
      }
      normalized.add(trimmed);
    }
    return normalized;
  }

  static String? _normalizeUrl(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
