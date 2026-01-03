// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';
import 'dart:io';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive/hive.dart';
import 'package:logging/logging.dart';

import 'package:axichat/src/storage/hive_extensions.dart';
import 'calendar_hive_adapters.dart';

const _fileNotFoundErrorCode = 2;

bool _isFileNotFound(Object error) {
  if (error is FileSystemException) {
    final osError = error.osError;
    return osError != null && osError.errorCode == _fileNotFoundErrorCode;
  }
  return false;
}

/// Hive-backed [Storage] implementation that namespaces keys so multiple
/// hydrated blocs can share the same box without collisions.
class CalendarHydratedStorage implements Storage {
  CalendarHydratedStorage._(this._box, this._prefix);

  /// Opens (or reuses) the Hive box identified by [boxName] and returns a
  /// storage wrapper that scopes all keys using [prefix].
  static Future<CalendarHydratedStorage> open({
    required String boxName,
    required String prefix,
    HydratedCipher? encryptionCipher,
    HiveInterface? hive,
  }) async {
    final Logger logger = Logger('CalendarHydratedStorage');
    final HiveInterface hiveInstance = hive ?? Hive;

    registerCalendarHiveAdapters(hiveInstance);

    Future<Box<dynamic>> openBoxWithRetry() {
      return hiveInstance.openBoxWithRetry<dynamic>(
        boxName,
        encryptionCipher: encryptionCipher,
        logger: logger,
      );
    }

    if (hiveInstance.isBoxOpen(boxName)) {
      final Box<dynamic> existing = hiveInstance.box<dynamic>(boxName);
      return CalendarHydratedStorage._(existing, prefix);
    }

    try {
      final Box<dynamic> box = await openBoxWithRetry();
      return CalendarHydratedStorage._(box, prefix);
    } catch (error, stackTrace) {
      if (isHiveLockUnavailable(error)) {
        logger.warning(
          'Hive box "$boxName" is locked and could not be opened.',
          error,
          stackTrace,
        );
        rethrow;
      }
      logger.warning(
        'Failed to open Hive box "$boxName". Attempting recovery.',
        error,
        stackTrace,
      );
      try {
        await hiveInstance.deleteBoxFromDisk(boxName);
      } catch (deleteError, deleteStack) {
        if (!_isFileNotFound(deleteError)) {
          logger.severe(
            'Unable to delete corrupted Hive box "$boxName".',
            deleteError,
            deleteStack,
          );
          rethrow;
        }
        logger.warning(
          'Hive box "$boxName" cleanup skipped missing files.',
          deleteError,
          deleteStack,
        );
      }

      final Box<dynamic> box = await openBoxWithRetry();
      return CalendarHydratedStorage._(box, prefix);
    }
  }

  final Box<dynamic> _box;
  final String _prefix;

  String _namespaced(String key) => '${_prefix}_$key';

  Iterable<String> get _scopedKeys sync* {
    if (!_box.isOpen) {
      return;
    }
    for (final key in _box.keys.whereType<String>()) {
      if (key.startsWith('${_prefix}_')) {
        yield key;
      }
    }
  }

  @override
  dynamic read(String key) {
    if (!_box.isOpen) {
      return null;
    }
    return _box.get(_namespaced(key));
  }

  @override
  Future<void> write(String key, dynamic value) async {
    if (!_box.isOpen) {
      return;
    }
    await _box.put(_namespaced(key), value);
  }

  @override
  Future<void> delete(String key) async {
    if (!_box.isOpen) {
      return;
    }
    await _box.delete(_namespaced(key));
  }

  @override
  Future<void> clear() async {
    if (!_box.isOpen) {
      return;
    }
    await _box.deleteAll(_scopedKeys);
  }

  @override
  Future<void> close() async {
    if (_box.isOpen) {
      await _box.close();
    }
  }
}
