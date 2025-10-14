import 'package:flutter/material.dart';

/// Controller shared by inline and guest quick task composers. Keeps the
/// expanded state and temporary schedule selections out of the widget layer so
/// builds can remain declarative.
class InlineTaskComposerController extends ChangeNotifier {
  bool _isExpanded = false;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  bool get isExpanded => _isExpanded;
  DateTime? get selectedDate => _selectedDate;
  TimeOfDay? get selectedTime => _selectedTime;

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

  void setDate(DateTime? date) {
    if (_selectedDate == date) return;
    _selectedDate = date;
    notifyListeners();
  }

  void setTime(TimeOfDay? time) {
    if (_selectedTime == time) return;
    _selectedTime = time;
    notifyListeners();
  }

  void resetSchedule() {
    bool changed = false;
    if (_selectedDate != null || _selectedTime != null) {
      _selectedDate = null;
      _selectedTime = null;
      changed = true;
    }
    if (_isExpanded) {
      _isExpanded = false;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }
}
