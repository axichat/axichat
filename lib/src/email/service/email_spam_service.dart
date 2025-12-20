import 'package:axichat/src/storage/database.dart';
import 'package:axichat/src/storage/models.dart';

/// Callback type for syncing spam state to DeltaChat core blocking.
typedef DeltaChatSpamCallback = Future<bool> Function(String address);

class EmailSpamService {
  EmailSpamService({
    required Future<XmppDatabase> Function() databaseBuilder,
    DeltaChatSpamCallback? onMarkSpam,
    DeltaChatSpamCallback? onUnmarkSpam,
  })  : _databaseBuilder = databaseBuilder,
        _onMarkSpam = onMarkSpam,
        _onUnmarkSpam = onUnmarkSpam;

  final Future<XmppDatabase> Function() _databaseBuilder;
  final DeltaChatSpamCallback? _onMarkSpam;
  final DeltaChatSpamCallback? _onUnmarkSpam;

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
    // Block in DeltaChat to stop downloading messages from spammers
    await _onMarkSpam?.call(normalized);
  }

  Future<void> unmark(String address) async {
    final normalized = _normalize(address);
    if (normalized == null) return;
    final db = await _db;
    await db.removeEmailSpam(normalized);
    // Unblock in DeltaChat to resume downloading messages
    await _onUnmarkSpam?.call(normalized);
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
