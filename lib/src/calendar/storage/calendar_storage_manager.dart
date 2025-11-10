import 'package:hydrated_bloc/hydrated_bloc.dart';

import '../models/calendar_model.dart';
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
  ///
  /// Optionally seeds the hydrated state from a legacy [CalendarModel]
  /// persisted in the Hive box when no hydrated snapshot exists yet.
  Future<Storage> ensureGuestStorage({CalendarModel? legacyModel}) async {
    if (_guestStorage != null) return _guestStorage!;

    final storage = await CalendarHydratedStorage.open(
      boxName: 'guest_calendar_state',
      prefix: guestStoragePrefix,
    );

    _registry.registerPrefix(guestStoragePrefix, storage);
    await _seedFromLegacy(
      storage: storage,
      storagePrefix: guestStoragePrefix,
      legacyModel: legacyModel,
    );

    _guestStorage = storage;
    return storage;
  }

  /// Ensures authenticated calendar hydrated storage exists and is registered.
  ///
  /// The [passphrase] is used to derive an AES encryption key for the storage.
  /// A legacy [CalendarModel] can be provided to seed the hydrated state when
  /// migrating from the pre-hydrated implementation.
  Future<Storage> ensureAuthStorage({
    required String passphrase,
    CalendarModel? legacyModel,
  }) async {
    if (_authStorage != null) {
      return _authStorage!;
    }
    final encryptionKey = deriveCalendarEncryptionKey(passphrase);
    final storage = await buildAuthCalendarStorage(
      encryptionKey: encryptionKey,
    );

    _registry.registerPrefix(authStoragePrefix, storage);
    await _seedFromLegacy(
      storage: storage,
      storagePrefix: authStoragePrefix,
      legacyModel: legacyModel,
    );

    _authStorage = storage;
    return storage;
  }

  /// Unregisters and forgets the authenticated storage reference.
  void clearAuthStorage() {
    _registry.unregisterPrefix(authStoragePrefix);
    _authStorage = null;
  }

  Future<void> _seedFromLegacy({
    required Storage storage,
    required String storagePrefix,
    CalendarModel? legacyModel,
  }) async {
    if (legacyModel == null) return;
    final token = _storageToken(storagePrefix, 'state');
    if (storage.read(token) != null) return;

    final seedState = {
      'model': legacyModel.toJson(),
      'selectedDate': DateTime.now().toIso8601String(),
      'viewMode': 'week',
    };
    await storage.write(token, seedState);
  }

  String _storageToken(String prefix, String id) => '$prefix$id';
}
