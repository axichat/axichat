import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:logging/logging.dart';

/// Routes hydrated storage access to dedicated calendar storage instances based
/// on key prefixes while delegating all other keys to a fallback storage.
class CalendarStorageRegistry implements Storage {
  CalendarStorageRegistry({required Storage fallback})
      : _fallback = fallback,
        _log = Logger('CalendarStorageRegistry');

  final Storage _fallback;
  final Logger _log;
  final Map<String, Storage> _prefixToStorage = {};

  /// Registers [storage] for the provided [prefix]. Keys that begin with the
  /// prefix will be persisted using the registered storage.
  void registerPrefix(String prefix, Storage storage) {
    _log.fine('Registering storage for prefix "$prefix"');
    _prefixToStorage[prefix] = storage;
  }

  /// Removes any storage mapped to [prefix]. Subsequent operations will fall
  /// back to the default storage.
  void unregisterPrefix(String prefix) {
    _log.fine('Unregistering storage for prefix "$prefix"');
    _prefixToStorage.remove(prefix);
  }

  bool hasPrefix(String prefix) => _prefixToStorage.containsKey(prefix);

  Storage _storageFor(String key) {
    for (final entry in _prefixToStorage.entries) {
      if (key.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return _fallback;
  }

  @override
  dynamic read(String key) => _storageFor(key).read(key);

  @override
  Future<void> write(String key, dynamic value) =>
      _storageFor(key).write(key, value);

  @override
  Future<void> delete(String key) => _storageFor(key).delete(key);

  @override
  Future<void> clear() async {
    final processed = <Storage>{};
    for (final storage in _prefixToStorage.values) {
      if (processed.add(storage)) {
        await storage.clear();
      }
    }
    if (processed.add(_fallback)) {
      await _fallback.clear();
    }
  }

  @override
  Future<void> close() async {
    final processed = <Storage>{};
    for (final storage in _prefixToStorage.values) {
      if (processed.add(storage)) {
        await storage.close();
      }
    }
    if (processed.add(_fallback)) {
      await _fallback.close();
    }
  }
}
