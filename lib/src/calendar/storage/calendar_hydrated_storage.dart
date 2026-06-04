// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:hive_ce/hive.dart';
import 'package:logging/logging.dart';

import 'package:axichat/src/storage/hive_extensions.dart';
import 'calendar_hive_adapters.dart';

/// Hive-backed [Storage] implementation that namespaces keys so multiple
/// hydrated blocs can share the same box without collisions.
class CalendarHydratedStorage implements Storage {
  CalendarHydratedStorage._(this._box, this._prefix);

  /// Opens (or reuses) the Hive box identified by [boxName] and returns a
  /// storage wrapper that scopes all keys using [prefix].
  static Future<CalendarHydratedStorage> open({
    required String boxName,
    required String prefix,
    HiveCipher? encryptionCipher,
    HiveInterface? hive,
    String? path,
  }) async {
    final Logger logger = Logger('CalendarHydratedStorage');
    final HiveInterface hiveInstance = hive ?? Hive;

    registerCalendarHiveAdapters(hiveInstance);

    Future<Box<dynamic>> openBoxWithRetry() {
      return hiveInstance.openBoxWithRetry<dynamic>(
        boxName,
        encryptionCipher: encryptionCipher,
        logger: logger,
        path: path,
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
      logger.warning(
        isHiveLockUnavailable(error)
            ? 'Hive box "$boxName" is locked and could not be opened.'
            : 'Failed to open Hive box "$boxName".',
        error,
        stackTrace,
      );
      rethrow;
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
