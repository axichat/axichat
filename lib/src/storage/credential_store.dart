part of '../../main.dart';

class RegisteredCredentialKey {
  RegisteredCredentialKey._(this.value) {
    _log.info('Registering key: $value...');
    _registeredKeys.add(this);
  }

  final _log = Logger('RegisteredCredentialKey');

  final String value;

  static final _registeredKeys = <RegisteredCredentialKey>{};
}

class CredentialStore
    implements KeyValueDatabase<RegisteredCredentialKey, String> {
  CredentialStore._();

  final Logger _log = Logger('CredentialStore');

  final FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: Policy().getFssAndroidOptions(),
  );

  @override
  RegisteredCredentialKey registerKey(String key) =>
      RegisteredCredentialKey._(key);

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
      if (!Capability().canFssBatchOperation) {
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
      data.forEach((key, value) async =>
          await _secureStorage.write(key: key.value, value: value));
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
      if (!Capability().canFssBatchOperation) {
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
}
