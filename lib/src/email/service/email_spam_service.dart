import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

class EmailSpamService {
  EmailSpamService({
    required Future<XmppDatabase> Function() databaseBuilder,
  }) : _databaseBuilder = databaseBuilder;

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
  }

  Future<void> unmark(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return;
    final db = await _db;
    await db.removeEmailSpam(normalized);
  }

  Future<bool> isSpam(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return false;
    final db = await _db;
    return db.isEmailAddressSpam(normalized);
  }

  String? _normalize(String address) {
    final normalized = address.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return normalized;
  }
}
