import 'package:flutter/material.dart';

import '../../models/calendar_task.dart';
import '../widgets/recurrence_editor.dart';

/// Declarative controller for the quick add modal. Encapsulates all local UI
/// state so the widget tree can rebuild via [AnimatedBuilder] without relying
/// on setState.
class QuickAddController extends ChangeNotifier {
  QuickAddController({
    DateTime? initialStart,
    DateTime? initialEnd,
    DateTime? initialDeadline,
    RecurrenceFormValue initialRecurrence = const RecurrenceFormValue(),
    bool initialImportant = false,
    bool initialUrgent = false,
  })  : _startTime = initialStart,
        _endTime = initialEnd,
        _deadline = initialDeadline,
        _recurrence = initialRecurrence,
        _isImportant = initialImportant,
        _isUrgent = initialUrgent;

  bool _isImportant;
  bool _isUrgent;
  bool _isSubmitting = false;
  DateTime? _startTime;
  DateTime? _endTime;
  DateTime? _deadline;
  RecurrenceFormValue _recurrence;

  bool get isImportant => _isImportant;
  bool get isUrgent => _isUrgent;
  bool get isSubmitting => _isSubmitting;
  DateTime? get startTime => _startTime;
  DateTime? get endTime => _endTime;
  DateTime? get deadline => _deadline;
  RecurrenceFormValue get recurrence => _recurrence;

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

  void setSubmitting(bool value) {
    if (_isSubmitting == value) return;
    _isSubmitting = value;
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
      }
    } else {
      if (_endTime == null || !_endTime!.isAfter(value)) {
        _endTime = value.add(const Duration(hours: 1));
      }
      if (_recurrence.frequency == RecurrenceFrequency.weekly &&
          (_recurrence.weekdays.isEmpty || _recurrence.weekdays.length == 1)) {
        _recurrence = _recurrence.copyWith(weekdays: {value.weekday});
      }
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
    if (_recurrence == value) return;
    _recurrence = value;
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

  RecurrenceRule? buildRecurrence() {
    final start = _startTime;
    if (start == null) {
      return null;
    }
    return _recurrence.toRule(start: start);
  }
}
