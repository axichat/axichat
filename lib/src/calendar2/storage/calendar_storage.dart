import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive/hive.dart';

/// Internal storage wrapper that namespaces keys to avoid collisions with the
/// legacy calendar implementation while still sharing the same Hive box when
/// required.
class Calendar2HydratedStorage implements Storage {
  Calendar2HydratedStorage._(this._box, this._keyPrefix);

  /// Opens (or reuses) the backing Hive [Box] and returns a storage instance.
  static Future<Calendar2HydratedStorage> open({
    required String boxName,
    required String keyPrefix,
    HydratedCipher? encryptionCipher,
    HiveInterface? hive,
  }) async {
    final hiveInstance = hive ?? Hive;
    if (hiveInstance.isBoxOpen(boxName)) {
      final existing = hiveInstance.box<dynamic>(boxName);
      return Calendar2HydratedStorage._(existing, keyPrefix);
    }

    final box = await hiveInstance.openBox<dynamic>(
      boxName,
      encryptionCipher: encryptionCipher,
    );
    return Calendar2HydratedStorage._(box, keyPrefix);
  }

  final Box<dynamic> _box;
  final String _keyPrefix;

  String _namespaced(String key) => 'calendar2_${_keyPrefix}_$key';

  @override
  dynamic read(String key) {
    if (!_box.isOpen) {
      return null;
    }
    return _box.get(_namespaced(key));
  }

  @override
  Future<void> write(String key, dynamic value) async {
    if (!_box.isOpen) {
      return;
    }
    await _box.put(_namespaced(key), value);
  }

  @override
  Future<void> delete(String key) async {
    if (!_box.isOpen) {
      return;
    }
    await _box.delete(_namespaced(key));
  }

  @override
  Future<void> clear() async {
    if (!_box.isOpen) {
      return;
    }
    final keysToDelete = _box.keys.whereType<String>().where(
          (key) => key.startsWith('calendar2_${_keyPrefix}_'),
        );
    await _box.deleteAll(keysToDelete);
  }

  @override
  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}
