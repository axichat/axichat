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
