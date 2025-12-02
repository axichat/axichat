import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:axichat/src/calendar/models/calendar_task.dart';

/// Declarative controller for managing inline task checklists across forms.
class TaskChecklistController extends ChangeNotifier {
  TaskChecklistController({
    List<TaskChecklistItem> initialItems = const [],
  }) : _items = List<TaskChecklistItem>.from(
          TaskChecklistController.normalize(initialItems),
          growable: true,
        );

  static const Uuid _uuid = Uuid();
  List<TaskChecklistItem> _items;

  UnmodifiableListView<TaskChecklistItem> get items =>
      UnmodifiableListView(_items);

  bool get hasItems => _items.isNotEmpty;

  int get completedCount => _items.where((item) => item.isCompleted).length;

  double get progress => _items.isEmpty ? 0 : completedCount / _items.length;

  void setItems(List<TaskChecklistItem> next) {
    final normalized = List<TaskChecklistItem>.from(
      normalize(next),
      growable: true,
    );
    if (listEquals(normalized, _items)) {
      return;
    }
    _items = normalized;
    notifyListeners();
  }

  void addItem(String label) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) {
      return;
    }
    _items = [
      ..._items,
      TaskChecklistItem(
        id: _uuid.v4(),
        label: trimmed,
        isCompleted: false,
      ),
    ];
    notifyListeners();
  }

  void toggleItem(String id, bool isCompleted) {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    final TaskChecklistItem current = _items[index];
    if (current.isCompleted == isCompleted) {
      return;
    }
    _items = [
      ..._items.sublist(0, index),
      current.copyWith(isCompleted: isCompleted),
      ..._items.sublist(index + 1),
    ];
    notifyListeners();
  }

  void updateLabel(String id, String label) {
    final int index = _items.indexWhere((item) => item.id == id);
    if (index == -1) {
      return;
    }
    final String trimmed = label.trim();
    if (trimmed.isEmpty) {
      removeItem(id);
      return;
    }
    final TaskChecklistItem current = _items[index];
    if (current.label == trimmed) {
      return;
    }
    _items = [
      ..._items.sublist(0, index),
      current.copyWith(label: trimmed),
      ..._items.sublist(index + 1),
    ];
    notifyListeners();
  }

  void removeItem(String id) {
    final next = _items.where((item) => item.id != id).toList(growable: true);
    if (listEquals(next, _items)) {
      return;
    }
    _items = next;
    notifyListeners();
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        newIndex < 0 ||
        oldIndex >= _items.length ||
        newIndex > _items.length) {
      return;
    }
    final List<TaskChecklistItem> updated = List<TaskChecklistItem>.from(
      _items,
      growable: true,
    );
    final TaskChecklistItem moved = updated.removeAt(oldIndex);
    final int targetIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    updated.insert(targetIndex, moved);
    if (listEquals(updated, _items)) {
      return;
    }
    _items = updated;
    notifyListeners();
  }

  void clear() {
    if (_items.isEmpty) {
      return;
    }
    _items = <TaskChecklistItem>[];
    notifyListeners();
  }

  static List<TaskChecklistItem> normalize(List<TaskChecklistItem> source) {
    return source
        .map(
          (item) => item.copyWith(label: item.label.trim()),
        )
        .where((item) => item.label.isNotEmpty)
        .toList(growable: true);
  }
}
