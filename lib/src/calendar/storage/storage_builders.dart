import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';

import 'calendar_hydrated_storage.dart';

const _guestPrefix = 'calendar_guest';
const _authPrefix = 'calendar_auth';

String get guestStoragePrefix => _guestPrefix;
String get authStoragePrefix => _authPrefix;

Future<Storage> buildGuestCalendarStorage() {
  return CalendarHydratedStorage.open(
    boxName: 'guest_calendar',
    prefix: _guestPrefix,
  );
}

Future<Storage> buildAuthCalendarStorage({required List<int> encryptionKey}) {
  return CalendarHydratedStorage.open(
    boxName: 'auth_calendar',
    prefix: _authPrefix,
    encryptionCipher: HydratedAesCipher(encryptionKey),
  );
}

/// Derives a 32-byte AES key from the provided secret string using SHA-256.
List<int> deriveCalendarEncryptionKey(String secret) {
  final digest = sha256.convert(utf8.encode(secret));
  return digest.bytes;
}
