import 'dart:async';

import 'package:axichat/src/storage/database.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

abstract class KeyValueDatabase<K, V> implements Database {
  FutureOr<V?> read({required K key});

  Future<bool> write({required K key, required V? value});

  Future<bool> delete({required K key});

  FutureOr<Map<String, V?>> readAll();

  Future<bool> writeAll({required Map<K, V?> data});

  Future<bool> deleteAll({bool burn = false});
}

class RegisteredStateKey {
  RegisteredStateKey._(this.value) {
    _registeredKeys.add(this);
  }

  final String value;

  static final _registeredKeys = <RegisteredStateKey>{};

  @override
  bool operator ==(Object other) =>
      other is RegisteredStateKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class XmppStateStore implements KeyValueDatabase<RegisteredStateKey, Object> {
  factory XmppStateStore() => _instance ??= XmppStateStore._();

  XmppStateStore._();

  static XmppStateStore? _instance;

  final _log = Logger('XmppStateStore');

  static const boxName = '.axichat.state_store';

  bool get initialized => Hive.isBoxOpen(boxName);

  static final Map<String, RegisteredStateKey> _keyCache = {};

  static RegisteredStateKey registerKey(String key) {
    final cached = _keyCache[key];
    if (cached != null) return cached;

    for (final existing in RegisteredStateKey._registeredKeys) {
      if (existing.value != key) continue;
      _keyCache[key] = existing;
      return existing;
    }

    final created = RegisteredStateKey._(key);
    _keyCache[key] = created;

    final uniqueByValue = <String, RegisteredStateKey>{};
    for (final existing in RegisteredStateKey._registeredKeys.toList()) {
      uniqueByValue.putIfAbsent(existing.value, () => existing);
    }
    RegisteredStateKey._registeredKeys
      ..clear()
      ..addAll(uniqueByValue.values);

    return created;
  }

  Stream<S>? watch<S>({required RegisteredStateKey key}) {
    if (!initialized) return null;
    return Hive.box(boxName).watch(key: key.value).map<S>((e) => e.value as S);
  }

  @override
  Object? read({required RegisteredStateKey key}) {
    if (!initialized) return null;
    return Hive.box(boxName).get(key.value);
  }

  @override
  Future<bool> write({
    required RegisteredStateKey key,
    required Object? value,
  }) async {
    if (!initialized) return false;
    await Hive.box(boxName).put(key.value, value);
    return true;
  }

  @override
  Future<bool> delete({required RegisteredStateKey key}) async {
    if (!initialized) return false;
    await Hive.box(boxName).delete(key.value);
    return true;
  }

  @override
  Map<String, Object?> readAll() {
    final result = <String, Object?>{};
    if (!initialized) return result;
    final box = Hive.box(boxName);
    for (final entry in box.toMap().entries) {
      result[entry.key.toString()] = entry.value;
    }
    return result;
  }

  @override
  Future<bool> writeAll({
    required Map<RegisteredStateKey, Object?> data,
  }) async {
    if (!initialized) return false;
    await Hive.box(boxName).putAll(data.map((k, v) => MapEntry(k.value, v)));
    return true;
  }

  @override
  Future<bool> deleteAll({bool burn = false}) async {
    if (!initialized) return false;
    if (burn) {
      _log.info('Deleting state store box from disk...');
      await Hive.box(boxName).deleteFromDisk();
    } else {
      await Hive.box(boxName)
          .deleteAll(RegisteredStateKey._registeredKeys.map((k) => k.value));
    }
    return true;
  }

  @override
  Future<void> close() async {
    if (!initialized) return;
    await Hive.box(boxName).close();
    _instance = null;
  }
}
