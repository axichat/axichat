import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:axichat/src/storage/impatient_completer.dart';
import 'calendar_hydrated_storage.dart';
import 'calendar_storage_registry.dart';
import 'storage_builders.dart';

/// Centralizes creation and registration of guest/auth calendar hydrated
/// storage instances. Ensures storages are registered with the
/// [CalendarStorageRegistry] before blocs attempt to hydrate using their
/// prefixes.
///
/// Extends ChangeNotifier to notify listeners when auth storage becomes ready.
class CalendarStorageManager extends ChangeNotifier {
  CalendarStorageManager({required CalendarStorageRegistry registry})
      : _registry = registry;

  final CalendarStorageRegistry _registry;
  Storage? _guestStorage;
  ImpatientCompleter<Storage>? _authStorageCompleter;

  /// The currently registered guest storage, if any.
  Storage? get guestStorage => _guestStorage;

  /// The currently registered authenticated storage, if any.
  ///
  /// Returns null if [ensureAuthStorage] hasn't been called or hasn't
  /// completed yet. Prefer [authStorageFuture] for async access.
  Storage? get authStorage => _authStorageCompleter?.value;

  /// Future that completes when auth storage is ready.
  ///
  /// Returns null if [ensureAuthStorage] hasn't been called yet.
  Future<Storage>? get authStorageFuture => _authStorageCompleter?.future;

  /// Whether auth storage initialization has completed.
  bool get isAuthStorageReady => _authStorageCompleter?.isCompleted ?? false;

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
  /// Returns a future that completes when storage is ready.
  Future<Storage> ensureAuthStorage({
    required String passphrase,
  }) async {
    if (_authStorageCompleter != null) {
      return _authStorageCompleter!.future;
    }

    final completer = ImpatientCompleter<Storage>(Completer<Storage>());
    _authStorageCompleter = completer;

    try {
      final encryptionKey = deriveCalendarEncryptionKey(passphrase);
      final storage = await buildAuthCalendarStorage(
        encryptionKey: encryptionKey,
      );

      _registry.registerPrefix(authStoragePrefix, storage);
      completer.complete(storage);
      notifyListeners();
      return storage;
    } catch (e, st) {
      completer.completeError(e, st);
      _authStorageCompleter = null;
      rethrow;
    }
  }

  /// Unregisters and forgets the authenticated storage reference.
  void clearAuthStorage() {
    _registry.unregisterPrefix(authStoragePrefix);
    _authStorageCompleter = null;
  }
}
