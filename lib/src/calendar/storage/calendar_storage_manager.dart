import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'calendar_hydrated_storage.dart';
import 'calendar_storage_registry.dart';
import 'storage_builders.dart';

/// Centralizes creation and registration of guest/auth calendar hydrated
/// storage instances. Ensures storages are registered with the
/// [CalendarStorageRegistry] before blocs attempt to hydrate using their
/// prefixes.
class CalendarStorageManager {
  CalendarStorageManager({required CalendarStorageRegistry registry})
      : _registry = registry;

  final CalendarStorageRegistry _registry;
  Storage? _guestStorage;
  Storage? _authStorage;

  /// The currently registered guest storage, if any.
  Storage? get guestStorage => _guestStorage;

  /// The currently registered authenticated storage, if any.
  Storage? get authStorage => _authStorage;

  /// Ensures guest calendar hydrated storage exists and is registered.
  Future<Storage> ensureGuestStorage() async {
    if (_guestStorage != null) return _guestStorage!;

    final storage = await CalendarHydratedStorage.open(
      boxName: 'guest_calendar_state',
      prefix: guestStoragePrefix,
    );

    _registry.registerPrefix(guestStoragePrefix, storage);

    _guestStorage = storage;
    return storage;
  }

  /// Ensures authenticated calendar hydrated storage exists and is registered.
  ///
  /// The [passphrase] is used to derive an AES encryption key for the storage.
  Future<Storage> ensureAuthStorage({
    required String passphrase,
  }) async {
    if (_authStorage != null) {
      return _authStorage!;
    }
    final encryptionKey = deriveCalendarEncryptionKey(passphrase);
    final storage = await buildAuthCalendarStorage(
      encryptionKey: encryptionKey,
    );

    _registry.registerPrefix(authStoragePrefix, storage);

    _authStorage = storage;
    return storage;
  }

  /// Unregisters and forgets the authenticated storage reference.
  void clearAuthStorage() {
    _registry.unregisterPrefix(authStoragePrefix);
    _authStorage = null;
  }
}
