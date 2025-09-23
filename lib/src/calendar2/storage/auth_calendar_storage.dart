import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive/hive.dart';

import 'calendar_storage.dart';

/// Builds an AES encrypted Hydrated [Storage] instance for the authenticated
/// calendar state.
Future<Storage> buildAuthCalendarStorage({
  required List<int> encryptionKey,
  HiveInterface? hive,
}) async {
  if (encryptionKey.length != 32) {
    throw ArgumentError(
      'calendar2 storage requires a 32-byte encryption key. '
      'Provided key length: ${encryptionKey.length}.',
    );
  }

  return Calendar2HydratedStorage.open(
    boxName: 'calendar2_auth',
    keyPrefix: 'auth',
    encryptionCipher: HydratedAesCipher(encryptionKey),
    hive: hive,
  );
}

/// Utility to derive a stable 32-byte AES key from an arbitrary secret using
/// SHA-256.
List<int> deriveCalendarStorageKey(String secret) {
  final hash = sha256.convert(utf8.encode(secret));
  return hash.bytes;
}
