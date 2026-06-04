// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/impatient_completer.dart';
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
  ImpatientCompleter<Storage>? _guestStorageCompleter;
  ImpatientCompleter<Storage>? _authStorageCompleter;
  String? _authStorageAccountAddress;
  String? _authStorageScopeKey;
  Future<void> _authStorageQueue = Future<void>.value();

  /// The currently registered guest storage, if any.
  Storage? get guestStorage => _guestStorageCompleter?.value;

  /// Future that completes when guest storage is ready.
  ///
  /// Returns null if [ensureGuestStorage] hasn't been called yet.
  Future<Storage>? get guestStorageFuture => _guestStorageCompleter?.future;

  /// Whether guest storage initialization has completed.
  bool get isGuestStorageReady => _guestStorageCompleter?.isCompleted ?? false;

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
    if (_guestStorageCompleter != null) {
      return _guestStorageCompleter!.future;
    }

    final ImpatientCompleter<Storage> completer = ImpatientCompleter<Storage>(
      Completer<Storage>(),
    );
    _guestStorageCompleter = completer;

    try {
      final Storage storage = await buildGuestCalendarStorage();
      _registry.registerPrefix(guestStoragePrefix, storage);

      completer.complete(storage);
      notifyListeners();
      return storage;
    } catch (e, st) {
      completer.completeError(e, st);
      _guestStorageCompleter = null;
      rethrow;
    }
  }

  /// Ensures authenticated calendar hydrated storage exists and is registered.
  ///
  /// Returns a future that completes when storage is ready.
  Future<Storage> ensureAuthStorage({
    required String accountAddress,
    required String passphrase,
    required String storageRootPath,
  }) async {
    final normalizedAccountAddress = normalizedAddressKey(accountAddress);
    if (normalizedAccountAddress == null) {
      throw ArgumentError.value(
        accountAddress,
        'accountAddress',
        'Authenticated calendar storage requires an account address.',
      );
    }
    final encryptionKey = deriveCalendarEncryptionKey(passphrase);
    final storageScopeKey = authCalendarStorageScopeKey(
      accountAddress: normalizedAccountAddress,
      encryptionKey: encryptionKey,
    );
    return _enqueueAuthStorageOperation(
      () => _ensureAuthStorage(
        accountAddress: normalizedAccountAddress,
        encryptionKey: encryptionKey,
        storageScopeKey: storageScopeKey,
        storageRootPath: storageRootPath,
      ),
    );
  }

  Future<Storage> _ensureAuthStorage({
    required String accountAddress,
    required List<int> encryptionKey,
    required String storageScopeKey,
    required String storageRootPath,
  }) async {
    final existingCompleter = _authStorageCompleter;
    if (existingCompleter != null) {
      if (_authStorageAccountAddress == accountAddress &&
          _authStorageScopeKey == storageScopeKey) {
        return existingCompleter.future;
      }
      await _closeAuthStorage(existingCompleter);
    }

    final ImpatientCompleter<Storage> completer = ImpatientCompleter<Storage>(
      Completer<Storage>(),
    );
    _authStorageCompleter = completer;
    _authStorageAccountAddress = accountAddress;
    _authStorageScopeKey = storageScopeKey;

    try {
      final storage = await buildAuthCalendarStorage(
        encryptionKey: encryptionKey,
        accountAddress: accountAddress,
        storageRootPath: storageRootPath,
      );

      _registry.registerPrefix(authStoragePrefix, storage);
      completer.complete(storage);
      notifyListeners();
      return storage;
    } catch (e, st) {
      completer.completeError(e, st);
      _authStorageCompleter = null;
      _authStorageAccountAddress = null;
      _authStorageScopeKey = null;
      rethrow;
    }
  }

  /// Unregisters and forgets the authenticated storage reference.
  Future<void> clearAuthStorage() {
    return _enqueueAuthStorageOperation(_clearAuthStorage);
  }

  Future<void> _clearAuthStorage() async {
    final existingCompleter = _authStorageCompleter;
    if (existingCompleter == null) {
      _registry.unregisterPrefix(authStoragePrefix);
      _authStorageAccountAddress = null;
      _authStorageScopeKey = null;
      return;
    }
    await _closeAuthStorage(existingCompleter);
  }

  Future<void> _closeAuthStorage(ImpatientCompleter<Storage> completer) async {
    _registry.unregisterPrefix(authStoragePrefix);
    _authStorageCompleter = null;
    _authStorageAccountAddress = null;
    _authStorageScopeKey = null;
    final storage = completer.value;
    try {
      await storage?.close();
    } finally {
      notifyListeners();
    }
  }

  Future<T> _enqueueAuthStorageOperation<T>(
    Future<T> Function() operation,
  ) async {
    final previousOperation = _authStorageQueue;
    final release = Completer<void>();
    _authStorageQueue = release.future;
    await previousOperation;
    try {
      return await operation();
    } finally {
      release.complete();
    }
  }
}
