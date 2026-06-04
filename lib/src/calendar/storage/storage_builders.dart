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

Future<String> _authCalendarStoragePath({
  required String accountAddress,
  required String storageRootPath,
}) async {
  final normalizedAddress = normalizedAddressKey(accountAddress);
  if (normalizedAddress == null) {
    throw ArgumentError.value(
      accountAddress,
      'accountAddress',
      'Authenticated calendar storage requires an account address.',
    );
  }
  final addressHash = sha256.convert(utf8.encode(normalizedAddress));
  final directory = Directory(
    p.join(
      storageRootPath,
      normalizeAppOwnedPathSegment('calendar_auth_v2_$addressHash'),
    ),
  );
  await directory.create(recursive: true);
  return directory.path;
}
