// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/capability.dart';
import 'package:axichat/src/common/policy.dart';
import 'package:axichat/src/demo/demo_mode.dart';
import 'package:axichat/src/storage/state_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logging/logging.dart';

class RegisteredCredentialKey {
  RegisteredCredentialKey._(this.value) {
    _registeredKeys.add(this);
  }

  final String value;

  static final _registeredKeys = <RegisteredCredentialKey>{};
  static final Map<String, RegisteredCredentialKey> _keyCache = {};

  @override
  bool operator ==(Object other) =>
      other is RegisteredCredentialKey && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class CredentialStore
    extends KeyValueDatabase<RegisteredCredentialKey, String> {
  CredentialStore._(this.capability, this.policy);

  static CredentialStore? _instance;

  factory CredentialStore({
    required Capability capability,
    required Policy policy,
  }) => _instance ??= kEnableDemoChats
      ? _DemoCredentialStore(capability, policy)
      : CredentialStore._(capability, policy);

  final Capability capability;
  final Policy policy;

  final Logger _log = Logger('CredentialStore');

  late final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: policy.getFssAndroidOptions(),
    mOptions: policy.getFssMacOsOptions(),
  );

  static RegisteredCredentialKey registerKey(String key) {
    final cached = RegisteredCredentialKey._keyCache[key];
    if (cached != null) return cached;

    for (final existing in RegisteredCredentialKey._registeredKeys) {
      if (existing.value != key) continue;
      RegisteredCredentialKey._keyCache[key] = existing;
      return existing;
    }

    final created = RegisteredCredentialKey._(key);
    RegisteredCredentialKey._keyCache[key] = created;

    final uniqueByValue = <String, RegisteredCredentialKey>{};
    for (final existing in RegisteredCredentialKey._registeredKeys.toList()) {
      uniqueByValue.putIfAbsent(existing.value, () => existing);
    }
    RegisteredCredentialKey._registeredKeys
      ..clear()
      ..addAll(uniqueByValue.values);

    return created;
  }

  @override
  Future<String?> read({required RegisteredCredentialKey key}) async {
    try {
      return await _secureStorage.read(key: key.value);
    } on Exception catch (e) {
      _log.severe('Failed to read value:', e);
    }
    return null;
  }

  @override
  Future<bool> write({
    required RegisteredCredentialKey key,
    required String? value,
  }) async {
    try {
      await _secureStorage.write(key: key.value, value: value);
      return true;
    } on Exception catch (e) {
      _log.severe('Failed to write value:', e);
    }
    return false;
  }

  @override
  Future<bool> delete({required RegisteredCredentialKey key}) async {
    try {
      await _secureStorage.delete(key: key.value);
      return true;
    } on Exception catch (e) {
      _log.severe('Failed to delete value:', e);
    }
    return false;
  }

  @override
  Future<Map<String, String?>> readAll() async {
    final values = <String, String?>{};
    try {
      if (!capability.canFssBatchOperation) {
        for (final key in RegisteredCredentialKey._registeredKeys) {
          values[key.value] = await read(key: key);
        }
        return values;
      }
      return await _secureStorage.readAll();
    } on Exception catch (e) {
      _log.severe('Failed to read all values:', e);
    }
    return values;
  }

  @override
  Future<bool> writeAll({
    required Map<RegisteredCredentialKey, String?> data,
  }) async {
    try {
      for (final entry in data.entries) {
        await _secureStorage.write(key: entry.key.value, value: entry.value);
      }
      return true;
    } on Exception catch (e) {
      _log.severe('Failed to write all values:', e);
    }
    return false;
  }

  @override
  Future<bool> deleteAll({bool burn = false}) async {
    try {
      _log.info('Deleting all values...');
      if (!capability.canFssBatchOperation) {
        for (final key in RegisteredCredentialKey._registeredKeys) {
          await _secureStorage.delete(key: key.value);
        }
      } else {
        await _secureStorage.deleteAll();
      }
      return true;
    } on Exception catch (e) {
      _log.severe('Failed to delete all values:', e);
    }
    return false;
  }

  @override
  Future<void> close() async {
    _instance = null;
  }
}

class _DemoCredentialStore extends CredentialStore {
  _DemoCredentialStore(super.capability, super.policy) : super._();

  final Map<String, String?> _values = {};

  @override
  Future<String?> read({required RegisteredCredentialKey key}) async =>
      _values[key.value];

  @override
  Future<bool> write({
    required RegisteredCredentialKey key,
    required String? value,
  }) async {
    if (value == null) {
      _values.remove(key.value);
      return true;
    }
    _values[key.value] = value;
    return true;
  }

  @override
  Future<bool> delete({required RegisteredCredentialKey key}) async {
    _values.remove(key.value);
    return true;
  }

  @override
  Future<Map<String, String?>> readAll() async =>
      Map<String, String?>.from(_values);

  @override
  Future<bool> writeAll({
    required Map<RegisteredCredentialKey, String?> data,
  }) async {
    for (final entry in data.entries) {
      _values[entry.key.value] = entry.value;
    }
    return true;
  }

  @override
  Future<bool> deleteAll({bool burn = false}) async {
    _values.clear();
    return true;
  }

  @override
  Future<void> close() async {
    _values.clear();
    CredentialStore._instance = null;
  }
}
