import 'dart:async';

import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import 'database.dart';

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
    _log.info('Registering key: $value...');
    _registeredKeys.add(this);
  }

  final _log = Logger('RegisteredStateKey');

  final String value;

  static final _registeredKeys = <RegisteredStateKey>{};
}

class XmppStateStore implements KeyValueDatabase<RegisteredStateKey, Object> {
  XmppStateStore._();

  static XmppStateStore? _instance;

  factory XmppStateStore() => _instance ??= XmppStateStore._();

  final _log = Logger('XmppStateStore');

  static const boxName = '.axichat.state_store';

  bool get initialized => Hive.isBoxOpen(boxName);

  static RegisteredStateKey registerKey(String key) =>
      RegisteredStateKey._(key);

  Stream<S>? watch<S>({required RegisteredStateKey key}) {
    if (!initialized) return null;
    return Hive.box(boxName).watch(key: key.value).map<S>((e) => e.value);
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
    Hive.box(boxName).toMap().forEach((k, v) => result[k.value] = v);
    return result;
  }

  @override
  Future<bool> writeAll(
      {required Map<RegisteredStateKey, Object?> data}) async {
    if (!initialized) return false;
    await Hive.box(boxName).putAll(data.map((k, v) => MapEntry(k.value, v)));
    return true;
  }

  @override
  Future<bool> deleteAll({bool burn = false}) async {
    if (!initialized) return false;
    if (burn) {
      _log.info('Deleting box: $boxName from disk...');
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
