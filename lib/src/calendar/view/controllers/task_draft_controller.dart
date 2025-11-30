import 'package:flutter/material.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';
import 'package:axichat/src/calendar/view/widgets/recurrence_editor.dart';
import 'package:axichat/src/calendar/models/reminder_preferences.dart';

/// Reusable controller that owns the mutable state for composing a task draft.
/// Widgets can listen to this controller to rebuild when priority, schedule,
/// deadline, or recurrence inputs change.
class TaskDraftController extends ChangeNotifier {
  TaskDraftController({
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? initialDeadline,
    RecurrenceFormValue initialRecurrence = const RecurrenceFormValue(),
    bool initialImportant = false,
    bool initialUrgent = false,
    ReminderPreferences? initialReminders,
  })  : _startTime = initialStart,
        _endTime = initialEnd,
        _deadline = initialDeadline,
        _recurrence = initialRecurrence,
        _isImportant = initialImportant,
        _isUrgent = initialUrgent,
        _reminders =
            (initialReminders ?? ReminderPreferences.defaults()).normalized();

  bool _isImportant;
  bool _isUrgent;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;
  RecurrenceFormValue _recurrence;
  ReminderPreferences _reminders;

  bool get isImportant => _isImportant;
  bool get isUrgent => _isUrgent;
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;
  DateTime? get deadline => _deadline;
  RecurrenceFormValue get recurrence => _recurrence;
  ReminderPreferences get reminders => _reminders;

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

    _startTime = value;

    if (value == null) {
      if (_endTime != null) {
        _endTime = null;
        notifyListeners();
      } else {
        notifyListeners();
      }
      return;
    }

    if (_endTime == null || !_endTime!.isAfter(value)) {
      _endTime = value.add(const Duration(hours: 1));
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
    if (value == null) {
      if (_endTime != null) {
        _endTime = null;
        notifyListeners();
      }
      return;
    }

    if (_startTime != null && !value.isAfter(_startTime!)) {
      final DateTime adjusted = _startTime!.add(const Duration(minutes: 15));
      if (_endTime == adjusted) {
        return;
      }
      _endTime = adjusted;
      notifyListeners();
      return;
    }

    if (_endTime != value) {
      _endTime = value;
      notifyListeners();
    }
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
        _reminders != ReminderPreferences.defaults();

    _isImportant = false;
    _isUrgent = false;
    _startTime = null;
    _endTime = null;
    _deadline = null;
    _recurrence = const RecurrenceFormValue();
    _reminders = ReminderPreferences.defaults();

    if (didChange) {
      notifyListeners();
    }
    return didChange;
  }
}
