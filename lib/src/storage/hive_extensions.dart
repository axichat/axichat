// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

const int _lockUnavailableErrorCode = 11;
const int _defaultLockRetryAttempts = 10;
const Duration _defaultLockRetryDelay = Duration(milliseconds: 200);
const String _lockRetryFailureMessage = 'Hive lock retry attempts exhausted.';

bool isHiveLockUnavailable(Object error) {
  if (error is FileSystemException) {
    final OSError? osError = error.osError;
    return osError != null && osError.errorCode == _lockUnavailableErrorCode;
  }
  return false;
}

extension HiveInterfaceOpenBoxRetry on HiveInterface {
  Future<Box<T>> openBoxWithRetry<T>(
    String name, {
    HiveCipher? encryptionCipher,
    Logger? logger,
    int lockRetryAttempts = _defaultLockRetryAttempts,
    Duration lockRetryDelay = _defaultLockRetryDelay,
  }) async {
    for (var attempt = 0; attempt < lockRetryAttempts; attempt++) {
      try {
        return await openBox<T>(
          name,
          encryptionCipher: encryptionCipher,
        );
      } catch (error, stackTrace) {
        final bool shouldRetry =
            isHiveLockUnavailable(error) && attempt < lockRetryAttempts - 1;
        if (!shouldRetry) {
          rethrow;
        }
        logger?.warning(
          'Hive box "$name" is locked. Retrying.',
          error,
          stackTrace,
        );
        await Future<void>.delayed(lockRetryDelay);
      }
    }
    throw StateError(_lockRetryFailureMessage);
  }
}
