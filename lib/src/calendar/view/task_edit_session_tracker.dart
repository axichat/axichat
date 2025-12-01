/// Tracks which tasks currently have an edit surface open to avoid opening
/// multiple popovers/sheets for the same task when it appears in different
/// places (grid + critical path, etc.).
class TaskEditSessionTracker {
  TaskEditSessionTracker._();

  static final TaskEditSessionTracker instance = TaskEditSessionTracker._();

  final Map<String, Object> _activeOwners = <String, Object>{};

  /// Returns `true` when this [owner] successfully claims the task for editing.
  /// Returns `false` if another owner already has an active edit session.
  bool begin(String taskId, Object owner) {
    final Object? existing = _activeOwners[taskId];
    if (existing != null) {
      return false;
    }
    _activeOwners[taskId] = owner;
    return true;
  }

  /// Releases the edit claim for [taskId] when owned by [owner].
  void end(String taskId, Object owner) {
    final Object? existing = _activeOwners[taskId];
    if (existing == owner) {
      _activeOwners.remove(taskId);
    }
  }

  /// Clears any claims held by [owner] (useful during dispose).
  void endForOwner(Object owner) {
    final Iterable<String> ownedTaskIds = _activeOwners.entries
        .where((entry) => identical(entry.value, owner))
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final String taskId in ownedTaskIds) {
      _activeOwners.remove(taskId);
    }
  }
}
