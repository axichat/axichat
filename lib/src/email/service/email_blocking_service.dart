// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'dart:async';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

/// Callback type for syncing blocking state to DeltaChat core.
typedef DeltaChatBlockCallback = Future<bool> Function(String address);

class EmailBlockingService {
  EmailBlockingService({
    required Future<XmppDatabase> Function() databaseBuilder,
    DeltaChatBlockCallback? onBlock,
    DeltaChatBlockCallback? onUnblock,
  })  : _databaseBuilder = databaseBuilder,
        _onBlock = onBlock,
        _onUnblock = onUnblock;

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaChatBlockCallback? _onBlock;
  final DeltaChatBlockCallback? _onUnblock;

  Future<XmppDatabase> get _db async => _databaseBuilder();

  Stream<List<EmailBlocklistEntry>> blocklistStream() async* {
    final db = await _db;
    yield* db.watchEmailBlocklist();
  }

  Future<void> block(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final db = await _db;
    await db.addEmailBlock(normalized);
    // Sync to DeltaChat core to stop downloading messages from this contact
    await _onBlock?.call(normalized);
  }

  Future<void> unblock(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final db = await _db;
    await db.removeEmailBlock(normalized);
    // Sync to DeltaChat core to resume downloading messages from this contact
    await _onUnblock?.call(normalized);
  }

  Future<bool> isBlocked(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final db = await _db;
    return db.isEmailAddressBlocked(normalized);
  }
}
