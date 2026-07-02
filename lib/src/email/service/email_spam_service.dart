// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright (C) 2025-present Eliot Lew, Axichat Developers

import 'package:axichat/src/common/address_tools.dart';
import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

class EmailSpamService {
  EmailSpamService({required Future<XmppDatabase> Function() databaseBuilder})
    : _databaseBuilder = databaseBuilder;

  final Future<XmppDatabase> Function() _databaseBuilder;

  Future<XmppDatabase> get _db async => _databaseBuilder();

  Stream<List<EmailSpamEntry>> spamlistStream() async* {
    final db = await _db;
    yield* db.watchEmailSpamlist();
  }

  Future<void> mark(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return;
    final db = await _db;
    await db.addEmailSpam(normalized);
    await db.markEmailChatsSpam(address: normalized, spam: true);
  }

  Future<void> unmark(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return;
    final db = await _db;
    await db.removeEmailSpam(normalized);
    await db.markEmailChatsSpam(address: normalized, spam: false);
  }

  Future<bool> isSpam(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return false;
    final db = await _db;
    return db.isEmailAddressSpam(normalized);
  }

  String? _normalize(String address) {
    return normalizedAddressValue(address);
  }
}
