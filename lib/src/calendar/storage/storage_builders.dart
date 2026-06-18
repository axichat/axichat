// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:convert';
import 'dart:io';

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/common/app_owned_storage.dart';
import 'package:crypto/crypto.dart';
import 'package:hive_ce/hive.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:path/path.dart' as p;

import 'calendar_hydrated_storage.dart';

const _guestPrefix = 'calendar_guest';
const _authPrefix = 'calendar_auth';
const _guestBoxName = 'guest_calendar_state';
const _authBoxName = 'auth_calendar';
const _authDirectoryPrefix = 'calendar_auth_v3';

String get guestStoragePrefix => _guestPrefix;
String get authStoragePrefix => _authPrefix;
String get guestStorageBoxName => _guestBoxName;
String get authStorageBoxName => _authBoxName;

Future<Storage> buildGuestCalendarStorage() {
  return CalendarHydratedStorage.open(
    boxName: _guestBoxName,
    prefix: _guestPrefix,
  );
}

Future<Storage> buildAuthCalendarStorage({
  required List<int> encryptionKey,
  required String accountAddress,
  required String storageRootPath,
}) async {
  final storagePath = await _authCalendarStoragePath(
    accountAddress: accountAddress,
    encryptionKey: encryptionKey,
    storageRootPath: storageRootPath,
  );
  await _importLegacyAuthCalendarStorageIfNeeded(
    encryptionKey: encryptionKey,
    storagePath: storagePath,
  );
  return CalendarHydratedStorage.open(
    boxName: _authBoxName,
    prefix: _authPrefix,
    encryptionCipher: HiveAesCipher(encryptionKey),
    path: storagePath,
  );
}

/// Derives a 32-byte AES key from the provided secret string using SHA-256.
List<int> deriveCalendarEncryptionKey(String secret) {
  final digest = sha256.convert(utf8.encode(secret));
  return digest.bytes;
}

String authCalendarStorageScopeKey({
  required String accountAddress,
  required List<int> encryptionKey,
}) {
  final normalizedAddress = normalizedAddressKey(accountAddress);
  if (normalizedAddress == null) {
    throw ArgumentError.value(
      accountAddress,
      'accountAddress',
      'Authenticated calendar storage requires an account address.',
    );
  }
  final scopeHash = sha256.convert(<int>[
    ...utf8.encode(normalizedAddress),
    0,
    ...encryptionKey,
  ]);
  return normalizeAppOwnedPathSegment('${_authDirectoryPrefix}_$scopeHash');
}

Future<String> _authCalendarStoragePath({
  required String accountAddress,
  required List<int> encryptionKey,
  required String storageRootPath,
}) async {
  final directory = Directory(
    p.join(
      storageRootPath,
      authCalendarStorageScopeKey(
        accountAddress: accountAddress,
        encryptionKey: encryptionKey,
      ),
    ),
  );
  await directory.create(recursive: true);
  return directory.path;
}

Future<void> _importLegacyAuthCalendarStorageIfNeeded({
  required List<int> encryptionKey,
  required String storagePath,
}) async {
  final cipher = HiveAesCipher(encryptionKey);
  if (await _authCalendarBoxHasModel(path: storagePath, cipher: cipher)) {
    return;
  }
  final legacyEntries = await _readLegacyAuthCalendarEntries(cipher);
  if (legacyEntries.isEmpty) {
    return;
  }
  final currentBox = await Hive.openBox<dynamic>(
    _authBoxName,
    encryptionCipher: cipher,
    path: storagePath,
  );
  try {
    if (currentBox.get(_authCalendarStateStorageKey) != null) {
      return;
    }
    for (final entry in legacyEntries.entries) {
      if (currentBox.get(entry.key) == null) {
        await currentBox.put(entry.key, entry.value);
      }
    }
  } finally {
    await currentBox.close();
  }
}

Future<bool> _authCalendarBoxHasModel({
  required String path,
  required HiveCipher cipher,
}) async {
  final box = await Hive.openBox<dynamic>(
    _authBoxName,
    encryptionCipher: cipher,
    path: path,
  );
  try {
    return box.get(_authCalendarStateStorageKey) != null;
  } finally {
    await box.close();
  }
}

Future<Map<String, dynamic>> _readLegacyAuthCalendarEntries(
  HiveCipher cipher,
) async {
  if (Hive.isBoxOpen(_authBoxName)) {
    return const {};
  }
  Box<dynamic>? legacyBox;
  try {
    legacyBox = await Hive.openBox<dynamic>(
      _authBoxName,
      encryptionCipher: cipher,
    );
    if (legacyBox.get(_authCalendarStateStorageKey) == null) {
      return const {};
    }
    final entries = <String, dynamic>{};
    for (final key in legacyBox.keys.whereType<String>()) {
      if (key.startsWith('${_authPrefix}_')) {
        entries[key] = legacyBox.get(key);
      }
    }
    return entries;
  } on Object {
    return const {};
  } finally {
    await legacyBox?.close();
  }
}

String get _authCalendarStateStorageKey => '${_authPrefix}_$_authPrefix';
