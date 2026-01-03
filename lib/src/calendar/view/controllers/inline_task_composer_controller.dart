// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:flutter/material.dart';

/// Controller shared by inline and guest quick task composers. Keeps the
/// expanded state and temporary schedule selections out of the widget layer so
/// builds can remain declarative.
class InlineTaskComposerController extends ChangeNotifier {
  bool _isExpanded = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _dateLocked = false;
  bool _timeLocked = false;

  bool get isExpanded => _isExpanded;
  DateTime? get selectedDate => _selectedDate;
  TimeOfDay? get selectedTime => _selectedTime;
  bool get hasManualSchedule => _dateLocked || _timeLocked;

  void expand() {
    if (_isExpanded) return;
    _isExpanded = true;
    notifyListeners();
  }

  void collapse() {
    if (!_isExpanded) return;
    _isExpanded = false;
    notifyListeners();
  }

  void setDate(DateTime? date, {bool fromUser = false}) {
    final bool selectionChanged = _selectedDate != date;
    _selectedDate = date;
    final bool previousLock = _dateLocked;
    if (fromUser) {
      _dateLocked = date != null;
    } else if (date == null) {
      _dateLocked = false;
    }
    if (selectionChanged || previousLock != _dateLocked) {
      notifyListeners();
    }
  }

  void setTime(TimeOfDay? time, {bool fromUser = false}) {
    final bool selectionChanged = _selectedTime != time;
    _selectedTime = time;
    final bool previousLock = _timeLocked;
    if (fromUser) {
      _timeLocked = time != null;
    } else if (time == null) {
      _timeLocked = false;
    }
    if (selectionChanged || previousLock != _timeLocked) {
      notifyListeners();
    }
  }

  void applyParserSchedule(DateTime? scheduledTime) {
    DateTime? parsedDate;
    TimeOfDay? parsedTime;
    if (scheduledTime != null) {
      parsedDate =
          DateTime(scheduledTime.year, scheduledTime.month, scheduledTime.day);
      parsedTime =
          TimeOfDay(hour: scheduledTime.hour, minute: scheduledTime.minute);
    }

    bool changed = false;
    if (!_dateLocked && _selectedDate != parsedDate) {
      _selectedDate = parsedDate;
      changed = true;
    }
    if (!_timeLocked && _selectedTime != parsedTime) {
      _selectedTime = parsedTime;
      changed = true;
    }
    if ((parsedDate != null || parsedTime != null) && !_isExpanded) {
      _isExpanded = true;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void clearParserSuggestions() {
    bool changed = false;
    if (!_dateLocked && _selectedDate != null) {
      _selectedDate = null;
      changed = true;
    }
    if (!_timeLocked && _selectedTime != null) {
      _selectedTime = null;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  void resetSchedule({bool collapse = true}) {
    bool changed = false;
    if (_selectedDate != null ||
        _selectedTime != null ||
        _dateLocked ||
        _timeLocked) {
      _selectedDate = null;
      _selectedTime = null;
      _dateLocked = false;
      _timeLocked = false;
      changed = true;
    }
    if (collapse && _isExpanded) {
      _isExpanded = false;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
