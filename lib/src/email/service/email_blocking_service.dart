import 'dart:async';

import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

class EmailBlockingService {
  EmailBlockingService({
    required Future<XmppDatabase> Function() databaseBuilder,
  }) : _databaseBuilder = databaseBuilder;

  final Future<XmppDatabase> Function() _databaseBuilder;

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
  }

  Future<void> unblock(String address) async {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final db = await _db;
    await db.removeEmailBlock(normalized);
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
