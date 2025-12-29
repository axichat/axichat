import 'package:hydrated_bloc/hydrated_bloc.dart';

const String _linkedTaskRegistryStorageKey = 'calendar_linked_tasks_v1';

class CalendarLinkedTaskRegistry {
  CalendarLinkedTaskRegistry({
    Storage? storage,
    String storageKey = _linkedTaskRegistryStorageKey,
  })  : _storage = storage ?? HydratedBloc.storage,
        _storageKey = storageKey;

  static final CalendarLinkedTaskRegistry instance =
      CalendarLinkedTaskRegistry();

  final Storage _storage;
  final String _storageKey;

  Set<String> linkedStorageIds(String taskId) {
    final String trimmed = taskId.trim();
    if (trimmed.isEmpty) {
      return const <String>{};
    }
    final Map<String, Set<String>> mapping = _readAll();
    return mapping[trimmed] ?? const <String>{};
  }

  Future<void> addLinks({
    required String taskId,
    required Iterable<String> storageIds,
  }) async {
    final String trimmed = taskId.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final Set<String> normalizedIds =
        storageIds.map((id) => id.trim()).where((id) => id.isNotEmpty).toSet();
    if (normalizedIds.isEmpty) {
      return;
    }
    final Map<String, Set<String>> mapping = _readAll();
    final Set<String> existing = mapping[trimmed] ?? <String>{};
    final Set<String> merged = <String>{...existing, ...normalizedIds};
    mapping[trimmed] = merged;
    await _writeAll(mapping);
  }

  Map<String, Set<String>> _readAll() {
    final raw = _storage.read(_storageKey);
    if (raw is! Map) {
      return <String, Set<String>>{};
    }
    final Map<String, Set<String>> result = <String, Set<String>>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      if (key is! String) {
        continue;
      }
      final value = entry.value;
      if (value is! List) {
        continue;
      }
      final List<String> ids = value.whereType<String>().toList();
      if (ids.isEmpty) {
        continue;
      }
      result[key] = ids.toSet();
    }
    return result;
  }

  Future<void> _writeAll(Map<String, Set<String>> mapping) async {
    final Map<String, List<String>> encoded = <String, List<String>>{};
    for (final entry in mapping.entries) {
      final String key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final List<String> values = entry.value
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      if (values.isEmpty) {
        continue;
      }
      encoded[key] = values;
    }
    await _storage.write(_storageKey, encoded);
  }
}
